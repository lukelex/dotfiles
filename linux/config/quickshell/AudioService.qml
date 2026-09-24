pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQml

QtObject {
  id: service

  property var outputs: []
  property string defaultSink: ""
  property string pendingSink: ""
  property string error: ""
  property bool loading: false
  property bool loaded: false
  property bool _readSucceeded: false
  property bool _refreshQueued: false
  property int activePanels: 0
  property string _requestedSink: ""
  readonly property bool busy: pendingSink !== "" || setOutputProcess.running

  function refresh(force = false) {
    if (service.loading) {
      if (force)
        service._refreshQueued = true
      return
    }

    service.loading = true
    service._readSucceeded = false
    listOutputsProcess.running = true
  }

  function panelOpened() {
    service.activePanels++
  }

  function panelClosed() {
    service.activePanels = Math.max(0, service.activePanels - 1)
  }

  function outputIcon(sink) {
    const properties = sink.properties && typeof sink.properties === "object" ? sink.properties : {}
    const activePort = Array.isArray(sink.ports)
      ? sink.ports.find(port => port.name === sink.active_port) : null
    const details = [
      sink.name,
      sink.description,
      properties["node.nick"],
      properties["device.product.name"],
      properties["device.profile.description"],
      properties["device.icon_name"],
      properties["device.bus"],
      activePort?.name,
      activePort?.description,
      activePort?.type,
    ].filter(value => typeof value === "string").join(" ").toLowerCase()
    const bus = typeof properties["device.bus"] === "string" ? properties["device.bus"].toLowerCase() : ""

    if (bus === "bluetooth" || /bluetooth|bluez/.test(details))
      return "bluetooth"
    if (/\bhdmi\b|displayport|monitor|television|\btv\b/.test(details))
      return "monitor"
    if (/headphones?|headsets?|earbuds?|airpods?/.test(details))
      return "headphones"
    if (bus === "usb" || /\busb\b/.test(details))
      return "usb"
    return "speaker"
  }

  function _accept(text) {
    const marker = "\n__QUICKSHELL_DEFAULT_SINK__\n"
    const markerIndex = text.indexOf(marker)
    if (markerIndex < 0) {
      service.error = "Output devices are unavailable."
      return
    }

    try {
      const sinks = JSON.parse(text.slice(0, markerIndex))
      if (!Array.isArray(sinks))
        throw new Error("Invalid output list")

      const nextOutputs = sinks
        .filter(sink => sink && typeof sink.name === "string" && sink.name.trim())
        .map(sink => ({
          name: sink.name,
          description: typeof sink.description === "string" && sink.description.trim()
            ? sink.description : sink.properties?.["node.nick"] || sink.name,
          iconName: service.outputIcon(sink),
        }))
        .sort((left, right) => left.description.localeCompare(right.description)
          || left.name.localeCompare(right.name))
      const nextDefault = text.slice(markerIndex + marker.length).trim().split("\n")[0]

      const unchanged = nextOutputs.length === service.outputs.length
        && nextOutputs.every((output, index) => output.name === service.outputs[index].name
          && output.description === service.outputs[index].description
          && output.iconName === service.outputs[index].iconName)
      if (!unchanged)
        service.outputs = nextOutputs

      service.defaultSink = nextDefault
      service.loaded = true
      service._readSucceeded = true
      if (service.error === "Output devices are unavailable.")
        service.error = ""

      if (service.pendingSink && service.pendingSink === nextDefault && !setOutputProcess.running) {
        service.pendingSink = ""
        service.error = ""
        service.selectionTimeout.stop()
      } else if (service.pendingSink && !setOutputProcess.running
          && !nextOutputs.some(output => output.name === service.pendingSink)) {
        service.pendingSink = ""
        service.error = "That output device is no longer available."
        service.selectionTimeout.stop()
      }
    } catch (_) {
      service.error = "Output devices are unavailable."
    }
  }

  function setDefaultSink(name) {
    if (service.busy || name === service.defaultSink
        || !service.outputs.some(output => output.name === name))
      return

    service.error = ""
    service._requestedSink = name
    service.pendingSink = name
    selectionTimeout.restart()
    setOutputProcess.running = true
  }

  function _finishRefresh(exitCode) {
    if (exitCode !== 0 || !service._readSucceeded)
      service.error = "Output devices are unavailable."

    service.loading = false
    if (service._refreshQueued) {
      service._refreshQueued = false
      queuedRefresh.restart()
    }
  }

  property Process listOutputsProcess: Process {
    command: ["sh", "-c", "pactl -f json list sinks && printf '\\n__QUICKSHELL_DEFAULT_SINK__\\n' && pactl get-default-sink"]
    stdout: StdioCollector {
      onStreamFinished: service._accept(this.text)
    }
    onExited: (exitCode) => service._finishRefresh(exitCode)
  }

  property Process setOutputProcess: Process {
    command: ["sh", "-c", "sink=$1; pactl set-default-sink \"$sink\" && pactl list short sink-inputs | cut -f1 | while IFS= read -r input; do pactl move-sink-input \"$input\" \"$sink\" 2>/dev/null || true; done", "quickshell-audio", service._requestedSink]
    onExited: (exitCode) => {
      const requestedSink = service._requestedSink
      if (service.pendingSink === requestedSink && exitCode !== 0) {
        service.pendingSink = ""
        service.error = "Could not switch output device."
        service.selectionTimeout.stop()
      }
      service.refresh(true)
    }
  }

  property Timer queuedRefresh: Timer {
    interval: 100
    onTriggered: service.refresh(true)
  }

  property Timer selectionTimeout: Timer {
    interval: 5000
    onTriggered: {
      if (!service.pendingSink)
        return
      service.pendingSink = ""
      service.error = "Could not confirm the output device change."
      service.refresh(true)
    }
  }

  property Timer refreshTimer: Timer {
    interval: 5000
    running: service.activePanels > 0
    repeat: true
    onTriggered: service.refresh()
  }
}

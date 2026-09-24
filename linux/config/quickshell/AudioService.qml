pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQml

QtObject {
  id: service

  property var outputs: []
  property var inputs: []
  property string defaultSink: ""
  property string defaultSource: ""
  property string pendingSink: ""
  property string pendingSource: ""
  property string error: ""
  property bool loading: false
  property bool loaded: false
  property bool _readSucceeded: false
  property bool _refreshQueued: false
  property int activePanels: 0
  property string _requestedSink: ""
  property string _requestedSource: ""
  readonly property bool busy: pendingSink !== "" || pendingSource !== ""
    || setOutputProcess.running || _settingInput
  property bool _settingInput: false

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

  function inputIcon(source) {
    const properties = source.properties && typeof source.properties === "object" ? source.properties : {}
    const activePort = Array.isArray(source.ports)
      ? source.ports.find(port => port.name === source.active_port) : null
    const details = [
      source.name,
      source.description,
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
    if (/headphones?|headsets?|earbuds?|airpods?/.test(details))
      return "headphones"
    if (bus === "usb" || /\busb\b/.test(details))
      return "usb"
    return "mic"
  }

  function inputDescription(source) {
    const properties = source.properties && typeof source.properties === "object" ? source.properties : {}
    const description = typeof source.description === "string" && source.description.trim()
      ? source.description : properties["node.nick"] || source.name
    const activePort = Array.isArray(source.ports)
      ? source.ports.find(port => port.name === source.active_port) : null
    const portDescription = activePort && typeof activePort.description === "string"
      ? activePort.description.trim() : ""
    if (portDescription && /mic|headset|input/i.test(portDescription)
        && !description.toLowerCase().includes(portDescription.toLowerCase()))
      return portDescription + " — " + description
    return description
  }

  function _accept(text) {
    const sinkMarker = "\n__QUICKSHELL_DEFAULT_SINK__\n"
    const inputMarker = "\n__QUICKSHELL_INPUTS__\n"
    const sourceMarker = "\n__QUICKSHELL_DEFAULT_SOURCE__\n"
    const sinkMarkerIndex = text.indexOf(sinkMarker)
    const inputMarkerIndex = text.indexOf(inputMarker, sinkMarkerIndex + sinkMarker.length)
    const sourceMarkerIndex = text.indexOf(sourceMarker, inputMarkerIndex + inputMarker.length)
    if (sinkMarkerIndex < 0 || inputMarkerIndex < 0 || sourceMarkerIndex < 0) {
      service.error = "Audio devices are unavailable."
      return
    }

    try {
      const sinks = JSON.parse(text.slice(0, sinkMarkerIndex))
      const sources = JSON.parse(text.slice(inputMarkerIndex + inputMarker.length, sourceMarkerIndex))
      if (!Array.isArray(sinks) || !Array.isArray(sources))
        throw new Error("Invalid audio device lists")

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
      const nextInputs = sources
        .filter(source => {
          if (!source || typeof source.name !== "string" || !source.name.trim())
            return false
          const properties = source.properties && typeof source.properties === "object" ? source.properties : {}
          return properties["device.class"] !== "monitor" && properties["media.class"] !== "Audio/Sink"
            && !(typeof source.monitor_of_sink === "string" && source.monitor_of_sink !== "")
            && !source.name.endsWith(".monitor")
        })
        .map(source => ({
          name: source.name,
          description: service.inputDescription(source),
          iconName: service.inputIcon(source),
        }))
        .sort((left, right) => left.description.localeCompare(right.description)
          || left.name.localeCompare(right.name))
      const nextDefaultSink = text.slice(sinkMarkerIndex + sinkMarker.length, inputMarkerIndex).trim().split("\n")[0]
      const nextDefaultSource = text.slice(sourceMarkerIndex + sourceMarker.length).trim().split("\n")[0]

      const outputsUnchanged = nextOutputs.length === service.outputs.length
        && nextOutputs.every((output, index) => output.name === service.outputs[index].name
          && output.description === service.outputs[index].description
          && output.iconName === service.outputs[index].iconName)
      const inputsUnchanged = nextInputs.length === service.inputs.length
        && nextInputs.every((input, index) => input.name === service.inputs[index].name
          && input.description === service.inputs[index].description
          && input.iconName === service.inputs[index].iconName)
      if (!outputsUnchanged)
        service.outputs = nextOutputs
      if (!inputsUnchanged)
        service.inputs = nextInputs

      service.defaultSink = nextDefaultSink
      service.defaultSource = nextDefaultSource
      service.loaded = true
      service._readSucceeded = true
      if (service.error === "Audio devices are unavailable.")
        service.error = ""

      if (service.pendingSink && service.pendingSink === nextDefaultSink && !setOutputProcess.running) {
        service.pendingSink = ""
        service.error = ""
        service.outputSelectionTimeout.stop()
      } else if (service.pendingSink && !setOutputProcess.running
          && !nextOutputs.some(output => output.name === service.pendingSink)) {
        service.pendingSink = ""
        service.error = "That output device is no longer available."
        service.outputSelectionTimeout.stop()
      }

      if (service.pendingSource && service.pendingSource === nextDefaultSource && !setInputProcess.running) {
        service.pendingSource = ""
        service.error = ""
        service.inputSelectionTimeout.stop()
      } else if (service.pendingSource && !setInputProcess.running
          && !nextInputs.some(input => input.name === service.pendingSource)) {
        service.pendingSource = ""
        service.error = "That input device is no longer available."
        service.inputSelectionTimeout.stop()
      }
    } catch (_) {
      service.error = "Audio devices are unavailable."
    }
  }

  function setDefaultSink(name) {
    if (service.busy || name === service.defaultSink
        || !service.outputs.some(output => output.name === name))
      return

    service.error = ""
    service._requestedSink = name
    service.pendingSink = name
    service.outputSelectionTimeout.restart()
    setOutputProcess.running = true
  }

  function setDefaultSource(name) {
    if (service.busy || name === service.defaultSource
        || !service.inputs.some(input => input.name === name))
      return

    service.error = ""
    service._requestedSource = name
    service.pendingSource = name
    service._settingInput = true
    service.inputSelectionTimeout.restart()
    setInputProcess.running = true
  }

  function _finishRefresh(exitCode) {
    if (exitCode !== 0 || !service._readSucceeded)
      service.error = "Audio devices are unavailable."

    service.loading = false
    if (service._refreshQueued) {
      service._refreshQueued = false
      queuedRefresh.restart()
    }
  }

  property Process listOutputsProcess: Process {
    command: ["sh", "-c", "pactl -f json list sinks && printf '\\n__QUICKSHELL_DEFAULT_SINK__\\n' && pactl get-default-sink && printf '\\n__QUICKSHELL_INPUTS__\\n' && pactl -f json list sources && printf '\\n__QUICKSHELL_DEFAULT_SOURCE__\\n' && { pactl get-default-source 2>/dev/null || true; }"]
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
        service.outputSelectionTimeout.stop()
      }
      service.refresh(true)
    }
  }

  property Process setInputProcess: Process {
    command: ["sh", "-c", "source=$1; pactl set-default-source \"$source\" && pactl list short source-outputs | cut -f1 | while IFS= read -r output; do pactl move-source-output \"$output\" \"$source\" 2>/dev/null || true; done", "quickshell-audio", service._requestedSource]
    onExited: (exitCode) => {
      service._settingInput = false
      const requestedSource = service._requestedSource
      if (service.pendingSource === requestedSource && exitCode !== 0) {
        service.pendingSource = ""
        service.error = "Could not switch input device."
        service.inputSelectionTimeout.stop()
      }
      service.refresh(true)
    }
  }

  property Timer queuedRefresh: Timer {
    interval: 100
    onTriggered: service.refresh(true)
  }

  property Timer outputSelectionTimeout: Timer {
    interval: 5000
    onTriggered: {
      if (!service.pendingSink)
        return
      service.pendingSink = ""
      service.error = "Could not confirm the output device change."
      service.refresh(true)
    }
  }

  property Timer inputSelectionTimeout: Timer {
    interval: 5000
    onTriggered: {
      if (!service.pendingSource)
        return
      service.pendingSource = ""
      service.error = "Could not confirm the input device change."
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

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: service
  readonly property string helper: Quickshell.env("HOME") + "/dotfiles/linux/config/system-settings/monitors.py"
  property bool visible: false
  property bool busy: false
  property string error: ""
  property var linkDetails: null
  property var snapshot: ({ outputs: [], profiles: [], automatic: true, pending: null, session: Quickshell.env("XDG_SESSION_TYPE") })
  property var draft: []
  property bool dirty: false
  property string selectedProfile: ""
  property int selectedOutput: 0
  onSelectedOutputChanged: linkDetails = null
  property double now: Date.now() / 1000
  readonly property int secondsLeft: snapshot.pending ? Math.max(0, Math.ceil(snapshot.pending.deadline - now)) : 0
  readonly property var output: draft[selectedOutput] || null
  readonly property var connectedOutput: output ? snapshot.outputs.find(o => o.connector === output.connector || output.identity && o.identity === output.identity) : null
  readonly property bool pending: !!snapshot.pending
  property bool resetAfterRead: false
  property bool preserveProfileAfterRead: false
  property var queuedCommand: null
  property string previousTopology: ""
  onVisibleChanged: { if (visible) refresh() }

  function refresh() {
    if (!reader.running && !writer.running)
      reader.running = true
  }

  function resetDraft(preserveProfile = false) {
    const initial = draft.length === 0
    draft = JSON.parse(JSON.stringify(snapshot.outputs))
    dirty = false
    if (!preserveProfile) selectedProfile = ""
    selectedOutput = Math.min(selectedOutput, Math.max(0, draft.length - 1))
    if (initial) selectedOutput = Math.max(0, draft.findIndex(o => o.enabled))
  }

  function chooseProfile(name) {
    const profile = snapshot.profiles.find(p => p.name === name)
    if (!profile)
      return
    draft = profile.outputs.map(saved => {
      const actual = snapshot.outputs.find(o => saved.identity ? o.identity === saved.identity : o.connector === saved.connector)
      return Object.assign({}, saved, { connector: actual ? actual.connector : saved.connector })
    })
    selectedProfile = name
    selectedOutput = 0
    dirty = profile.current !== true
  }

  function edit(key, value) {
    if (!output || busy || pending || output[key] === value)
      return
    draft = draft.map((o, index) => index === selectedOutput ? Object.assign({}, o, { [key]: value })
      : key === "primary" && value ? Object.assign({}, o, { primary: false }) : o)
    dirty = true
  }

  function size(output) {
    const dimensions = output.mode.split("x").map(Number)
    const rotated = output.rotation === "left" || output.rotation === "right"
    return { width: dimensions[rotated ? 1 : 0] / output.scale, height: dimensions[rotated ? 0 : 1] / output.scale }
  }

  function move(index, x, y) {
    const current = draft[index]
    const dimensions = size(current)
    x = Math.max(0, Math.round(x))
    y = Math.max(0, Math.round(y))
    for (let i = 0; i < draft.length; i++) {
      if (i === index || !draft[i].enabled)
        continue
      const other = draft[i]
      const bounds = size(other)
      for (const edge of [other.x, other.x + bounds.width, other.x - dimensions.width])
        if (Math.abs(edge - x) < 100) x = Math.max(0, Math.round(edge))
      for (const edge of [other.y, other.y + bounds.height, other.y - dimensions.height])
        if (Math.abs(edge - y) < 100) y = Math.max(0, Math.round(edge))
    }
    draft = draft.map((o, i) => i === index ? Object.assign({}, o, { x: x, y: y }) : o)
    dirty = true
  }

  function run(action, value = "", extra = "") {
    if (busy || writer.running)
      return
    error = ""
    busy = true
    queuedCommand = ["python3", helper, action, value, extra]
    writer.action = action
    if (!reader.running) {
      writer.command = queuedCommand
      queuedCommand = null
      writer.running = true
    }
  }

  function save(name, replaceName, preferred) {
    run("save", JSON.stringify({ name: name.trim(), session: snapshot.session, preferred: preferred,
      outputs: draft.map(o => ({ connector: o.connector, identity: o.identity, enabled: o.enabled,
        mode: o.mode, rate: o.rate, scale: o.scale, rotation: o.rotation, x: o.x, y: o.y, primary: o.primary })) }), replaceName)
  }

  property Process reader: Process {
    command: ["python3", service.helper, "snapshot"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const next = JSON.parse(text)
          const topology = JSON.stringify(next.outputs.map(o => o.identity || o.connector).sort())
          if (service.dirty && service.previousTopology && topology !== service.previousTopology)
            service.error = "Connected displays changed. Reload the current layout before applying."
          const ended = service.snapshot.pending && !next.pending
          if (JSON.stringify(service.snapshot.outputs) !== JSON.stringify(next.outputs))
            service.linkDetails = null
          service.snapshot = next
          service.previousTopology = topology
          if (!service.dirty || service.resetAfterRead || ended)
            service.resetDraft(service.preserveProfileAfterRead || (!service.resetAfterRead && !ended))
          service.resetAfterRead = false
          service.preserveProfileAfterRead = false
        } catch (_) {
          if (!service.error) service.error = "Could not read monitor configuration."
        }
      }
    }
    stderr: StdioCollector { onStreamFinished: { if (text.trim()) service.error = text.trim() } }
    onExited: {
      if (service.queuedCommand) {
        service.writer.command = service.queuedCommand
        service.queuedCommand = null
        service.writer.running = true
      }
    }
  }
  property Process writer: Process {
    property string action: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (service.writer.action === "details") {
          try { service.linkDetails = JSON.parse(text) }
          catch (_) { service.error = "Could not read display link details." }
        }
      }
    }
    stderr: StdioCollector { onStreamFinished: { if (text.trim()) service.error = text.trim() } }
    onExited: code => {
      service.busy = false
      if (code === 0 && ["keep", "revert", "delete", "import", "rename"].includes(action))
        service.resetAfterRead = true
      service.preserveProfileAfterRead = code === 0 && action === "keep"
      service.refresh()
    }
  }
  property Timer poll: Timer {
    interval: 2000
    running: service.visible || service.pending
    repeat: true
    onTriggered: service.refresh()
  }
  property Timer countdown: Timer {
    interval: 250
    running: service.pending
    repeat: true
    onTriggered: service.now = Date.now() / 1000
  }
}

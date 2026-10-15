import QtQml
import Quickshell.Io

QtObject {
  id: service

  property bool available: false
  property bool bypass: false
  property bool pending: false
  property string error: ""
  property bool targetBypass: false
  readonly property string description: error || (pending ? "OpenEffects: applying…"
    : !available ? "OpenEffects unavailable"
    : bypass ? "OpenEffects: bypassed — click to enable effects"
    : "OpenEffects: effects active — click to bypass")

  function refresh() {
    if (!query.running && !action.running)
      query.running = true
  }

  function toggle() {
    if (!available || pending || query.running)
      return
    error = ""
    targetBypass = !bypass
    pending = true
    action.command = ["timeout", "--kill-after=1s", "5s", "openeffectsctl", "passthrough", targetBypass ? "--on" : "--off"]
    action.running = true
  }

  Component.onCompleted: refresh()

  // Shared across screens; hover refreshes immediately, while this catches
  // external changes and daemon restarts without frequent background queries.
  property Timer polling: Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: service.refresh()
  }

  property Process query: Process {
    command: ["timeout", "--kill-after=1s", "5s", "openeffectsctl", "passthrough"]
    stdout: StdioCollector { id: output }
    stderr: StdioCollector {}
    onExited: (exitCode) => {
      const state = output.text.trim()
      service.available = exitCode === 0 && (state === "passthrough off (effects active)" || state === "passthrough on (all effects bypassed)")
      if (service.available)
        service.bypass = state === "passthrough on (all effects bypassed)"
      if (service.pending && (!service.available || service.bypass !== service.targetBypass))
        service.error = "OpenEffects: could not confirm effects toggle"
      service.pending = false
    }
  }

  property Process action: Process {
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (exitCode) => {
      if (exitCode !== 0) {
        service.error = "OpenEffects: toggle failed — click to retry"
        service.pending = false
      }
      service.refresh()
    }
  }
}

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  id: service
  readonly property string helper: Quickshell.env("HOME") + "/dotfiles/linux/config/system-settings/usb-storage.py"
  property bool visible: false
  property bool busy: false
  property string error: ""
  property string result: ""
  property var devices: []
  property var fstabMounts: []
  property bool automount: true
  property string pendingPath: ""
  property string pendingAction: ""

  function refresh() {
    if (!reader.running && !writer.running) reader.running = true
  }
  function run(action, path = "") {
    if (busy || writer.running) return
    busy = true
    error = ""
    pendingAction = action
    pendingPath = path
    writer.command = action === "automount"
      ? ["python3", helper, action, automount ? "off" : "on"]
      : ["python3", helper, action, path]
    writer.running = true
  }

  property Process reader: Process {
    command: ["python3", service.helper, "snapshot"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const state = JSON.parse(text)
          service.devices = state.devices
          service.fstabMounts = state.fstabMounts || []
          service.automount = state.automount
        } catch (_) {
          service.error = "Could not read USB storage devices."
        }
      }
    }
    stderr: StdioCollector { onStreamFinished: { if (text.trim()) service.error = text.trim() } }
  }
  property Process writer: Process {
    stdout: StdioCollector { onStreamFinished: service.result = text.trim() }
    stderr: StdioCollector { onStreamFinished: { if (text.trim()) service.error = text.trim() } }
    onExited: code => {
      service.busy = false
      if (code !== 0 && !service.error) service.error = "The USB storage action failed."
      service.refresh()
    }
  }
  property Timer poll: Timer {
    interval: 2500
    running: service.visible
    repeat: true
    onTriggered: service.refresh()
  }
  onVisibleChanged: if (visible) refresh()
}

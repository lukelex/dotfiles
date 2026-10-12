import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: preferences
  readonly property string helper: Quickshell.env("HOME") + "/dotfiles/linux/config/system-settings/settings.py"
  readonly property string path: Quickshell.env("DOTFILES_PREFERENCES") || Quickshell.env("HOME") + "/dotfiles/linux/config/system-settings/preferences.json"
  property var data: ({})
  property var fields: []
  property bool ready: false
  property string error: ""
  property var queue: []
  property bool busy: false

  function value(key, fallback) {
    const parts = key.split(".")
    return data[parts[0]]?.[parts[1]] ?? fallback
  }

  function setValue(key, value) {
    const changes = {}
    changes[key] = value
    setMany(changes)
  }

  function applySection(section) {
    queue.push(["apply", section])
    runNext()
  }

  function setMany(changes) {
    if (!ready || Object.keys(changes).length === 0)
      return
    queue.push(["patch", JSON.stringify(changes)])
    runNext()
  }

  function runNext() {
    if (writer.running || reader.running || queue.length === 0)
      return
    busy = true
    writer.command = ["python3", helper].concat(queue.shift())
    writer.running = true
  }

  function reload() {
    if (!reader.running)
      reader.running = true
  }

  property FileView watcher: FileView {
    path: preferences.path
    watchChanges: true
    onFileChanged: {
      reload()
      preferences.reloadTimer.restart()
    }
  }
  property Timer reloadTimer: Timer {
    interval: 100
    onTriggered: preferences.reload()
  }
  property Process reader: Process {
    command: ["python3", preferences.helper, "describe"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const result = JSON.parse(text)
          const previous = preferences.data
          const initial = !preferences.ready
          preferences.fields = result.fields
          preferences.data = result.data
          preferences.ready = true
          for (const section of ["display", "idle", "input"]) {
            if ((initial && section === "input") || (!initial && JSON.stringify(previous[section]) !== JSON.stringify(result.data[section])))
              preferences.queue.push(["apply", section])
          }
        } catch (_) {
          preferences.error = "Could not load preferences. Check preferences.json and run settings.py validate."
        }
      }
    }
    stderr: StdioCollector { onStreamFinished: { if (text.trim()) preferences.error = text.trim() } }
    onExited: {
      preferences.busy = false
      preferences.runNext()
    }
  }
  property Process writer: Process {
    stderr: StdioCollector { onStreamFinished: { if (text.trim()) preferences.error = text.trim() } }
    onExited: code => {
      preferences.busy = false
      if (code === 0)
        preferences.error = ""
      preferences.reload()
    }
  }
}

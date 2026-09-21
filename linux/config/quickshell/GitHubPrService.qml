pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
  id: service

  property var prs: []
  property bool loading: false
  property string error: ""
  property int _lastRefresh: 0

  readonly property string script: Quickshell.env("HOME") + "/dotfiles/linux/config/quickshell/scripts/github-prs"

  Component.onCompleted: service.refresh(true)

  function refresh(force = false) {
    const now = Date.now()
    if (loading || (!force && now - _lastRefresh < 60000))
      return
    _lastRefresh = now
    loading = true
    process.running = true
  }

  function accept(text) {
    try {
      const value = JSON.parse(text)
      if (!Array.isArray(value))
        throw new Error("Invalid PR data")
      prs = value
      error = ""
    } catch (exception) {
      error = "GitHub PR data unavailable"
    }
    loading = false
  }

  function open(url) {
    browser.command = ["xdg-open", url]
    browser.startDetached()
  }

  property Process browser: Process { command: [] }

  property Process process: Process {
    command: [service.script]
    stdout: StdioCollector {
      onStreamFinished: service.accept(this.text)
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0)
        service.error = "GitHub PR query failed"
      service.loading = false
    }
  }

  property Timer refreshTimer: Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: service.refresh()
  }
}

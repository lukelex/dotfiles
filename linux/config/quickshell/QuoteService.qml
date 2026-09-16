pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
  id: service

  readonly property bool available: _snapshot.available === true && quote !== ""
  readonly property string quote: _snapshot.quote || ""
  readonly property string date: _snapshot.date || ""
  readonly property bool stale: _snapshot.stale !== false
  readonly property string error: _failure || _snapshot.error || ""
  property bool loading: false
  property var _snapshot: ({})
  property string _failure: ""
  property real _lastAttempt: 0
  property real _now: Date.now() / 1000

  function refresh(force = false) {
    const now = Date.now() / 1000
    service._now = now
    if (service.loading || now - service._lastAttempt < 60)
      return
    if (!force && service.available && !service.stale)
      return
    service._lastAttempt = now
    service.loading = true
    service._failure = ""
    service._process.running = true
  }

  function _accept(text) {
    try {
      const data = JSON.parse(text)
      if (!data || typeof data.available !== "boolean"
          || typeof data.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(data.date)
          || typeof data.quote !== "string" || data.quote.length > 1000
          || /[<>\u0000-\u001f\u007f]/.test(data.quote)
          || typeof data.stale !== "boolean" || typeof data.error !== "string")
        throw new Error("Invalid quote snapshot")
      service._snapshot = data
      service._failure = ""
    } catch (_) {
      service._failure = "Quote snapshot unavailable."
    }
    service.loading = false
    service._now = Date.now() / 1000
  }

  readonly property string _quoteScript: Quickshell.env("HOME") + "/dotfiles/linux/scripts/quotes"
  readonly property Process _process: Process {
    command: [service._quoteScript, "snapshot"]
    stdout: StdioCollector {
      onStreamFinished: service._accept(this.text)
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 || exitStatus !== 0) {
        service._failure = "Quote process failed."
        service.loading = false
      }
    }
  }

  readonly property Timer _clock: Timer {
    interval: 1000
    running: service._lastAttempt > 0
    repeat: true
    onTriggered: {
      service._now = Date.now() / 1000
       if (service._snapshot.date !== Qt.formatDate(new Date(), "yyyy-MM-dd"))
        service.refresh()
    }
  }

  readonly property Timer _timeout: Timer {
    interval: 15000
    running: service.loading
    onTriggered: {
      service._process.running = false
      service._failure = "Quote request timed out."
      service.loading = false
    }
  }
}

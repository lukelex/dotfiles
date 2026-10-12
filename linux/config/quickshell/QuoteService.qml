pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
  id: service

  readonly property bool available: quote !== ""
  readonly property string quote: _snapshot.quote || ""
  readonly property string date: _snapshot.date || ""
  readonly property bool stale: available && date !== Qt.formatDate(new Date(_now * 1000), "yyyy-MM-dd")
  readonly property string error: _failure
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
    if (!force && service.available && service._snapshot.date === Qt.formatDate(new Date(now * 1000), "yyyy-MM-dd"))
      return
    service._lastAttempt = now
    service.loading = true
    service._failure = ""
    service._process.running = true
  }

  function _accept(text) {
    try {
      const quote = text.trim()
      if (!quote || quote.length > 1000 || /[<>\u0000-\u001f\u007f]/.test(quote))
        throw new Error("Invalid quote")
      service._snapshot = { quote, date: Qt.formatDate(new Date(Date.now()), "yyyy-MM-dd") }
      service._failure = ""
    } catch (_) {
      service._failure = "Quote snapshot unavailable."
    }
    service.loading = false
    service._now = Date.now() / 1000
  }

  readonly property string _quoteScript: Quickshell.env("HOME") + "/dotfiles/linux/scripts/lock-quote"
  readonly property Process _process: Process {
    command: [service._quoteScript]
    stdout: StdioCollector {
      onStreamFinished: service._accept(this.text)
    }
    onExited: (exitCode, exitStatus) => {
      service._now = Date.now() / 1000
      if (exitCode !== 0 || exitStatus !== 0) {
        service._failure = "Quote unavailable."
        service.loading = false
      }
    }
  }

  function _refreshDelay() {
    const now = service._now * 1000
    const today = new Date(now)
    if (!service.available || service._snapshot.date !== Qt.formatDate(today, "yyyy-MM-dd"))
      return Math.max(1, Math.ceil((service._lastAttempt + 60) * 1000 - now))
    const midnight = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
    return Math.max(1, midnight.getTime() - now)
  }

  // Local midnight (including DST), or the retry deadline after a failed fetch.
  readonly property Timer _clock: Timer {
    interval: service._refreshDelay()
    running: service._lastAttempt > 0 && !service.loading
    repeat: true
    onTriggered: {
      service.refresh()
    }
  }

  readonly property Timer _timeout: Timer {
    interval: 15000
    running: service.loading
    onTriggered: {
      service._process.running = false
      service._now = Date.now() / 1000
      service._failure = "Quote lookup timed out."
      service.loading = false
    }
  }
}

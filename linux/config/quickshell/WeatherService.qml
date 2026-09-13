pragma ComponentBehavior: Bound

import QtQml
import Quickshell.Io

QtObject {
  id: service

  readonly property bool available: _snapshot.available === true
  property bool loading: false
  readonly property int retryAfter: Math.max(0, Math.ceil(60 - (_now - _lastAttempt)))
  readonly property bool stale: _failed || _snapshot.stale !== false
    || _now - Math.min(updatedAt, _snapshot.forecastUpdatedAt || 0, _snapshot.locationUpdatedAt || 0) >= 1200
  readonly property string error: _failure || _snapshot.error || ""
  readonly property real updatedAt: _snapshot.updatedAt || 0
  readonly property string city: _snapshot.city || ""
  readonly property string country: _snapshot.country || ""
  readonly property var temperature: _snapshot.temperature ?? null
  readonly property var feelsLike: _snapshot.feelsLike ?? null
  readonly property string description: _snapshot.description || ""
  readonly property var humidity: _snapshot.humidity ?? null
  readonly property var wind: _snapshot.wind ?? null
  readonly property string conditionIcon: _snapshot.conditionIcon || "cloud-sun"
  readonly property var forecast: _snapshot.forecast || []

  property var _snapshot: ({})
  property bool _failed: false
  property string _failure: ""
  property real _now: Date.now() / 1000
  property real _lastAttempt: 0
  property bool _force: false

  function refresh(force = false) {
    const now = Date.now() / 1000
    service._now = now
    if (service.loading || now - service._lastAttempt < 60)
      return
    if (!force && !service.stale && now - service._lastAttempt < 1200)
      return
    service._lastAttempt = now
    service._force = force
    service.loading = true
    service._process.running = true
  }

  function _accept(text) {
    try {
      const data = JSON.parse(text)
      if (!data || typeof data.available !== "boolean" || typeof data.stale !== "boolean"
          || !Number.isFinite(data.updatedAt) || data.updatedAt < 0 || !Array.isArray(data.forecast)
          || data.forecast.length > 3
          || !data.forecast.every(row => row && typeof row.date === "string"
            && /^\d{4}-\d{2}-\d{2}$/.test(row.date)
            && new Date(row.date + "T00:00:00Z").toISOString().slice(0, 10) === row.date
            && Number.isFinite(row.low) && Number.isFinite(row.high) && row.low <= row.high
            && ["sun", "moon", "cloud-sun", "cloud-moon", "cloud", "cloud-rain",
              "cloud-snow", "cloud-fog", "cloud-lightning", "cloud-drizzle"].includes(row.icon)
            && typeof row.condition === "string" && row.condition.trim().length > 0
            && /^[^<>\u0000-\u001f\u007f]{1,200}$/.test(row.condition))
          || (data.available && (!Number.isFinite(data.temperature) || !Number.isFinite(data.feelsLike))))
        throw new Error("Invalid snapshot")
      service._snapshot = data
      service._failed = false
      service._failure = ""
    } catch (_) {
      service._failed = true
      service._failure = "Weather snapshot unavailable."
    }
    service.loading = false
    service._now = Date.now() / 1000
  }

  readonly property Process _process: Process {
    command: service._force ? ["u_weather", "snapshot", "--refresh"] : ["u_weather", "snapshot"]
    stdout: StdioCollector {
      onStreamFinished: service._accept(this.text)
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 || exitStatus !== 0) {
        service._failed = true
        service._failure = "Weather process failed."
      }
      service.loading = false
    }
  }

  function _tick() {
    service._now = Date.now() / 1000
    const oldest = Math.min(service.updatedAt, service._snapshot.forecastUpdatedAt || 0,
      service._snapshot.locationUpdatedAt || 0)
    if (service._lastAttempt > 0
        && (service._now - oldest >= 1200 || service._now - service._lastAttempt >= 1200))
      service.refresh()
  }

  // Check expiry, not only time since opening: a cache hit may already be nearly 20 minutes old.
  readonly property Timer _refreshTimer: Timer {
    interval: 1000
    running: service._lastAttempt > 0
    repeat: true
    onTriggered: service._tick()
  }

  // Also bounds lock contention and a process that fails to start or finish.
  readonly property Timer _timeout: Timer {
    interval: 75000
    running: service.loading
    onTriggered: {
      service._process.running = false
      service._failed = true
      service._failure = "Weather request timed out."
      service.loading = false
    }
  }
}

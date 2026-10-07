import QtQml
import Quickshell.Io

QtObject {
  id: service

  property bool monitoring: false
  property bool installed: false
  property string state: "unknown"
  property string location: ""
  property string country: ""
  property string error: ""
  property string statusError: ""
  property var locations: []
  property string locationsError: ""
  property bool pending: false
  property bool requestedConnected: false
  property string requestedLocation: ""
  property string selectedLocation: ""
  property bool destinationEdited: false
  readonly property var locationOptions: {
    const values = [""].concat(service.locations)
    if (service.selectedLocation && values.indexOf(service.selectedLocation) < 0)
      values.push(service.selectedLocation)
    return values.map(value => ({ value: value, label: value ? value.replace(/_/g, " ") : "Recommended" }))
  }
  property int generation: 0
  readonly property bool connected: state === "connected"
  readonly property bool busy: pending || action.running || state === "connecting" || state === "disconnecting"
  readonly property bool statusKnown: state !== "unknown"
  readonly property string statusText: !installed ? "Not installed"
    : pending ? (requestedConnected ? "Connecting…" : "Disconnecting…")
    : state === "connected" ? "Connected / " + (location || "Location unavailable")
    : state === "disconnected" ? "Disconnected"
    : state === "connecting" ? "Connecting…"
    : state === "disconnecting" ? "Disconnecting…" : "Status unavailable"

  onMonitoringChanged: {
    if (monitoring) {
      service.refresh()
      service.refreshLocations()
    }
  }

  function clean(text) {
    return text.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "").replace(/\r/g, "").trim()
  }

  function failureMessage(text, exitCode) {
    const message = service.clean(text)
    if (exitCode === 124 || exitCode === 137)
      return "NordVPN timed out. Check its daemon and try again."
    if (/log.?in|authenticat|logged (in|out)/i.test(message))
      return "NordVPN authentication is required. Run nordvpn login."
    if (/permission|access denied|not permitted/i.test(message))
      return "NordVPN permission denied. Check access to its daemon."
    if (/daemon|socket|service.*(unavailable|not running)/i.test(message))
      return "NordVPN daemon is unavailable. Check the nordvpnd service."
    return message.slice(0, 300) || "NordVPN request failed. Try again."
  }

  function refresh() {
    if (!service.installed || status.running)
      return
    status.generation = service.generation
    status.running = true
  }

  function refreshLocations() {
    if (service.installed && !service.locations.length && !countries.running)
      countries.running = true
  }

  function selectLocation(location) {
    if (service.busy)
      return
    service.selectedLocation = location
    service.destinationEdited = true
  }

  function applyStatus(text, exitCode, requestGeneration) {
    if (requestGeneration !== service.generation)
      return
    const output = service.clean(text)
    const match = output.match(/^Status:\s*(Connected|Disconnected|Connecting|Disconnecting)\s*$/im)
    if (exitCode !== 0 || !match) {
      service.state = "unknown"
      service.location = ""
      service.country = ""
      service.statusError = service.failureMessage(output, exitCode)
      return
    }
    service.state = match[1].toLowerCase()
    service.statusError = ""
    const country = output.match(/^Country:\s*(.+)$/im)
    const city = output.match(/^City:\s*(.+)$/im)
    service.country = service.connected && country ? country[1].trim() : ""
    service.location = service.country + (service.country && city ? " / " + city[1].trim() : "")
    if (service.pending && !action.running
        && service.connected === service.requestedConnected
        && (service.state === "connected" || service.state === "disconnected")
        && (!service.requestedConnected || !service.requestedLocation
          || service.country.toLowerCase().replace(/_/g, " ") === service.requestedLocation.toLowerCase().replace(/_/g, " "))) {
      service.pending = false
      service.destinationEdited = false
      confirmationTimeout.stop()
    }
    if (!service.pending && !service.destinationEdited && service.connected)
      service.selectedLocation = service.country.replace(/\s+/g, "_")
  }

  function toggle() {
    if (service.connected)
      service.startRequest(false, "")
    else
      service.connectLocation(service.selectedLocation)
  }

  function connectLocation(location) {
    service.startRequest(true, location)
  }

  function startRequest(connect, location) {
    if (!service.installed || service.busy || !service.statusKnown)
      return
    service.error = ""
    service.generation++
    service.requestedConnected = connect
    service.requestedLocation = location
    service.pending = true
    action.command = ["env", "LC_ALL=C", "timeout", "--kill-after=2s", "45s", "nordvpn", connect ? "connect" : "disconnect"]
      .concat(connect && location ? [location] : [])
    confirmationTimeout.restart()
    action.running = true
  }

  function finishAction(exitCode, output) {
    // Discard status requests begun before the command completed.
    service.generation++
    if (exitCode !== 0) {
      service.pending = false
      service.error = service.failureMessage(output, exitCode)
      confirmationTimeout.stop()
    }
    service.refresh()
  }

  function expireRequest() {
    service.pending = false
    service.error = "NordVPN did not confirm the requested connection. Refresh status before retrying."
    service.state = "unknown"
    service.refresh()
  }

  readonly property Process _probe: Process {
    command: ["sh", "-c", "command -v nordvpn >/dev/null 2>&1"]
    running: true
    onExited: exitCode => {
      service.installed = exitCode === 0
      service.refresh()
      if (service.monitoring)
        service.refreshLocations()
    }
  }

  readonly property Process _status: Process {
    id: status
    property int generation: 0
    command: ["env", "LC_ALL=C", "timeout", "--kill-after=2s", "10s", "nordvpn", "status"]
    stdout: StdioCollector { id: statusOutput }
    stderr: StdioCollector { id: statusErrors }
    onExited: exitCode => {
      service.applyStatus(statusOutput.text + "\n" + statusErrors.text, exitCode, generation)
      if (generation !== service.generation)
        Qt.callLater(service.refresh)
    }
  }

  readonly property Process _action: Process {
    id: action
    stdout: StdioCollector { id: actionOutput }
    stderr: StdioCollector { id: actionErrors }
    onExited: exitCode => service.finishAction(exitCode, actionOutput.text + "\n" + actionErrors.text)
  }

  readonly property Timer _confirmationTimeout: Timer {
    id: confirmationTimeout
    interval: 60000
    onTriggered: service.expireRequest()
  }

  readonly property Timer _poll: Timer {
    interval: service.pending ? 2000 : 10000
    repeat: true
    running: service.installed && (service.monitoring || service.pending)
    onTriggered: service.refresh()
  }

  readonly property Process _countries: Process {
    id: countries
    command: ["env", "LC_ALL=C", "timeout", "--kill-after=2s", "10s", "nordvpn", "countries"]
    stdout: StdioCollector { id: countriesOutput }
    stderr: StdioCollector { id: countriesErrors }
    onExited: exitCode => {
      if (exitCode !== 0) {
        service.locationsError = service.failureMessage(countriesOutput.text + "\n" + countriesErrors.text, exitCode)
        return
      }
      service.locations = service.clean(countriesOutput.text).split("\n").map(location => location.trim())
        .filter(location => /^[A-Za-z][A-Za-z _-]*$/.test(location) && location !== "Available countries")
        .map(location => location.replace(/\s+/g, "_"))
      service.locationsError = service.locations.length ? "" : "No VPN locations were returned."
    }
  }
}

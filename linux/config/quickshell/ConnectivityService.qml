pragma ComponentBehavior: Bound

import QtQml
import QtQml.Models
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

QtObject {
  id: service

  readonly property bool wifiAvailable: Networking.backend === NetworkBackendType.NetworkManager && service._wifiDevices.length > 0
  readonly property bool wifiEnabled: Networking.wifiEnabled
  readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
  property bool wifiScanningEnabled: true
  property bool trafficMonitoringEnabled: false
  property real downloadSpeed: -1
  property real uploadSpeed: -1
  property var _deviceSpeeds: ({})
  property var _trafficSample: null
  readonly property string _trafficInterfaces: service._wifiDevices.concat(service._wiredDevices)
    .filter(device => device.connected).map(device => device.name).sort().join(",")

  onTrafficMonitoringEnabledChanged: service.resetTraffic()
  on_TrafficInterfacesChanged: service.resetTraffic()

  readonly property FileView _trafficFile: FileView {
    path: service.trafficMonitoringEnabled && service._trafficInterfaces ? "/proc/net/dev" : ""
    onLoaded: service.sampleTraffic(service._trafficFile.text(), Date.now())
    onLoadFailed: service.resetTraffic()
  }

  readonly property Timer _trafficTimer: Timer {
    interval: 1000
    repeat: true
    running: service.trafficMonitoringEnabled && service._trafficInterfaces !== ""
    onTriggered: service._trafficFile.reload()
  }

  function resetTraffic(): void {
    service._trafficSample = null
    service.downloadSpeed = -1
    service.uploadSpeed = -1
    service._deviceSpeeds = ({})
  }

  function sampleTraffic(text: string, now: real): void {
    if (!service.trafficMonitoringEnabled || !service._trafficInterfaces)
      return
    const interfaces = service._trafficInterfaces.split(",")
    const counters = {}
    for (const line of text.split("\n")) {
      const colon = line.indexOf(":")
      if (colon < 0)
        continue
      const name = line.slice(0, colon).trim()
      if (interfaces.indexOf(name) < 0)
        continue
      const fields = line.slice(colon + 1).trim().split(/\s+/)
      const rx = Number(fields[0])
      const tx = Number(fields[8])
      if (fields.length >= 16 && Number.isFinite(rx) && Number.isFinite(tx) && rx >= 0 && tx >= 0)
        counters[name] = { rx: rx, tx: tx }
    }
    if (interfaces.some(name => !counters[name])) {
      service.resetTraffic()
      return
    }
    const previous = service._trafficSample
    service._trafficSample = { time: now, counters: counters }
    const seconds = previous ? (now - previous.time) / 1000 : 0
    if (seconds <= 0 || interfaces.some(name => !previous.counters[name]
        || counters[name].rx < previous.counters[name].rx || counters[name].tx < previous.counters[name].tx)) {
      service.downloadSpeed = -1
      service.uploadSpeed = -1
      service._deviceSpeeds = ({})
      return
    }
    service.downloadSpeed = interfaces.reduce((sum, name) => sum + counters[name].rx - previous.counters[name].rx, 0) / seconds
    service.uploadSpeed = interfaces.reduce((sum, name) => sum + counters[name].tx - previous.counters[name].tx, 0) / seconds
    const speeds = {}
    for (const name of interfaces) {
      speeds[name] = {
        download: (counters[name].rx - previous.counters[name].rx) / seconds,
        upload: (counters[name].tx - previous.counters[name].tx) / seconds
      }
    }
    service._deviceSpeeds = speeds
  }

  function connectionSpeed(wired: bool, direction: string): real {
    const devices = (wired ? service._wiredDevices : service._wifiDevices).filter(device => device.connected)
    if (!devices.length || devices.some(device => !service._deviceSpeeds[device.name]))
      return -1
    return devices.reduce((sum, device) => sum + service._deviceSpeeds[device.name][direction], 0)
  }

  function formatSpeed(bytesPerSecond: real): string {
    if (!Number.isFinite(bytesPerSecond) || bytesPerSecond < 0)
      return "—"
    const units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
    let unit = 0
    while (bytesPerSecond >= 1024 && unit < units.length - 1) {
      bytesPerSecond /= 1024
      unit++
    }
    return bytesPerSecond.toFixed(unit === 0 ? 0 : 1) + " " + units[unit]
  }
  readonly property bool wifiConnected: service.activeNetwork !== null
  readonly property string wifiSsid: service.activeNetwork ? service.activeNetwork.name : ""
  readonly property bool ethernetAvailable: service._wiredDevices.length > 0
  readonly property bool ethernetConnected: service._wiredDevices.some(device => device.connected)
  readonly property string ethernetName: service.activeEthernetNetwork ? service.activeEthernetNetwork.name : ""
  readonly property string ethernetError: service._state.ethernetError
  // Native signalStrength and BluetoothDevice.battery are fractions, not percentages.
  readonly property real wifiStrength: service.activeNetwork ? service.activeNetwork.signalStrength : 0
  readonly property WifiNetwork activeNetwork: service._networks.find(network => network.connected) || null
  readonly property WifiNetwork connectingNetwork: service._state.pending
    ? service._state.requestedNetwork
    : service._networks.find(network => network.state === ConnectionState.Connecting) || null
  readonly property bool wifiConnecting: service.connectingNetwork !== null
  readonly property string wifiError: service._state.wifiError
  readonly property int wifiErrorReason: service._state.wifiErrorReason

  // No native availability flag: zero strength also includes out-of-range saved networks.
  readonly property var savedNetworks: service._networks.filter(network => network.known
    && (network.signalStrength > 0 || network.connected || network.stateChanging))

  readonly property bool bluetoothAvailable: Bluetooth.adapters.values.length > 0
  readonly property bool bluetoothEnabled: Bluetooth.adapters.values.some(adapter => adapter.enabled)
  readonly property bool bluetoothBlocked: Bluetooth.adapters.values.some(adapter => adapter.state === BluetoothAdapterState.Blocked)
  readonly property bool bluetoothChanging: Bluetooth.adapters.values.some(adapter =>
    adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
  readonly property bool bluetoothConnecting: Bluetooth.devices.values.some(device => device.state === BluetoothDeviceState.Connecting)
  readonly property string bluetoothError: service._state.bluetoothError
  // Keep native objects so name, state, batteryAvailable and battery remain live bindings.
  readonly property var connectedBluetoothDevices: Bluetooth.devices.values.filter(device => device.connected)
    .sort((a, b) => a.name.localeCompare(b.name) || a.dbusPath.localeCompare(b.dbusPath))

  readonly property var _wifiDevices: Networking.devices.values.filter(device => device.type === DeviceType.Wifi)
  readonly property var _wiredDevices: Networking.devices.values.filter(device => device.type === DeviceType.Wired)
  readonly property var _wiredNetworks: {
    const networks = []
    for (const device of service._wiredDevices) {
      for (const network of device.networks.values)
        networks.push(network)
    }
    return networks
  }
  readonly property Network activeEthernetNetwork: service._wiredNetworks.find(network => network.connected) || null
  readonly property var _networks: {
    const networks = []
    for (const device of service._wifiDevices) {
      for (const network of device.networks.values)
        networks.push(network)
    }
    return networks.sort((a, b) => Number(b.connected) - Number(a.connected)
      || a.name.localeCompare(b.name) || a.device.name.localeCompare(b.device.name))
  }

  readonly property var _state: QtObject {
    property WifiNetwork requestedNetwork: null
    property bool pending: false
    property bool sawConnecting: false
    property string wifiError: ""
    property int wifiErrorReason: -1
    property string ethernetError: ""
    property string bluetoothError: ""
  }

  readonly property Instantiator _scanners: Instantiator {
    model: service._wifiDevices
    delegate: Binding {
      required property var modelData
      target: modelData
      property: "scannerEnabled"
      value: service.wifiEnabled && service.wifiScanningEnabled
      restoreMode: Binding.RestoreBindingOrValue
    }
  }

  readonly property Connections _connectionEvents: Connections {
    target: service._state.requestedNetwork

    function onConnectionFailed(reason) {
      service._state.wifiErrorReason = reason
      service._finishConnection(ConnectionFailReason.toString(reason))
    }

    function onStateChanged() {
      const network = service._state.requestedNetwork
      if (!network || !service._state.pending)
        return
      if (network.state === ConnectionState.Connecting)
        service._state.sawConnecting = true
      else if (network.state === ConnectionState.Connected)
        service._finishConnection("")
      else if (service._state.sawConnecting && network.state === ConnectionState.Disconnected)
        service._finishConnection("Wi-Fi connection ended before it was established.")
    }
  }

  // ActivateConnection D-Bus errors are not all forwarded as connectionFailed in 0.3.1.
  readonly property Timer _connectionTimeout: Timer {
    interval: 45000
    onTriggered: service._finishConnection("Wi-Fi connection timed out; check NetworkManager permissions and saved credentials.")
  }

  on_NetworksChanged: {
    if (service._state.pending && service._networks.indexOf(service._state.requestedNetwork) < 0)
      service._finishConnection("The Wi-Fi network or adapter disappeared.")
  }

  onWifiEnabledChanged: {
    if (!service.wifiEnabled && service._state.pending)
      service._finishConnection("Wi-Fi was disabled.")
  }

  function setWifiEnabled(enabled: bool): bool {
    service._state.wifiError = ""
    service._state.wifiErrorReason = -1
    if (!service.wifiAvailable || (enabled && !service.wifiHardwareEnabled)) {
      service._state.wifiError = service.wifiAvailable ? "Wi-Fi is hardware blocked." : "No NetworkManager Wi-Fi adapter is available."
      return false
    }
    Networking.wifiEnabled = enabled
    return true
  }

  function setEthernetEnabled(enabled: bool): bool {
    service._state.ethernetError = ""
    if (!service.ethernetAvailable) {
      service._state.ethernetError = "No Ethernet adapter is available."
      return false
    }
    for (const device of service._wiredDevices)
      device.autoconnect = enabled
    if (!enabled) {
      for (const device of service._wiredDevices) {
        if (device.connected || device.state === ConnectionState.Connecting)
          device.disconnect()
      }
      return true
    }
    const network = service._wiredNetworks.find(network => network.known) || service._wiredNetworks[0]
    if (!network) {
      service._state.ethernetError = "No Ethernet connection is available."
      return false
    }
    try {
      if (!network.connected && network.state !== ConnectionState.Connecting)
        network.connect()
    } catch (error) {
      service._state.ethernetError = String(error)
      return false
    }
    return true
  }

  function setBluetoothEnabled(enabled: bool): bool {
    service._state.bluetoothError = ""
    if (!service.bluetoothAvailable) {
      service._state.bluetoothError = "No Bluetooth adapter is available."
      return false
    }
    let accepted = true
    for (const adapter of Bluetooth.adapters.values) {
      if (enabled && adapter.state === BluetoothAdapterState.Blocked) {
        service._state.bluetoothError = "A Bluetooth adapter is blocked."
        accepted = false
      } else {
        adapter.enabled = enabled
      }
    }
    return accepted
  }

  function connectNetwork(network: WifiNetwork): bool {
    if (service._state.pending)
      return false
    service._state.wifiError = ""
    service._state.wifiErrorReason = -1
    if (!service.wifiAvailable || !service.wifiEnabled || !service.wifiHardwareEnabled) {
      service._state.wifiError = "Wi-Fi is unavailable, disabled or hardware blocked."
      return false
    }
    if (!network || service.savedNetworks.indexOf(network) < 0 || !network.known) {
      service._state.wifiError = "The saved Wi-Fi network is no longer available."
      return false
    }
    if (network.connected)
      return true
    service._state.requestedNetwork = network
    service._state.sawConnecting = network.state === ConnectionState.Connecting
    service._state.pending = true
    service._connectionTimeout.restart()
    try {
      // NM connect() activates the active/last-successful saved profile, not a new PSK profile.
      if (!service._state.sawConnecting)
        network.connect()
    } catch (error) {
      service._finishConnection(String(error))
      return false
    }
    return true
  }

  function clearErrors(): void {
    service._state.wifiError = ""
    service._state.wifiErrorReason = -1
    service._state.ethernetError = ""
    service._state.bluetoothError = ""
  }

  function _finishConnection(error: string): void {
    service._connectionTimeout.stop()
    service._state.pending = false
    service._state.wifiError = error
  }
}

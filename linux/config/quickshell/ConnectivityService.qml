pragma ComponentBehavior: Bound

import QtQml
import QtQml.Models
import Quickshell.Networking
import Quickshell.Bluetooth

QtObject {
  id: service

  readonly property bool wifiAvailable: Networking.backend === NetworkBackendType.NetworkManager && service._wifiDevices.length > 0
  readonly property bool wifiEnabled: Networking.wifiEnabled
  readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
  property bool wifiScanningEnabled: true
  readonly property bool wifiConnected: service.activeNetwork !== null
  readonly property string wifiSsid: service.activeNetwork ? service.activeNetwork.name : ""
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
    service._state.bluetoothError = ""
  }

  function _finishConnection(error: string): void {
    service._connectionTimeout.stop()
    service._state.pending = false
    service._state.wifiError = error
  }
}

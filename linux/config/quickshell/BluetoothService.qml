pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQml
import QtQml.Models

QtObject {
  id: service
  required property var preferences
  readonly property bool bluetoothAvailable: Bluetooth.adapters.values.length > 0
  readonly property bool bluetoothEnabled: Bluetooth.adapters.values.some(adapter => adapter.enabled)
  readonly property bool bluetoothBlocked: Bluetooth.adapters.values.some(adapter => adapter.state === BluetoothAdapterState.Blocked)
  readonly property bool bluetoothChanging: Bluetooth.adapters.values.some(adapter =>
    adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
  readonly property bool bluetoothConnecting: Bluetooth.devices.values.some(device => device.state === BluetoothDeviceState.Connecting)
  property string bluetoothError: ""
  // Keep native objects so name, state, batteryAvailable and battery remain live bindings.
  readonly property var connectedBluetoothDevices: Bluetooth.devices.values.filter(device => device.connected)
    .sort((a, b) => a.name.localeCompare(b.name) || a.dbusPath.localeCompare(b.dbusPath))

  // Observe every native device, including connections made while the panel is closed.
  // Use the native model to avoid rebuilding watchers on device list changes.
  property var _bluetoothBatteryWarnings: ({})
  readonly property Instantiator _bluetoothBatteryWatchers: Instantiator {
    model: Bluetooth.devices
    delegate: QtObject {
      id: watcher
      required property var modelData
      readonly property Connections events: Connections {
        target: watcher.modelData
        function onConnectedChanged() { service.checkBluetoothBattery(watcher.modelData) }
        function onBatteryAvailableChanged() { service.checkBluetoothBattery(watcher.modelData) }
        function onBatteryChanged() { service.checkBluetoothBattery(watcher.modelData) }
      }
      Component.onCompleted: service.checkBluetoothBattery(modelData)
    }
  }

  readonly property bool bluetoothBatteryAlertsEnabled: preferences ? preferences.value("connectivity.bluetoothBatteryAlerts", true) : true
  readonly property real bluetoothBatteryThreshold: preferences ? preferences.value("connectivity.bluetoothBatteryThreshold", 15) / 100 : 0.15
  readonly property string bluetoothBatteryPolicy: String(bluetoothBatteryAlertsEnabled) + ":" + bluetoothBatteryThreshold
  onBluetoothBatteryPolicyChanged: service._bluetoothPolicyTimer.restart()
  readonly property Timer _bluetoothPolicyTimer: Timer {
    interval: 0
    onTriggered: {
      for (const device of Bluetooth.devices.values)
        service.checkBluetoothBattery(device)
    }
  }

  function checkBluetoothBattery(device): void {
    if (!device)
      return
    const key = device.dbusPath
    if (!device.connected) {
      delete service._bluetoothBatteryWarnings[key]
      return
    }
    if (!device.batteryAvailable || !Number.isFinite(device.battery)
        || device.battery < 0 || device.battery > 1)
      return
    if (device.battery > service.bluetoothBatteryThreshold) {
      delete service._bluetoothBatteryWarnings[key]
      return
    }
    if (!service.bluetoothBatteryAlertsEnabled || service._bluetoothBatteryWarnings[key] === device)
      return
    service._bluetoothBatteryWarnings[key] = device
    const name = (device.name || "Bluetooth device").replace(/&/g, "&amp;")
      .replace(/</g, "&lt;").replace(/>/g, "&gt;")
    Quickshell.execDetached(["notify-send", "-a", "Bluetooth", "-u", "critical",
      "-i", Quickshell.env("HOME") + "/dotfiles/linux/config/lucide/svg/battery-low.svg",
      "--", "Bluetooth battery low", name + " has " + Math.round(device.battery * 100) + "% battery remaining."])
  }

  function setBluetoothEnabled(enabled: bool): bool {
    service.bluetoothError = ""
    if (!service.bluetoothAvailable) {
      service.bluetoothError = "No Bluetooth adapter is available."
      return false
    }
    let accepted = true
    for (const adapter of Bluetooth.adapters.values) {
      if (enabled && adapter.state === BluetoothAdapterState.Blocked) {
        service.bluetoothError = "A Bluetooth adapter is blocked."
        accepted = false
      } else {
        adapter.enabled = enabled
      }
    }
    return accepted
  }
}

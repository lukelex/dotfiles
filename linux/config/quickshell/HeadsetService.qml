import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQml
import QtQml.Models

QtObject {
  id: service

  property var usbDevices: []
  property var devices: []
  readonly property var bluetoothDevices: Bluetooth.devices.values
  readonly property var powerDevices: UPower.devices.values

  // BlueZ identifies the device type; don't mistake other battery-powered
  // Bluetooth devices (mice, keyboards, speakers) for headphones.
  function bluetoothHeadphones(devices) {
    return devices.filter(device => device && device.connected
      && ["audio-headset", "audio-headphones"].includes(device.icon)
      && device.batteryAvailable && Number.isFinite(device.battery)
      && device.battery >= 0 && device.battery <= 1)
      .map(device => ({
        name: device.name || "Bluetooth headphones",
        percentage: Math.round(device.battery * 100),
        charging: false
      }))
  }

  function powerHeadphones(devices) {
    return devices.filter(device => device && device.ready && device.isPresent
      && (device.type === UPowerDeviceType.Headset || device.type === UPowerDeviceType.Headphones)
      && Number.isFinite(device.percentage) && device.percentage >= 0 && device.percentage <= 1)
      .map(device => ({
        name: device.model || "Wireless headphones",
        percentage: Math.round(device.percentage * 100),
        charging: device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge
      }))
  }

  function mergeDevices(usb, power, bluetooth) {
    // Prefer dongle and UPower readings when a device is reported by multiple
    // backends; both can report charging, unlike BlueZ's battery percentage.
    const result = usb.slice()
    for (const source of [power, bluetooth]) {
      const existing = result.length
      const matched = new Set()
      for (const device of source) {
        const duplicate = result.findIndex((other, index) => index < existing
          && !matched.has(index) && other.name === device.name)
        if (duplicate === -1)
          result.push(device)
        else
          matched.add(duplicate)
      }
    }
    return result
  }

  function updateDevices() {
    service.devices = service.mergeDevices(service.usbDevices,
      service.powerHeadphones(service.powerDevices), service.bluetoothHeadphones(service.bluetoothDevices))
  }

  onBluetoothDevicesChanged: updateDevices()
  onPowerDevicesChanged: updateDevices()

  property Instantiator bluetoothWatchers: Instantiator {
    model: Bluetooth.devices.values
    delegate: QtObject {
      id: watcher
      required property var modelData
      readonly property Connections events: Connections {
        target: watcher.modelData
        function onConnectedChanged() { service.updateDevices() }
        function onIconChanged() { service.updateDevices() }
        function onNameChanged() { service.updateDevices() }
        function onBatteryAvailableChanged() { service.updateDevices() }
        function onBatteryChanged() { service.updateDevices() }
      }
      Component.onCompleted: service.updateDevices()
    }
  }

  property Instantiator powerWatchers: Instantiator {
    model: UPower.devices.values
    delegate: QtObject {
      id: powerWatcher
      required property var modelData
      readonly property Connections events: Connections {
        target: powerWatcher.modelData
        function onReadyChanged() { service.updateDevices() }
        function onIsPresentChanged() { service.updateDevices() }
        function onTypeChanged() { service.updateDevices() }
        function onModelChanged() { service.updateDevices() }
        function onPercentageChanged() { service.updateDevices() }
        function onStateChanged() { service.updateDevices() }
      }
      Component.onCompleted: service.updateDevices()
    }
  }

  // HeadsetControl's USB battery protocol is separate from Bluetooth/UPower.
  // Levels are percentages; charging can be reported without a known level.
  function parseDevices(text) {
    try {
      const payload = JSON.parse(text)
      if (!payload || !Array.isArray(payload.devices))
        return []
      return payload.devices.filter(device => {
        const battery = device && device.battery
        return typeof device?.device === "string" && device.device.length > 0
          && battery && (battery.status === "BATTERY_AVAILABLE" || battery.status === "BATTERY_CHARGING")
          && Number.isInteger(battery.level)
          && ((battery.level >= 0 && battery.level <= 100)
            || (battery.status === "BATTERY_CHARGING" && battery.level === -1))
      }).map(device => ({
        name: device.device,
        percentage: device.battery.level === -1 ? null : device.battery.level,
        charging: device.battery.status === "BATTERY_CHARGING"
      }))
    } catch (_) {
      return []
    }
  }

  function refresh() {
    if (!query.running)
      query.running = true
  }

  Component.onCompleted: refresh()

  // One bounded query per minute, shared by every screen. Never retain a
  // previous percentage after a failed query or disconnected receiver.
  property Timer polling: Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: service.refresh()
  }

  property Process query: Process {
    command: ["timeout", "--kill-after=1s", "5s", "headsetcontrol", "-b", "-o", "json"]
    stdout: StdioCollector { id: output }
    stderr: StdioCollector {}
    onExited: (exitCode) => {
      service.usbDevices = exitCode === 0 ? service.parseDevices(output.text) : []
      service.updateDevices()
    }
  }
}

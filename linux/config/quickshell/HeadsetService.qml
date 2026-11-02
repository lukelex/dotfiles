import Quickshell.Io
import QtQml

QtObject {
  id: service

  property var devices: []

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
      service.devices = exitCode === 0 ? service.parseDevices(output.text) : []
    }
  }
}

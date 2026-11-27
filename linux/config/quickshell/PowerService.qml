pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Scope {
  id: root
  required property string quickshellScripts
  required property var notificationService
  property string batteryState: ""
  property int batteryPercentage: 0
  property string batteryTime: ""
  property bool batteryAvailable: false
  property real batteryHealth: 0
  property bool batteryHealthAvailable: false
  property real batteryWatts: 0
  property bool batteryRateAvailable: false
  property bool batteryWarningPending: false
  property var previousOnBattery: null
  property bool powerProfileAvailable: false
  property bool nativePowerProfilesAvailable: false
  property string powerProfile: ""
  property string powerProfileDegradation: ""
  function batteryStateName(state) {
    switch (state) {
    case UPowerDeviceState.Charging: return "charging"
    case UPowerDeviceState.Discharging: return "discharging"
    case UPowerDeviceState.PendingCharge: return "pending-charge"
    case UPowerDeviceState.PendingDischarge: return "pending-discharge"
    case UPowerDeviceState.FullyCharged: return "fully-charged"
    default: return "unknown"
    }
  }

  function formatBatteryTime(seconds) {
    if (!(seconds > 0))
      return ""

    const minutes = Math.ceil(seconds / 60)
    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60
    return hours ? hours + " hr" + (remainingMinutes ? " " + remainingMinutes + " min" : "") : minutes + " min"
  }

  function updateBatteryStatus() {
    const device = UPower.displayDevice
    if (!device.ready || !device.isPresent) {
      root.batteryAvailable = false
      root.batteryHealthAvailable = false
      root.batteryRateAvailable = false
      return
    }

    root.batteryPercentage = Math.round(device.percentage * 100)
    root.batteryState = root.batteryStateName(device.state)
    // changeRate is in watts; direction is labelled from the device state.
    root.batteryWatts = Math.abs(device.changeRate)
    root.batteryRateAvailable = Number.isFinite(root.batteryWatts) && root.batteryWatts > 0
    root.batteryHealthAvailable = device.healthSupported
    root.batteryHealth = device.healthPercentage
    root.batteryTime = root.formatBatteryTime(root.batteryState === "discharging"
      ? device.timeToEmpty : root.batteryState === "charging" ? device.timeToFull : 0)
    root.batteryAvailable = true
  }

  function checkBatteryWarnings() {
    if (!root.batteryAvailable || root.batteryState !== "discharging") {
      root.batteryWarningPending = false
      return
    }

    if (batteryWarnings.running)
      root.batteryWarningPending = true
    else
      batteryWarnings.running = true
  }

  function powerProfileName(profile) {
    switch (profile) {
    case PowerProfile.PowerSaver: return "power-saver"
    case PowerProfile.Balanced: return "balanced"
    case PowerProfile.Performance: return "performance"
    default: return "balanced"
    }
  }

  function syncPowerProfile() {
    if (!root.nativePowerProfilesAvailable)
      return

    root.powerProfile = root.powerProfileName(PowerProfiles.profile)
    root.powerProfileDegradation = PowerProfiles.degradationReason === PerformanceDegradationReason.HighTemperature
      ? "Performance reduced due to high temperature"
      : PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected
        ? "Performance reduced by lap detection" : ""
  }

  function cyclePowerProfile() {
    if (!root.powerProfileAvailable)
      return

    if (root.nativePowerProfilesAvailable) {
      const profiles = PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]
      const currentIndex = profiles.indexOf(PowerProfiles.profile)
      PowerProfiles.profile = profiles[(currentIndex + 1 + profiles.length) % profiles.length]
      return
    }

    powerProfileNext.running = true
  }

  Process {
    id: powerProfileNext
    command: ["u_performance-profile", "next"]
    onExited: fallbackProfileStatus.running = true
  }

  Process {
    id: fallbackProfileStatus
    command: ["sh", "-c", "printf '%s\\n' \"$(u_performance-profile if 2>/dev/null)\" \"$(u_performance-profile get 2>/dev/null)\""]
    running: !root.nativePowerProfilesAvailable
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.trim().split("\n")
        if (!root.nativePowerProfilesAvailable) {
          root.powerProfileAvailable = output[0] === "true"
          root.powerProfile = output[1] || ""
        }
      }
    }
  }

  Process {
    id: batteryWarnings
    command: [root.quickshellScripts + "/battery", "warn"]
    onExited: {
      if (root.batteryWarningPending) {
        root.batteryWarningPending = false
        batteryWarnings.running = true
      }
    }
  }

  Process {
    id: nativePowerProfilesCheck
    command: ["sh", "-c", "busctl --system --no-pager list 2>/dev/null | grep -q '^org\\.freedesktop\\.UPower\\.PowerProfiles[[:space:]]' && printf true || printf false"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        root.nativePowerProfilesAvailable = this.text.trim() === "true"
        root.powerProfileAvailable = root.powerProfileAvailable || root.nativePowerProfilesAvailable
        root.syncPowerProfile()
      }
    }
  }

  Connections {
    target: PowerProfiles
    function onProfileChanged() { root.syncPowerProfile() }
    function onDegradationReasonChanged() { root.syncPowerProfile() }
  }

  Process {
    id: powerNotification
  }

  function updatePowerSource() {
    root.updateBatteryStatus()
    if (!root.batteryAvailable)
      return

    const onBattery = UPower.onBattery
    if (root.previousOnBattery !== null && root.previousOnBattery !== onBattery) {
      if (!onBattery) {
        root.notificationService?.dismissTag("battery-low")
        root.notificationService?.dismissTag("battery-critical")
      }
      powerNotification.command = [root.quickshellScripts + "/battery", "power",
        onBattery ? "unplugged" : "plugged", String(root.batteryPercentage), root.batteryState]
      powerNotification.running = true
      batteryWarnings.running = true
    }
    root.previousOnBattery = onBattery
  }

  Component.onCompleted: {
    root.updatePowerSource()
    root.checkBatteryWarnings()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() { root.updatePowerSource() }
  }

  Connections {
    target: UPower.displayDevice
    function onReadyChanged() { root.updatePowerSource(); root.checkBatteryWarnings() }
    function onPercentageChanged() { root.updateBatteryStatus(); root.checkBatteryWarnings() }
    function onStateChanged() { root.updateBatteryStatus(); root.checkBatteryWarnings() }
    function onTimeToEmptyChanged() { root.updateBatteryStatus() }
    function onTimeToFullChanged() { root.updateBatteryStatus() }
    function onChangeRateChanged() { root.updateBatteryStatus() }
    function onIsPresentChanged() { root.updateBatteryStatus() }
    function onHealthPercentageChanged() { root.updateBatteryStatus() }
    function onHealthSupportedChanged() { root.updateBatteryStatus() }
  }

  Timer {
    interval: 5000
    running: !root.nativePowerProfilesAvailable
    repeat: true
    onTriggered: fallbackProfileStatus.running = true
  }
}

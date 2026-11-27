pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtCore
import QtQuick
import "DesignTokens.js" as Design
import QtQuick.Controls as Controls

Scope {
  id: root

  OptionalModule {
    id: wmLoader
    module: root.hyprlandSession ? "HyprlandAdapter.qml" : "I3Adapter.qml"
    initialProperties: () => ({ controller: root })
  }
  readonly property var wm: wmLoader.item

  required property var notificationService
  required property var audioService
  required property var headsetService
  required property var webcamService
  required property var openEffectsService
  readonly property bool notificationCenterOpen: notificationCenterTarget !== null && notificationCenterTarget.visible
  readonly property bool controlCenterVisible: Object.values(root.panelsByScreen).some(panel => panel?.controlCenter?.visible)
  onControlCenterVisibleChanged: {
    if (!controlCenterVisible)
      previousCpuTotal = -1
  }
  property var notificationCenterTarget: null
  property var todayCenterTarget: null
  property var connectivityTarget: null
  property var bluetoothTarget: null
  property var audioOutputTarget: null
  readonly property var systemSettings: settingsLoader.item
  readonly property bool wifiSettingsOpen: root.systemSettings?.wifiDiscoveryActive ?? false
  property var panelsByScreen: ({})
  readonly property bool resizeMode: root.wm?.resizeMode ?? false

  OptionalModule {
    id: weatherLoader
    module: "WeatherService.qml"
    initialProperties: () => ({
      preferences: root.preferences,
      panelVisible: Qt.binding(() => root.todayCenterTarget !== null && root.todayCenterTarget.visible)
    })
  }
  OptionalModule { id: quoteLoader; module: "QuoteService.qml" }

  function closeDateTime() {
    if (root.todayCenterTarget)
      root.todayCenterTarget.requestClose()
  }

  readonly property var connectivity: networkLoader.item
  readonly property var bluetooth: bluetoothLoader.item
  OptionalModule {
    id: networkLoader
    module: "ConnectivityService.qml"
    initialProperties: () => ({
      preferences: root.preferences,
      wifiScanningEnabled: Qt.binding(() => root.connectivityTarget !== null && root.connectivityTarget.visible),
      wifiDiscoveryEnabled: Qt.binding(() => root.wifiSettingsOpen),
      trafficMonitoringEnabled: Qt.binding(() => root.connectivityTarget !== null && root.connectivityTarget.visible)
    })
  }
  OptionalModule {
    id: bluetoothLoader
    module: "BluetoothService.qml"
    initialProperties: () => ({ preferences: root.preferences })
  }

  function closeBluetooth() {
    if (root.bluetoothTarget)
      root.bluetoothTarget.requestClose()
  }

  function closeConnectivity(includeBluetooth = true) {
    if (root.connectivityTarget)
      root.connectivityTarget.requestClose()
    if (includeBluetooth)
      root.closeBluetooth()
  }

  function closeAudioOutput() {
    if (root.audioOutputTarget)
      root.audioOutputTarget.requestClose()
  }

  function focusedPanel() {
    const monitorName = root.wm?.focusedMonitorName
    const panel = monitorName ? root.panelsByScreen[monitorName] : null
    if (panel) return panel
    const screens = Quickshell.screens
    const primary = screens.find(screen => screen.x === 0 && screen.y === 0)
    return (primary && root.panelsByScreen[primary.name]) || root.panelsByScreen[screens[0]?.name] || null
  }

  function openCalendarFromKeyboard() {
    const panel = root.focusedPanel()
    if (panel)
      panel.openDateTime(true)
  }

  function openConnectivityFromKeyboard() {
    const panel = root.focusedPanel()
    if (panel)
      panel.openConnectivity(true)
  }

  function openAudioOutputFromKeyboard() {
    const panel = root.focusedPanel()
    if (panel)
      panel.openAudioOutput(true)
  }

  function toggleDoNotDisturbFromKeyboard() {
    root.toggleDoNotDisturb()
  }

  readonly property var designPalette: Design.palette(root.darkMode)
  readonly property var barMetrics: Design.barMetrics(preferences.value("desktop.density", "comfortable") === "compact")
  readonly property color foreground: designPalette.foreground
  readonly property color urgent: designPalette.urgent
  readonly property color muted: designPalette.muted
  required property var preferences
  readonly property string fontFamily: Design.typography.family
  readonly property int barFontSize: barMetrics.fontSize
  readonly property string quickshellScripts: Quickshell.env("HOME") + "/dotfiles/linux/config/quickshell/scripts"
  readonly property bool hyprlandSession: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
  readonly property var workspaceNumbers: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  readonly property int focusedWorkspaceNumber: root.wm?.focusedWorkspaceNumber ?? 0
  readonly property string currentLayoutName: root.wm?.currentLayoutName ?? ""
  readonly property string layoutIconName: root.layoutIconFor(root.currentLayoutName)
  property bool layoutOsdArmed: false
  property string lastLayoutOsdLayout: ""
  property int workspaceTransition: 0

  readonly property var defaultAudioSink: root.audioService?.defaultAudioSink ?? null
  readonly property bool audioAvailable: !!root.audioService?.monitoringAvailable && !!root.defaultAudioSink
    && root.defaultAudioSink.ready && !!root.defaultAudioSink.audio
  readonly property real audioVolume: root.audioAvailable ? root.defaultAudioSink.audio.volume * 100 : 0
  readonly property bool audioMuted: root.audioAvailable && root.defaultAudioSink.audio.muted
  readonly property var defaultMicrophone: root.audioService?.defaultMicrophone ?? null
  readonly property bool microphoneAvailable: !!root.audioService?.monitoringAvailable && !!root.defaultMicrophone
    && root.defaultMicrophone.ready && !!root.defaultMicrophone.audio
  readonly property real microphoneVolume: root.microphoneAvailable ? root.defaultMicrophone.audio.volume * 100 : 0
  readonly property bool microphoneMuted: root.microphoneAvailable && root.defaultMicrophone.audio.muted
  property int pendingAudioVolume: -1
  property int pendingMicrophoneVolume: -1
  property var pendingAudioNode: null
  property var pendingMicrophoneNode: null
  property var audioFeedbackNode: null
  property var microphoneFeedbackNode: null
  property int audioFeedbackVolume: -1
  property int microphoneFeedbackVolume: -1
  property int audioFeedbackMute: -1
  property int microphoneFeedbackMute: -1
  property string audioControlError: ""

  onDefaultAudioSinkChanged: root.cancelAudioAdjustment()
  onAudioAvailableChanged: { if (!root.audioAvailable) root.cancelAudioAdjustment() }
  onDefaultMicrophoneChanged: root.cancelAudioAdjustment(true)
  onMicrophoneAvailableChanged: { if (!root.microphoneAvailable) root.cancelAudioAdjustment(true) }

  function cancelAudioAdjustment(microphone = false) {
    if (microphone) {
      root.pendingMicrophoneVolume = -1
      root.pendingMicrophoneNode = null
      root.microphoneFeedbackNode = null
      root.microphoneFeedbackVolume = -1
      root.microphoneFeedbackMute = -1
      microphoneApplyTimer.stop()
      microphoneFeedbackTimeout.stop()
    } else {
      root.pendingAudioVolume = -1
      root.pendingAudioNode = null
      root.audioFeedbackNode = null
      root.audioFeedbackVolume = -1
      root.audioFeedbackMute = -1
      audioApplyTimer.stop()
      audioFeedbackTimeout.stop()
    }
  }

  function applyAudioVolume() {
    if (root.pendingAudioVolume < 0)
      return
    const node = root.pendingAudioNode
    if (!root.audioAvailable || node !== root.defaultAudioSink) {
      root.cancelAudioAdjustment()
      return
    }
    root.audioFeedbackNode = node
    root.audioFeedbackVolume = root.pendingAudioVolume
    root.pendingAudioVolume = -1
    root.pendingAudioNode = null
    audioFeedbackTimeout.restart()
    node.audio.volume = root.audioFeedbackVolume / 100
    root.confirmAudioAdjustment()
  }

  function applyMicrophoneVolume() {
    if (root.pendingMicrophoneVolume < 0)
      return
    const node = root.pendingMicrophoneNode
    if (!root.microphoneAvailable || node !== root.defaultMicrophone) {
      root.cancelAudioAdjustment(true)
      return
    }
    root.microphoneFeedbackNode = node
    root.microphoneFeedbackVolume = root.pendingMicrophoneVolume
    root.pendingMicrophoneVolume = -1
    root.pendingMicrophoneNode = null
    microphoneFeedbackTimeout.restart()
    node.audio.volume = root.microphoneFeedbackVolume / 100
    root.confirmAudioAdjustment(true)
  }

  function confirmAudioAdjustment(microphone = false) {
    const node = microphone ? root.microphoneFeedbackNode : root.audioFeedbackNode
    const current = microphone ? root.defaultMicrophone : root.defaultAudioSink
    const volume = microphone ? root.microphoneFeedbackVolume : root.audioFeedbackVolume
    const mute = microphone ? root.microphoneFeedbackMute : root.audioFeedbackMute
    if (!node || node !== current || !node.ready || !node.audio)
      return
    if (volume >= 0 && Math.abs(node.audio.volume * 100 - volume) > 1)
      return
    if (mute >= 0 && node.audio.muted !== (mute === 1))
      return
    root.audioControlError = ""
    root.notificationService?.showOsd(microphone ? "Microphone" : "Volume",
      node.audio.muted ? 0 : Math.round(node.audio.volume * 100),
      root.icon(microphone ? (node.audio.muted ? "mic-off" : "mic") : root.audioIcon()))
    if (microphone) {
      root.microphoneFeedbackNode = null
      root.microphoneFeedbackVolume = -1
      root.microphoneFeedbackMute = -1
      microphoneFeedbackTimeout.stop()
    } else {
      root.audioFeedbackNode = null
      root.audioFeedbackVolume = -1
      root.audioFeedbackMute = -1
      audioFeedbackTimeout.stop()
    }
  }

  function toggleMicrophone() {
    if (!root.microphoneAvailable)
      return
    const node = root.defaultMicrophone
    root.microphoneFeedbackNode = node
    root.microphoneFeedbackMute = node.audio.muted ? 0 : 1
    microphoneFeedbackTimeout.restart()
    root.audioService.setMicrophoneMuted(root.microphoneFeedbackMute === 1)
    root.confirmAudioAdjustment(true)
  }

  function setMicrophoneVolume(value) {
    if (!root.microphoneAvailable)
      return
    root.pendingMicrophoneVolume = Math.max(0, Math.min(100, Math.round(value)))
    root.pendingMicrophoneNode = root.defaultMicrophone
    if (!microphoneApplyTimer.running)
      microphoneApplyTimer.start()
  }
  OptionalModule {
    id: powerLoader
    module: "PowerService.qml"
    initialProperties: () => ({ quickshellScripts: root.quickshellScripts,
      notificationService: Qt.binding(() => root.notificationService) })
  }
  function cyclePowerProfile() { powerLoader.item?.cyclePowerProfile() }
  readonly property string batteryState: powerLoader.item?.batteryState ?? ""
  readonly property int batteryPercentage: powerLoader.item?.batteryPercentage ?? 0
  readonly property string batteryTime: powerLoader.item?.batteryTime ?? ""
  readonly property bool batteryAvailable: powerLoader.item?.batteryAvailable ?? false
  readonly property real batteryHealth: powerLoader.item?.batteryHealth ?? 0
  readonly property bool batteryHealthAvailable: powerLoader.item?.batteryHealthAvailable ?? false
  readonly property real batteryWatts: powerLoader.item?.batteryWatts ?? 0
  readonly property bool batteryRateAvailable: powerLoader.item?.batteryRateAvailable ?? false
  readonly property bool powerProfileAvailable: powerLoader.item?.powerProfileAvailable ?? false
  readonly property string powerProfile: powerLoader.item?.powerProfile ?? ""
  readonly property string powerProfileDegradation: powerLoader.item?.powerProfileDegradation ?? ""
  property string idleLockStatus: ""
  readonly property bool doNotDisturb: root.notificationService?.doNotDisturb ?? false
  readonly property bool brightnessBusy: brightnessSet.running
  property real brightness: NaN
  property bool darkMode: true
  property bool nightModeEnabled: false
  property bool nightModeAvailable: false
  property bool keepAwake: false
  readonly property var vpnService: vpnLoader.item
  OptionalModule {
    id: vpnLoader
    module: "VpnService.qml"
    initialProperties: () => ({ monitoring: Qt.binding(() => root.connectivityTarget !== null && root.connectivityTarget.visible) })
  }
  property real cpuUsage: NaN
  property int memoryPercentage: 0
  property real memoryUsedGib: 0
  property real memoryTotalGib: 0
  property real loadAverage: NaN
  property bool cpuTemperatureAvailable: false
  property real cpuTemperature: 0
  property bool gpuTemperatureAvailable: false
  property real gpuTemperature: 0
  property real gpuUsage: NaN
  property real previousCpuTotal: -1
  property real previousCpuIdle: -1
  readonly property date currentDate: clock.date

  readonly property color controlActive: designPalette.controlActive
  readonly property color controlActiveIcon: designPalette.controlActiveIcon
  readonly property color controlDownloadIcon: designPalette.controlDownloadIcon
  readonly property color controlUploadIcon: designPalette.controlUploadIcon
  readonly property color controlWarningText: designPalette.controlWarningText
  readonly property color controlBackground: designPalette.controlBackground
  readonly property color controlPrimaryText: designPalette.controlPrimaryText
  readonly property color controlSecondaryText: designPalette.controlSecondaryText
  readonly property color controlSliderFill: designPalette.controlSliderFill
  readonly property color controlSliderTrack: designPalette.controlSliderTrack
  readonly property color controlSurface: designPalette.controlSurface
  readonly property color controlBorder: designPalette.controlBorder
  readonly property color controlSurfaceBorder: designPalette.controlSurfaceBorder
  readonly property color controlHover: designPalette.controlHover

  function icon(name) {
    return "file://" + Quickshell.env("HOME") + "/dotfiles/linux/config/lucide/svg/" + name + ".svg"
  }

  function layoutIconFor(layoutName) {
    switch (layoutName) {
    case "dwindle": return "columns-2"
    case "master": return "layout-panel-left"
    case "monocle": return "maximize"
    case "scrolling": return "gallery-horizontal-end"
    case "splith": return "columns-2"
    case "splitv": return "rows-2"
    case "tabbed": return "layout-panel-top"
    case "stacked": return "layout-list"
    default: return ""
    }
  }

  function layoutDisplayName(layoutName) {
    switch (layoutName) {
    case "dwindle": return "Dwindle"
    case "master": return "Master"
    case "monocle": return "Monocle"
    case "scrolling": return "Scrolling"
    case "splith": return "Split horizontal"
    case "splitv": return "Split vertical"
    case "tabbed": return "Tabbed"
    case "stacked": return "Stacked"
    default: return ""
    }
  }

  function armLayoutOsd(layout) {
    if (!root.layoutOsdArmed && root.layoutIconFor(layout))
      root.layoutOsdArmed = true
  }

  function maybeShowLayoutOsd(layout) {
    const iconName = root.layoutIconFor(layout)
    if (!iconName)
      return
    // The first resolved layout only arms the OSD; shell reloads and startup
    // must not flash it. Repeats of the last shown layout are suppressed even
    // across a transient unknown value.
    if (!root.layoutOsdArmed) {
      root.layoutOsdArmed = true
      return
    }
    if (layout === root.lastLayoutOsdLayout)
      return
    root.lastLayoutOsdLayout = layout
    root.notificationService?.showOsd("Layout", 0, iconName, root.layoutDisplayName(layout))
  }

  function audioIcon() {
    if (root.audioMuted)
      return "volume-x"
    if (root.audioVolume > 50)
      return "volume-2"
    if (root.audioVolume > 0)
      return "volume-1"
    return "volume"
  }

  function batteryIcon() {
    if (root.batteryState === "charging" || root.batteryState === "pending-charge")
      return "battery-charging"
    if (root.batteryPercentage < 15)
      return "battery-warning"
    if (root.batteryPercentage < 40)
      return "battery-low"
    if (root.batteryPercentage < 65)
      return "battery-medium"
    if (root.batteryPercentage < 90)
      return "battery-high"
    return "battery-full"
  }

  function refreshControlStatus() {
    if (!root.controlCenterVisible) return
    brightnessStatus.running = true
    nightStatus.running = true
  }

  function sensorTemperature(sensors, chipPattern) {
    for (const chipName of Object.keys(sensors)) {
      if (!chipPattern.test(chipName))
        continue

      for (const label of Object.keys(sensors[chipName])) {
        const value = Number(sensors[chipName][label]?.temp1_input)
        if (Number.isFinite(value))
          return value
      }
    }

    return null
  }

  function openNotificationCenter() {
    const panel = root.focusedPanel()
    if (panel)
      panel.toggleNotifications()
  }

  function openSystemSettings(targetScreen, section = "") {
    if (!root.systemSettings) return
    root.closeNotifications()
    root.closeConnectivity()
    root.closeAudioOutput()
    root.closeDateTime()
    for (const name of Object.keys(root.panelsByScreen))
      root.panelsByScreen[name]?.closeControlCenter()
    const panel = root.focusedPanel()
    if (!section)
      systemSettings.section = "system"
    else {
      systemSettings.section = section === "wifi" || section === "connectivityPreferences" ? "connectivity" : section
      if (systemSettings.section === "connectivity") {
        systemSettings.connectivityAnchor = section === "connectivityPreferences" ? "preferences" : "networks"
        systemSettings.connectivityAdvanced = false
      }
    }
    systemSettings.open(targetScreen || (panel ? panel.screen : null))
  }

  OptionalModule {
    id: settingsLoader
    module: "SystemSettings.qml"
    initialProperties: () => ({ controller: root, service: Qt.binding(() => root.notificationService),
      connectivity: Qt.binding(() => root.connectivity), bluetooth: Qt.binding(() => root.bluetooth) })
  }

  function closeNotifications() {
    if (root.notificationCenterTarget)
      root.notificationCenterTarget.requestClose()
  }

  function toggleDoNotDisturb() {
    root.notificationService?.setDoNotDisturb(!root.notificationService.doNotDisturb)
  }

  function toggleNightMode() {
    nightModeToggle.running = true
  }

  function toggleAudio() {
    if (!root.audioAvailable)
      return

    const node = root.defaultAudioSink
    root.audioFeedbackNode = node
    root.audioFeedbackMute = node.audio.muted ? 0 : 1
    audioFeedbackTimeout.restart()
    node.audio.muted = root.audioFeedbackMute === 1
    root.confirmAudioAdjustment()
  }

  function setAudioVolume(value) {
    if (!root.audioAvailable)
      return

    root.pendingAudioVolume = Math.max(0, Math.min(100, Math.round(value)))
    root.pendingAudioNode = root.defaultAudioSink
    if (!audioApplyTimer.running)
      audioApplyTimer.start()
  }

  function setBrightness(value) {
    if (root.brightnessBusy || !Number.isFinite(root.brightness))
      return

    brightnessSet.value = Math.round(value)
    brightnessSet.running = true
    root.notificationService?.showOsd("Brightness", value, "sun")
  }

  function lockScreen() {
    lockScreenProcess.startDetached()
  }

  function applyKeepAwake(value) {
    root.keepAwake = value
    if (!root.hyprlandSession && !keepAwakeProcess.running)
      keepAwakeProcess.running = true
  }

  function toggleKeepAwake() {
    if (keepAwakeProcess.running)
      return

    keepAwakeSettings.keepAwake = !root.keepAwake
  }

  function toggleTheme() {
    if (themeToggle.running)
      return
    themeToggle.running = true
  }

  function syncTheme() {
    root.darkMode = themeState.text().trim() !== "light"
  }

  FileView {
    id: themeState
    path: Quickshell.env("HOME") + "/.local/state/dotfiles/color-scheme"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.syncTheme()
  }

  function readPercentage(text) {
    if (!text?.trim()) return NaN
    const value = Number(text)
    return Number.isFinite(value) && value >= 0 && value <= 100 ? value : NaN
  }

  StatusProbe {
    id: brightnessStatus
    probeCommand: [root.quickshellScripts + "/brightness", "get"]
    onSampled: text => root.brightness = root.readPercentage(text)
  }
  StatusProbe {
    id: nightStatus
    probeCommand: ["systemctl", "--user", "show", "gammastep", "--property=LoadState,ActiveState"]
    onSampled: text => {
      const fields = text.trim().split("\n")
      const state = fields.find(field => field.startsWith("ActiveState="))?.slice(12)
      root.nightModeAvailable = fields.includes("LoadState=loaded") && !!state
      root.nightModeEnabled = root.nightModeAvailable && ["active", "activating", "reloading"].includes(state)
    }
  }

  Timer {
    id: audioApplyTimer
    interval: 30
    onTriggered: root.applyAudioVolume()
  }

  Timer {
    id: microphoneApplyTimer
    interval: 30
    onTriggered: root.applyMicrophoneVolume()
  }

  Timer {
    id: audioFeedbackTimeout
    interval: 1500
    onTriggered: {
      root.cancelAudioAdjustment()
      root.audioControlError = "Could not confirm the output adjustment."
    }
  }

  Timer {
    id: microphoneFeedbackTimeout
    interval: 1500
    onTriggered: {
      root.cancelAudioAdjustment(true)
      root.audioControlError = "Could not confirm the microphone adjustment."
    }
  }

  Connections {
    target: root.audioAvailable ? root.defaultAudioSink.audio : null
    function onVolumesChanged() { root.confirmAudioAdjustment() }
    function onMutedChanged() { root.confirmAudioAdjustment() }
  }

  Connections {
    target: root.microphoneAvailable ? root.defaultMicrophone.audio : null
    function onVolumesChanged() { root.confirmAudioAdjustment(true) }
    function onMutedChanged() { root.confirmAudioAdjustment(true) }
  }

  Process {
    id: nightModeToggle
    command: [root.quickshellScripts + "/nightmode", "toggle"]
    onExited: root.refreshControlStatus()
  }

  Process {
    id: brightnessSet
    property int value: 0
    command: [root.quickshellScripts + "/brightness", "set", value.toString()]
    onExited: root.refreshControlStatus()
  }

  Process {
    id: lockScreenProcess
    command: ["u_exit", "lock"]
  }

  Process {
    id: keepAwakeProcess
    command: ["sh", "-c", root.keepAwake
      ? "xautolock -disable; xset s off -dpms"
      : "xautolock -enable; xset s on +dpms; xset dpms " + root.preferences.value("idle.x11ScreenOffSeconds", 1200) + " 0 0"]
  }

  property Settings keepAwakeSettings: Settings {
    id: keepAwakeSettings
    location: "file://" + Quickshell.env("HOME") + "/.local/state/dotfiles/keep-awake.conf"
    property bool keepAwake: false
    onKeepAwakeChanged: root.applyKeepAwake(keepAwakeSettings.keepAwake)
  }

  Process {
    id: themeToggle
    command: ["u_theme", "toggle"]
  }

  Process {
    id: idleLockStatus
    command: ["timeout", "--kill-after=1s", "4s", "u_lock-status", "idle"]
    stdout: StdioCollector {
      onStreamFinished: root.idleLockStatus = this.text.trim()
    }
  }

  Process {
    id: systemStatus
    // Keep a field for every source even when a file disappears between reads.
    command: ["timeout", "--kill-after=1s", "4s", "sh", "-c",
      "cpu=$(awk '/^cpu / { for (i=2;i<=NF;i++) total+=$i; print total, $5+$6; exit }' /proc/stat); "
      + "mem=$(awk '/^MemTotal:/ { t=$2 } /^MemAvailable:/ { a=$2 } END { if (t && a!=\"\") print t,a }' /proc/meminfo); "
      + "load=$(awk '{ print $1 }' /proc/loadavg); gpu=; "
      + "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && { read -r gpu < \"$f\"; break; }; done; "
      + "printf '%s\\n' \"$cpu\" \"$mem\" \"$load\" \"$gpu\""]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.controlCenterVisible) return
        const output = this.text.split("\n")
        const cpu = output[0]?.trim().split(/\s+/).map(Number)
        const memory = output[1]?.trim().split(/\s+/).map(Number)
        const load = output[2]?.trim() ? Number(output[2]) : NaN
        const gpuUsage = root.readPercentage(output[3])
        if (cpu?.length === 2 && cpu.every(Number.isFinite)) {
          if (root.previousCpuTotal >= 0 && cpu[0] > root.previousCpuTotal) {
            const totalDelta = cpu[0] - root.previousCpuTotal
            const idleDelta = Math.max(0, cpu[1] - root.previousCpuIdle)
            root.cpuUsage = Math.round(Math.max(0, Math.min(100, (1 - idleDelta / totalDelta) * 100)))
          }
          root.previousCpuTotal = cpu[0]
          root.previousCpuIdle = cpu[1]
        }

        if (memory?.length === 2 && memory.every(Number.isFinite) && memory[0] > 0
          && memory[1] >= 0 && memory[1] <= memory[0]) {
          const used = Math.max(0, memory[0] - memory[1])
          root.memoryPercentage = Math.round(used / memory[0] * 100)
          root.memoryUsedGib = used / 1048576
          root.memoryTotalGib = memory[0] / 1048576
        }

        if (Number.isFinite(load) && load >= 0)
          root.loadAverage = load

        if (Number.isFinite(gpuUsage))
          root.gpuUsage = Math.round(gpuUsage)
      }
    }
  }

  StatusProbe {
    id: temperatures
    probeCommand: ["sensors", "-j"]
    onSampled: text => {
      let sensors = {}
      try { sensors = JSON.parse(text) || {} } catch (_) {}
      const cpuTemperature = root.sensorTemperature(sensors, /^(k10temp|coretemp|zenpower|cpu_thermal)/i)
      root.cpuTemperatureAvailable = Number.isFinite(cpuTemperature)
      if (root.cpuTemperatureAvailable)
        root.cpuTemperature = cpuTemperature

      const gpuTemperature = root.sensorTemperature(sensors, /^(amdgpu|nouveau|nvidia)/i)
      root.gpuTemperatureAvailable = Number.isFinite(gpuTemperature)
      if (root.gpuTemperatureAvailable)
        root.gpuTemperature = gpuTemperature
    }
  }

  Timer {
    interval: 30000
    running: root.controlCenterVisible
    triggeredOnStart: true
    repeat: true
    onTriggered: idleLockStatus.running = true
  }
  Timer {
    interval: 2000
    running: root.controlCenterVisible
    triggeredOnStart: true
    repeat: true
    onTriggered: {
      systemStatus.running = true
      temperatures.running = true
    }
  }
  Timer {
    interval: 5000
    running: root.controlCenterVisible
    triggeredOnStart: true
    repeat: true
    onTriggered: root.refreshControlStatus()
  }

  IpcHandler {
    target: "notifications"

    function toggleCenter() {
      root.openNotificationCenter()
    }

    function clearVisible() {
      root.notificationService?.clearVisible()
    }
  }

  IpcHandler {
    target: "bar"

    function openCalendar() { root.openCalendarFromKeyboard() }
    function openSettings() { root.openSystemSettings(null) }
    function openConnectivity() { root.openConnectivityFromKeyboard() }
    function openBluetooth() {
      const panel = root.focusedPanel()
      if (panel)
        panel.openBluetooth(true)
    }
    function openAudioOutput() { root.openAudioOutputFromKeyboard() }
    function toggleDoNotDisturb() { root.toggleDoNotDisturbFromKeyboard() }
    function refreshLayout() {
      root.wm?.refreshLayout()
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Variants {
    model: Quickshell.screens

      PanelWindow {
        id: panel

      required property var modelData
      readonly property var notificationCenter: notificationLoader.item
      readonly property var audioOutputCenter: audioLoader.item
      readonly property var controlCenter: controlLoader.item
      readonly property var todayCenter: todayLoader.item

      Timer {
        id: controlHoverTimer
        interval: root.preferences.value("desktop.hoverCloseDelayMs", 600)
        onTriggered: panel.closeControlCenter()
      }
      function requestHoverClose() { controlHoverTimer.restart() }
      function cancelHoverClose() { controlHoverTimer.stop() }
      function closeControlCenter() {
        panel.cancelHoverClose()
        controlCenter?.requestClose()
      }

      function toggleNotifications() {
        if (!notificationCenter) return
        if (notificationCenter.visible && notificationCenter.pinned && !notificationCenter.closePending)
          notificationCenter.requestClose()
        else
          panel.showNotifications(true)
      }

      function showNotifications(pin = false) {
        if (!notificationCenter) return
        panel.cancelHoverClose()
        if (root.notificationCenterTarget !== notificationCenter)
          root.closeNotifications()
        root.notificationCenterTarget = notificationCenter
        root.closeConnectivity()
        root.closeAudioOutput()
        root.closeDateTime()
        controlCenter?.requestClose()
        notificationCenter.requestOpen(pin)
      }

      function openDateTime(pin = false) {
        if (!todayCenter) return
        panel.cancelHoverClose()
        root.closeConnectivity()
        root.closeAudioOutput()
        if (root.todayCenterTarget !== todayCenter)
          root.closeDateTime()
        root.todayCenterTarget = todayCenter
        controlCenter?.requestClose()
        root.closeNotifications()
        todayCenter.requestOpen(pin)
      }

      function openConnectivity(pin = false) {
        panel.cancelHoverClose()
        root.closeBluetooth()
        root.closeAudioOutput()
        if (root.connectivityTarget !== connectivityCenter)
          root.closeConnectivity()
        root.connectivityTarget = connectivityCenter
        controlCenter?.requestClose()
        root.closeNotifications()
        root.closeDateTime()
        connectivityCenter.requestOpen(pin)
      }

      function openBluetooth(pin = false) {
        panel.cancelHoverClose()
        root.closeConnectivity(false)
        root.closeAudioOutput()
        root.closeDateTime()
        root.closeNotifications()
        controlCenter?.requestClose()
        if (root.bluetoothTarget !== bluetoothCenter)
          root.closeBluetooth()
        root.bluetoothTarget = bluetoothCenter
        bluetoothCenter.requestOpen(pin)
      }

      function openControlCenter() {
        if (!controlCenter) return
        root.closeConnectivity()
        root.closeDateTime()
        root.closeAudioOutput()
        root.closeNotifications()
        controlCenter.requestOpen()
        panel.cancelHoverClose()
      }

      function openAudioOutput(pin = false) {
        if (!audioOutputCenter) return
        panel.cancelHoverClose()
        root.closeConnectivity()
        root.closeDateTime()
        controlCenter?.requestClose()
        root.closeNotifications()
        if (root.audioOutputTarget !== audioOutputCenter)
          root.closeAudioOutput()
        root.audioOutputTarget = audioOutputCenter
        audioOutputCenter.requestOpen(pin)
      }

      ConnectivityCenter {
        id: connectivityCenter
        controller: root
        panel: panel
        service: root.connectivity
      }

      ConnectivityCenter {
        id: bluetoothCenter
        bluetoothOnly: true
        controller: root
        panel: panel
        service: root.bluetooth
      }

      OptionalModule {
        id: audioLoader
        active: !!root.audioService
        module: "AudioOutputCenter.qml"
        initialProperties: () => ({ controller: root, panel, service: Qt.binding(() => root.audioService), trigger: volumeWidget })
      }

      OptionalModule {
        active: root.hyprlandSession
        module: "WaylandIdleInhibitor.qml"
        initialProperties: () => ({ window: panel, enabled: Qt.binding(() => root.keepAwake) })
      }

      screen: modelData
      color: "transparent"
      implicitHeight: root.barMetrics.height
      focusable: false
      aboveWindows: true

        anchors {
          left: true
          right: true
          top: true
        }

      OptionalModule {
        id: controlLoader
        module: "ControlCenter.qml"
        initialProperties: () => ({ controller: root, panel })
      }

      OptionalModule {
        id: notificationLoader
        active: !!root.notificationService
        module: "NotificationCenter.qml"
        initialProperties: () => ({ controller: root, panel, service: Qt.binding(() => root.notificationService) })
      }

      OptionalModule {
        active: !!root.notificationService
        module: "NotificationPopup.qml"
        initialProperties: () => ({ controller: root, panel, service: Qt.binding(() => root.notificationService) })
      }

      OptionalModule {
        active: !!root.notificationService
        module: "SystemOsd.qml"
        initialProperties: () => ({ controller: root, panel, service: Qt.binding(() => root.notificationService) })
      }

      OptionalModule {
        id: todayLoader
        module: "TodayCenter.qml"
        initialProperties: () => ({
          controller: root, panel,
          weather: Qt.binding(() => weatherLoader.item), quote: Qt.binding(() => quoteLoader.item)
        })
      }

      property string registeredScreen: ""
      Component.onCompleted: {
        registeredScreen = modelData.name
        root.panelsByScreen = Object.assign({}, root.panelsByScreen, { [registeredScreen]: panel })
      }
      Component.onDestruction: {
        if (root.panelsByScreen[registeredScreen] === panel) {
          const remaining = Object.assign({}, root.panelsByScreen)
          delete remaining[registeredScreen]
          root.panelsByScreen = remaining
        }
      }

      Row {
        id: leftWidgets

        anchors {
          left: parent.left
          leftMargin: 12
          verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Item {
          height: 26
          width: 26

          LucideIcon {
            anchors.centerIn: parent
            color: root.foreground
            height: root.barFontSize
            source: root.layoutIconName.length > 0 ? root.icon(root.layoutIconName) : ""
            visible: root.layoutIconName.length > 0
            width: root.barFontSize

            Accessible.role: Accessible.Indicator
            Accessible.name: root.layoutIconName.length > 0 ? "Layout " + root.currentLayoutName : "Layout unknown"
          }
        }

        Repeater {
          model: panel.width < 620 ? [root.focusedWorkspaceNumber] : root.workspaceNumbers

          delegate: Item {
            id: workspaceItem

            required property int modelData

            readonly property int workspaceNumber: modelData
            readonly property var workspace: root.wm?.workspaceFor(workspaceNumber) ?? null
            readonly property bool selected: !!workspace && workspace.focused
            readonly property bool occupied: !!workspace && root.wm.isOccupied(workspace)

            height: 26
            width: 24
            Canvas {
              id: marker

              anchors.centerIn: parent
              height: 20
              width: 24

              property real mouthAngle: 0.42
              property real ghostOffsetY: 0
              property real ghostScaleX: 1
              property real ghostScaleY: 1
              property bool active: workspaceItem.selected
              property bool full: workspaceItem.occupied
              property bool urgent: !!workspaceItem.workspace && workspaceItem.workspace.urgent
              property bool ready: false
              property int transitionTick: root.workspaceTransition

              Component.onCompleted: ready = true
              onActiveChanged: {
                if (marker.active && marker.ready) {
                  biteAnimation.restart()
                  root.workspaceTransition++
                }
                else if (!marker.active) {
                  biteAnimation.stop()
                  marker.mouthAngle = 0.42
                }
                requestPaint()
              }
              onFullChanged: {
                if (!marker.full) {
                  ghostAnimation.stop()
                  marker.ghostOffsetY = 0
                  marker.ghostScaleX = 1
                  marker.ghostScaleY = 1
                }
                requestPaint()
              }
              onUrgentChanged: requestPaint()
              onMouthAngleChanged: requestPaint()
              onGhostOffsetYChanged: requestPaint()
              onGhostScaleXChanged: requestPaint()
              onGhostScaleYChanged: requestPaint()
              onTransitionTickChanged: {
                if (marker.ready && marker.full && !marker.active)
                  ghostAnimation.restart()
              }
              onPaint: {
                const context = getContext("2d")
                const centerX = width / 2
                const centerY = height / 2
                const ghost = marker.full && !marker.active

                context.clearRect(0, 0, width, height)
                context.fillStyle = marker.urgent ? root.urgent : root.foreground

                if (ghost) {
                  context.save()
                  context.translate(centerX, centerY + marker.ghostOffsetY)
                  context.scale(marker.ghostScaleX, marker.ghostScaleY)
                  context.translate(-centerX, -centerY)

                  context.beginPath()
                  context.moveTo(4, 18)
                  context.lineTo(4, 10)
                  context.arc(centerX, centerY, 8, Math.PI, 0)
                  context.lineTo(20, 18)
                  context.lineTo(17.3, 15)
                  context.lineTo(14.7, 18)
                  context.lineTo(12, 15)
                  context.lineTo(9.3, 18)
                  context.lineTo(6.7, 15)
                  context.closePath()
                  context.lineWidth = 2
                  context.strokeStyle = marker.urgent ? root.urgent : root.foreground
                  context.stroke()

                  context.fillStyle = root.foreground
                  context.beginPath()
                  context.arc(centerX - 3, centerY - 1, 2, 0, Math.PI * 2)
                  context.arc(centerX + 3, centerY - 1, 2, 0, Math.PI * 2)
                  context.fill()
                  context.restore()
                }

                if (marker.active) {
                  context.beginPath()
                  context.moveTo(centerX, centerY)
                  context.arc(centerX, centerY, 8, marker.mouthAngle, Math.PI * 2 - marker.mouthAngle)
                  context.closePath()
                  context.lineWidth = 2
                  context.strokeStyle = marker.urgent ? root.urgent : root.foreground
                  context.stroke()

                  context.fillStyle = root.foreground
                  context.beginPath()
                  context.arc(centerX - 2, centerY - 3, 1, 0, Math.PI * 2)
                  context.fill()
                } else if (!marker.full) {
                  context.fillStyle = marker.urgent ? root.urgent : root.foreground
                  context.beginPath()
                  context.arc(centerX, centerY, 3, 0, Math.PI * 2)
                  context.fill()
                }
              }

              SequentialAnimation {
                id: biteAnimation

                NumberAnimation { target: marker; property: "mouthAngle"; to: 0.12; duration: 70 }
                NumberAnimation { target: marker; property: "mouthAngle"; to: 0.42; duration: 70 }
                NumberAnimation { target: marker; property: "mouthAngle"; to: 0.12; duration: 70 }
                NumberAnimation { target: marker; property: "mouthAngle"; to: 0.42; duration: 70 }
              }

              SequentialAnimation {
                id: ghostAnimation

                ParallelAnimation {
                  NumberAnimation { target: marker; property: "ghostOffsetY"; to: -2; duration: 70; easing.type: Easing.OutQuad }
                  NumberAnimation { target: marker; property: "ghostScaleX"; to: 1.06; duration: 70; easing.type: Easing.OutQuad }
                  NumberAnimation { target: marker; property: "ghostScaleY"; to: 0.94; duration: 70; easing.type: Easing.OutQuad }
                }
                ParallelAnimation {
                  NumberAnimation { target: marker; property: "ghostOffsetY"; to: 0; duration: 120; easing.type: Easing.InOutSine }
                  NumberAnimation { target: marker; property: "ghostScaleX"; to: 1; duration: 120; easing.type: Easing.OutQuad }
                  NumberAnimation { target: marker; property: "ghostScaleY"; to: 1; duration: 120; easing.type: Easing.OutQuad }
                }
              }
            }

            MouseArea {
              id: workspaceMouse

              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              Accessible.role: Accessible.Button
              Accessible.name: "Workspace " + workspaceItem.workspaceNumber
              Accessible.onPressAction: root.wm?.activateWorkspace(workspaceItem.workspaceNumber, workspaceItem.workspace)
              hoverEnabled: true
              onClicked: root.wm?.activateWorkspace(workspaceItem.workspaceNumber, workspaceItem.workspace)
            }
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          color: root.controlActive
          height: 24
          radius: 8
          visible: root.resizeMode
          width: visible ? resizeModeContent.width + 14 : 0

          Row {
            id: resizeModeContent

            anchors.centerIn: parent
            spacing: 5

            LucideIcon {
              anchors.verticalCenter: parent.verticalCenter
              color: root.controlActiveIcon
              height: 14
              source: root.icon("scan-line")
              width: 14
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              color: root.controlPrimaryText
              font.family: root.fontFamily
              font.pixelSize: 11
              text: "Resize"
            }
          }

          Accessible.name: "Window manager resize mode"
          Accessible.role: Accessible.Indicator
        }
      }

      Item {
        id: centerWidgets

        anchors {
          horizontalCenter: parent.horizontalCenter
          verticalCenter: parent.verticalCenter
        }
        width: Math.max(0, 2 * Math.min(
          panel.width / 2 - leftWidgets.x - leftWidgets.width - 8,
          rightWidgets.x - panel.width / 2 - 8))
        height: parent.height
        visible: width >= 200

        Row {
          id: centerContent

          anchors.centerIn: parent
          width: timeItem.width + dateItem.width + spacing
          spacing: 16

          Item {
            id: timeItem

            height: timeContent.height
            width: Math.min(root.barFontSize + timeContent.spacing + timeText.implicitWidth,
              Math.max(0, (centerWidgets.width - centerContent.spacing) / 2))
            clip: true

            Row {
              id: timeContent

              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 6

              LucideIcon {
                height: root.barFontSize
                source: root.icon("clock")
                width: root.barFontSize
                color: root.foreground
              }

              Text {
                id: timeText

                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.barFontSize
                text: Qt.formatTime(clock.date, root.preferences.value("clock.hourFormat", "24") === "12" ? "h:mm AP" : "HH:mm")
                width: Math.max(0, timeItem.width - root.barFontSize - timeContent.spacing)
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              anchors.margins: -4
              Accessible.role: Accessible.Button
              Accessible.name: "Open calendar and weather"
              Accessible.onPressAction: panel.openDateTime(true)
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onEntered: { if (root.preferences.value("desktop.hoverPreviews", true)) panel.openDateTime() }
              onExited: panel.todayCenter?.scheduleClose()
              onClicked: panel.openDateTime(true)
            }
          }

          Item {
            id: dateItem

            height: dateContent.height
            width: Math.min(root.barFontSize + dateContent.spacing + dateText.implicitWidth,
              Math.max(0, (centerWidgets.width - centerContent.spacing) / 2))
            clip: true

            Row {
              id: dateContent

              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 6

              LucideIcon {
                height: root.barFontSize
                source: root.icon("calendar")
                width: root.barFontSize
                color: root.foreground
              }

              Text {
                id: dateText

                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.barFontSize
                text: Qt.formatDate(clock.date, root.preferences.value("clock.dateFormat", "dd MMM - dddd"))
                width: Math.max(0, dateItem.width - root.barFontSize - dateContent.spacing)
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              Accessible.role: Accessible.Button
              Accessible.name: "Open calendar and weather"
              Accessible.onPressAction: panel.openDateTime(true)
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onEntered: { if (root.preferences.value("desktop.hoverPreviews", true)) panel.openDateTime() }
              onExited: panel.todayCenter?.scheduleClose()
              onClicked: panel.openDateTime(true)
            }
          }
        }
      }

      Row {
        id: rightWidgets

        anchors {
          right: parent.right
          rightMargin: panel.width < 900 ? 12 : 28
          verticalCenter: parent.verticalCenter
        }
        spacing: panel.width < 900 ? 8 : 12

        LucideIcon {
          readonly property string missing: [!root.audioService?.monitoringAvailable ? "microphone" : "",
            !root.webcamService?.monitoringAvailable ? "webcam" : ""].filter(Boolean).join(" and ")
          visible: missing !== ""
          width: root.barFontSize
          height: root.barFontSize
          source: root.icon("info")
          color: root.controlWarningText
          Accessible.role: Accessible.StatusBar
          Accessible.name: "Privacy monitoring unavailable: " + missing
          HoverHandler { id: privacyHover }
          Controls.ToolTip.visible: privacyHover.hovered
          Controls.ToolTip.text: Accessible.name
        }

        Item {
          height: root.barFontSize
          width: root.barFontSize
          visible: root.audioService?.microphoneInUse ?? false
          Accessible.role: Accessible.Button
          Accessible.name: "Microphone in use by " + (root.audioService?.recordingApplications ?? []).map(application => application.name).join(", ")
            + ((root.audioService?.recordingMicrophonesMuted ?? false) ? "; inputs muted" : "")
          LucideIcon {
            anchors.fill: parent
            source: root.icon((root.audioService?.recordingMicrophonesMuted ?? false) ? "mic-off" : "mic")
            color: (root.audioService?.recordingMicrophonesMuted ?? false) ? root.muted : root.controlActiveIcon
          }
          MouseArea {
            id: microphoneHover
            anchors.fill: parent
            anchors.margins: -4
            Accessible.role: Accessible.Button
            Accessible.name: parent.Accessible.name
            Accessible.onPressAction: panel.openAudioOutput(true)
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: panel.openAudioOutput(true)
          }
          PrivacyHint {
            controller: root
            panel: panel
            trigger: microphoneHover
            title: "Microphone"
            iconName: (root.audioService?.recordingMicrophonesMuted ?? false) ? "mic-off" : "mic"
            applications: Array.from(new Set((root.audioService?.recordingApplications ?? []).map(application => application.name)))
            applicationDetails: {
              const details = Object.create(null)
              for (const application of root.audioService?.recordingApplications ?? []) {
                const device = application.inputDescription || application.inputName || "Unknown microphone"
                const label = device + (application.muted ? " · Muted" : "")
                details[application.name] = details[application.name]
                  ? details[application.name] + "\n" + label : label
              }
              return details
            }
            muted: (root.audioService?.recordingMicrophonesMuted ?? false)
          }
        }

        LucideIcon {
          height: root.barFontSize
          width: root.barFontSize
          visible: root.webcamService?.inUse ?? false
          source: root.icon("webcam")
          color: root.controlActiveIcon
          Accessible.role: Accessible.StatusBar
          Accessible.name: "Webcam in use by " + (root.webcamService?.recordingApplications ?? []).join(", ")
          MouseArea {
            id: webcamHover
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
          }
          PrivacyHint {
            controller: root
            panel: panel
            trigger: webcamHover
            title: "Webcam"
            iconName: "webcam"
            applications: root.webcamService?.recordingApplications ?? []
            applicationDetails: root.webcamService?.applicationDevices ?? ({})
          }
        }

        OptionalModule {
          module: "OpenEffectsButton.qml"
          active: !!root.openEffectsService
          visible: item?.available ?? false
          initialProperties: () => ({ controller: root, service: Qt.binding(() => root.openEffectsService) })
        }

        Item {
          height: root.barFontSize
          width: root.barFontSize
          LucideIcon {
            anchors.fill: parent
            source: root.icon(!root.connectivity ? "info" : !connectivity.wifiConnected && connectivity.ethernetConnected ? "ethernet-port"
              : !connectivity.wifiEnabled ? "wifi-off"
              : !connectivity.wifiConnected ? "wifi-zero"
              : connectivity.wifiStrength < 0.35 ? "wifi-low"
              : connectivity.wifiStrength < 0.7 ? "wifi-high" : "wifi")
            color: connectivity && (connectivity.wifiConnected || connectivity.ethernetConnected) ? root.foreground : root.muted
          }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            Accessible.role: Accessible.Button
            Accessible.name: "Network connections"
            Accessible.onPressAction: panel.openConnectivity(true)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { if (root.preferences.value("desktop.hoverPreviews", true)) panel.openConnectivity() }
            onExited: connectivityCenter.scheduleClose()
            onClicked: panel.openConnectivity(true)
          }
        }

        Item {
          height: root.barFontSize
          width: root.barFontSize
          LucideIcon {
            anchors.fill: parent
            source: root.icon(!root.bluetooth ? "info" : root.bluetooth.bluetoothEnabled ? "bluetooth" : "bluetooth-off")
            color: !root.bluetooth ? root.muted : root.bluetooth.connectedBluetoothDevices.some(device => device.batteryAvailable && device.battery <= 0.15)
              ? root.urgent : root.bluetooth.connectedBluetoothDevices.length > 0 ? root.foreground : root.muted
          }
          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            Accessible.role: Accessible.Button
            Accessible.name: "Bluetooth"
            Accessible.onPressAction: panel.openBluetooth(true)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { if (root.preferences.value("desktop.hoverPreviews", true)) panel.openBluetooth() }
            onExited: bluetoothCenter.scheduleClose()
            onClicked: panel.openBluetooth(true)
          }
        }

        LucideIcon {
          height: root.barFontSize
          width: root.barFontSize
          visible: root.batteryAvailable && panel.width >= 840
          color: root.batteryAvailable && root.batteryPercentage < 15 ? root.urgent : root.batteryAvailable ? root.foreground : root.muted
          source: root.icon(root.batteryIcon())

          Accessible.role: Accessible.StatusBar
          Accessible.name: "Battery " + root.batteryPercentage + "%"
            + (root.batteryTime ? ", " + root.batteryTime
              + (root.batteryState === "charging" ? " until full" : root.batteryState === "discharging" ? " remaining" : "") : "")
        }
        OptionalModule {
          module: "HeadphoneBatteryModule.qml"
          initialProperties: () => ({
            controller: root,
            devices: Qt.binding(() => root.headsetService?.devices ?? [])
          })
        }

        Item {
          id: volumeWidget

          height: root.barFontSize
          width: root.barFontSize
          Accessible.role: Accessible.Button
          Accessible.name: "Select sound devices"

          LucideIcon {
            anchors.fill: parent
            source: root.icon(root.audioIcon())
            color: root.audioAvailable && !root.audioMuted ? root.foreground : root.muted
          }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            Accessible.role: Accessible.Button
            Accessible.name: "Select sound devices"
            Accessible.onPressAction: panel.openAudioOutput(true)
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: { if (root.preferences.value("desktop.hoverPreviews", true)) panel.openAudioOutput() }
            onExited: panel.audioOutputCenter?.scheduleClose()
            onClicked: panel.openAudioOutput(true)
          }
        }

        Item {
          height: root.barFontSize
          width: root.barFontSize

          visible: !!root.notificationService
          LucideIcon {
            anchors.fill: parent
            source: root.icon(root.doNotDisturb ? "bell-off" : "bell")
            color: root.doNotDisturb ? root.controlActiveIcon : root.foreground
          }

          Rectangle {
            anchors {
              right: parent.right
              top: parent.top
            }
            border.color: root.controlSurfaceBorder
            border.width: 1
            color: root.urgent
            height: 6
            radius: 3
            visible: (root.notificationService?.popup.length ?? 0) > 0
            width: 6
            z: 1
          }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            Accessible.role: Accessible.Button
            Accessible.name: "Notifications"
              + ((root.notificationService?.popup.length ?? 0) > 0 ? "; active notifications" : "; no active notifications")
              + (root.doNotDisturb ? "; Do Not Disturb on" : "; Do Not Disturb off")
            Accessible.onPressAction: root.toggleDoNotDisturb()
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
              panel.showNotifications()
            }
            onExited: panel.notificationCenter?.requestHoverClose()
            onClicked: root.toggleDoNotDisturb()
          }
        }

        LucideIcon {
          height: root.barFontSize
          visible: !!panel.controlCenter
          source: root.icon("sliders")
          width: root.barFontSize
          color: root.foreground

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            Accessible.role: Accessible.Button
            Accessible.name: "Control Center"
            Accessible.onPressAction: panel.openControlCenter()
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: { if (root.preferences.value("desktop.hoverPreviews", true)) panel.openControlCenter() }
            onExited: panel.requestHoverClose()
            onClicked: panel.openControlCenter()
          }
        }
      }
    }
  }
}

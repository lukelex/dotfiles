pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtCore
import QtQuick

Scope {
  id: root

  Connections {
    target: I3
    function onConnected() {
      if (!root.hyprlandSession)
        I3.refreshWorkspaces()
      root.refreshI3Layout()
    }
    function onRawEvent(event) {
      if (root.hyprlandSession || !event)
        return
      // i3 emits workspace events on focus changes; layout toggles do not, so
      // the binding pokes the bar through refreshLayout.
      if (event.type === "workspace")
        root.refreshI3Layout()
    }
  }

  // I3.rawEvent only receives workspace/output events; mode needs its own subscription.
  I3IpcListener {
    subscriptions: root.hyprlandSession ? [] : ["mode"]
    onIpcEvent: event => root.handleI3ModeEvent(event)
  }

  function handleI3ModeEvent(event) {
    if (root.hyprlandSession)
      return
    if (event.type === "subscribe") {
      // Query only after subscribing; newer mode events take precedence over the result.
      if (!i3BindingState.running) {
        i3BindingState.revision = root.resizeModeRevision
        i3BindingState.running = true
      }
    } else if (event.type === "mode") {
      try {
        const mode = JSON.parse(event.data).change
        if (typeof mode === "string") {
          root.resizeModeRevision++
          root.resizeMode = mode === "resize"
        }
      } catch (error) {
        console.warn("Invalid i3 mode event:", error)
      }
    }
  }

  function applyI3BindingState(data, revision) {
    if (root.hyprlandSession || revision !== root.resizeModeRevision)
      return
    try {
      const mode = JSON.parse(data).name
      if (typeof mode === "string")
        root.resizeMode = mode === "resize"
    } catch (error) {
      console.warn("Invalid i3 binding state:", error)
    }
  }

  Process {
    id: i3BindingState

    property int revision: 0
    command: ["i3-msg", "-t", "get_binding_state"]
    stdout: StdioCollector {
      onStreamFinished: root.applyI3BindingState(text, i3BindingState.revision)
    }
  }

  function refreshHyprlandSubmap() {
    // The first focused monitor arrives after native IPC initialization. On reload
    // it already exists, so Component.onCompleted restores the current submap.
    if (!root.hyprlandSession || !Hyprland.focusedMonitor || hyprlandSubmap.running)
      return
    hyprlandSubmap.revision = root.resizeModeRevision
    hyprlandSubmap.running = true
  }

  function handleHyprlandEvent(event) {
    if (!root.hyprlandSession)
      return
    if (event.name === "activespecial" || event.name === "activespecialv2") {
      Hyprland.refreshMonitors()
    } else if (event.name === "submap") {
      root.resizeModeRevision++
      root.resizeMode = String(event.data || "") === "resize"
      root.hyprlandModeInitialized = true
    } else if (event.name === "configreloaded") {
      root.refreshHyprlandSubmap()
      root.refreshHyprlandLayout()
    }
  }

  function applyHyprlandSubmap(data, revision) {
    if (!root.hyprlandSession || revision !== root.resizeModeRevision)
      return
    try {
      // hyprctl -j submap returns a JSON string, not an object.
      const mode = JSON.parse(data)
      if (typeof mode === "string") {
        root.resizeMode = mode === "resize"
        root.hyprlandModeInitialized = true
      }
    } catch (error) {
      console.warn("Invalid Hyprland submap state:", error)
    }
  }

  Process {
    id: hyprlandSubmap

    property int revision: 0
    command: ["hyprctl", "-j", "submap"]
    stdout: StdioCollector {
      onStreamFinished: root.applyHyprlandSubmap(text, hyprlandSubmap.revision)
    }
  }

  function refreshHyprlandLayout() {
    // Like the submap query, wait for the first focused monitor, which arrives
    // after native IPC initialization; config reloads and the IPC handler retry.
    if (!root.hyprlandSession || !Hyprland.focusedMonitor || hyprlandLayout.running)
      return
    root.layoutRevision++
    hyprlandLayout.revision = root.layoutRevision
    hyprlandLayout.running = true
  }

  function applyHyprlandLayout(data, revision) {
    if (!root.hyprlandSession || revision !== root.layoutRevision)
      return
    try {
      const option = JSON.parse(data)
      if (typeof option.str === "string") {
        root.hyprlandLayout = option.str
        root.hyprlandLayoutInitialized = true
      }
    } catch (error) {
      console.warn("Invalid Hyprland layout state:", error)
    }
  }

  Process {
    id: hyprlandLayout

    property int revision: 0
    command: ["hyprctl", "-j", "getoption", "general:layout"]
    stdout: StdioCollector {
      onStreamFinished: root.applyHyprlandLayout(text, hyprlandLayout.revision)
    }
  }

  function refreshI3Layout() {
    if (root.hyprlandSession || i3LayoutQuery.running)
      return
    root.i3LayoutRevision++
    i3LayoutQuery.revision = root.i3LayoutRevision
    i3LayoutQuery.running = true
  }

  function applyI3Layout(data, revision) {
    if (root.hyprlandSession || revision !== root.i3LayoutRevision)
      return
    try {
      root.i3Layout = root.i3LayoutFromTree(data)
    } catch (error) {
      console.warn("Invalid i3 layout tree:", error)
    }
  }

  function i3FocusedNode(node, parent) {
    if (node.focused)
      return { node, parent }
    for (const child of node.nodes || []) {
      const found = root.i3FocusedNode(child, node)
      if (found)
        return found
    }
    return null
  }

  function i3LayoutFromTree(data) {
    const focused = root.i3FocusedNode(JSON.parse(data), null)
    if (!focused)
      return ""
    // i3 applies layout to the container holding the focused one; an empty
    // focused workspace is itself the container.
    const container = focused.node.type === "workspace" ? focused.node : focused.parent
    return container && container.layout ? container.layout : ""
  }

  Process {
    id: i3LayoutQuery

    property int revision: 0
    command: ["i3-msg", "-t", "get_tree"]
    stdout: StdioCollector {
      onStreamFinished: root.applyI3Layout(text, i3LayoutQuery.revision)
    }
  }

  // i3 emits no event when a layout command runs, so the icon is kept in sync
  // with the user's own layout binds by a quiet poll; the poke and workspace
  // events only speed up Hyprland and focus changes.
  Timer {
    id: i3LayoutPoll
    interval: 1000
    repeat: true
    running: !root.hyprlandSession
    onTriggered: root.refreshI3Layout()
  }

  required property var notificationService
  required property var githubPrService
  required property var audioService
  required property var webcamService
  readonly property bool notificationCenterOpen: notificationCenterTarget !== null && notificationCenterTarget.visible
  property bool githubReviewCenterOpen: false
  property var controlCenterTarget: null
  property var notificationCenterTarget: null
  property var githubReviewCenterTarget: null
  property var todayCenterTarget: null
  property var connectivityTarget: null
  property var audioOutputTarget: null
  property var panelsByScreen: ({})
  property bool resizeMode: false
  property int resizeModeRevision: 0
  property bool hyprlandModeInitialized: false
  property string hyprlandLayout: ""
  property int layoutRevision: 0
  property bool hyprlandLayoutInitialized: false
  property string i3Layout: ""
  property int i3LayoutRevision: 0

  WeatherService { id: weatherService }
  QuoteService { id: quoteService }

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(node => node !== null)
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) { root.handleHyprlandEvent(event) }
    function onFocusedMonitorChanged() {
      if (!root.hyprlandModeInitialized)
        root.refreshHyprlandSubmap()
      if (!root.hyprlandLayoutInitialized)
        root.refreshHyprlandLayout()
    }
  }

  function closeDateTime() {
    if (root.todayCenterTarget)
      root.todayCenterTarget.requestClose()
  }

  function closeGitHubReviewCenter() {
    if (root.githubReviewCenterTarget)
      root.githubReviewCenterTarget.requestClose()
    root.githubReviewCenterOpen = false
  }

  ConnectivityService {
    id: connectivity
    wifiScanningEnabled: root.connectivityTarget !== null && root.connectivityTarget.visible
    trafficMonitoringEnabled: root.connectivityTarget !== null && root.connectivityTarget.visible
  }

  function closeConnectivity() {
    if (root.connectivityTarget)
      root.connectivityTarget.requestClose()
  }

  function closeAudioOutput() {
    if (root.audioOutputTarget)
      root.audioOutputTarget.requestClose()
  }

  function focusedPanel() {
    let monitorName = ""
    if (root.hyprlandSession && Hyprland.focusedMonitor)
      monitorName = Hyprland.focusedMonitor.name
    else if (!root.hyprlandSession && I3.focusedMonitor)
      monitorName = I3.focusedMonitor.name
    const panel = monitorName ? root.panelsByScreen[monitorName] : null
    return panel || (root.controlCenterTarget ? root.controlCenterTarget.panel : null)
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

  property int hoverCloseCandidate: 0

  property Timer hoverCloseTimer: Timer {
    interval: 250
    onTriggered: root.runHoverClose()
  }

  readonly property color foreground: "#F3F4F5"
  readonly property color urgent: "#DA4939"
  readonly property color muted: "#A9ADB4"
  readonly property string fontFamily: "Hack Nerd Font Mono"
  readonly property int barFontSize: 18
  readonly property string quickshellScripts: Quickshell.env("HOME") + "/dotfiles/linux/config/quickshell/scripts"
  readonly property bool hyprlandSession: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
  readonly property var workspaceNumbers: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  readonly property var focusedWorkspace: {
    const workspaces = root.hyprlandSession ? Hyprland.workspaces.values : I3.workspaces.values
    return workspaces.find(workspace => workspace.focused) || null
  }
  readonly property int focusedWorkspaceNumber: root.focusedWorkspace
    ? (root.hyprlandSession ? root.focusedWorkspace.id : root.focusedWorkspace.number)
    : 1
  readonly property string currentLayoutName: root.hyprlandSession
    ? root.hyprlandLayout
    : root.i3Layout
  readonly property string layoutIconName: root.layoutIconFor(root.currentLayoutName)
  property int workspaceTransition: 0

  readonly property var defaultAudioSink: Pipewire.defaultAudioSink
  readonly property bool audioAvailable: Pipewire.ready && !!root.defaultAudioSink
    && root.defaultAudioSink.ready && !!root.defaultAudioSink.audio
  readonly property real audioVolume: root.audioAvailable ? root.defaultAudioSink.audio.volume * 100 : 0
  readonly property bool audioMuted: root.audioAvailable && root.defaultAudioSink.audio.muted
  readonly property var defaultMicrophone: Pipewire.defaultAudioSource
  readonly property bool microphoneAvailable: Pipewire.ready && !!root.defaultMicrophone
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
    root.notificationService.showOsd(microphone ? "Microphone" : "Volume",
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
  property string idleLockStatus: ""
  readonly property bool doNotDisturb: root.notificationService.doNotDisturb
  readonly property bool brightnessBusy: brightnessSet.running
  property int brightness: 0
  property bool darkMode: true
  property bool nightModeEnabled: false
  property bool keepAwake: false
  readonly property VpnService vpnService: VpnService {
    monitoring: root.connectivityTarget !== null && root.connectivityTarget.visible
  }
  property bool powerProfileAvailable: false
  property bool nativePowerProfilesAvailable: false
  property string powerProfile: ""
  property string powerProfileDegradation: ""
  property bool systemStatsAvailable: false
  property int cpuUsage: 0
  property int memoryPercentage: 0
  property real memoryUsedGib: 0
  property real memoryTotalGib: 0
  property real loadAverage: 0
  property bool cpuTemperatureAvailable: false
  property real cpuTemperature: 0
  property bool gpuTemperatureAvailable: false
  property real gpuTemperature: 0
  property bool gpuUsageAvailable: false
  property int gpuUsage: 0
  property real previousCpuTotal: -1
  property real previousCpuIdle: -1
  readonly property date currentDate: clock.date

  readonly property color controlActive: root.darkMode ? "#3E5978" : "#C9E1F7"
  readonly property color controlActiveIcon: root.darkMode ? "#8CAED8" : "#5C94C8"
  readonly property color controlDownloadIcon: root.darkMode ? "#83E6B2" : "#167044"
  readonly property color controlUploadIcon: root.darkMode ? "#D6B4FF" : "#7442AD"
  readonly property color controlWarningText: root.darkMode ? "#F0C674" : "#805500"
  readonly property color controlBackground: root.darkMode ? "#D9171A20" : "#D9F8F9FB"
  readonly property color controlPrimaryText: root.darkMode ? "#F8F9FB" : "#20242A"
  readonly property color controlSecondaryText: root.darkMode ? "#B7BEC9" : "#59616D"
  readonly property color controlSliderFill: root.darkMode ? "#DDE1E7" : "#477AA8"
  readonly property color controlSliderTrack: root.darkMode ? "#20242C" : "#D4D9E0"
  readonly property color controlSurface: root.darkMode ? "#2B303A" : "#E8EBEF"
  readonly property color controlBorder: root.darkMode ? "#3A424E" : "#D8DDE4"
  readonly property color controlSurfaceBorder: root.darkMode ? "#33404D" : "#D7DCE3"
  readonly property color controlHover: root.darkMode ? "#38404C" : "#DCE1E8"

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

  function workspaceFor(number) {
    const workspaces = root.hyprlandSession ? Hyprland.workspaces.values : I3.workspaces.values

    for (const workspace of workspaces) {
      if ((root.hyprlandSession ? workspace.id : workspace.number) === number)
        return workspace
    }

    return null
  }

  function activateWorkspace(number, workspace) {
    if (workspace) {
      workspace.activate()
    } else if (root.hyprlandSession) {
      Hyprland.dispatch("workspace " + number)
    } else {
      I3.dispatch("workspace " + number)
    }
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

  function refreshControlStatus() {
    controlStatus.running = true
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

  function closeNotifications() {
    if (root.notificationCenterTarget)
      root.notificationCenterTarget.requestClose()
  }

  function openGitHubReviewCenter() {
    if (root.githubReviewCenterTarget === null)
      return

    root.cancelHoverClose()
    root.closeConnectivity()
    root.closeDateTime()
    root.closeAudioOutput()
    root.controlCenterTarget.requestClose()
    root.closeNotifications()
    if (root.githubReviewCenterOpen)
      root.githubReviewCenterTarget.requestClose()
    else
      root.githubReviewCenterTarget.requestOpen()
    root.githubReviewCenterOpen = !root.githubReviewCenterOpen
  }

  function cancelHoverClose() {
    root.hoverCloseTimer.stop()
    root.hoverCloseCandidate = 0
  }

  function requestHoverClose(kind, delay) {
    root.hoverCloseCandidate = kind
    root.hoverCloseTimer.interval = delay || 250
    root.hoverCloseTimer.start()
  }

  function runHoverClose() {
    if (root.hoverCloseCandidate === 2) {
      root.controlCenterTarget.requestClose()
    } else if (root.hoverCloseCandidate === 3) {
      root.closeGitHubReviewCenter()
    }
    root.hoverCloseCandidate = 0
  }

  function toggleDoNotDisturb() {
    root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
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
    controlRefreshTimer.restart()
  }

  function toggleNightMode() {
    nightModeToggle.running = true
    controlRefreshTimer.restart()
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
    if (root.brightnessBusy)
      return

    brightnessSet.value = Math.round(value)
    brightnessSet.running = true
    root.notificationService.showOsd("Brightness", value, "sun")
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

  Process {
    id: controlStatus
    command: ["sh", "-c", "printf '%s\\n' \"$($HOME/dotfiles/linux/config/quickshell/scripts/nightmode get 2>/dev/null)\" \"$($HOME/dotfiles/linux/config/quickshell/scripts/brightness get 2>/dev/null)\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.replace(/\n$/, "").split("\n")
        root.nightModeEnabled = output[0] === "true"

        const brightness = Number(output[1])
        if (!isNaN(brightness))
          root.brightness = brightness

      }
    }
  }

  Process {
    id: powerProfileNext
    command: ["u_performance-profile", "next"]
    onExited: fallbackProfileStatus.running = true
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
    id: nightModeToggle
    command: [root.quickshellScripts + "/nightmode", "toggle"]
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
      : "xautolock -enable; xset s on +dpms; xset dpms 1200 0 0"]
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
    id: powerNotification
  }

  function updatePowerSource() {
    root.updateBatteryStatus()
    if (!root.batteryAvailable)
      return

    const onBattery = UPower.onBattery
    if (root.previousOnBattery !== null && root.previousOnBattery !== onBattery) {
      powerNotification.command = [root.quickshellScripts + "/battery", "power",
        onBattery ? "unplugged" : "plugged", String(root.batteryPercentage), root.batteryState]
      powerNotification.running = true
      batteryWarnings.running = true
    }
    root.previousOnBattery = onBattery
  }

  Component.onCompleted: {
    root.refreshHyprlandSubmap()
    root.refreshHyprlandLayout()
    root.refreshI3Layout()
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

  Process {
    id: idleLockStatus
    command: ["u_lock-status", "idle"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.idleLockStatus = this.text.trim()
    }
  }

  Process {
    id: systemStatus
    command: ["sh", "-c", "awk '/^cpu / { total = 0; for (i = 2; i <= NF; i++) total += $i; print total, $5 + $6; exit }' /proc/stat; awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { available = $2 } END { print total, available }' /proc/meminfo; awk '{ print $1 }' /proc/loadavg; gpu_usage=; for gpu_path in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$gpu_path\" ] || continue; read -r gpu_usage < \"$gpu_path\"; break; done; printf '%s\\n' \"$gpu_usage\"; sensors -j 2>/dev/null | tr -d '\\n'; printf '\\n'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.trim().split("\n")
        const cpu = output[0]?.trim().split(/\s+/).map(Number)
        const memory = output[1]?.trim().split(/\s+/).map(Number)
        const load = Number(output[2])
        const gpuUsage = Number(output[3])
        let sensors = {}

        try {
          sensors = JSON.parse(output[4] || "{}")
        } catch (_) {
          sensors = {}
        }

        if (cpu?.length === 2 && cpu.every(Number.isFinite)) {
          if (root.previousCpuTotal >= 0 && cpu[0] > root.previousCpuTotal) {
            const totalDelta = cpu[0] - root.previousCpuTotal
            const idleDelta = Math.max(0, cpu[1] - root.previousCpuIdle)
            root.cpuUsage = Math.round(Math.max(0, Math.min(100, (1 - idleDelta / totalDelta) * 100)))
            root.systemStatsAvailable = true
          }
          root.previousCpuTotal = cpu[0]
          root.previousCpuIdle = cpu[1]
        }

        if (memory?.length === 2 && memory.every(Number.isFinite) && memory[0] > 0) {
          const used = Math.max(0, memory[0] - memory[1])
          root.memoryPercentage = Math.round(used / memory[0] * 100)
          root.memoryUsedGib = used / 1048576
          root.memoryTotalGib = memory[0] / 1048576
        }

        if (Number.isFinite(load))
          root.loadAverage = load

        root.gpuUsageAvailable = Number.isFinite(gpuUsage) && gpuUsage >= 0 && gpuUsage <= 100
        if (root.gpuUsageAvailable)
          root.gpuUsage = Math.round(gpuUsage)

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
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: idleLockStatus.running = true
  }

  Timer {
    interval: root.controlCenterTarget && root.controlCenterTarget.visible ? 2000 : 30000
    running: true
    repeat: true
    onTriggered: systemStatus.running = true
  }

  Timer {
    interval: 5000
    running: !root.nativePowerProfilesAvailable
    repeat: true
    onTriggered: fallbackProfileStatus.running = true
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: controlStatus.running = true
  }

  Timer {
    id: controlRefreshTimer
    interval: 400
    onTriggered: controlStatus.running = true
  }

  IpcHandler {
    target: "notifications"

    function toggleCenter() {
      root.openNotificationCenter()
    }

    function clearVisible() {
      root.notificationService.clearVisible()
    }
  }

  IpcHandler {
    target: "bar"

    function openCalendar() { root.openCalendarFromKeyboard() }
    function openConnectivity() { root.openConnectivityFromKeyboard() }
    function openAudioOutput() { root.openAudioOutputFromKeyboard() }
    function toggleDoNotDisturb() { root.toggleDoNotDisturbFromKeyboard() }
    function refreshLayout() {
      root.refreshHyprlandLayout()
      root.refreshI3Layout()
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

      function toggleNotifications() {
        if (notificationCenter.visible && !notificationCenter.closePending)
          notificationCenter.requestClose()
        else
          panel.showNotifications()
      }

      function showNotifications() {
        root.cancelHoverClose()
        if (root.notificationCenterTarget !== notificationCenter)
          root.closeNotifications()
        root.notificationCenterTarget = notificationCenter
        root.closeConnectivity()
        root.closeAudioOutput()
        root.closeDateTime()
        root.closeGitHubReviewCenter()
        controlCenter.requestClose()
        notificationCenter.requestOpen()
      }

      function openDateTime(pin = false) {
        root.cancelHoverClose()
        root.closeConnectivity()
        root.closeAudioOutput()
        if (root.todayCenterTarget !== todayCenter)
          root.closeDateTime()
        root.todayCenterTarget = todayCenter
        controlCenter.requestClose()
        root.closeNotifications()
        root.closeGitHubReviewCenter()
        todayCenter.requestOpen(pin)
      }

      function openConnectivity(pin = false) {
        root.cancelHoverClose()
        root.closeAudioOutput()
        if (root.connectivityTarget !== connectivityCenter)
          root.closeConnectivity()
        root.connectivityTarget = connectivityCenter
        controlCenter.requestClose()
        root.closeNotifications()
        root.closeGitHubReviewCenter()
        root.closeDateTime()
        connectivityCenter.requestOpen(pin)
      }

      function openControlCenter() {
        root.closeConnectivity()
        root.closeDateTime()
        root.closeAudioOutput()
        root.closeNotifications()
        root.closeGitHubReviewCenter()
        controlCenter.requestOpen()
        systemStatus.running = true
        root.cancelHoverClose()
      }

      function openAudioOutput(pin = false) {
        root.cancelHoverClose()
        root.closeConnectivity()
        root.closeDateTime()
        controlCenter.requestClose()
        root.closeNotifications()
        root.closeGitHubReviewCenter()
        if (root.audioOutputTarget !== audioOutputCenter)
          root.closeAudioOutput()
        root.audioOutputTarget = audioOutputCenter
        audioOutputCenter.requestOpen(pin)
      }

      function showGitHubReviewCenter() {
        root.cancelHoverClose()
        root.closeConnectivity()
        root.closeDateTime()
        root.closeAudioOutput()
        controlCenter.requestClose()
        root.closeNotifications()
        if (root.githubReviewCenterTarget !== githubReviewCenter)
          root.closeGitHubReviewCenter()
        root.githubReviewCenterTarget = githubReviewCenter
        root.githubReviewCenterOpen = true
        githubReviewCenter.requestOpen()
      }

      ConnectivityCenter {
        id: connectivityCenter
        controller: root
        panel: panel
        service: connectivity
      }

      AudioOutputCenter {
        id: audioOutputCenter
        controller: root
        panel: panel
        service: root.audioService
        trigger: volumeWidget
      }

      IdleInhibitor {
        enabled: root.hyprlandSession && root.keepAwake
        window: panel
      }

      screen: modelData
      color: "transparent"
      implicitHeight: 40
      focusable: false
      aboveWindows: true

        anchors {
          left: true
          right: true
          top: true
        }

      ControlCenter {
        id: controlCenter
        controller: root
        panel: panel
      }

      NotificationCenter {
        id: notificationCenter
        controller: root
        panel: panel
        service: root.notificationService
      }

      GitHubReviewCenter {
        id: githubReviewCenter
        controller: root
        panel: panel
        service: root.notificationService
        prs: root.githubPrService
      }

      NotificationPopup {
        id: notificationPopup
        controller: root
        panel: panel
        service: root.notificationService
      }

      SystemOsd {
        controller: root
        panel: panel
        service: root.notificationService
      }

      TodayCenter {
        id: todayCenter
        controller: root
        panel: panel
        weather: weatherService
        quote: quoteService
      }

      Component.onCompleted: {
        root.panelsByScreen[modelData.name] = panel
        if (root.controlCenterTarget === null || (modelData.x === 0 && modelData.y === 0)) {
          root.controlCenterTarget = controlCenter
          root.githubReviewCenterTarget = githubReviewCenter
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
            readonly property var workspace: root.workspaceFor(workspaceNumber)
            readonly property bool selected: !!workspace && workspace.focused
            readonly property bool occupied: !!workspace && (root.hyprlandSession
              ? workspace.toplevels.values.length > 0
              : !!workspace.lastIpcObject && ((!!workspace.lastIpcObject.nodes && workspace.lastIpcObject.nodes.length > 0)
                || (!!workspace.lastIpcObject.floating_nodes && workspace.lastIpcObject.floating_nodes.length > 0)))

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
              Accessible.onPressAction: root.activateWorkspace(workspaceItem.workspaceNumber, workspaceItem.workspace)
              hoverEnabled: true
              onClicked: root.activateWorkspace(workspaceItem.workspaceNumber, workspaceItem.workspace)
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
                text: Qt.formatTime(clock.date, "HH:mm")
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
              onEntered: panel.openDateTime()
              onExited: todayCenter.scheduleClose()
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
                text: Qt.formatDate(clock.date, "dd MMM - dddd")
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
              onEntered: panel.openDateTime()
              onExited: todayCenter.scheduleClose()
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

        Item {
          height: root.barFontSize
          width: root.barFontSize
          visible: root.audioService.microphoneInUse
          Accessible.role: Accessible.Button
          Accessible.name: "Microphone in use by " + root.audioService.recordingApplications.map(application => application.name).join(", ")
            + (root.audioService.recordingMicrophonesMuted ? "; inputs muted" : "")
          LucideIcon {
            anchors.fill: parent
            source: root.icon(root.audioService.recordingMicrophonesMuted ? "mic-off" : "mic")
            color: root.audioService.recordingMicrophonesMuted ? root.muted : root.controlActiveIcon
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
            iconName: root.audioService.recordingMicrophonesMuted ? "mic-off" : "mic"
            applications: Array.from(new Set(root.audioService.recordingApplications.map(application => application.name)))
            applicationDetails: {
              const details = Object.create(null)
              for (const application of root.audioService.recordingApplications) {
                const device = application.inputDescription || application.inputName || "Unknown microphone"
                const label = device + (application.muted ? " · Muted" : "")
                details[application.name] = details[application.name]
                  ? details[application.name] + "\n" + label : label
              }
              return details
            }
            muted: root.audioService.recordingMicrophonesMuted
          }
        }

        LucideIcon {
          height: root.barFontSize
          width: root.barFontSize
          visible: root.webcamService.inUse
          source: root.icon("webcam")
          color: root.controlActiveIcon
          Accessible.role: Accessible.StatusBar
          Accessible.name: "Webcam in use by " + root.webcamService.recordingApplications.join(", ")
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
            applications: root.webcamService.recordingApplications
            applicationDetails: root.webcamService.applicationDevices
          }
        }

        Item {
          height: root.barFontSize
          width: root.barFontSize
          visible: panel.width >= 720

          LucideIcon {
            anchors.fill: parent
            color: root.foreground
            source: root.icon("message-square-quote")
          }

          Rectangle {
            anchors {
              right: parent.right
              top: parent.top
            }
            color: "transparent"
            border.color: root.urgent
            border.width: 2
            height: 6
            radius: 3
            visible: root.githubPrService.prs.some(pr => ["review-needed", "changes-requested", "awaiting-review"].includes(pr.action))
            width: 6
          }

          MouseArea {
            anchors.fill: parent
            Accessible.role: Accessible.Button
            Accessible.name: "GitHub review requests"
            Accessible.onPressAction: panel.showGitHubReviewCenter()
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: panel.showGitHubReviewCenter()
            onExited: root.requestHoverClose(3, 500)
            onClicked: panel.showGitHubReviewCenter()
          }
        }


        Item {
          height: root.barFontSize
          width: root.barFontSize * 2 + 8

          Row {
            spacing: 8
            LucideIcon {
              width: root.barFontSize
              height: root.barFontSize
              source: root.icon(!connectivity.wifiConnected && connectivity.ethernetConnected ? "ethernet-port"
                : !connectivity.wifiEnabled ? "wifi-off"
                : !connectivity.wifiConnected ? "wifi-zero"
                : connectivity.wifiStrength < 0.35 ? "wifi-low"
                : connectivity.wifiStrength < 0.7 ? "wifi-high" : "wifi")
              color: connectivity.wifiConnected || connectivity.ethernetConnected ? root.foreground : root.muted
            }
            LucideIcon {
              width: root.barFontSize
              height: root.barFontSize
              source: root.icon(connectivity.bluetoothEnabled ? "bluetooth" : "bluetooth-off")
              color: connectivity.connectedBluetoothDevices.some(device => device.batteryAvailable && device.battery <= 0.15)
                ? root.urgent : connectivity.connectedBluetoothDevices.length > 0 ? root.foreground : root.muted
            }
          }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            Accessible.role: Accessible.Button
            Accessible.name: "Wi-Fi and Bluetooth"
            Accessible.onPressAction: panel.openConnectivity(true)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: panel.openConnectivity()
            onExited: connectivityCenter.scheduleClose()
            onClicked: panel.openConnectivity(true)
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
            onEntered: panel.openAudioOutput()
            onExited: audioOutputCenter.scheduleClose()
            onClicked: panel.openAudioOutput(true)
          }
        }

        Item {
          height: root.barFontSize
          width: root.barFontSize

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
            visible: root.notificationService.popup.length > 0
            width: 6
            z: 1
          }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            Accessible.role: Accessible.Button
            Accessible.name: "Notifications"
              + (root.notificationService.popup.length > 0 ? "; active notifications" : "; no active notifications")
              + (root.doNotDisturb ? "; Do Not Disturb on" : "; Do Not Disturb off")
            Accessible.onPressAction: root.toggleDoNotDisturb()
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
              panel.showNotifications()
            }
            onExited: notificationCenter.requestHoverClose()
            onClicked: root.toggleDoNotDisturb()
          }
        }

        LucideIcon {
          height: root.barFontSize
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
            onEntered: panel.openControlCenter()
            onExited: root.requestHoverClose(2)
            onClicked: panel.openControlCenter()
          }
        }
      }
    }
  }
}

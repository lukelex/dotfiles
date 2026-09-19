import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls as Controls

Scope {
  id: root

  required property var notificationService
  property bool notificationCenterOpen: false
  property var controlCenterTarget: null
  property var notificationCenterTarget: null
  property var dateTimeCenterTarget: null
  property var connectivityTarget: null

  WeatherService { id: weatherService }
  QuoteService { id: quoteService }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "activespecial" || event.name === "activespecialv2")
        Hyprland.refreshMonitors()
    }
  }

  function closeDateTime() {
    if (root.dateTimeCenterTarget)
      root.dateTimeCenterTarget.requestClose()
  }

  ConnectivityService {
    id: connectivity
    wifiScanningEnabled: root.connectivityTarget !== null && root.connectivityTarget.visible
  }

  function closeConnectivity() {
    if (root.connectivityTarget)
      root.connectivityTarget.requestClose()
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
  property int workspaceTransition: 0

  property real audioVolume: 0
  property bool audioMuted: false
  property bool audioAvailable: false
  property string batteryState: ""
  property int batteryPercentage: 0
  property string batteryTime: ""
  property bool batteryAvailable: false
  readonly property bool doNotDisturb: root.notificationService.doNotDisturb
  readonly property bool brightnessBusy: brightnessSet.running
  property int brightness: 0
  property bool darkMode: true
  property bool nightModeEnabled: false
  property bool keepAwake: false
  property bool nordVpnInstalled: false
  property bool vpnConnected: false
  property string vpnLocation: ""
  property var vpnLocations: []
  readonly property bool vpnBusy: vpnToggle.running
  property bool powerProfileAvailable: false
  property string powerProfile: ""
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
  readonly property color controlBackground: root.darkMode ? "#D9171A20" : "#D9F8F9FB"
  readonly property color controlPrimaryText: root.darkMode ? "#F8F9FB" : "#20242A"
  readonly property color controlSecondaryText: root.darkMode ? "#B7BEC9" : "#59616D"
  readonly property color controlSliderFill: root.darkMode ? "#DDE1E7" : "#477AA8"
  readonly property color controlSliderTrack: root.darkMode ? "#20242C" : "#D4D9E0"
  readonly property color controlSurface: root.darkMode ? "#2B303A" : "#E8EBEF"

  function icon(name) {
    return "file://" + Quickshell.env("HOME") + "/dotfiles/linux/config/lucide/svg/" + name + ".svg"
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
    if (root.batteryState === "charging")
      return "battery-charging"
    if (root.batteryPercentage <= 5)
      return "battery-warning"
    if (root.batteryPercentage <= 33)
      return "battery-low"
    if (root.batteryPercentage <= 66)
      return "battery-medium"
    return "battery-full"
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
    if (root.notificationCenterTarget === null)
      return

    root.cancelHoverClose()
    root.closeConnectivity()
    root.closeDateTime()
    root.controlCenterTarget.requestClose()
    if (root.notificationCenterOpen)
      root.notificationCenterTarget.requestClose()
    else
      root.notificationCenterTarget.requestOpen()
    root.notificationCenterOpen = !root.notificationCenterOpen
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
    if (root.hoverCloseCandidate === 1) {
      root.notificationCenterOpen = false
      root.notificationCenterTarget.requestClose()
    } else if (root.hoverCloseCandidate === 2) {
      root.controlCenterTarget.requestClose()
    }
    root.hoverCloseCandidate = 0
  }

  function toggleDoNotDisturb() {
    root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
  }

  function toggleVpn() {
    if (!root.nordVpnInstalled || root.vpnBusy)
      return

    if (root.vpnConnected) {
      vpnToggle.command = ["nordvpn", "disconnect"]
      vpnToggle.running = true
      controlRefreshTimer.restart()
    } else {
      root.connectVpn("")
    }
  }

  function connectVpn(location) {
    if (!root.nordVpnInstalled || root.vpnBusy)
      return

    vpnToggle.command = location ? ["nordvpn", "connect", location] : ["nordvpn", "connect"]
    vpnToggle.running = true
    controlRefreshTimer.restart()
  }

  function refreshVpnLocations() {
    if (!root.nordVpnInstalled || root.vpnLocations.length || vpnLocationsLoad.running)
      return

    vpnLocationsLoad.running = true
  }

  function cyclePowerProfile() {
    if (!root.powerProfileAvailable)
      return

    powerProfileNext.running = true
    controlRefreshTimer.restart()
  }

  function toggleNightMode() {
    nightModeToggle.running = true
    controlRefreshTimer.restart()
  }

  function toggleAudio() {
    audioToggle.running = true
    controlRefreshTimer.restart()
  }

  function setAudioVolume(value) {
    audioSet.value = Math.round(value)
    audioSet.running = true
    root.notificationService.showOsd("Volume", root.audioMuted ? 0 : value, root.audioIcon())
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

  function toggleKeepAwake() {
    if (keepAwakeProcess.running)
      return

    root.keepAwake = !root.keepAwake
    if (!root.hyprlandSession)
      keepAwakeProcess.running = true
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
    command: ["sh", "-c", "vpn_status=\"$(command -v nordvpn >/dev/null && nordvpn status 2>/dev/null || true)\"; printf '%s\\n' \"$($HOME/dotfiles/linux/config/quickshell/scripts/nightmode get 2>/dev/null)\" \"$($HOME/dotfiles/linux/config/quickshell/scripts/brightness get 2>/dev/null)\" \"$(command -v nordvpn >/dev/null && printf true || printf false)\" \"$(printf '%s\\n' \"$vpn_status\" | awk -F ': ' '/^Status:/{ print $2; exit }')\" \"$(u_performance-profile if 2>/dev/null)\" \"$(u_performance-profile get 2>/dev/null)\" \"$(printf '%s\\n' \"$vpn_status\" | awk -F ': ' '/^Country:/{ country=$2 } /^City:/{ city=$2 } END { if (country) print country (city ? \" / \" city : \"\") }')\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.replace(/\n$/, "").split("\n")
        root.nightModeEnabled = output[0] === "true"

        const brightness = Number(output[1])
        if (!isNaN(brightness))
          root.brightness = brightness

        root.nordVpnInstalled = output[2] === "true"
        root.vpnConnected = output[3] === "Connected"
        root.powerProfileAvailable = output[4] === "true"
        root.powerProfile = output[5] || ""
        root.vpnLocation = output[6] || ""
      }
    }
  }

  Process {
    id: vpnToggle
    command: []
    onExited: root.refreshControlStatus()
  }

  Process {
    id: vpnLocationsLoad
    command: ["nordvpn", "countries"]
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "").replace(/\r/g, "")
        if (/Permission denied|^Error:/mi.test(output)) {
          root.vpnLocations = []
          return
        }

        root.vpnLocations = output.split("\n").map(location => location.trim())
          .filter(location => /^[A-Za-z][A-Za-z -]*$/.test(location) && location !== "Available countries")
      }
    }
  }

  Process {
    id: powerProfileNext
    command: ["u_performance-profile", "next"]
  }

  Process {
    id: nightModeToggle
    command: [root.quickshellScripts + "/nightmode", "toggle"]
  }

  Process {
    id: audioToggle
    command: ["u_audio", "vol", "toggle"]
  }

  Process {
    id: audioSet
    property int value: 0
    command: ["u_audio", "vol", "set", value.toString()]
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

  Process {
    id: themeToggle
    command: ["u_theme", "toggle"]
  }

  Process {
    id: audioStatus
    command: ["sh", "-c", "u_audio vol get; pactl get-sink-mute @DEFAULT_SINK@"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.trim().split("\n")
        const volume = Number(output[0])

        if (!isNaN(volume)) {
          root.audioVolume = volume
          root.audioMuted = output[1] === "Mute: yes"
          root.audioAvailable = true
        }
      }
    }
  }

  Process {
    id: batteryStatus
    command: [root.quickshellScripts + "/battery", "get"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.trim().split(" | ")
        const percentage = Number(output[1]?.replace("%", ""))

        if (!isNaN(percentage)) {
          root.batteryState = output[0]
          root.batteryPercentage = percentage
          root.batteryTime = output[2] || ""
          root.batteryAvailable = true
        }
      }
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
    interval: 1000
    running: true
    repeat: true
    onTriggered: audioStatus.running = true
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: batteryStatus.running = true
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: systemStatus.running = true
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

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Variants {
    model: Quickshell.screens

      PanelWindow {
        id: panel

      required property var modelData

      function openDateTime(pin = false) {
        root.cancelHoverClose()
        root.closeConnectivity()
        if (root.dateTimeCenterTarget !== dateTimeCenter)
          root.closeDateTime()
        root.dateTimeCenterTarget = dateTimeCenter
        controlCenter.requestClose()
        notificationCenter.requestClose()
        root.notificationCenterOpen = false
        dateTimeCenter.requestOpen(pin)
      }

      function openConnectivity(pin = false) {
        root.cancelHoverClose()
        if (root.connectivityTarget !== connectivityCenter)
          root.closeConnectivity()
        root.connectivityTarget = connectivityCenter
        controlCenter.requestClose()
        notificationCenter.requestClose()
        root.closeDateTime()
        root.notificationCenterOpen = false
        connectivityCenter.requestOpen(pin)
      }

      ConnectivityCenter {
        id: connectivityCenter
        controller: root
        panel: panel
        service: connectivity
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

      DateTimeCenter {
        id: dateTimeCenter
        controller: root
        panel: panel
        weather: weatherService
        quote: quoteService
      }

      Component.onCompleted: {
        if (root.controlCenterTarget === null || (modelData.x === 0 && modelData.y === 0)) {
          root.controlCenterTarget = controlCenter
          root.notificationCenterTarget = notificationCenter
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

          Image {
            anchors.centerIn: parent
            height: root.barFontSize
            source: "file:///usr/share/icons/Papirus/24x24/apps/tux.svg"
            width: root.barFontSize
          }
        }

        Repeater {
          model: root.workspaceNumbers

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
            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + workspaceNumber
            Accessible.onPressAction: root.activateWorkspace(workspaceNumber, workspace)

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
                  context.fillStyle = marker.urgent ? root.urgent : "#FFD43B"
                  context.beginPath()
                  context.moveTo(centerX, centerY)
                  context.arc(centerX, centerY, 8, marker.mouthAngle, Math.PI * 2 - marker.mouthAngle)
                  context.closePath()
                  context.fill()

                  context.fillStyle = "#000000"
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
              hoverEnabled: true
              onClicked: root.activateWorkspace(workspaceItem.workspaceNumber, workspaceItem.workspace)
            }

            Controls.ToolTip {
              parent: workspaceMouse
              visible: workspaceMouse.containsMouse
              delay: 500
              text: "Workspace " + workspaceItem.workspaceNumber
            }
          }
        }
      }

      Row {
        anchors.centerIn: parent
        spacing: 16

        Item {
          height: timeContent.height
          width: timeContent.width

          Row {
            id: timeContent

            spacing: 6

            LucideIcon {
              height: root.barFontSize
              source: root.icon("clock")
              width: root.barFontSize
              color: root.foreground
            }

            Text {
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.barFontSize
              text: Qt.formatTime(clock.date, "HH:mm")
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: panel.openDateTime()
            onExited: dateTimeCenter.scheduleClose()
            onClicked: panel.openDateTime(true)
          }
        }

        Item {
          height: dateContent.height
          width: dateContent.width

          Row {
            id: dateContent

            spacing: 6

            LucideIcon {
              height: root.barFontSize
              source: root.icon("calendar")
              width: root.barFontSize
              color: root.foreground
            }

            Text {
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.barFontSize
              text: Qt.formatDate(clock.date, "dd MMM - dddd")
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: panel.openDateTime()
            onExited: dateTimeCenter.scheduleClose()
            onClicked: panel.openDateTime(true)
          }
        }
      }

      Row {
        anchors {
          right: parent.right
          rightMargin: 28
          verticalCenter: parent.verticalCenter
        }
        spacing: 12

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
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: panel.openConnectivity()
            onExited: connectivityCenter.scheduleClose()
            onClicked: panel.openConnectivity(true)
          }
        }

        LucideIcon {
          height: root.barFontSize
          source: root.icon(root.audioIcon())
          width: root.barFontSize
          color: root.audioAvailable && !root.audioMuted ? root.foreground : root.muted
        }

        LucideIcon {
          height: root.barFontSize
          width: root.barFontSize
          visible: root.batteryAvailable
          color: root.batteryAvailable && root.batteryPercentage <= 5 ? root.urgent : root.batteryAvailable ? root.foreground : root.muted
          source: root.icon(root.batteryIcon())
        }

        Item {
          height: root.barFontSize
          width: root.barFontSize

          LucideIcon {
            anchors.fill: parent
            source: root.icon("bell")
            color: root.doNotDisturb ? root.urgent : root.foreground
          }

          Rectangle {
            anchors {
              right: parent.right
              top: parent.top
            }
            border.color: root.darkMode ? "#3A4654" : "#D4DAE1"
            border.width: 1
            color: root.urgent
            height: 6
            radius: 3
            visible: root.notificationService.history.length > 0
            width: 6
            z: 1
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
              root.closeConnectivity()
              controlCenter.requestClose()
              root.closeDateTime()
              notificationCenter.requestOpen()
              root.notificationCenterOpen = true
              root.cancelHoverClose()
            }
            onExited: root.requestHoverClose(1)
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
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
              root.closeConnectivity()
              root.closeDateTime()
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              controlCenter.requestOpen()
              root.cancelHoverClose()
            }
            onExited: root.requestHoverClose(2)
            onClicked: {
              root.closeConnectivity()
              controlCenter.requestOpen()
            }
          }
        }
      }
    }
  }
}

import Quickshell
import Quickshell.I3
import Quickshell.Io
import QtQuick

Scope {
  id: root

  required property var notificationService
  property bool notificationCenterOpen: false
  property var controlCenterTarget: null
  property var notificationCenterTarget: null
  property var dateTimeCenterTarget: null
  property var connectivityTarget: null

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
  readonly property int barFontSize: 17

  property real audioVolume: 0
  property bool audioMuted: false
  property bool audioAvailable: false
  property string batteryState: ""
  property int batteryPercentage: 0
  property string batteryTime: ""
  property bool batteryAvailable: false
  readonly property bool doNotDisturb: root.notificationService.doNotDisturb
  property int brightness: 0
  property bool darkMode: true
  property bool nightModeEnabled: false
  property bool nordVpnInstalled: false
  property bool vpnConnected: false
  readonly property bool vpnBusy: vpnToggle.running
  property bool powerProfileAvailable: false
  property string powerProfile: ""
  property bool weatherAvailable: false
  property string weatherTemperature: ""
  property string weatherDescription: ""
  property string weatherCity: ""
  property string weatherCountry: ""
  property string weatherFeelsLike: ""
  property string weatherLow: ""
  property string weatherHigh: ""
  property string weatherHumidity: ""
  property string weatherWind: ""
  property var weatherForecast: []
  property string profileName: "lukas"
  property string profileImage: ""
  readonly property date currentDate: clock.date
  readonly property string timezoneName: Qt.formatDateTime(new Date(), "tt")
  readonly property int weekNumber: Math.ceil((Math.floor((new Date() - new Date(new Date().getFullYear(), 0, 1)) / 86400000) + new Date(new Date().getFullYear(), 0, 1).getDay() + 1) / 7)

  readonly property color controlActive: root.darkMode ? "#3E5978" : "#C9E1F7"
  readonly property color controlActiveIcon: root.darkMode ? "#8CAED8" : "#5C94C8"
  readonly property color controlBackground: root.darkMode ? "#D9171A20" : "#D9F8F9FB"
  readonly property color controlPrimaryText: root.darkMode ? "#F8F9FB" : "#20242A"
  readonly property color controlSecondaryText: root.darkMode ? "#B7BEC9" : "#59616D"
  readonly property color controlSliderFill: root.darkMode ? "#DDE1E7" : "#477AA8"
  readonly property color controlSliderTrack: root.darkMode ? "#20242C" : "#D4D9E0"
  readonly property color controlSurface: root.darkMode ? "#2B303A" : "#E8EBEF"

  function icon(name) {
    return "file:///home/lukas/dotfiles/linux/config/lucide/svg/" + name + ".svg"
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

  function refreshDateTimeStatus() {
    weatherStatus.running = true
    weatherForecastStatus.running = true
  }

  function openNotificationCenter() {
    if (root.notificationCenterTarget === null)
      return

    root.cancelHoverClose()
    root.closeConnectivity()
    root.dateTimeCenterTarget.visible = false
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
    } else if (root.hoverCloseCandidate === 3) {
      root.dateTimeCenterTarget.visible = false
    }
    root.hoverCloseCandidate = 0
  }

  function toggleDoNotDisturb() {
    root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
  }

  function toggleVpn() {
    if (!root.nordVpnInstalled || root.vpnBusy)
      return

    vpnToggle.command = ["nordvpn", root.vpnConnected ? "disconnect" : "connect"]
    vpnToggle.running = true
    controlRefreshTimer.restart()
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
    brightnessSet.value = Math.round(value)
    brightnessSet.running = true
    root.notificationService.showOsd("Brightness", value, "sun")
  }

  function lockScreen() {
    lockScreenProcess.startDetached()
  }

  function syncTheme() {
    root.darkMode = themeState.text().trim() !== "light"
  }

  FileView {
    id: themeState
    path: "/home/lukas/.local/state/dotfiles/color-scheme"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.syncTheme()
  }

  Process {
    id: controlStatus
    command: ["sh", "-c", "printf '%s\\n' \"$(u_nightmode get 2>/dev/null)\" \"$(u_backlight get 2>/dev/null)\" \"$(command -v nordvpn >/dev/null && printf true || printf false)\" \"$(command -v nordvpn >/dev/null && nordvpn status 2>/dev/null | awk -F ': ' '/^Status:/{ print $2; exit }' || true)\" \"$(u_performance-profile if 2>/dev/null)\" \"$(u_performance-profile get 2>/dev/null)\""]
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
      }
    }
  }

  Process {
    id: vpnToggle
    command: []
    onExited: root.refreshControlStatus()
  }

  Process {
    id: powerProfileNext
    command: ["u_performance-profile", "next"]
  }

  Process {
    id: nightModeToggle
    command: ["u_nightmode", "toggle"]
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
    command: ["u_backlight", "set", value.toString()]
  }

  Process {
    id: lockScreenProcess
    command: ["u_exit", "lock"]
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
    command: ["u_battery", "get"]
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
    id: weatherStatus
    command: ["u_weather", "details"]
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.trim().split("|")
        if (output.length !== 9)
          return

        root.weatherTemperature = output[0]
        root.weatherDescription = output[1]
        root.weatherCity = output[2]
        root.weatherCountry = output[3]
        root.weatherFeelsLike = output[4]
        root.weatherLow = output[5]
        root.weatherHigh = output[6]
        root.weatherHumidity = output[7]
        root.weatherWind = output[8]
        root.weatherAvailable = true
      }
    }
  }

  Process {
    id: weatherForecastStatus
    command: ["u_weather", "forecast"]
    stdout: StdioCollector {
      onStreamFinished: {
        const entries = this.text.trim().split("|").filter(entry => entry.length > 0)
        root.weatherForecast = entries.map(entry => {
          const values = entry.split("~")
          return {
            day: Qt.formatDate(new Date(values[0] + "T12:00:00"), "ddd"),
            temperature: values[1],
            condition: values[2]
          }
        }).filter(entry => entry.day && entry.temperature && entry.condition)
      }
    }
  }

  Process {
    id: profileStatus
    command: ["sh", "-c", "image=''; for path in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do [ -r \"$path\" ] && { image=\"file://$path\"; break; }; done; printf '%s\\n%s\\n' \"$USER\" \"$image\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.trim().split("\n")
        root.profileName = output[0] || root.profileName
        root.profileImage = output[1] || ""
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
    interval: 1200000
    running: true
    repeat: true
    onTriggered: {
      weatherStatus.running = true
      weatherForecastStatus.running = true
    }
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

      function openConnectivity(pin = false) {
        root.cancelHoverClose()
        if (root.connectivityTarget !== connectivityCenter)
          root.closeConnectivity()
        root.connectivityTarget = connectivityCenter
        controlCenter.requestClose()
        notificationCenter.requestClose()
        dateTimeCenter.visible = false
        root.notificationCenterOpen = false
        connectivityCenter.requestOpen(pin)
      }

      ConnectivityCenter {
        id: connectivityCenter
        controller: root
        panel: panel
        service: connectivity
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
      }

      Component.onCompleted: {
        if (root.controlCenterTarget === null || (modelData.x === 0 && modelData.y === 0)) {
          root.controlCenterTarget = controlCenter
          root.notificationCenterTarget = notificationCenter
          root.dateTimeCenterTarget = dateTimeCenter
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
          model: I3.workspaces

          delegate: Item {
            required property var modelData

            readonly property var workspace: modelData

            height: 26
            width: label.implicitWidth + 6

            Text {
              id: label

              anchors.centerIn: parent
              color: workspace.urgent ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.barFontSize
              text: workspace.number
            }

            Rectangle {
              anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
              }
              color: root.foreground
              height: 2
              visible: workspace.focused
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: workspace.activate()
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
            onEntered: {
              root.closeConnectivity()
              controlCenter.requestClose()
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              dateTimeCenter.visible = true
              root.cancelHoverClose()
            }
            onExited: root.requestHoverClose(3, 600)
            onClicked: {
              root.closeConnectivity()
              controlCenter.requestClose()
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              dateTimeCenter.visible = true
            }
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
            onEntered: {
              root.closeConnectivity()
              controlCenter.requestClose()
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              dateTimeCenter.visible = true
              root.cancelHoverClose()
            }
            onExited: root.requestHoverClose(3, 600)
            onClicked: {
              root.closeConnectivity()
              controlCenter.requestClose()
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              dateTimeCenter.visible = true
            }
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
              source: root.icon(!connectivity.wifiEnabled ? "wifi-off"
                : !connectivity.wifiConnected ? "wifi-zero"
                : connectivity.wifiStrength < 0.35 ? "wifi-low"
                : connectivity.wifiStrength < 0.7 ? "wifi-high" : "wifi")
              color: connectivity.wifiConnected ? root.foreground : root.muted
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
              dateTimeCenter.visible = false
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
              dateTimeCenter.visible = false
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

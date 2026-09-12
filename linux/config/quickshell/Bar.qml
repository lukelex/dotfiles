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
  property int hoverCloseCandidate: 0

  property Timer hoverCloseTimer: Timer {
    interval: 250
    onTriggered: root.runHoverClose()
  }

  readonly property color foreground: "#F3F4F5"
  readonly property color urgent: "#DA4939"
  readonly property color muted: "#A9ADB4"
  readonly property string fontFamily: "Hack Nerd Font Mono"

  property real audioVolume: 0
  property bool audioMuted: false
  property bool audioAvailable: false
  property string i3Mode: "default"
  property string batteryState: ""
  property int batteryPercentage: 0
  property string batteryTime: ""
  property bool batteryAvailable: false
  property bool bluetoothEnabled: false
  readonly property bool doNotDisturb: root.notificationService.doNotDisturb
  property int brightness: 0
  property bool darkMode: true
  property bool nightModeEnabled: false
  property bool wifiEnabled: false
  property string wifiSsid: ""
  property bool vpnAvailable: false
  property bool vpnConnected: false
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

  function modeIcon() {
    if (root.i3Mode === "resize")
      return "expand"
    if (root.i3Mode === "move")
      return "arrow-up-down"
    return "scan-line"
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

  function requestHoverClose(kind) {
    root.hoverCloseCandidate = kind
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

  function toggleWifi() {
    wifiToggle.enabled = !root.wifiEnabled
    wifiToggle.running = true
    controlRefreshTimer.restart()
  }

  function toggleDoNotDisturb() {
    root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
  }

  function toggleVpn() {
    if (!root.vpnAvailable)
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

  function toggleBluetooth() {
    bluetoothToggle.enabled = !root.bluetoothEnabled
    bluetoothToggle.running = true
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
    id: modeStatus

    command: ["i3-msg", "-t", "get_binding_state"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.i3Mode = JSON.parse(this.text).name || "default"
        } catch (error) {
          root.i3Mode = "default"
        }
      }
    }
  }

  I3IpcListener {
    subscriptions: ["mode"]

    onIpcEvent: event => {
      try {
        root.i3Mode = JSON.parse(event.data).change || "default"
      } catch (error) {
        root.i3Mode = "default"
      }
    }
  }

  Process {
    id: controlStatus
    command: ["sh", "-c", "printf '%s\\n' \"$(nmcli -t -f WIFI general 2>/dev/null)\" \"$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1 == \"yes\" { print $2; exit }')\" \"$(bluetoothctl show 2>/dev/null | awk '/Powered:/ { print $2; exit }')\" \"$(u_nightmode get 2>/dev/null)\" \"$(u_backlight get 2>/dev/null)\" \"$(command -v nordvpn >/dev/null && nordvpn status 2>/dev/null | awk -F ': ' '/^Status:/{ print $2; exit }' || true)\" \"$(u_performance-profile if 2>/dev/null)\" \"$(u_performance-profile get 2>/dev/null)\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const output = this.text.replace(/\n$/, "").split("\n")
        root.wifiEnabled = output[0] === "enabled"
        root.wifiSsid = output[1] || ""
        root.bluetoothEnabled = output[2] === "yes"
        root.nightModeEnabled = output[3] === "true"

        const brightness = Number(output[4])
        if (!isNaN(brightness))
          root.brightness = brightness

        root.vpnAvailable = output[5] === "Connected" || output[5] === "Disconnected"
        root.vpnConnected = output[5] === "Connected"
        root.powerProfileAvailable = output[6] === "true"
        root.powerProfile = output[7] || ""
      }
    }
  }

  Process {
    id: wifiToggle
    property bool enabled: false
    command: ["nmcli", "radio", "wifi", enabled ? "on" : "off"]
  }

  Process {
    id: bluetoothToggle
    property bool enabled: false
    command: ["bluetoothctl", "power", enabled ? "on" : "off"]
  }

  Process {
    id: vpnToggle
    command: []
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
          visible: root.i3Mode !== "default"
          width: visible ? 26 : 0

          Rectangle {
            anchors.fill: parent
            color: root.controlActive
            radius: 8
          }

          LucideIcon {
            anchors.centerIn: parent
            color: root.controlActiveIcon
            height: 16
            source: root.icon(root.modeIcon())
            width: 16
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
              font.pixelSize: 15
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
              height: 16
              source: root.icon("clock")
              width: 16
              color: root.foreground
            }

            Text {
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 15
              text: Qt.formatTime(clock.date, "HH:mm")
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              controlCenter.requestClose()
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              dateTimeCenter.visible = !dateTimeCenter.visible
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
              height: 16
              source: root.icon("calendar")
              width: 16
              color: root.foreground
            }

            Text {
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 15
              text: Qt.formatDate(clock.date, "dd MMM - dddd")
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              controlCenter.requestClose()
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              dateTimeCenter.visible = !dateTimeCenter.visible
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

        LucideIcon {
          height: 18
          source: root.icon(root.audioIcon())
          width: 18
          color: root.audioAvailable && !root.audioMuted ? root.foreground : root.muted
        }

        LucideIcon {
          height: 18
          width: 18
          color: root.batteryAvailable && root.batteryPercentage <= 5 ? root.urgent : root.batteryAvailable ? root.foreground : root.muted
          source: root.icon(root.batteryIcon())
        }

        LucideIcon {
          height: 18
          source: root.icon("bell")
          width: 18
          color: root.doNotDisturb ? root.urgent : root.foreground

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
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
          height: 18
          source: root.icon("sliders")
          width: 18
          color: root.foreground

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
              dateTimeCenter.visible = false
              notificationCenter.requestClose()
              root.notificationCenterOpen = false
              controlCenter.requestOpen()
              root.cancelHoverClose()
            }
            onExited: root.requestHoverClose(2)
            onClicked: {
              controlCenter.requestOpen()
            }
          }
        }
      }
    }
  }
}

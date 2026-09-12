import Quickshell
import QtQuick

PopupWindow {
  id: popup

  required property var controller
  required property var panel

  anchor.window: panel
  anchor.rect.x: parentWindow.width - width - 12
  anchor.rect.y: parentWindow.height + 12
  color: "transparent"
  grabFocus: true
  implicitHeight: 504
  implicitWidth: 432

  surfaceFormat.opaque: false

  component ControlTile: Item {
    id: tile

    required property bool active
    required property var controller
    required property string iconName
    required property string subtitle
    required property string title
    signal activated()

    Rectangle {
      anchors.fill: parent
      border.color: tile.controller.darkMode ? "#33404D" : "#D7DCE3"
      border.width: 1
      color: tile.active ? tile.controller.controlActive : tile.controller.controlSurface
      radius: 16
    }

    Row {
      anchors {
        fill: parent
        margins: 12
      }
      spacing: 10

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        color: tile.active ? tile.controller.controlActiveIcon : tile.controller.controlSliderTrack
        height: 34
        radius: 17
        width: 34

        LucideIcon {
          anchors.centerIn: parent
          color: tile.controller.controlPrimaryText
          height: 18
          source: tile.controller.icon(tile.iconName)
          width: 18
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        width: parent.width - 56

        Text {
          color: tile.controller.controlPrimaryText
          elide: Text.ElideRight
          font.family: tile.controller.fontFamily
          font.pixelSize: 14
          text: tile.title
          width: parent.width
        }

        Text {
          color: tile.controller.controlSecondaryText
          elide: Text.ElideRight
          font.family: tile.controller.fontFamily
          font.pixelSize: 11
          text: tile.subtitle
          width: parent.width
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.activated()
    }
  }

  component QuickAction: Item {
    id: action

    required property bool active
    required property var controller
    required property string iconName
    required property string title
    signal activated()

    Rectangle {
      anchors.fill: parent
      border.color: action.controller.darkMode ? "#33404D" : "#D7DCE3"
      border.width: 1
      color: action.active ? action.controller.controlActive : action.controller.controlSurface
      radius: 14
    }

    Row {
      anchors {
        fill: parent
        margins: 10
      }
      spacing: 8

      LucideIcon {
        anchors.verticalCenter: parent.verticalCenter
        color: action.active ? action.controller.controlPrimaryText : action.controller.controlSecondaryText
        height: 17
        source: action.controller.icon(action.iconName)
        width: 17
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        color: action.controller.controlPrimaryText
        font.family: action.controller.fontFamily
        font.pixelSize: 12
        text: action.title
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: action.activated()
    }
  }

  component SliderControl: Item {
    id: slider

    required property string iconName
    required property var controller
    required property real value
    signal valueChangedByUser(real value)

    height: 34

    LucideIcon {
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
      }
      color: slider.controller.controlSliderFill
      height: 18
      source: slider.controller.icon(slider.iconName)
      width: 18
    }

    Rectangle {
      id: track

      anchors {
        left: parent.left
        leftMargin: 30
        right: valueLabel.left
        rightMargin: 10
        verticalCenter: parent.verticalCenter
      }
      color: slider.controller.controlSliderTrack
      height: 8
      radius: 4

      Rectangle {
        color: slider.controller.controlSliderFill
        height: parent.height
        radius: parent.radius
        width: Math.max(height, parent.width * slider.value / 100)
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: function(mouse) {
          if (pressed)
            slider.valueChangedByUser(Math.max(0, Math.min(100, mouse.x / width * 100)))
        }
        onPressed: function(mouse) {
          slider.valueChangedByUser(Math.max(0, Math.min(100, mouse.x / width * 100)))
        }
      }
    }

    Text {
      id: valueLabel

      anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
      }
      color: slider.controller.controlSecondaryText
      font.family: slider.controller.fontFamily
      font.pixelSize: 11
      text: Math.round(slider.value) + "%"
    }
  }

  property bool closePending: false

  function requestOpen() {
    if (popup.visible && !closeAnim.running)
      return
    popup.visible = true
    popup.closePending = false
    content.opacity = 0
    content.y = 10
    openAnim.start()
  }

  function requestClose() {
    if (!popup.visible || closeAnim.running)
      return
    popup.closePending = true
    openAnim.stop()
    closeAnim.start()
  }

  // Soft rise + fade: content slides up into place on open and down on close.
  ParallelAnimation {
    id: openAnim
    OpacityAnimator {
      target: content
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
    YAnimator {
      target: content
      to: 0
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  ParallelAnimation {
    id: closeAnim
    OpacityAnimator {
      target: content
      to: 0
      duration: 120
      easing.type: Easing.InCubic
    }
    YAnimator {
      target: content
      to: 6
      duration: 120
      easing.type: Easing.InCubic
    }
    onStopped: {
      if (popup.closePending) {
        popup.closePending = false
        popup.visible = false
      }
    }
  }

  Item {
    id: content

    width: parent.width
    height: parent.height

    HoverHandler {
      onHoveredChanged: {
        if (hovered)
          popup.controller.cancelHoverClose()
        else
          popup.controller.requestHoverClose(2)
      }
    }

    Rectangle {
      anchors.fill: parent
      border.color: popup.controller.darkMode ? "#3A424E" : "#D8DDE4"
      border.width: 1
      color: popup.controller.controlBackground
      radius: 26
    }

    Column {
      anchors {
        fill: parent
        margins: 16
      }
      spacing: 12

      Text {
        color: popup.controller.controlPrimaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: 16
        text: "Control Center"
      }

      Row {
        height: 70
        spacing: 10
        width: parent.width

        ControlTile {
          active: popup.controller.wifiEnabled
          controller: popup.controller
          height: parent.height
          iconName: "wifi"
          subtitle: popup.controller.wifiEnabled ? popup.controller.wifiSsid || "Not connected" : "Off"
          title: "Wi-Fi"
          width: (parent.width - parent.spacing) / 2
          onActivated: popup.controller.toggleWifi()
        }

        ControlTile {
          active: popup.controller.bluetoothEnabled
          controller: popup.controller
          height: parent.height
          iconName: "bluetooth"
          subtitle: popup.controller.bluetoothEnabled ? "On" : "Off"
          title: "Bluetooth"
          width: (parent.width - parent.spacing) / 2
          onActivated: popup.controller.toggleBluetooth()
        }
      }

      Row {
        height: 46
        spacing: 10
        width: parent.width

        QuickAction {
          active: popup.controller.vpnConnected
          controller: popup.controller
          height: parent.height
          iconName: "globe"
          title: popup.controller.vpnAvailable ? popup.controller.vpnConnected ? "VPN Connected" : "VPN" : "VPN unavailable"
          width: parent.width
          onActivated: popup.controller.toggleVpn()
        }
      }

      Row {
        height: 46
        spacing: 10
        width: parent.width

        QuickAction {
          active: popup.controller.nightModeEnabled
          controller: popup.controller
          height: parent.height
          iconName: "moon-star"
          title: "Night Shift"
          width: (parent.width - parent.spacing) / 2
          onActivated: popup.controller.toggleNightMode()
        }

        QuickAction {
          active: popup.controller.audioMuted
          controller: popup.controller
          height: parent.height
          iconName: popup.controller.audioMuted ? "volume-x" : "volume-2"
          title: popup.controller.audioMuted ? "Muted" : "Sound"
          width: (parent.width - parent.spacing) / 2
          onActivated: popup.controller.toggleAudio()
        }
      }

      ControlTile {
        active: popup.controller.powerProfile === "performance"
        controller: popup.controller
        height: 70
        iconName: "gauge"
        subtitle: popup.controller.powerProfileAvailable ? "Click to switch profile" : "No firmware profiles available"
        title: popup.controller.powerProfileAvailable ? "Power: " + popup.controller.powerProfile : "Power profile"
        width: parent.width
        onActivated: popup.controller.cyclePowerProfile()
      }

      Item {
        height: 102
        width: parent.width

        Rectangle {
          anchors.fill: parent
          border.color: popup.controller.darkMode ? "#33404D" : "#D7DCE3"
          border.width: 1
          color: popup.controller.controlSurface
          radius: 18
        }

        Column {
          anchors {
            fill: parent
            margins: 14
          }
          spacing: 10

          SliderControl {
            controller: popup.controller
            iconName: popup.controller.audioIcon()
            value: popup.controller.audioVolume
            width: parent.width
            onValueChangedByUser: function(value) {
              popup.controller.setAudioVolume(value)
            }
          }

          SliderControl {
            controller: popup.controller
            iconName: "sun"
            value: popup.controller.brightness
            width: parent.width
            onValueChangedByUser: function(value) {
              popup.controller.setBrightness(value)
            }
          }
        }
      }

      Row {
        height: 44
        spacing: 10
        width: parent.width

        QuickAction {
          active: false
          controller: popup.controller
          height: parent.height
          iconName: "lock"
          title: "Lock Screen"
          width: 134
          onActivated: popup.controller.lockScreen()
        }

        Item {
          height: parent.height
          width: parent.width - 144

          Rectangle {
            anchors.fill: parent
            border.color: popup.controller.darkMode ? "#33404D" : "#D7DCE3"
            border.width: 1
            color: popup.controller.controlSurface
            radius: 14
          }

          Row {
            anchors {
              fill: parent
              leftMargin: 12
              rightMargin: 12
            }
            spacing: 8

            LucideIcon {
              anchors.verticalCenter: parent.verticalCenter
              color: popup.controller.batteryAvailable && popup.controller.batteryPercentage <= 5 ? popup.controller.urgent : popup.controller.batteryAvailable ? popup.controller.controlPrimaryText : popup.controller.controlSecondaryText
              height: 18
              width: 18
              source: popup.controller.icon(popup.controller.batteryIcon())
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              color: popup.controller.controlPrimaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 12
              text: popup.controller.batteryAvailable ? popup.controller.batteryPercentage + "%" : "Unavailable"
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              color: popup.controller.controlSecondaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 11
              text: popup.controller.batteryAvailable ? popup.controller.batteryTime ? popup.controller.batteryState === "charging" ? popup.controller.batteryTime + " until full" : popup.controller.batteryTime + " remaining" : popup.controller.batteryState === "charging" ? "Charging" : "Battery" : ""
            }
          }
        }
      }
    }
  }

  onVisibleChanged: {
    if (visible)
      controller.refreshControlStatus()
    else {
      openAnim.stop()
      closeAnim.stop()
      popup.closePending = false
      content.opacity = 1
      content.y = 0
    }
  }
}

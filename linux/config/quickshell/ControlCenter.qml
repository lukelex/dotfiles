pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Controls as Controls

PopupWindow {
  id: popup

  required property var controller
  required property var panel

  anchor.window: panel
  anchor.rect.x: Math.max(0, panel.width - width - 12)
  anchor.rect.y: panel.height + 12
  color: "transparent"
  grabFocus: false
  readonly property real maxHeight: Math.max(1, panel.screen.height - panel.height - 24)
  implicitHeight: Math.min(sections.implicitHeight + 32, maxHeight)
  implicitWidth: Math.min(432, panel.screen.width - 24)

  surfaceFormat.opaque: false

  component ControlTile: Item {
    id: tile

    required property bool active
    required property var controller
    required property string iconName
    required property string subtitle
    required property string title
    signal activated()

    opacity: enabled ? 1 : 0.55

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
      anchors.fill: parent
      anchors.margins: 10
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
        width: parent.width - 25
        elide: Text.ElideRight
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
    required property string title
    required property string toggleTitle
    required property string toggleIcon
    required property bool toggleActive
    property bool busy: false
    signal valueChangedByUser(real value)
    signal toggleRequested()

    height: 72
    opacity: enabled ? 1 : 0.55

    Text {
      height: 30
      width: parent.width - toggle.width - 12
      verticalAlignment: Text.AlignVCenter
      color: slider.controller.controlPrimaryText
      font.family: slider.controller.fontFamily
      font.pixelSize: 12
      text: slider.title
      elide: Text.ElideRight
    }

    QuickAction {
      id: toggle
      anchors.right: parent.right
      height: 30
      width: 116
      active: slider.toggleActive
      controller: slider.controller
      iconName: slider.toggleIcon
      title: slider.toggleTitle
      onActivated: slider.toggleRequested()
    }

    LucideIcon {
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
        verticalCenterOffset: 16
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
        verticalCenterOffset: 16
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
        anchors.topMargin: -12
        anchors.bottomMargin: -12
        cursorShape: slider.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: !slider.busy
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
        right: spinner.left
        rightMargin: 6
        verticalCenter: parent.verticalCenter
        verticalCenterOffset: 16
      }
      color: slider.controller.controlSecondaryText
      font.family: slider.controller.fontFamily
      font.pixelSize: 11
      text: Math.round(slider.value) + "%"
      width: 44
      horizontalAlignment: Text.AlignRight
    }

    LucideIcon {
      id: spinner

      anchors {
        right: parent.right
        verticalCenter: valueLabel.verticalCenter
      }
      Accessible.name: "Applying " + slider.title
      color: slider.controller.controlSecondaryText
      height: 14
      source: slider.controller.icon("refresh-cw")
      visible: slider.busy
      width: 14

      RotationAnimation on rotation {
        duration: 700
        from: 0
        loops: Animation.Infinite
        running: spinner.visible
        to: 360
      }
    }
  }

  component SystemUsage: Item {
    id: metric

    required property var controller
    required property string iconName
    required property real percentage
    required property string title
    required property string value

    height: 38

    Row {
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
      }
      spacing: 8

      LucideIcon {
        anchors.verticalCenter: parent.verticalCenter
        color: metric.percentage >= 90 ? metric.controller.urgent : metric.controller.controlSecondaryText
        height: 16
        source: metric.controller.icon(metric.iconName)
        width: 16
      }

      Text {
        id: metricLabel

        anchors.verticalCenter: parent.verticalCenter
        color: metric.controller.controlPrimaryText
        font.family: metric.controller.fontFamily
        font.pixelSize: 12
        text: metric.title
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        color: metric.percentage >= 90 ? metric.controller.urgent : metric.controller.controlSecondaryText
        font.family: metric.controller.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
        text: metric.value
        width: parent.width - 16 - metricLabel.width - parent.spacing * 2
      }
    }

    Rectangle {
      anchors {
        bottom: parent.bottom
        left: parent.left
        right: parent.right
      }
      color: metric.controller.controlSliderTrack
      height: 6
      radius: 3

      Rectangle {
        color: metric.percentage >= 90 ? metric.controller.urgent : metric.controller.controlSliderFill
        height: parent.height
        radius: parent.radius
        width: Math.max(parent.height, parent.width * metric.percentage / 100)
      }
    }
  }

  property bool closePending: false

  function requestOpen() {
    if (popup.visible && !closeAnim.running)
      return
    popup.closePending = false
    closeAnim.stop()
    if (!popup.visible) {
      content.opacity = 0
      content.y = 10
      popup.visible = true
    }
    openAnim.start()
  }

  function requestClose() {
    if (!popup.visible || closeAnim.running)
      return
    popup.closePending = true
    trayModule.closeMenu()
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
      id: contentHover

      onHoveredChanged: {
        if (hovered)
          popup.controller.cancelHoverClose()
        else if (!trayModule.menuOpen)
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

    Flickable {
      id: scroll

      anchors.fill: parent
      anchors.margins: 16
      contentWidth: width
      contentHeight: sections.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      Controls.ScrollBar.vertical: Controls.ScrollBar {
        policy: Controls.ScrollBar.AsNeeded
      }

      Column {
        id: sections
        width: scroll.width - (scroll.contentHeight > scroll.height ? 12 : 0)
        spacing: 16

        Text {
          color: popup.controller.controlPrimaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 16
          text: "Control Center"
        }

        Rectangle {
          height: adjustments.implicitHeight + 28
          width: parent.width
          color: popup.controller.controlSurface
          radius: 18

          Column {
            id: adjustments
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12

            SliderControl {
              controller: popup.controller
              enabled: popup.controller.audioAvailable
              title: !popup.controller.audioAvailable ? "Audio unavailable" : popup.controller.audioMuted ? "Volume / muted" : "Volume"
              iconName: popup.controller.audioIcon()
              toggleTitle: popup.controller.audioMuted ? "Unmute" : "Mute"
              toggleIcon: "volume-x"
              toggleActive: popup.controller.audioMuted
              onToggleRequested: popup.controller.toggleAudio()
              value: popup.controller.audioVolume
              width: parent.width
              onValueChangedByUser: function(value) {
                popup.controller.setAudioVolume(value)
              }
            }

            SliderControl {
              busy: popup.controller.brightnessBusy
              controller: popup.controller
              title: "Brightness"
              iconName: "sun"
              toggleTitle: popup.controller.nightModeEnabled ? "Night on" : "Night off"
              toggleIcon: "moon-star"
              toggleActive: popup.controller.nightModeEnabled
              onToggleRequested: popup.controller.toggleNightMode()
              value: popup.controller.brightness
              width: parent.width
              onValueChangedByUser: function(value) {
                popup.controller.setBrightness(value)
              }
            }

            Text {
              color: popup.controller.controlSecondaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 11
              text: popup.controller.idleLockStatus
              textFormat: Text.PlainText
              visible: text.length > 0
              width: parent.width
              wrapMode: Text.Wrap
            }
          }
        }

        Rectangle {
          height: systemMetrics.implicitHeight + 28
          visible: popup.controller.systemStatsAvailable
          width: parent.width
          color: popup.controller.controlSurface
          radius: 18

          Column {
            id: systemMetrics
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10

            Text {
              color: popup.controller.controlPrimaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 12
              text: "System"
            }

            SystemUsage {
              controller: popup.controller
              iconName: "cpu"
              percentage: popup.controller.cpuUsage
              title: "CPU" + (popup.controller.cpuTemperatureAvailable
                ? " - " + Math.round(popup.controller.cpuTemperature) + "\u00b0C" : "")
              value: popup.controller.cpuUsage + "%"
              width: parent.width
            }

            SystemUsage {
              controller: popup.controller
              iconName: "memory-stick"
              percentage: popup.controller.memoryPercentage
              title: "Memory"
              value: popup.controller.memoryUsedGib.toFixed(1) + " / " + popup.controller.memoryTotalGib.toFixed(1) + " GiB"
              width: parent.width
            }

            SystemUsage {
              controller: popup.controller
              iconName: "microchip"
              percentage: popup.controller.gpuUsage
              title: "GPU - " + Math.round(popup.controller.gpuTemperature) + "\u00b0C"
              value: popup.controller.gpuUsage + "%"
              visible: popup.controller.gpuTemperatureAvailable && popup.controller.gpuUsageAvailable
              width: parent.width
            }

            Row {
              height: 18
              spacing: 8
              width: parent.width

              LucideIcon {
                anchors.verticalCenter: parent.verticalCenter
                color: popup.controller.controlSecondaryText
                height: 16
                source: popup.controller.icon("gauge")
                width: 16
              }

              Text {
                id: loadLabel

                anchors.verticalCenter: parent.verticalCenter
                color: popup.controller.controlPrimaryText
                font.family: popup.controller.fontFamily
                font.pixelSize: 12
                text: "Load (1m)"
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                color: popup.controller.controlSecondaryText
                font.family: popup.controller.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                text: popup.controller.loadAverage.toFixed(2)
                width: parent.width - 16 - loadLabel.width - parent.spacing * 2
              }
            }
          }
        }

        Column {
          spacing: 10
          width: parent.width
          visible: popup.controller.batteryAvailable || popup.controller.powerProfileAvailable

          Row {
            width: parent.width
            height: 24
            spacing: 8
            visible: popup.controller.batteryAvailable

            LucideIcon {
              id: powerIcon
              anchors.verticalCenter: parent.verticalCenter
              height: 18
              width: 18
              source: popup.controller.icon(popup.controller.batteryIcon())
              color: popup.controller.batteryAvailable && popup.controller.batteryPercentage <= 5
                ? popup.controller.urgent : popup.controller.controlSecondaryText
            }

            Text {
              id: batterySummary
              anchors.verticalCenter: parent.verticalCenter
              color: popup.controller.controlPrimaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 12
              text: popup.controller.batteryAvailable ? "Battery " + popup.controller.batteryPercentage + "%" : "Power"
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - powerIcon.width - batterySummary.width - parent.spacing * 2
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
              color: popup.controller.controlSecondaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 11
              text: !popup.controller.batteryAvailable ? ""
                : popup.controller.batteryTime ? popup.controller.batteryTime
                  + (popup.controller.batteryState === "charging" ? " until full" : " remaining")
                : popup.controller.batteryState === "charging" ? "Charging" : ""
            }
          }

          ControlTile {
            active: popup.controller.powerProfile === "performance"
            enabled: popup.controller.powerProfileAvailable
            visible: popup.controller.powerProfileAvailable
            controller: popup.controller
            height: 64
            iconName: "gauge"
            subtitle: "Click to switch profile"
            title: "Power: " + popup.controller.powerProfile
            width: parent.width
            onActivated: popup.controller.cyclePowerProfile()
          }
        }

        Row {
          anchors.right: parent.right
          width: parent.width
          spacing: 8

          QuickAction {
            active: popup.controller.keepAwake
            controller: popup.controller
            height: 40
            width: (parent.width - parent.spacing * 2) / 3
            iconName: popup.controller.keepAwake ? "monitor-off" : "monitor"
            title: popup.controller.keepAwake ? "Keep Awake" : "Allow Idle"
            onActivated: popup.controller.toggleKeepAwake()
          }

          QuickAction {
            active: popup.controller.darkMode
            controller: popup.controller
            height: 40
            width: (parent.width - parent.spacing * 2) / 3
            Accessible.name: popup.controller.darkMode ? "Switch to light mode" : "Switch to dark mode"
            iconName: popup.controller.darkMode ? "sun" : "moon"
            title: popup.controller.darkMode ? "Light" : "Dark"
            onActivated: popup.controller.toggleTheme()
          }

          QuickAction {
            active: false
            controller: popup.controller
            height: 40
            width: (parent.width - parent.spacing * 2) / 3
            iconName: "lock"
            title: "Lock Screen"
            onActivated: popup.controller.lockScreen()
          }
        }

        TrayModule {
          id: trayModule

          controller: popup.controller
          width: parent.width
          onMenuClosed: {
            if (popup.visible && !popup.closePending && !contentHover.hovered)
              popup.controller.requestHoverClose(2)
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

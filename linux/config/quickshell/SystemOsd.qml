import Quickshell
import QtQml
import QtQuick

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property var service

  property bool closePending: false
  property var displayedOsd: null

  readonly property bool muted: displayedOsd && displayedOsd.summary === "Volume" && displayedOsd.value === 0
  readonly property real value: displayedOsd ? displayedOsd.value : 0

  anchor.window: panel
  anchor.rect.x: (parentWindow.width - width) / 2
  anchor.rect.y: parentWindow.height + 64
  color: "transparent"
  implicitHeight: 172
  implicitWidth: 216
  surfaceFormat.opaque: false
  visible: false

  function iconName() {
    if (!popup.displayedOsd || popup.displayedOsd.summary === "Brightness")
      return "sun"
    if (popup.muted)
      return "volume-x"
    if (popup.value <= 25)
      return "volume"
    if (popup.value <= 50)
      return "volume-1"
    return "volume-2"
  }

  function showOsd(record) {
    popup.closePending = false
    popup.displayedOsd = record
    if (hideAnimation.running) {
      hideAnimation.stop()
      showAnimation.start()
      return
    }
    if (popup.visible)
      return

    content.opacity = 0
    content.scale = 0.9
    popup.visible = true
    showAnimation.start()
  }

  function hideOsd() {
    if (!popup.visible)
      return
    popup.closePending = true
    showAnimation.stop()
    hideAnimation.start()
  }

  Component.onCompleted: {
    if (service.osd)
      popup.showOsd(service.osd)
  }

  Connections {
    target: popup.service

    function onOsdChanged() {
      if (popup.service.osd)
        popup.showOsd(popup.service.osd)
      else
        popup.hideOsd()
    }
  }

  ParallelAnimation {
    id: showAnimation

    OpacityAnimator {
      target: content
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
    ScaleAnimator {
      target: content
      to: 1
      duration: 180
      easing.type: Easing.OutBack
    }
  }

  ParallelAnimation {
    id: hideAnimation

    OpacityAnimator {
      target: content
      to: 0
      duration: 140
      easing.type: Easing.InCubic
    }
    ScaleAnimator {
      target: content
      to: 0.94
      duration: 140
      easing.type: Easing.InCubic
    }
    onStopped: {
      if (popup.closePending) {
        popup.closePending = false
        popup.displayedOsd = null
        popup.visible = false
      }
    }
  }

  Item {
    id: content

    anchors.fill: parent
    transformOrigin: Item.Center

    Rectangle {
      anchors {
        fill: parent
        topMargin: 5
      }
      color: Qt.rgba(0, 0, 0, popup.controller.darkMode ? 0.32 : 0.16)
      radius: 30
    }

    Rectangle {
      anchors.fill: parent
      color: popup.controller.darkMode ? Qt.rgba(0.10, 0.12, 0.16, 0.94) : Qt.rgba(0.96, 0.97, 0.99, 0.94)
      radius: 30
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      border.color: popup.controller.darkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.72)
      border.width: 1
      color: "transparent"
      radius: 29
    }

    Column {
      anchors {
        fill: parent
        margins: 22
      }
      spacing: 14

      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        height: 66
        width: 66

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(popup.controller.controlActive.r, popup.controller.controlActive.g, popup.controller.controlActive.b, 0.45)
          radius: 33
        }

        LucideIcon {
          anchors.centerIn: parent
          color: popup.muted ? popup.controller.urgent : popup.controller.controlPrimaryText
          height: 34
          source: popup.controller.icon(popup.iconName())
          width: 34
        }
      }

      Item {
        height: 12
        width: parent.width

        Rectangle {
          id: meterTrack

          anchors.verticalCenter: parent.verticalCenter
          color: popup.controller.controlSliderTrack
          height: 8
          radius: 4
          width: parent.width

          Rectangle {
            id: meterFill

            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            color: popup.muted ? popup.controller.urgent : popup.controller.controlSliderFill
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0, Math.min(100, popup.value)) / 100

          }
        }
      }

      Text {
        color: popup.controller.controlSecondaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        text: Math.round(popup.value) + "%"
        width: parent.width
      }
    }
  }
}

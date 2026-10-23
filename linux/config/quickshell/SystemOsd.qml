import Quickshell
import QtQml
import QtQuick
import "DesignTokens.js" as Design

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property var service

  property bool closePending: false
  property var displayedOsd: null
  readonly property bool labeledOsd: displayedOsd && ["Layout", "Reload", "Monitor"].includes(displayedOsd.summary)

  readonly property bool muted: displayedOsd && (displayedOsd.summary === "Volume" && displayedOsd.value === 0
    || displayedOsd.summary === "Microphone" && /mic-off/.test(displayedOsd.appIcon))
  readonly property real value: displayedOsd ? displayedOsd.value : 0

  anchor.window: panel
  anchor.rect.x: (parentWindow.width - width) / 2
  anchor.rect.y: parentWindow.height + Design.osd.offset
  color: "transparent"
  implicitHeight: Design.osd.height
  implicitWidth: Design.osd.width
  surfaceFormat.opaque: false
  visible: false

  function iconName() {
    if (!popup.displayedOsd)
      return "sun"
    if (popup.labeledOsd)
      return popup.displayedOsd.osdIconName || "maximize"
    if (popup.displayedOsd.summary === "Brightness")
      return "sun"
    if (popup.displayedOsd.summary === "Microphone")
      return popup.muted ? "mic-off" : "mic"
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
      duration: Design.motion.enter
      easing.type: Easing.OutCubic
    }
    ScaleAnimator {
      target: content
      to: 1
      duration: Design.motion.enter
      easing.type: Easing.OutCubic
    }
  }

  ParallelAnimation {
    id: hideAnimation

    OpacityAnimator {
      target: content
      to: 0
      duration: Design.motion.exit
      easing.type: Easing.InCubic
    }
    ScaleAnimator {
      target: content
      to: 0.94
      duration: Design.motion.exit
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

    PanelSurface {
      anchors.fill: parent
      controller: popup.controller
    }

    Column {
      anchors {
        fill: parent
        margins: Design.osd.padding
      }
      spacing: Design.spacing.card

      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        height: Design.osd.iconWell
        width: Design.osd.iconWell

        Rectangle {
          anchors.fill: parent
          color: popup.controller.controlSurface
          radius: width / 2
        }

        LucideIcon {
          anchors.centerIn: parent
          color: popup.muted ? popup.controller.controlSecondaryText : popup.controller.controlPrimaryText
          height: Design.osd.icon
          source: popup.controller.icon(popup.iconName())
          width: Design.osd.icon
        }
      }

      Item {
        height: 12
        width: parent.width
        visible: !popup.labeledOsd

        Rectangle {
          id: meterTrack

          anchors.verticalCenter: parent.verticalCenter
          color: popup.controller.controlSliderTrack
          height: Design.osd.track
          radius: 4
          width: parent.width

          Rectangle {
            id: meterFill

            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            color: popup.controller.controlSliderFill
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0, Math.min(100, popup.value)) / 100

          }
        }
      }

      Text {
        color: popup.controller.controlSecondaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: Design.typography.caption
        horizontalAlignment: Text.AlignHCenter
        text: popup.muted ? "Muted"
          : popup.labeledOsd
            ? (popup.displayedOsd.osdScreenLabels?.[popup.panel.screen.name] || popup.displayedOsd.osdLabel || "")
            : Math.round(popup.value) + "%"
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }
    }
  }
}

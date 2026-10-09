pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Controls.Basic as Controls

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property MouseArea trigger
  required property string title
  required property string iconName
  required property var applications
  property var applicationDetails: ({})
  property bool muted: false
  property bool shown: false
  readonly property bool hovered: trigger.containsMouse && trigger.visible

  anchor.window: panel
  anchor.rect.x: Math.max(12, Math.min(panel.width - width - 12,
    trigger.mapToItem(panel.contentItem, trigger.width / 2, 0).x - width / 2))
  anchor.rect.y: panel.height + 12
  implicitWidth: Math.min(300, panel.screen.width - 24)
  implicitHeight: body.implicitHeight + 32
  color: "transparent"
  surfaceFormat.opaque: false
  grabFocus: false
  visible: shown && applications.length > 0 && trigger.visible

  onHoveredChanged: {
    if (hovered)
      openDelay.restart()
    else
      openDelay.stop()
  }

  Connections {
    target: popup.trigger
    function onClicked() {
      openDelay.stop()
      popup.shown = false
    }
  }

  Timer {
    id: openDelay
    interval: 350
    onTriggered: popup.shown = true
  }

  Timer {
    interval: 500
    running: popup.shown && !popup.hovered && !surfaceHover.hovered
    onTriggered: popup.shown = false
  }

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: popup.controller.controlBackground
    border.color: popup.controller.controlBorder

    HoverHandler { id: surfaceHover }

    Column {
      id: body
      x: 16
      y: 16
      width: parent.width - 32
      spacing: 12

      Row {
        width: parent.width
        spacing: 10

        LucideIcon {
          width: 18
          height: 18
          anchors.verticalCenter: parent.verticalCenter
          source: popup.controller.icon(popup.iconName)
          color: popup.muted ? popup.controller.controlSecondaryText : popup.controller.controlActiveIcon
        }

        Text {
          width: parent.width - 28
          text: popup.title
          color: popup.controller.controlPrimaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 16
          textFormat: Text.PlainText
        }
      }

      Text {
        width: parent.width
        text: popup.muted ? "Inputs muted · Used by" : "Used by"
        color: popup.controller.controlSecondaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: 12
        wrapMode: Text.Wrap
      }

      Flickable {
        width: parent.width
        height: Math.min(appRows.implicitHeight, 220, Math.max(40, popup.panel.screen.height - 180))
        contentWidth: width
        contentHeight: appRows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: appRows
          width: parent.width
          spacing: 6

          Repeater {
            model: popup.applications

            Rectangle {
              id: appRow
              required property string modelData
              width: appRows.width
              height: appText.implicitHeight + 20
              radius: 8
              color: popup.controller.controlSurface

              Column {
                id: appText
                x: 12
                y: 10
                width: parent.width - 24
                spacing: 6

                Text {
                  width: parent.width
                  text: appRow.modelData
                  textFormat: Text.PlainText
                  wrapMode: Text.Wrap
                  color: popup.controller.controlPrimaryText
                  font.family: popup.controller.fontFamily
                  font.pixelSize: 13
                }

                Text {
                  width: parent.width
                  text: popup.applicationDetails[appRow.modelData] || ""
                  visible: text.length > 0
                  textFormat: Text.PlainText
                  wrapMode: Text.Wrap
                  color: popup.controller.controlSecondaryText
                  font.family: popup.controller.fontFamily
                  font.pixelSize: 12
                }
              }
            }
          }
        }

        Controls.ScrollBar.vertical: Controls.ScrollBar {
          policy: Controls.ScrollBar.AsNeeded
        }
      }
    }
  }
}

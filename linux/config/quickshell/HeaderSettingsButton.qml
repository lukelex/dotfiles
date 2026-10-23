pragma ComponentBehavior: Bound

import QtQuick
import "DesignTokens.js" as Design
import QtQuick.Controls.Basic as Controls

Controls.Button {
  id: button
  required property var controller
  required property string description
  property bool keyboardEnabled: true
  property var options: []
  signal opening()
  signal activated()
  width: Design.panel.headerHeight
  height: Design.panel.headerHeight
  focusPolicy: keyboardEnabled ? Qt.StrongFocus : Qt.NoFocus
  Accessible.name: description
  onClicked: {
    opening()
    if (options.length)
      menu.popup()
    else
      activated()
  }
  background: Rectangle {
    radius: Design.radius.control
    color: button.hovered ? button.controller.controlSurface : "transparent"
    border.width: button.activeFocus ? Design.stroke.focus : 0
    border.color: button.controller.controlActiveIcon
  }
  contentItem: Item {
    LucideIcon {
      anchors.centerIn: parent
      width: Design.icon.header
      height: Design.icon.header
      color: button.controller.controlPrimaryText
      source: button.controller.icon("settings")
    }
  }
  Controls.ToolTip {
    visible: button.hovered || button.activeFocus
    delay: Design.motion.tooltipDelay
    text: button.description
    contentItem: Text {
      text: button.description
      textFormat: Text.PlainText
      font.family: button.controller.fontFamily
      font.pixelSize: Design.typography.caption
      color: button.controller.controlPrimaryText
    }
    background: Rectangle { radius: Design.radius.tooltip; color: button.controller.controlSurface; border.color: button.controller.controlSurfaceBorder }
  }
  Controls.Menu {
    id: menu
    x: button.width - width
    y: button.height + 4
    width: 240
    background: Rectangle { radius: Design.radius.menu; color: button.controller.controlSurface; border.color: button.controller.controlSurfaceBorder }
    Repeater {
      model: button.options
      delegate: Controls.MenuItem {
        id: entry
        required property var modelData
        text: modelData.text
        onTriggered: modelData.run()
        contentItem: Text {
          text: entry.text
          textFormat: Text.PlainText
          font.family: button.controller.fontFamily
          font.pixelSize: Design.typography.body
          color: button.controller.controlPrimaryText
        }
        background: Rectangle { radius: 7; color: entry.highlighted ? button.controller.controlHover : "transparent" }
      }
    }
  }
}

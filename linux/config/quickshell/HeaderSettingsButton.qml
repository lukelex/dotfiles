pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Button {
  id: button
  required property var controller
  required property string description
  property bool keyboardEnabled: true
  property var options: []
  signal opening()
  signal activated()
  width: 32
  height: 32
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
    radius: 8
    color: button.hovered ? button.controller.controlSurface : "transparent"
    border.width: button.activeFocus ? 2 : 0
    border.color: button.controller.controlActiveIcon
  }
  contentItem: Item {
    LucideIcon {
      anchors.centerIn: parent
      width: 16
      height: 16
      color: button.controller.controlPrimaryText
      source: button.controller.icon("settings")
    }
  }
  Controls.ToolTip {
    visible: button.hovered || button.activeFocus
    delay: 500
    text: button.description
    contentItem: Text {
      text: button.description
      textFormat: Text.PlainText
      font.family: button.controller.fontFamily
      font.pixelSize: 11
      color: button.controller.controlPrimaryText
    }
    background: Rectangle { radius: 7; color: button.controller.controlSurface; border.color: button.controller.controlSurfaceBorder }
  }
  Controls.Menu {
    id: menu
    x: button.width - width
    y: button.height + 4
    width: 240
    background: Rectangle { radius: 10; color: button.controller.controlSurface; border.color: button.controller.controlSurfaceBorder }
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
          font.pixelSize: 12
          color: button.controller.controlPrimaryText
        }
        background: Rectangle { radius: 7; color: entry.highlighted ? button.controller.controlHover : "transparent" }
      }
    }
  }
}

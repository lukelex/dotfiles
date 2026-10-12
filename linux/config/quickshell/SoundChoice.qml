pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.ComboBox {
  id: choice
  required property var controller
  required property bool keyboardEnabled
  required property var choices
  required property string selected
  required property string label
  signal chosen(var option)
  signal interacted()
  width: parent.width
  height: 36
  model: choices
  textRole: "description"
  currentIndex: choices.findIndex(option => option.name === selected)
  displayText: currentIndex < 0 ? label + ": unavailable" : label + ": " + choices[currentIndex].description
  focusPolicy: keyboardEnabled ? Qt.StrongFocus : Qt.NoFocus
  Accessible.name: label
  onPressedChanged: { if (pressed) interacted() }
  onActivated: index => chosen(choices[index])
  background: Rectangle {
    radius: 10
    color: choice.controller.controlSurface
    border.width: choice.activeFocus ? 2 : 1
    border.color: choice.activeFocus ? choice.controller.controlActiveIcon : choice.controller.controlSurfaceBorder
  }
  component Label: Text {
    textFormat: Text.PlainText
    font.family: choice.controller.fontFamily
    font.pixelSize: 12
    color: choice.controller.controlPrimaryText
    elide: Text.ElideRight
  }
  contentItem: Label {
    leftPadding: 10
    rightPadding: 28
    text: choice.displayText
    verticalAlignment: Text.AlignVCenter
  }
  delegate: Controls.ItemDelegate {
    id: option
    required property var modelData
    width: choice.width
    contentItem: Label { text: option.modelData.description }
    background: Rectangle { color: option.hovered || option.highlighted ? choice.controller.controlHover : choice.controller.controlSurface }
  }
  popup: Controls.Popup {
    y: choice.height
    width: choice.width
    padding: 4
    implicitHeight: Math.min(220, contentItem.implicitHeight + 8)
    background: Rectangle { color: choice.controller.controlSurface; radius: 10; border.color: choice.controller.controlSurfaceBorder }
    contentItem: ListView {
      implicitHeight: contentHeight
      clip: true
      model: choice.popup.visible ? choice.delegateModel : null
      currentIndex: choice.highlightedIndex
      Controls.ScrollBar.vertical: Controls.ScrollBar {}
    }
  }
}

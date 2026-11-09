import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.AbstractButton {
  id: button

  required property var controller
  property string iconName: ""
  property int iconSize: 14
  property string description: text
  property bool keyboardEnabled: true
  property real maximumWidth: implicitWidth
  property color foregroundColor: controller.controlPrimaryText

  implicitWidth: text ? label.implicitWidth + 20 : 28
  implicitHeight: Math.max(28, text ? label.implicitHeight + 12 : iconSize + 12)
  width: Math.min(implicitWidth, maximumWidth)
  height: implicitHeight
  hoverEnabled: true
  focusPolicy: keyboardEnabled ? Qt.StrongFocus : Qt.NoFocus
  onKeyboardEnabledChanged: { if (!keyboardEnabled) focus = false }
  opacity: enabled ? 1 : 0.45
  Accessible.name: description
  Accessible.onPressAction: { if (enabled) clicked() }
  Keys.onReturnPressed: event => { if (!event.isAutoRepeat && enabled) clicked() }
  Keys.onEnterPressed: event => { if (!event.isAutoRepeat && enabled) clicked() }

  background: Rectangle {
    radius: 7
    color: button.down ? button.controller.controlSliderTrack
      : button.hovered ? button.controller.controlHover : button.controller.controlBackground
    border.width: 1
    border.color: button.activeFocus ? button.controller.controlActiveIcon : button.controller.controlSurfaceBorder
  }

  contentItem: Item {
    Text {
      id: label
      anchors.centerIn: parent
      width: Math.max(1, button.width - 20)
      text: button.text
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      horizontalAlignment: Text.AlignHCenter
      visible: text.length > 0
      color: button.foregroundColor
      font.family: button.controller.fontFamily
      font.pixelSize: 11
    }
    LucideIcon {
      anchors.centerIn: parent
      width: button.iconSize
      height: width
      visible: !button.text && button.iconName !== ""
      source: visible ? button.controller.icon(button.iconName) : ""
      color: button.foregroundColor
    }
  }

  Controls.ToolTip {
    parent: button
    x: button.width - implicitWidth
    y: -implicitHeight - 6
    delay: 500
    padding: 8
    visible: button.enabled && button.description !== "" && (button.hovered || button.activeFocus)
    text: button.description
    contentItem: Text {
      text: button.description
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      width: Math.min(280, implicitWidth)
      color: button.controller.controlPrimaryText
      font.family: button.controller.fontFamily
      font.pixelSize: 11
    }
    background: Rectangle {
      color: button.controller.controlSurface
      border.color: button.controller.controlSurfaceBorder
      radius: 7
    }
  }
  HoverHandler { cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "DesignTokens.js" as Design

Controls.TextField {
  id: input
  required property var controller
  implicitHeight: 36
  padding: 8
  font.family: controller.fontFamily
  font.pixelSize: Design.typography.body
  color: controller.controlPrimaryText
  placeholderTextColor: controller.controlSecondaryText
  selectionColor: controller.controlActive
  selectedTextColor: controller.controlPrimaryText
  selectByMouse: true
  opacity: enabled ? 1 : 0.45
  background: Rectangle {
    radius: Design.radius.control
    color: input.controller.controlSurface
    border.width: input.activeFocus ? Design.stroke.focus : Design.stroke.outline
    border.color: input.activeFocus ? input.controller.controlActiveIcon : input.controller.controlSurfaceBorder
  }
  SettingsHint {
    controller: input.controller
    text: input.text
    visible: input.echoMode === TextInput.Normal && input.contentWidth > input.width - input.leftPadding - input.rightPadding
      && (input.hovered || input.activeFocus)
  }
}

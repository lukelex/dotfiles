pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "DesignTokens.js" as Design

Controls.Button {
  id: button
  required property var controller
  property string iconName: ""
  property string description: text
  property bool showHint: text === "" || description !== text
  property bool quiet: false
  implicitHeight: 36
  implicitWidth: Math.max(36, implicitContentWidth + leftPadding + rightPadding)
  padding: Design.spacing.small
  focusPolicy: Qt.StrongFocus
  opacity: enabled ? 1 : 0.45
  Accessible.name: description
  contentItem: RowLayout {
    spacing: Design.spacing.small
    LucideIcon {
      Layout.preferredWidth: Design.icon.header
      Layout.preferredHeight: Design.icon.header
      visible: button.iconName !== ""
      source: button.iconName ? button.controller.icon(button.iconName) : ""
      color: button.controller.controlPrimaryText
    }
    Text {
      id: label
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      visible: button.text !== ""
      text: button.text
      textFormat: Text.PlainText
      font.family: button.controller.fontFamily
      font.pixelSize: Design.typography.body
      color: button.controller.controlPrimaryText
      elide: Text.ElideRight
      horizontalAlignment: button.iconName ? Text.AlignLeft : Text.AlignHCenter
    }
  }
  background: Rectangle {
    radius: Design.radius.control
    color: button.down || button.hovered ? button.controller.controlHover
      : button.quiet ? "transparent" : button.controller.controlSurface
    border.width: button.activeFocus ? Design.stroke.focus : button.quiet ? 0 : Design.stroke.outline
    border.color: button.activeFocus ? button.controller.controlActiveIcon : button.controller.controlSurfaceBorder
  }
  SettingsHint {
    controller: button.controller
    text: button.description
    visible: (button.showHint || label.truncated) && text !== "" && (button.hovered || button.activeFocus)
  }
}

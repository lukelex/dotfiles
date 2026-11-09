pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import "DesignTokens.js" as Design

Controls.ToolTip {
  id: hint
  required property var controller
  delay: Design.motion.tooltipDelay
  padding: Design.spacing.small
  implicitWidth: Math.min(320, (parent?.Window.window?.width ?? 352) - 32, contentItem.implicitWidth + padding * 2)
  contentItem: Text {
    text: hint.text
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    font.family: hint.controller.fontFamily
    font.pixelSize: Design.typography.caption
    color: hint.controller.controlPrimaryText
  }
  background: Rectangle {
    radius: Design.radius.tooltip
    color: hint.controller.controlSurface
    border.color: hint.controller.controlSurfaceBorder
  }
}

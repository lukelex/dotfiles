import QtQuick
import "DesignTokens.js" as Design

// Visual shell only: the owning panel retains geometry, input and lifecycle.
Rectangle {
  required property var controller
  color: controller.controlBackground
  border.color: controller.controlBorder
  border.width: Design.stroke.outline
  radius: Design.radius.panel
}

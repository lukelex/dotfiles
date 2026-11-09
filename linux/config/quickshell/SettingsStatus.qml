import QtQuick
import QtQuick.Layouts
import "DesignTokens.js" as Design

Text {
  required property var controller
  property bool failed: false
  font.family: controller.fontFamily
  font.pixelSize: Design.typography.body
  textFormat: Text.PlainText
  wrapMode: Text.Wrap
  Layout.fillWidth: true
  visible: text !== ""
  color: failed ? controller.controlWarningText : controller.controlSecondaryText
}

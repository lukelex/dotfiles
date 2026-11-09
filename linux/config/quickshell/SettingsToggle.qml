pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "DesignTokens.js" as Design

Controls.Switch {
  id: toggle
  required property var controller
  property string description: ""
  property bool showHint: true
  property string iconName: ""
  Accessible.description: description
  hoverEnabled: true
  implicitHeight: Math.max(36, contentItem.implicitHeight)
  spacing: Design.spacing.small
  padding: 0
  opacity: enabled ? 1 : 0.45
  SettingsHint {
    controller: toggle.controller
    text: toggle.description
    visible: toggle.showHint && text !== "" && (toggle.hovered || toggle.activeFocus)
  }
  indicator: Rectangle {
    x: toggle.width - width
    y: (toggle.height - height) / 2
    implicitWidth: 36
    implicitHeight: 20
    radius: 10
    color: toggle.checked ? toggle.controller.controlActive : toggle.controller.controlSliderTrack
    border.width: toggle.activeFocus ? Design.stroke.focus : Design.stroke.outline
    border.color: toggle.activeFocus ? toggle.controller.controlActiveIcon : toggle.controller.controlSurfaceBorder
    Rectangle {
      x: toggle.checked ? 18 : 2
      y: 2
      width: 16
      height: 16
      radius: 8
      color: toggle.controller.controlPrimaryText
    }
  }
  contentItem: Text {
    text: toggle.text
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    font.family: toggle.controller.fontFamily
    font.pixelSize: Design.typography.body
    color: toggle.controller.controlPrimaryText
    leftPadding: toggle.iconName ? 28 : 0
    rightPadding: 44
    verticalAlignment: Text.AlignVCenter
    LucideIcon {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18
      visible: toggle.iconName !== ""
      source: toggle.iconName ? toggle.controller.icon(toggle.iconName) : ""
      color: toggle.controller.controlSecondaryText
    }
  }
}

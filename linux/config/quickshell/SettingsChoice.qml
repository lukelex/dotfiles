pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "DesignTokens.js" as Design

Controls.ComboBox {
  id: choice
  required property var controller
  readonly property var hostWindow: Window.window
  readonly property real preferredEditorWidth: Math.max(140, ...Array.from({ length: model ? count : 0 }, (_, index) => metrics.advanceWidth(textAt(index)) + 56))
  implicitHeight: 36
  implicitWidth: preferredEditorWidth
  Layout.minimumWidth: 0
  font.family: controller.fontFamily
  font.pixelSize: Design.typography.body
  opacity: enabled ? 1 : 0.45
  FontMetrics { id: metrics; font: choice.font }
  contentItem: Text {
    id: selectedLabel
    text: choice.displayText
    textFormat: Text.PlainText
    font: choice.font
    color: choice.controller.controlPrimaryText
    leftPadding: 8
    rightPadding: 28
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }
  indicator: LucideIcon {
    x: choice.width - width - 10
    y: (choice.height - height) / 2
    width: 16
    height: 16
    source: choice.controller.icon("chevron-right")
    rotation: 90
    color: choice.controller.controlSecondaryText
  }
  background: Rectangle {
    radius: Design.radius.control
    color: choice.hovered ? choice.controller.controlHover : choice.controller.controlSurface
    border.width: choice.activeFocus ? Design.stroke.focus : Design.stroke.outline
    border.color: choice.activeFocus ? choice.controller.controlActiveIcon : choice.controller.controlSurfaceBorder
  }
  SettingsHint {
    controller: choice.controller
    text: choice.displayText
    visible: selectedLabel.truncated && (choice.hovered || choice.activeFocus) && !choice.popup.visible
  }
  delegate: Controls.ItemDelegate {
    id: option
    required property int index
    width: choice.width - 8
    implicitHeight: Math.max(36, contentItem.implicitHeight + 16)
    padding: 8
    highlighted: choice.highlightedIndex === index
    Accessible.name: choice.textAt(index)
    contentItem: RowLayout {
      spacing: 8
      Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: choice.textAt(option.index)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font: choice.font
        color: choice.controller.controlPrimaryText
      }
      LucideIcon {
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        source: choice.controller.icon("circle-check")
        visible: choice.currentIndex === option.index
        color: choice.controller.controlPrimaryText
      }
    }
    background: Rectangle {
      radius: 6
      color: choice.currentIndex === option.index ? choice.controller.controlActive
        : option.highlighted || option.hovered ? choice.controller.controlHover : choice.controller.controlSurface
    }
  }
  popup: Controls.Popup {
    y: choice.height + 4
    width: choice.width
    padding: 4
    implicitHeight: Math.min(contentItem.implicitHeight + 8, 240, (choice.hostWindow?.height ?? 640) - 80)
    contentItem: ListView {
      clip: true
      implicitHeight: contentHeight
      model: choice.popup.visible ? choice.delegateModel : null
      currentIndex: choice.highlightedIndex
      boundsBehavior: Flickable.StopAtBounds
      Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
    }
    background: Rectangle {
      radius: Design.radius.control
      color: choice.controller.controlSurface
      border.color: choice.controller.controlBorder
    }
  }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls

Row {
  id: module
  required property var controller
  required property var devices

  spacing: 8

  Repeater {
    model: module.devices

    delegate: Item {
      id: deviceWidget
      required property var modelData
      readonly property string description: modelData.name + ": "
        + (modelData.percentage === null ? "Battery percentage unavailable" : modelData.percentage + "%")
        + (modelData.charging ? " · Charging" : modelData.percentage !== null && modelData.percentage < 15 ? " · Battery low" : "")
      height: module.controller.barFontSize
      width: deviceRow.width
      Accessible.role: Accessible.StatusBar
      Accessible.name: description

      Row {
        id: deviceRow
        spacing: 4
        LucideIcon {
          width: module.controller.barFontSize
          height: module.controller.barFontSize
          source: module.controller.icon("headphones")
          color: deviceWidget.modelData.percentage !== null && deviceWidget.modelData.percentage < 15
            && !deviceWidget.modelData.charging ? module.controller.urgent : module.controller.foreground
        }
        Text {
          visible: deviceWidget.modelData.percentage !== null
          text: deviceWidget.modelData.percentage === null ? "" : deviceWidget.modelData.percentage + "%"
          font.family: module.controller.fontFamily
          font.pixelSize: module.controller.barFontSize
          color: module.controller.foreground
        }
        LucideIcon {
          visible: deviceWidget.modelData.charging
          width: module.controller.barFontSize
          height: module.controller.barFontSize
          source: module.controller.icon("battery-charging")
          color: module.controller.foreground
        }
      }
      MouseArea {
        id: deviceHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
      }
      Controls.ToolTip {
        visible: deviceHover.containsMouse
        delay: 500
        text: deviceWidget.description
        contentItem: Text {
          text: deviceWidget.description
          textFormat: Text.PlainText
          font.family: module.controller.fontFamily
          font.pixelSize: 11
          color: module.controller.controlPrimaryText
        }
        background: Rectangle {
          radius: 7
          color: module.controller.controlSurface
          border.color: module.controller.controlSurfaceBorder
        }
      }
    }
  }
}

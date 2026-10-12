pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Scope {
  id: rootIdentify
  required property var controller
  required property var outputs
  function identify() { duration.restart() }
  Timer { id: duration; interval: 3500 }
  Variants {
    model: duration.running ? Quickshell.screens : []
    PanelWindow {
      id: labelWindow
      required property var modelData
      screen: modelData
      anchors.top: true
      margins { top: 100 }
      implicitWidth: 300
      implicitHeight: 100
      exclusiveZone: 0
      focusable: false
      color: "transparent"
      Rectangle {
        anchors.fill: parent
        radius: 16
        color: rootIdentify.controller.controlBackground
        border.color: rootIdentify.controller.controlActiveIcon
        Text {
          anchors.centerIn: parent
          text: (rootIdentify.outputs.findIndex(o => o.connector === labelWindow.modelData.name) + 1) + " · " + labelWindow.modelData.name
          font.family: rootIdentify.controller.fontFamily
          font.pixelSize: 24
          color: rootIdentify.controller.controlPrimaryText
        }
      }
    }
  }
}

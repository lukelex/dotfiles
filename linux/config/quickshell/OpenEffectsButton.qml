pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: effects
  required property var controller
  required property var service
  height: effects.controller.barFontSize
  width: effects.controller.barFontSize
  readonly property bool available: effects.service.available || effects.service.pending || effects.service.error.length > 0

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: 4
    color: effectsHover.containsMouse ? effects.controller.controlHover : "transparent"
  }
  LucideIcon {
    anchors.fill: parent
    source: effects.controller.icon(effects.service.pending ? "refresh-cw" : "sparkles")
    color: effects.service.error ? effects.controller.urgent
      : !effects.service.available || effects.service.bypass ? effects.controller.muted : effects.controller.controlActiveIcon
  }
  Rectangle {
    anchors.centerIn: parent
    width: effects.controller.barFontSize + 2
    height: 2
    rotation: -45
    color: effects.controller.muted
    visible: effects.service.available && effects.service.bypass && !effects.service.pending
  }
  MouseArea {
    id: effectsHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: effects.service.pending ? Qt.BusyCursor : Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: effects.service.description
    Accessible.onPressAction: effects.service.toggle()
    onEntered: effects.service.refresh()
    onClicked: effects.service.toggle()
  }
}

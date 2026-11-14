pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

GridLayout {
  id: entry
  required property var controller
  required property string title
  property string iconName: "bluetooth"
  property color iconColor: controller.controlSecondaryText
  property bool current: false
  property bool locked: false
  property bool narrow: width < 370
  property Component actionDelegate: null
  default property alias details: detailContent.data
  columns: narrow ? 2 : 3
  columnSpacing: 12
  rowSpacing: 8

  Item {
    Layout.preferredWidth: 28
    Layout.preferredHeight: 32
    LucideIcon {
      anchors.centerIn: parent
      width: 22
      height: 22
      source: entry.controller.icon(entry.current ? "circle-check" : entry.iconName)
      color: entry.current ? entry.controller.controlActiveIcon : entry.iconColor
    }
    Rectangle {
      visible: entry.locked && !entry.current
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: 14
      height: 14
      radius: 4
      color: entry.controller.controlSurface
      LucideIcon {
        anchors.centerIn: parent
        width: 10
        height: 10
        source: entry.controller.icon("lock")
        color: entry.controller.controlSecondaryText
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: 4
    Text {
      Layout.fillWidth: true
      text: entry.title
      color: entry.controller.controlPrimaryText
      font.family: entry.controller.fontFamily
      font.pixelSize: entry.current ? 14 : 12
      font.bold: entry.current
      textFormat: Text.PlainText
      elide: Text.ElideRight
    }
    ColumnLayout {
      id: detailContent
      Layout.fillWidth: true
      spacing: 0
    }
  }
  Loader {
    Layout.columnSpan: entry.narrow ? 2 : 1
    Layout.alignment: Qt.AlignRight
    sourceComponent: entry.actionDelegate
  }
}

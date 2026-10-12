pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls

Rectangle {
  id: subsection
  required property var controller
  required property string title
  required property string iconName
  property string description: title
  property bool collapsible: false
  property bool expanded: true
  property bool framed: true
  default property alias contents: subsectionBody.data
  signal toggled()
  implicitHeight: subsectionContent.implicitHeight + 28
  radius: 18
  color: framed ? controller.controlSurface : "transparent"
  border.width: framed ? 1 : 0
  border.color: controller.controlSurfaceBorder
  ColumnLayout {
    id: subsectionContent
    anchors.fill: parent
    anchors.margins: 14
    spacing: 14
    Controls.Button {
      id: subsectionHeader
      Layout.fillWidth: true
      padding: 0
      implicitHeight: Math.max(32, contentItem.implicitHeight)
      enabled: subsection.collapsible
      Accessible.name: subsection.title
      Accessible.description: subsection.description
      Accessible.role: subsection.collapsible ? Accessible.Button : Accessible.Heading
      Accessible.checkable: subsection.collapsible
      Accessible.checked: subsection.expanded
      onClicked: subsection.toggled()
      contentItem: RowLayout {
        spacing: 10
        LucideIcon {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          source: subsection.controller.icon(subsection.iconName)
          color: subsection.controller.controlActiveIcon
        }
        Text {
          Layout.fillWidth: true
          text: subsection.title
          font.family: subsection.controller.fontFamily
          font.pixelSize: 14
          font.bold: true
          color: subsection.controller.controlPrimaryText
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
        }
        LucideIcon {
          Layout.preferredWidth: 16
          Layout.preferredHeight: 16
          visible: subsection.collapsible
          source: subsection.controller.icon("chevron-right")
          rotation: subsection.expanded ? 90 : 0
          color: subsection.controller.controlSecondaryText
        }
      }
      background: Rectangle {
        radius: 8
        color: subsectionHeader.hovered ? subsection.controller.controlHover : "transparent"
        border.width: subsectionHeader.activeFocus ? 1 : 0
        border.color: subsection.controller.controlActiveIcon
      }
    }
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      visible: subsection.expanded
      color: subsection.controller.controlSurfaceBorder
    }
    ColumnLayout {
      id: subsectionBody
      Layout.fillWidth: true
      visible: subsection.expanded
      spacing: 12
    }
  }
}

pragma ComponentBehavior: Bound

import QtQuick
import "DesignTokens.js" as Design
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
  implicitHeight: subsectionContent.implicitHeight + Design.spacing.card * 2
  radius: Design.radius.card
  color: framed ? controller.controlSurface : "transparent"
  border.width: framed ? 1 : 0
  border.color: controller.controlSurfaceBorder
  ColumnLayout {
    id: subsectionContent
    anchors.fill: parent
    anchors.margins: Design.spacing.card
    spacing: Design.spacing.card
    Controls.Button {
      id: subsectionHeader
      Layout.fillWidth: true
      padding: 0
      implicitHeight: Math.max(Design.panel.headerHeight, contentItem.implicitHeight)
      enabled: subsection.collapsible
      Accessible.name: subsection.title
      Accessible.description: subsection.description
      Accessible.role: subsection.collapsible ? Accessible.Button : Accessible.Heading
      Accessible.checkable: subsection.collapsible
      Accessible.checked: subsection.expanded
      onClicked: subsection.toggled()
      contentItem: RowLayout {
        spacing: Design.spacing.related
        LucideIcon {
          Layout.preferredWidth: Design.icon.section
          Layout.preferredHeight: Design.icon.section
          source: subsection.controller.icon(subsection.iconName)
          color: subsection.controller.controlActiveIcon
        }
        Text {
          Layout.fillWidth: true
          text: subsection.title
          font.family: subsection.controller.fontFamily
          font.pixelSize: Design.typography.section
          font.bold: true
          color: subsection.controller.controlPrimaryText
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
        }
        LucideIcon {
          Layout.preferredWidth: Design.icon.header
          Layout.preferredHeight: Design.icon.header
          visible: subsection.collapsible
          source: subsection.controller.icon("chevron-right")
          rotation: subsection.expanded ? 90 : 0
          color: subsection.controller.controlSecondaryText
        }
      }
      background: Rectangle {
        radius: Design.radius.control
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
      spacing: Design.spacing.row
    }
  }
}

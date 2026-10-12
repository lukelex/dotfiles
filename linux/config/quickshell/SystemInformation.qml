pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell.Io
import "SystemInformation.js" as Information

ColumnLayout {
  id: page
  required property var controller
  property bool active: false
  property var snapshot: null
  property string error: ""
  property bool loading: false
  spacing: 12

  onActiveChanged: {
    if (active) {
      scroll.contentItem.contentY = 0
      refresh()
    }
  }
  function refresh() {
    if (loading) return
    error = ""
    loading = true
    fetch.running = true
  }

  Process {
    id: fetch
    command: ["fastfetch", "--config", "none", "--structure",
      "Title:OS:Host:Kernel:Uptime:Packages:Display:DE:WM:CPU:GPU:Memory:Swap:Disk", "--format", "json"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!page.loading) return
        try {
          page.snapshot = Information.normalize(JSON.parse(text))
        } catch (error) {
          page.error = "Unable to read system information. Try refreshing."
        }
      }
    }
    onExited: code => {
      if (page.loading && code !== 0)
        page.error = "Fastfetch could not load system information. Try refreshing."
      page.loading = false
    }
  }
  Timer {
    interval: 15000
    running: page.loading
    onTriggered: {
      page.loading = false
      fetch.running = false
      page.error = "System information request timed out. Try refreshing."
    }
  }

  component Label: Text {
    color: page.controller.controlPrimaryText
    font.family: page.controller.fontFamily
    font.pixelSize: 12
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  component InfoRow: ColumnLayout {
    id: infoRow
    required property var entry
    spacing: 8
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      LucideIcon {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        Layout.alignment: Qt.AlignTop
        source: page.controller.icon(infoRow.entry.icon)
        color: page.controller.controlSecondaryText
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Label {
          Layout.fillWidth: true
          text: infoRow.entry.label
          color: page.controller.controlSecondaryText
          font.pixelSize: 11
        }
        Label { Layout.fillWidth: true; text: infoRow.entry.value }
      }
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: 28
      implicitHeight: 6
      radius: 3
      visible: infoRow.entry.usage >= 0
      color: page.controller.controlSliderTrack
      Rectangle {
        width: parent.width * Math.max(0, infoRow.entry.usage)
        height: parent.height
        radius: 3
        color: page.controller.controlSecondaryText
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Label { Layout.fillWidth: true; text: "System information"; font.pixelSize: 16; font.bold: true }
    Controls.Button {
      id: refreshButton
      implicitWidth: 32
      implicitHeight: 32
      padding: 8
      enabled: !page.loading
      Accessible.name: "Refresh system information"
      onClicked: page.refresh()
      Controls.ToolTip.text: Accessible.name
      Controls.ToolTip.visible: hovered
      contentItem: LucideIcon {
        source: page.controller.icon("refresh-cw")
        color: page.controller.controlSecondaryText
      }
      background: Rectangle {
        radius: 10
        color: refreshButton.hovered ? page.controller.controlHover : page.controller.controlSurface
        border.color: refreshButton.activeFocus ? page.controller.controlActiveIcon : page.controller.controlSurfaceBorder
      }
    }
  }
  Label {
    Layout.fillWidth: true
    text: page.error ? page.error + (page.snapshot ? " Showing previous snapshot." : "")
      : page.loading ? "Loading system information…" : ""
    visible: text !== ""
    color: page.error ? page.controller.controlWarningText : page.controller.controlSecondaryText
    font.pixelSize: 11
  }
  Controls.ScrollView {
    id: scroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: availableWidth
    clip: true
    Binding {
      target: scroll.contentItem
      property: "boundsBehavior"
      value: Flickable.StopAtBounds
    }
    ColumnLayout {
      width: scroll.availableWidth
      spacing: 16
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: summary.implicitHeight + 32
        visible: page.snapshot !== null
        radius: 18
        color: page.controller.controlSurface
        border.color: page.controller.controlSurfaceBorder
        RowLayout {
          id: summary
          anchors.fill: parent
          anchors.margins: 16
          spacing: 14
          LucideIcon {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            source: page.controller.icon("monitor")
            color: page.controller.controlActiveIcon
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Label { Layout.fillWidth: true; text: page.snapshot?.hostname || ""; font.pixelSize: 18; font.bold: true }
            Label { Layout.fillWidth: true; text: page.snapshot?.model || ""; visible: text !== "" }
            Label { Layout.fillWidth: true; text: page.snapshot?.os || ""; color: page.controller.controlSecondaryText }
          }
        }
      }
      Repeater {
        model: page.snapshot?.groups || []
        delegate: Rectangle {
          id: group
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: groupContent.implicitHeight + 28
          radius: 18
          color: page.controller.controlSurface
          border.color: page.controller.controlSurfaceBorder
          ColumnLayout {
            id: groupContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14
            RowLayout {
              spacing: 10
              LucideIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: page.controller.icon(group.modelData.icon)
                color: page.controller.controlActiveIcon
              }
              Label { text: group.modelData.title; font.pixelSize: 14; font.bold: true }
            }
            Repeater {
              model: group.modelData.rows
              delegate: ColumnLayout {
                id: detail
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: page.controller.controlSurfaceBorder }
                InfoRow { Layout.fillWidth: true; entry: detail.modelData }
              }
            }
          }
        }
      }
      Rectangle {
        Layout.fillWidth: true
        visible: page.controller.batteryAvailable
        implicitHeight: batteryContent.implicitHeight + 28
        radius: 18
        color: page.controller.controlSurface
        border.color: page.controller.controlSurfaceBorder
        ColumnLayout {
          id: batteryContent
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12
          Label { text: "Power"; font.pixelSize: 14; font.bold: true }
          InfoRow {
            Layout.fillWidth: true
            entry: ({ icon: page.controller.batteryIcon(), label: "Battery",
              value: page.controller.batteryPercentage + "% · " + page.controller.batteryState.replace(/-/g, " ")
                + (page.controller.batteryHealthAvailable ? " · Health " + Math.round(page.controller.batteryHealth) + "%" : ""),
              usage: page.controller.batteryPercentage / 100 })
          }
        }
      }
    }
  }
}

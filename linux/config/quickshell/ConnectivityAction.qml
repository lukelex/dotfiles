pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
  required property var host
  id: action
  required property string title
  property string subtitle: ""
  property string qualityText: ""
  property color qualityColor: action.host.controller.controlSecondaryText
  property string iconName: ""
  property bool active: false
  property bool radioSwitch: false
  property bool showTraffic: false
  property bool wiredTraffic: false
  property string trafficDeviceName: ""
  property string detail: title + (subtitle ? "\n" + subtitle : "")
  readonly property bool compactTraffic: showTraffic && width < 360
  readonly property bool showIcon: iconName !== "" && (!compactTraffic || width >= 300)
  signal activated()

  height: subtitle ? 64 : 40
  radius: 14
  color: active ? action.host.controller.controlActive : area.containsMouse ? action.host.controller.controlHover : action.host.controller.controlSurface
  border.width: 1
  border.color: action.host.controller.controlSurfaceBorder
  opacity: enabled || active ? 1 : 0.55
  activeFocusOnTab: enabled && action.host.pinned
  Accessible.role: radioSwitch ? Accessible.CheckBox : Accessible.Button
  Accessible.name: title
  Accessible.description: detail
  Accessible.checkable: radioSwitch
  Accessible.checked: active
  Accessible.onPressAction: activated()
  Keys.onSpacePressed: activated()
  Keys.onReturnPressed: activated()

  LucideIcon {
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 18
    height: 18
    visible: action.showIcon
    source: action.iconName ? action.host.controller.icon(action.iconName) : ""
    color: action.host.controller.controlPrimaryText
  }

  Column {
    id: actionLabels
    anchors.left: parent.left
    anchors.leftMargin: action.showIcon ? 40 : 12
    anchors.right: action.showTraffic ? trafficColumn.left : parent.right
    anchors.rightMargin: action.showTraffic ? 8 : action.radioSwitch ? 66 : 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 3

    HoverHandler { id: labelHover }
    ConnectivityHint {
      host: action.host
      visible: action.host.visible && (labelHover.hovered || action.activeFocus)
      text: action.detail
    }

    ConnectivityLabel {
      host: action.host
      width: parent.width
      text: action.title
      font.pixelSize: 12
      color: action.host.controller.controlPrimaryText
    }
    Row {
      width: parent.width
      visible: action.subtitle !== ""

      ConnectivityLabel {
        host: action.host
        width: Math.min(implicitWidth, Math.max(0, parent.width - qualityLabel.width))
        text: action.qualityText ? action.subtitle.slice(0, -action.qualityText.length) : action.subtitle
      }
      ConnectivityLabel {
        host: action.host
        id: qualityLabel
        width: Math.min(implicitWidth, parent.width)
        text: action.qualityText
        color: action.qualityColor
      }
    }
  }

  Column {
    id: trafficColumn
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: 66
    width: action.compactTraffic ? Math.min(100, action.width * 0.34) : 116
    visible: action.showTraffic
    spacing: 2

    Repeater {
      model: ["upload", "download"]
      delegate: Row {
        id: trafficRate
        required property string modelData
        readonly property string rate: !action.showTraffic ? "" : action.host.service.formatSpeed(action.host.service.connectionSpeed(action.wiredTraffic, modelData, action.trafficDeviceName))
        width: trafficColumn.width
        height: 20
        spacing: 5
        Accessible.role: Accessible.StaticText
        Accessible.name: (modelData === "download" ? "Download " : "Upload ") + rate
        activeFocusOnTab: action.host.pinned && action.showTraffic
        HoverHandler { id: rateHover }
        ConnectivityHint {
          host: action.host
          visible: action.host.visible && (rateHover.hovered || trafficRate.activeFocus)
          text: (trafficRate.modelData === "download" ? "Download: " : "Upload: ") + trafficRate.rate
            + "\nBytes per second (KiB = 1,024 bytes). Includes local network traffic; this is usage, not available internet bandwidth."
        }

        LucideIcon {
          width: 16
          height: 16
          anchors.verticalCenter: parent.verticalCenter
          source: action.host.controller.icon(trafficRate.modelData === "download" ? "arrow-down" : "arrow-up")
          color: trafficRate.modelData === "download" ? action.host.controller.controlDownloadIcon : action.host.controller.controlUploadIcon
        }
        ConnectivityLabel {
          host: action.host
          width: parent.width - 21
          anchors.verticalCenter: parent.verticalCenter
          text: trafficRate.rate
          color: action.host.controller.controlPrimaryText
          font.pixelSize: 12
          font.bold: true
        }
      }
    }
  }

  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 40
    height: 24
    radius: 12
    visible: action.radioSwitch
    color: action.active ? action.host.controller.controlActiveIcon : action.host.controller.controlSliderTrack
    Rectangle {
      x: action.active ? 19 : 3
      y: 3
      width: 18
      height: 18
      radius: 9
      color: action.host.controller.controlPrimaryText
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: "transparent"
    border.width: 2
    border.color: action.host.controller.controlActiveIcon
    visible: action.activeFocus
  }

  MouseArea {
    id: area
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: action.radioSwitch ? 66 : parent.width
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: action.activated()
  }
}

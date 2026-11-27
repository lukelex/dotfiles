pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Column {
  id: controls
  required property var popup
  required property var closeButtonItem
  spacing: 10

  component Label: ConnectivityLabel { host: controls.popup }
  component Action: ConnectivityAction { host: controls.popup }
  component Hint: ConnectivityHint { host: controls.popup }

  Action {
    width: parent.width
    title: "Bluetooth"
    iconName: "bluetooth"
    radioSwitch: true
    active: controls.popup.service.bluetoothEnabled
    enabled: controls.popup.service.bluetoothAvailable && !controls.popup.service.bluetoothChanging
      && (controls.popup.service.bluetoothEnabled || !controls.popup.service.bluetoothBlocked)
    subtitle: !controls.popup.service.bluetoothAvailable ? "No Bluetooth adapter"
      : controls.popup.service.bluetoothBlocked ? "Hardware blocked"
      : controls.popup.service.bluetoothChanging ? "Updating radio..."
      : controls.popup.service.bluetoothConnecting ? "Connecting..."
      : controls.popup.service.bluetoothEnabled ? "On" : "Off"
    onActivated: {
      controls.popup.requestOpen()
      controls.popup.service.setBluetoothEnabled(!controls.popup.service.bluetoothEnabled)
    }
  }

  Label {
    width: parent.width
    text: "Connected devices"

    font.pixelSize: 12
  }

  Label {
    width: parent.width
    visible: text !== ""
    text: controls.popup.service.bluetoothError
    color: controls.popup.controller.urgent
    elide: Text.ElideNone
    wrapMode: Text.Wrap
  }

  ConnectionDeviceList {
    id: bluetoothScroll

    width: parent.width
    maximumHeight: 140
    entries: controls.popup.service.connectedBluetoothDevices
    keyForEntry: device => device.dbusPath
    panelVisible: controls.popup.visible
    keyboardEnabled: controls.popup.pinned
    focusFallback: controls.closeButtonItem
    delegate: Rectangle {
      id: deviceRow
      required property var entry
      readonly property var modelData: entry
      readonly property string deviceName: modelData ? modelData.name : "Device unavailable"
      width: bluetoothScroll.rowWidth
      height: 48
      radius: 14
      color: controls.popup.controller.controlSurface
      activeFocusOnTab: controls.popup.pinned
      Accessible.role: Accessible.StaticText
      Accessible.name: deviceName + ", " + batteryLabel.text
      HoverHandler { id: deviceHover }
      Hint {
        visible: controls.popup.visible && (deviceHover.hovered || deviceRow.activeFocus)
        text: deviceRow.deviceName + "\n" + batteryLabel.text
      }
      LucideIcon {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        source: controls.popup.controller.icon("bluetooth-connected")
        color: controls.popup.controller.controlActiveIcon
      }
      Label {
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: batteryLabel.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: deviceRow.deviceName
        font.pixelSize: 12
        color: controls.popup.controller.controlPrimaryText
      }
      Label {
        id: batteryLabel
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: !deviceRow.modelData ? "Unavailable" : deviceRow.modelData.batteryAvailable
          ? controls.popup.percentageText(deviceRow.modelData.battery) : "Connected"
        color: deviceRow.modelData && deviceRow.modelData.batteryAvailable
          ? controls.popup.strengthColor(deviceRow.modelData.battery) : controls.popup.controller.controlSecondaryText
      }
    }
  }

  Label {
    width: parent.width
    height: visible ? 30 : 0
    visible: controls.popup.service.connectedBluetoothDevices.length === 0
    text: "No connected devices"
    verticalAlignment: Text.AlignVCenter
  }
}

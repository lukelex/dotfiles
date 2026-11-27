pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking

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
    title: "Wi-Fi"

    showTraffic: controls.popup.service.wifiConnected
    iconName: "wifi"
    radioSwitch: true
    active: controls.popup.service.wifiEnabled
    enabled: controls.popup.service.wifiAvailable && (controls.popup.service.wifiEnabled || controls.popup.service.wifiHardwareEnabled)
    subtitle: !controls.popup.service.wifiAvailable ? "No Wi-Fi adapter"
      : !controls.popup.service.wifiHardwareEnabled ? "Hardware blocked"
      : !controls.popup.service.wifiEnabled ? "Off"
      : controls.popup.service.wifiConnected ? controls.popup.service.wifiSsid + " / " + controls.popup.strengthText(controls.popup.service.wifiStrength)
      : "On / Not connected"
    qualityColor: controls.popup.service.wifiConnected && controls.popup.service.wifiEnabled && controls.popup.service.wifiHardwareEnabled
      ? controls.popup.strengthColor(controls.popup.service.wifiStrength) : controls.popup.controller.controlSecondaryText
    qualityText: controls.popup.service.wifiConnected && controls.popup.service.wifiAvailable && controls.popup.service.wifiEnabled && controls.popup.service.wifiHardwareEnabled
      ? controls.popup.strengthText(controls.popup.service.wifiStrength) : ""
    detail: title + "\n" + subtitle + (controls.popup.service.activeNetwork ? "\nDevice: " + controls.popup.service.activeNetwork.device.name : "")
    onActivated: {
      controls.popup.requestOpen()
      controls.popup.service.setWifiEnabled(!controls.popup.service.wifiEnabled)
    }
  }

  Repeater {
    model: controls.popup.service._wiredDevices.length ? controls.popup.service._wiredDevices : [null]
    delegate: Action {
      required property var modelData
      width: controls.width
      title: controls.popup.service._wiredDevices.length > 1 ? "Ethernet / " + modelData.name : "Ethernet"
      showTraffic: modelData !== null && modelData.connected
      wiredTraffic: true
      trafficDeviceName: modelData ? modelData.name : ""
      iconName: "ethernet-port"
      radioSwitch: true
      active: modelData !== null && modelData.connected
      enabled: modelData !== null && modelData.nmManaged && !controls.popup.service.ethernetBusy
        && modelData.state !== ConnectionState.Connecting
      subtitle: controls.popup.service.ethernetStatus(modelData)
      detail: title + "\n" + subtitle + (modelData ? "\nDevice: " + modelData.name : "")
      onActivated: {
        controls.popup.requestOpen()
        controls.popup.service.setEthernetEnabled(!modelData.connected, modelData)
      }
    }
  }

  Label {
    width: parent.width
    visible: text !== ""
    text: controls.popup.service.ethernetError
    color: controls.popup.controller.urgent
    elide: Text.ElideNone
    wrapMode: Text.Wrap
  }

  Label {
    width: parent.width
    text: "Saved networks"

    font.pixelSize: 12
  }

  Label {
    width: parent.width
    visible: controls.popup.service.wifiConnecting
    text: controls.popup.service.connectingNetwork ? "Connecting to " + controls.popup.service.connectingNetwork.name + "..." : "Connecting..."
  }

  Label {
    width: parent.width
    visible: text !== ""
    text: controls.popup.service.wifiError
    color: controls.popup.controller.urgent
    elide: Text.ElideNone
    wrapMode: Text.Wrap
  }

  ConnectionDeviceList {
    id: wifiScroll

    width: parent.width
    entries: controls.popup.service.savedNetworks
    keyForEntry: network => JSON.stringify([network.device.name, network.name, network.security])
    panelVisible: controls.popup.visible
    keyboardEnabled: controls.popup.pinned
    focusFallback: controls.closeButtonItem
    delegate: Action {
      required property var entry
      readonly property var modelData: entry
      readonly property bool connecting: modelData && (modelData.state === ConnectionState.Connecting
        || controls.popup.service.connectingNetwork === modelData)
      width: wifiScroll.rowWidth
      height: 54
      title: modelData ? modelData.name || "Hidden network" : "Network unavailable"
      detail: title + "\n" + subtitle + (modelData ? "\nDevice: " + modelData.device.name : "")
      subtitle: !modelData ? "Unavailable" : connecting ? "Connecting..."
        : modelData.connected ? "Connected / " + controls.popup.strengthText(modelData.signalStrength)
        : "Saved / " + controls.popup.strengthText(modelData.signalStrength)
      qualityColor: modelData && !connecting
        ? controls.popup.strengthColor(modelData.signalStrength) : controls.popup.controller.controlSecondaryText
      qualityText: modelData && !connecting ? controls.popup.strengthText(modelData.signalStrength) : ""
      iconName: modelData && modelData.connected ? "circle-check" : "wifi"
      active: modelData && (modelData.connected || connecting)
      enabled: modelData !== null && controls.popup.service.wifiEnabled && controls.popup.service.wifiHardwareEnabled
        && !controls.popup.service.wifiConnecting && !modelData.connected
      onActivated: {
        controls.popup.requestOpen(true)
        controls.popup.service.connectNetwork(modelData)
      }
    }
  }

  Label {
    width: parent.width
    height: visible ? 30 : 0
    visible: controls.popup.service.savedNetworks.length === 0
    text: controls.popup.service.wifiEnabled ? "No saved networks in range" : "Turn on Wi-Fi to see saved networks"
    verticalAlignment: Text.AlignVCenter
  }

  Action {
    width: parent.width
    title: "Add Wi-Fi network…"
    iconName: "wifi"
    detail: "Create a Wi-Fi profile in Network settings. Enter the network name and security credentials, then save. In-range profiles appear in Saved networks."
    enabled: controls.popup.service.wifiAvailable
    onActivated: {
      controls.popup.requestClose(true)
      Quickshell.execDetached(["nm-connection-editor", "--create", "--type=802-11-wireless"])
    }
  }

  OptionalModule {
    width: parent.width
    active: !!controls.popup.controller.vpnService
    module: "VpnControls.qml"
    initialProperties: () => ({ popup: controls.popup, service: Qt.binding(() => controls.popup.controller.vpnService) })
  }
}

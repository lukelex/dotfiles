pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Controls

Scope {
  id: popup

  required property var controller
  required property var panel
  required property var service
  property bool pinned: false
  property bool closing: false
  property bool closeImmediately: false
  property bool promotionPending: false
  property var promotionSnapshot: null
  property var promotionWindow: null
  property int pinRequest: 0
  readonly property bool visible: preview.visible || pinnedPopup.visible
  readonly property real width: Math.max(1, Math.min(432, (popup.panel.screen ? popup.panel.screen.width : popup.panel.width) - 24))
  readonly property real height: sections.implicitHeight + 32
  signal shown()
  onShown: {
    popup.controller.refreshControlStatus()
    popup.controller.refreshVpnLocations()
  }

  function openPinned(request) {
    if (request !== popup.pinRequest)
      return
    if (popup.pinned && !popup.closing)
      pinnedPopup.open()
    popup.promotionPending = false
  }

  function requestOpen(pin = false) {
    if (!pin && popup.closing && popup.pinned)
      return
    popup.cancelClose()
    closeAnim.stop()
    popup.closing = false
    popup.closeImmediately = false
    if (pin || popup.pinned) {
      popup.pinned = true
      if (pinnedPopup.visible || popup.promotionPending)
        return
      popup.promotionPending = true
      const request = ++popup.pinRequest
      if (preview.visible) {
        const captured = content.grabToImage(result => {
          if (request !== popup.pinRequest || !popup.pinned || popup.closing)
            return
          popup.promotionSnapshot = result
        })
        if (!captured) {
          popup.promotionPending = false
          popup.pinned = false
        }
      } else {
        Qt.callLater(popup.openPinned, request)
      }
    } else {
      preview.visible = true
      if (content.opacity < 1 && !openAnim.running)
        openAnim.start()
    }
  }

  function requestClose(immediate = false) {
    popup.pinRequest++
    popup.promotionPending = false
    popup.promotionSnapshot = null
    popup.promotionWindow = null
    popup.closing = true
    popup.cancelClose()
    openAnim.stop()
    popup.closeImmediately = immediate
    if (pinnedPopup.visible) {
      pinnedPopup.close()
    } else {
      popup.pinned = false
    }
    if (immediate) {
      closeAnim.stop()
      preview.visible = false
    } else if (preview.visible && !closeAnim.running) {
      closeAnim.start()
    }
  }

  function scheduleClose() {
    if (!popup.pinned)
      closeTimer.restart()
  }

  function cancelClose() {
    closeTimer.stop()
  }

  function strengthText(strength) {
    return Math.round(Math.max(0, Math.min(1, strength)) * 100) + "%"
  }

  onVisibleChanged: {
    if (visible) {
      popup.shown()
    } else {
      closeTimer.stop()
      openAnim.stop()
      closeAnim.stop()
      popup.pinRequest++
      popup.promotionPending = false
      popup.promotionSnapshot = null
      popup.promotionWindow = null
      content.opacity = 0
      content.y = 10
    }
  }

  PopupWindow {
    id: preview
    anchor.window: popup.panel
    anchor.rect.x: Math.max(0, popup.panel.width - popup.width - 12)
    anchor.rect.y: popup.panel.height + 12
    implicitWidth: popup.width
    implicitHeight: popup.height
    color: "transparent"
    surfaceFormat.opaque: false
    grabFocus: false

    Image {
      anchors.fill: parent
      source: popup.promotionSnapshot ? popup.promotionSnapshot.url : ""
      visible: popup.promotionSnapshot !== null
      z: 1
      onStatusChanged: {
        if (status === Image.Ready)
          Qt.callLater(popup.openPinned, popup.pinRequest)
      }
    }
  }

  Connections {
    target: popup.promotionWindow
    function onFrameSwapped() {
      if (pinnedPopup.visible && popup.promotionSnapshot) {
        preview.visible = false
        popup.promotionSnapshot = null
        popup.promotionWindow = null
      }
    }
  }

  PopupWindow {
    id: pinnedPopup
    anchor.window: popup.panel
    anchor.rect.x: Math.max(0, popup.panel.width - popup.width - 12)
    anchor.rect.y: popup.panel.height + 12
    implicitWidth: popup.width
    implicitHeight: popup.height
    color: "transparent"
    surfaceFormat.opaque: false
    grabFocus: true

    function open() {
      pinnedPopup.visible = true
      // The preview snapshot bridges the first pinned frame.
      if (popup.promotionSnapshot) {
        popup.promotionWindow = content.nativeWindow
        preview.contentItem.Window.window.raise()
      }
      content.forceActiveFocus()
      if (content.opacity < 1 && !openAnim.running)
        openAnim.start()
    }

    function close() {
      pinnedPopup.visible = false
      popup.pinned = false
      preview.visible = false
      popup.promotionSnapshot = null
      popup.promotionWindow = null
    }
  }

  Timer {
    id: closeTimer
    interval: 500
    onTriggered: {
      if (!popup.pinned)
        popup.requestClose()
    }
  }

  ParallelAnimation {
    id: openAnim
    NumberAnimation { target: content; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
    NumberAnimation { target: content; property: "y"; to: 0; duration: 160; easing.type: Easing.OutCubic }
  }

  ParallelAnimation {
    id: closeAnim
    NumberAnimation { target: content; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
    NumberAnimation { target: content; property: "y"; to: 6; duration: 120; easing.type: Easing.InCubic }
    onFinished: preview.visible = false
  }

  component Label: Text {
    color: popup.controller.controlSecondaryText
    font.family: popup.controller.fontFamily
    font.pixelSize: 11
    textFormat: Text.PlainText
    elide: Text.ElideRight
  }

  component Action: Rectangle {
    id: action
    required property string title
    property string subtitle: ""
    property string iconName: ""
    property bool active: false
    property bool radioSwitch: false
    signal activated()

    height: subtitle ? 64 : 40
    radius: 14
    color: active || area.containsMouse ? popup.controller.controlActive : popup.controller.controlSurface
    border.width: 1
    border.color: popup.controller.darkMode ? "#33404D" : "#D7DCE3"
    opacity: enabled || active ? 1 : 0.55
    activeFocusOnTab: enabled && popup.pinned
    Accessible.role: radioSwitch ? Accessible.CheckBox : Accessible.Button
    Accessible.name: title
    Accessible.description: subtitle
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
      visible: action.iconName !== ""
      source: action.iconName ? popup.controller.icon(action.iconName) : ""
      color: popup.controller.controlPrimaryText
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: action.iconName ? 40 : 12
      anchors.right: parent.right
      anchors.rightMargin: action.radioSwitch ? 66 : 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3

      Label {
        width: parent.width
        text: action.title
        font.pixelSize: 12
        color: popup.controller.controlPrimaryText
      }
      Label {
        width: parent.width
        visible: text !== ""
        text: action.subtitle
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
      color: action.active ? popup.controller.controlActiveIcon : popup.controller.controlSliderTrack
      Rectangle {
        x: action.active ? 19 : 3
        y: 3
        width: 18
        height: 18
        radius: 9
        color: popup.controller.controlPrimaryText
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: "transparent"
      border.width: 2
      border.color: popup.controller.controlActiveIcon
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

  FocusScope {
    id: content
    readonly property var nativeWindow: Window.window
    parent: pinnedPopup.visible ? pinnedPopup.contentItem : preview.contentItem
    width: popup.width
    height: popup.height
    opacity: 0
    y: 10
    focus: popup.pinned
    Keys.onEscapePressed: function(event) {
      popup.requestClose()
      event.accepted = true
    }

    HoverHandler {
      onHoveredChanged: {
        if (hovered)
          popup.cancelClose()
        else
          popup.scheduleClose()
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 26
      border.width: 1
      border.color: popup.controller.darkMode ? "#3A424E" : "#D8DDE4"
      color: popup.controller.controlBackground
    }

    Column {
      id: sections
      x: 16
      y: 16
      width: parent.width - 32
      spacing: 10

      Row {
        width: parent.width
        height: 32
        spacing: 8
        Label {
          width: parent.width - 80
          anchors.verticalCenter: parent.verticalCenter
          text: "Connectivity"
          font.pixelSize: 16
          color: popup.controller.controlPrimaryText
        }
        Action {
          width: 72
          height: 32
          title: "Close"
          onActivated: popup.requestClose()
        }
      }

      Action {
        width: parent.width
        title: "Wi-Fi"
        iconName: "wifi"
        radioSwitch: true
        active: popup.service.wifiEnabled
        enabled: popup.service.wifiAvailable && (popup.service.wifiEnabled || popup.service.wifiHardwareEnabled)
        subtitle: !popup.service.wifiAvailable ? "No Wi-Fi adapter"
          : !popup.service.wifiHardwareEnabled ? "Hardware blocked"
          : !popup.service.wifiEnabled ? "Off"
          : popup.service.wifiConnected ? popup.service.wifiSsid + " / " + popup.strengthText(popup.service.wifiStrength)
          : "On / Not connected"
        onActivated: {
          popup.requestOpen()
          popup.service.setWifiEnabled(!popup.service.wifiEnabled)
        }
      }

      Action {
        width: parent.width
        title: "Ethernet"
        iconName: "ethernet-port"
        radioSwitch: true
        active: popup.service.ethernetConnected
        enabled: popup.service.ethernetAvailable
        subtitle: !popup.service.ethernetAvailable ? "No Ethernet adapter"
          : popup.service.ethernetConnected ? popup.service.ethernetName || "Connected" : "Off"
        onActivated: {
          popup.requestOpen()
          popup.service.setEthernetEnabled(!popup.service.ethernetConnected)
        }
      }

      Label {
        width: parent.width
        visible: text !== ""
        text: popup.service.ethernetError
        color: popup.controller.urgent
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
        visible: popup.service.wifiConnecting
        text: popup.service.connectingNetwork ? "Connecting to " + popup.service.connectingNetwork.name + "..." : "Connecting..."
      }

      Label {
        width: parent.width
        visible: text !== ""
        text: popup.service.wifiError
        color: popup.controller.urgent
        elide: Text.ElideNone
        wrapMode: Text.Wrap
      }

      Flickable {
        id: wifiScroll
        width: parent.width
        height: Math.min(180, wifiRows.implicitHeight)
        contentWidth: width
        contentHeight: wifiRows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: wifiRows
          width: wifiScroll.width - (wifiScroll.contentHeight > wifiScroll.height ? 12 : 0)
          spacing: 6
          Repeater {
            // The service orders active first, then name/device; never sort by strength.
            model: popup.service.savedNetworks
            delegate: Action {
              required property var modelData
              readonly property bool connecting: modelData.state === ConnectionState.Connecting
                || popup.service.connectingNetwork === modelData
              width: wifiRows.width
              height: 54
              title: modelData.name || "Hidden network"
              subtitle: connecting ? "Connecting..." : modelData.connected ? "Connected / " + popup.strengthText(modelData.signalStrength)
                : "Saved / " + popup.strengthText(modelData.signalStrength)
              iconName: modelData.connected ? "circle-check" : "wifi"
              active: modelData.connected || connecting
              enabled: popup.service.wifiEnabled && popup.service.wifiHardwareEnabled
                && !popup.service.wifiConnecting && !modelData.connected
              onActivated: {
                popup.requestOpen(true)
                popup.service.connectNetwork(modelData)
              }
            }
          }
          Label {
            width: parent.width
            height: visible ? 30 : 0
            visible: popup.service.savedNetworks.length === 0
            text: popup.service.wifiEnabled ? "No saved networks in range" : "Turn on Wi-Fi to see saved networks"
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      Action {
        width: parent.width
        title: "NordVPN"
        iconName: "globe"
        radioSwitch: true
        active: popup.controller.vpnConnected
        enabled: popup.controller.nordVpnInstalled && !popup.controller.vpnBusy
        subtitle: !popup.controller.nordVpnInstalled ? "Not installed"
          : popup.controller.vpnBusy ? "Updating connection..."
          : popup.controller.vpnConnected ? "Connected / " + (popup.controller.vpnLocation || "Location unavailable") : "Disconnected"
        onActivated: {
          popup.requestOpen()
          popup.controller.toggleVpn()
        }
      }

      Row {
        width: parent.width
        height: visible ? 32 : 0
        spacing: 10
        visible: popup.controller.nordVpnInstalled && popup.controller.vpnConnected

        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: "Location"
          width: 64
        }

        ComboBox {
          id: vpnLocations

          anchors.verticalCenter: parent.verticalCenter
          enabled: !popup.controller.vpnBusy && popup.controller.vpnLocations.length > 0
          font.family: popup.controller.fontFamily
          font.pixelSize: 11
          model: ["Recommended"].concat(popup.controller.vpnLocations)
          width: parent.width - 74
          onActivated: function(index) {
            popup.requestOpen()
            popup.controller.connectVpn(index === 0 ? "" : currentText)
          }
        }
      }

      Action {
        width: parent.width
        title: "Bluetooth"
        iconName: "bluetooth"
        radioSwitch: true
        active: popup.service.bluetoothEnabled
        enabled: popup.service.bluetoothAvailable && !popup.service.bluetoothChanging
          && (popup.service.bluetoothEnabled || !popup.service.bluetoothBlocked)
        subtitle: !popup.service.bluetoothAvailable ? "No Bluetooth adapter"
          : popup.service.bluetoothBlocked ? "Hardware blocked"
          : popup.service.bluetoothChanging ? "Updating radio..."
          : popup.service.bluetoothConnecting ? "Connecting..."
          : popup.service.bluetoothEnabled ? "On" : "Off"
        onActivated: {
          popup.requestOpen()
          popup.service.setBluetoothEnabled(!popup.service.bluetoothEnabled)
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
        text: popup.service.bluetoothError
        color: popup.controller.urgent
        elide: Text.ElideNone
        wrapMode: Text.Wrap
      }

      Flickable {
        id: bluetoothScroll
        width: parent.width
        height: Math.min(140, bluetoothRows.implicitHeight)
        contentWidth: width
        contentHeight: bluetoothRows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: bluetoothRows
          width: bluetoothScroll.width - (bluetoothScroll.contentHeight > bluetoothScroll.height ? 12 : 0)
          spacing: 6
          Repeater {
            model: popup.service.connectedBluetoothDevices
            delegate: Rectangle {
              id: deviceRow
              required property var modelData
              width: bluetoothRows.width
              height: 48
              radius: 14
              color: popup.controller.controlSurface
              LucideIcon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: popup.controller.icon("bluetooth-connected")
                color: popup.controller.controlActiveIcon
              }
              Label {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: batteryLabel.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: deviceRow.modelData.name
                font.pixelSize: 12
                color: popup.controller.controlPrimaryText
              }
              Label {
                id: batteryLabel
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: deviceRow.modelData.batteryAvailable ? popup.strengthText(deviceRow.modelData.battery) : "Connected"
              }
            }
          }
          Label {
            width: parent.width
            height: visible ? 30 : 0
            visible: popup.service.connectedBluetoothDevices.length === 0
            text: "No connected devices"
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      Row {
        width: parent.width
        spacing: 10
        Action {
          width: (parent.width - parent.spacing) / 2
          title: "Wi-Fi settings"
          iconName: "settings"
          onActivated: {
            popup.requestClose(true)
            Quickshell.execDetached(["nm-connection-editor"])
          }
        }
        Action {
          width: (parent.width - parent.spacing) / 2
          title: "Bluetooth settings"
          iconName: "settings"
          onActivated: {
            popup.requestClose(true)
            Quickshell.execDetached(["blueman-manager"])
          }
        }
      }
    }
  }
}

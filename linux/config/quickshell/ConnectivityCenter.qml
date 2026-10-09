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
  readonly property real availableHeight: Math.max(1, (popup.panel.screen ? popup.panel.screen.height : 768) - popup.panel.height - 24)
  readonly property real height: Math.min(availableHeight, sections.implicitHeight + 32)
  signal shown()
  onShown: {
    popup.controller.refreshControlStatus()
    popup.controller.vpnService.refresh()
    popup.controller.vpnService.refreshLocations()
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

  function percentageText(strength) {
    return Math.round(Math.max(0, Math.min(1, strength)) * 100) + "%"
  }

  function strengthText(strength) {
    if (strength >= 0.75) return "Excellent"
    if (strength >= 0.5) return "Good"
    if (strength >= 0.25) return "Fair"
    return "Weak"
  }

  function strengthColor(strength) {
    if (strength >= 0.75) return popup.controller.controlDownloadIcon
    if (strength >= 0.5) return popup.controller.controlActiveIcon
    if (strength >= 0.25) return popup.controller.controlWarningText
    return popup.controller.urgent
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

  component Hint: ToolTip {
    id: hint
    delay: 500
    padding: 10
    width: Math.min(340, popup.width - 24)
    contentItem: Label {
      text: hint.text
      color: popup.controller.controlPrimaryText
      wrapMode: Text.Wrap
      elide: Text.ElideNone
    }
    background: Rectangle {
      radius: 10
      color: popup.controller.controlSurface
      border.width: 1
      border.color: popup.controller.controlSurfaceBorder
    }
  }

  component Action: Rectangle {
    id: action
    required property string title
    property string subtitle: ""
    property string qualityText: ""
    property color qualityColor: popup.controller.controlSecondaryText
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
    color: active ? popup.controller.controlActive : area.containsMouse ? popup.controller.controlHover : popup.controller.controlSurface
    border.width: 1
    border.color: popup.controller.controlSurfaceBorder
    opacity: enabled || active ? 1 : 0.55
    activeFocusOnTab: enabled && popup.pinned
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
      source: action.iconName ? popup.controller.icon(action.iconName) : ""
      color: popup.controller.controlPrimaryText
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
      Hint {
        visible: popup.visible && (labelHover.hovered || action.activeFocus)
        text: action.detail
      }

      Label {
        width: parent.width
        text: action.title
        font.pixelSize: 12
        color: popup.controller.controlPrimaryText
      }
      Row {
        width: parent.width
        visible: action.subtitle !== ""

        Label {
          width: Math.min(implicitWidth, Math.max(0, parent.width - qualityLabel.width))
          text: action.qualityText ? action.subtitle.slice(0, -action.qualityText.length) : action.subtitle
        }
        Label {
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
      x: action.compactTraffic ? action.width - 66 - width : (action.width - width) / 2
      width: action.compactTraffic ? Math.min(100, action.width * 0.34) : 116
      visible: action.showTraffic
      spacing: 2

      Repeater {
        model: ["upload", "download"]
        delegate: Row {
          id: trafficRate
          required property string modelData
          readonly property string rate: popup.service.formatSpeed(popup.service.connectionSpeed(action.wiredTraffic, modelData, action.trafficDeviceName))
          width: trafficColumn.width
          height: 20
          spacing: 5
          Accessible.role: Accessible.StaticText
          Accessible.name: (modelData === "download" ? "Download " : "Upload ") + rate
          activeFocusOnTab: popup.pinned && action.showTraffic
          HoverHandler { id: rateHover }
          Hint {
            visible: popup.visible && (rateHover.hovered || trafficRate.activeFocus)
            text: (trafficRate.modelData === "download" ? "Download: " : "Upload: ") + trafficRate.rate
              + "\nBytes per second (KiB = 1,024 bytes). Includes local network traffic; this is usage, not available internet bandwidth."
          }

          LucideIcon {
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            source: popup.controller.icon(trafficRate.modelData === "download" ? "arrow-down" : "arrow-up")
            color: trafficRate.modelData === "download" ? popup.controller.controlDownloadIcon : popup.controller.controlUploadIcon
          }
          Label {
            width: parent.width - 21
            anchors.verticalCenter: parent.verticalCenter
            text: trafficRate.rate
            color: popup.controller.controlPrimaryText
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
      border.color: popup.controller.controlBorder
      color: popup.controller.controlBackground
    }

    Flickable {
      id: panelScroll
      x: 16
      y: 16
      width: parent.width - 32
      height: Math.max(1, parent.height - 32)
      contentWidth: width
      contentHeight: sections.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }

    Column {
      id: sections
      parent: panelScroll.contentItem
      width: panelScroll.width - (panelScroll.contentHeight > panelScroll.height ? 12 : 0)
      spacing: 10

      Row {
        width: parent.width
        height: 40
        spacing: 8
        Column {
          width: parent.width - 40
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Label {
            width: parent.width
            text: "Connectivity"
            font.pixelSize: 16
            color: popup.controller.controlPrimaryText
          }
          Label {
            width: parent.width
            text: popup.service.internetStatus
            color: popup.controller.controlPrimaryText
            Accessible.name: "NetworkManager internet status: " + text
          }
        }
        Item {
          id: closeButton
          anchors.verticalCenter: parent.verticalCenter
          width: 32
          height: 32
          activeFocusOnTab: popup.pinned
          Keys.onReturnPressed: popup.requestClose()
          Keys.onSpacePressed: popup.requestClose()
          Accessible.role: Accessible.Button
          Accessible.name: "Close connectivity"
          Accessible.onPressAction: popup.requestClose()
          Rectangle {
            anchors.fill: parent
            color: closeArea.containsMouse ? popup.controller.controlHover : popup.controller.controlSurface
            border.width: closeButton.activeFocus ? 2 : 0
            border.color: popup.controller.controlActiveIcon
            radius: 10
          }
          LucideIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: popup.controller.icon("x")
            color: popup.controller.controlSecondaryText
          }
          MouseArea {
            id: closeArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: popup.requestClose()
          }
        }
      }

      Action {
        width: parent.width
        title: "Wi-Fi"
        showTraffic: popup.service.wifiConnected
        iconName: "wifi"
        radioSwitch: true
        active: popup.service.wifiEnabled
        enabled: popup.service.wifiAvailable && (popup.service.wifiEnabled || popup.service.wifiHardwareEnabled)
        subtitle: !popup.service.wifiAvailable ? "No Wi-Fi adapter"
          : !popup.service.wifiHardwareEnabled ? "Hardware blocked"
          : !popup.service.wifiEnabled ? "Off"
          : popup.service.wifiConnected ? popup.service.wifiSsid + " / " + popup.strengthText(popup.service.wifiStrength)
          : "On / Not connected"
        qualityColor: popup.service.wifiConnected && popup.service.wifiEnabled && popup.service.wifiHardwareEnabled
          ? popup.strengthColor(popup.service.wifiStrength) : popup.controller.controlSecondaryText
        qualityText: popup.service.wifiConnected && popup.service.wifiAvailable && popup.service.wifiEnabled && popup.service.wifiHardwareEnabled
          ? popup.strengthText(popup.service.wifiStrength) : ""
        detail: title + "\n" + subtitle + (popup.service.activeNetwork ? "\nDevice: " + popup.service.activeNetwork.device.name : "")
        onActivated: {
          popup.requestOpen()
          popup.service.setWifiEnabled(!popup.service.wifiEnabled)
        }
      }

      Repeater {
        model: popup.service._wiredDevices.length ? popup.service._wiredDevices : [null]
        delegate: Action {
          required property var modelData
          width: sections.width
          title: popup.service._wiredDevices.length > 1 ? "Ethernet / " + modelData.name : "Ethernet"
          showTraffic: modelData !== null && modelData.connected
          wiredTraffic: true
          trafficDeviceName: modelData ? modelData.name : ""
          iconName: "ethernet-port"
          radioSwitch: true
          active: modelData !== null && modelData.connected
          enabled: modelData !== null && modelData.nmManaged && !popup.service.ethernetBusy
            && modelData.state !== ConnectionState.Connecting
          subtitle: popup.service.ethernetStatus(modelData)
          detail: title + "\n" + subtitle + (modelData ? "\nDevice: " + modelData.name : "")
          onActivated: {
            popup.requestOpen()
            popup.service.setEthernetEnabled(!modelData.connected, modelData)
          }
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

      ConnectionDeviceList {
        id: wifiScroll
        width: parent.width
        entries: popup.service.savedNetworks
        keyForEntry: network => JSON.stringify([network.device.name, network.name, network.security])
        panelVisible: popup.visible
        keyboardEnabled: popup.pinned
        focusFallback: closeButton
        delegate: Action {
          required property var entry
          readonly property var modelData: entry
          readonly property bool connecting: modelData && (modelData.state === ConnectionState.Connecting
            || popup.service.connectingNetwork === modelData)
          width: wifiScroll.rowWidth
          height: 54
          title: modelData ? modelData.name || "Hidden network" : "Network unavailable"
          detail: title + "\n" + subtitle + (modelData ? "\nDevice: " + modelData.device.name : "")
          subtitle: !modelData ? "Unavailable" : connecting ? "Connecting..."
            : modelData.connected ? "Connected / " + popup.strengthText(modelData.signalStrength)
            : "Saved / " + popup.strengthText(modelData.signalStrength)
          qualityColor: modelData && !connecting
            ? popup.strengthColor(modelData.signalStrength) : popup.controller.controlSecondaryText
          qualityText: modelData && !connecting ? popup.strengthText(modelData.signalStrength) : ""
          iconName: modelData && modelData.connected ? "circle-check" : "wifi"
          active: modelData && (modelData.connected || connecting)
          enabled: modelData !== null && popup.service.wifiEnabled && popup.service.wifiHardwareEnabled
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

      Action {
        width: parent.width
        title: "Add Wi-Fi network…"
        iconName: "wifi"
        detail: "Create a Wi-Fi profile in Network settings. Enter the network name and security credentials, then save. In-range profiles appear in Saved networks."
        enabled: popup.service.wifiAvailable
        onActivated: {
          popup.requestClose(true)
          Quickshell.execDetached(["nm-connection-editor", "--create", "--type=802-11-wireless"])
        }
      }

      Action {
        width: parent.width
        title: "NordVPN"
        iconName: "globe"
        radioSwitch: true
        active: popup.controller.vpnService.connected
        enabled: popup.controller.vpnService.installed && !popup.controller.vpnService.busy
          && popup.controller.vpnService.statusKnown
        subtitle: popup.controller.vpnService.statusText
        onActivated: {
          popup.requestOpen()
          popup.controller.vpnService.toggle()
        }
      }

      Label {
        width: parent.width
        visible: text !== ""
        text: popup.controller.vpnService.error || popup.controller.vpnService.statusError || popup.controller.vpnService.locationsError
        color: popup.controller.urgent
        elide: Text.ElideNone
        wrapMode: Text.Wrap
      }

      Action {
        width: parent.width
        title: "Refresh VPN status"
        visible: popup.controller.vpnService.installed && !popup.controller.vpnService.statusKnown
        height: visible ? 40 : 0
        onActivated: popup.controller.vpnService.refresh()
      }

      Row {
        width: parent.width
        height: visible ? 32 : 0
        spacing: 10
        visible: popup.controller.vpnService.installed

        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: "Destination"
          width: 80
        }

        ComboBox {
          id: vpnLocations

          anchors.verticalCenter: parent.verticalCenter
          enabled: !popup.controller.vpnService.busy
          font.family: popup.controller.fontFamily
          font.pixelSize: 11
          palette.base: popup.controller.controlSurface
          palette.button: popup.controller.controlSurface
          palette.text: popup.controller.controlPrimaryText
          palette.buttonText: popup.controller.controlPrimaryText
          palette.highlight: popup.controller.controlActive
          palette.highlightedText: popup.controller.controlPrimaryText
          palette.window: popup.controller.controlSurface
          palette.windowText: popup.controller.controlPrimaryText
          model: popup.controller.vpnService.locationOptions
          textRole: "label"
          valueRole: "value"
          currentIndex: popup.controller.vpnService.locationOptions.findIndex(option => option.value === popup.controller.vpnService.selectedLocation)
          width: parent.width - 90 - (applyVpnLocation.visible ? applyVpnLocation.width + 10 : 0)
          Accessible.name: "VPN destination"
          onActivated: function(index) {
            popup.requestOpen(true)
            popup.controller.vpnService.selectLocation(model[index].value)
          }
        }

        Action {
          id: applyVpnLocation
          anchors.verticalCenter: parent.verticalCenter
          width: 64
          height: 32
          title: "Apply"
          visible: popup.controller.vpnService.connected && popup.controller.vpnService.destinationEdited
          enabled: !popup.controller.vpnService.busy
          Accessible.name: "Connect to selected VPN destination"
          onActivated: {
            popup.requestOpen(true)
            popup.controller.vpnService.connectLocation(popup.controller.vpnService.selectedLocation)
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

      ConnectionDeviceList {
        id: bluetoothScroll
        width: parent.width
        maximumHeight: 140
        entries: popup.service.connectedBluetoothDevices
        keyForEntry: device => device.dbusPath
        panelVisible: popup.visible
        keyboardEnabled: popup.pinned
        focusFallback: closeButton
        delegate: Rectangle {
          id: deviceRow
          required property var entry
          readonly property var modelData: entry
          readonly property string deviceName: modelData ? modelData.name : "Device unavailable"
          width: bluetoothScroll.rowWidth
          height: 48
          radius: 14
          color: popup.controller.controlSurface
          activeFocusOnTab: popup.pinned
          Accessible.role: Accessible.StaticText
          Accessible.name: deviceName + ", " + batteryLabel.text
          HoverHandler { id: deviceHover }
          Hint {
            visible: popup.visible && (deviceHover.hovered || deviceRow.activeFocus)
            text: deviceRow.deviceName + "\n" + batteryLabel.text
          }
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
            text: deviceRow.deviceName
            font.pixelSize: 12
            color: popup.controller.controlPrimaryText
          }
          Label {
            id: batteryLabel
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: !deviceRow.modelData ? "Unavailable" : deviceRow.modelData.batteryAvailable
              ? popup.percentageText(deviceRow.modelData.battery) : "Connected"
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

      Row {
        width: parent.width
        spacing: 10
        Action {
          width: (parent.width - parent.spacing) / 2
          title: "Network settings"
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

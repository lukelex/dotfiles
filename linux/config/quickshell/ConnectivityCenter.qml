pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "DesignTokens.js" as Design
import QtQuick.Controls

Scope {
  id: popup

  required property var controller
  required property var panel
  required property var service
  property bool bluetoothOnly: false
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
  readonly property real height: Math.min(availableHeight, sections.implicitHeight + 82)
  signal shown()
  onShown: {
    if (!popup.bluetoothOnly) {
      popup.controller.refreshControlStatus()
      popup.controller.vpnService?.refresh()
      popup.controller.vpnService?.refreshLocations()
    }
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
    interval: popup.controller.preferences.value("desktop.hoverCloseDelayMs", 600)
    onTriggered: {
      if (!popup.pinned)
        popup.requestClose()
    }
  }

  ParallelAnimation {
    id: openAnim
    NumberAnimation { target: content; property: "opacity"; to: 1; duration: Design.motion.enter; easing.type: Easing.OutCubic }
    NumberAnimation { target: content; property: "y"; to: 0; duration: Design.motion.enter; easing.type: Easing.OutCubic }
  }

  ParallelAnimation {
    id: closeAnim
    NumberAnimation { target: content; property: "opacity"; to: 0; duration: Design.motion.exit; easing.type: Easing.InCubic }
    NumberAnimation { target: content; property: "y"; to: 6; duration: Design.motion.exit; easing.type: Easing.InCubic }
    onFinished: preview.visible = false
  }

  component Label: ConnectivityLabel { host: popup }
  component Hint: ConnectivityHint { host: popup }
  component Action: ConnectivityAction { host: popup }

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

    PanelSurface {
      anchors.fill: parent
      controller: popup.controller
    }

    Flickable {
      id: panelScroll
      x: 16
      y: 66
      width: parent.width - 32
      height: Math.max(1, parent.height - 82)
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
        parent: content
        x: 16
        y: 16
        width: content.width - 32
        height: 40
        spacing: 8
        Column {
          width: parent.width - 80
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Label {
            width: parent.width
            text: popup.bluetoothOnly ? "Bluetooth" : "Network"
            font.pixelSize: Design.typography.heading
            color: popup.controller.controlPrimaryText
          }
          Label {
            width: parent.width
            text: popup.bluetoothOnly ? "" : popup.service?.internetStatus ?? "Internet status unknown"
            visible: !popup.bluetoothOnly
            color: popup.controller.controlPrimaryText
            Accessible.name: "NetworkManager internet status: " + text
          }
        }
        HeaderSettingsButton {
          controller: popup.controller
          description: popup.bluetoothOnly ? "Bluetooth settings" : "Wi-Fi settings"
          keyboardEnabled: popup.pinned
          anchors.verticalCenter: parent.verticalCenter
          onActivated: popup.controller.openSystemSettings(popup.panel.screen, popup.bluetoothOnly ? "bluetooth" : "wifi")
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
          Accessible.name: popup.bluetoothOnly ? "Close Bluetooth" : "Close network"
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

      Label {
        visible: !popup.service || controls.status === Loader.Error
        text: popup.bluetoothOnly ? "Bluetooth controls unavailable" : "Network controls unavailable"
      }
      OptionalModule {
        id: controls
        width: parent.width
        active: !!popup.service
        module: popup.bluetoothOnly ? "BluetoothControls.qml" : "NetworkControls.qml"
        initialProperties: () => ({ popup, closeButtonItem: closeButton })
      }

    }
  }
}

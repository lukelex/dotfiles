pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Controls as Controls

Scope {
  id: popup

  required property var controller
  required property var panel
  required property var service
  required property var trigger
  property bool pinned: false
  property bool closing: false
  property bool promotionPending: false
  property var promotionSnapshot: null
  property var promotionWindow: null
  property int pinRequest: 0
  property bool _audioPanelActive: false
  readonly property bool visible: preview.visible || pinnedPopup.visible
  readonly property real width: Math.max(1, Math.min(432, (panel.screen ? panel.screen.width : panel.width) - 24))
  readonly property real availableHeight: Math.max(1, (panel.screen ? panel.screen.height : 768) - panel.height - 24)
  readonly property real height: Math.min(availableHeight, sections.implicitHeight + 32)

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
    const fresh = !popup.visible && !popup.pinned
    popup.cancelClose()
    closeAnim.stop()
    popup.closing = false
    if (fresh)
      popup.service.refresh(true)

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
    if (pinnedPopup.visible)
      pinnedPopup.close()
    else
      popup.pinned = false
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

  onVisibleChanged: {
    if (visible && !popup._audioPanelActive) {
      popup._audioPanelActive = true
      popup.service.panelOpened()
    } else if (!visible && popup._audioPanelActive) {
      popup._audioPanelActive = false
      popup.service.panelClosed()
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

  Component.onDestruction: {
    if (popup._audioPanelActive)
      popup.service.panelClosed()
  }

  component Label: Text {
    color: popup.controller.controlSecondaryText
    font.family: popup.controller.fontFamily
    font.pixelSize: 11
    textFormat: Text.PlainText
    elide: Text.ElideRight
  }

  component AudioDeviceRow: Item {
    id: outputRow

    required property var device
    required property bool isInput
    readonly property bool isDefault: outputRow.isInput
      ? popup.service.defaultSource === device.name : popup.service.defaultSink === device.name
    readonly property bool isPending: outputRow.isInput
      ? popup.service.pendingSource === device.name : popup.service.pendingSink === device.name

    height: 48
    width: parent.width
    enabled: !popup.service.busy
    activeFocusOnTab: enabled && popup.pinned
    Accessible.role: Accessible.RadioButton
    Accessible.name: device.description
    Accessible.description: isPending ? "Switching " + (isInput ? "input" : "output") + " device"
      : isDefault ? "Current " + (isInput ? "input" : "output") + " device"
      : "Select " + (isInput ? "input" : "output") + " device"
    Accessible.checkable: true
    Accessible.checked: isDefault
    Accessible.onPressAction: outputRow.activate()
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) outputRow.activate() }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) outputRow.activate() }

    function activate() {
      if (!outputRow.enabled)
        return
      popup.requestOpen(true)
      if (outputRow.isInput)
        popup.service.setDefaultSource(outputRow.device.name)
      else
        popup.service.setDefaultSink(outputRow.device.name)
    }

    Rectangle {
      anchors.fill: parent
      border.color: outputRow.isPending ? popup.controller.controlActiveIcon
        : outputRow.isDefault ? popup.controller.controlActive : popup.controller.darkMode ? "#33404D" : "#D7DCE3"
      border.width: 1
      color: outputRow.isDefault ? popup.controller.controlActive
        : area.containsMouse ? popup.controller.controlActive : popup.controller.controlSurface
      radius: 12
    }

    LucideIcon {
      id: typeIcon

      anchors {
        left: parent.left
        leftMargin: 12
        verticalCenter: parent.verticalCenter
      }
      color: outputRow.isDefault ? popup.controller.controlActiveIcon : popup.controller.controlSecondaryText
      height: 18
      source: popup.controller.icon(outputRow.device.iconName || "speaker")
      width: 18
    }

    Column {
      anchors {
        left: typeIcon.right
        leftMargin: 10
        right: statusIcon.left
        rightMargin: 8
        verticalCenter: parent.verticalCenter
      }
      spacing: 2

      Label {
        color: popup.controller.controlPrimaryText
        font.pixelSize: 12
        text: outputRow.device.description
        width: parent.width
      }

      Label {
        color: outputRow.isPending ? popup.controller.controlActiveIcon : popup.controller.controlSecondaryText
        font.pixelSize: 10
        text: outputRow.isPending ? "Switching…"
          : outputRow.isDefault ? "Current " + (outputRow.isInput ? "input" : "output") : ""
        visible: text !== ""
        width: parent.width
      }
    }

    LucideIcon {
      id: statusIcon

      anchors {
        right: parent.right
        rightMargin: 12
        verticalCenter: parent.verticalCenter
      }
      color: outputRow.isDefault ? popup.controller.controlActiveIcon
        : outputRow.isPending ? popup.controller.controlPrimaryText : popup.controller.controlSecondaryText
      height: 17
      source: popup.controller.icon(outputRow.isPending ? "refresh-cw" : outputRow.isDefault ? "circle-check" : "volume-2")
      width: 17
    }

    MouseArea {
      id: area

      anchors.fill: parent
      cursorShape: outputRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: outputRow.enabled
      hoverEnabled: true
      onClicked: outputRow.activate()
    }
  }

  PopupWindow {
    id: preview
    anchor.window: popup.panel
    anchor.rect.x: Math.max(0, Math.min(popup.panel.width - popup.width,
      popup.trigger.mapToItem(popup.panel.contentItem, popup.trigger.width / 2, 0).x - popup.width / 2))
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
    anchor.rect.x: Math.max(0, Math.min(popup.panel.width - popup.width,
      popup.trigger.mapToItem(popup.panel.contentItem, popup.trigger.width / 2, 0).x - popup.width / 2))
    anchor.rect.y: popup.panel.height + 12
    implicitWidth: popup.width
    implicitHeight: popup.height
    color: "transparent"
    surfaceFormat.opaque: false
    grabFocus: true

    function open() {
      pinnedPopup.visible = true
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
        id: headerRow

        width: parent.width
        height: 32
        spacing: 8

        Label {
          anchors.verticalCenter: parent.verticalCenter
          color: popup.controller.controlPrimaryText
          font.pixelSize: 16
          text: "Sound devices"
          width: parent.width - closeButton.width - parent.spacing
        }

        Item {
          id: closeButton

          width: 64
          height: 32
          activeFocusOnTab: popup.pinned
          Accessible.role: Accessible.Button
          Accessible.name: "Close sound device selector"
          Accessible.onPressAction: popup.requestClose()
          Keys.onReturnPressed: popup.requestClose()
          Keys.onSpacePressed: popup.requestClose()

          Rectangle {
            anchors.fill: parent
            color: closeArea.containsMouse ? popup.controller.controlActive : popup.controller.controlSurface
            radius: 10
          }

          Label {
            anchors.centerIn: parent
            color: popup.controller.controlPrimaryText
            text: "Close"
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

      Flickable {
        id: deviceScroll

        width: parent.width
        height: Math.max(1, Math.min(deviceSections.implicitHeight,
          popup.availableHeight - 32 - sections.spacing - 32))
        contentWidth: width
        contentHeight: deviceSections.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Controls.ScrollBar.vertical: Controls.ScrollBar {
          policy: Controls.ScrollBar.AsNeeded
        }

        Column {
          id: deviceSections
          width: deviceScroll.contentHeight > deviceScroll.height ? deviceScroll.width - 12 : deviceScroll.width
          spacing: 6

          Label {
            width: parent.width
            visible: text !== ""
            text: popup.service.error
            color: popup.controller.urgent
            elide: Text.ElideNone
            wrapMode: Text.Wrap
          }

          Label {
            width: parent.width
            color: popup.controller.controlPrimaryText
            font.pixelSize: 12
            text: "Output devices"
          }

          Repeater {
            model: popup.service.outputs
            delegate: AudioDeviceRow {
              required property var modelData
              device: modelData
              isInput: false
              width: deviceSections.width
            }
          }

          Label {
            width: parent.width
            visible: popup.service.outputs.length === 0
            text: popup.service.loaded ? "No output devices found." : "Looking for devices…"
          }

          Label {
            width: parent.width
            color: popup.controller.controlPrimaryText
            font.pixelSize: 12
            text: "Input devices"
          }

          Repeater {
            model: popup.service.inputs
            delegate: AudioDeviceRow {
              required property var modelData
              device: modelData
              isInput: true
              width: deviceSections.width
            }
          }

          Label {
            width: parent.width
            visible: popup.service.inputs.length === 0
            text: popup.service.loaded ? "No input devices found." : "Looking for devices…"
          }
        }
      }
    }
  }
}

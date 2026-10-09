pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
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

  PwNodePeakMonitor {
    id: microphonePeak
    node: popup.visible && popup.controller.microphoneAvailable ? popup.controller.defaultMicrophone : null
    enabled: popup.visible && popup.controller.microphoneAvailable && !popup.controller.microphoneMuted
  }

  Process {
    id: advancedSettings
    command: ["pavucontrol"]
  }

  function openAdvancedSettings() {
    popup.requestClose(true)
    Qt.callLater(() => { advancedSettings.running = true })
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
    readonly property var inputNode: isInput
      ? popup.service.microphoneNodes.find(node => node.name === device.name) || null : null
    readonly property string muteStatus: !isInput ? ""
      : inputNode && inputNode.ready && inputNode.audio ? (inputNode.audio.muted ? "Muted" : "Unmuted")
      : "Checking mute state…"

    height: 48
    width: parent.width
    enabled: !popup.service.busy
    activeFocusOnTab: enabled && popup.pinned
    Accessible.role: Accessible.RadioButton
    Accessible.name: device.description
    Accessible.description: (isPending ? "Switching " + (isInput ? "input" : "output") + " device"
      : isDefault ? "Current " + (isInput ? "input" : "output") + " device"
      : "Select " + (isInput ? "input" : "output") + " device") + (muteStatus ? ", " + muteStatus : "")
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
        : outputRow.activeFocus ? popup.controller.controlActiveIcon : popup.controller.controlSurfaceBorder
      border.width: outputRow.activeFocus ? 2 : 1
      color: outputRow.isDefault ? popup.controller.controlActive
        : area.containsMouse ? popup.controller.controlHover : popup.controller.controlSurface
      radius: 14
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
        text: (outputRow.isPending ? "Switching…"
          : outputRow.isDefault ? "Current " + (outputRow.isInput ? "input" : "output") : "")
          + (outputRow.muteStatus ? (outputRow.isPending || outputRow.isDefault ? " · " : "") + outputRow.muteStatus : "")
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
      source: popup.controller.icon(outputRow.isPending ? "refresh-cw" : "circle-check")
      visible: outputRow.isPending || outputRow.isDefault
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

  component VolumeControl: Column {
    id: volumeControl
    required property string title
    required property string iconName
    required property bool muted
    required property real volume
    signal volumeEdited(real value)
    signal muteRequested()
    width: parent.width
    spacing: 2
    opacity: enabled ? 1 : 0.55

    Item {
      width: parent.width
      height: 36

      Label {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - muteButton.width - 12
        color: popup.controller.controlPrimaryText
        font.pixelSize: 12
        text: volumeControl.title + (!volumeControl.enabled ? " unavailable" : volumeControl.muted ? " / muted" : "")
      }

      SoundAction {
        id: muteButton
        anchors.right: parent.right
        width: 100
        text: volumeControl.muted ? "Unmute" : "Mute"
        accessibleName: text + " " + volumeControl.title.toLowerCase()
        iconName: volumeControl.iconName
        active: volumeControl.muted
        onActivated: volumeControl.muteRequested()
      }
    }

    Item {
      width: parent.width
      height: 32

      LucideIcon {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        source: popup.controller.icon(volumeControl.iconName)
        color: popup.controller.controlSecondaryText
      }

      Controls.Slider {
        id: volumeSlider
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.right: percentage.left
        anchors.rightMargin: 10
        height: parent.height
        from: 0
        to: 100
        value: volumeControl.volume
        stepSize: 1
        focusPolicy: popup.pinned ? Qt.StrongFocus : Qt.NoFocus
        Accessible.name: volumeControl.title + " volume"
        onMoved: volumeControl.volumeEdited(value)

        background: Rectangle {
          x: volumeSlider.leftPadding
          y: (volumeSlider.height - height) / 2
          width: volumeSlider.availableWidth
          height: 8
          radius: 4
          color: popup.controller.controlSliderTrack
          Rectangle {
            width: volumeSlider.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: popup.controller.controlSliderFill
          }
        }
        handle: Rectangle {
          x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
          y: (volumeSlider.height - height) / 2
          width: 14
          height: 14
          radius: 7
          color: popup.controller.controlSliderFill
          border.width: volumeSlider.activeFocus ? 2 : 0
          border.color: popup.controller.controlActiveIcon
        }
      }

      Label {
        id: percentage
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: volumeControl.enabled ? Math.round(volumeControl.volume) + "%" : "—"
      }
    }
  }

  component SoundAction: Item {
    id: action
    required property string text
    required property string iconName
    property string accessibleName: text
    property bool active: false
    signal activated()
    width: parent.width
    height: 36
    activeFocusOnTab: popup.pinned && enabled
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: action.activate()
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) action.activate() }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) action.activate() }
    function activate() {
      if (!action.enabled)
        return
      popup.requestOpen(true)
      action.activated()
    }
    Rectangle {
      anchors.fill: parent
      radius: 14
      color: action.active ? popup.controller.controlActive
        : actionArea.containsMouse ? popup.controller.controlHover : popup.controller.controlSurface
      border.width: action.activeFocus ? 2 : 1
      border.color: action.activeFocus ? popup.controller.controlActiveIcon : popup.controller.controlSurfaceBorder
    }
    Row {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 8
      LucideIcon {
        anchors.verticalCenter: parent.verticalCenter
        color: action.active ? popup.controller.controlPrimaryText : popup.controller.controlSecondaryText
        height: 17
        source: popup.controller.icon(action.iconName)
        width: 17
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        text: action.text
        color: action.enabled ? popup.controller.controlPrimaryText : popup.controller.controlSecondaryText
        font.pixelSize: 12
        width: parent.width - 25
      }
    }
    MouseArea {
      id: actionArea
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: action.activate()
    }
  }

  PopupWindow {
    id: preview
    anchor.window: popup.panel
    anchor.rect.x: Math.max(12, Math.min(popup.panel.width - popup.width - 12,
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
    anchor.rect.x: Math.max(12, Math.min(popup.panel.width - popup.width - 12,
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
      border.color: popup.controller.controlBorder
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
           text: "Audio Devices"
          width: parent.width - closeButton.width - parent.spacing
        }

        Item {
          id: closeButton

          width: 32
          height: 32
          activeFocusOnTab: popup.pinned
          Accessible.role: Accessible.Button
           Accessible.name: "Close Audio Devices"
          Accessible.onPressAction: popup.requestClose()
          Keys.onReturnPressed: popup.requestClose()
          Keys.onSpacePressed: popup.requestClose()

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

      Flickable {
        id: deviceScroll

        width: parent.width
        height: Math.max(1, Math.min(deviceSections.implicitHeight,
          popup.availableHeight - 32 - sections.spacing * 2 - 32 - settingsFooter.height))
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

          Rectangle {
            width: parent.width
            height: volumeControls.implicitHeight + 28
            radius: 18
            color: popup.controller.controlSurface

            Column {
              id: volumeControls
              x: 14
              y: 14
              width: parent.width - 28
              spacing: 12

              VolumeControl {
                title: "Speaker"
                enabled: popup.controller.audioAvailable
                iconName: popup.controller.audioIcon()
                muted: popup.controller.audioMuted
                volume: popup.controller.audioVolume
                onVolumeEdited: value => popup.controller.setAudioVolume(value)
                onMuteRequested: popup.controller.toggleAudio()
              }

              VolumeControl {
                title: "Microphone"
                enabled: popup.controller.microphoneAvailable
                iconName: popup.controller.microphoneMuted ? "mic-off" : "mic"
                muted: popup.controller.microphoneMuted
                volume: popup.controller.microphoneVolume
                onVolumeEdited: value => popup.controller.setMicrophoneVolume(value)
                onMuteRequested: popup.controller.toggleMicrophone()
              }

              Label {
                width: parent.width
                visible: text !== ""
                text: popup.controller.audioControlError
                color: popup.controller.urgent
                elide: Text.ElideNone
                wrapMode: Text.Wrap
              }
            }
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

          Label {
            width: parent.width
            visible: popup.controller.microphoneAvailable
            text: "Microphone: " + (popup.service.inputs.find(input => input.name === popup.service.defaultSource)?.description || "Selected input")
              + (popup.controller.microphoneMuted ? " — Muted" : " — Unmuted")
          }

          Rectangle {
            width: parent.width
            height: 6
            radius: 3
            visible: popup.controller.microphoneAvailable
            color: popup.controller.controlSliderTrack
            Accessible.role: Accessible.ProgressBar
            Accessible.name: "Microphone input level"
            Rectangle {
              width: popup.controller.microphoneMuted ? 0 : parent.width * Math.max(0, Math.min(1, microphonePeak.peak))
              height: parent.height
              radius: parent.radius
              color: microphonePeak.peak >= 0.95 ? popup.controller.urgent : popup.controller.controlSliderFill
            }
          }

          Label {
            width: parent.width
            visible: popup.service.allMicrophonesMuteRequested
            text: popup.service.allMicrophonesMuted ? "All microphones muted"
              : popup.service.microphoneNodes.length === 0 ? "No microphones connected"
              : popup.service.microphoneMuteError ? "All-input mute could not be confirmed" : "Muting all microphones…"
            color: popup.controller.controlPrimaryText
          }

          SoundAction {
            text: "Mute all microphones"
            iconName: "mic-off"
            active: popup.service.allMicrophonesMuted
            enabled: popup.service.microphoneNodes.length > 0 && !popup.service.allMicrophonesMuted
            onActivated: popup.service.muteAllMicrophones()
          }

          Label {
            width: parent.width
            text: popup.service.microphoneMuteError || "Unmute the selected microphone above to release all-input muting. Other inputs stay muted."
            visible: popup.service.microphoneMuteError !== "" || popup.service.allMicrophonesMuteRequested
            color: popup.service.microphoneMuteError ? popup.controller.urgent : popup.controller.controlSecondaryText
            wrapMode: Text.Wrap
            elide: Text.ElideNone
          }

          Label {
            width: parent.width
            text: "Applications using microphones"
            color: popup.controller.controlPrimaryText
            font.pixelSize: 12
          }

          Label {
            width: parent.width
            visible: popup.service.recordingApplications.length === 0
            text: Pipewire.ready ? "No applications are recording." : "Checking recording applications…"
          }

          Flickable {
            id: recordingScroll
            width: parent.width
            height: Math.min(recordingRows.implicitHeight, 156)
            visible: popup.service.recordingApplications.length > 0
            contentWidth: width
            contentHeight: recordingRows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

            Column {
              id: recordingRows
              width: recordingScroll.width - (recordingScroll.contentHeight > recordingScroll.height ? 12 : 0)
              spacing: 6
              Repeater {
                model: popup.service.recordingApplications
                delegate: Rectangle {
                  id: recordingRow
                  required property var modelData
                  width: recordingRows.width
                  height: 48
                  radius: 14
                  color: popup.controller.controlSurface
                  border.width: 1
                  border.color: popup.controller.controlSurfaceBorder
                  Accessible.role: Accessible.StaticText
                  Accessible.name: modelData.name + " using " + modelData.inputDescription
                    + (modelData.muted ? ", input muted" : ", recording")
                  Column {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    spacing: 2
                    Label {
                      width: parent.width
                      color: popup.controller.controlPrimaryText
                      text: recordingRow.modelData.name
                      font.pixelSize: 12
                    }
                    Label {
                      width: parent.width
                      text: recordingRow.modelData.inputDescription + (recordingRow.modelData.muted ? " · Input muted" : " · Recording")
                        + (recordingRow.modelData.streamCount > 1 ? " · " + recordingRow.modelData.streamCount + " streams" : "")
                      font.pixelSize: 10
                    }
                  }
                }
              }
            }
          }

        }
      }

      Item {
        id: settingsFooter
        width: parent.width
        height: 45

        Rectangle {
          width: parent.width
          height: 1
          color: popup.controller.controlSurfaceBorder
        }

        SoundAction {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          width: Math.min(190, parent.width)
          text: "Advanced settings"
          accessibleName: "Advanced sound settings"
          iconName: "sliders"
          onActivated: popup.openAdvancedSettings()
        }
      }
    }
  }
}

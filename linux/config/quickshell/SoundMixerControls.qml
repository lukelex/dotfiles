pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls

Column {
  id: view
  required property var controller
  required property var mixer
  required property bool keyboardEnabled
  signal interacted()
  spacing: 16
  property bool deviceDetails: false
  readonly property var audio: controller.audioService

  component Label: Text {
    width: parent.width
    color: view.controller.controlSecondaryText
    font.family: view.controller.fontFamily
    font.pixelSize: 12
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  component Button: Controls.Button {
    id: button
    property string description: text
    property bool quiet: false
    width: parent.width
    height: 36
    focusPolicy: view.keyboardEnabled ? Qt.StrongFocus : Qt.NoFocus
    onPressed: view.interacted()
    Accessible.name: description
    Controls.ToolTip {
      visible: button.hovered || button.activeFocus
      delay: 500
      implicitWidth: Math.min(320, contentItem.implicitWidth + 20)
      contentItem: Label { text: button.description; color: view.controller.controlPrimaryText }
      background: Rectangle { radius: 8; color: view.controller.controlSurface; border.color: view.controller.controlSurfaceBorder }
    }
    background: Rectangle {
      radius: 10
      color: button.down || button.hovered ? view.controller.controlHover : button.quiet ? "transparent" : view.controller.controlSurface
      border.width: button.activeFocus ? 2 : button.quiet ? 0 : 1
      border.color: button.activeFocus ? view.controller.controlActiveIcon : view.controller.controlSurfaceBorder
    }
    contentItem: Label {
      text: button.text
      color: button.enabled ? view.controller.controlPrimaryText : view.controller.controlSecondaryText
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
      wrapMode: Text.NoWrap
    }
  }

  component Choice: SoundChoice {
    controller: view.controller
    keyboardEnabled: view.keyboardEnabled
    onInteracted: view.interacted()
  }

  component Level: Row {
    id: level
    required property string title
    required property real volume
    property real maximum: 100
    signal edited(real value)
    width: parent.width
    spacing: 8
    height: 32
    Controls.Slider {
      id: slider
      width: level.width - 54
      height: 32
      from: 0
      to: level.maximum
      stepSize: 1
      value: level.volume
      Accessible.name: level.title + " volume"
      focusPolicy: view.keyboardEnabled ? Qt.StrongFocus : Qt.NoFocus
      onPressedChanged: { if (pressed) view.interacted() }
      onMoved: level.edited(value)
      background: Rectangle {
        x: slider.leftPadding
        y: (slider.height - height) / 2
        width: slider.availableWidth
        height: 6
        radius: 3
        color: view.controller.controlSliderTrack
        Rectangle { width: parent.width * slider.visualPosition; height: parent.height; radius: 3; color: view.controller.controlSliderFill }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: (slider.height - height) / 2
        width: 14
        height: 14
        radius: 7
        color: view.controller.controlSliderFill
        border.width: slider.activeFocus ? 2 : 0
        border.color: view.controller.controlActiveIcon
      }
    }
    Label {
      width: 46
      height: parent.height
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignRight
      text: Math.round(level.volume) + "%"
    }
  }

  component TargetControls: Rectangle {
    id: targetRow
    required property var target
    property bool details: false
    property bool amplification: false
    readonly property bool stream: target.kind === "playback" || target.kind === "recording"
    readonly property var routes: view.mixer.devices.filter(device => device.kind === (target.kind === "playback" ? "output" : "input"))
    readonly property bool pending: view.mixer.pendingTarget === target.token
    readonly property var currentDevice: routes.find(device => device.index === target.deviceIndex) || null
    ListModel { id: channelRecords; dynamicRoles: true }
    function syncChannels() {
      view.mixer.syncModel(channelRecords, targetRow.target.channels.map(channel => ({ key: channel.name, name: channel.name, value: channel.value })))
    }
    onTargetChanged: syncChannels()
    Component.onCompleted: syncChannels()
    implicitHeight: targetContent.height + 24
    color: "transparent"
    Rectangle { width: parent.width; height: 1; color: view.controller.controlSurfaceBorder }
    Column {
    id: targetContent
    x: 0
    y: 12
    width: parent.width
    spacing: 8
    Label {
      text: (targetRow.stream ? (targetRow.target.kind === "playback" ? "Playback" : "Recording") + " · " : "")
        + targetRow.target.description + (targetRow.target.paused ? " · Paused" : "")
        + (targetRow.target.kind === "recording" && targetRow.currentDevice?.muted ? " · Input muted" : "")
         + (targetRow.pending ? " · Applying…" : "")
        + (!targetRow.stream && targetRow.target.name === (targetRow.target.kind === "output" ? view.audio.defaultSink : view.audio.defaultSource)
          ? " · Current " + (targetRow.target.kind === "output" ? "output" : "microphone") : "")
      color: view.controller.controlPrimaryText
    }
    RowLayout {
      width: parent.width
      spacing: 6
      LucideIcon {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        source: view.controller.icon(targetRow.target.kind === "recording" || targetRow.target.kind === "input" ? "mic" : targetRow.target.muted ? "volume-x" : "volume-2")
        color: view.controller.controlSecondaryText
      }
      Level {
        Layout.fillWidth: true
        title: targetRow.target.description
        enabled: targetRow.target.channels.length > 0
        volume: targetRow.target.volume
        maximum: targetRow.amplification ? 150 : 100
        onEdited: value => view.mixer.change(targetRow.target, "volume", value)
      }
      Button {
        Layout.preferredWidth: 76
        enabled: !targetRow.pending
        text: targetRow.target.muted ? "Unmute" : "Mute"
        description: text + " " + targetRow.target.description + (targetRow.target.kind === "recording" ? ". Muting this stream does not revoke microphone access." : "")
        onClicked: view.mixer.change(targetRow.target, "mute", !targetRow.target.muted)
      }
    }
    Button {
      quiet: true
      text: (targetRow.details ? "⌄  " : "›  ") + (targetRow.stream ? "Routing, channels & amplification" : "Connector, channels & amplification")
      onClicked: targetRow.details = !targetRow.details
    }
    Choice {
      visible: targetRow.stream && targetRow.details
      enabled: !targetRow.pending
      choices: targetRow.routes
      label: targetRow.target.kind === "playback" ? "Output" : "Input"
      selected: targetRow.routes.find(device => device.index === targetRow.target.deviceIndex)?.name || ""
      onChosen: option => view.mixer.change(targetRow.target, "route", null, { deviceToken: option.token })
    }
    Label {
      visible: targetRow.details && targetRow.stream && targetRow.target.kind === "recording"
      text: "Muting this stream does not revoke microphone access."
      font.pixelSize: 10
    }
    Choice {
      visible: targetRow.details && !targetRow.stream && choices.length > 1
      enabled: !targetRow.pending
      choices: targetRow.target.ports || []
      selected: targetRow.target.activePort || ""
      label: "Connector"
      onChosen: option => view.mixer.change(targetRow.target, "port", option.name)
    }
    Column {
      width: parent.width
      visible: targetRow.details
      spacing: 6
      Button {
        text: targetRow.amplification ? "Limit to 100%" : "Allow amplification to 150%"
        onClicked: targetRow.amplification = !targetRow.amplification
      }
      Label { visible: targetRow.amplification; text: "Amplification can distort audio and be unexpectedly loud." }
      Repeater {
        model: channelRecords
        delegate: Column {
          id: channel
          required property string payload
          readonly property var entry: JSON.parse(payload)
          width: targetContent.width
          Label { text: channel.entry.name }
          Level {
            title: targetRow.target.description + " " + channel.entry.name
            volume: channel.entry.value
            maximum: targetRow.amplification ? 150 : 100
            onEdited: value => view.mixer.change(targetRow.target, "channel", value, { channel: channel.entry.name })
          }
        }
      }
    }
    Label {
      visible: view.mixer.errorTarget === targetRow.target.token
      text: view.mixer.error
      color: view.controller.controlWarningText
    }
    }
  }

  SettingsSection {
    width: view.width
    controller: view.controller
    title: "Current devices"
    iconName: "headphones"
    Column {
      Layout.fillWidth: true
      spacing: 12
      Choice {
        label: "Output"
        choices: view.audio.outputs
        selected: view.audio.defaultSink
        enabled: !view.audio.busy && view.audio.loaded
        onChosen: option => view.audio.setDefaultSink(option.name)
      }
      Choice {
        label: "Microphone"
        choices: view.audio.inputs
        selected: view.audio.defaultSource
        enabled: !view.audio.busy && view.audio.loaded
        onChosen: option => view.audio.setDefaultSource(option.name)
      }
      Label {
        visible: view.audio.busy
        text: "Switching device…"
      }
      Label {
        visible: view.audio.error !== ""
        text: view.audio.error
        color: view.controller.controlWarningText
      }
      Label { text: "Changing these devices also moves running applications. Individual app routes below can override the default." }
    }
  }
  SettingsSection {
    width: view.width
    controller: view.controller
    title: "Applications"
    iconName: "volume-2"
    Column {
      id: applicationContent
      Layout.fillWidth: true
      spacing: 12
      Label { visible: view.mixer.applications.count === 0; text: view.mixer.loading ? "Reading application audio…" : "No apps are using audio. Playback and recording controls appear here when active." }
      Label { visible: view.mixer.error !== "" && !view.mixer.targetTokens.includes(view.mixer.errorTarget); text: view.mixer.error; color: view.controller.controlWarningText }
      Repeater {
        model: view.mixer.applications
        delegate: Column {
          id: application
          required property string payload
          required property string identity
          readonly property var entry: JSON.parse(payload)
          property bool expanded: false
          width: applicationContent.width
          spacing: 8
          ListModel { id: streams; dynamicRoles: true }
          onEntryChanged: view.mixer.syncModel(streams, entry.streams)
          Component.onCompleted: view.mixer.syncModel(streams, entry.streams)
          Label { text: application.entry.name; font.bold: true; color: view.controller.controlPrimaryText }
          Button {
            visible: streams.count > 2
            text: application.expanded ? "Collapse streams" : streams.count + " streams · Show controls"
            onClicked: application.expanded = !application.expanded
          }
          Repeater {
            model: streams
            delegate: TargetControls {
              required property string payload
              width: application.width
              target: JSON.parse(payload)
              visible: streams.count <= 2 || application.expanded
            }
          }
        }
      }
    }
  }
  SettingsSection {
    width: view.width
    controller: view.controller
    title: "Devices & hardware modes"
    iconName: "speaker"
    collapsible: true
    expanded: view.deviceDetails
    onToggled: {
      view.interacted()
      view.deviceDetails = !view.deviceDetails
    }
    Column {
      id: deviceSettings
      Layout.fillWidth: true
      spacing: 12
      ListModel { id: devices; dynamicRoles: true }
      ListModel { id: cards; dynamicRoles: true }
      Connections {
        target: view.mixer
        function onDevicesChanged() { view.mixer.syncModel(devices, view.mixer.devices.filter(device => !device.monitor)) }
        function onCardsChanged() { view.mixer.syncModel(cards, view.mixer.cards) }
      }
      Component.onCompleted: {
        view.mixer.syncModel(devices, view.mixer.devices.filter(device => !device.monitor))
        view.mixer.syncModel(cards, view.mixer.cards)
      }
      Repeater {
        model: devices
        delegate: TargetControls { required property string payload; width: deviceSettings.width; target: JSON.parse(payload) }
      }
      Repeater {
        model: cards
        delegate: Column {
          id: card
          required property string payload
          readonly property var entry: JSON.parse(payload)
          width: deviceSettings.width
          spacing: 6
          Rectangle { width: parent.width; height: 1; color: view.controller.controlSurfaceBorder }
          Label { text: card.entry.description; color: view.controller.controlPrimaryText }
          Choice {
            label: "Mode"
            choices: card.entry.profiles
            selected: card.entry.activeProfile
            enabled: view.mixer.pendingTarget !== card.entry.token
            onChosen: option => view.mixer.change(card.entry, "profile", option.name)
          }
          Label { text: "Changing mode may interrupt sound or change microphone availability. Headset modes can reduce playback quality."; font.pixelSize: 10 }
          Label { visible: view.mixer.errorTarget === card.entry.token; text: view.mixer.error; color: view.controller.controlWarningText }
        }
      }
    }
  }
}

pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Basic as Controls

FloatingWindow {
  id: window

  required property var controller
  required property var service

  title: "Quickshell System Settings"
  visible: false
  implicitWidth: 760
  implicitHeight: 640
  minimumSize: Qt.size(420, 480)
  color: Qt.rgba(controller.controlBackground.r, controller.controlBackground.g, controller.controlBackground.b, 1)
  onVisibleChanged: {
    if (!visible) {
      soundFileDialog.close()
      service.stopSoundPreview()
    }
  }

  function open(targetScreen) {
    visible = false
    if (targetScreen)
      screen = targetScreen
    minimized = false
    visible = true
    content.forceActiveFocus()
  }

  component Label: Text {
    color: window.controller.controlPrimaryText
    font.family: window.controller.fontFamily
    font.pixelSize: 12
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  component Hint: Controls.ToolTip {
    id: hint
    delay: 500
    padding: 8
    implicitWidth: Math.min(320, window.width - 32, contentItem.implicitWidth + 16)
    contentItem: Label {
      text: hint.text
      font.pixelSize: 11
    }
    background: Rectangle {
      radius: 7
      color: window.controller.controlSurface
      border.color: window.controller.controlSurfaceBorder
    }
  }

  component Toggle: Controls.Switch {
    id: toggle
    property string description: ""
    property string iconName: ""
    Accessible.description: description
    hoverEnabled: true
    Hint {
      text: toggle.description
      visible: text.length > 0 && (toggle.hovered || toggle.activeFocus)
    }
    implicitHeight: 36
    spacing: 8
    padding: 0
    opacity: enabled ? 1 : 0.45
    indicator: Rectangle {
      x: toggle.width - width
      y: (toggle.height - height) / 2
      width: 36
      height: 20
      radius: 10
      color: toggle.checked ? window.controller.controlActive : window.controller.controlSliderTrack
      border.width: toggle.activeFocus ? 2 : 1
      border.color: toggle.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
      Rectangle {
        x: toggle.checked ? 18 : 2
        y: 2
        width: 16
        height: 16
        radius: 8
        color: window.controller.controlPrimaryText
      }
    }
    contentItem: Label {
      text: toggle.text
      leftPadding: toggle.iconName ? 28 : 0
      rightPadding: 44
      verticalAlignment: Text.AlignVCenter
      LucideIcon {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        visible: toggle.iconName !== ""
        source: toggle.iconName ? window.controller.icon(toggle.iconName) : ""
        color: toggle.checked ? window.controller.controlPrimaryText : window.controller.controlSecondaryText
      }
    }
  }

  component SoundButton: Controls.Button {
    id: button
    property string iconName: ""
    property string description: text
    implicitHeight: 32
    implicitWidth: contentItem.implicitWidth + 16
    padding: 8
    opacity: enabled ? 1 : 0.45
    Accessible.name: description
    contentItem: RowLayout {
      spacing: 6
      LucideIcon {
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        source: window.controller.icon(button.iconName)
        color: window.controller.controlPrimaryText
      }
      Label {
        visible: button.text !== ""
        text: button.text
      }
    }
    background: Rectangle {
      radius: 8
      color: button.hovered ? window.controller.controlHover : window.controller.controlSurface
      border.color: button.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
    }
    Hint {
      text: button.description
      visible: button.hovered || button.activeFocus
    }
  }

  component Choice: Controls.ComboBox {
    id: choice
    property var selectedValue
    signal chosen(var value)
    textRole: "label"
    valueRole: "value"
    currentIndex: model.findIndex(entry => entry.value === selectedValue)
    onActivated: chosen(currentValue)
    implicitHeight: 36
    font.family: window.controller.fontFamily
    font.pixelSize: 12
    palette.button: window.controller.controlSurface
    palette.buttonText: window.controller.controlPrimaryText
    palette.base: window.controller.controlSurface
    palette.text: window.controller.controlPrimaryText
    palette.highlight: window.controller.controlActive
    palette.highlightedText: window.controller.controlPrimaryText
    background: Rectangle {
      radius: 8
      color: choice.hovered ? window.controller.controlHover : window.controller.controlSurface
      border.color: choice.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
    }
  }

  function monitorChoices() {
    const entries = [{ label: "All monitors", value: "all" }, { label: "Focused monitor", value: "focused" }]
    for (const screen of Quickshell.screens)
      entries.push({ label: screen.name, value: screen.name })
    const saved = window.service.popupMonitor
    if (!entries.some(entry => entry.value === saved))
      entries.push({ label: saved + " (disconnected)", value: saved })
    return entries
  }

  function applicationIcon(application) {
    const systemIcons = {
      "bluetooth connections": "bluetooth",
      "usb connections": "usb",
      "power connection": "battery-charging",
      "system": "settings"
    }
    if (Object.prototype.hasOwnProperty.call(systemIcons, application.key))
      return { kind: "lucide", source: systemIcons[application.key] }
    return window.service.iconFor({ appName: application.appName })
  }

  ColumnLayout {
    id: content
    FileDialog {
      id: soundFileDialog
      title: "Choose notification sound"
      fileMode: FileDialog.OpenFile
      currentFolder: "file://" + Quickshell.env("HOME")
      nameFilters: ["Audio files (*.wav *.mp3 *.ogg *.flac *.aiff *.aif *.opus)", "All files (*)"]
      onAccepted: window.service.setNotificationSoundFile(selectedFile)
    }
    anchors.centerIn: parent
    width: Math.min(1000, parent.width - 32)
    height: parent.height - 32
    spacing: 12
    Keys.onEscapePressed: window.visible = false

    RowLayout {
      Layout.fillWidth: true
      Label {
        text: "System Settings"
        font.pixelSize: 16
        Layout.fillWidth: true
      }
      Controls.Button {
        id: closeButton
        implicitWidth: 32
        implicitHeight: 32
        Accessible.name: "Close settings"
        onClicked: window.visible = false
        contentItem: LucideIcon {
          source: window.controller.icon("x")
          color: window.controller.controlPrimaryText
          implicitWidth: 16
          implicitHeight: 16
        }
        padding: 8
        background: Rectangle {
          radius: 10
          color: closeButton.hovered ? window.controller.controlHover : window.controller.controlSurface
          border.width: closeButton.activeFocus ? 1 : 0
          border.color: window.controller.controlActiveIcon
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 16

      Rectangle {
        id: sidebar
        readonly property bool compact: content.width < 620
        Layout.preferredWidth: compact ? 48 : 172
        Layout.fillHeight: true
        radius: 12
        color: window.controller.controlSurface

        Controls.Button {
          id: notificationsSection
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 6
          height: 40
          padding: 10
          text: "Notifications"
          Accessible.role: Accessible.PageTab
          Accessible.name: "Notifications"
          Accessible.description: "Current settings section"
          Accessible.selected: true
          Controls.ToolTip.visible: sidebar.compact && (hovered || activeFocus)
          Controls.ToolTip.text: text
          Controls.ToolTip.delay: 500

          background: Rectangle {
            radius: 8
            color: window.controller.controlActive
            border.width: notificationsSection.activeFocus ? 1 : 0
            border.color: window.controller.controlActiveIcon
          }
          contentItem: RowLayout {
            spacing: 8
            LucideIcon {
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              source: window.controller.icon("bell")
              color: window.controller.controlActiveIcon
            }
            Label {
              visible: !sidebar.compact
              Layout.fillWidth: true
              text: notificationsSection.text
              font.bold: true
              color: window.controller.controlPrimaryText
            }
          }
        }
      }

      NotificationsPage {
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
    }
  }

  component GeneralOptions: ColumnLayout {
    spacing: 12
    Toggle {
      Layout.fillWidth: true
      text: "Do Not Disturb"
      iconName: "bell-off"
      description: "Pauses popups and sounds. Notifications from enabled apps are still saved in history."
      checked: window.service.doNotDisturb
      onClicked: window.service.setDoNotDisturb(!window.service.doNotDisturb)
    }
    Toggle {
      Layout.fillWidth: true
      text: "Notification sounds"
      iconName: checked ? "volume-2" : "volume-x"
      description: "Controls sound for all apps without changing popups or history. Per-app sound preferences are preserved while muted."
      checked: !window.service.notificationSoundsMuted
      onClicked: window.service.setNotificationSoundsMuted(!window.service.notificationSoundsMuted)
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: window.service.notificationSoundName
        maximumLineCount: 1
        elide: Text.ElideMiddle
        Accessible.name: "Notification sound: " + text
        HoverHandler { id: soundNameHover }
        Hint {
          text: window.service.notificationSoundPath
          visible: soundNameHover.hovered
        }
      }
      SoundButton {
        iconName: "search"
        text: "Choose file…"
        description: "Choose a notification sound from this computer"
        onClicked: soundFileDialog.open()
      }
      SoundButton {
        iconName: window.service.soundPreviewPlaying ? "x" : "play"
        description: window.service.soundPreviewPlaying ? "Stop preview" : "Preview sound (up to 10 seconds, even when muted)"
        onClicked: window.service.soundPreviewPlaying
          ? window.service.stopSoundPreview() : window.service.previewNotificationSound()
      }
      SoundButton {
        iconName: "refresh-cw"
        description: "Reset to the default ICQ sound"
        enabled: window.service.customNotificationSoundPath !== ""
        onClicked: window.service.setNotificationSoundFile("")
      }
    }
    Label {
      Layout.fillWidth: true
      visible: text !== ""
      text: window.service.soundSelectionError
      color: window.controller.controlPrimaryText
    }

    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: 12
      rowSpacing: 8
      Label { text: "Popup monitor" }
      Choice {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        model: window.monitorChoices()
        selectedValue: window.service.popupMonitor
        Accessible.name: "Popup monitor"
        onChosen: value => window.service.setPopupMonitor(value)
      }
      Label { text: "Popup corner" }
      Choice {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        model: [
          { label: "Top right", value: "top-right" },
          { label: "Top left", value: "top-left" },
          { label: "Bottom right", value: "bottom-right" },
          { label: "Bottom left", value: "bottom-left" }
        ]
        selectedValue: window.service.popupCorner
        Accessible.name: "Popup corner"
        onChosen: value => window.service.setPopupCorner(value)
      }
    }
  }

  component NotificationsPage: ColumnLayout {
    spacing: 12
    Label {
      text: "Notifications"
      font.pixelSize: 16
      Accessible.description: "Apps appear here after sending a notification and stay listed after their history is cleared."
      HoverHandler { id: headingHover }
      Hint {
        text: "Apps appear here after sending a notification and stay listed after their history is cleared."
        visible: headingHover.hovered
      }
    }
    Controls.ScrollView {
      id: optionsScroll
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(generalOptions.implicitHeight, parent.height * 0.6)
      contentWidth: availableWidth
      clip: true
      GeneralOptions {
        id: generalOptions
        width: optionsScroll.availableWidth
      }
    }

    Label { text: "Applications"; font.bold: true }
    ListView {
      id: applicationList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: 8
      boundsBehavior: Flickable.StopAtBounds
      // Append-only discovery and a count model preserve delegates, focus and scroll position.
      model: window.service.applications.length
      Controls.ScrollBar.vertical: Controls.ScrollBar {}

      delegate: Rectangle {
        id: applicationRow
        required property int index
        readonly property var application: window.service.applications[index]
        readonly property var appIcon: window.applicationIcon(application)
        width: applicationList.width
        height: rowContent.implicitHeight + 24
        radius: 12
        color: window.controller.controlSurface
        border.color: window.controller.controlSurfaceBorder

        RowLayout {
          id: rowContent
          anchors.fill: parent
          anchors.margins: 12
          spacing: 12

          Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            LucideIcon {
              anchors.fill: parent
              visible: applicationRow.appIcon.kind === "lucide"
              source: visible ? window.controller.icon(applicationRow.appIcon.source) : ""
              color: window.controller.controlSecondaryText
            }
            Image {
              anchors.fill: parent
              visible: applicationRow.appIcon.kind === "image"
              source: visible ? applicationRow.appIcon.source : ""
              fillMode: Image.PreserveAspectFit
              sourceSize: Qt.size(48, 48)
            }
          }

          Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: applicationRow.application.appName
            font.bold: true
          }

          RowLayout {
            spacing: 12
            Toggle {
              Layout.preferredWidth: 72
              iconName: checked ? "bell" : "bell-off"
              description: (checked ? "Notifications on. " : "Notifications off. ")
                + "Turning this off blocks new popups, sounds and history entries from this app. Existing history is kept."
              Accessible.name: applicationRow.application.appName + " notifications"
              checked: applicationRow.application.enabled
              onClicked: window.service.setApplicationPreference(applicationRow.application.key, "enabled", !applicationRow.application.enabled)
            }
            Toggle {
              Layout.preferredWidth: 72
              iconName: checked ? "volume-2" : "volume-x"
              description: (checked ? "Sound on for this app. " : "Sound off for this app. ")
                + "Global sound mute, Do Not Disturb and the sender’s silent-notification preference still apply."
              Accessible.name: applicationRow.application.appName + " notification sound"
              enabled: applicationRow.application.enabled
              checked: applicationRow.application.sound
              onClicked: window.service.setApplicationPreference(applicationRow.application.key, "sound", !applicationRow.application.sound)
            }
          }
        }
      }

      Label {
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: applicationList.count === 0
        color: window.controller.controlSecondaryText
        text: "No apps yet."
      }
    }
  }
}

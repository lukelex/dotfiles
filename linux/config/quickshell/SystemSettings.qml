pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Basic as Controls

FloatingWindow {
  id: window

  required property var controller
  required property var service
  required property var connectivity
  readonly property var monitors: monitorLoader.item?.monitorService ?? null
  property string section: "system"
  readonly property bool displayPage: section === "monitors" || section === "display"
  readonly property string sidebarSection: displayPage ? "monitors" : section
  property string connectivityAnchor: "networks"
  property bool connectivityAdvanced: false
  readonly property bool wifiDiscoveryActive: visible && section === "connectivity"
  onSectionChanged: {
    connectivityAnchor = "networks"
    connectivityAdvanced = false
  }
  readonly property var sections: [
    { key: "system", label: "System information", icon: "cpu", group: "System" },
    { key: "power", label: "Power & battery", icon: "battery", group: "System" },
    { key: "connectivity", label: "Wi-Fi", icon: "wifi", group: "Devices & connections" },
    { key: "bluetooth", label: "Bluetooth", icon: "bluetooth", group: "Devices & connections" },
    { key: "storage", label: "Storage & mounts", icon: "hard-drive", group: "Devices & connections" },
    { key: "monitors", label: "Displays", icon: "monitor", group: "Devices & connections" },
    { key: "audio", label: "Sound", icon: "volume-2", group: "Devices & connections" },
    { key: "input", label: "Keyboard & pointer", icon: "keyboard", group: "Devices & connections" },
    { key: "desktop", label: "Desktop & bar", icon: "settings", group: "Desktop & appearance" },
    { key: "wallpaper", label: "Wallpaper", icon: "gallery-horizontal-end", group: "Desktop & appearance" },
    { key: "lockScreen", label: "Lock screen appearance", icon: "lock", group: "Desktop & appearance" },
    { key: "notifications", label: "Notifications", icon: "bell", group: "Behavior" },
    { key: "idle", label: "Idle & locking", icon: "clock", group: "Behavior" },
    { key: "weather", label: "Clock & weather", icon: "calendar", group: "Behavior" }
  ]

  title: "Quickshell System Settings"
  visible: false
  implicitWidth: 760
  implicitHeight: 640
  minimumSize: Qt.size(420, 480)
  color: Qt.rgba(controller.controlBackground.r, controller.controlBackground.g, controller.controlBackground.b, 1)
  onVisibleChanged: {
    if (!visible) {
      soundFileDialog.close()
      wallpaperFileDialog.close()
      wallpaperFolderDialog.close()
      service.stopSoundPreview()
    }
  }

  Binding {
    target: window.controller.audioService
    property: "mixerSettingsActive"
    value: window.visible && window.section === "audio"
  }
  Process {
    id: advancedAudioSettings
    command: ["pavucontrol"]
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
    font.underline: activeFocus
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  component Hint: SettingsHint {
    controller: window.controller
  }

  component Toggle: SettingsToggle {
    controller: window.controller
  }

  component SoundButton: SettingsButton {
    controller: window.controller
  }

  component Choice: SettingsChoice {
    id: choice
    controller: window.controller
    property var selectedValue
    signal chosen(var value)
    textRole: "label"
    valueRole: "value"
    currentIndex: model.findIndex(entry => entry.value === selectedValue)
    onActivated: chosen(currentValue)
  }

  component ScheduleTime: SettingsTextField {
    id: timeInput
    controller: window.controller
    required property int minutesValue
    signal edited(int minutes)
    text: window.service.formatScheduleTime(minutesValue)
    implicitWidth: 76
    implicitHeight: 36
    horizontalAlignment: TextInput.AlignHCenter
    font.family: window.controller.fontFamily
    font.pixelSize: 12
    color: window.controller.controlPrimaryText
    selectByMouse: true
    // Permit intermediate values (e.g. "1" or "19:") while typing; the
    // complete value is still checked before it is committed.
    validator: RegularExpressionValidator { regularExpression: /([01]?[0-9]|2[0-3])?:?[0-5]?[0-9]?/ }
    onEditingFinished: {
      if (/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(text)) {
        const parts = text.split(":")
        edited(Number(parts[0]) * 60 + Number(parts[1]))
      }
      text = Qt.binding(() => window.service.formatScheduleTime(timeInput.minutesValue))
    }
    onActiveFocusChanged: {
      if (!activeFocus && !acceptableInput)
        text = Qt.binding(() => window.service.formatScheduleTime(timeInput.minutesValue))
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
      id: wallpaperFileDialog
      title: "Choose wallpaper"
      fileMode: FileDialog.OpenFile
      nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)"]
      currentFolder: "file://" + Quickshell.env("HOME")
      onAccepted: wallpaperAction.run("choose", selectedFile.toString())
    }
    FolderDialog {
      id: wallpaperFolderDialog
      title: "Choose random wallpaper folder"
      onAccepted: {
        const path = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
        window.controller.preferences.setValue("wallpaper.folder", path.startsWith(Quickshell.env("HOME") + "/")
          ? "~" + path.slice(Quickshell.env("HOME").length) : path)
      }
    }
    QtObject {
      id: wallpaperAction
      property string error: ""
      property Process process: Process {
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) wallpaperAction.error = text.trim() } }
      }
      function run(action, path = "") {
        if (process.running) return
        error = ""
        process.command = ["python3", Quickshell.env("HOME") + "/dotfiles/linux/config/system-settings/wallpaper.py", action]
          .concat(path ? [path] : [])
        process.running = true
      }
    }
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
      visible: monitors?.pending ?? false
      Layout.fillWidth: true
      Label {
        Layout.fillWidth: true
        text: "Keep this display layout? Reverting in " + (monitors?.secondsLeft ?? 0) + " seconds."
      }
      SoundButton {
        text: "Revert"
        enabled: monitors !== null && !monitors.busy
        onClicked: monitors.run("revert", monitors.snapshot.pending.token)
      }
      SoundButton {
        text: "Keep changes"
        enabled: monitors !== null && !monitors.busy
        onClicked: monitors.run("keep", monitors.snapshot.pending.token)
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

        function revealSelection() {
          if (!window.visible) return
          const index = window.sections.findIndex(entry => entry.key === window.sidebarSection)
          const entry = sectionEntries.itemAt(index)
          const flick = sidebarScroll.contentItem as Flickable
          if (!entry || !flick || flick.moving) return
          const top = entry.y
          const bottom = top + entry.height
          if (top < flick.contentY)
            flick.contentY = top
          else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height
          flick.returnToBounds()
        }
        onCompactChanged: Qt.callLater(revealSelection)
        onHeightChanged: Qt.callLater(revealSelection)
        Connections {
          target: window
          function onSidebarSectionChanged() { Qt.callLater(sidebar.revealSelection) }
          function onVisibleChanged() { if (window.visible) Qt.callLater(sidebar.revealSelection) }
        }
        Controls.ScrollView {
          id: sidebarScroll
          anchors.fill: parent
          anchors.margins: 6
          contentWidth: availableWidth
          clip: true
          Binding {
            target: sidebarScroll.contentItem
            property: "boundsBehavior"
            value: Flickable.StopAtBounds
          }
        Column {
          width: sidebar.width - 12
          spacing: 4
          Repeater {
            id: sectionEntries
            model: window.sections
            delegate: Column {
              id: sectionEntry
              required property var modelData
              required property int index
              readonly property bool startsGroup: index === 0 || window.sections[index - 1].group !== modelData.group
              width: sidebar.width - 12
              spacing: 4
              Label {
                visible: sectionEntry.startsGroup && !sidebar.compact
                width: parent.width
                topPadding: sectionEntry.index === 0 ? 6 : 14
                bottomPadding: 4
                leftPadding: 10
                rightPadding: 10
                text: sectionEntry.modelData.group
                font.pixelSize: 11
                font.bold: true
                color: window.controller.controlSecondaryText
              }
              Item {
                visible: sectionEntry.startsGroup && sectionEntry.index > 0 && sidebar.compact
                width: parent.width
                height: 13
                Rectangle {
                  anchors.centerIn: parent
                  width: parent.width - 12
                  height: 1
                  color: window.controller.controlSurfaceBorder
                }
              }
              Controls.Button {
              id: sectionButton
              readonly property var modelData: sectionEntry.modelData
              width: sidebar.width - 12
              height: Math.max(40, contentItem.implicitHeight + 20)
              padding: 10
              text: modelData.label
              Accessible.role: Accessible.PageTab
              Accessible.name: text
              Accessible.selected: window.sidebarSection === modelData.key
              onClicked: window.section = modelData.key
              Hint {
                visible: sidebar.compact && (sectionButton.hovered || sectionButton.activeFocus)
                text: sectionButton.text
              }
              background: Rectangle {
                radius: 8
                color: window.sidebarSection === sectionButton.modelData.key ? window.controller.controlActive
                  : sectionButton.hovered ? window.controller.controlHover : "transparent"
                border.width: sectionButton.activeFocus ? 1 : 0
                border.color: window.controller.controlActiveIcon
              }
              contentItem: RowLayout {
                spacing: 8
                LucideIcon {
                  Layout.preferredWidth: 16
                  Layout.preferredHeight: 16
                  source: window.controller.icon(sectionButton.modelData.icon)
                  color: window.sidebarSection === sectionButton.modelData.key ? window.controller.controlActiveIcon : window.controller.controlSecondaryText
                }
                Label {
                  visible: !sidebar.compact
                  Layout.fillWidth: true
                  text: sectionButton.text
                  font.bold: window.sidebarSection === sectionButton.modelData.key
                }
              }
              }
            }
          }
        }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12
        Label {
          visible: window.displayPage
          Layout.fillWidth: true
          text: "Displays"
          font.pixelSize: 16
          font.bold: true
        }
        RowLayout {
          visible: window.displayPage
          Layout.fillWidth: true
          spacing: 8
          Repeater {
            model: [
              { key: "monitors", label: "Arrangement & resolution" },
              { key: "display", label: "Brightness & night color" }
            ]
            delegate: SoundButton {
              id: displayTab
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              text: modelData.label
              implicitHeight: Math.max(36, contentItem.implicitHeight + 16)
              Accessible.role: Accessible.PageTab
              Accessible.selected: window.section === modelData.key
              onClicked: window.section = modelData.key
              contentItem: Label {
                text: displayTab.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              background: Rectangle {
                radius: 8
                color: window.section === displayTab.modelData.key ? window.controller.controlActive
                  : displayTab.hovered ? window.controller.controlHover : window.controller.controlSurface
                border.width: displayTab.activeFocus ? 2 : 1
                border.color: displayTab.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
              }
            }
          }
        }
      NotificationsPage {
        visible: window.section === "notifications"
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
      PreferencesPage {
        visible: !["system", "notifications", "monitors"].includes(window.section)
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
      OptionalModule {
        id: monitorLoader
        module: "MonitorSettings.qml"
        initialProperties: () => ({ settingsWindow: window })
        visible: window.section === "monitors" && status === Loader.Ready
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
      OptionalModule {
        module: "SystemInformation.qml"
        visible: window.section === "system" && status === Loader.Ready
        Layout.fillWidth: true
        Layout.fillHeight: true
        initialProperties: () => ({
          controller: window.controller,
          active: Qt.binding(() => window.visible && window.section === "system")
        })
      }
      }
    }
  }

  component PreferencesPage: ColumnLayout {
    spacing: 12
    Label {
      Layout.fillWidth: true
      visible: !window.displayPage
      text: window.sections.find(entry => entry.key === window.section)?.label || ""
      font.pixelSize: 16
      font.bold: true
    }
    SettingsScrollView {
      id: preferenceScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      Connections {
        target: window
        function onSectionChanged() { preferenceScroll.resetPosition() }
        function onVisibleChanged() {
          if (!window.visible) return
          preferenceScroll.resetPosition()
          Qt.callLater(() => {
            if (!window.visible || window.section !== "connectivity" || window.connectivityAnchor !== "preferences") return
            const flick = preferenceScroll.flickable
            if (flick && !flick.moving) {
              flick.contentY = Math.min(connectivityPreferences.y,
                Math.max(flick.originY, flick.contentHeight - flick.height + flick.originY))
            }
          })
        }
      }
      ColumnLayout {
        width: preferenceScroll.availableWidth
        spacing: 16
        SettingsSubsection {
          id: preferenceStatus
          readonly property var preferences: window.controller.preferences
          readonly property bool failed: preferences.error !== "" && (preferences.errorKeys.length === 0 || preferences.errorKeys.includes(window.section))
          readonly property bool pending: preferences.busy && preferences.activeKeys.includes(window.section)
          Layout.fillWidth: true
          visible: failed || pending
          title: "Preferences"
          iconName: "settings"
          Label {
            Layout.fillWidth: true
            text: preferenceStatus.failed ? preferenceStatus.preferences.error : "Applying changes…"
            color: preferenceStatus.failed ? window.controller.controlWarningText : window.controller.controlSecondaryText
          }
        }
        Label {
          Layout.fillWidth: true
          visible: window.section === "lockScreen"
          text: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
            ? "Hyprlock appearance · changes apply the next time you lock."
            : "These appearance controls apply to Hyprlock on Wayland. Your X11 locker remains unchanged."
          color: window.controller.controlSecondaryText
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "power" && window.controller.batteryAvailable
          title: "Battery"
          iconName: window.controller.batteryIcon()
          Label {
            Layout.fillWidth: true
            text: window.controller.batteryPercentage + "% · " + window.controller.batteryState.replace(/-/g, " ")
              + (window.controller.batteryHealthAvailable ? " · Health " + Math.round(window.controller.batteryHealth) + "%" : "")
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: window.controller.controlSliderTrack
            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, window.controller.batteryPercentage / 100))
              height: parent.height
              radius: 3
              color: window.controller.controlSecondaryText
            }
          }
        }
        Label {
          Layout.fillWidth: true
          visible: window.section === "power"
          text: "Configure battery warnings. Power-profile selection stays in Control Center."
          color: window.controller.controlSecondaryText
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "power"
          title: "Battery warnings"
          iconName: "battery-warning"
          Label {
            Layout.fillWidth: true
            text: "Warn once per level in a discharge episode. Critical, urgent and final levels use critical urgency; notification policies still apply."
            color: window.controller.controlSecondaryText
          }
          Repeater {
          model: window.section === "power" ? [
            { key: "low", title: "Low battery", icon: "battery-low" },
            { key: "critical", title: "Critical battery", icon: "battery-warning" },
            { key: "urgent", title: "Urgent battery", icon: "battery-warning" },
            { key: "final", title: "Final warning", icon: "battery" }
          ] : []
          delegate: ColumnLayout {
            id: batteryWarning
            required property var modelData
            required property int index
            readonly property string enabledKey: "power." + modelData.key + "WarningEnabled"
            readonly property string thresholdKey: "power." + modelData.key + "Threshold"
            readonly property var threshold: window.controller.preferences.value(thresholdKey, "")
            Layout.fillWidth: true
            spacing: 12
            enabled: window.controller.preferences.ready && !window.controller.preferences.busy
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 1
              visible: batteryWarning.index > 0
              color: window.controller.controlSurfaceBorder
            }
            Toggle {
              Layout.fillWidth: true
              text: batteryWarning.modelData.title
              Accessible.name: batteryWarning.modelData.title + " warning enabled"
              checked: window.controller.preferences.value(batteryWarning.enabledKey, true)
              onClicked: window.controller.preferences.setValue(batteryWarning.enabledKey,
                !window.controller.preferences.value(batteryWarning.enabledKey, true))
            }
            SettingsGrid {
              id: thresholdLayout
              Layout.fillWidth: true
              Label { Layout.fillWidth: true; text: "Battery threshold (%)" }
              SettingsTextField {
                id: batteryThreshold
                controller: window.controller
                Layout.alignment: Qt.AlignRight
                Layout.fillWidth: !thresholdLayout.inlineEditors
                Layout.preferredWidth: 80
                implicitWidth: 80
                text: String(batteryWarning.threshold)
                Accessible.name: batteryWarning.modelData.title + " threshold (%)"
                horizontalAlignment: Text.AlignHCenter
                color: window.controller.controlPrimaryText
                selectionColor: window.controller.controlActive
                selectedTextColor: window.controller.controlPrimaryText
                font.family: window.controller.fontFamily
                font.pixelSize: 12
                onEditingFinished: {
                  const value = Number(text)
                  if (value !== batteryWarning.threshold)
                    window.controller.preferences.setValue(batteryWarning.thresholdKey, value)
                  text = Qt.binding(() => String(batteryWarning.threshold))
                }
              }
            }
            PreferenceStatus { controller: window.controller; preferences: window.controller.preferences; keys: [batteryWarning.enabledKey, batteryWarning.thresholdKey] }
          }
          }
        }
        OptionalModule {
          id: mixerControls
          module: "SoundMixerControls.qml"
          active: !!window.controller.audioService.mixer
          visible: window.section === "audio" && status === Loader.Ready
          Layout.fillWidth: true
          initialProperties: () => ({
            controller: window.controller, mixer: Qt.binding(() => window.controller.audioService.mixer),
            keyboardEnabled: true
          })
          Connections {
            target: mixerControls.item
            function onDisclosureToggled() { preferenceScroll.preservePosition() }
          }
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "audio"
          title: "Keyboard volume steps"
          iconName: "keyboard"
          Repeater {
            model: window.controller.preferences.fields.filter(field => field.key.startsWith("audio."))
            delegate: ColumnLayout {
              id: audioField
              required property var modelData
              required property int index
              Layout.fillWidth: true
              spacing: 12
              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                visible: audioField.index > 0
                color: window.controller.controlSurfaceBorder
              }
              PreferenceField { modelData: audioField.modelData }
            }
          }
        }
        WifiSettings {
          Layout.fillWidth: true
          visible: window.section === "connectivity"
          controller: window.controller
          service: window.connectivity
          onDisclosureToggled: preferenceScroll.preservePosition()
        }
        OptionalModule {
          module: "UsbStorageSettings.qml"
          Layout.fillWidth: true
          visible: window.section === "storage" && status === Loader.Ready
          initialProperties: () => ({
            controller: window.controller, preferences: window.controller.preferences,
            pageActive: Qt.binding(() => window.visible && window.section === "storage")
          })
        }
        SettingsSubsection {
          id: connectivityPreferences
          Layout.fillWidth: true
          visible: window.section === "connectivity"
          title: "Wi-Fi suggestions"
          iconName: "bell"
          enabled: window.controller.preferences.ready && !window.controller.preferences.busy
          Toggle {
            Layout.fillWidth: true
            text: "Suggest stronger saved Wi-Fi"
            checked: window.controller.preferences.value("connectivity.wifiSuggestions", true)
            description: "Offers a stronger saved network when your signal is weak. Switching always requires your confirmation."
            onClicked: window.controller.preferences.setValue("connectivity.wifiSuggestions", !window.controller.preferences.value("connectivity.wifiSuggestions", true))
          }
          PreferenceStatus { controller: window.controller; preferences: window.controller.preferences; keys: ["connectivity.wifiSuggestions"] }
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "connectivity"
          title: "Advanced tuning"
          iconName: "sliders"
          collapsible: true
          expanded: window.connectivityAdvanced
          onToggled: {
            preferenceScroll.preservePosition()
            window.connectivityAdvanced = !window.connectivityAdvanced
          }
          Label {
            Layout.fillWidth: true
            text: "Thresholds and timing are saved in preferences.json. Suggestions never switch networks automatically."
            color: window.controller.controlSecondaryText
          }
          Repeater {
            model: window.controller.preferences.fields.filter(field => field.key.startsWith("connectivity.")
              && !field.key.startsWith("connectivity.bluetooth") && window.connectivityAdvanced && field.kind !== "boolean")
            delegate: ColumnLayout {
              id: connectivityField
              required property var modelData
              Layout.fillWidth: true
              spacing: 12
              Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: window.controller.controlSurfaceBorder }
              PreferenceField { modelData: connectivityField.modelData }
            }
          }
        }
        BluetoothSettings {
          Layout.fillWidth: true
          visible: window.section === "bluetooth"
          active: window.visible && visible
          controller: window.controller
          service: window.connectivity
          onDisclosureToggled: preferenceScroll.preservePosition()
          onRevealRequested: item => {
            const flick = preferenceScroll.flickable
            if (!flick || flick.moving || !window.visible || window.section !== "bluetooth") return
            const top = item.mapToItem(flick.contentItem, 0, 0).y
            if (top < flick.contentY || top + item.height > flick.contentY + flick.height) {
              flick.contentY = top
              flick.returnToBounds()
            }
          }
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "bluetooth"
          title: "Battery alerts"
          iconName: "battery-low"
          Repeater {
            model: window.controller.preferences.fields.filter(field => field.key.startsWith("connectivity.bluetooth"))
            delegate: ColumnLayout {
              id: bluetoothField
              required property var modelData
              required property int index
              Layout.fillWidth: true
              spacing: 12
              Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: bluetoothField.index > 0; color: window.controller.controlSurfaceBorder }
              PreferenceField { modelData: bluetoothField.modelData }
            }
          }
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "bluetooth"
          title: "Advanced Bluetooth"
          iconName: "settings"
          Label { Layout.fillWidth: true; text: "Open Blueman for additional adapter and service controls." }
          SoundButton { text: "Advanced Bluetooth settings…"; onClicked: Quickshell.execDetached(["blueman-manager"]) }
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "input" && Quickshell.env("XDG_SESSION_TYPE") === "x11"
            && (window.controller.preferences.x11Input.error !== "" || window.controller.preferences.x11Input.keys.length === 0)
          title: "Mouse & trackpad"
          iconName: "mouse"
          Label {
            Layout.fillWidth: true
            text: window.controller.preferences.x11Input.error || "No supported libinput pointing devices detected. Connect a mouse or trackpad to configure it."
            color: window.controller.controlSecondaryText
          }
        }
        Label {
          Layout.fillWidth: true
          visible: window.section === "input"
          text: "Pointer sensitivity and acceleration apply to both mouse and trackpad. Scrolling and tap settings are configured separately."
          color: window.controller.controlSecondaryText
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "wallpaper"
          title: "Choose wallpaper"
          iconName: "gallery-horizontal-end"
          Flow {
            Layout.fillWidth: true
            spacing: 8
            enabled: !wallpaperAction.process.running
            SoundButton { text: "Choose image…"; onClicked: wallpaperFileDialog.open() }
            SoundButton { text: "Choose folder…"; onClicked: wallpaperFolderDialog.open() }
            SoundButton { text: "Random now"; onClicked: wallpaperAction.run("random") }
            SoundButton { text: "Restore saved"; onClicked: wallpaperAction.run("restore") }
          }
          Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: wallpaperAction.process.running ? "Applying wallpaper…" : wallpaperAction.error
            color: wallpaperAction.error ? window.controller.controlWarningText : window.controller.controlSecondaryText
          }
        }
        Repeater {
          model: {
            const groups = {
              display: [
                { title: "Brightness controls", icon: "sun", keys: ["display.linkBrightness", "display.brightnessStep", "display.lockBrightness"] },
                { title: "Night color", icon: "moon", keys: ["display.dayTemperature", "display.nightTemperature"] },
                { title: "Sunrise & sunset", icon: "globe", keys: ["display.latitude", "display.longitude"] },
                { title: "On-screen indicators", icon: "monitor", keys: ["display.osdDurationMs"] }
              ],
              wallpaper: [
                { title: "Wallpaper at login", icon: "monitor", keys: ["wallpaper.startupMode", "wallpaper.folder"] }
              ],
              idle: [
                { title: "Dim, lock & screen-off timers", icon: "clock", keys: ["idle.dimSeconds", "idle.lockSeconds", "idle.screenOffSeconds", "idle.x11LockSeconds", "idle.x11ScreenOffSeconds"] },
                { title: "Postpone locking", icon: "lock", keys: ["idle.deferFullscreen", "idle.deferMicrophone", "idle.deferCamera"] }
              ],
              lockScreen: [
                { title: "Greeting & daily content", icon: "user", keys: ["lockScreen.showGreeting", "lockScreen.showQuote", "lockScreen.showWeather"] },
                { title: "System status", icon: "gauge", keys: ["lockScreen.showBattery", "lockScreen.showNetwork", "lockScreen.showVpn", "lockScreen.showAudio", "lockScreen.showDnd"] },
                { title: "Privacy & security", icon: "lock", keys: ["lockScreen.showPrivacy", "lockScreen.showSecurity"] },
                { title: "Media", icon: "play", keys: ["lockScreen.showMedia", "lockScreen.showMediaArtwork"] },
                { title: "Wallpaper & backdrop", icon: "monitor", keys: ["lockScreen.wallpaperBlur", "lockScreen.wallpaperBlurPasses", "lockScreen.wallpaperBrightness"] }
              ],
              input: [
                { title: "Keyboard", icon: "keyboard", keys: ["input.repeatDelay", "input.repeatRate"] },
                { title: "Pointer", icon: "mouse", keys: ["input.sensitivity", "input.acceleration"] },
                { title: "Mouse", icon: "mouse", keys: ["input.naturalScroll"] },
                { title: "Trackpad", icon: "laptop", keys: ["input.touchpadNaturalScroll", "input.tapToClick", "input.disableWhileTyping"] }
              ],
              weather: [
                { title: "Clock & calendar", icon: "calendar", keys: ["clock.hourFormat", "clock.dateFormat", "clock.firstDay"] },
                { title: "Weather", icon: "cloud-sun", keys: ["weather.locationMode", "weather.city", "weather.units"] }
              ],
              desktop: [
                { title: "Bar appearance", icon: "layout-panel-top", keys: ["desktop.density"] },
                { title: "Panel interactions", icon: "mouse", keys: ["desktop.hoverPreviews", "desktop.hoverCloseDelayMs"] }
              ]
            }
            return (groups[window.section] || []).map(group => ({
              title: group.title, icon: group.icon,
              fields: group.keys.map(key => window.controller.preferences.fields.find(field => field.key === key))
                .filter(field => field && (!field.session || field.session === Quickshell.env("XDG_SESSION_TYPE")
                  || Quickshell.env("XDG_SESSION_TYPE") === "x11" && field.key.startsWith("input.")
                    && window.controller.preferences.x11Input.keys.includes(field.key.split(".")[1])))
            })).filter(group => group.fields.length > 0)
          }
          delegate: SettingsSubsection {
            id: preferenceGroup
            required property var modelData
            Layout.fillWidth: true
            title: modelData.title
            iconName: modelData.icon
            Repeater {
              model: preferenceGroup.modelData.fields
              delegate: ColumnLayout {
                id: groupedField
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: 1
                  visible: groupedField.index > 0
                  color: window.controller.controlSurfaceBorder
                }
                PreferenceField {
                  Layout.fillWidth: true
                  modelData: groupedField.modelData
                }
              }
            }
          }
        }
        Flow {
          Layout.fillWidth: true
          visible: ["lockScreen", "idle"].includes(window.section)
          spacing: 8
          SoundButton {
            visible: window.section === "lockScreen"
            text: "Idle & locking…"
            onClicked: window.section = "idle"
          }
          SoundButton {
            visible: window.section === "lockScreen"
            text: "Notifications…"
            description: "Configure notification popups, privacy and history"
            onClicked: window.section = "notifications"
          }
          SoundButton {
            visible: window.section === "idle"
            text: "Lock screen appearance…"
            onClicked: window.section = "lockScreen"
          }
        }
        SettingsSubsection {
          Layout.fillWidth: true
          visible: window.section === "audio"
          title: "Advanced audio"
          iconName: "sliders"
          Label {
            Layout.fillWidth: true
            text: "Open pavucontrol for speaker testing and additional hardware controls."
            color: window.controller.controlSecondaryText
          }
          SoundButton {
            text: "Advanced audio settings…"
            onClicked: advancedAudioSettings.running = true
          }
        }
      }
    }
  }

  component PreferenceField: ColumnLayout {
    id: preferenceRow
    required property var modelData
    readonly property var currentValue: window.controller.preferences.value(modelData.key, "")
    Layout.fillWidth: true
    spacing: 6
    enabled: window.controller.preferences.ready && !window.controller.preferences.busy
    Toggle {
      Layout.fillWidth: true
      visible: preferenceRow.modelData.kind === "boolean"
      text: preferenceRow.modelData.label
      checked: preferenceRow.currentValue === true
      description: preferenceRow.modelData.key === "desktop.hoverPreviews"
        ? "Calendar, connectivity, audio, reviews and Control Center. Notification history and privacy indicators remain available on hover."
        : preferenceRow.modelData.key === "display.linkBrightness" ? "When setting laptop brightness, also set keyboard and DDC-capable external displays to the same percentage. Enabling this does not immediately change any device."
        : preferenceRow.modelData.key === "connectivity.bluetoothBatteryAlerts" ? "Warn once per device below the selected threshold. Disconnecting or recovering above the threshold rearms alerts; existing notification policies still apply."
        : window.section === "lockScreen" ? "Changes apply on the next lock. Hiding a widget removes its label or image and stops its helper from running. Authentication, date/time and explicit locking are unchanged."
        : window.section === "connectivity" ? "Only offers a stronger saved network on the same adapter. Clicking Switch rechecks your current preferences and network availability." : ""
      onClicked: window.controller.preferences.setValue(preferenceRow.modelData.key, !preferenceRow.currentValue)
    }
    GridLayout {
      id: fieldLayout
      Layout.fillWidth: true
      visible: preferenceRow.modelData.kind !== "boolean"
      readonly property real editorWidth: preferenceRow.modelData.kind === "choice"
        ? Math.max(140, ...preferenceChoice.model.map(entry => fieldMetrics.advanceWidth(entry.label) + 56))
        : preferenceRow.modelData.kind === "number"
          ? Math.max(100, ...preferenceRow.modelData.values.map(value => fieldMetrics.advanceWidth(String(value)) + 28))
          : Math.max(180, fieldMetrics.advanceWidth(String(preferenceRow.currentValue)) + 28)
      readonly property bool inlineEditor: width >= fieldMetrics.advanceWidth(preferenceRow.modelData.label) + editorWidth + 16
      columns: inlineEditor ? 2 : 1
      columnSpacing: 16
      rowSpacing: 6
      FontMetrics {
        id: fieldMetrics
        font.family: window.controller.fontFamily
        font.pixelSize: 12
      }
    Label {
      Layout.fillWidth: true
      text: preferenceRow.modelData.label
    }
    Choice {
      id: preferenceChoice
      Layout.fillWidth: !fieldLayout.inlineEditor
      Layout.preferredWidth: fieldLayout.inlineEditor ? fieldLayout.editorWidth : -1
      Layout.alignment: Qt.AlignRight
      visible: preferenceRow.modelData.kind === "choice"
      model: preferenceRow.modelData.values.map(value => {
        const labels = {
          automatic: "Automatic (IP location)", fixed: "Fixed city",
          metric: "Celsius · metres/second", imperial: "Fahrenheit · miles/hour",
          flat: "Off (flat)", adaptive: "Adaptive", comfortable: "Comfortable", compact: "Compact",
          random: "Random from folder", restore: "Restore saved image",
          "24": "24-hour", "12": "12-hour", "0": "Sunday", "1": "Monday"
        }
        const label = preferenceRow.modelData.key === "clock.dateFormat"
          ? Qt.formatDate(new Date(), String(value)) : labels[String(value)] || String(value)
        return { label: label, value: value }
      })
      selectedValue: preferenceRow.currentValue
      Accessible.name: preferenceRow.modelData.label
      onChosen: value => window.controller.preferences.setValue(preferenceRow.modelData.key, value)
    }
    SettingsTextField {
      id: preferenceInput
      controller: window.controller
      Layout.fillWidth: !fieldLayout.inlineEditor
      Layout.preferredWidth: fieldLayout.inlineEditor ? fieldLayout.editorWidth : -1
      Layout.alignment: Qt.AlignRight
      visible: ["text", "number"].includes(preferenceRow.modelData.kind)
      text: String(preferenceRow.currentValue)
      color: window.controller.controlPrimaryText
      selectionColor: window.controller.controlActive
      selectedTextColor: window.controller.controlPrimaryText
      font.family: window.controller.fontFamily
      font.pixelSize: 12
      Accessible.name: preferenceRow.modelData.label
      onEditingFinished: {
        const value = preferenceRow.modelData.kind === "number" ? Number(text) : text.trim()
        if (value !== preferenceRow.currentValue)
          window.controller.preferences.setValue(preferenceRow.modelData.key, value)
        text = Qt.binding(() => String(preferenceRow.currentValue))
      }
    }
    }
    Controls.Slider {
      id: temperatureSlider
      Layout.fillWidth: true
      visible: preferenceRow.modelData.key.endsWith("Temperature")
      from: 2500
      to: 10000
      stepSize: 100
      value: Number(preferenceRow.currentValue) || 2500
      Accessible.name: preferenceRow.modelData.label
      onPressedChanged: {
        if (!pressed && visible && value !== preferenceRow.currentValue)
          window.controller.preferences.setValue(preferenceRow.modelData.key, Math.round(value))
      }
      onMoved: {
        if (!pressed && visible)
          window.controller.preferences.setValue(preferenceRow.modelData.key, Math.round(value))
      }
      background: Rectangle {
        x: temperatureSlider.leftPadding
        y: temperatureSlider.topPadding + temperatureSlider.availableHeight / 2 - height / 2
        width: temperatureSlider.availableWidth
        height: 6
        radius: 3
        color: window.controller.controlSliderTrack
        Rectangle {
          width: temperatureSlider.visualPosition * parent.width
          height: parent.height
          radius: 3
          color: window.controller.controlActiveIcon
        }
      }
      handle: Rectangle {
        x: temperatureSlider.leftPadding + temperatureSlider.visualPosition * (temperatureSlider.availableWidth - width)
        y: temperatureSlider.topPadding + temperatureSlider.availableHeight / 2 - height / 2
        implicitWidth: 18
        implicitHeight: 18
        radius: 9
        color: window.controller.controlPrimaryText
        border.width: temperatureSlider.activeFocus ? 2 : 0
        border.color: window.controller.controlActiveIcon
      }
    }
    PreferenceStatus { controller: window.controller; preferences: window.controller.preferences; keys: [preferenceRow.modelData.key] }
  }

  component SettingsSubsection: SettingsSection {
    controller: window.controller
  }

  component GeneralOptions: ColumnLayout {
    id: notificationOptions
    required property var scrollView
    property bool quietHoursExpanded: false
    property bool soundExpanded: false
    property bool presentationExpanded: false
    property bool privacyExpanded: false
    function toggleDetails(key) {
      const offset = scrollView.contentY - scrollView.originY
      notificationOptions[key] = !notificationOptions[key]
      scrollView.restoreHeaderOffset(offset)
    }
    spacing: 16
    SettingsSubsection {
      Layout.fillWidth: true
      title: "Notification delivery"
      iconName: "bell"
    Toggle {
      Layout.fillWidth: true
      text: "Do Not Disturb"
      showHint: false
      iconName: "bell-off"
      description: "Pauses popups and sounds, except allowed critical alerts. Notifications from enabled apps are still saved in history."
      checked: window.service.doNotDisturb
      onClicked: window.service.setDoNotDisturb(!window.service.doNotDisturb)
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: window.controller.controlSurfaceBorder }
    Toggle {
      Layout.fillWidth: true
      text: "Notification sounds"
      showHint: false
      iconName: checked ? "volume-2" : "volume-x"
      description: "Controls sound for all apps without changing popups or history. Per-app sound preferences are preserved while muted."
      checked: !window.service.notificationSoundsMuted
      onClicked: window.service.setNotificationSoundsMuted(!window.service.notificationSoundsMuted)
    }
    }
    SettingsSubsection {
      Layout.fillWidth: true
      iconName: "clock"
      title: "Quiet hours"
        + (window.service.dndScheduleEnabled ? " · Scheduled" : " · Off")
      description: "Schedule Do Not Disturb and choose whether critical alerts can interrupt it."
      collapsible: true
      expanded: notificationOptions.quietHoursExpanded
      onToggled: notificationOptions.toggleDetails("quietHoursExpanded")
    Toggle {
      Layout.fillWidth: true
      text: "Scheduled DND"
      iconName: "clock"
      description: "Quiet hours use local time. Manual DND changes last until the next scheduled boundary. Disabling the schedule leaves the current DND state unchanged."
      checked: window.service.dndScheduleEnabled
      onClicked: window.service.setDndSchedule(!window.service.dndScheduleEnabled, window.service.dndStartMinutes,
        window.service.dndEndMinutes, window.service.dndScheduleDays)
    }
    SettingsGrid {
      visible: window.service.dndScheduleEnabled
      Layout.fillWidth: true
      columnSpacing: 12
      rowSpacing: 12
      Label { text: "Quiet hours" }
      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 8
        ScheduleTime {
          minutesValue: window.service.dndStartMinutes
          Accessible.name: "Quiet hours start (24-hour local time)"
          onEdited: minutes => window.service.setDndSchedule(true, minutes,
            window.service.dndEndMinutes, window.service.dndScheduleDays)
        }
        Label { text: "–" }
        ScheduleTime {
          minutesValue: window.service.dndEndMinutes
          Accessible.name: "Quiet hours end (24-hour local time)"
          onEdited: minutes => window.service.setDndSchedule(true, window.service.dndStartMinutes,
            minutes, window.service.dndScheduleDays)
        }
      }
      Label { text: "Repeat" }
      Choice {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        model: [
          { label: "Every day", value: 127 },
          { label: "Weekdays", value: 31 },
          { label: "Weekends", value: 96 }
        ]
        selectedValue: window.service.dndScheduleDays
        Accessible.name: "Quiet hours repeat on these start days"
        onChosen: value => window.service.setDndSchedule(true, window.service.dndStartMinutes,
          window.service.dndEndMinutes, value)
      }
    }
    Label {
      Layout.fillWidth: true
      visible: text !== ""
      text: window.service.dndScheduleError || window.service.dndScheduleStatus
      color: window.service.dndScheduleError ? window.controller.controlWarningText : window.controller.controlSecondaryText
    }
    Toggle {
      Layout.fillWidth: true
      text: "Allow critical alerts during DND"
      iconName: "bell"
      description: "Allows critical popups and sounds through manual or scheduled DND. App blocking, sound mute, sender silence and popup privacy still apply. Earlier suppressed alerts do not replay."
      checked: window.service.allowCriticalDuringDnd
      onClicked: window.service.setAllowCriticalDuringDnd(!window.service.allowCriticalDuringDnd)
    }
    }
    SettingsSubsection {
      Layout.fillWidth: true
      iconName: "volume-2"
      title: "Notification sound"
      description: "Choose, preview or reset the notification sound. Current sound: " + window.service.notificationSoundName
      collapsible: true
      expanded: notificationOptions.soundExpanded
      onToggled: {
        notificationOptions.toggleDetails("soundExpanded")
        if (!notificationOptions.soundExpanded) window.service.stopSoundPreview()
      }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: window.service.notificationSoundName
        activeFocusOnTab: true
        maximumLineCount: 1
        elide: Text.ElideMiddle
        Accessible.name: "Notification sound: " + text
        HoverHandler { id: soundNameHover }
        Hint {
          text: window.service.notificationSoundPath
          visible: soundNameHover.hovered || soundNameHover.parent.activeFocus
        }
      }
      SoundButton {
        iconName: "search"
        text: "Choose file…"
        description: "Choose a notification sound from this computer"
        showHint: false
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
      color: window.controller.controlWarningText
    }
    }
    SettingsSubsection {
      Layout.fillWidth: true
      iconName: "settings"
      title: "Popup placement & behavior"
      description: "Choose where popups appear, how long they stay and whether notifications animate."
      collapsible: true
      expanded: notificationOptions.presentationExpanded
      onToggled: notificationOptions.toggleDetails("presentationExpanded")
    SettingsGrid {
      Layout.fillWidth: true
      columnSpacing: 12
      rowSpacing: 12
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
      Label {
        text: "Popup duration"
        activeFocusOnTab: true
        HoverHandler { id: durationHover }
        Hint {
          text: "Default lifetime for new notifications. Explicit app timeouts and critical alerts keep their own lifetime. Hover pauses expiry; history remains after expiry."
          visible: durationHover.hovered || durationHover.parent.activeFocus
        }
      }
      Choice {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        model: [
          { label: "5 seconds", value: 5 },
          { label: "10 seconds", value: 10 },
          { label: "20 seconds (default)", value: 20 },
          { label: "30 seconds", value: 30 },
          { label: "1 minute", value: 60 },
          { label: "Until dismissed", value: 0 }
        ]
        selectedValue: window.service.popupDurationSeconds
        Accessible.name: "Default popup duration"
        Accessible.description: "Applies to new notifications using the default timeout."
        onChosen: value => window.service.setPopupDurationSeconds(value)
      }
    }
    Toggle {
      Layout.fillWidth: true
      text: "Reduce notification motion"
      iconName: "bell"
      checked: window.service.reduceMotion
      description: "Show notification changes immediately, without slides, staggered expansion or attention pulses. Applies to popups and notification history."
      onClicked: window.service.setReduceMotion(!window.service.reduceMotion)
    }
    }
    SettingsSubsection {
      Layout.fillWidth: true
      iconName: "lock"
      title: "Privacy & history"
      description: "Control message previews, lock-screen visibility and how long notification history is kept."
      collapsible: true
      expanded: notificationOptions.privacyExpanded
      onToggled: notificationOptions.toggleDetails("privacyExpanded")
    Toggle {
      Layout.fillWidth: true
      text: "Popup message previews"
      iconName: "lock"
      checked: window.service.popupPreviews
      description: "When off, popups show the app name and New notification, hiding message text, images and action labels. Full content remains in history."
      onClicked: window.service.setPopupPreviews(!window.service.popupPreviews)
    }
    SettingsGrid {
      Layout.fillWidth: true
      columnSpacing: 12
      rowSpacing: 12
      Label {
        text: "Lock screen"
        activeFocusOnTab: true
        HoverHandler { id: lockPrivacyHover }
        Hint {
          text: "Controls the lock-screen notification panel. Message bodies are always hidden; choose whether titles or app names are shown."
          visible: lockPrivacyHover.hovered || lockPrivacyHover.parent.activeFocus
        }
      }
      Choice {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        model: [
          { label: "Show titles", value: "show" },
          { label: "App names only", value: "redact" },
          { label: "Hide notifications", value: "hide" }
        ]
        selectedValue: window.service.lockScreenPrivacy
        Accessible.name: "Lock-screen notification privacy"
        onChosen: value => window.service.setLockScreenPrivacy(value)
      }
      Label {
        text: "Keep history"
        activeFocusOnTab: true
        HoverHandler { id: retentionHover }
        Hint {
          text: "Removes older inactive notifications, up to the existing 100-entry limit. Live notifications are kept; cleanup pauses while history is open. App preferences are kept."
          visible: retentionHover.hovered || retentionHover.parent.activeFocus
        }
      }
      Choice {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        model: [
          { label: "No age limit", value: 0 },
          { label: "1 day", value: 1 },
          { label: "7 days", value: 7 },
          { label: "30 days", value: 30 }
        ]
        selectedValue: window.service.historyRetentionDays
        Accessible.name: "Keep notification history"
        Accessible.description: "Removes older inactive history. Up to 100 entries are kept, regardless of age limit."
        onChosen: value => window.service.setHistoryRetentionDays(value)
      }
    }
    }
  }

  component NotificationsPage: ColumnLayout {
    spacing: 12
    Label {
      text: "Notifications"
      font.pixelSize: 16
      font.bold: true
      Accessible.description: "Apps appear here after sending a notification and stay listed after their history is cleared."
    }
    ListView {
      id: applicationList
      function restoreHeaderOffset(offset) {
        restoreHeader.offset = offset
        restoreHeader.restart()
      }
      Timer {
        id: restoreHeader
        property real offset: 0
        interval: 16
        onTriggered: {
          if (applicationList.moving) return
          applicationList.forceLayout()
          applicationList.contentY = applicationList.originY + offset
          applicationList.returnToBounds()
        }
      }
      Component.onCompleted: restoreHeaderOffset(0)
      Connections {
        target: window
        function onVisibleChanged() { if (window.visible) applicationList.restoreHeaderOffset(0) }
      }
      onVisibleChanged: {
        if (visible) restoreHeaderOffset(0)
      }
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: 0
      boundsBehavior: Flickable.StopAtBounds
      // Append-only discovery and a count model preserve delegates, focus and scroll position.
      model: window.service.applications.length
      Controls.ScrollBar.vertical: Controls.ScrollBar {}

      // One subsection surface spans the header, virtualized app rows and footer.
      Rectangle {
        parent: applicationList.contentItem
        z: -1
        y: applicationList.headerItem ? applicationList.headerItem.y + applicationList.headerItem.applicationsY : 0
        width: applicationList.width
        height: applicationList.headerItem ? Math.max(0, applicationList.contentHeight - applicationList.headerItem.applicationsY) : 0
        radius: 18
        color: window.controller.controlSurface
        border.color: window.controller.controlSurfaceBorder
      }

      header: ColumnLayout {
        readonly property real applicationsY: applicationsHeading.y
        width: applicationList.width
        spacing: 16
        GeneralOptions {
          Layout.fillWidth: true
          scrollView: applicationList
        }
        SettingsSubsection {
          id: applicationsHeading
          Layout.fillWidth: true
          framed: false
          title: "Applications"
          iconName: "box"
          Label {
            Layout.fillWidth: true
            text: "Control notifications and sound for each app."
            color: window.controller.controlSecondaryText
          }
        }
      }

      delegate: Item {
        id: applicationRow
        required property int index
        readonly property var application: window.service.applications[index]
        readonly property var appIcon: window.applicationIcon(application)
        width: applicationList.width
        height: rowContent.implicitHeight + 28
        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          height: 1
          color: window.controller.controlSurfaceBorder
        }

        RowLayout {
          id: rowContent
          anchors.fill: parent
          anchors.margins: 14
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

      footer: Label {
        width: applicationList.width
        height: applicationList.count === 0 ? implicitHeight + 28 : 14
        topPadding: 12
        leftPadding: 14
        rightPadding: 14
        horizontalAlignment: Text.AlignHCenter
        color: window.controller.controlSecondaryText
        text: applicationList.count === 0 ? "Apps appear here after sending their first notification." : ""
      }
    }
  }
}

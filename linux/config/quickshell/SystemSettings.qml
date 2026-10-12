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
  property string section: "system"
  property string connectivityTab: "networks"
  property bool connectivityAdvanced: false
  readonly property bool wifiDiscoveryActive: visible && section === "connectivity" && connectivityTab === "networks"
  onSectionChanged: {
    connectivityTab = "networks"
    connectivityAdvanced = false
  }
  readonly property var sections: [
    { key: "system", label: "System information", icon: "cpu" },
    { key: "notifications", label: "Notifications", icon: "bell" },
    { key: "display", label: "Display", icon: "sun" },
    { key: "monitors", label: "Monitors", icon: "monitor" },
    { key: "wallpaper", label: "Wallpaper", icon: "monitor" },
    { key: "power", label: "Power & battery", icon: "battery" },
    { key: "connectivity", label: "Connectivity", icon: "wifi" },
    { key: "idle", label: "Lock & idle", icon: "lock" },
    { key: "lockScreen", label: "Session & lock screen", icon: "lock" },
    { key: "input", label: "Input", icon: "keyboard" },
    { key: "audio", label: "Audio", icon: "volume-2" },
    { key: "weather", label: "Date & weather", icon: "calendar" },
    { key: "desktop", label: "Desktop & bar", icon: "settings" }
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
    property bool showHint: true
    property string iconName: ""
    Accessible.description: description
    hoverEnabled: true
    Hint {
      text: toggle.description
      visible: toggle.showHint && text.length > 0 && toggle.hovered
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
    property bool showHint: text === "" || description !== text
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
        visible: button.iconName !== ""
        source: button.iconName ? window.controller.icon(button.iconName) : ""
        color: window.controller.controlPrimaryText
      }
      Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: button.text !== ""
        text: button.text
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
      }
    }
    background: Rectangle {
      radius: 8
      color: button.hovered ? window.controller.controlHover : window.controller.controlSurface
      border.color: button.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
    }
    Hint {
      text: button.description
      visible: button.showHint && button.hovered
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
    delegate: Controls.ItemDelegate {
      id: option
      required property int index
      width: choice.width - 8
      implicitHeight: 36
      padding: 8
      highlighted: choice.highlightedIndex === index
      Accessible.name: choice.textAt(index)
      contentItem: RowLayout {
        spacing: 8
        Label {
          Layout.fillWidth: true
          text: choice.textAt(option.index)
          elide: Text.ElideRight
          maximumLineCount: 1
          color: window.controller.controlPrimaryText
        }
        LucideIcon {
          Layout.preferredWidth: 16
          Layout.preferredHeight: 16
          source: window.controller.icon("circle-check")
          visible: choice.currentIndex === option.index
          color: window.controller.controlPrimaryText
        }
      }
      background: Rectangle {
        radius: 6
        color: choice.currentIndex === option.index ? window.controller.controlActive
          : option.highlighted || option.hovered ? window.controller.controlHover : window.controller.controlSurface
      }
    }
    popup: Controls.Popup {
      y: choice.height + 4
      width: choice.width
      padding: 4
      implicitHeight: Math.min(contentItem.implicitHeight + 8, 240, window.height - 80)
      contentItem: ListView {
        clip: true
        implicitHeight: contentHeight
        model: choice.popup.visible ? choice.delegateModel : null
        currentIndex: choice.highlightedIndex
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
      }
      background: Rectangle {
        radius: 8
        color: window.controller.controlSurface
        border.color: window.controller.controlBorder
      }
    }
    background: Rectangle {
      radius: 8
      color: choice.hovered ? window.controller.controlHover : window.controller.controlSurface
      border.color: choice.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
    }
  }

  component ScheduleTime: Controls.TextField {
    id: timeInput
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
    validator: RegularExpressionValidator { regularExpression: /([01][0-9]|2[0-3]):[0-5][0-9]/ }
    onEditingFinished: {
      if (acceptableInput) {
        const parts = text.split(":")
        edited(Number(parts[0]) * 60 + Number(parts[1]))
      }
      text = Qt.binding(() => window.service.formatScheduleTime(timeInput.minutesValue))
    }
    onActiveFocusChanged: {
      if (!activeFocus && !acceptableInput)
        text = Qt.binding(() => window.service.formatScheduleTime(timeInput.minutesValue))
    }
    background: Rectangle {
      radius: 8
      color: window.controller.controlSurface
      border.color: timeInput.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
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
    MonitorService {
      id: monitors
      visible: window.visible && window.section === "monitors"
    }
    MonitorIdentify {
      id: monitorIdentify
      controller: window.controller
      outputs: monitors.draft
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
      visible: monitors.pending
      Layout.fillWidth: true
      Label {
        Layout.fillWidth: true
        text: "Keep this display layout? Reverting in " + monitors.secondsLeft + " seconds."
      }
      SoundButton {
        text: "Revert"
        enabled: !monitors.busy
        onClicked: monitors.run("revert", monitors.snapshot.pending.token)
      }
      SoundButton {
        text: "Keep changes"
        enabled: !monitors.busy
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
            model: window.sections
            delegate: Controls.Button {
              id: sectionButton
              required property var modelData
              width: sidebar.width - 12
              height: Math.max(40, contentItem.implicitHeight + 20)
              padding: 10
              text: modelData.label
              Accessible.role: Accessible.PageTab
              Accessible.name: text
              Accessible.selected: window.section === modelData.key
              onClicked: window.section = modelData.key
              Controls.ToolTip.visible: sidebar.compact && hovered
              Controls.ToolTip.text: text
              Controls.ToolTip.delay: 500
              background: Rectangle {
                radius: 8
                color: window.section === sectionButton.modelData.key ? window.controller.controlActive
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
                  color: window.section === sectionButton.modelData.key ? window.controller.controlActiveIcon : window.controller.controlSecondaryText
                }
                Label {
                  visible: !sidebar.compact
                  Layout.fillWidth: true
                  text: sectionButton.text
                  font.bold: window.section === sectionButton.modelData.key
                }
              }
            }
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
      MonitorsPage {
        visible: window.section === "monitors"
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
      SystemInformation {
        controller: window.controller
        active: window.visible && window.section === "system"
        visible: window.section === "system"
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
    }
    Label {
      Layout.fillWidth: true
      text: window.controller.preferences.error
      visible: text.length > 0
      color: window.controller.controlWarningText
    }
  }

  component MonitorsPage: ColumnLayout {
    id: monitorPage
    property bool editing: false
    spacing: 10
    RowLayout {
      Layout.fillWidth: true
      Label { Layout.fillWidth: true; text: "Monitors"; font.pixelSize: 16; font.bold: true }
      SoundButton { text: "Identify"; iconName: "monitor"; onClicked: monitorIdentify.identify() }
    }
    Controls.ScrollView {
      id: monitorScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: availableWidth
      clip: true
      Binding {
        target: monitorScroll.contentItem
        property: "boundsBehavior"
        value: Flickable.StopAtBounds
      }
      ColumnLayout {
        width: monitorScroll.availableWidth
        spacing: 12
        enabled: !monitors.busy && !monitors.pending
        Label { text: "Saved profiles"; font.bold: true }
        Label {
          Layout.fillWidth: true
          text: monitors.snapshot.profiles.length ? "Choose a detected setup. Keep the new layout within 20 seconds to confirm."
            : "No saved profiles yet. Customize your layout below to save one."
          color: window.controller.controlSecondaryText
        }
        GridLayout {
          Layout.fillWidth: true
          columns: monitorScroll.availableWidth >= 480 ? 2 : 1
          columnSpacing: 10
          rowSpacing: 10
        Repeater {
          model: monitors.snapshot.profiles.slice().sort((a, b) => Number(b.available) - Number(a.available)
            || Number(b.current) - Number(a.current) || a.name.localeCompare(b.name))
          delegate: Controls.Button {
            id: profileCard
            required property var modelData
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            implicitHeight: profileCardContent.implicitHeight + 24
            enabled: modelData.available && modelData.session === monitors.snapshot.session && !monitors.dirty
            Accessible.name: modelData.name
            Accessible.description: modelData.current ? "Active profile" : modelData.available ? "Apply detected profile" : modelData.reason
            onClicked: {
              monitors.activateProfile(modelData.name)
              profileName.text = modelData.name
            }
            background: Rectangle {
              radius: 12
              color: profileCard.modelData.current ? window.controller.controlActive
                : profileCard.hovered ? window.controller.controlHover : window.controller.controlSurface
              border.width: profileCard.activeFocus ? 2 : 1
              border.color: profileCard.modelData.current || profileCard.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
            }
            contentItem: RowLayout {
              id: profileCardContent
              spacing: 12
              opacity: profileCard.enabled || profileCard.modelData.current ? 1 : 0.7
              LucideIcon {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                source: window.controller.icon(profileCard.modelData.current ? "circle-check" : "monitor")
                color: window.controller.controlSecondaryText
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { Layout.fillWidth: true; text: profileCard.modelData.name; font.bold: true }
                Label {
                  Layout.fillWidth: true
                  text: (profileCard.modelData.current ? "Active" : profileCard.modelData.available ? "Detected" : "Unavailable")
                    + (profileCard.modelData.preferred ? " · Preferred" : "")
                    + " · " + profileCard.modelData.outputs.filter(output => output.enabled).length
                    + (profileCard.modelData.outputs.filter(output => output.enabled).length === 1 ? " display" : " displays")
                  color: window.controller.controlSecondaryText
                }
                Label {
                  Layout.fillWidth: true
                  visible: !profileCard.modelData.available
                  text: profileCard.modelData.reason || "Required displays are not connected."
                  color: window.controller.controlSecondaryText
                }
              }
            }
          }
        }
        }
        Label {
          Layout.fillWidth: true
          visible: monitors.dirty
          text: "Finish or reload your draft layout below before switching profiles."
          color: window.controller.controlWarningText
        }
        Toggle {
          Layout.fillWidth: true
          text: "Automatically switch setups"
          checked: monitors.snapshot.automatic
          description: "Use matching saved profiles when displays connect or disconnect. A kept manual layout remains until the connected hardware changes."
          onClicked: monitors.run("automatic", JSON.stringify(!monitors.snapshot.automatic))
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: window.controller.controlSurfaceBorder }
        SoundButton {
          Layout.fillWidth: true
          text: monitorPage.editing ? "⌄  Customize layout & manage profiles" : "›  Customize layout & manage profiles"
          iconName: "settings"
          onClicked: monitorPage.editing = !monitorPage.editing
        }
        ColumnLayout {
          Layout.fillWidth: true
          visible: monitorPage.editing
          spacing: 12
          Choice {
            Layout.fillWidth: true
            Accessible.name: "Profile to edit"
            model: [{ label: "Current layout", value: "" }].concat(monitors.snapshot.profiles
              .filter(p => p.session === monitors.snapshot.session)
              .map(p => ({ label: p.name + (p.available ? "" : " (disconnected · edit only)"), value: p.name })))
            selectedValue: monitors.selectedProfile
            onChosen: value => {
              if (value) monitors.chooseProfile(value)
              else monitors.resetDraft()
              profileName.text = value
            }
          }
        Rectangle {
          id: diagram
          Layout.fillWidth: true
          Layout.preferredHeight: 200
          radius: 12
          color: window.controller.controlSurface
          border.color: window.controller.controlSurfaceBorder
          clip: true
          readonly property real extentWidth: Math.max(1, ...monitors.draft.filter(o => o.enabled).map(o => o.x + monitors.size(o).width))
          readonly property real extentHeight: Math.max(1, ...monitors.draft.filter(o => o.enabled).map(o => o.y + monitors.size(o).height))
          readonly property real factor: Math.min((width - 32) / extentWidth, (height - 32) / extentHeight)
          Repeater {
            model: monitors.draft
            delegate: Rectangle {
              id: displayCard
              required property var modelData
              required property int index
              visible: modelData.enabled
              x: 16 + modelData.x * diagram.factor
              y: 16 + modelData.y * diagram.factor
              width: Math.max(36, monitors.size(modelData).width * diagram.factor)
              height: Math.max(28, monitors.size(modelData).height * diagram.factor)
              radius: 6
              color: monitors.selectedOutput === index ? window.controller.controlActive : window.controller.controlBackground
              border.width: monitors.selectedOutput === index ? 2 : 1
              border.color: window.controller.controlActiveIcon
              Label {
                anchors.centerIn: parent
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                text: (displayCard.index + 1) + " · " + displayCard.modelData.connector
                font.pixelSize: 11
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                property real startScale: 1
                drag.target: displayCard
                drag.minimumX: 16
                drag.minimumY: 16
                onPressed: {
                  monitors.selectedOutput = displayCard.index
                  startScale = diagram.factor
                }
                onReleased: {
                  if (drag.active)
                    monitors.move(displayCard.index, (displayCard.x - 16) / startScale, (displayCard.y - 16) / startScale)
                  displayCard.x = Qt.binding(() => 16 + displayCard.modelData.x * diagram.factor)
                  displayCard.y = Qt.binding(() => 16 + displayCard.modelData.y * diagram.factor)
                }
              }
            }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { Layout.fillWidth: true; text: "Drag displays to arrange; edges snap."; color: window.controller.controlSecondaryText }
        }
        Choice {
          Layout.fillWidth: true
          Accessible.name: "Selected display"
          model: monitors.draft.map((o, index) => ({ label: (index + 1) + " · " + o.connector + (o.enabled ? "" : " (off)"), value: index }))
          selectedValue: monitors.selectedOutput
          onChosen: value => monitors.selectedOutput = value
        }
        Label {
          Layout.fillWidth: true
          visible: monitors.output !== null
          text: monitors.connectedOutput ? monitors.connectedOutput.description : "Display disconnected"
          color: window.controller.controlSecondaryText
        }
        Toggle {
          Layout.fillWidth: true
          text: "Enable display"
          checked: monitors.output?.enabled ?? false
          enabled: monitors.output !== null
          onClicked: monitors.edit("enabled", !monitors.output.enabled)
        }
        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: 12
          rowSpacing: 10
          enabled: monitors.output?.enabled ?? false
          Label { text: "Resolution" }
          Choice {
            Layout.fillWidth: true
            Accessible.name: "Resolution"
            model: [...new Set([monitors.output?.mode, ...(monitors.connectedOutput?.modes || []).map(m => m.mode)].filter(Boolean))].map(mode => ({ label: mode, value: mode }))
            selectedValue: monitors.output?.mode ?? ""
            onChosen: value => {
              monitors.edit("mode", value)
              const available = monitors.connectedOutput.modes.filter(m => m.mode === value)
              if (available.length && !available.some(m => m.rate === monitors.output.rate)) monitors.edit("rate", available[0].rate)
            }
          }
          Label { text: "Refresh rate" }
          Choice {
            Layout.fillWidth: true
            Accessible.name: "Refresh rate"
            model: {
              const choices = (monitors.connectedOutput?.modes || []).filter(m => m.mode === monitors.output?.mode)
                .map(m => ({ label: m.rate + " Hz", value: m.rate }))
              if (monitors.output && !choices.some(c => c.value === monitors.output.rate))
                choices.unshift({ label: monitors.output.rate + " Hz (saved)", value: monitors.output.rate })
              return choices
            }
            selectedValue: monitors.output?.rate ?? 60
            onChosen: value => monitors.edit("rate", value)
          }
          Label {
            text: "Scale"
            HoverHandler { id: scaleHover }
            Hint {
              visible: scaleHover.hovered
              text: monitors.snapshot.session === "x11" ? "X11 scales the output using resampling; application DPI remains session-wide. Hyprland uses native per-display scaling." : "Native per-display scale. Some modes only support particular scale factors."
            }
          }
          Choice {
            Layout.fillWidth: true
            Accessible.name: "Display scale"
            model: [...new Set([1, 1.25, 1.5, 1.75, 2, monitors.output?.scale || 1])].sort((a, b) => a - b)
              .map(scale => ({ label: Math.round(scale * 10000) / 100 + "%", value: scale }))
            selectedValue: monitors.output?.scale ?? 1
            onChosen: value => monitors.edit("scale", value)
          }
          Label { text: "Orientation" }
          Choice {
            Layout.fillWidth: true
            Accessible.name: "Display orientation"
            model: [ { label: "Landscape", value: "normal" }, { label: "Portrait left", value: "left" },
              { label: "Upside down", value: "inverted" }, { label: "Portrait right", value: "right" } ]
            selectedValue: monitors.output?.rotation ?? "normal"
            onChosen: value => monitors.edit("rotation", value)
          }
          Repeater {
            model: ["x", "y"]
            delegate: RowLayout {
              id: positionRow
              required property string modelData
              Layout.columnSpan: 2
              Layout.fillWidth: true
              Label { text: positionRow.modelData.toUpperCase() + " position"; Layout.fillWidth: true }
              Controls.TextField {
                Layout.preferredWidth: 120
                text: String(monitors.output?.[positionRow.modelData] ?? 0)
                color: window.controller.controlPrimaryText
                validator: IntValidator { bottom: 0; top: 65535 }
                Accessible.name: positionRow.modelData.toUpperCase() + " position"
                onEditingFinished: {
                  if (acceptableInput) monitors.edit(positionRow.modelData, Number(text))
                  text = Qt.binding(() => String(monitors.output?.[positionRow.modelData] ?? 0))
                }
                background: Rectangle { color: window.controller.controlSurface; radius: 8; border.color: window.controller.controlSurfaceBorder }
              }
            }
          }
        }
        Toggle {
          Layout.fillWidth: true
          visible: monitors.snapshot.session === "x11"
          text: "Primary display"
          checked: monitors.output?.primary ?? false
          enabled: monitors.output?.enabled ?? false
          onClicked: monitors.edit("primary", !monitors.output.primary)
        }
        SoundButton {
          text: monitors.linkDetails ? "Hide link details" : "Link details"
          enabled: monitors.connectedOutput !== null && monitors.connectedOutput !== undefined
          onClicked: {
            if (monitors.linkDetails) monitors.linkDetails = null
            else monitors.run("details", monitors.connectedOutput.connector)
          }
        }
        Label {
          Layout.fillWidth: true
          visible: monitors.linkDetails !== null
          text: {
            const d = monitors.linkDetails
            if (!d) return ""
            return (d.monitorName ? d.monitorName + "\n" : "")
              + "Connection: " + (d.subconnector || d.connector) + (d.linkStatus ? " · " + d.linkStatus : "")
              + "\nAdvertised HDMI TMDS limit: " + (d.maxTmdsMHz ? d.maxTmdsMHz + " MHz (" + (d.maxTmdsMHz * 30 / 1000).toFixed(2) + " Gbit/s raw)" : "Not reported")
              + "\nCurrent pixel clock: " + (d.pixelClockMHz ? d.pixelClockMHz + " MHz" : "Not exposed")
              + "\n8-bit RGB estimate, including blanking: " + (d.estimated8BitRgbGbps ? d.estimated8BitRgbGbps.toFixed(2) + " Gbit/s before encoding" : "Unavailable")
              + "\nNegotiated link capacity: Not exposed"
              + "\nActive color depth / DSC: Not exposed"
          }
          HoverHandler { id: linkHintHover }
          Hint {
            visible: linkHintHover.hovered
            text: "These describe the current applied layout, not the draft. The estimate assumes uncompressed 8-bit RGB. EDID limits describe the monitor's HDMI capability, not the negotiated GPU/cable/dock link. max bpc is a limit, not active color depth."
          }
        }
        RowLayout {
          Layout.fillWidth: true
          SoundButton { text: "Reload current"; iconName: "refresh-cw"; onClicked: { monitors.resetAfterRead = true; monitors.refresh() } }
          Item { Layout.fillWidth: true }
          SoundButton { text: "Apply"; enabled: monitors.dirty; onClicked: monitors.run("apply", JSON.stringify(monitors.draft)) }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: window.controller.controlSurfaceBorder }
        Label { text: "Save & manage profiles"; font.bold: true }
        Controls.TextField {
          id: profileName
          Layout.fillWidth: true
          placeholderText: "Profile name"
          color: window.controller.controlPrimaryText
          placeholderTextColor: window.controller.controlSecondaryText
          Accessible.name: "Profile name"
          padding: 10
          background: Rectangle { color: window.controller.controlSurface; radius: 8; border.color: window.controller.controlSurfaceBorder }
        }
        Toggle {
          id: preferredProfile
          Layout.fillWidth: true
          text: "Preferred for this hardware"
          checked: true
          description: "When multiple profiles match these displays, use this one for automatic switching."
        }
        Flow {
          Layout.fillWidth: true
          spacing: 8
          SoundButton {
            text: "Save as"
            enabled: !monitors.dirty && profileName.text.trim() !== ""
            description: "Save the current confirmed layout. Apply and keep any draft changes first."
            onClicked: monitors.save(profileName.text, "", preferredProfile.checked)
          }
          SoundButton {
            text: "Update"
            enabled: !monitors.dirty && monitors.selectedProfile !== ""
            onClicked: monitors.save(monitors.selectedProfile, monitors.selectedProfile, preferredProfile.checked)
          }
          SoundButton {
            text: "Rename"
            enabled: monitors.selectedProfile !== "" && profileName.text.trim() !== ""
            onClicked: monitors.run("rename", monitors.selectedProfile, profileName.text.trim())
          }
          SoundButton {
            text: "Delete"
            enabled: monitors.selectedProfile !== ""
            onClicked: monitors.run("delete", monitors.selectedProfile)
          }
          SoundButton {
            text: "Import autorandr"
            visible: monitors.snapshot.session === "x11"
            description: "Import existing user profiles without overwriting profiles already in the portable store."
            onClicked: monitors.run("import")
          }
        }
        }
        Label {
          Layout.fillWidth: true
          text: monitors.error || monitors.snapshot.automationError || (monitors.dirty ? "Draft changes · apply and keep before saving." : "Saved in system-settings/monitor-profiles.json")
          color: monitors.error || monitors.snapshot.automationError ? window.controller.controlWarningText : window.controller.controlSecondaryText
        }
      }
    }
  }

  component PreferencesPage: ColumnLayout {
    spacing: 12
    Label {
      text: window.sections.find(entry => entry.key === window.section)?.label || ""
      font.pixelSize: 16
      font.bold: true
    }
    RowLayout {
      Layout.fillWidth: true
      visible: window.section === "connectivity"
      spacing: 4
      Repeater {
        model: [{ key: "networks", label: "Wi-Fi networks", icon: "wifi" }, { key: "preferences", label: "Preferences", icon: "settings" }]
        delegate: Controls.Button {
          id: connectivityTabButton
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 40
          Accessible.role: Accessible.PageTab
          Accessible.name: modelData.label
          Accessible.selected: window.connectivityTab === modelData.key
          onClicked: window.connectivityTab = modelData.key
          contentItem: RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }
            LucideIcon {
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              source: window.controller.icon(connectivityTabButton.modelData.icon)
              color: window.controller.controlPrimaryText
            }
            Label {
              text: connectivityTabButton.modelData.label
              Layout.maximumWidth: Math.max(0, connectivityTabButton.availableWidth - 24)
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            Item { Layout.fillWidth: true }
          }
          background: Rectangle {
            radius: 10
            color: window.connectivityTab === connectivityTabButton.modelData.key ? window.controller.controlActive
              : connectivityTabButton.hovered ? window.controller.controlHover : window.controller.controlSurface
            border.width: connectivityTabButton.activeFocus ? 2 : 1
            border.color: window.connectivityTab === connectivityTabButton.modelData.key || connectivityTabButton.activeFocus
              ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
          }
        }
      }
    }
    Controls.ScrollView {
      id: preferenceScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: availableWidth
      clip: true
      Binding {
        target: preferenceScroll.contentItem
        property: "boundsBehavior"
        value: Flickable.StopAtBounds
      }
      Connections {
        target: window
        function onSectionChanged() {
          if (window.section === "connectivity" || window.section === "audio")
            preferenceScroll.contentItem.contentY = 0
        }
        function onVisibleChanged() {
          if (window.visible && (window.section === "connectivity" || window.section === "audio"))
            preferenceScroll.contentItem.contentY = 0
        }
        function onConnectivityTabChanged() { preferenceScroll.contentItem.contentY = 0 }
      }
      ColumnLayout {
        width: preferenceScroll.availableWidth
        spacing: 16
        Label {
          Layout.fillWidth: true
          visible: window.section === "lockScreen"
          text: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
            ? "Hyprlock presentation · changes apply the next time you lock. Idle locking is configured in Lock & idle; notification privacy is in Notifications."
            : "These presentation controls apply to Hyprlock on Wayland. Your X11 locker remains unchanged. Idle locking is configured in Lock & idle."
          color: window.controller.controlSecondaryText
        }
        Label {
          Layout.fillWidth: true
          visible: window.section === "power"
          text: "Configure battery warnings. Power-profile selection stays in Control Center."
          color: window.controller.controlSecondaryText
        }
        Repeater {
          model: window.section === "power" ? [
            { key: "low", title: "Low battery", icon: "battery-low" },
            { key: "critical", title: "Critical battery", icon: "battery-warning" },
            { key: "urgent", title: "Urgent battery", icon: "battery-warning" },
            { key: "final", title: "Final warning", icon: "battery" }
          ] : []
          delegate: SettingsSubsection {
            id: batteryWarning
            required property var modelData
            readonly property string enabledKey: "power." + modelData.key + "WarningEnabled"
            readonly property string thresholdKey: "power." + modelData.key + "Threshold"
            readonly property var threshold: window.controller.preferences.value(thresholdKey, "")
            Layout.fillWidth: true
            title: modelData.title
            iconName: modelData.icon
            enabled: window.controller.preferences.ready && !window.controller.preferences.busy
            Toggle {
              Layout.fillWidth: true
              text: "Enable warning"
              Accessible.name: batteryWarning.modelData.title + " warning enabled"
              checked: window.controller.preferences.value(batteryWarning.enabledKey, true)
              description: "Warns once per level in a discharge episode. Critical, urgent and final levels use critical urgency; notification policies still apply."
              onClicked: window.controller.preferences.setValue(batteryWarning.enabledKey,
                !window.controller.preferences.value(batteryWarning.enabledKey, true))
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: window.controller.controlSurfaceBorder }
            RowLayout {
              Layout.fillWidth: true
              spacing: 12
              Label { Layout.fillWidth: true; text: "Battery threshold (%)" }
              Controls.TextField {
                id: batteryThreshold
                Layout.preferredWidth: 80
                text: String(batteryWarning.threshold)
                Accessible.name: batteryWarning.modelData.title + " threshold (%)"
                horizontalAlignment: Text.AlignHCenter
                color: window.controller.controlPrimaryText
                selectionColor: window.controller.controlActive
                selectedTextColor: window.controller.controlPrimaryText
                font.family: window.controller.fontFamily
                font.pixelSize: 12
                padding: 10
                onEditingFinished: {
                  const value = Number(text)
                  if (value !== batteryWarning.threshold)
                    window.controller.preferences.setValue(batteryWarning.thresholdKey, value)
                  text = Qt.binding(() => String(batteryWarning.threshold))
                }
                background: Rectangle {
                  radius: 8
                  color: window.controller.controlSurface
                  border.color: batteryThreshold.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
                }
              }
            }
          }
        }
        SoundMixerControls {
          Layout.fillWidth: true
          visible: window.section === "audio"
          controller: window.controller
          mixer: window.controller.audioService.mixer
          keyboardEnabled: true
        }
        Label {
          Layout.fillWidth: true
          visible: window.section === "audio"
          text: "Keyboard volume steps"
          font.bold: true
          HoverHandler { id: audioStorageHover }
          Hint {
            visible: audioStorageHover.hovered
            text: "Key steps are saved in preferences.json. Mixer levels, routes and modes are live audio-server state. Everyday volume and default device selection are also available in the bar’s Sound panel."
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          visible: window.section === "connectivity" && window.connectivityTab === "preferences"
          spacing: 12
          enabled: window.controller.preferences.ready && !window.controller.preferences.busy
          Label { text: "Suggestions & alerts"; font.bold: true }
          Toggle {
            Layout.fillWidth: true
            text: "Suggest stronger saved Wi-Fi"
            checked: window.controller.preferences.value("connectivity.wifiSuggestions", true)
            description: "Offers a stronger saved network when your signal is weak. Switching always requires your confirmation."
            onClicked: window.controller.preferences.setValue("connectivity.wifiSuggestions", !window.controller.preferences.value("connectivity.wifiSuggestions", true))
          }
          Toggle {
            Layout.fillWidth: true
            text: "Bluetooth low-battery alerts"
            checked: window.controller.preferences.value("connectivity.bluetoothBatteryAlerts", true)
            description: "Warn once per connected device below the threshold. Alerts rearm after disconnecting or recovering."
            onClicked: window.controller.preferences.setValue("connectivity.bluetoothBatteryAlerts", !window.controller.preferences.value("connectivity.bluetoothBatteryAlerts", true))
          }
          Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: window.controller.controlSurfaceBorder }
          SoundButton {
            Layout.fillWidth: true
            text: window.connectivityAdvanced ? "⌄  Advanced tuning" : "›  Advanced tuning"
            onClicked: window.connectivityAdvanced = !window.connectivityAdvanced
          }
          Label {
            Layout.fillWidth: true
            visible: window.connectivityAdvanced
            text: "Thresholds and timing are saved in preferences.json. Suggestions never switch networks automatically."
            color: window.controller.controlSecondaryText
          }
        }
        Repeater {
          model: window.controller.preferences.fields.filter(field => {
            const category = field.key.split(".")[0]
            if (category === "power") return false
            if (category === "connectivity")
              return window.section === "connectivity" && window.connectivityTab === "preferences"
                && window.connectivityAdvanced && field.kind !== "boolean"
            return (category === window.section || window.section === "weather" && category === "clock")
              && (!field.session || field.session === Quickshell.env("XDG_SESSION_TYPE"))
          })
          delegate: ColumnLayout {
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
            Label {
              Layout.fillWidth: true
              visible: preferenceRow.modelData.kind !== "boolean"
              text: preferenceRow.modelData.label
            }
            Choice {
              Layout.fillWidth: true
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
            Controls.TextField {
              id: preferenceInput
              Layout.fillWidth: true
              visible: ["text", "number"].includes(preferenceRow.modelData.kind)
              text: String(preferenceRow.currentValue)
              color: window.controller.controlPrimaryText
              selectionColor: window.controller.controlActive
              selectedTextColor: window.controller.controlPrimaryText
              font.family: window.controller.fontFamily
              font.pixelSize: 12
              padding: 10
              Accessible.name: preferenceRow.modelData.label
              onEditingFinished: {
                const value = preferenceRow.modelData.kind === "number" ? Number(text) : text.trim()
                if (value !== preferenceRow.currentValue)
                  window.controller.preferences.setValue(preferenceRow.modelData.key, value)
                text = Qt.binding(() => String(preferenceRow.currentValue))
              }
              background: Rectangle {
                radius: 8
                color: window.controller.controlSurface
                border.color: preferenceInput.activeFocus ? window.controller.controlActiveIcon : window.controller.controlSurfaceBorder
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
          }
        }
        Flow {
          Layout.fillWidth: true
          visible: window.section === "wallpaper"
          spacing: 8
          enabled: !wallpaperAction.process.running
          SoundButton { text: "Choose image…"; onClicked: wallpaperFileDialog.open() }
          SoundButton { text: "Choose folder…"; onClicked: wallpaperFolderDialog.open() }
          SoundButton { text: "Random now"; onClicked: wallpaperAction.run("random") }
          SoundButton { text: "Restore saved"; onClicked: wallpaperAction.run("restore") }
        }
        WifiSettings {
          Layout.fillWidth: true
          visible: window.section === "connectivity" && window.connectivityTab === "networks"
          controller: window.controller
          service: window.connectivity
        }
        SoundButton {
          visible: window.section === "audio"
          text: "Advanced audio settings…"
          HoverHandler { id: advancedAudioHover }
          Hint { visible: advancedAudioHover.hovered; text: "Open pavucontrol for speaker testing and additional hardware controls." }
          onClicked: advancedAudioSettings.running = true
        }
        Label {
          Layout.fillWidth: true
          visible: window.section === "wallpaper" && text !== ""
          text: wallpaperAction.process.running ? "Applying wallpaper…" : wallpaperAction.error
          color: window.controller.controlWarningText
        }
      }
    }
  }

  component SettingsSubsection: Rectangle {
    id: subsection
    required property string title
    required property string iconName
    property string description: title
    property bool collapsible: false
    property bool expanded: true
    property bool framed: true
    default property alias contents: subsectionBody.data
    signal toggled()
    implicitHeight: subsectionContent.implicitHeight + 28
    radius: 18
    color: framed ? window.controller.controlSurface : "transparent"
    border.width: framed ? 1 : 0
    border.color: window.controller.controlSurfaceBorder
    ColumnLayout {
      id: subsectionContent
      anchors.fill: parent
      anchors.margins: 14
      spacing: 14
      Controls.Button {
        id: subsectionHeader
        Layout.fillWidth: true
        padding: 0
        implicitHeight: Math.max(32, contentItem.implicitHeight)
        enabled: subsection.collapsible
        Accessible.name: subsection.title
        Accessible.description: subsection.description
        Accessible.role: subsection.collapsible ? Accessible.Button : Accessible.Heading
        Accessible.checkable: subsection.collapsible
        Accessible.checked: subsection.expanded
        onClicked: subsection.toggled()
        contentItem: RowLayout {
          spacing: 10
          LucideIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: window.controller.icon(subsection.iconName)
            color: window.controller.controlActiveIcon
          }
          Label {
            Layout.fillWidth: true
            text: subsection.title
            font.pixelSize: 14
            font.bold: true
          }
          LucideIcon {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            visible: subsection.collapsible
            source: window.controller.icon("chevron-right")
            rotation: subsection.expanded ? 90 : 0
            color: window.controller.controlSecondaryText
          }
        }
        background: Rectangle {
          radius: 8
          color: subsectionHeader.hovered ? window.controller.controlHover : "transparent"
          border.width: subsectionHeader.activeFocus ? 1 : 0
          border.color: window.controller.controlActiveIcon
        }
      }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        visible: subsection.expanded
        color: window.controller.controlSurfaceBorder
      }
      ColumnLayout {
        id: subsectionBody
        Layout.fillWidth: true
        visible: subsection.expanded
        spacing: 12
      }
    }
  }

  component GeneralOptions: ColumnLayout {
    id: notificationOptions
    required property var scrollView
    property bool quietHoursExpanded: false
    property bool soundExpanded: false
    property bool presentationExpanded: false
    function toggleDetails(key) {
      const offset = scrollView.contentY - scrollView.originY
      notificationOptions[key] = !notificationOptions[key]
      scrollView.restoreHeaderOffset(offset)
    }
    spacing: 16
    SettingsSubsection {
      Layout.fillWidth: true
      title: "General"
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
    GridLayout {
      visible: window.service.dndScheduleEnabled
      Layout.fillWidth: true
      columns: 2
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
      color: window.controller.controlSecondaryText
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
      title: "Sound selection"
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
      color: window.controller.controlPrimaryText
    }
    }
    SettingsSubsection {
      Layout.fillWidth: true
      iconName: "settings"
      title: "Popups, privacy & history"
      description: "Choose popup position and duration, message previews, lock-screen privacy and history retention."
      collapsible: true
      expanded: notificationOptions.presentationExpanded
      onToggled: notificationOptions.toggleDetails("presentationExpanded")
    GridLayout {
      Layout.fillWidth: true
      columns: 2
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
      Label {
        text: "Lock screen"
        HoverHandler { id: lockPrivacyHover }
        Hint {
          text: "Controls the lock-screen notification panel. Message bodies are always hidden; choose whether titles or app names are shown."
          visible: lockPrivacyHover.hovered
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
        HoverHandler { id: durationHover }
        Hint {
          text: "Default lifetime for new notifications. Explicit app timeouts and critical alerts keep their own lifetime. Hover pauses expiry; history remains after expiry."
          visible: durationHover.hovered
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
      Label {
        text: "Keep history"
        HoverHandler { id: retentionHover }
        Hint {
          text: "Removes older inactive notifications, up to the existing 100-entry limit. Live notifications are kept; cleanup pauses while history is open. App preferences are kept."
          visible: retentionHover.hovered
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
    Toggle {
      Layout.fillWidth: true
      text: "Popup message previews"
      iconName: "lock"
      checked: window.service.popupPreviews
      description: "When off, popups show the app name and New notification, hiding message text, images and action labels. Full content remains in history."
      onClicked: window.service.setPopupPreviews(!window.service.popupPreviews)
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

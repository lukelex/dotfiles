pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls

ColumnLayout {
  id: monitorPage
  required property var settingsWindow
  readonly property alias monitorService: monitors

  MonitorService {
    id: monitors
    visible: monitorPage.settingsWindow.visible && monitorPage.settingsWindow.section === "monitors"
  }
  MonitorIdentify {
    id: monitorIdentify
    controller: monitorPage.settingsWindow.controller
    outputs: monitors.draft
  }

  component Label: Text {
    color: monitorPage.settingsWindow.controller.controlPrimaryText
    font.family: monitorPage.settingsWindow.controller.fontFamily
    font.pixelSize: 12
    font.underline: activeFocus
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  component Hint: SettingsHint {
    controller: monitorPage.settingsWindow.controller
  }

  component Toggle: SettingsToggle {
    controller: monitorPage.settingsWindow.controller
  }

  component SoundButton: SettingsButton {
    controller: monitorPage.settingsWindow.controller
  }

  component Choice: SettingsChoice {
    id: choice
    controller: monitorPage.settingsWindow.controller
    property var selectedValue
    signal chosen(var value)
    textRole: "label"
    valueRole: "value"
    currentIndex: model.findIndex(entry => entry.value === selectedValue)
    onActivated: chosen(currentValue)
  }

  component SettingsSubsection: SettingsSection { controller: monitorPage.settingsWindow.controller }

  property bool editing: false
  spacing: 10
  Connections {
    target: monitorPage.settingsWindow
    function onVisibleChanged() { if (monitorPage.settingsWindow.visible) monitorScroll.resetPosition() }
  }
  Connections {
    target: monitors
    function onLinkDetailsChanged() { monitorScroll.preservePosition() }
  }
  RowLayout {
    Layout.fillWidth: true
    Item { Layout.fillWidth: true }
    SoundButton { text: "Identify"; iconName: "monitor"; onClicked: monitorIdentify.identify() }
  }
  SettingsScrollView {
    id: monitorScroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    ColumnLayout {
      width: monitorScroll.availableWidth
      spacing: 16
      enabled: !monitors.busy && !monitors.pending
      SettingsSubsection {
        Layout.fillWidth: true
        title: "Displays"
        iconName: "monitor"
        Label {
          Layout.fillWidth: true
          visible: monitors.snapshot.outputs.length === 0
          text: "No displays reported."
          color: monitorPage.settingsWindow.controller.controlSecondaryText
        }
        Repeater {
          model: monitors.snapshot.outputs
          delegate: ColumnLayout {
            id: displaySummary
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 1
              visible: displaySummary.index > 0
              color: monitorPage.settingsWindow.controller.controlSurfaceBorder
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              LucideIcon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: monitorPage.settingsWindow.controller.icon(displaySummary.modelData.enabled ? "monitor" : "monitor-off")
                color: monitorPage.settingsWindow.controller.controlSecondaryText
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label {
                  Layout.fillWidth: true
                  text: displaySummary.modelData.description || displaySummary.modelData.connector
                  color: monitorPage.settingsWindow.controller.controlSecondaryText
                }
                Label {
                  Layout.fillWidth: true
                  text: displaySummary.modelData.enabled
                    ? displaySummary.modelData.mode.replace("x", " × ")
                      + " · " + Number(Number(displaySummary.modelData.rate).toFixed(2)) + " Hz"
                      + (displaySummary.modelData.primary ? " · Primary" : "")
                    : "Disabled"
                }
              }
            }
          }
        }
      MonitorSettingsStatus { controller: monitorPage.settingsWindow.controller; service: monitors; actions: [""] }
      }
      SettingsSubsection {
        id: savedProfiles
        Layout.fillWidth: true
        title: "Saved profiles"
        iconName: "monitor"
      Label {
        Layout.fillWidth: true
        text: monitors.snapshot.profiles.length ? "Choose a detected setup. Keep the new layout within 20 seconds to confirm."
          : "No saved profiles yet. Customize your layout below to save one."
        color: monitorPage.settingsWindow.controller.controlSecondaryText
      }
      GridLayout {
        Layout.fillWidth: true
        columns: savedProfiles.width - 28 >= 480 ? 2 : 1
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
            color: profileCard.modelData.current ? monitorPage.settingsWindow.controller.controlActive
              : profileCard.hovered ? monitorPage.settingsWindow.controller.controlHover : monitorPage.settingsWindow.controller.controlSurface
            border.width: profileCard.activeFocus ? 2 : 1
            border.color: profileCard.modelData.current || profileCard.activeFocus ? monitorPage.settingsWindow.controller.controlActiveIcon : monitorPage.settingsWindow.controller.controlSurfaceBorder
          }
          contentItem: RowLayout {
            id: profileCardContent
            spacing: 12
            opacity: profileCard.enabled || profileCard.modelData.current ? 1 : 0.7
            LucideIcon {
              Layout.preferredWidth: 22
              Layout.preferredHeight: 22
              source: monitorPage.settingsWindow.controller.icon(profileCard.modelData.current ? "circle-check" : "monitor")
              color: monitorPage.settingsWindow.controller.controlSecondaryText
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
                color: monitorPage.settingsWindow.controller.controlSecondaryText
              }
              Label {
                Layout.fillWidth: true
                visible: !profileCard.modelData.available
                text: profileCard.modelData.reason || "Required displays are not connected."
                color: monitorPage.settingsWindow.controller.controlSecondaryText
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
        color: monitorPage.settingsWindow.controller.controlWarningText
      }
      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: monitorPage.settingsWindow.controller.controlSurfaceBorder }
      Toggle {
        Layout.fillWidth: true
        text: "Automatically switch setups"
        checked: monitors.snapshot.automatic
        description: "Use matching saved profiles when displays connect or disconnect. A kept manual layout remains until the connected hardware changes."
        onClicked: monitors.run("automatic", JSON.stringify(!monitors.snapshot.automatic))
      }
      MonitorSettingsStatus { controller: monitorPage.settingsWindow.controller; service: monitors; actions: monitorPage.editing ? ["automatic"] : ["automatic", "apply", "keep", "revert"] }
      Label {
        Layout.fillWidth: true
        visible: text !== ""
        text: monitors.snapshot.automationError || ""
        color: monitorPage.settingsWindow.controller.controlWarningText
      }
      }
      SettingsSubsection {
        Layout.fillWidth: true
        title: "Customize layout & profiles"
        iconName: "settings"
        collapsible: true
        expanded: monitorPage.editing
        onToggled: {
          monitorScroll.preservePosition()
          monitorPage.editing = !monitorPage.editing
        }
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
        color: monitorPage.settingsWindow.controller.controlSurface
        border.color: monitorPage.settingsWindow.controller.controlSurfaceBorder
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
            color: monitors.selectedOutput === index ? monitorPage.settingsWindow.controller.controlActive : monitorPage.settingsWindow.controller.controlBackground
            border.width: monitors.selectedOutput === index ? 2 : 1
            border.color: monitorPage.settingsWindow.controller.controlActiveIcon
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
        Label { Layout.fillWidth: true; text: "Drag displays to arrange; edges snap."; color: monitorPage.settingsWindow.controller.controlSecondaryText }
      }
      }
      SettingsSubsection {
        Layout.fillWidth: true
        visible: monitorPage.editing
        title: "Display properties"
        iconName: "monitor"
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
        color: monitorPage.settingsWindow.controller.controlSecondaryText
      }
      Toggle {
        Layout.fillWidth: true
        text: "Enable display"
        checked: monitors.output?.enabled ?? false
        enabled: monitors.output !== null
        onClicked: monitors.edit("enabled", !monitors.output.enabled)
      }
      SettingsGrid {
        id: displayProperties
        Layout.fillWidth: true
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
          activeFocusOnTab: true
          HoverHandler { id: scaleHover }
          Hint {
            visible: scaleHover.hovered || scaleHover.parent.activeFocus
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
      }
        Repeater {
          model: ["x", "y"]
          delegate: SettingsGrid {
            id: positionRow
            required property string modelData
            Layout.fillWidth: true
            enabled: monitors.output?.enabled ?? false
            Label { text: positionRow.modelData.toUpperCase() + " position"; Layout.fillWidth: true }
            SettingsTextField {
              controller: monitorPage.settingsWindow.controller
              Layout.alignment: Qt.AlignRight
              Layout.fillWidth: !positionRow.inlineEditors
              Layout.preferredWidth: 120
              implicitWidth: 120
              text: String(monitors.output?.[positionRow.modelData] ?? 0)
              color: monitorPage.settingsWindow.controller.controlPrimaryText
              validator: IntValidator { bottom: 0; top: 65535 }
              Accessible.name: positionRow.modelData.toUpperCase() + " position"
              onEditingFinished: {
                if (acceptableInput) monitors.edit(positionRow.modelData, Number(text))
                text = Qt.binding(() => String(monitors.output?.[positionRow.modelData] ?? 0))
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
      Toggle {
        Layout.fillWidth: true
        visible: monitors.snapshot.session === "wayland"
        text: "10-bit color"
        checked: (monitors.output?.bitDepth ?? monitors.connectedOutput?.bitDepth) === 10
        enabled: (monitors.output?.enabled ?? false) && (monitors.connectedOutput?.tenBitAvailable ?? false)
          && !monitors.busy && !monitors.pending
        onClicked: monitors.edit("bitDepth", (monitors.output?.bitDepth ?? monitors.connectedOutput?.bitDepth) === 10 ? 8 : 10)
      }
      Label {
        Layout.fillWidth: true
        visible: monitors.snapshot.session === "wayland"
        text: "Current output: " + (monitors.connectedOutput?.bitDepth ? monitors.connectedOutput.bitDepth + "-bit" : "Unknown")
          + "\n" + (monitors.connectedOutput?.colorDepthReason || "Display disconnected.")
        color: monitorPage.settingsWindow.controller.controlSecondaryText
      }
      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: monitorPage.settingsWindow.controller.controlSurfaceBorder }
      MonitorSettingsStatus { controller: monitorPage.settingsWindow.controller; service: monitors; actions: ["apply", "keep", "revert"] }
      RowLayout {
        Layout.fillWidth: true
        SoundButton { text: "Reload current"; iconName: "refresh-cw"; onClicked: { monitors.resetAfterRead = true; monitors.refresh() } }
        Item { Layout.fillWidth: true }
        SoundButton { text: "Apply"; enabled: monitors.dirty; onClicked: monitors.run("apply", JSON.stringify(monitors.draft)) }
      }
      }
      SettingsSubsection {
        Layout.fillWidth: true
        visible: monitorPage.editing
        title: "Connection details"
        iconName: "gauge"
        statusText: monitors.action === "details" ? monitors.error || (monitors.busy ? "Loading connection details…" : "") : ""
        statusError: monitors.error !== ""
        collapsible: true
        expanded: monitors.linkDetails !== null
        enabled: monitors.connectedOutput !== null && monitors.connectedOutput !== undefined
        onToggled: {
          monitorScroll.preservePosition()
          if (monitors.linkDetails) monitors.linkDetails = null
          else monitors.run("details", monitors.connectedOutput.connector)
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
        activeFocusOnTab: true
        Hint {
          visible: linkHintHover.hovered || linkHintHover.parent.activeFocus
          text: "These describe the current applied layout, not the draft. The estimate assumes uncompressed 8-bit RGB. EDID limits describe the monitor's HDMI capability, not the negotiated GPU/cable/dock link. max bpc is a limit, not active color depth."
        }
      }
      }
      SettingsSubsection {
        Layout.fillWidth: true
        visible: monitorPage.editing
        title: "Save & manage profiles"
        iconName: "boxes"
      SettingsTextField {
        id: profileName
        controller: monitorPage.settingsWindow.controller
        Layout.fillWidth: true
        placeholderText: "Profile name"
        color: monitorPage.settingsWindow.controller.controlPrimaryText
        placeholderTextColor: monitorPage.settingsWindow.controller.controlSecondaryText
        Accessible.name: "Profile name"
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
      MonitorSettingsStatus { controller: monitorPage.settingsWindow.controller; service: monitors; actions: ["save", "rename", "delete", "import"] }
      Label {
        Layout.fillWidth: true
        text: monitors.dirty ? "Draft changes · apply and keep before saving." : "Saved in system-settings/monitor-profiles.json"
        color: monitorPage.settingsWindow.controller.controlSecondaryText
      }
      }
    }
  }
}

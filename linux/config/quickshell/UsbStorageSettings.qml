pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: page
  required property var controller
  required property var preferences
  required property var service
  signal disclosureToggled()
  spacing: 16

  component Label: Text {
    color: page.controller.controlPrimaryText
    font.family: page.controller.fontFamily
    font.pixelSize: 12
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }
  component Button: SettingsButton { controller: page.controller }

  SettingsSection {
    Layout.fillWidth: true
    controller: page.controller
    title: "USB storage"
    iconName: "usb"
    SettingsToggle {
      Layout.fillWidth: true
      controller: page.controller
      text: "Automatically mount USB drives"
      checked: page.service.automount
      enabled: !page.service.busy && page.preferences.ready && !page.preferences.busy
      description: "When off, new drives stay unmounted. Turning it on also mounts connected drives that are currently unmounted."
      onClicked: page.service.run("automount")
    }
    Label {
      Layout.fillWidth: true
      text: page.service.automount ? "Automatic mounting is on." : "Automatic mounting is off. Mounted drives stay mounted until you unmount them."
      color: page.controller.controlSecondaryText
    }
  }

  SettingsSection {
    Layout.fillWidth: true
    controller: page.controller
    title: "Connected drives"
    iconName: "hard-drive"
    Label {
      Layout.fillWidth: true
      visible: page.service.devices.length === 0
      text: "No USB storage devices connected."
      color: page.controller.controlSecondaryText
    }
    Repeater {
      model: page.service.devices
      delegate: ColumnLayout {
        id: driveRow
        required property var modelData
        required property int index
        Layout.fillWidth: true
        spacing: 8
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: driveRow.index > 0; color: page.controller.controlSurfaceBorder }
        Label { Layout.fillWidth: true; text: driveRow.modelData.name; font.bold: true }
        Label {
          Layout.fillWidth: true
          text: page.formatSize(driveRow.modelData.size) + " · " + (driveRow.modelData.volumes.length ? driveRow.modelData.volumes.length + (driveRow.modelData.volumes.length === 1 ? " volume" : " volumes") : "No mountable volumes")
          color: page.controller.controlSecondaryText
        }
        Repeater {
          model: driveRow.modelData.volumes
          delegate: RowLayout {
            id: volumeRow
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            ColumnLayout {
              Layout.fillWidth: true
              Label { Layout.fillWidth: true; text: volumeRow.modelData.name }
              Label {
                Layout.fillWidth: true
                text: volumeRow.modelData.mounts.length ? volumeRow.modelData.mounts.join(", ") : volumeRow.modelData.filesystem + " · Not mounted"
                color: page.controller.controlSecondaryText
                elide: Text.ElideMiddle
              }
            }
            Button {
              text: volumeRow.modelData.mounts.length ? "Unmount safely" : "Mount"
              enabled: !page.service.busy
              description: text + " " + volumeRow.modelData.name
              onClicked: page.service.run(volumeRow.modelData.mounts.length ? "unmount" : "mount", volumeRow.modelData.path)
            }
          }
        }
      }
    }
  }

  SettingsSection {
    Layout.fillWidth: true
    visible: page.service.fstabMounts.length > 0
    controller: page.controller
    title: "Remote Volumes"
    iconName: "network"
    Label {
      Layout.fillWidth: true
      text: "Currently mounted filesystems configured in fstab. System mounts are omitted."
      color: page.controller.controlSecondaryText
    }
    Repeater {
      model: page.service.fstabMounts
      delegate: ColumnLayout {
        id: fstabRow
        required property var modelData
        required property int index
        Layout.fillWidth: true
        spacing: 8
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: fstabRow.index > 0; color: page.controller.controlSurfaceBorder }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          ColumnLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: fstabRow.modelData.target; font.bold: true }
            Label {
              Layout.fillWidth: true
              text: fstabRow.modelData.source + " · " + fstabRow.modelData.filesystem
              color: page.controller.controlSecondaryText
              elide: Text.ElideMiddle
            }
          }
          Button {
            text: "Unmount safely"
            enabled: !page.service.busy
            description: "Unmount " + fstabRow.modelData.target + " safely"
            onClicked: page.service.run("unmount-fstab", fstabRow.modelData.target)
          }
        }
      }
    }
  }
  Label {
    Layout.fillWidth: true
    visible: page.service.error !== ""
    text: page.service.error
    color: page.controller.controlWarningText
  }
  Label {
    Layout.fillWidth: true
    visible: page.service.result !== ""
    text: page.service.result
    color: page.controller.controlSecondaryText
  }

  function formatSize(bytes) {
    if (!Number.isFinite(bytes) || bytes <= 0) return "Size unavailable"
    const units = ["B", "KiB", "MiB", "GiB", "TiB"]
    let unit = 0
    while (bytes >= 1024 && unit < units.length - 1) { bytes /= 1024; unit++ }
    return bytes.toFixed(unit === 0 ? 0 : 1) + " " + units[unit]
  }
}

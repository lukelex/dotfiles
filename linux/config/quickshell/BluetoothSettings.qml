pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls

ColumnLayout {
  id: page
  required property var controller
  required property var service
  required property bool active
  property bool adding: false
  signal disclosureToggled()
  signal revealRequested(var item)
  spacing: 16
  readonly property bool multipleAdapters: Bluetooth.adapters.values.length > 1
  readonly property bool someAdaptersOff: Bluetooth.adapters.values.some(adapter => !adapter.enabled)
  readonly property var known: Bluetooth.devices.values.filter(device => device.connected || device.paired || device.bonded)
  readonly property var discovered: Bluetooth.devices.values.filter(device => !device.connected && !device.paired && !device.bonded && manager.seen.includes(device.dbusPath))
  readonly property bool resultHasRow: known.concat(discovered).some(device => device.dbusPath === manager.resultPath)

  BluetoothManager { id: manager; active: page.active }
  ListModel { id: knownRows }
  ListModel { id: discoveredRows }

  // Preserve delegates and reading order across discovery/battery updates.
  function syncRows(model, devices) {
    const available = new Map(devices.map(device => [device.dbusPath, device]))
    for (let index = model.count - 1; index >= 0; index--) {
      if (!available.has(model.get(index).identity)) model.remove(index)
    }
    for (let index = 0; index < model.count; index++) {
      const identity = model.get(index).identity
      if (model.get(index).device !== available.get(identity))
        model.setProperty(index, "device", available.get(identity))
      available.delete(identity)
    }
    for (const [identity, device] of available) model.append({ identity, device })
  }
  onKnownChanged: syncRows(knownRows, known)
  onDiscoveredChanged: syncRows(discoveredRows, discovered)
  Component.onCompleted: { syncRows(knownRows, known); syncRows(discoveredRows, discovered) }
  onActiveChanged: { if (!active) adding = false }

  component Label: Text {
    color: page.controller.controlPrimaryText
    font.family: page.controller.fontFamily
    font.pixelSize: 12
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }
  component Button: SettingsButton { controller: page.controller }
  component Section: SettingsSection { controller: page.controller }

  Section {
    Layout.fillWidth: true
    title: "Bluetooth"
    iconName: "bluetooth"
    SettingsToggle {
      controller: page.controller
      Layout.fillWidth: true
      text: page.multipleAdapters ? "Bluetooth on all adapters" : "Bluetooth"
      checked: page.service.bluetoothEnabled
      enabled: page.service.bluetoothAvailable && !page.service.bluetoothChanging && !manager.pendingPath
      description: "Turns all available adapters on or off. Hardware-blocked adapters cannot be enabled here."
      onClicked: page.service.setBluetoothEnabled(!page.service.bluetoothEnabled)
    }
    Label {
      Layout.fillWidth: true
      text: !page.service.bluetoothAvailable ? "No Bluetooth adapter detected."
        : page.service.bluetoothChanging ? "Updating Bluetooth…"
        : page.service.bluetoothBlocked ? "One or more adapters are hardware blocked. Check the physical switch or airplane mode."
        : !page.service.bluetoothEnabled ? "Bluetooth is off."
        : page.someAdaptersOff ? "Some adapters are off. The switch turns all adapters off; turn it back on to enable all available adapters."
        : "Bluetooth is on."
      color: page.controller.controlSecondaryText
    }
    Label {
      Layout.fillWidth: true
      visible: page.service.bluetoothError !== ""
      text: page.service.bluetoothError
      color: page.controller.controlWarningText
    }
    Label {
      Layout.fillWidth: true
      visible: manager.error !== "" && !page.resultHasRow
      text: manager.error
      color: page.controller.controlWarningText
    }
    Label {
      Layout.fillWidth: true
      visible: manager.message !== "" && !page.resultHasRow
      text: manager.message
      color: page.controller.controlSecondaryText
    }
    Label {
      Layout.fillWidth: true
      visible: !manager.ready && manager.error === ""
      text: "Starting Bluetooth management…"
      color: page.controller.controlSecondaryText
    }
  }

  Section {
    Layout.fillWidth: true
    title: "Your devices"
    iconName: "bluetooth"
    Label {
      Layout.fillWidth: true
      visible: knownRows.count === 0
      text: "No connected or paired devices. Choose Add device to pair one."
      color: page.controller.controlSecondaryText
    }
    Repeater {
      model: knownRows
      delegate: DeviceRow {
        required property var device
        required property int index
        target: device
        divider: index > 0
        Layout.fillWidth: true
      }
    }
    Button {
      text: "Add device…"
      enabled: manager.ready && page.service.bluetoothEnabled && !manager.pendingPath && !page.adding
      onClicked: { page.adding = true; manager.scan(); page.disclosureToggled() }
    }
  }

  Section {
    Layout.fillWidth: true
    visible: page.adding
    title: "Add device"
    iconName: "search"
    Label {
      Layout.fillWidth: true
      text: manager.scanning ? "Searching for 60 seconds… Put your device in pairing mode."
        : "Discovery stopped. Results are from this scan and may no longer be nearby."
      color: page.controller.controlSecondaryText
    }
    Label {
      Layout.fillWidth: true
      visible: manager.scanError !== ""
      text: manager.scanError
      color: page.controller.controlWarningText
    }
    Label {
      Layout.fillWidth: true
      visible: discoveredRows.count === 0
      text: "No new devices discovered."
      color: page.controller.controlSecondaryText
    }
    Repeater {
      model: discoveredRows
      delegate: DeviceRow {
        required property var device
        required property int index
        target: device
        divider: index > 0
        Layout.fillWidth: true
      }
    }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      Button {
        text: manager.scanning ? "Stop discovery" : "Scan again"
        enabled: manager.ready && page.service.bluetoothEnabled && !manager.pendingPath
        onClicked: manager.scanning ? manager.stopScan() : manager.scan()
      }
      Button {
        text: "Done"
        onClicked: {
          manager.stopScan()
          manager.cancelPair()
          page.adding = false
          page.disclosureToggled()
        }
      }
    }
  }

  component DeviceRow: ColumnLayout {
    id: row
    required property var target
    property bool divider: false
    property bool confirmForget: false
    readonly property string identity: target?.dbusPath || ""
    readonly property string deviceName: target?.name || target?.address || "Bluetooth device"
    readonly property bool paired: target?.paired || target?.bonded || false
    readonly property bool connected: target?.connected || false
    readonly property bool busy: manager.pendingPath === identity
    readonly property bool prompting: manager.prompt !== null && manager.prompt.path === identity
    spacing: 8
    onTargetChanged: confirmForget = false
    onVisibleChanged: { if (!visible) confirmForget = false }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: row.divider; color: page.controller.controlSurfaceBorder }
    Label { Layout.fillWidth: true; text: row.deviceName; font.bold: true }
    Label {
      Layout.fillWidth: true
      text: (row.busy ? (manager.pendingAction === "pair" ? "Pairing…" : "Updating…")
        : row.connected ? "Connected" : row.paired ? "Paired · not connected" : "Discovered in this scan")
        + (row.target?.batteryAvailable && Number.isFinite(row.target.battery) && row.target.battery >= 0 && row.target.battery <= 1
          ? " · " + Math.round(row.target.battery * 100) + "% battery" : "")
        + (page.multipleAdapters ? " · " + (row.target?.adapter?.name || "Adapter unavailable") : "")
      color: page.controller.controlSecondaryText
    }
    Label {
      Layout.fillWidth: true
      text: row.target?.address || ""
      color: page.controller.controlSecondaryText
    }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      Button {
        text: row.busy ? (manager.pendingAction === "pair" ? "Pairing…"
          : manager.pendingAction === "connect" ? "Connecting…"
          : manager.pendingAction === "disconnect" ? "Disconnecting…" : "Forgetting…")
          : row.connected ? "Disconnect" : row.paired ? "Connect" : "Pair"
        description: text + " " + row.deviceName
        enabled: manager.ready && !manager.pendingPath && row.target !== null && (row.target?.adapter?.enabled || false)
        onClicked: manager.run(row.connected ? "disconnect" : row.paired ? "connect" : "pair", row.identity)
      }
      Button {
        visible: row.busy && manager.pendingAction === "pair" && !row.prompting
        text: "Cancel pairing"
        onClicked: manager.cancelPair()
      }
      Button {
        id: more
        visible: row.paired
        iconName: "ellipsis"
        quiet: true
        description: "Manage " + row.deviceName
        enabled: manager.ready && !manager.pendingPath
        onClicked: manageMenu.popup()
        Controls.Menu {
          id: manageMenu
          y: more.height
          width: 180
          background: Rectangle { radius: 10; color: page.controller.controlSurface; border.color: page.controller.controlSurfaceBorder }
          Controls.MenuItem {
            id: forgetItem
            text: "Forget device…"
            onTriggered: { row.confirmForget = true; page.disclosureToggled() }
            contentItem: Label { text: forgetItem.text }
            background: Rectangle { radius: 8; color: forgetItem.highlighted ? page.controller.controlHover : "transparent" }
          }
        }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      visible: row.confirmForget
      Label {
        Layout.fillWidth: true
        text: "Forget " + row.deviceName + "? This removes its pairing and disconnects it. You will need to pair again to reconnect."
      }
      Flow {
        Layout.fillWidth: true
        spacing: 8
        Button {
          text: "Forget device"
          enabled: manager.ready && !manager.pendingPath && row.target !== null
          onClicked: { const path = row.identity; row.confirmForget = false; manager.run("forget", path) }
        }
        Button { text: "Cancel"; onClicked: row.confirmForget = false }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      visible: row.prompting
      readonly property var request: row.prompting ? manager.prompt : null
      id: pairingPrompt
      readonly property bool pin: request?.kind === "RequestPinCode"
      readonly property bool passkey: request?.kind === "RequestPasskey"
      readonly property bool displayOnly: request?.kind === "DisplayPinCode" || request?.kind === "DisplayPasskey"
      property int lastToken: 0
      onRequestChanged: {
        if (request && request.token === lastToken) return
        lastToken = request?.token || 0
        secret.clear()
        if (request) Qt.callLater(() => {
          if (!row.prompting) return
          if (pairingPrompt.pin || pairingPrompt.passkey) secret.forceActiveFocus()
          page.revealRequested(pairingPrompt)
        })
      }
      Label {
        Layout.fillWidth: true
        text: pairingPrompt.pin ? "Enter the device PIN (up to 16 bytes)."
          : pairingPrompt.passkey ? "Enter the six-digit passkey shown on the device."
          : pairingPrompt.request?.kind === "DisplayPinCode" ? "Type this PIN on the device: " + pairingPrompt.request.value
          : pairingPrompt.request?.kind === "DisplayPasskey" ? "Type this code on the device: " + String(pairingPrompt.request.value).padStart(6, "0") + " · " + pairingPrompt.request.entered + " digits entered"
          : pairingPrompt.request?.kind === "RequestConfirmation" ? "Does this code match the device? " + String(pairingPrompt.request.value).padStart(6, "0")
          : pairingPrompt.request?.kind === "AuthorizeService" ? "Allow the requested Bluetooth service? " + pairingPrompt.request.value
          : "Allow pairing with this device?"
      }
      SettingsTextField {
        id: secret
        controller: page.controller
        Layout.fillWidth: true
        visible: pairingPrompt.pin || pairingPrompt.passkey
        echoMode: TextInput.Password
        maximumLength: pairingPrompt.passkey ? 6 : 16
        Accessible.name: pairingPrompt.pin ? "Bluetooth pairing PIN" : "Bluetooth pairing passkey"
        onAccepted: { if (submit.enabled) submit.clicked() }
        onVisibleChanged: { if (!visible) clear() }
      }
      Flow {
        Layout.fillWidth: true
        spacing: 8
        Button {
          id: submit
          visible: !pairingPrompt.displayOnly
          text: pairingPrompt.pin || pairingPrompt.passkey ? "Submit" : "Confirm"
          enabled: row.prompting && (!pairingPrompt.pin || secret.text.length > 0 && encodeURIComponent(secret.text).replace(/%[A-F\d]{2}/gi, "x").length <= 16)
            && (!pairingPrompt.passkey || /^[0-9]{1,6}$/.test(secret.text))
          onClicked: {
            const token = pairingPrompt.request.token
            const value = secret.text
            secret.clear()
            manager.answer(token, true, value)
          }
        }
        Button { text: "Cancel pairing"; onClicked: { secret.clear(); manager.cancelPair() } }
      }
    }
    Label {
      Layout.fillWidth: true
      visible: manager.resultPath === row.identity && (manager.error !== "" || manager.message !== "")
      text: manager.error || manager.message
      color: manager.error ? page.controller.controlWarningText : page.controller.controlSecondaryText
    }
  }
}

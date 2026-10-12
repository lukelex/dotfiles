pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls

ColumnLayout {
  id: page
  required property var controller
  required property var service
  spacing: 20
  property var pendingPassphraseNetwork: null
  property string actionKey: ""
  property string actionName: ""
  property bool unavailableExpanded: false
  readonly property bool radioReady: service.wifiAvailable && service.wifiEnabled && service.wifiHardwareEnabled
  readonly property bool multipleAdapters: service._wifiDevices.length > 1
  readonly property var currentNetworks: service.knownNetworks.filter(network => network && network.connected)
  readonly property var availableSaved: service.knownNetworks.filter(network => network && !network.connected
    && (network.signalStrength > 0 || network.stateChanging || network === page.service.connectingNetwork))
  readonly property var unavailableSaved: service.knownNetworks.filter(network => network && !network.connected
    && network.signalStrength <= 0 && !network.stateChanging && network !== page.service.connectingNetwork)
  readonly property var allNetworks: service.knownNetworks.concat(service.discoveredNetworks).filter(network => network !== null)
  readonly property bool errorHasRow: actionKey !== "" && allNetworks.some(network => page.networkKey(network) === actionKey)

  function networkKey(network) {
    if (!network || !network.device) return ""
    return JSON.stringify([network.device.name, network.name, network.security])
  }

  // Retain delegates and order through signal changes. New entries append; only
  // disappeared entries are removed, so typing and focus survive scan updates.
  function syncRows(model, networks) {
    const available = new Map(networks.filter(network => network && page.networkKey(network)).map(network => [page.networkKey(network), network]))
    for (let index = model.count - 1; index >= 0; index--) {
      if (!available.has(model.get(index).identity))
        model.remove(index)
    }
    for (let index = 0; index < model.count; index++) {
      const identity = model.get(index).identity
      const network = available.get(identity)
      if (model.get(index).network !== network)
        model.setProperty(index, "network", network)
      available.delete(identity)
    }
    for (const [identity, network] of available)
      model.append({ identity, network })
  }

  function beginAction(network) {
    page.actionKey = page.networkKey(network)
    page.actionName = network.name || "Hidden network"
    page.service.clearErrors()
  }

  function signalIcon(network) {
    if (!network) return "wifi-zero"
    if (network.signalStrength <= 0) return "wifi-zero"
    if (network.signalStrength < 0.25) return "wifi-low"
    if (network.signalStrength < 0.75) return "wifi-high"
    return "wifi"
  }

  function signalColor(network) {
    if (!network) return page.controller.controlSecondaryText
    if (network.signalStrength <= 0) return page.controller.controlSecondaryText
    if (network.signalStrength < 0.25) return page.controller.urgent
    if (network.signalStrength < 0.5) return page.controller.controlWarningText
    if (network.signalStrength < 0.75) return page.controller.controlActiveIcon
    return page.controller.controlDownloadIcon
  }

  function securityLabel(network) {
    if (!network) return "Unavailable"
    return network.security === WifiSecurityType.Open ? "Open"
      : network.security === WifiSecurityType.Owe ? "Encrypted · no password" : "Secured"
  }

  onVisibleChanged: {
    if (!visible) {
      page.pendingPassphraseNetwork = null
      page.unavailableExpanded = false
    }
  }
  onAllNetworksChanged: {
    if (page.pendingPassphraseNetwork && !page.allNetworks.includes(page.pendingPassphraseNetwork))
      page.pendingPassphraseNetwork = null
  }
  Connections {
    target: page.service
    function onWifiEnabledChanged() { if (!page.service.wifiEnabled) page.pendingPassphraseNetwork = null }
    function onConnectingNetworkChanged() {
      if (page.service.connectingNetwork) {
        page.actionKey = page.networkKey(page.service.connectingNetwork)
        page.actionName = page.service.connectingNetwork.name
      }
    }
  }

  component Label: Text {
    color: page.controller.controlSecondaryText
    font.family: page.controller.fontFamily
    font.pixelSize: 12
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  component Hint: Controls.ToolTip {
    id: hint
    delay: 500
    implicitWidth: Math.min(300, contentItem.implicitWidth + 20)
    contentItem: Label { text: hint.text; color: page.controller.controlPrimaryText }
    background: Rectangle { radius: 8; color: page.controller.controlSurface; border.color: page.controller.controlSurfaceBorder }
  }

  component Button: Controls.Button {
    id: button
    property string iconName: ""
    property string description: text
    property bool quiet: false
    implicitWidth: text ? Math.max(76, buttonText.implicitWidth + (iconName ? 44 : 24)) : 36
    implicitHeight: 36
    focusPolicy: Qt.StrongFocus
    Accessible.name: description
    opacity: enabled ? 1 : 0.5
    background: Rectangle {
      radius: 8
      color: button.down || button.hovered ? page.controller.controlHover
        : button.quiet ? "transparent" : page.controller.controlSurface
      border.width: button.activeFocus ? 2 : button.quiet ? 0 : 1
      border.color: button.activeFocus ? page.controller.controlActiveIcon : page.controller.controlSurfaceBorder
    }
    contentItem: Item {
      LucideIcon {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        visible: button.iconName !== ""
        source: button.iconName ? page.controller.icon(button.iconName) : ""
        color: page.controller.controlSecondaryText
      }
      Label {
        id: buttonText
        anchors.fill: parent
        anchors.leftMargin: button.iconName ? 24 : 0
        text: button.text
        color: page.controller.controlPrimaryText
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: button.iconName ? Text.AlignLeft : Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
      }
    }
    Hint { text: button.description; visible: button.hovered || button.activeFocus }
  }

  component NetworkRow: ColumnLayout {
    id: row
    required property var network
    // Copy display fields: native objects can be destroyed before model removal.
    readonly property var details: ({ name: network?.name || "Network unavailable",
      security: network?.security ?? WifiSecurityType.Unknown,
      signalStrength: network?.signalStrength || 0, known: network?.known || false,
      connected: network?.connected || false, stateChanging: network?.stateChanging || false,
      device: { name: network?.device?.name || "" } })
    property bool current: false
    property bool offline: false
    property bool confirmForget: false
    readonly property bool busy: details.stateChanging || (network !== null && page.service.connectingNetwork === network)
    readonly property bool narrow: width < 370
    readonly property string identity: page.networkKey(network)
    spacing: 8
    enabled: network !== null
    onNetworkChanged: { confirmForget = false; passphrase.clear() }
    onVisibleChanged: { if (!visible) confirmForget = false }

    GridLayout {
      Layout.fillWidth: true
      columns: row.narrow ? 2 : 3
      columnSpacing: 12
      rowSpacing: 8
      Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 32
        LucideIcon {
          anchors.centerIn: parent
          width: 22
          height: 22
          source: page.controller.icon(row.current ? "circle-check" : page.signalIcon(row.network))
          color: row.current ? page.controller.controlActiveIcon : page.signalColor(row.network)
        }
        Rectangle {
          visible: row.details.security !== WifiSecurityType.Open && !row.current
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          width: 14
          height: 14
          radius: 4
          color: page.controller.controlSurface
          LucideIcon { anchors.centerIn: parent; width: 10; height: 10; source: page.controller.icon("lock"); color: page.controller.controlSecondaryText }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 4
        Label {
          Layout.fillWidth: true
          text: row.details.name || "Hidden network"
          color: page.controller.controlPrimaryText
          font.pixelSize: row.current ? 14 : 12
          font.bold: row.current
        }
        Flow {
          Layout.fillWidth: true
          spacing: 5
          Label { visible: row.current || row.busy; text: row.current ? "Connected ·" : "Connecting… ·" }
          Label {
            text: row.offline ? "Out of range" : row.details.signalStrength > 0 ? page.service.wifiStrengthText(row.details.signalStrength) + " signal" : "Signal unavailable"
            color: page.signalColor(row.network)
          }
          Label { text: "· " + page.securityLabel(row.network) }
          Label { visible: page.multipleAdapters; text: "· " + (row.details.device?.name || "") }
        }
        HoverHandler { id: detailsHover }
        Hint {
          visible: detailsHover.hovered
          text: row.details.name + "\n" + WifiSecurityType.toString(row.details.security) + " · " + (row.details.device?.name || "")
        }
      }
      RowLayout {
        Layout.columnSpan: row.narrow ? 2 : 1
        Layout.alignment: Qt.AlignRight
        visible: !row.current
        spacing: 4
        Button {
          visible: !row.offline
          text: row.busy ? "Connecting…" : row.details.known || page.service.wifiCanConnectDiscovered(row.details) ? "Connect" : "Configure…"
          description: text + " " + (row.details.name || "hidden Wi-Fi")
          enabled: page.radioReady && !page.service.wifiConnecting
          onClicked: {
            page.beginAction(row.network)
            if (row.network.known)
              page.service.connectNetwork(row.network)
            else if (!page.service.wifiCanConnectDiscovered(row.network))
              Quickshell.execDetached(["nm-connection-editor"])
            else if (page.service.wifiNeedsPassphrase(row.network)) {
              page.pendingPassphraseNetwork = row.network
              Qt.callLater(() => passphrase.forceActiveFocus())
            } else
              page.service.connectDiscoveredNetwork(row.network, "")
          }
        }
        Button {
          id: overflow
          visible: row.details.known
          text: "⋯"
          implicitWidth: 36
          quiet: true
          description: "Manage " + row.details.name
          enabled: !row.busy && !page.service.wifiConnecting
          onClicked: manageMenu.popup()
          Controls.Menu {
            id: manageMenu
            x: overflow.width - width
            y: overflow.height
            width: 180
            background: Rectangle { radius: 10; color: page.controller.controlSurface; border.color: page.controller.controlSurfaceBorder }
            Controls.MenuItem {
              id: activateItem
              text: "Activate saved profile"
              visible: row.offline
              height: visible ? implicitHeight : 0
              enabled: row.offline && page.radioReady && !page.service.wifiConnecting
              onTriggered: {
                page.beginAction(row.network)
                page.service.connectNetwork(row.network)
              }
              contentItem: Label { text: activateItem.text; color: page.controller.controlPrimaryText }
              background: Rectangle { color: activateItem.highlighted ? page.controller.controlHover : "transparent"; radius: 8 }
            }
            Controls.MenuItem {
              id: forgetItem
              text: "Forget network…"
              enabled: !row.details.connected && !row.busy
              onTriggered: row.confirmForget = true
              contentItem: Label { text: forgetItem.text; color: page.controller.controlPrimaryText }
              background: Rectangle { color: forgetItem.highlighted ? page.controller.controlHover : "transparent"; radius: 8 }
            }
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: row.network !== null && page.pendingPassphraseNetwork === row.network
      onVisibleChanged: { if (!visible) passphrase.clear() }
      spacing: 8
      Controls.TextField {
        id: passphrase
        Layout.fillWidth: true
        placeholderText: "Wi-Fi password"
        echoMode: TextInput.Password
        color: page.controller.controlPrimaryText
        selectionColor: page.controller.controlActive
        selectedTextColor: page.controller.controlPrimaryText
        font.family: page.controller.fontFamily
        padding: 10
        Accessible.name: "Password for " + row.details.name
        onAccepted: { if (connectButton.enabled) connectButton.clicked() }
        background: Rectangle { radius: 8; color: page.controller.controlBackground; border.color: passphrase.activeFocus ? page.controller.controlActiveIcon : page.controller.controlSurfaceBorder }
      }
      RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignRight
        Button {
          text: "Cancel"
          quiet: true
          onClicked: { passphrase.clear(); page.pendingPassphraseNetwork = null }
        }
        Button {
          id: connectButton
          text: "Connect"
          description: "Connect to " + row.details.name
          enabled: page.radioReady && !page.service.wifiConnecting && passphrase.text.length >= 8 && passphrase.text.length <= 63
          onClicked: {
            const secret = passphrase.text
            passphrase.clear()
            page.pendingPassphraseNetwork = null
            page.beginAction(row.network)
            page.service.connectDiscoveredNetwork(row.network, secret)
          }
        }
      }
    }
    Label {
      Layout.fillWidth: true
      visible: page.actionKey === row.identity && page.service.wifiError !== ""
      text: page.service.wifiError
      color: page.controller.controlWarningText
    }
    ColumnLayout {
      Layout.fillWidth: true
      visible: row.confirmForget
      Label { Layout.fillWidth: true; text: "Forget “" + row.details.name + "” and its saved credentials?" }
      RowLayout {
        Layout.alignment: Qt.AlignRight
        Button { text: "Cancel"; quiet: true; onClicked: row.confirmForget = false }
        Button {
          text: "Forget"
          enabled: !row.details.connected && !row.busy && !page.service.wifiConnecting
          onClicked: {
            page.beginAction(row.network)
            page.service.forgetWifiNetwork(row.network)
            row.confirmForget = false
          }
        }
      }
    }
  }

  component NetworkGroup: Rectangle {
    id: group
    required property var entries
    property bool current: false
    property bool offline: false
    property alias count: records.count
    implicitHeight: rows.implicitHeight + 8
    visible: count > 0
    radius: 14
    color: current ? page.controller.controlActive : page.controller.controlSurface
    border.color: current ? page.controller.controlActiveIcon : page.controller.controlSurfaceBorder
    ListModel { id: records; dynamicRoles: true }
    onEntriesChanged: page.syncRows(records, entries)
    Component.onCompleted: page.syncRows(records, entries)
    ColumnLayout {
      id: rows
      x: 12
      y: 4
      width: group.width - 24
      spacing: 0
      Repeater {
        model: records
        delegate: ColumnLayout {
          id: entryRow
          required property var network
          required property int index
          Layout.fillWidth: true
          spacing: 0
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            visible: entryRow.index > 0
            color: page.controller.controlSurfaceBorder
          }
          NetworkRow {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            network: entryRow.network
            current: group.current
            offline: group.offline
          }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Label { Layout.fillWidth: true; text: "Wi-Fi"; color: page.controller.controlPrimaryText; font.pixelSize: 14 }
    Button {
      text: "ⓘ"
      implicitWidth: 32
      quiet: true
      description: "Passwords go directly to NetworkManager. Saved networks and credentials are managed by NetworkManager, not stored in dotfiles."
    }
    Controls.Switch {
      id: radio
      text: page.service.wifiEnabled ? "On" : "Off"
      checked: page.service.wifiEnabled
      enabled: page.service.wifiAvailable && (page.service.wifiEnabled || page.service.wifiHardwareEnabled)
      Accessible.name: "Wi-Fi"
      palette.windowText: page.controller.controlPrimaryText
      palette.highlight: page.controller.controlActiveIcon
      font.family: page.controller.fontFamily
      spacing: 8
      indicator: Rectangle {
        x: radio.leftPadding
        y: (radio.height - height) / 2
        implicitWidth: 40
        implicitHeight: 24
        radius: 12
        color: radio.checked ? page.controller.controlActive : page.controller.controlSliderTrack
        border.color: radio.activeFocus ? page.controller.controlActiveIcon : page.controller.controlSurfaceBorder
        border.width: radio.activeFocus ? 2 : 1
        Rectangle {
          x: radio.checked ? parent.width - width - 3 : 3
          y: 3
          width: 18
          height: 18
          radius: 9
          color: radio.checked ? page.controller.controlActiveIcon : page.controller.controlSecondaryText
        }
      }
      contentItem: Label {
        leftPadding: radio.indicator.width + radio.spacing
        text: radio.text
        color: page.controller.controlPrimaryText
        verticalAlignment: Text.AlignVCenter
      }
      onClicked: {
        page.actionKey = ""
        page.service.clearErrors()
        page.service.setWifiEnabled(!page.service.wifiEnabled)
      }
    }
  }

  NetworkGroup { Layout.fillWidth: true; entries: page.currentNetworks; current: true }
  RowLayout {
    Layout.fillWidth: true
    visible: page.currentNetworks.length === 0
    LucideIcon { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: page.controller.icon(page.radioReady ? "wifi-zero" : "wifi-off"); color: page.controller.controlSecondaryText }
    Label {
      Layout.fillWidth: true
      text: !page.service.wifiAvailable ? "No Wi-Fi adapter available"
        : !page.service.wifiHardwareEnabled ? "Wi-Fi is hardware blocked"
        : !page.service.wifiEnabled ? "Wi-Fi is off" : "Not connected · choose a network below"
    }
  }
  Label {
    Layout.fillWidth: true
    visible: page.service.wifiError !== "" && !page.errorHasRow
    text: (page.actionKey ? page.actionName + ": " : "") + page.service.wifiError
    color: page.controller.controlWarningText
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 8
    Label { Layout.fillWidth: true; text: "Saved networks"; color: page.controller.controlPrimaryText; font.bold: true }
    NetworkGroup { Layout.fillWidth: true; entries: page.availableSaved }
    Label {
      Layout.fillWidth: true
      visible: page.availableSaved.length === 0
      text: page.radioReady ? "No other saved networks in range." : "Enable Wi-Fi to find saved networks in range."
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 8
    RowLayout {
      Layout.fillWidth: true
      Label { Layout.fillWidth: true; text: "Other nearby networks"; color: page.controller.controlPrimaryText; font.bold: true }
      Button {
        iconName: "refresh-cw"
        quiet: true
        description: page.service.wifiRescanSuspended ? "Requesting scan…" : "Scan again"
        enabled: page.radioReady && !page.service.wifiRescanSuspended
        onClicked: page.service.rescanWifi()
      }
    }
    NetworkGroup { Layout.fillWidth: true; entries: page.service.discoveredNetworks }
    Label {
      Layout.fillWidth: true
      visible: page.service.discoveredNetworks.length === 0
      text: page.radioReady ? "No new networks found. Use Scan again to refresh." : "Enable Wi-Fi to discover nearby networks."
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    visible: page.unavailableSaved.length > 0
    spacing: 8
    Button {
      Layout.fillWidth: true
      quiet: true
      iconName: page.unavailableExpanded ? "chevrons-down-up" : "chevron-right"
      text: "Unavailable saved networks (" + page.unavailableSaved.length + ")"
      onClicked: page.unavailableExpanded = !page.unavailableExpanded
    }
    NetworkGroup {
      Layout.fillWidth: true
      entries: page.unavailableSaved
      offline: true
      visible: page.unavailableExpanded && count > 0
    }
  }
  Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: page.controller.controlSurfaceBorder }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 4
    Button {
      Layout.fillWidth: true
      quiet: true
      iconName: "wifi"
      text: "Add hidden network…"
      description: "Add a hidden Wi-Fi network in NetworkManager's connection editor."
      onClicked: Quickshell.execDetached(["nm-connection-editor", "--create", "--type=802-11-wireless"])
    }
    Button {
      Layout.fillWidth: true
      quiet: true
      iconName: "settings"
      text: "Advanced network settings"
      description: "Edit saved profiles, enterprise authentication, certificates and IP settings in NetworkManager."
      onClicked: Quickshell.execDetached(["nm-connection-editor"])
    }
  }
}

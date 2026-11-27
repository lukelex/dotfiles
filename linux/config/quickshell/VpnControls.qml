pragma ComponentBehavior: Bound

import QtQuick

Column {
  id: vpn
  required property var popup
  required property var service
  spacing: 10

  component Action: ConnectivityAction { host: vpn.popup }
  component Label: ConnectivityLabel { host: vpn.popup }

  Action {
    width: parent.width
    title: "NordVPN"
    iconName: "globe"
    radioSwitch: true
    active: vpn.service.connected
    enabled: vpn.service.installed && !vpn.service.busy
      && vpn.service.statusKnown
    subtitle: vpn.service.statusText
    onActivated: {
      vpn.popup.requestOpen()
      vpn.service.toggle()
    }
  }

  Label {
    width: parent.width
    visible: text !== ""
    text: vpn.service.error || vpn.service.statusError || vpn.service.locationsError
    color: vpn.popup.controller.urgent
    elide: Text.ElideNone
    wrapMode: Text.Wrap
  }

  Action {
    width: parent.width
    title: "Refresh VPN status"
    visible: vpn.service.installed && !vpn.service.statusKnown
    height: visible ? 40 : 0
    onActivated: vpn.service.refresh()
  }

  Row {
    width: parent.width
    height: visible ? vpnLocations.implicitHeight : 0
    spacing: 10
    visible: vpn.service.installed

    Label {
      anchors.verticalCenter: parent.verticalCenter
      text: "Destination"
      width: 80
    }

    SettingsChoice {
      id: vpnLocations

      anchors.verticalCenter: parent.verticalCenter
      enabled: !vpn.service.busy
      controller: vpn.popup.controller
      focusPolicy: vpn.popup.pinned ? Qt.StrongFocus : Qt.NoFocus
      model: vpn.service.locationOptions
      textRole: "label"
      valueRole: "value"
      currentIndex: vpn.service.locationOptions.findIndex(option => option.value === vpn.service.selectedLocation)
      width: parent.width - 90 - (applyVpnLocation.visible ? applyVpnLocation.width + 10 : 0)
      Accessible.name: "VPN destination"
      onPressedChanged: { if (pressed) vpn.popup.requestOpen(true) }
      onActivated: index => vpn.service.selectLocation(model[index].value)
    }

    Action {
      id: applyVpnLocation
      anchors.verticalCenter: parent.verticalCenter
      width: 64
      height: 32
      title: "Apply"
      visible: vpn.service.connected && vpn.service.destinationEdited
      enabled: !vpn.service.busy
      Accessible.name: "Connect to selected VPN destination"
      onActivated: {
        vpn.popup.requestOpen(true)
        vpn.service.connectLocation(vpn.service.selectedLocation)
      }
    }
  }
}

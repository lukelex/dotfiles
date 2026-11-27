pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

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
    height: visible ? 32 : 0
    spacing: 10
    visible: vpn.service.installed

    Label {
      anchors.verticalCenter: parent.verticalCenter
      text: "Destination"
      width: 80
    }

    ComboBox {
      id: vpnLocations

      anchors.verticalCenter: parent.verticalCenter
      enabled: !vpn.service.busy
      font.family: vpn.popup.controller.fontFamily
      font.pixelSize: 11
      palette.base: vpn.popup.controller.controlSurface
      palette.button: vpn.popup.controller.controlSurface
      palette.text: vpn.popup.controller.controlPrimaryText
      palette.buttonText: vpn.popup.controller.controlPrimaryText
      palette.highlight: vpn.popup.controller.controlActive
      palette.highlightedText: vpn.popup.controller.controlPrimaryText
      palette.window: vpn.popup.controller.controlSurface
      palette.windowText: vpn.popup.controller.controlPrimaryText
      model: vpn.service.locationOptions
      textRole: "label"
      valueRole: "value"
      currentIndex: vpn.service.locationOptions.findIndex(option => option.value === vpn.service.selectedLocation)
      width: parent.width - 90 - (applyVpnLocation.visible ? applyVpnLocation.width + 10 : 0)
      Accessible.name: "VPN destination"
      onActivated: function(index) {
        vpn.popup.requestOpen(true)
        vpn.service.selectLocation(model[index].value)
      }
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

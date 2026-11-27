pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ToolTip {
  required property var host
  id: hint
  delay: 500
  padding: 10
  width: Math.min(340, hint.host.width - 24)
  contentItem: ConnectivityLabel {
    host: hint.host
    text: hint.text
    color: hint.host.controller.controlPrimaryText
    wrapMode: Text.Wrap
    elide: Text.ElideNone
  }
  background: Rectangle {
    radius: 10
    color: hint.host.controller.controlSurface
    border.width: 1
    border.color: hint.host.controller.controlSurfaceBorder
  }
}

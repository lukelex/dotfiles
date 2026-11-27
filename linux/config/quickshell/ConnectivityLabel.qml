pragma ComponentBehavior: Bound

import QtQuick

Text {
  required property var host
  color: host.controller.controlSecondaryText
  font.family: host.controller.fontFamily
  font.pixelSize: 11
  textFormat: Text.PlainText
  elide: Text.ElideRight
}

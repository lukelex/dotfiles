import QtQuick
import Qt5Compat.GraphicalEffects

Item {
  id: root

  required property url source
  property color color: "white"

  implicitHeight: 18
  implicitWidth: 18

  Image {
    id: image

    anchors.fill: parent
    source: root.source
  }

  ColorOverlay {
    anchors.fill: parent
    color: root.color
    source: image
  }
}

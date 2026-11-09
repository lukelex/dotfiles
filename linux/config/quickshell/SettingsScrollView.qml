pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.ScrollView {
  id: scroll
  readonly property Flickable flickable: contentItem as Flickable
  contentWidth: availableWidth
  clip: true
  function resetPosition() {
    restore.stop()
    if (flickable) flickable.contentY = flickable.originY
  }
  function preservePosition() {
    if (!flickable) return
    restore.offset = flickable.contentY - flickable.originY
    restore.restart()
  }
  Timer {
    id: restore
    property real offset: 0
    interval: 16
    onTriggered: {
      if (!scroll.flickable || scroll.flickable.moving) return
      scroll.flickable.contentY = scroll.flickable.originY + offset
      scroll.flickable.returnToBounds()
    }
  }
  onVisibleChanged: { if (visible) resetPosition() }
  Binding {
    target: scroll.contentItem
    property: "boundsBehavior"
    value: Flickable.StopAtBounds
  }
}

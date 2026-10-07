pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Flickable {
  id: view
  required property var entries
  required property var keyForEntry
  required property Component delegate
  required property bool panelVisible
  required property bool keyboardEnabled
  required property var focusFallback
  property real maximumHeight: 180
  readonly property real rowWidth: width - (contentHeight > height ? 12 : 0)
  readonly property bool interacting: listHover.hovered || moving || focusedKey !== ""
  readonly property string focusedKey: {
    for (let index = 0; index < items.count; index++) {
      const item = items.itemAt(index)
      if (item && item.activeFocus)
        return records.get(index).deviceKey
    }
    return ""
  }
  property var readingAnchor: null
  property string pendingFocusKey: ""
  property bool reconciling: false

  height: Math.min(maximumHeight, rows.implicitHeight)
  contentWidth: width
  contentHeight: rows.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  onEntriesChanged: sync()
  onInteractingChanged: { if (!interacting) sync() }
  onPanelVisibleChanged: sync()
  onMovementStarted: readingAnchor = null
  onContentYChanged: { if (!reconciling) readingAnchor = null }
  Component.onCompleted: sync()

  HoverHandler { id: listHover }
  ScrollBar.vertical: ScrollBar {
    policy: ScrollBar.AsNeeded
    onPressedChanged: { if (pressed) view.readingAnchor = null }
  }

  ListModel { id: records; dynamicRoles: true }
  Column {
    id: rows
    width: view.rowWidth
    spacing: 6
    Repeater {
      id: items
      model: records
      delegate: view.delegate
    }
  }

  function sync() {
    if (view.reconciling)
      return
    const available = view.entries.filter(entry => entry !== null)
    const byKey = new Map(available.map(entry => [view.keyForEntry(entry), entry]))
    let desired = available
    // Existing rows retain their order during pointer/keyboard interaction.
    if (view.panelVisible && view.interacting) {
      const retained = []
      for (let index = 0; index < records.count; index++) {
        const key = records.get(index).deviceKey
        if (byKey.has(key))
          retained.push(byKey.get(key))
      }
      const retainedKeys = new Set(retained.map(entry => view.keyForEntry(entry)))
      desired = retained.concat(available.filter(entry => !retainedKeys.has(view.keyForEntry(entry))))
    }

    const previous = []
    for (let index = 0; index < items.count; index++) {
      const item = items.itemAt(index)
      if (item)
        previous.push({ key: records.get(index).deviceKey, y: item.y, height: item.height })
    }
    const survivors = previous.filter(entry => byKey.has(entry.key))
    if (!view.readingAnchor || !byKey.has(view.readingAnchor.key)) {
      const pointerY = view.contentY + listHover.point.position.y
      const hovered = listHover.hovered ? survivors.find(entry => entry.y <= pointerY && entry.y + entry.height > pointerY) : null
      const anchor = hovered || survivors.find(entry => entry.y + entry.height > view.contentY) || survivors[survivors.length - 1]
      view.readingAnchor = !view.moving && anchor ? { key: anchor.key, offset: anchor.y - view.contentY } : null
    }
    const focused = view.focusedKey
    if (focused && !byKey.has(focused)) {
      const oldIndex = previous.findIndex(entry => entry.key === focused)
      const next = previous.slice(oldIndex + 1).find(entry => byKey.has(entry.key)) || survivors[survivors.length - 1]
      view.pendingFocusKey = next ? next.key : "fallback"
    }

    view.reconciling = true
    for (let index = 0; index < desired.length; index++) {
      const key = view.keyForEntry(desired[index])
      let existing = index
      while (existing < records.count && records.get(existing).deviceKey !== key)
        existing++
      if (existing === records.count) {
        records.insert(index, { deviceKey: key, entry: desired[index] })
      } else {
        if (existing !== index)
          records.move(existing, index, 1)
        if (records.get(index).entry !== desired[index])
          records.setProperty(index, "entry", desired[index])
      }
    }
    if (records.count > desired.length)
      records.remove(desired.length, records.count - desired.length)
    rows.forceLayout()
    view.restore()
    view.reconciling = false
    Qt.callLater(view.restore)
  }

  function restore() {
    if (view.readingAnchor && !view.moving) {
      for (let index = 0; index < records.count; index++) {
        if (records.get(index).deviceKey === view.readingAnchor.key) {
          const item = items.itemAt(index)
          if (item)
            view.contentY = Math.max(0, Math.min(item.y - view.readingAnchor.offset, view.contentHeight - view.height))
          break
        }
      }
    }
    if (view.pendingFocusKey && view.panelVisible && view.keyboardEnabled) {
      const target = view.pendingFocusKey
      view.pendingFocusKey = ""
      let found = false
      for (let index = 0; index < records.count; index++) {
        if (records.get(index).deviceKey === target && items.itemAt(index)) {
          items.itemAt(index).forceActiveFocus()
          found = true
          break
        }
      }
      if (!found)
        view.focusFallback.forceActiveFocus()
    }
  }
}

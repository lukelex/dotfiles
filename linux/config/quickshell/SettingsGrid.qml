pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Alternating label/editor pairs. Reflow the same items so focus survives resizing.
GridLayout {
  id: grid
  readonly property real labelWidth: Math.max(0, ...Array.from(children).filter((_, index) => index % 2 === 0).map(item => item.implicitWidth))
  readonly property real editorWidth: Math.max(0, ...Array.from(children).filter((_, index) => index % 2 === 1).map(item => item.preferredEditorWidth ?? item.implicitWidth))
  readonly property bool inlineEditors: width >= labelWidth + editorWidth + columnSpacing
  columns: inlineEditors ? 2 : 1
  columnSpacing: 16
  rowSpacing: 12
}

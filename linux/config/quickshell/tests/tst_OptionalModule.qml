import QtQuick
import QtTest
import ".."

TestCase {
  id: testCase
  name: "OptionalModule"
  when: windowShown
  visible: true
  property int reading: 12

  Row {
    id: row
    spacing: 8
    OptionalModule {
      id: broken
      module: "data:text/plain," + encodeURIComponent("import Missing.OptionalPlugin\nimport QtQuick\nItem {}")
    }
    OptionalModule {
      id: healthy
      module: "data:text/plain," + encodeURIComponent("import QtQuick\nItem { required property int reading; implicitWidth: reading; implicitHeight: 16 }")
      initialProperties: () => ({ reading: Qt.binding(() => testCase.reading) })
    }
  }

  function test_failedSiblingDoesNotAffectLayoutOrUpdates() {
    tryCompare(broken, "status", Loader.Error)
    tryCompare(healthy, "status", Loader.Ready)
    compare(broken.visible, false)
    compare(row.implicitWidth, 12)
    const original = healthy.item
    reading = 24
    tryCompare(row, "implicitWidth", 24)
    compare(healthy.item, original)
  }
}

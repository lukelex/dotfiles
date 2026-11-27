import QtQuick

// Resolve the URL at the feature boundary, so a component error stays local.
Loader {
  required property url module
  property var initialProperties: () => ({})

  focus: true
  visible: status === Loader.Ready
  Component.onCompleted: setSource(module, initialProperties())
}

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Scope {
  id: rootIdentify
  required property var controller
  required property var outputs
  function identify() {
    const labels = {}
    for (const screen of Quickshell.screens) {
      const index = rootIdentify.outputs.findIndex(output => output.connector === screen.name)
      labels[screen.name] = (index >= 0 ? (index + 1) + " · " : "") + screen.name
    }
    rootIdentify.controller.notificationService.showOsd("Monitor", 0, "monitor", "Display", labels)
  }
}

//@ pragma UseQApplication
import Quickshell
import QtQml

Scope {
  Connections {
    target: Quickshell

    function onReloadCompleted() {
      Quickshell.inhibitReloadPopup()
      notifications.item?.showOsd("Reload", 0, "refresh-cw", "Quickshell Reloaded")
    }
  }

  SystemPreferences { id: preferences }
  OptionalModule {
    id: notifications
    module: "NotificationService.qml"
    initialProperties: () => ({
      preferences, bluetoothDevices: Qt.binding(() => bar.bluetooth?.connectedBluetoothDevices ?? []),
      historyBeingRead: Qt.binding(() => bar.notificationCenterOpen)
    })
  }
  OptionalModule { id: audioLoader; module: "AudioService.qml" }
  OptionalModule { id: webcamLoader; module: "WebcamService.qml" }
  OptionalModule { id: headsets; module: "HeadsetService.qml" }
  OptionalModule { id: openEffects; module: "OpenEffectsService.qml" }

  Bar {
    id: bar
    preferences: preferences
    notificationService: notifications.item
    audioService: audioLoader.item
    webcamService: webcamLoader.item
    headsetService: headsets.item
    openEffectsService: openEffects.item
  }
}

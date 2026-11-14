//@ pragma UseQApplication
import Quickshell
import QtQml

Scope {
  Connections {
    target: Quickshell

    function onReloadCompleted() {
      Quickshell.inhibitReloadPopup()
      notifications.showOsd("Reload", 0, "refresh-cw", "Quickshell Reloaded")
    }
  }

  SystemPreferences { id: preferences }
  NotificationService {
    id: notifications
    preferences: preferences
    historyBeingRead: bar.notificationCenterOpen
  }

  // One shared device snapshot backs the output picker on each screen.
  AudioService {
    id: audioService
  }

  WebcamService {
    id: webcamService
  }

  HeadsetService { id: headsets }
  OpenEffectsService { id: openEffects }

  Bar {
    id: bar
    preferences: preferences
    notificationService: notifications
    audioService: audioService
    webcamService: webcamService
    headsetService: headsets
    openEffectsService: openEffects
  }
}

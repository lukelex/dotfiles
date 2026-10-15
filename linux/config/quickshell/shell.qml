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
    historyBeingRead: bar.notificationCenterOpen || bar.githubReviewCenterOpen
  }

  GitHubPrService {
    id: githubPrs
  }

  // One shared device snapshot backs the output picker on each screen.
  AudioService {
    id: audioService
  }

  WebcamService {
    id: webcamService
  }

  OpenEffectsService { id: openEffects }

  Bar {
    id: bar
    preferences: preferences
    notificationService: notifications
    githubPrService: githubPrs
    audioService: audioService
    webcamService: webcamService
    openEffectsService: openEffects
  }
}

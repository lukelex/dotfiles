//@ pragma UseQApplication
import Quickshell

Scope {
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

  Bar {
    id: bar
    preferences: preferences
    notificationService: notifications
    githubPrService: githubPrs
    audioService: audioService
    webcamService: webcamService
  }
}

//@ pragma UseQApplication
import Quickshell

Scope {
  NotificationService {
    id: notifications
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
    notificationService: notifications
    githubPrService: githubPrs
    audioService: audioService
    webcamService: webcamService
  }
}

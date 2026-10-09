//@ pragma UseQApplication
import Quickshell

Scope {
  NotificationService {
    id: notifications
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
    notificationService: notifications
    githubPrService: githubPrs
    audioService: audioService
    webcamService: webcamService
  }
}

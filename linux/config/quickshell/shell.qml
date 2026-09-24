//@ pragma UseQApplication
import Quickshell

Scope {
  NotificationService {
    id: notifications
  }

  GitHubPrService {
    id: githubPrs
  }

  AudioService {
    id: audioService
  }

  Bar {
    notificationService: notifications
    githubPrService: githubPrs
    audioService: audioService
  }
}

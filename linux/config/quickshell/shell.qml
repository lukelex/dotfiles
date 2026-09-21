//@ pragma UseQApplication
import Quickshell

Scope {
  NotificationService {
    id: notifications
  }

  GitHubPrService {
    id: githubPrs
  }

  Bar {
    notificationService: notifications
    githubPrService: githubPrs
  }
}

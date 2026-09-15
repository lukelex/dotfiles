//@ pragma UseQApplication
import Quickshell

Scope {
  NotificationService {
    id: notifications
  }

  Bar {
    notificationService: notifications
  }
}

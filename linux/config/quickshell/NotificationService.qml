import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtCore
import QtQml
import "NotificationDefaults.js" as NotificationDefaults

QtObject {
  id: service

  property int historyLimit: 100
  property int popupLimit: 5
  property int popupGroupWindow: 30
  property int notificationGroupWindow: 5 * 60
  property var history: []
  property var popup: []
  property var popupReversed: []
  property var live: ({})
  property int liveRevision: 0
  property var liveDeadlines: ({})
  property var osd: null
  property var tagMap: ({})
  property var hovered: ({})
  property double now: 0
  property bool doNotDisturb: false
  property bool preferencesLoaded: false
  property bool scheduledDndActive: false
  property string dndScheduleError: ""
  property string dndScheduleStatus: ""
  readonly property bool dndScheduleEnabled: settings.dndScheduleEnabled
  readonly property int dndStartMinutes: settings.dndStartMinutes
  readonly property int dndEndMinutes: settings.dndEndMinutes
  readonly property int dndScheduleDays: settings.dndScheduleDays
  property bool notificationSoundsMuted: false
  property bool notificationSoundIsCritical: false
  readonly property bool allowCriticalDuringDnd: settings.allowCriticalDuringDnd
  property var applications: []
  onNotificationSoundsMutedChanged: {
    if (notificationSoundsMuted)
      service.notificationSound.running = false
  }
  property int osdSequence: 0
  property var githubSeenIds: ({})
  property int githubSeenRevision: 0
  property var historyGroups: []
  property int historyGroupSequence: 0
  readonly property var popupGroups: service.groupPopup(service.popupReversed)
  signal popupRecordAdded(var record)
  signal popupRecordRemoved(var id)
  signal popupRecordsCleared()
  signal historyRecordDismissed(string id)

  property var activationPendingId: null
  property var activationErrorId: null
  property string activationError: ""
  property string activationOutput: ""

  property Process windowFocus: Process {
    command: []
    stdout: StdioCollector { onStreamFinished: service.activationOutput = text }
    onExited: (exitCode, exitStatus) => service.finishActivation(exitCode, exitStatus)
  }

  property Timer activationTimer: Timer {
    interval: 9000
    onTriggered: {
      service.finishActivation(-1, 0)
      service.windowFocus.running = false
    }
  }

  property Process lowerPowerProfile: Process {
    command: []
  }

  property Process notificationSound: Process {
    command: ["play", "-q", service.notificationSoundPath, "vol", "0.5"]
  }

  property string soundSelectionError: ""
  property bool soundPreviewCancelled: false
  readonly property bool soundPreviewPlaying: soundPreview.running
  property Process soundPreview: Process {
    command: []
    onExited: (exitCode) => {
      if (!service.soundPreviewCancelled && exitCode !== 0)
        service.soundSelectionError = "Could not play this file. Check that it exists and is a supported audio format."
    }
  }

  // Resolves theme icon names to concrete files when the QIcon theme lookup fails.
  // Qt caches the icon theme per process, so icons installed after the shell started
  // (e.g. a freshly shipped desktop entry icon) are invisible to Quickshell.iconPath()
  // until a restart. A filesystem search runs outside the QML thread and stays correct
  // for the shell's whole lifetime; results are cached by icon name.
  property var iconFileCache: ({})
  property var iconFilePending: ({})
  property var iconFileQueue: []
  property int iconRevision: 0
  readonly property string iconLookupScript:
    'name=$1\n' +
    'for dir in "$HOME/.local/share/icons/hicolor"/*/apps "$HOME/.local/share/icons"/*/*/apps \\\n' +
    '    /usr/share/icons/hicolor/*/apps /usr/share/icons/*/*/apps /usr/share/pixmaps; do\n' +
    '  for ext in png svg xpm; do\n' +
    '    if [ -f "$dir/$name.$ext" ]; then\n' +
    '      printf \'%s\\n\' "$dir/$name.$ext"\n' +
    '      exit 0\n' +
    '    fi\n' +
    '  done\n' +
    'done\n' +
    'exit 1'
  property string iconFileLastLine: ""
  property Process iconFileResolver: Process {
    command: []
    stdout: SplitParser {
      onRead: data => service.iconFileLastLine = String(data).trim()
    }
    onStarted: service.iconFileLastLine = ""
    onExited: service.finishIconLookup()
  }

  // Process runs outside the QML thread; notification handling stays responsive while audio plays.
  property Timer notificationSoundTimer: Timer {
    interval: 3000
  }

  readonly property string defaultNotificationSoundPath: Quickshell.env("HOME")
    + "/dotfiles/sounds/icq-uh-oh.mp3"
  readonly property string customNotificationSoundPath: settings.soundFilePath
  readonly property string notificationSoundPath: customNotificationSoundPath || defaultNotificationSoundPath
  readonly property string notificationSoundName: customNotificationSoundPath
    ? customNotificationSoundPath.split("/").pop() : "ICQ (default)"
  readonly property string popupCorner: settings.popupCorner
  readonly property int popupDurationSeconds: settings.popupDurationSeconds
  readonly property string popupMonitor: settings.popupMonitor
  readonly property bool popupPreviews: settings.popupPreviews
  readonly property string lockScreenPrivacy: settings.lockScreenPrivacy
  readonly property int historyRetentionDays: settings.historyRetentionDays
  property bool historyBeingRead: false
  onHistoryBeingReadChanged: {
    if (!historyBeingRead)
      service.pruneHistory()
  }

  property Settings settings: Settings {
    id: settings
    location: "file://" + Quickshell.env("HOME") + "/.local/state/dotfiles/notifications.conf"
    property string historyJson: "[]"
    property string githubSeenJson: "[]"
    property string applicationsJson: "[]"
    property string soundFilePath: ""
    property string popupCorner: "top-right"
    property int popupDurationSeconds: 20
    property string popupMonitor: "all"
    property bool popupPreviews: true
    property string lockScreenPrivacy: "show"
    property int historyRetentionDays: 0
    property bool doNotDisturb: false
    property bool dndScheduleEnabled: false
    property int dndStartMinutes: 22 * 60
    property int dndEndMinutes: 8 * 60
    property int dndScheduleDays: 127
    property double dndOverrideUntil: 0
    property bool dndOverrideEnabled: false
    property bool notificationSoundsMuted: false
    property bool allowCriticalDuringDnd: false

    onDoNotDisturbChanged: { if (!service.importingPreferences) service.refreshDndSchedule() }
    onNotificationSoundsMutedChanged: service.notificationSoundsMuted = notificationSoundsMuted
  }

  property var preferences: null
  property bool importingPreferences: false
  property string importedNotifications: ""
  readonly property var portableKeys: ["soundFilePath", "popupCorner", "popupDurationSeconds", "popupMonitor", "popupPreviews", "lockScreenPrivacy", "historyRetentionDays", "doNotDisturb", "dndScheduleEnabled", "dndStartMinutes", "dndEndMinutes", "dndScheduleDays", "notificationSoundsMuted", "allowCriticalDuringDnd"]
  property Connections portableReader: Connections {
    target: service.preferences
    function onDataChanged() { service.importPreferences() }
    function onReadyChanged() { service.importPreferences() }
  }
  function importPreferences() {
    if (!preferences || !preferences.ready)
      return
    const values = preferences.data.notifications || {}
    const serialized = JSON.stringify(values)
    if (serialized === importedNotifications)
      return
    importedNotifications = serialized
    importingPreferences = true
    const scheduleChanged = ["dndScheduleEnabled", "dndStartMinutes", "dndEndMinutes", "dndScheduleDays"]
      .some(key => values[key] !== undefined && values[key] !== settings[key])
    for (const key of portableKeys)
      if (values[key] !== undefined)
        settings[key] = values[key]
    if (values.applications !== undefined) {
      settings.applicationsJson = JSON.stringify(values.applications)
      service.loadApplications()
      service.history = service.history.map(record => {
        const app = service.applications.find(entry => entry.key === service.appKey(record))
        return app && !app.enabled ? Object.assign({}, record, { popupSuppressed: true }) : record
      })
      service.pendingPopupRecords = service.pendingPopupRecords.filter(record =>
        !service.applications.some(entry => entry.key === service.appKey(record) && !entry.enabled))
    }
    if (scheduleChanged)
      settings.dndOverrideUntil = 0
    settings.sync()
    service.refreshDndSchedule()
    if (service.doNotDisturb)
      service.suppressDndRecords()
    service.pruneHistory()
    service.syncPopup()
    importingPreferences = false
  }
  function savePortablePreferences() {
    if (preferences && preferences.ready && !importingPreferences)
      portableSave.restart()
  }
  property Timer portableSave: Timer {
    interval: 250
    onTriggered: {
      const changes = {}
      const saved = service.preferences.data.notifications || {}
      for (const key of service.portableKeys)
        if (saved[key] !== settings[key])
          changes["notifications." + key] = settings[key]
      const apps = JSON.parse(settings.applicationsJson)
      if (JSON.stringify(saved.applications) !== JSON.stringify(apps))
        changes["notifications.applications"] = apps
      service.preferences.setMany(changes)
    }
  }
  property Connections portableWriter: Connections {
    target: settings
    function onApplicationsJsonChanged() { service.savePortablePreferences() }
    function onSoundFilePathChanged() { service.savePortablePreferences() }
    function onPopupCornerChanged() { service.savePortablePreferences() }
    function onPopupDurationSecondsChanged() { service.savePortablePreferences() }
    function onPopupMonitorChanged() { service.savePortablePreferences() }
    function onPopupPreviewsChanged() { service.savePortablePreferences() }
    function onLockScreenPrivacyChanged() { service.savePortablePreferences() }
    function onHistoryRetentionDaysChanged() { service.savePortablePreferences() }
    function onDoNotDisturbChanged() { service.savePortablePreferences() }
    function onDndScheduleEnabledChanged() { service.savePortablePreferences() }
    function onDndStartMinutesChanged() { service.savePortablePreferences() }
    function onDndEndMinutesChanged() { service.savePortablePreferences() }
    function onDndScheduleDaysChanged() { service.savePortablePreferences() }
    function onNotificationSoundsMutedChanged() { service.savePortablePreferences() }
    function onAllowCriticalDuringDndChanged() { service.savePortablePreferences() }
  }

  property NotificationServer server: NotificationServer {
    id: server
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    keepOnReload: false
    extraHints: ["wired-tag", "value", "suppress-sound", "x-github-review-url", "x-github-review-repository", "x-github-review-number", "x-github-review-title", "x-github-review-status", "x-github-review-author", "x-github-review-state"]

    onNotification: n => service.handleNotification(n)
  }

  property Timer expiryTimer: Timer {
    id: expiryTimer
    interval: 500
    repeat: true
    running: true
    onTriggered: {
      service.now = Date.now()
      service.expireDue()
    }
  }

  property Timer historyRetentionTimer: Timer {
    interval: 60000
    repeat: true
    running: service.historyRetentionDays > 0
    onTriggered: service.pruneHistory()
  }

  property SystemClock scheduleClock: SystemClock {
    precision: SystemClock.Minutes
    onDateChanged: service.refreshDndSchedule()
  }

  property Timer osdTimer: Timer {
    id: osdTimer

    interval: service.preferences ? service.preferences.value("display.osdDurationMs", 1500) : 1500
    onTriggered: {
      if (!service.osd)
        return

      const record = service.osd
      const notification = service.live[record.id]
      if (notification)
        notification.expire()
      service.releaseLive(record.id, notification)
      if (record.tag && service.tagMap[record.tag] === notification)
        delete service.tagMap[record.tag]
      service.osd = null
    }
  }

  Component.onCompleted: {
    service.now = Date.now()
    service.loadInitial()
  }

  function loadInitial() {
    service.loadApplications()
    service.migrateApplicationDefaults()
    try {
      const parsed = JSON.parse(settings.historyJson)
      service.history = service.restoreHistory(parsed)
    } catch (error) {
      service.history = []
    }
    try {
      const seen = JSON.parse(settings.githubSeenJson)
      if (Array.isArray(seen))
        for (const id of seen)
          service.githubSeenIds[String(id)] = true
    } catch (error) {
      service.githubSeenIds = {}
    }
    service.doNotDisturb = settings.doNotDisturb
    service.notificationSoundsMuted = settings.notificationSoundsMuted
    for (const record of service.history.slice().reverse())
      service.trackApplication(record)
    service.historyGroups = service.groupHistory(service.history)
    service.pruneHistory()
    service.syncPopup()
    service.preferencesLoaded = true
    service.refreshDndSchedule()
  }

  function saveHistory() {
    historySaveTimer.restart()
  }

  function setHistoryRetentionDays(days) {
    if (![0, 1, 7, 30].includes(days))
      return
    settings.historyRetentionDays = days
    service.pruneHistory()
  }

  function pruneHistory() {
    if (!(service.historyRetentionDays > 0) || service.historyBeingRead)
      return
    const cutoff = Date.now() / 1000 - service.historyRetentionDays * 86400
    const retained = service.history.filter(record => record.time >= cutoff
      || service.live[record.id] || service.hovered[record.id])
    if (retained.length === service.history.length)
      return
    service.history = retained
    service.historyGroups = service.groupHistory(retained)
    service.saveHistory()
  }

  function loadApplications() {
    const applications = []
    const keys = new Set()
    try {
      const parsed = JSON.parse(settings.applicationsJson)
      if (Array.isArray(parsed)) {
        for (const entry of parsed) {
          if (!entry || typeof entry.appName !== "string" || !entry.appName.trim())
            continue
          const appName = entry.appName.trim()
          const key = service.appKey({ appName: appName })
          if (keys.has(key))
            continue
          keys.add(key)
          applications.push({ key: key, appName: appName,
            enabled: entry.enabled !== false, sound: entry.sound !== false })
        }
      }
    } catch (error) {}
    service.applications = applications
  }

  function trackApplication(record) {
    const key = service.appKey(record)
    const existing = service.applications.find(entry => entry.key === key)
    if (existing)
      return existing
    const entry = { key: key, appName: String(record.appName || "Unknown").trim() || "Unknown",
      enabled: true, sound: true }
    service.applications = service.applications.concat([entry])
    settings.applicationsJson = JSON.stringify(service.applications)
    return entry
  }

  function migrateApplicationDefaults() {
    const missing = NotificationDefaults.applications.filter(entry =>
      !service.applications.some(app => app.key === service.appKey(entry)))
    if (missing.length === 0)
      return
    service.applications = service.applications.concat(missing.map(entry =>
      Object.assign({}, entry, { key: service.appKey(entry) })))
    settings.applicationsJson = JSON.stringify(service.applications)
  }

  function setApplicationPreference(key, preference, enabled) {
    if (!["enabled", "sound"].includes(preference) || typeof enabled !== "boolean")
      return
    const entry = service.applications.find(app => app.key === key)
    if (!entry || entry[preference] === enabled)
      return
    service.applications = service.applications.map(app => app.key === key
      ? Object.assign({}, app, { [preference]: enabled }) : app)
    settings.applicationsJson = JSON.stringify(service.applications)
    if (preference === "enabled" && !enabled) {
      // Keep old history, but never replay its popups after re-enabling an app.
      service.history = service.history.map(record => service.appKey(record) === key
        ? Object.assign({}, record, { popupSuppressed: true }) : record)
      service.pendingPopupRecords = service.pendingPopupRecords.filter(record => service.appKey(record) !== key)
      service.saveHistory()
      service.syncPopup()
    }
  }

  function restoreHistory(parsed) {
    if (!Array.isArray(parsed))
      return []
    const records = []
    const ids = new Set()
    for (const value of parsed) {
      if (!value || typeof value !== "object" || Array.isArray(value)
          || !((typeof value.id === "number" && Number.isSafeInteger(value.id) && value.id > 0)
            || (typeof value.id === "string" && value.id.length > 0))
          || typeof value.time !== "number" || !Number.isFinite(value.time) || value.time < 0
          || ids.has(String(value.id)))
        continue
      const record = { id: value.id, time: value.time, actions: [], expiresAt: 0, popupSuppressed: true }
      for (const key of ["tag", "appName", "appIcon", "desktopEntry", "image", "summary", "body",
          "githubReviewUrl", "githubRepository", "githubNumber", "githubTitle", "githubStatus",
          "githubAuthor", "githubReviewState"])
        record[key] = typeof value[key] === "string" ? value[key] : ""
      record.appName = record.appName || "Unknown"
      record.browserNotification = value.browserNotification === true
      record.urgency = ["low", "normal", "critical"].includes(value.urgency) ? value.urgency : "normal"
      record.value = typeof value.value === "number" && Number.isFinite(value.value) ? value.value : -1
      records.push(service.sanitizeRecord(record))
      ids.add(String(value.id))
      if (records.length >= service.historyLimit)
        break
    }
    return records
  }

  function releaseLive(id, notification) {
    // A late closed signal from a replaced native object cannot release its successor.
    if (service.live[id] !== notification)
      return
    delete service.live[id]
    delete service.liveDeadlines[id]
    delete service.hovered[id]
    for (const tag of Object.keys(service.tagMap)) {
      if (service.tagMap[tag] === notification)
        delete service.tagMap[tag]
    }
    service.liveRevision++
  }

  property Timer historySaveTimer: Timer {
    interval: 250
    onTriggered: settings.historyJson = JSON.stringify(service.history.slice(0, service.historyLimit).map(service.sanitizeRecord))
  }

  property Timer historyGroupTimer: Timer {
    interval: 33
    onTriggered: service.historyGroups = service.groupHistory(service.history)
  }

  property var pendingPopupRecords: []
  property Timer popupUpdateTimer: Timer {
    interval: 16
    onTriggered: {
      const pending = service.pendingPopupRecords
      service.pendingPopupRecords = []
      service.syncPopup()
      for (const record of pending) {
        if (service.popup.some(entry => entry.id === record.id))
          service.popupRecordAdded(record)
      }
    }
  }

  function handleNotification(notification) {
    service.refreshDndSchedule()
    const hints = notification.hints || {}
    const tag = String(hints["wired-tag"] || "")
    const value = typeof hints["value"] === "number" ? hints["value"] : -1

    if (tag && service.tagMap[tag]) {
      const previous = service.tagMap[tag]
      delete service.tagMap[tag]
      service.releaseLive(previous.id, previous)
      previous.expire()
    }

    notification.tracked = true
    service.live[notification.id] = notification
    service.liveRevision++
    if (tag)
      service.tagMap[tag] = notification

    const id = notification.id
    notification.closed.connect(() => {
      service.releaseLive(id, notification)
      Qt.callLater(service.syncPopup)
    })

    const record = service.buildRecord(notification, tag, value)
    if (service.isSystemOsd(record)) {
      service.osd = record
      service.osdTimer.restart()
      return
    }

    const application = service.trackApplication(record)
    if (!application.enabled) {
      notification.dismiss()
      service.releaseLive(record.id, notification)
      service.syncPopup()
      return
    }
    service.liveDeadlines[record.id] = record.expiresAt
    service.addHistory(record)
    if (service.isDndSuppressed(record))
      return
    if (application.sound && hints["suppress-sound"] !== true)
      service.playNotificationSound(record)
    service.pendingPopupRecords = service.pendingPopupRecords
      .filter(entry => entry.id !== record.id).concat([record]).slice(-service.popupLimit)
    popupUpdateTimer.start()
  }

  function playNotificationSound(record) {
    if (service.notificationSoundsMuted || service.isDndSuppressed(record)
        || service.notificationSoundTimer.running || service.notificationSound.running)
      return

    service.notificationSoundIsCritical = !!record && record.urgency === "critical"
    service.notificationSound.running = true
    service.notificationSoundTimer.start()
  }

  function isDndSuppressed(record) {
    return service.doNotDisturb && !(service.allowCriticalDuringDnd && record && record.urgency === "critical")
  }

  function setAllowCriticalDuringDnd(enabled) {
    if (typeof enabled !== "boolean" || enabled === service.allowCriticalDuringDnd)
      return
    settings.allowCriticalDuringDnd = enabled
    if (service.doNotDisturb && !enabled)
      service.suppressDndRecords()
    service.syncPopup()
  }

  function suppressDndRecords() {
    if (!service.allowCriticalDuringDnd || !service.notificationSoundIsCritical)
      service.notificationSound.running = false
    // Suppression persists per record so later preference changes never replay old alerts.
    service.history = service.history.map(record => service.isDndSuppressed(record)
      ? Object.assign({}, record, { popupSuppressed: true }) : record)
    service.pendingPopupRecords = service.pendingPopupRecords.filter(record => !service.isDndSuppressed(record))
    service.saveHistory()
  }

  function setPopupCorner(corner) {
    if (["top-right", "top-left", "bottom-right", "bottom-left"].includes(corner))
      settings.popupCorner = corner
  }

  function setPopupDurationSeconds(seconds) {
    if ([0, 5, 10, 20, 30, 60].includes(seconds))
      settings.popupDurationSeconds = seconds
  }

  function setPopupPreviews(enabled) {
    if (typeof enabled === "boolean")
      settings.popupPreviews = enabled
  }

  function setLockScreenPrivacy(mode) {
    if (["show", "redact", "hide"].includes(mode)) {
      settings.lockScreenPrivacy = mode
      settings.sync()
    }
  }

  function popupDisplayRecord(record) {
    if (service.popupPreviews)
      return record
    // Use only application identity for imagery: sender images and action labels can contain private content.
    return {
      id: record.id, appName: record.appName, desktopEntry: record.desktopEntry || "",
      summary: "New notification", body: "", appIcon: "", image: "", actions: [], value: -1,
      urgency: record.urgency, time: record.time
    }
  }

  function setPopupMonitor(monitor) {
    if (typeof monitor === "string" && monitor.length > 0)
      settings.popupMonitor = monitor
  }

  function popupScreenMatches(name, screens, focusedName) {
    if (service.popupMonitor === "all")
      return true
    const names = screens.map(screen => screen.name)
    const preferred = names.includes(service.popupMonitor) ? service.popupMonitor
      : names.includes(focusedName) ? focusedName : names[0]
    return name === preferred
  }

  function setNotificationSoundFile(fileUrl) {
    const url = String(fileUrl || "")
    let path = ""
    if (url) {
      try {
        if (!/^file:\/\/(?:localhost)?\//.test(url))
          throw new Error("Not a local file")
        path = decodeURIComponent(url.replace(/^file:\/\/(?:localhost)?/, ""))
        if (path.includes("\u0000") || path.endsWith("/"))
          throw new Error("Not a file path")
      } catch (error) {
        service.soundSelectionError = "Choose an audio file stored on this computer."
        return false
      }
    }
    service.stopSoundPreview()
    service.soundSelectionError = ""
    settings.soundFilePath = path
    return true
  }

  function previewNotificationSound() {
    if (service.soundPreview.running)
      return
    service.soundSelectionError = ""
    service.soundPreviewCancelled = false
    // Explicit preview is available even while sounds or notifications are muted.
    service.soundPreview.command = ["play", "-q", service.notificationSoundPath, "trim", "0", "10", "vol", "0.5"]
    service.soundPreview.running = true
  }

  function stopSoundPreview() {
    service.soundPreviewCancelled = true
    service.soundPreview.running = false
  }

  function isSystemOsd(record) {
    return record.appName === "System" && ["Brightness", "Volume", "Microphone"].includes(record.summary)
  }

  function showOsd(summary, value, iconName, label, screenLabels = null) {
    service.osdSequence++
    service.osd = {
      id: "osd-" + service.osdSequence,
      tag: "",
      appName: "System",
      appIcon: Quickshell.iconPath(iconName),
      osdIconName: iconName,
      osdLabel: label || "",
      osdScreenLabels: screenLabels,
      image: "",
      summary: summary,
      body: "",
      urgency: "normal",
      value: value,
      actions: [],
      time: Math.floor(Date.now() / 1000),
      expiresAt: 0
    }
    service.osdTimer.restart()
  }

  function buildRecord(notification, tag, value) {
    const actions = service.buildActions(notification, tag)
    const browserNotification = service.isBrowserIcon(notification.appIcon)

    let urgency = "normal"
    if (notification.urgency === NotificationUrgency.Critical)
      urgency = "critical"
    else if (notification.urgency === NotificationUrgency.Low)
      urgency = "low"

    urgency = service.effectiveUrgency(notification, urgency)

    const record = {
      id: notification.id,
      tag: tag,
      appName: service.isTeamsNotification(notification) ? "Microsoft Teams" : notification.appName || "",
      appIcon: notification.appIcon || "",
      browserNotification: browserNotification,
      desktopEntry: notification.desktopEntry || "",
      image: notification.image || "",
      summary: notification.summary || "",
      body: notification.body || "",
      githubReviewUrl: String((notification.hints || {})["x-github-review-url"] || ""),
      githubRepository: String((notification.hints || {})["x-github-review-repository"] || ""),
      githubNumber: String((notification.hints || {})["x-github-review-number"] || ""),
      githubTitle: String((notification.hints || {})["x-github-review-title"] || ""),
      githubStatus: String((notification.hints || {})["x-github-review-status"] || ""),
      githubAuthor: String((notification.hints || {})["x-github-review-author"] || ""),
      githubReviewState: String((notification.hints || {})["x-github-review-state"] || ""),
      urgency: urgency,
      value: value,
      actions: actions,
      popupSuppressed: service.isDndSuppressed({ urgency: urgency }),
      time: Math.floor(Date.now() / 1000),
      expiresAt: service.computeExpiry(notification, urgency)
    }
    // Store the visible body rather than Chromium's transient origin prefix, so
    // the message stays correct after its browser icon is discarded from history.
    record.body = service.displayBody(record)
    return record
  }

  function buildActions(notification, tag) {
    const actions = []
    for (let index = 0; index < notification.actions.length; index++) {
      const action = notification.actions[index]
      if (action.text)
        actions.push({ identifier: action.identifier, text: action.text, sourceIndex: index })
    }

    if (tag === "battery-low" && (notification.hints || {})["x-power-profile-can-lower"] === true)
      actions.push({ identifier: "lower-profile", text: "Use lower power profile", sourceIndex: -1 })

    return actions
  }

  function computeExpiry(notification, urgency) {
    if (urgency === "critical")
      return 0
    if (notification.expireTimeout === 0 && !service.isTeamsNotification(notification))
      return 0
    if (notification.expireTimeout > 0)
      return Date.now() + notification.expireTimeout
    return service.popupDurationSeconds > 0 ? Date.now() + service.popupDurationSeconds * 1000 : 0
  }

  function effectiveUrgency(notification, urgency) {
    if (urgency === "critical" && service.isTeamsNotification(notification)
        && !service.isTeamsUrgent(notification))
      return "normal"
    return urgency
  }

  function addHistory(record) {
    const next = service.history.filter(entry => entry.id !== record.id && (record.tag === "" || entry.tag !== record.tag))
    next.unshift(record)
    service.history = next.slice(0, service.historyLimit)
    historyGroupTimer.start()
    service.saveHistory()
  }

  function expireDue() {
    let changed = false
    for (const id of Object.keys(service.liveDeadlines)) {
      const deadline = service.liveDeadlines[id]
      if (deadline === 0 || deadline > service.now || service.hovered[id])
        continue
      changed = true
      const notification = service.live[id]
      delete service.liveDeadlines[id]
      if (notification)
        notification.expire()
      service.releaseLive(id, notification)
    }
    if (changed)
      service.syncPopup()
  }

  function syncPopup(suppressRemovalId) {
    const cutoff = Date.now()
    const previousPopup = service.popup
    const candidates = service.history.filter(record => !service.isDndSuppressed(record) && !record.popupSuppressed && (record.expiresAt === 0 || record.expiresAt > cutoff || service.hovered[record.id]) && service.live[record.id])
    // Incoming traffic must not evict a card the user is reading or clicking.
    const pinned = candidates.filter(record => service.hovered[record.id])
    const selected = pinned.concat(candidates.filter(record => !service.hovered[record.id]).slice(0, Math.max(0, service.popupLimit - pinned.length)))
    const nextPopup = candidates.filter(record => selected.includes(record))

    for (const record of previousPopup) {
      if (record.id !== suppressRemovalId && !nextPopup.some(entry => entry.id === record.id))
        service.popupRecordRemoved(record.id)
    }

    service.popup = nextPopup
    service.popupReversed = service.popup.slice().reverse()
  }

  function appKey(record) {
    return (String(record.appName || "Unknown").trim() || "Unknown").toLowerCase()
  }

  function groupHistory(records) {
    const groups = []

    for (const record of records) {
      const previousGroup = groups[groups.length - 1]
      const previousRecord = previousGroup ? previousGroup.records[previousGroup.records.length - 1] : null
      const firstRecord = previousGroup ? previousGroup.records[0] : null
      if (previousRecord && service.appKey(previousRecord) === service.appKey(record)
          && previousRecord.urgency === record.urgency
          && Math.abs(record.time - firstRecord.time) <= service.notificationGroupWindow)
        previousGroup.records.push(record)
      else
        groups.push({ key: String(record.id), records: [record] })
    }

    const previousKeys = new Map()
    for (const group of service.historyGroups) {
      for (const record of group.records)
        previousKeys.set(record.id, group.key)
    }
    const usedKeys = new Set()
    for (const group of groups) {
      const survivor = group.records.find(record => previousKeys.has(record.id)
        && !usedKeys.has(previousKeys.get(record.id)))
      group.key = survivor ? previousKeys.get(survivor.id) : "history-" + (++service.historyGroupSequence)
      usedKeys.add(group.key)
    }
    return groups
  }

  function groupPopup(records) {
    const groups = []

    for (const record of records) {
      const previousGroup = groups[groups.length - 1]
      const previousRecord = previousGroup ? previousGroup.records[previousGroup.records.length - 1] : null
      const firstRecord = previousGroup ? previousGroup.records[0] : null
      const isConsecutive = previousGroup
        && previousGroup.key === service.appKey(record)
        && record.urgency === previousRecord.urgency
        && record.time - previousRecord.time <= service.popupGroupWindow
        && Math.abs(record.time - firstRecord.time) <= service.notificationGroupWindow

      if (isConsecutive) {
        previousGroup.records.push(record)
      } else {
        groups.push({ key: service.appKey(record), records: [record] })
      }
    }

    return groups
  }

  function dismissRecord(id, preservePopupLayout = false) {
    const notification = service.live[id]
    if (notification)
      notification.dismiss()
    service.releaseLive(id, notification)
    if (service.osd && service.osd.id === id) {
      service.osdTimer.stop()
      service.osd = null
    }
    service.history = service.history.filter(record => record.id !== id)
    for (const group of service.historyGroups)
      group.records = group.records.filter(record => record.id !== id)
    service.historyRecordDismissed(id)
    service.historyGroups = service.historyGroups.filter(group => group.records.length > 0)
    service.saveHistory()
    service.syncPopup(preservePopupLayout ? id : undefined)
  }

  function dismissRecords(records) {
    const ids = ({})

    for (const record of records) {
      ids[record.id] = true
      if (record.tag && service.tagMap[record.tag] === service.live[record.id])
        delete service.tagMap[record.tag]

      const notification = service.live[record.id]
      if (notification)
        notification.dismiss()
      service.releaseLive(record.id, notification)
    }

    service.history = service.history.filter(record => !ids[record.id])
    service.historyGroups = service.groupHistory(service.history)
    service.saveHistory()
    service.syncPopup()
  }

  function dismissTag(tag) {
    const notification = service.tagMap[String(tag || "")]
    if (notification)
      service.dismissRecord(notification.id)
  }

  function clearHistory() {
    for (const id of Object.keys(service.live)) {
      const notification = service.live[id]
      if (notification)
        notification.dismiss()
      delete service.hovered[id]
    }
    service.live = {}
    service.liveRevision++
    service.liveDeadlines = {}
    service.tagMap = {}
    service.history = []
    service.historyGroups = []
    service.popup = []
    service.popupReversed = []
    service.popupRecordsCleared()
    service.osdTimer.stop()
    service.osd = null
    service.saveHistory()
  }

  function clearVisible() {
    for (const id of Object.keys(service.live)) {
      const notification = service.live[id]
      if (notification)
        notification.dismiss()
      delete service.hovered[id]
    }
    service.live = {}
    service.liveRevision++
    service.liveDeadlines = {}
    service.tagMap = {}
    service.osdTimer.stop()
    service.osd = null
    service.syncPopup()
  }

  function setNotificationSoundsMuted(enabled) {
    service.notificationSoundsMuted = enabled
    settings.notificationSoundsMuted = enabled
  }

  function setDoNotDisturb(enabled) {
    if (service.dndScheduleEnabled) {
      const date = new Date()
      settings.dndOverrideEnabled = enabled
      settings.dndOverrideUntil = service.nextDndBoundary(date)
    }
    settings.doNotDisturb = enabled
    service.applyDoNotDisturb(enabled)
    service.refreshDndSchedule()
  }

  function applyDoNotDisturb(enabled) {
    if (service.doNotDisturb === enabled)
      return
    service.doNotDisturb = enabled
    if (enabled)
      service.suppressDndRecords()
    service.syncPopup()
  }

  function formatScheduleTime(minutes) {
    return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0")
  }

  function setDndSchedule(enabled, start, end, days) {
    if (typeof enabled !== "boolean" || !Number.isInteger(start) || !Number.isInteger(end)
        || start < 0 || start >= 1440 || end < 0 || end >= 1440
        || start === end || ![127, 31, 96].includes(days)) {
      service.dndScheduleError = "Choose different start and end times in 24-hour format."
      return false
    }
    // Disabling automation leaves the current DND state under manual control.
    const current = service.doNotDisturb
    settings.dndScheduleEnabled = enabled
    settings.dndStartMinutes = start
    settings.dndEndMinutes = end
    settings.dndScheduleDays = days
    settings.dndOverrideUntil = 0
    if (!enabled)
      settings.doNotDisturb = current
    service.dndScheduleError = ""
    service.refreshDndSchedule()
    return true
  }

  function dndIntervals(date) {
    const intervals = []
    if (!service.dndScheduleEnabled || service.dndStartMinutes === service.dndEndMinutes)
      return intervals
    const start = service.dndStartMinutes
    const end = service.dndEndMinutes
    for (let offset = -1; offset <= 7; offset++) {
      const day = new Date(date.getFullYear(), date.getMonth(), date.getDate() + offset)
      const weekday = (day.getDay() + 6) % 7
      if (!(service.dndScheduleDays & (1 << weekday)))
        continue
      // Local calendar dates handle DST and overnight intervals without assuming 24-hour days.
      const from = new Date(day.getFullYear(), day.getMonth(), day.getDate(), Math.floor(start / 60), start % 60)
      const to = new Date(day.getFullYear(), day.getMonth(), day.getDate() + (end < start ? 1 : 0), Math.floor(end / 60), end % 60)
      intervals.push({ start: from.getTime(), end: to.getTime() })
    }
    return intervals
  }

  function nextDndBoundary(date) {
    const now = date.getTime()
    const future = service.dndIntervals(date).flatMap(interval => [interval.start, interval.end]).filter(time => time > now)
    return future.length ? Math.min(...future) : 0
  }

  function refreshDndSchedule() {
    if (!service.preferencesLoaded)
      return
    const date = new Date()
    const now = date.getTime()
    service.scheduledDndActive = service.dndIntervals(date).some(interval => now >= interval.start && now < interval.end)
    const overridden = service.dndScheduleEnabled && settings.dndOverrideUntil > now
    if (!overridden && settings.dndOverrideUntil !== 0)
      settings.dndOverrideUntil = 0
    service.dndScheduleStatus = !service.dndScheduleEnabled ? ""
      : overridden ? "Manual override until " + Qt.formatDateTime(new Date(settings.dndOverrideUntil), "ddd HH:mm")
      : service.scheduledDndActive ? "Quiet hours active" : "Quiet hours inactive"
    service.applyDoNotDisturb(overridden ? settings.dndOverrideEnabled
      : service.dndScheduleEnabled ? service.scheduledDndActive : settings.doNotDisturb)
  }

  function setHovered(id, enabled) {
    service.hovered[id] = enabled
  }

  function setRecordsHovered(records, enabled) {
    for (const record of records)
      service.setHovered(record.id, enabled)
  }

  function activateRecord(id) {
    if (service.activationPendingId !== null)
      return false
    service.activationErrorId = id
    service.activationError = ""
    const notification = service.live[id]
    const record = service.history.find(entry => entry.id === id)
    if (service.openGithubReview && service.openGithubReview(record))
      return true

    if (notification) {
      for (let index = 0; index < notification.actions.length; index++) {
        const action = notification.actions[index]
        if (action.identifier === "default") {
          try {
            action.invoke()
            return true
          } catch (error) {
            service.activationError = "This notification's action is no longer available."
            return false
          }
        }
      }
    }

    if (service.focusRecord(record))
      return true
    service.activationError = "No application is available to open this notification."
    return false
  }

  function canActivate(record) {
    service.liveRevision
    if (!record)
      return false
    const notification = service.live[record.id]
    return service.isGithubReview(record)
      || Boolean(notification && notification.actions.some(action => action.identifier === "default"))
      || service.focusCommand(record).length > 0
  }

  function launchActivation(record, command) {
    if (service.activationPendingId !== null)
      return false
    service.activationPendingId = record.id
    service.activationErrorId = record.id
    service.activationError = ""
    service.activationOutput = ""
    service.windowFocus.command = ["timeout", "8"].concat(command)
    service.activationTimer.restart()
    service.windowFocus.running = true
    return true
  }

  function finishActivation(exitCode, exitStatus) {
    if (service.activationPendingId === null)
      return
    service.activationTimer.stop()
    let succeeded = exitCode === 0 && exitStatus === 0
    const command = service.windowFocus.command[2]
    if (succeeded && command === "i3-msg") {
      try {
        const results = JSON.parse(service.activationOutput)
        succeeded = Array.isArray(results) && results.length > 0 && results.every(result => result.success === true)
      } catch (error) { succeeded = false }
    } else if (succeeded && command === "hyprctl") {
      succeeded = service.activationOutput.trim() === "ok"
    }
    service.activationErrorId = service.activationPendingId
    service.activationPendingId = null
    service.activationError = succeeded ? "" : "Could not open the application. It may no longer be running."
  }

  function isGithubReview(record) {
    return String(record && record.githubReviewUrl || "").startsWith("https://github.com/")
  }

  function isGithubReviewSeen(record) {
    service.githubSeenRevision
    return service.isGithubReview(record) && !!service.githubSeenIds[String(record.id)]
  }

  function markGithubReviewSeen(id) {
    const key = String(id || "")
    if (!key || service.githubSeenIds[key])
      return
    service.githubSeenIds[key] = true
    service.githubSeenRevision++
    settings.githubSeenJson = JSON.stringify(Object.keys(service.githubSeenIds))
  }

  function openGithubReview(record) {
    if (!service.isGithubReview(record))
      return false

    return service.launchActivation(record, ["xdg-open", record.githubReviewUrl])
  }

  function focusRecord(record) {
    const command = service.focusCommand(record)
    if (command.length === 0)
      return false

    return service.launchActivation(record, command)
  }

  function focusCommand(record) {
    if (!record)
      return []

    const entryId = String(record.desktopEntry || "")
    const entry = entryId && (DesktopEntries.byId(entryId) || DesktopEntries.byId(entryId.replace(/\.desktop$/, "")))
    const namedApp = DesktopEntries.heuristicLookup(record.appName)
    const startupClass = String((entry || namedApp || {}).startupClass || "")
    if (!startupClass)
      return []

    const escapedClass = startupClass.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&")
    const target = service.isTeamsNotification(record)
      ? "title:^(.*Microsoft Teams.*)$"
      : "class:^(" + escapedClass + ")$"
    if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
      return ["hyprctl", "dispatch", "focuswindow", target]
    if (Quickshell.env("I3SOCK"))
      return ["i3-msg", service.isTeamsNotification(record)
        ? "[title=\"^(?i).*Microsoft Teams.*$\"] focus"
        : "[class=\"^(?i)" + escapedClass + "$\"] focus"]
    return []
  }

  function invokeAction(recordId, index) {
    const notification = service.live[recordId]
    const record = service.history.find(entry => entry.id === recordId)
    const action = record && (record.actions || []).find(entry => entry.sourceIndex === index)
    if (action && action.identifier === "lower-profile") {
      service.lowerPowerProfile.command = [Quickshell.env("HOME") + "/dotfiles/linux/config/quickshell/scripts/battery", "lower-profile"]
      service.lowerPowerProfile.startDetached()
      service.dismissRecord(recordId)
      return
    }

    if (notification && index >= 0 && index < notification.actions.length) {
      service.focusRecord(record)
      notification.actions[index].invoke()
      service.dismissRecord(recordId)
    }
  }

  function timeAgo(record) {
    if (!record)
      return ""

    const seconds = Math.floor(Math.max(0, service.now / 1000 - record.time))
    if (seconds < 60)
      return "now"
    if (seconds < 3600)
      return Math.floor(seconds / 60) + "m"
    if (seconds < 86400)
      return Math.floor(seconds / 3600) + "h"
    if (seconds < 604800)
      return Math.floor(seconds / 86400) + "d"
    return Math.floor(seconds / 604800) + "w"
  }

  function exactTime(record) {
    if (!record || !Number.isFinite(record.time))
      return ""
    return Qt.formatDateTime(new Date(record.time * 1000), "yyyy-MM-dd HH:mm:ss") + " (local time)"
  }

  function lucideIcon(record) {
    const name = String(record.appName).toLowerCase()
    const mappings = [
      [["github"], "message-square-quote"],
      [["telegram desktop", "discord", "slack", "whatsapp"], "message-square"],
      [["kitty"], "monitor"],
      [["flameshot"], "camera"],
      [["gpg", "key"], "key"],
      [["printer", "cups"], "printer"],
      [["bluetooth"], "bluetooth"],
      [["networkmanager"], "globe"]
    ]
    for (const mapping of mappings) {
      if (mapping[0].some(entry => name.includes(entry)))
        return mapping[1]
    }
    return "bell"
  }

  function isBrowserIcon(icon) {
    const name = String(icon || "").toLowerCase()
    return ["brave", "chromium", "firefox", "google-chrome", "google.chrome", "microsoft-edge", "microsoft.edge"].some(browser => name.includes(browser))
  }

  function isTeamsNotification(record) {
    const appName = String(record.appName || "")
    const desktopEntry = String(record.desktopEntry || "")
    const body = String(record.body || "")
    return /microsoft teams|teams\.microsoft/i.test(appName)
      || /(?:^|\n)teams(?:\.cloud)?\.microsoft(?:\.com)?(?:\n|$)/i.test(body)
      || (/teams/i.test(desktopEntry) && service.isBrowserIcon(record.appIcon))
  }

  function isTeamsUrgent(record) {
    const hints = record.hints || {}
    const priority = String(hints["teams-priority"] || hints.priority || "")
    const text = String(record.summary || "") + "\n" + String(record.body || "")
    return /^(?:urgent|high[- ]priority)$/i.test(priority)
      || /(?:^|\b)(?:urgent message|priority message|high[- ]priority)\b/i.test(text)
      || /\bincoming (?:audio |video )?call\b/i.test(text)
  }

  function displayBody(record) {
    const body = String(record && record.body || "")
    const isBrowser = record && (record.browserNotification
      || service.isBrowserIcon(record.appIcon) || service.isBrowserIcon(record.appName))
    if (!record || (!isBrowser && !service.isTeamsNotification(record)))
      return body

    // Chromium prefixes web notifications with their origin on a separate line.
    // Keep recognizing Teams after its temporary browser icon is stripped from
    // persisted history records. Personal messages use one newline.
    return body.replace(/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+[ \t]*(?:\r?\n[ \t]*)+/i, "")
  }

  function isEphemeralSource(source) {
    // Chromium-family browsers park web-notification icons in temporary
    // scoped_dir/.org.chromium directories that are deleted once the
    // notification closes; loading them again (e.g. from history) fails.
    return /(?:\.scoped_dir\.|\.org\.chromium\.)/i.test(String(source || ""))
  }

  function isLiveOnlySource(source) {
    // The notification server keeps these in-memory pixmaps only while the
    // notification is alive; a history record that reuses the same URL renders
    // a broken image once the notification is gone.
    return /^image:\/\/qsimage\//i.test(String(source || ""))
  }

  function usableAppIcon(record) {
    service.liveRevision
    const source = String(record.appIcon || "")
    if (service.isLiveOnlySource(source) && !service.live[record.id])
      return ""
    return service.resolveIcon(source)
  }

  function usableImage(record) {
    service.liveRevision
    const source = String(record.image || "")
    if (service.isLiveOnlySource(source) && !service.live[record.id])
      return ""
    return service.resolveIcon(source)
  }

  function requestIconFile(name) {
    const key = String(name)
    if (!key || key in service.iconFileCache || key in service.iconFilePending)
      return
    service.iconFilePending[key] = true
    service.iconFileQueue = service.iconFileQueue.concat([key])
    if (!service.iconFileResolver.running)
      service.startIconLookup()
  }

  function startIconLookup() {
    const name = service.iconFileQueue.length > 0 ? service.iconFileQueue[0] : ""
    if (!name)
      return
    service.iconFileResolver.command = ["sh", "-c", service.iconLookupScript, "icons", name]
    service.iconFileResolver.running = true
  }

  function finishIconLookup() {
    const name = service.iconFileQueue.length > 0 ? service.iconFileQueue[0] : ""
    service.iconFileQueue = service.iconFileQueue.slice(1)
    if (name) {
      const path = service.iconFileLastLine.trim()
      service.iconFileCache[name] = path ? "file://" + path : ""
      delete service.iconFilePending[name]
      service.iconRevision++
    }
    if (service.iconFileQueue.length > 0)
      service.startIconLookup()
  }

  function sanitizeRecord(record) {
    const clean = {}
    const keys = Object.keys(record)
    for (let index = 0; index < keys.length; index++)
      clean[keys[index]] = record[keys[index]]
    clean.appIcon = service.isLiveOnlySource(clean.appIcon) || service.isEphemeralSource(clean.appIcon) ? "" : clean.appIcon
    clean.image = service.isLiveOnlySource(clean.image) || service.isEphemeralSource(clean.image) ? "" : clean.image
    return clean
  }

  function resolveIcon(icon) {
    const source = String(icon || "")
    if (!source)
      return ""
    if (service.isEphemeralSource(source))
      return ""
    if (/^(file|image|qrc):/.test(source) || source.startsWith("/"))
      return source
    if (Object.prototype.hasOwnProperty.call(service.iconFileCache, source))
      return service.iconFileCache[source]
    const themed = Quickshell.iconPath(source, true)
    if (themed)
      return themed
    service.requestIconFile(source)
    return ""
  }

  function desktopEntryIcon(desktopEntry) {
    const entryId = String(desktopEntry || "")
    if (!entryId)
      return ""

    const entry = DesktopEntries.byId(entryId) || DesktopEntries.byId(entryId.replace(/\.desktop$/, ""))
    return entry ? service.resolveIcon(entry.icon) : ""
  }

  function iconDescriptor(source) {
    const path = source.startsWith("image://icon/") ? source.slice("image://icon/".length) : source
    const url = path.startsWith("/") ? "file://" + path : path
    const lucideDirectory = "file://" + Quickshell.env("HOME") + "/dotfiles/linux/config/lucide/svg/"
    if (url.startsWith(lucideDirectory)) {
      const filename = url.slice(lucideDirectory.length)
      // Only our own monochrome assets should use the theme's foreground color.
      if (/^[a-z0-9-]+\.svg$/.test(filename))
        return { kind: "lucide", source: filename.slice(0, -4) }
    }
    return { kind: "image", source: source }
  }

  function systemIcon(record) {
    if (record.appName !== "System")
      return ""
    const tags = {
      "battery-charging": "battery-charging",
      "battery-critical": "battery-warning",
      "battery-low": "battery-low"
    }
    const summaries = {
      "Charging started": "battery-charging",
      "Battery critical": "battery-warning",
      "Battery low": "battery-low",
      "Battery": "battery",
      "Microphone": "mic-audio-lines",
      "Bluetooth device connected": "bluetooth-connected"
    }
    return Object.prototype.hasOwnProperty.call(tags, record.tag) ? tags[record.tag]
      : Object.prototype.hasOwnProperty.call(summaries, record.summary) ? summaries[record.summary] : ""
  }

  function iconFor(record) {
    // Re-evaluate when an outstanding filesystem icon lookup resolves.
    service.iconRevision

    if (!record)
      return { kind: "lucide", source: "bell" }

    const appIcon = service.usableAppIcon(record)
    const image = service.usableImage(record)
    if (service.isTeamsNotification(record))
      return { kind: "image", source: "file://" + Quickshell.env("HOME") + "/dotfiles/linux/config/quickshell/assets/teams.svg" }
    if (appIcon && !service.isBrowserIcon(record.appIcon))
      return service.iconDescriptor(appIcon)
    if (image)
      return service.iconDescriptor(image)

    const systemIcon = service.systemIcon(record)
    if (systemIcon)
      return { kind: "lucide", source: systemIcon }

    const desktopIcon = service.desktopEntryIcon(record.desktopEntry)
    const namedApp = DesktopEntries.heuristicLookup(record.appName)
    const namedAppIcon = namedApp ? service.resolveIcon(namedApp.icon) : ""
    if (desktopIcon)
      return service.iconDescriptor(desktopIcon)
    if (namedAppIcon)
      return service.iconDescriptor(namedAppIcon)
    if (appIcon)
      return service.iconDescriptor(appIcon)

    return { kind: "lucide", source: service.lucideIcon(record) }
  }
}

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtCore
import QtQml

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
  property var osd: null
  property var tagMap: ({})
  property var hovered: ({})
  property double now: 0
  property bool doNotDisturb: false
  property int osdSequence: 0
  property var historyGroups: []
  readonly property var popupGroups: service.groupPopup(service.popupReversed)
  signal popupRecordAdded(var record)
  signal popupRecordRemoved(var id)
  signal popupRecordsCleared()
  signal historyRecordDismissed(string id)

  property Process windowFocus: Process {
    command: []
  }

  property Process notificationSound: Process {
    command: ["play", "-q", service.notificationSoundPath, "vol", "0.5"]
  }

  // Process runs outside the QML thread; notification handling stays responsive while audio plays.
  property Timer notificationSoundTimer: Timer {
    interval: 3000
  }

  readonly property string notificationSoundPath: Quickshell.env("HOME")
    + "/dotfiles/sounds/icq-uh-oh.mp3"

  property Settings settings: Settings {
    id: settings
    location: "file:///home/lukas/.local/state/dotfiles/notifications.conf"
    property string historyJson: "[]"
    property bool doNotDisturb: false

    onDoNotDisturbChanged: service.doNotDisturb = doNotDisturb
  }

  property NotificationServer server: NotificationServer {
    id: server
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    keepOnReload: false
    extraHints: ["wired-tag", "value"]

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

  property Timer osdTimer: Timer {
    id: osdTimer

    interval: 1500
    onTriggered: {
      if (!service.osd)
        return

      const record = service.osd
      const notification = service.live[record.id]
      if (notification)
        notification.expire()
      delete service.live[record.id]
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
    try {
      const parsed = JSON.parse(settings.historyJson)
    if (Array.isArray(parsed))
      service.history = parsed.slice(0, service.historyLimit)
    } catch (error) {
      service.history = []
    }
    service.doNotDisturb = settings.doNotDisturb
    service.historyGroups = service.groupHistory(service.history)
    service.syncPopup()
  }

  function saveHistory() {
    historySaveTimer.restart()
  }

  property Timer historySaveTimer: Timer {
    interval: 250
    onTriggered: settings.historyJson = JSON.stringify(service.history.slice(0, service.historyLimit))
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
    if (service.doNotDisturb)
      return

    const hints = notification.hints || {}
    const tag = String(hints["wired-tag"] || "")
    const value = typeof hints["value"] === "number" ? hints["value"] : -1

    if (tag && service.tagMap[tag]) {
      const previous = service.tagMap[tag]
      delete service.tagMap[tag]
      delete service.live[previous.id]
      previous.expire()
    }

    notification.tracked = true
    service.live[notification.id] = notification
    if (tag)
      service.tagMap[tag] = notification

    const id = notification.id
    notification.closed.connect(() => {
      if (service.live[id] === notification)
        delete service.live[id]
      if (tag && service.tagMap[tag] === notification)
        delete service.tagMap[tag]
      delete service.hovered[id]
      Qt.callLater(service.syncPopup)
    })

    const record = service.buildRecord(notification, tag, value)
    if (service.isSystemOsd(record)) {
      service.osd = record
      service.osdTimer.restart()
      return
    }

    service.addHistory(record)
    service.playNotificationSound()
    service.pendingPopupRecords = service.pendingPopupRecords
      .filter(entry => entry.id !== record.id).concat([record]).slice(-service.popupLimit)
    popupUpdateTimer.start()
  }

  function playNotificationSound() {
    if (service.notificationSoundTimer.running || service.notificationSound.running)
      return

    service.notificationSound.running = true
    service.notificationSoundTimer.start()
  }

  function isSystemOsd(record) {
    return record.appName === "System" && ["Brightness", "Volume"].includes(record.summary)
  }

  function showOsd(summary, value, iconName) {
    service.osdSequence++
    service.osd = {
      id: "osd-" + service.osdSequence,
      tag: "",
      appName: "System",
      appIcon: Quickshell.iconPath(iconName),
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
    const actions = []
    for (let index = 0; index < notification.actions.length; index++) {
      const action = notification.actions[index]
      if (action.text)
        actions.push({ identifier: action.identifier, text: action.text, sourceIndex: index })
    }

    let urgency = "normal"
    if (notification.urgency === NotificationUrgency.Critical)
      urgency = "critical"
    else if (notification.urgency === NotificationUrgency.Low)
      urgency = "low"

    return {
      id: notification.id,
      tag: tag,
      appName: service.isTeamsNotification(notification) ? "Microsoft Teams" : notification.appName || "",
      appIcon: notification.appIcon || "",
      desktopEntry: notification.desktopEntry || "",
      image: notification.image || "",
      summary: notification.summary || "",
      body: notification.body || "",
      urgency: urgency,
      value: value,
      actions: actions,
      time: Math.floor(Date.now() / 1000),
      expiresAt: service.computeExpiry(notification, urgency)
    }
  }

  function computeExpiry(notification, urgency) {
    if (urgency === "critical" || notification.expireTimeout === 0)
      return 0
    if (notification.expireTimeout > 0)
      return Date.now() + notification.expireTimeout
    return Date.now() + 20000
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
    for (let index = service.popup.length - 1; index >= 0; index--) {
      const record = service.popup[index]
      if (record.expiresAt === 0 || record.expiresAt > service.now || service.hovered[record.id])
        continue
      changed = true
      const notification = service.live[record.id]
      if (notification)
        notification.expire()
      delete service.live[record.id]
      delete service.hovered[record.id]
    }
    if (changed)
      service.syncPopup()
  }

  function syncPopup(suppressRemovalId) {
    const cutoff = Date.now()
    const previousPopup = service.popup
    const candidates = service.history.filter(record => (record.expiresAt === 0 || record.expiresAt > cutoff || service.hovered[record.id]) && service.live[record.id])
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
    return String(record.appName || "Unknown").toLowerCase()
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
    delete service.live[id]
    delete service.hovered[id]
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
      delete service.live[record.id]
      delete service.hovered[record.id]
    }

    service.history = service.history.filter(record => !ids[record.id])
    service.historyGroups = service.groupHistory(service.history)
    service.saveHistory()
    service.syncPopup()
  }

  function clearHistory() {
    for (const id of Object.keys(service.live)) {
      const notification = service.live[id]
      if (notification)
        notification.dismiss()
      delete service.hovered[id]
    }
    service.live = {}
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
    service.tagMap = {}
    service.osdTimer.stop()
    service.osd = null
    service.syncPopup()
  }

  function setDoNotDisturb(enabled) {
    settings.doNotDisturb = enabled
    if (enabled)
      service.clearVisible()
  }

  function setHovered(id, enabled) {
    service.hovered[id] = enabled
  }

  function setRecordsHovered(records, enabled) {
    for (const record of records)
      service.setHovered(record.id, enabled)
  }

  function activateRecord(id) {
    const notification = service.live[id]
    const record = service.history.find(entry => entry.id === id)
    const focused = service.focusRecord(record)

    if (notification) {
      for (let index = 0; index < notification.actions.length; index++) {
        const action = notification.actions[index]
        if (action.identifier === "default") {
          action.invoke()
          return true
        }
      }
    }

    return focused
  }

  function focusRecord(record) {
    const command = service.focusCommand(record)
    if (command.length === 0)
      return false

    service.windowFocus.command = command
    service.windowFocus.startDetached()
    return true
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
    if (notification && index < notification.actions.length) {
      service.focusRecord(service.history.find(entry => entry.id === recordId))
      notification.actions[index].invoke()
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

  function lucideIcon(record) {
    const name = String(record.appName).toLowerCase()
    const mappings = [
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
    const body = String(record.body || "")
    return service.isBrowserIcon(record.appIcon)
      && /(?:^|\n)teams(?:\.cloud)?\.microsoft(?:\.com)?(?:\n|$)/i.test(body)
  }

  function displayBody(record) {
    const body = String(record && record.body || "")
    if (!record || !service.isBrowserIcon(record.appIcon))
      return body

    // Chromium prefixes web notifications with their origin on a separate line.
    return body.replace(/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+[ \t]*(?:\r?\n[ \t]*){2}/i, "")
  }

  function resolveIcon(icon) {
    const source = String(icon || "")
    if (!source)
      return ""
    if (/^(file|image|qrc):/.test(source) || source.startsWith("/"))
      return source
    return Quickshell.iconPath(source, true)
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
    if (!record)
      return { kind: "lucide", source: "bell" }

    const appIcon = service.resolveIcon(record.appIcon)
    const image = service.resolveIcon(record.image)
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

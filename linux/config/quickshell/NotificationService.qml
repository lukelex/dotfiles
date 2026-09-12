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
  signal historyRecordDismissed(string id)

  property Process desktopEntryLauncher: Process {
    command: []
  }

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
      if (record.tag)
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
    settings.historyJson = JSON.stringify(service.history.slice(0, service.historyLimit))
  }

  function handleNotification(notification) {
    if (service.doNotDisturb)
      return

    const hints = notification.hints || {}
    const tag = String(hints["wired-tag"] || "")
    const value = typeof hints["value"] === "number" ? hints["value"] : -1

    if (tag && service.tagMap[tag]) {
      const previous = service.tagMap[tag]
      previous.dismiss()
      delete service.tagMap[tag]
      delete service.live[previous.id]
    }

    notification.tracked = true
    service.live[notification.id] = notification
    if (tag)
      service.tagMap[tag] = notification

    const record = service.buildRecord(notification, tag, value)
    if (service.isSystemOsd(record)) {
      service.osd = record
      service.osdTimer.restart()
      return
    }

    service.addHistory(record)
    if (!service.appendToPopupGroup(record))
      service.syncPopup()
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
    for (let index = 0; index < notification.actions.length; index++)
      actions.push({ identifier: notification.actions[index].identifier, text: notification.actions[index].text })

    let urgency = "normal"
    if (notification.urgency === NotificationUrgency.Critical)
      urgency = "critical"
    else if (notification.urgency === NotificationUrgency.Low)
      urgency = "low"

    return {
      id: notification.id,
      tag: tag,
      appName: notification.appName || "",
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
    if (urgency === "critical")
      return 0
    if (notification.expireTimeout > 0)
      return Date.now() + notification.expireTimeout
    return Date.now() + 3000
  }

  function addHistory(record) {
    const next = service.history.filter(entry => entry.id !== record.id && (record.tag === "" || entry.tag !== record.tag))
    next.unshift(record)
    service.history = next.slice(0, service.historyLimit)
    service.historyGroups = service.groupHistory(service.history)
    service.saveHistory()
  }

  function expireDue() {
    let changed = false
    for (let index = service.popup.length - 1; index >= 0; index--) {
      const record = service.popup[index]
      if (record.urgency === "critical" || record.expiresAt > service.now || service.hovered[record.id])
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

  function syncPopup() {
    const cutoff = Date.now()
    service.popup = service.history.filter(record => (record.urgency === "critical" || record.expiresAt > cutoff) && service.live[record.id]).slice(0, service.popupLimit)
    service.popupReversed = service.popup.slice().reverse()
  }

  function appendToPopupGroup(record) {
    if (service.popup.length >= service.popupLimit)
      return false

    const latestRecord = service.popupReversed[service.popupReversed.length - 1]
    if (!latestRecord || service.appKey(latestRecord) !== service.appKey(record))
      return false
    if (record.time - latestRecord.time > service.popupGroupWindow)
      return false

    service.popup = [record].concat(service.popup)
    service.popupRecordAdded(record)
    return true
  }

  function appKey(record) {
    return String(record.appName || "Unknown").toLowerCase()
  }

  function groupHistory(records) {
    const groups = []
    const groupsByApp = ({})

    for (const record of records) {
      const key = service.appKey(record)
      let group = groupsByApp[key]
      if (!group) {
        group = { key: key, records: [] }
        groupsByApp[key] = group
        groups.push(group)
      }
      group.records.push(record)
    }

    return groups
  }

  function groupPopup(records) {
    const groups = []

    for (const record of records) {
      const previousGroup = groups[groups.length - 1]
      const previousRecord = previousGroup ? previousGroup.records[previousGroup.records.length - 1] : null
      const isConsecutive = previousGroup
        && previousGroup.key === service.appKey(record)
        && record.time - previousRecord.time <= service.popupGroupWindow

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
    service.saveHistory()
    if (!preservePopupLayout)
      service.syncPopup()
  }

  function dismissRecords(records) {
    const ids = ({})

    for (const record of records) {
      ids[record.id] = true
      if (record.tag)
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
    if (notification) {
      for (let index = 0; index < notification.actions.length; index++) {
        const action = notification.actions[index]
        if (action.identifier === "default") {
          action.invoke()
          return true
        }
      }
    }

    const record = service.history.find(entry => entry.id === id)
    if (!record || !record.desktopEntry)
      return false

    service.desktopEntryLauncher.command = ["gtk-launch", record.desktopEntry.replace(/\.desktop$/, "")]
    service.desktopEntryLauncher.startDetached()
    return true
  }

  function invokeAction(recordId, index) {
    const notification = service.live[recordId]
    if (notification && index < notification.actions.length)
      notification.actions[index].invoke()
  }

  function timeAgo(record) {
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
    return ["brave", "chromium", "firefox", "google-chrome", "microsoft-edge"].some(browser => name.includes(browser))
  }

  function resolveIcon(icon) {
    const source = String(icon || "")
    if (!source)
      return ""
    if (source.startsWith("file://") || source.startsWith("/"))
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

  function iconFor(record) {
    const appIcon = service.resolveIcon(record.appIcon)
    const image = service.resolveIcon(record.image)
    const desktopIcon = service.desktopEntryIcon(record.desktopEntry)
    const namedApp = DesktopEntries.heuristicLookup(record.appName)
    const namedAppIcon = namedApp ? service.resolveIcon(namedApp.icon) : ""

    if (appIcon && !service.isBrowserIcon(record.appIcon))
      return { kind: "image", source: appIcon }
    if (image)
      return { kind: "image", source: image }
    if (desktopIcon)
      return { kind: "image", source: desktopIcon }
    if (namedAppIcon)
      return { kind: "image", source: namedAppIcon }
    if (appIcon)
      return { kind: "image", source: appIcon }

    return { kind: "lucide", source: service.lucideIcon(record) }
  }
}

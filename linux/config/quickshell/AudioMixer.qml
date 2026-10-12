pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  id: mixer
  property bool active: false
  property bool loading: false
  property string error: ""
  property string errorTarget: ""
  property string pendingTarget: ""
  property var devices: []
  property var cards: []
  property var targetTokens: []
  property var queue: []
  property var request: ({})
  property bool refreshQueued: false
  property bool received: false
  property ListModel applications: ListModel { dynamicRoles: true }

  function accept(text) {
    try {
      const data = JSON.parse(text)
      if (!Array.isArray(data.devices) || !Array.isArray(data.streams) || !Array.isArray(data.cards))
        throw new Error("Invalid mixer response")
      mixer.devices = data.devices
      mixer.cards = data.cards
      mixer.targetTokens = data.devices.concat(data.streams, data.cards).map(target => target.token)
      const groups = new Map()
      for (const stream of data.streams) {
        if (!groups.has(stream.appKey))
          groups.set(stream.appKey, { key: stream.appKey, name: stream.app, streams: [] })
        groups.get(stream.appKey).streams.push(stream)
      }
      mixer.syncModel(mixer.applications, Array.from(groups.values()))
      mixer.received = true
      if (!mixer.errorTarget && (mixer.error === "Application audio is unavailable." || mixer.error === "Could not read application audio."))
        mixer.error = ""
    } catch (_) {
      mixer.error = "Could not read application audio."
      mixer.errorTarget = ""
    }
  }

  // Preserve surviving delegates and their order, focus and expanded state.
  function syncModel(model, entries) {
    const available = new Map(entries.map(entry => [entry.key || entry.token, entry]))
    for (let i = model.count - 1; i >= 0; i--) {
      if (!available.has(model.get(i).identity))
        model.remove(i)
    }
    for (let i = 0; i < model.count; i++) {
      const entry = available.get(model.get(i).identity)
      const payload = JSON.stringify(entry)
      if (payload !== model.get(i).payload)
        model.setProperty(i, "payload", payload)
      available.delete(model.get(i).identity)
    }
    for (const [identity, entry] of available)
      model.append({ identity, payload: JSON.stringify(entry) })
  }

  function refresh() {
    if (!mixer.active)
      return
    if (snapshot.running || action.running || mixer.queue.length) {
      mixer.refreshQueued = true
      return
    }
    mixer.loading = true
    mixer.refreshQueued = false
    mixer.received = false
    snapshot.running = true
  }

  function change(target, operation, value, extra = {}) {
    const next = Object.assign({ kind: target.kind, token: target.token, operation, value }, extra)
    // Slider edits coalesce against the captured identity, not a later default.
    const key = next.token + ":" + operation + ":" + (next.channel || "")
    const retained = mixer.queue.filter(item => item.key !== key)
    retained.push({ key, request: next })
    mixer.queue = retained
    dispatch.restart()
  }

  function send() {
    if (action.running || snapshot.running || !mixer.queue.length)
      return
    mixer.request = mixer.queue[0].request
    mixer.queue = mixer.queue.slice(1)
    mixer.pendingTarget = mixer.request.token
    mixer.error = ""
    mixer.errorTarget = ""
    action.running = true
  }

  onActiveChanged: {
    if (active)
      refresh()
    else {
      mixer.queue = []
      dispatch.stop()
    }
  }

  property Timer dispatch: Timer { interval: 30; onTriggered: mixer.send() }
  property Timer eventRefresh: Timer { interval: 100; onTriggered: mixer.refresh() }
  property Timer reconciliation: Timer { interval: 5000; repeat: true; running: mixer.active; onTriggered: mixer.refresh() }
  property Process subscription: Process {
    command: ["pactl", "subscribe"]
    running: mixer.active
    stdout: SplitParser {
      onRead: line => {
        if (/(sink-input|source-output|sink|source|card) #/.test(line))
          mixer.eventRefresh.restart()
      }
    }
  }
  property Process snapshot: Process {
    command: ["python3", Quickshell.shellPath("audio-mixer.py")]
    stdout: StdioCollector { onStreamFinished: mixer.accept(this.text) }
    onExited: code => {
      mixer.loading = false
      if (code !== 0 || !mixer.received) {
        mixer.error = "Application audio is unavailable."
        mixer.errorTarget = ""
      }
      if (mixer.queue.length)
        mixer.dispatch.restart()
      else if (mixer.refreshQueued) {
        mixer.refreshQueued = false
        mixer.refresh()
      }
    }
  }
  property Process action: Process {
    command: ["python3", Quickshell.shellPath("audio-mixer.py"), JSON.stringify(mixer.request)]
    stdout: StdioCollector { onStreamFinished: { if (this.text.trim()) mixer.accept(this.text) } }
    stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) mixer.error = this.text.trim() } }
    onExited: code => {
      if (code !== 0) {
        mixer.error = mixer.error || "Could not change audio."
        mixer.errorTarget = mixer.request.token
        mixer.queue = mixer.queue.filter(item => item.request.token !== mixer.request.token)
      }
      mixer.pendingTarget = ""
      if (mixer.queue.length)
        mixer.dispatch.restart()
      else
        mixer.refresh()
    }
  }
}

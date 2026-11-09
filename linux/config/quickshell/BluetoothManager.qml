pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  id: manager
  property bool active: false
  property bool ready: false
  property bool closing: false
  property bool scanning: false
  property var seen: []
  property var prompt: null
  property string pendingPath: ""
  property string pendingAction: ""
  property string resultPath: ""
  property string error: ""
  property string message: ""
  property string scanError: ""
  property int serial: 0
  property int pendingId: 0
  property int scanId: 0

  function send(request) {
    if (!process.running || closing) return
    // PINs/passkeys go through stdin only, never argv, preferences or logs.
    process.write(JSON.stringify(request) + "\n")
  }

  function run(action, path = "") {
    if (!ready || pendingPath || !active) return
    error = ""
    message = ""
    resultPath = path
    pendingPath = path
    pendingAction = action
    pendingId = ++serial
    send({ id: pendingId, action, path })
  }

  function scan() {
    if (!ready || scanning || !active) return
    scanError = ""
    scanId = ++serial
    scanning = true
    seen = []
    send({ id: scanId, action: "scan" })
  }

  function stopScan() { send({ action: "stopScan" }) }
  function cancelPair() { send({ action: "cancel" }) }
  function answer(token, accept, value = "") {
    if (!prompt || prompt.token !== token) return
    send({ action: "reply", token, accept, value })
    prompt = null
  }

  function accept(line) {
    let event
    try { event = JSON.parse(line) } catch (_) { return }
    if (closing || !active) return
    if (event.event === "ready") {
      ready = true
      startup.stop()
    } else if (event.event === "fatal") {
      ready = false
      error = event.error
      resultPath = ""
    } else if (!ready) {
      return
    } else if (event.event === "scan") {
      scanning = event.active === true
      seen = Array.isArray(event.seen) ? event.seen : []
    } else if (event.event === "scanError") {
      scanError = event.error || "Bluetooth discovery could not stop."
    } else if (event.event === "prompt") {
      prompt = event.prompt
    } else if (event.event === "result") {
      if (event.id === scanId) {
        scanError = event.error || ""
      } else if (event.id === pendingId) {
        pendingPath = ""
        pendingAction = ""
        prompt = null
        resultPath = event.path || ""
        error = event.error || ""
        message = error ? "" : event.message || ""
      }
    }
  }

  function start() {
    if (process.running || closing || !active) return
    ready = false
    prompt = null
    pendingPath = ""
    pendingAction = ""
    resultPath = ""
    error = ""
    message = ""
    scanError = ""
    scanning = false
    seen = []
    process.running = true
    startup.restart()
  }

  onActiveChanged: {
    if (active) start()
    else {
      ready = false
      prompt = null
      scanning = false
      startup.stop()
      if (process.running) {
        process.write(JSON.stringify({ action: "shutdown" }) + "\n")
        closing = true
        shutdown.restart()
      }
    }
  }
  property Timer startup: Timer {
    interval: 20000
    onTriggered: {
      manager.error = "Bluetooth helper did not respond. Reopen Bluetooth settings to retry."
      manager.process.running = false
    }
  }
  property Timer shutdown: Timer { interval: 2000; onTriggered: manager.process.running = false }
  property Process process: Process {
    command: ["python3", Quickshell.shellPath("bluetooth-agent.py")]
    stdinEnabled: true
    stdout: SplitParser { onRead: line => manager.accept(line) }
    // Do not forward helper diagnostics or pairing payloads into shell logs.
    stderr: StdioCollector {}
    onExited: {
      const restart = manager.closing && manager.active
      manager.closing = false
      manager.ready = false
      manager.prompt = null
      manager.pendingPath = ""
      manager.pendingAction = ""
      manager.scanning = false
      manager.startup.stop()
      manager.shutdown.stop()
      if (restart) Qt.callLater(manager.start)
      else if (manager.active && !manager.error)
        manager.error = "Bluetooth helper stopped. Reopen Bluetooth settings to retry."
    }
  }
}

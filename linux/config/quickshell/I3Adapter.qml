pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

Scope {
  id: root
  required property var controller
  readonly property bool hyprlandSession: controller.hyprlandSession
  property bool resizeMode: false
  property int resizeModeRevision: 0
  property string i3Layout: ""
  property string i3LayoutFocusId: ""
  property int i3LayoutRevision: 0
  readonly property string currentLayoutName: i3Layout
  readonly property string focusedMonitorName: I3.focusedMonitor?.name ?? ""
  readonly property int focusedWorkspaceNumber: I3.workspaces.values.find(workspace => workspace.focused)?.number ?? 0

  function workspaceFor(number) {
    return I3.workspaces.values.find(workspace => workspace.number === number) ?? null
  }
  function activateWorkspace(number, workspace) {
    if (workspace) workspace.activate()
    else if (number > 0) I3.dispatch("workspace " + number)
  }
  function isOccupied(workspace) {
    const tree = workspace.lastIpcObject
    return !!(tree?.nodes?.length || tree?.floating_nodes?.length)
  }
  function refreshLayout() { root.refreshI3Layout() }

  Connections {
    target: I3
    function onConnected() {
      if (!root.hyprlandSession)
        I3.refreshWorkspaces()
      root.refreshI3Layout()
    }
    function onRawEvent(event) {
      if (root.hyprlandSession || !event)
        return
      // i3 emits workspace events on focus changes; layout toggles do not, so
      // the binding pokes the bar through refreshLayout.
      if (event.type === "workspace")
        root.refreshI3Layout()
    }
  }

  // I3.rawEvent only receives workspace/output events; the mode and binding
  // subscriptions need their own listener.
  I3IpcListener {
    subscriptions: root.hyprlandSession ? [] : ["mode", "binding"]
    onIpcEvent: event => {
      root.handleI3ModeEvent(event)
      root.handleI3BindingEvent(event)
    }
  }

  function handleI3ModeEvent(event) {
    if (root.hyprlandSession)
      return
    if (event.type === "subscribe") {
      // Query only after subscribing; newer mode events take precedence over the result.
      if (!i3BindingState.running) {
        i3BindingState.revision = root.resizeModeRevision
        i3BindingState.running = true
      }
    } else if (event.type === "mode") {
      try {
        const mode = JSON.parse(event.data).change
        if (typeof mode === "string") {
          root.resizeModeRevision++
          root.resizeMode = mode === "resize"
        }
      } catch (error) {
        console.warn("Invalid i3 mode event:", error)
      }
    }
  }

  // i3 fires the binding event the moment a configured keybinding starts
  // running — long before the get_tree poll notices the new layout — so the
  // OSD can flash immediately instead of waiting up to a second.
  function handleI3BindingEvent(event) {
    if (root.hyprlandSession || !event || event.type !== "binding")
      return
    try {
      const payload = JSON.parse(event.data)
      if (payload.change !== "run")
        return
      const command = payload.binding && payload.binding.command
      if (typeof command !== "string")
        return
      const predicted = root.layoutFromBindingCommand(command)
      if (predicted) {
        root.controller.maybeShowLayoutOsd(predicted)
        root.refreshI3Layout()
      }
    } catch (error) {
      console.warn("Invalid i3 binding event:", error)
    }
  }

  function layoutFromBindingCommand(command) {
    const cmd = String(command || "").trim()
    if (cmd === "layout stacking" || cmd.startsWith("layout stacking,"))
      return "stacked"
    if (cmd === "layout tabbed" || cmd.startsWith("layout tabbed,"))
      return "tabbed"
    // Toggle-split only has a certain outcome when the current layout is a split.
    if ((cmd === "layout toggle split" || cmd === "split toggle"
         || cmd.startsWith("layout toggle split,") || cmd.startsWith("split toggle,"))
        && (root.i3Layout === "splith" || root.i3Layout === "splitv"))
      return root.i3Layout === "splitv" ? "splith" : "splitv"
    return ""
  }

  function applyI3BindingState(data, revision) {
    if (root.hyprlandSession || revision !== root.resizeModeRevision)
      return
    try {
      const mode = JSON.parse(data).name
      if (typeof mode === "string")
        root.resizeMode = mode === "resize"
    } catch (error) {
      console.warn("Invalid i3 binding state:", error)
    }
  }

  Process {
    id: i3BindingState

    property int revision: 0
    command: ["i3-msg", "-t", "get_binding_state"]
    stdout: StdioCollector {
      onStreamFinished: root.applyI3BindingState(text, i3BindingState.revision)
    }
  }

  function refreshI3Layout() {
    if (root.hyprlandSession || i3LayoutQuery.running)
      return
    root.i3LayoutRevision++
    i3LayoutQuery.revision = root.i3LayoutRevision
    i3LayoutQuery.running = true
  }

  function applyI3Layout(data, revision) {
    if (root.hyprlandSession || revision !== root.i3LayoutRevision)
      return
    try {
      const tree = JSON.parse(data)
      const focused = root.i3FocusedNode(tree, null)
      const layout = root.i3LayoutFromTree(tree)
      const focusId = focused && focused.node.id !== undefined ? String(focused.node.id) : ""
      const focusChanged = focusId !== root.i3LayoutFocusId
      const layoutChanged = layout !== root.i3Layout
      root.i3Layout = layout
      root.i3LayoutFocusId = focusId
      // The poll also picks up incidental layout differences when focus moves
      // between windows, containers, or workspaces; only emit the OSD when the
      // focused node is unchanged, i.e. an active layout command ran.
      if (layoutChanged && !focusChanged)
        root.controller.maybeShowLayoutOsd(layout)
      else
        root.controller.armLayoutOsd(layout)
    } catch (error) {
      console.warn("Invalid i3 layout tree:", error)
    }
  }

  function i3FocusedNode(node, parent) {
    if (node.focused)
      return { node, parent }
    for (const child of node.nodes || []) {
      const found = root.i3FocusedNode(child, node)
      if (found)
        return found
    }
    return null
  }

  function i3LayoutFromTree(data) {
    const tree = typeof data === "string" ? JSON.parse(data) : data
    const focused = root.i3FocusedNode(tree, null)
    if (!focused)
      return ""
    // i3 applies layout to the container holding the focused one; an empty
    // focused workspace is itself the container.
    const container = focused.node.type === "workspace" ? focused.node : focused.parent
    return container && container.layout ? container.layout : ""
  }

  Process {
    id: i3LayoutQuery

    property int revision: 0
    command: ["i3-msg", "-t", "get_tree"]
    stdout: StdioCollector {
      onStreamFinished: root.applyI3Layout(text, i3LayoutQuery.revision)
    }
  }

  // i3 emits no layout event, so the icon is kept in sync with the user's own
  // binds by a quiet poll; the binding event above only flashes the OSD early
  // and re-queries. The poke and workspace events only speed up Hyprland and
  // focus changes.
  Timer {
    id: i3LayoutPoll
    interval: 1000
    repeat: true
    running: !root.hyprlandSession
    onTriggered: root.refreshI3Layout()
  }

  Component.onCompleted: root.refreshLayout()
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
  id: root
  required property var controller
  readonly property bool hyprlandSession: controller.hyprlandSession
  property bool resizeMode: false
  property int resizeModeRevision: 0
  property bool hyprlandModeInitialized: false
  property bool hyprlandLayoutInitialized: false
  property string hyprlandLayout: ""
  property int layoutRevision: 0
  readonly property string currentLayoutName: hyprlandLayout
  readonly property string focusedMonitorName: Hyprland.focusedMonitor?.name ?? ""
  readonly property int focusedWorkspaceNumber: Hyprland.workspaces.values.find(workspace => workspace.focused)?.id ?? 0

  function workspaceFor(number) {
    return Hyprland.workspaces.values.find(workspace => workspace.id === number) ?? null
  }
  function activateWorkspace(number, workspace) {
    if (workspace) workspace.activate()
    else if (number > 0) Hyprland.dispatch("workspace " + number)
  }
  function isOccupied(workspace) {
    return workspace.toplevels.values.length > 0
  }
  function refreshLayout() { root.refreshHyprlandLayout() }

  function refreshHyprlandSubmap() {
    // The first focused monitor arrives after native IPC initialization. On reload
    // it already exists, so Component.onCompleted restores the current submap.
    if (!root.hyprlandSession || !Hyprland.focusedMonitor || hyprlandSubmap.running)
      return
    hyprlandSubmap.revision = root.resizeModeRevision
    hyprlandSubmap.running = true
  }

  function handleHyprlandEvent(event) {
    if (!root.hyprlandSession)
      return
    if (event.name === "activespecial" || event.name === "activespecialv2") {
      Hyprland.refreshMonitors()
    } else if (event.name === "submap") {
      root.resizeModeRevision++
      root.resizeMode = String(event.data || "") === "resize"
      root.hyprlandModeInitialized = true
    } else if (event.name === "configreloaded") {
      root.refreshHyprlandSubmap()
      root.refreshHyprlandLayout()
      root.controller.preferences.applySection("input")
    }
  }

  function applyHyprlandSubmap(data, revision) {
    if (!root.hyprlandSession || revision !== root.resizeModeRevision)
      return
    try {
      // hyprctl -j submap returns a JSON string, not an object.
      const mode = JSON.parse(data)
      if (typeof mode === "string") {
        root.resizeMode = mode === "resize"
        root.hyprlandModeInitialized = true
      }
    } catch (error) {
      console.warn("Invalid Hyprland submap state:", error)
    }
  }

  Process {
    id: hyprlandSubmap

    property int revision: 0
    command: ["hyprctl", "-j", "submap"]
    stdout: StdioCollector {
      onStreamFinished: root.applyHyprlandSubmap(text, hyprlandSubmap.revision)
    }
  }

  function refreshHyprlandLayout() {
    // Like the submap query, wait for the first focused monitor, which arrives
    // after native IPC initialization; config reloads and the IPC handler retry.
    if (!root.hyprlandSession || !Hyprland.focusedMonitor || hyprlandLayout.running)
      return
    root.layoutRevision++
    hyprlandLayout.revision = root.layoutRevision
    hyprlandLayout.running = true
  }

  function applyHyprlandLayout(data, revision) {
    if (!root.hyprlandSession || revision !== root.layoutRevision)
      return
    try {
      const option = JSON.parse(data)
      if (typeof option.str === "string" && option.str !== root.hyprlandLayout) {
        root.hyprlandLayout = option.str
        root.hyprlandLayoutInitialized = true
        // general:layout only changes when a layout command runs, never on
        // focus or workspace navigation, so every change is an active switch.
        root.controller.maybeShowLayoutOsd(option.str)
      }
    } catch (error) {
      console.warn("Invalid Hyprland layout state:", error)
    }
  }

  Process {
    id: hyprlandLayout

    property int revision: 0
    command: ["hyprctl", "-j", "getoption", "general:layout"]
    stdout: StdioCollector {
      onStreamFinished: root.applyHyprlandLayout(text, hyprlandLayout.revision)
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) { root.handleHyprlandEvent(event) }
    function onFocusedMonitorChanged() {
      if (!Hyprland.focusedMonitor) {
        root.hyprlandModeInitialized = false
        root.hyprlandLayoutInitialized = false
        root.layoutRevision++
        root.resizeModeRevision++
        root.resizeMode = false
        root.hyprlandLayout = ""
        return
      }
      if (!root.hyprlandModeInitialized) Hyprland.refreshWorkspaces()
      if (!root.hyprlandModeInitialized)
        root.refreshHyprlandSubmap()
      if (!root.hyprlandLayoutInitialized)
        root.refreshHyprlandLayout()
    }
  }

  Component.onCompleted: {
    root.refreshHyprlandSubmap()
    root.refreshHyprlandLayout()
  }
}

pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

QtObject {
  id: service

  readonly property var cameraNodes: Pipewire.nodes.values.filter(node => node.type === PwNodeType.VideoSource)
  readonly property var cameraLinks: Pipewire.linkGroups.values.filter(group => service.isCamera(group.source))
  readonly property bool inUse: directInUse || cameraLinks.some(group => group.state === PwLinkState.Active)
  property bool directInUse: false

  function isCamera(node) {
    if (node.type !== PwNodeType.VideoSource)
      return false
    const properties = node.properties || {}
    return properties["device.api"] === "v4l2" || properties["device.api"] === "libcamera"
      || !!properties["api.v4l2.path"] || !!properties["api.libcamera.path"]
  }

  // Metadata/link subscriptions do not create a capture stream.
  readonly property PwObjectTracker tracker: PwObjectTracker {
    objects: service.cameraNodes.concat(service.cameraLinks)
  }

  // Direct V4L2 users (including browsers on X11) do not appear in PipeWire.
  readonly property Process directAccess: Process {
    command: ["python3", Quickshell.env("HOME") + "/dotfiles/linux/config/quickshell/scripts/webcam-status.py"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: service.directInUse = this.text.trim() === "active"
    }
  }

  readonly property Timer poll: Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      if (!service.directAccess.running)
        service.directAccess.running = true
    }
  }
}

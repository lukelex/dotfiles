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
  property var directUsage: []
  readonly property var directApplications: directUsage.map(entry => entry.name)
  readonly property bool directInUse: directApplications.length > 0
  readonly property var recordingApplications: service.collectRecordingApplications(service.cameraLinks, service.directApplications)
  readonly property var applicationDevices: service.collectApplicationDevices(service.cameraLinks, service.directUsage)

  function collectApplicationDevices(groups, direct) {
    const applications = new Map()
    function add(name, path, description) {
      if (!applications.has(name))
        applications.set(name, new Map())
      applications.get(name).set(path || description, description !== path && path
        ? description + " · " + path : description)
    }
    for (const entry of direct)
      add(entry.name, entry.devicePath, entry.deviceName)
    for (const group of groups) {
      if (group.state !== PwLinkState.Active || !service.isCamera(group.source))
        continue
      const stream = group.target
      const properties = stream.properties || {}
      const name = properties["application.name"] || properties["application.process.binary"]
        || stream.description || stream.name || "Unknown application"
      const camera = group.source
      const metadata = camera.properties || {}
      const path = metadata["api.v4l2.path"] || metadata["api.libcamera.path"] || ""
      const description = camera.description || metadata["node.description"]
        || metadata["device.description"] || camera.name || path || "Unknown webcam"
      add(name, path, description)
    }
    const details = Object.create(null)
    for (const [name, devices] of applications)
      details[name] = Array.from(devices.values()).sort().join("\n")
    return details
  }

  function collectRecordingApplications(groups, direct) {
    const names = new Set(direct)
    for (const group of groups) {
      if (group.state !== PwLinkState.Active || !service.isCamera(group.source))
        continue
      const stream = group.target
      const properties = stream.properties || {}
      names.add(properties["application.name"] || properties["application.process.binary"]
        || stream.description || stream.name || "Unknown application")
    }
    return Array.from(names).sort((left, right) => left.localeCompare(right))
  }

  function isCamera(node) {
    if (node.type !== PwNodeType.VideoSource)
      return false
    const properties = node.properties || {}
    return properties["device.api"] === "v4l2" || properties["device.api"] === "libcamera"
      || !!properties["api.v4l2.path"] || !!properties["api.libcamera.path"]
  }

  // Metadata/link subscriptions do not create a capture stream.
  readonly property PwObjectTracker tracker: PwObjectTracker {
    objects: service.cameraNodes.concat(service.cameraLinks, service.cameraLinks.map(group => group.target))
  }

  // Direct V4L2 users (including browsers on X11) do not appear in PipeWire.
  readonly property Process directAccess: Process {
    command: ["python3", Quickshell.env("HOME") + "/dotfiles/linux/config/quickshell/scripts/webcam-status.py"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const usage = JSON.parse(this.text)
          service.directUsage = Array.isArray(usage)
            ? usage.filter(entry => entry && typeof entry.name === "string" && entry.name.length > 0
              && typeof entry.devicePath === "string" && typeof entry.deviceName === "string") : []
        } catch (error) {
          service.directUsage = []
        }
      }
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

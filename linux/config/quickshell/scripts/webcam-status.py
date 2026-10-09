"""Observe open webcam descriptors without opening a camera or requesting capture."""

import json
import os
from pathlib import Path


def usage(sysfs=Path("/sys/class/video4linux"), proc=Path("/proc")):
  devices = {}
  for node in sysfs.glob("video*"):
    try:
      # UVC webcams expose capture at index 0 and metadata at index 1.
      # Ignore metadata-only access, which does not use the camera image.
      if (node / "index").read_text().strip() == "0":
        device = "/dev/" + node.name
        try:
          devices[device] = (node / "name").read_text().strip() or device
        except OSError:
          devices[device] = device
    except OSError:
      continue
  if not devices:
    return []

  users = set()
  for process in proc.iterdir():
    if not process.name.isdigit():
      continue
    try:
      for descriptor in (process / "fd").iterdir():
        try:
          device = os.readlink(descriptor)
          if device in devices:
            users.add((process_name(process), device))
        except OSError:
          continue
    except OSError:
      # Processes can exit during the scan; other users may be inaccessible.
      continue
  return [{"name": name, "devicePath": device, "deviceName": devices[device]}
          for name, device in sorted(users)]


def applications(sysfs=Path("/sys/class/video4linux"), proc=Path("/proc")):
  return sorted({entry["name"] for entry in usage(sysfs, proc)}, key=str.casefold)


def process_name(process):
  try:
    return Path(os.readlink(process / "exe")).name.removesuffix(" (deleted)")
  except OSError:
    pass
  try:
    command = (process / "cmdline").read_bytes().split(b"\0")[0]
    if command:
      # Chromium can rewrite argv[0] to include its child-process arguments.
      return Path(os.fsdecode(command).split(" --", 1)[0]).name
  except OSError:
    pass
  try:
    return (process / "comm").read_text().strip() or "Unknown application"
  except OSError:
    return "Unknown application"


def in_use(sysfs=Path("/sys/class/video4linux"), proc=Path("/proc")):
  return bool(applications(sysfs, proc))


if __name__ == "__main__":
  print(json.dumps(usage()))

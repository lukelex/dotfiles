"""Observe open webcam descriptors without opening a camera or requesting capture."""

import os
from pathlib import Path


def in_use(sysfs=Path("/sys/class/video4linux"), proc=Path("/proc")):
  devices = set()
  for node in sysfs.glob("video*"):
    try:
      # UVC webcams expose capture at index 0 and metadata at index 1.
      # Ignore metadata-only access, which does not use the camera image.
      if (node / "index").read_text().strip() == "0":
        devices.add("/dev/" + node.name)
    except OSError:
      continue
  if not devices:
    return False

  for process in proc.iterdir():
    if not process.name.isdigit():
      continue
    try:
      for descriptor in (process / "fd").iterdir():
        try:
          if os.readlink(descriptor) in devices:
            return True
        except OSError:
          continue
    except OSError:
      # Processes can exit during the scan; other users may be inaccessible.
      continue
  return False


if __name__ == "__main__":
  print("active" if in_use() else "idle")

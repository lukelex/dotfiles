#!/usr/bin/env python3
"""USB storage inventory and udiskie lifecycle for System Settings."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

DIRECTORY = Path(__file__).resolve().parent
SETTINGS = DIRECTORY / "settings.py"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"dotfiles-usb-storage-{os.getuid()}"
PIDFILE = RUNTIME.with_suffix(".pid")


def run(args, timeout=15):
  return subprocess.run(args, check=True, capture_output=True, text=True, timeout=timeout)


def automount_preference():
  data = json.loads(run([sys.executable, str(SETTINGS), "get"]).stdout)
  return bool(data["storage"]["usbAutomount"])


def pid():
  try:
    value = int(PIDFILE.read_text())
    os.kill(value, 0)
    return value
  except (OSError, ValueError):
    PIDFILE.unlink(missing_ok=True)
    return None


def start_automount():
  if pid():
    return
  RUNTIME.parent.mkdir(parents=True, exist_ok=True)
  process = subprocess.Popen(["udiskie", "-a"], stdin=subprocess.DEVNULL,
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
  PIDFILE.write_text(str(process.pid))


def stop_automount():
  process_id = pid()
  if process_id:
    os.kill(process_id, signal.SIGTERM)
    for _ in range(20):
      try:
        os.kill(process_id, 0)
      except ProcessLookupError:
        break
      time.sleep(0.05)
    else:
      os.kill(process_id, signal.SIGKILL)
  PIDFILE.unlink(missing_ok=True)


def snapshot():
  result = run(["lsblk", "--json", "--bytes", "--output", "NAME,PATH,TYPE,TRAN,RM,HOTPLUG,LABEL,FSTYPE,SIZE,MOUNTPOINTS"])
  devices = []
  for disk in json.loads(result.stdout).get("blockdevices", []):
    if disk.get("type") != "disk" or disk.get("tran") != "usb":
      continue
    volumes = []
    for part in disk.get("children", []):
      if part.get("type") not in ("part", "crypt", "lvm"):
        continue
      mounts = [mount for mount in (part.get("mountpoints") or []) if mount]
      volumes.append({"path": part.get("path", ""), "name": part.get("label") or Path(part.get("path", "volume")).name,
        "filesystem": part.get("fstype") or "Unknown format", "size": part.get("size") or 0, "mounts": mounts})
    devices.append({"id": disk.get("path", disk.get("name")), "name": disk.get("label") or disk.get("name") or "USB drive",
      "size": disk.get("size") or 0, "volumes": volumes})
  fstab = json.loads(run(["findmnt", "--fstab", "--json", "--output", "SOURCE,TARGET,FSTYPE"]).stdout).get("filesystems", [])
  mounted = {}

  def index_mounts(entries):
    for entry in entries:
      if entry.get("fstype") != "autofs":
        mounted[entry.get("target")] = entry
      index_mounts(entry.get("children", []))

  index_mounts(json.loads(run(["findmnt", "--json", "--output", "SOURCE,TARGET,FSTYPE"]).stdout).get("filesystems", []))
  system_mounts = ("/", "/boot", "/efi", "/home", "/usr", "/var", "/etc", "/opt")
  fstab_mounts = []
  for entry in fstab:
    target = entry.get("target", "")
    fstype = entry.get("fstype", "")
    active = mounted.get(target)
    if not active or not target or target == "/" or any(target == root or target.startswith(root + "/") for root in system_mounts[1:]):
      continue
    if fstype in ("swap", "none", "proc", "sysfs", "tmpfs", "devtmpfs", "cgroup", "cgroup2", "overlay"):
      continue
    fstab_mounts.append({"source": active.get("source") or entry.get("source", "Unknown source"),
      "target": target, "filesystem": active.get("fstype") or fstype})
  print(json.dumps({"devices": devices, "fstabMounts": fstab_mounts, "automount": automount_preference()}))


def main():
  action = sys.argv[1] if len(sys.argv) > 1 else "snapshot"
  if action == "startup":
    if automount_preference(): start_automount()
    return
  if action == "snapshot":
    snapshot()
    return
  if action == "automount":
    enabled = sys.argv[2] == "on"
    run([sys.executable, str(SETTINGS), "set", "storage.usbAutomount", "true" if enabled else "false"])
    if enabled:
      start_automount()
      # Enabling applies to devices already connected as well as future arrivals.
      for device in json.loads(run(["lsblk", "--json", "--tree", "--output", "PATH,TYPE,TRAN"]).stdout).get("blockdevices", []):
        if device.get("type") != "disk" or device.get("tran") != "usb":
          continue
        for volume in device.get("children", []):
          if volume.get("type") == "part":
            subprocess.run(["udisksctl", "mount", "--block-device", volume["path"]], capture_output=True, text=True, timeout=30)
    else:
      stop_automount()
    return
  if action in ("mount", "unmount") and len(sys.argv) == 3:
    command = "mount" if action == "mount" else "unmount"
    print(run(["udisksctl", command, "--block-device", sys.argv[2]], timeout=45).stdout.strip())
    return
  if action == "unmount-fstab" and len(sys.argv) == 3:
    print(run(["umount", "--", sys.argv[2]], timeout=45).stdout.strip() or "Unmounted " + sys.argv[2])
    return
  raise ValueError("Usage: usb-storage.py snapshot|startup|automount on|off|mount|unmount DEVICE")


if __name__ == "__main__":
  try:
    main()
  except (OSError, ValueError, subprocess.SubprocessError, KeyError, json.JSONDecodeError) as error:
    print(str(error), file=sys.stderr)
    raise SystemExit(1)

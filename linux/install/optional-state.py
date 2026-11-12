#!/usr/bin/env python3
"""Transfer only known optional ownership records before core reconciliation.

dotpkg v1 state has no ownership-transfer command. Match its advisory locks,
retain complete backups, write destinations durably before removing the source,
and accept identical duplicates on retry after an interrupted transfer.

Verified against lukelex/dotpkg commit
a654a1a7f7ef330f04ddf7b1204a9223f18e93a3 (clean local source checkout):
  internal/state/state.go: CurrentVersion, managed lists, RemoteBundles
  internal/state/service_tracking.go: top-level service_tracking map
  internal/reconcile/lock.go: StatePath + ".lock", flock(EX | NB)
  internal/recovery/journal.go: StatePath + ".journal.yaml"
  internal/reconcile/sync.go: Recover, packageFailure, rollback
These are internal formats, so unknown versions fail instead of being guessed.
"""

import contextlib
import copy
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


INSTALL = Path(__file__).resolve().parent
CONFIG = "linux/config/openeffects/openeffectsd.service.d/autostart.conf:$XDG_CONFIG_HOME/systemd/user/openeffectsd.service.d/autostart.conf"
OLD_CONFIG = "linux/config/openeffects/state.toml:$XDG_CONFIG_HOME/openeffects/state.toml"
SERVICE = "user:openeffectsd.service"


def load(path):
  if path.is_symlink():
    raise ValueError(f"State path is a symlink: {path}; resolve its ownership manually before migration")
  if not path.exists():
    return {"version": 1, "current": {}, "managed": {}}
  value = json.loads(subprocess.check_output([str(INSTALL / "yq"), "-o=json", ".", str(path)]))
  if not isinstance(value, dict) or value.get("version") != 1:
    raise ValueError(f"Unsupported state version in {path}; upgrade/migrate with dotpkg before retrying")
  if not isinstance(value.get("managed"), dict):
    raise ValueError(f"Invalid managed state in {path}")
  managed = value["managed"]
  for key in ("configs", "services"):
    if key in managed and (not isinstance(managed[key], list) or not all(isinstance(item, str) for item in managed[key])):
      raise ValueError(f"Invalid managed.{key} in {path}")
  if not isinstance(managed.get("remote_bundles", {}), dict) or not isinstance(value.get("service_tracking", {}), dict):
    raise ValueError(f"Invalid bundle or service tracking in {path}")
  return value


def transfer(core, skills, effects):
  managed = core["managed"]
  bundles = managed.get("remote_bundles", {})
  if "grill-me" in bundles:
    target = skills["managed"].setdefault("remote_bundles", {})
    if "grill-me" in target and target["grill-me"] != bundles["grill-me"]:
      raise ValueError("Conflicting grill-me ownership; preserve both state files and resolve before retrying")
    target["grill-me"] = bundles.pop("grill-me")
  for key, names in (("configs", (CONFIG, OLD_CONFIG)), ("services", (SERVICE,))):
    source = managed.get(key, [])
    if not isinstance(source, list):
      raise ValueError(f"Invalid managed.{key}")
    for name in names:
      if name in source:
        destination = effects["managed"].setdefault(key, [])
        if name not in destination:
          destination.append(name)
        source.remove(name)
  tracking = core.get("service_tracking", {})
  if SERVICE in tracking:
    target = effects.setdefault("service_tracking", {})
    if SERVICE in target and target[SERVICE] != tracking[SERVICE]:
      raise ValueError("Conflicting OpenEffects service tracking; resolve before retrying")
    target[SERVICE] = tracking.pop(SERVICE)


def sync_directory(path):
  directory = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
  try:
    os.fsync(directory)
  finally:
    os.close(directory)


def write(path, data):
  # JSON is a YAML subset accepted by dotpkg; its next write restores YAML.
  fd, name = tempfile.mkstemp(prefix=".optional-state-", dir=path.parent)
  try:
    with os.fdopen(fd, "w") as stream:
      json.dump(data, stream, indent=2)
      stream.write("\n")
      stream.flush()
      os.fsync(stream.fileno())
    os.replace(name, path)
    sync_directory(path.parent)
  finally:
    if os.path.exists(name):
      os.unlink(name)


def check_recovery(paths):
  for path in paths:
    journal = Path(str(path) + ".journal.yaml")
    # Even a completed, malformed or dangling journal needs review/cleanup
    # by dotpkg. Do not infer that it is safe to discard its recovery state.
    if os.path.lexists(journal):
      raise ValueError(
        f"Recovery journal exists: {journal}. Ownership was not transferred. "
        f"Review and resolve it with dotpkg recover --state-file {path} "
        "using the matching manifest before retrying; do not delete the journal to bypass this check."
      )


def main():
  preview = "--dry-run" in sys.argv or "--check" in sys.argv
  root = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "dotpkg"
  paths = [root / "state.yaml", root / "optional-skills" / "state.yaml", root / "optional-effects" / "state.yaml"]
  check_recovery(paths)
  if not paths[0].exists():
    return 0
  with contextlib.ExitStack() as stack:
    if not preview:
      for path in sorted(paths):
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(str(path) + ".lock", os.O_CREAT | os.O_RDWR, 0o600)
        lock = stack.enter_context(os.fdopen(fd, "w"))
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    # A sync might have created a journal between the initial check and lock
    # acquisition. All three ownership states must be clear of recovery.
    check_recovery(paths)
    originals = [load(path) for path in paths]
    updated = copy.deepcopy(originals)
    transfer(*updated)
    if originals == updated:
      return 0
    if preview:
      print("Optional ownership migration required; no state was changed. Run python3 linux/install/optional-state.py explicitly, then retry. If migration reports conflicting state, retain both files and inspect the conflict before proceeding; do not run direct dotpkg sync/clean against the core manifest yet.")
      return 3
    backup = Path(tempfile.mkdtemp(prefix="optional-state-backup-", dir=root))
    for index, path in enumerate(paths):
      if path.exists():
        # Retain original bytes, including unknown fields and comments.
        with open(backup / f"{index}-{path.parent.name}.yaml", "xb") as stream:
          os.chmod(stream.name, 0o600)
          stream.write(path.read_bytes())
          stream.flush()
          os.fsync(stream.fileno())
    # Persist both the saved file entries and the backup directory entry
    # before replacing any ownership state.
    sync_directory(backup)
    sync_directory(root)
    print(f"Optional ownership backup retained: {backup}")
    # Never drop ownership before its new owner has been saved. If interrupted,
    # identical records are safe to transfer again on the next wrapper run.
    for index in (1, 2, 0):
      if originals[index] != updated[index]:
        write(paths[index], updated[index])
    return 0


if __name__ == "__main__":
  try:
    sys.exit(main())
  except (OSError, ValueError, subprocess.CalledProcessError) as error:
    print(f"Optional ownership migration failed: {error}", file=sys.stderr)
    sys.exit(1)

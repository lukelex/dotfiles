#!/usr/bin/env python3
"""Exercise filesystem ownership and failure recovery in a disposable sandbox."""
import copy
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]


def put(path, text, executable=False):
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(text)
  if executable:
    path.chmod(0o700)


with tempfile.TemporaryDirectory(prefix="installer-reliability-") as temporary:
  base = Path(temporary)
  root = base / "repo"
  install = root / "linux/install"
  shutil.copytree(REPO / "linux/install", install)
  shutil.copytree(REPO / "linux/vendor/yq", root / "linux/vendor/yq")
  scripts = root / "linux/scripts"
  scripts.mkdir()
  home = base / "home"
  home.mkdir()
  bin_dir = base / "bin"
  put(bin_dir / "sudo", '''#!/bin/bash
if [ -n "${SUDO_LOG:-}" ]; then printf '%s\\n' "$1" >> "$SUDO_LOG"; fi
if [ "$1" = "${FAIL_SUDO_CMD:-}" ]; then exit 71; fi
case "$1" in mkdir|ln|mv|install|mktemp|rm) exec "$@" ;; *) exit 0 ;; esac
''', True)
  for name in ("dotpkg", "quickshell", "fc-cache", "timedatectl", "tldr", "rustup", "update-desktop-database", "chsh"):
    put(bin_dir / name, "#!/bin/bash\nexit 0\n", True)
  put(bin_dir / "systemctl", '#!/bin/bash\necho session-check >> "$TEST_LOG"\nexit 1\n', True)
  put(bin_dir / "xset", '#!/bin/bash\necho xset >> "$TEST_LOG"\nexit 1\n', True)
  env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
             PATH=f"{bin_dir}:{os.environ['PATH']}", TEST_LOG=str(base / "log"),
             DOTPKG_WIZARD="1", DOTPKG_INPUT_SHELL="keep", DOTPKG_INPUT_TIMEZONE="UTC")
  env.pop("DISPLAY", None)
  env.pop("WAYLAND_DISPLAY", None)
  # Rewrite only the fixture's absolute system targets; real privileged paths
  # cannot be reached by these tests, even if a stub is accidentally omitted.
  for name in ("binaries", "verify", "configs-system"):
    path = install / name
    text = path.read_text()
    for prefix in ("/usr/local/bin", "/usr/share", "/etc"):
      text = text.replace(prefix, str(base / "system" / prefix.lstrip("/")))
    path.write_text(text)
  put(root / "linux/variables.env", 'XDG_CONFIG_HOME="$HOME/.config"\n')

  def run(name, *args, ok=True, extra=None):
    command = ["python3" if name.endswith(".py") else "bash", str(install / name), *args]
    result = subprocess.run(command, env=env | (extra or {}), text=True, capture_output=True)
    assert (result.returncode == 0) == ok, (name, result.returncode, result.stdout, result.stderr)
    return result

  helpers = base / "system/usr/local/bin"
  helpers.mkdir(parents=True)
  put(scripts / "has spaces", "#!/bin/bash\n", True)
  (scripts / "directory").mkdir()
  put(helpers / "u_has spaces", "user owned")
  (helpers / "u_obsolete").symlink_to(scripts / "obsolete")
  (helpers / "u_foreign").symlink_to(base / "missing")
  # A wrong basename under our scripts directory is not installer ownership.
  (helpers / "u_wrong").symlink_to(scripts / "other")
  run("binaries", ok=False)
  assert (helpers / "u_has spaces").read_text() == "user owned"
  assert not (helpers / "u_obsolete").is_symlink()
  assert (helpers / "u_foreign").is_symlink() and (helpers / "u_wrong").is_symlink()
  run("binaries", "--replace")
  assert (helpers / "u_has spaces").resolve() == scripts / "has spaces"
  assert next(helpers.glob(".dotfiles-backup-*/u_has spaces")).read_text() == "user owned"
  assert not (helpers / "u_directory").exists()

  service = home / ".config/systemd/user/quickshell.service"
  put(service, "fixture")
  for name in ("dotfiles-idle", "dotfiles-lock"):
    source = root / f"linux/config/session/{name}.service"
    put(source, "fixture")
    (service.parent / f"{name}.service").symlink_to(source)
  run("verify")
  assert not (base / "log").exists()
  run("verify", "--session", ok=False)
  (helpers / "u_has spaces").unlink()
  (helpers / "u_has spaces").symlink_to(bin_dir / "dotpkg")
  result = run("verify", ok=False)
  assert "points to" in result.stderr

  config = root / "linux/config"
  for name in ("tmpfiles.d/platform-profile.conf", "ly.ini", "nwg-hello/nwg-hello.json", "nwg-hello/nwg-hello.css"):
    put(config / name, "repo config")
  put(root / "linux/devices/pointers.conf", "pointers")
  put(root / "linux/system/system-sleep/90-bluetooth-resume", "bluetooth")
  etc = base / "system/etc"
  wifi = etc / "NetworkManager/conf.d/wifi_backend.conf"
  put(wifi, "user backend")
  theme = etc / "nwg-hello/nwg-hello.css"
  put(theme, "user theme")
  run("configs-system", ok=False)
  assert wifi.read_text() == "user backend" and theme.read_text() == "user theme"
  run("configs-system", "--replace")
  assert theme.read_text() == "repo config"
  assert next(theme.parent.glob(".dotfiles-backup-*/nwg-hello.css")).read_text() == "user theme"
  wifi.unlink()
  wifi.symlink_to(config / "network-manager.conf")
  run("configs-system")
  assert not wifi.is_symlink()
  wifi.symlink_to(base / "foreign-network-config")
  run("configs-system")
  assert wifi.is_symlink()

  # Call the installer functions in an `if`, deliberately disabling errexit
  # throughout their bodies. Operational errors must still propagate and must
  # never be mistaken for the intentionally preserved-conflict result.
  put(install / "assert-install-failure", '''#!/bin/bash
set -Eeuo pipefail
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/managed-paths.sh" --replace
if "install_$1" "$2" "$3"; then
  printf 'Installer swallowed an operational failure\\n' >&2
  exit 90
fi
[ "$path_conflicts" -eq 0 ]
''')
  for method, final_command in (("link", "ln"), ("copy", "install")):
    commands = ["mktemp", "mv", "mkdir", final_command]
    for failed in commands:
      case = base / f"failure-{method}-{failed}"
      source, target, log = case / "source", case / "target", case / "log"
      put(source, "replacement")
      put(target, "original")
      run("assert-install-failure", method, str(source), str(target),
          extra={"FAIL_SUDO_CMD": failed, "SUDO_LOG": str(log)})
      assert log.read_text().splitlines() == commands[:commands.index(failed) + 1]
      if failed in ("mktemp", "mv"):
        assert target.read_text() == "original" and not target.is_symlink()
      else:
        assert not target.exists() and not target.is_symlink()
        assert next(case.glob(".dotfiles-backup-*/target")).read_text() == "original"

  put(scripts / "theme", "#!/bin/bash\nexit 0\n", True)
  (base / "log").unlink()
  run("post")
  assert not (base / "log").exists(), "TTY post attempted xset"
  run("post", extra={"DISPLAY": ":1", "XDG_SESSION_TYPE": "x11"})
  assert (base / "log").read_text() == "xset\n", "X11 failure should be reported without aborting setup"

  # Full migration preserves unrelated fields and ownership, is read-only in
  # preview, refuses conflicting state and active dotpkg locks, and retries
  # a crash after saving the destination but before removing the source.
  state_root = home / ".config/dotpkg"
  core = state_root / "state.yaml"
  skills = state_root / "optional-skills/state.yaml"
  effects = state_root / "optional-effects/state.yaml"
  mapping = "linux/config/openeffects/openeffectsd.service.d/autostart.conf:$XDG_CONFIG_HOME/systemd/user/openeffectsd.service.d/autostart.conf"
  bundle = {"repository": "mattpocock/skills", "target": str(home / ".local/share/dotpkg/opencode-skills"), "commit": "a" * 40, "paths": ["skills/productivity/grill-me", "skills/productivity/grilling", "LICENSE"]}
  original = {"version": 1, "current": {"selections": {"hyprland": True}},
              "unknown": "preserve", "managed": {"packages": ["vim"], "configs": [mapping, "other:target"],
              "services": ["user:openeffectsd.service", "user:other.service"],
              "remote_bundles": {"grill-me": bundle, "other": copy.deepcopy(bundle)}},
              "service_tracking": {"user:openeffectsd.service": {"fingerprint": "abc"}}}
  put(core, json.dumps(original))
  before = core.read_bytes()
  for state in (core, skills, effects):
    journal = Path(str(state) + ".journal.yaml")
    put(journal, json.dumps({"version": 1, "state_path": str(state), "completed": False,
                            "installed": {"repository": ["test-package"]}, "removed": {}}))
    journal_bytes = journal.read_bytes()
    for args in ((), ("--check",)):
      result = run("optional-state.py", *args, ok=False)
      assert result.returncode == 1 and str(journal) in result.stderr
      assert "dotpkg recover --state-file" in result.stderr
      assert core.read_bytes() == before and journal.read_bytes() == journal_bytes
      assert not skills.exists() and not effects.exists()
      assert not list(state_root.glob("optional-state-backup-*"))
    journal.unlink()
  # Completed or unparseable journals are dotpkg's responsibility too, and a
  # journal can survive loss of the state file itself.
  journal = Path(str(core) + ".journal.yaml")
  core.unlink()
  for content in ('{"version":1,"completed":true}', 'invalid: ['):
    put(journal, content)
    run("optional-state.py", ok=False)
    assert not core.exists() and journal.read_text() == content
  journal.unlink()
  journal.symlink_to(state_root / "missing-journal")
  run("optional-state.py", "--check", ok=False)
  assert journal.is_symlink()
  journal.unlink()
  put(core, before.decode())
  result = run("optional-state.py", "--dry-run", ok=False)
  assert result.returncode == 3 and core.read_bytes() == before and not skills.exists()
  with open(str(core) + ".lock", "w") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    run("optional-state.py", ok=False)
  put(skills, json.dumps({"version": 1, "managed": {"remote_bundles": {"grill-me": bundle | {"commit": "b" * 40}}}}))
  run("optional-state.py", ok=False)
  assert core.read_bytes() == before
  put(skills, json.dumps({"version": 1, "managed": {"remote_bundles": {"grill-me": bundle}}}))
  run("optional-state.py")
  after = json.loads(core.read_text())
  assert after["managed"]["configs"] == ["other:target"]
  assert after["managed"]["services"] == ["user:other.service"]
  assert after["managed"]["packages"] == ["vim"] and after["unknown"] == "preserve"
  assert set(after["managed"]["remote_bundles"]) == {"other"}
  assert json.loads(effects.read_text())["managed"]["configs"] == [mapping]
  assert json.loads(skills.read_text())["managed"]["remote_bundles"]["grill-me"] == bundle
  assert next(state_root.glob("optional-state-backup-*/0-dotpkg.yaml")).read_bytes() == before
  stable = core.read_bytes(), skills.read_bytes(), effects.read_bytes()
  run("optional-state.py")
  assert stable == (core.read_bytes(), skills.read_bytes(), effects.read_bytes())

print("Installer reliability: ok")

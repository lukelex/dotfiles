#!/usr/bin/env python3
"""Own idle processes for exactly one logind graphical session."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
ENVIRONMENT = ('DISPLAY', 'XAUTHORITY', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE',
  'XDG_SESSION_TYPE', 'XDG_SESSION_DESKTOP', 'XDG_CURRENT_DESKTOP', 'XDG_SESSION_ID',
  'DBUS_SESSION_BUS_ADDRESS')


def session_alive(session=None):
  session = session or os.environ.get('XDG_SESSION_ID')
  if not session or os.environ.get('XDG_SESSION_TYPE') not in ('x11', 'wayland'):
    return False
  try:
    result = subprocess.run(['loginctl', 'show-session', session, '-p', 'State', '-p', 'Type'],
      capture_output=True, text=True, timeout=2)
    properties = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    return (result.returncode == 0 and properties.get('State') in ('active', 'online')
      and properties.get('Type') in ('x11', 'wayland'))
  except subprocess.SubprocessError:
    return False


def systemctl(*args):
  subprocess.run(['systemctl', '--user', *args], check=True, timeout=15)


def stop_retired_idle():
  # Hyprland-only profiles never installed this optional legacy unit. Query
  # state rather than swallowing a failed stop (which could hide a live owner).
  result = subprocess.check_output(['systemctl', '--user', 'show', 'xautolock.service',
    '-p', 'LoadState', '-p', 'ActiveState'], text=True, timeout=2)
  properties = dict(line.split('=', 1) for line in result.splitlines() if '=' in line)
  if properties == {'LoadState': 'not-found', 'ActiveState': 'inactive'}:
    return
  if not properties.get('LoadState') or not properties.get('ActiveState'):
    raise RuntimeError('Cannot determine the retired idle owner state')
  systemctl('stop', 'xautolock.service')


def start():
  if not session_alive():
    raise RuntimeError('No live graphical logind session')
  # Stop the old owner before importing the new display. A lingering manager
  # must not retain Wayland variables when the next session is X11 (or vice versa).
  manager = subprocess.check_output(['systemctl', '--user', 'show-environment'], text=True, timeout=2)
  previous = next((line.split('=', 1)[1] for line in manager.splitlines() if line.startswith('XDG_SESSION_ID=')), None)
  if previous and previous != os.environ['XDG_SESSION_ID']:
    if session_alive(previous):
      raise RuntimeError('Another graphical session is still live; concurrent sessions are not supported')
    systemctl('stop', 'dotfiles-lock.service')
  systemctl('stop', 'dotfiles-idle.service')
  stop_retired_idle()
  systemctl('unset-environment', *ENVIRONMENT)
  systemctl('import-environment', *(key for key in ENVIRONMENT if os.environ.get(key)))
  systemctl('daemon-reload')
  systemctl('reset-failed', 'dotfiles-idle.service')
  systemctl('start', 'dotfiles-idle.service')


def run():
  processes = []
  try:
    if os.environ['XDG_SESSION_TYPE'] == 'x11':
      # xautolock alone owns idle timing; disable X's independent screensaver.
      subprocess.run(['xset', 's', 'off'], check=True, timeout=2)
      processes.append(subprocess.Popen(['xss-lock', '--transfer-sleep-lock', '--',
        str(ROOT / 'scripts/exit'), 'lock']))
    processes.append(subprocess.Popen([sys.executable, str(Path(__file__).with_name('settings.py')), 'run-idle']))
    while session_alive():
      if any(process.poll() is not None for process in processes):
        return 1  # systemd restarts both children, never leaves half an owner
      time.sleep(1)
    return 0
  finally:
    for process in processes:
      if process.poll() is None:
        process.terminate()


if __name__ == '__main__':
  try:
    if sys.argv[1] == 'check':
      sys.exit(0 if session_alive() else 1)
    if sys.argv[1] == 'start':
      with (Path(os.environ['XDG_RUNTIME_DIR']) / 'dotfiles-session-start.lock').open('w') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX)
        start()
    else:
      sys.exit(run())
  except (OSError, RuntimeError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)

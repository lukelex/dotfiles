#!/usr/bin/env python3
"""One supervised locker. Only native readiness can complete a start job.

Wayland: hypridle's GetActive is driven by hyprland-lock-notify-v1, not
process presence or LockedHint. Verify the D-Bus owner belongs to this
compositor. X11: i3lock closes XSS_SLEEP_LOCK_FD after grabbing inputs and
mapping its window. A closed pipe from a dead process is NOT readiness.

Verified with installed Arch hypridle 0.1.8-2 (upstream v0.1.8):
https://github.com/hyprwm/hypridle/blob/v0.1.8/src/core/Hypridle.cpp
run() binds lock-notify; onLocked/onUnlocked update m_isLocked; setupDBUS()
returns it from GetActive. inhibit_sleep=3 selects SLEEP_INHIBIT_LOCK_NOTIFY,
and onLocked releases the logind delay FD. The protocol requires a frame on
every output and immediately reports an already-locked session to new clients:
https://github.com/hyprwm/hyprland-protocols/blob/main/protocols/hyprland-lock-notify-v1.xml
"""
import os
from pathlib import Path
import select
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
UNIT = 'dotfiles-lock.service'


def output(*args):
  return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL, timeout=1).strip()


def wayland_locked():
  try:
    owner = output('busctl', '--user', 'call', 'org.freedesktop.DBus',
      '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'GetNameOwner',
      's', 'org.freedesktop.ScreenSaver').split('"')[1]
    pid = int(output('busctl', '--user', 'call', 'org.freedesktop.DBus',
      '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'GetConnectionUnixProcessID', 's', owner).split()[1])
    proc = Path('/proc') / str(pid)
    if (proc / 'exe').resolve().name != 'hypridle':
      return False
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    if not signature or f'HYPRLAND_INSTANCE_SIGNATURE={signature}'.encode() not in (proc / 'environ').read_bytes().split(b'\0'):
      return False
    return output('busctl', '--user', 'call', owner, '/org/freedesktop/ScreenSaver',
      'org.freedesktop.ScreenSaver', 'GetActive') == 'b true'
  except (OSError, ValueError, IndexError, subprocess.SubprocessError):
    return False


def notify_ready():
  address = os.environ['NOTIFY_SOCKET']
  if address.startswith('@'):
    address = '\0' + address[1:]
  with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
    sock.connect(address)
    sock.sendall(b'READY=1')


def wait_ready(process, session, read_fd=None, seconds=12):
  deadline = time.monotonic() + seconds
  while time.monotonic() < deadline:
    if process.poll() is not None:
      return False
    if session == 'wayland':
      ready = wayland_locked()
    else:
      ready = bool(select.select([read_fd], [], [], 0.05)[0]) and os.read(read_fd, 1) == b''
      # EOF is also generated on exec/startup failure. Reap it before accepting.
      if ready:
        time.sleep(0.05)
    if ready and process.poll() is None:
      return True
    time.sleep(0.05)
  return False


def serve():
  session = os.environ.get('XDG_SESSION_TYPE')
  if session not in ('wayland', 'x11'):
    raise RuntimeError('No supported graphical session')
  env = os.environ.copy()
  env.pop('XSS_SLEEP_LOCK_FD', None)
  read_fd = write_fd = None
  if session == 'x11':
    read_fd, write_fd = os.pipe()
    env['XSS_SLEEP_LOCK_FD'] = str(write_fd)
  command = ROOT / 'scripts' / ('hyprlock' if session == 'wayland' else 'blurlock')
  process = subprocess.Popen([str(command)], env=env, pass_fds=(() if write_fd is None else (write_fd,)))
  if write_fd is not None:
    os.close(write_fd)
  try:
    if not wait_ready(process, session, read_fd):
      raise RuntimeError('Locker did not acknowledge readiness; refusing explicit sleep')
    notify_ready()
    # Hardware/IPC work starts only after the lock is established.
    for command in (['u_music', 'pause'], ['qs', '-p', str(ROOT / 'config/quickshell/shell.qml'),
        'ipc', 'call', 'notifications', 'clearVisible']):
      subprocess.Popen(['timeout', '-k', '0.2', '1', *command],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.Popen([str(ROOT / 'scripts/lock-with-dim'), '--watch', str(process.pid)])
    # Exit immediately on unlock: never advertise active readiness during a
    # brightness restore. systemd sends TERM to the sidecar, which restores.
    return process.wait()
  finally:
    if read_fd is not None:
      os.close(read_fd)
    # systemd owns the whole cgroup, including render subprocesses and locker.


def client(wait):
  # Check that this caller and the manager agree about the current session.
  expected = os.environ.get('XDG_SESSION_ID')
  manager = output('systemctl', '--user', 'show-environment').splitlines()
  if not expected or f'XDG_SESSION_ID={expected}' not in manager:
    raise RuntimeError('Graphical session environment is not initialized')
  subprocess.run(['systemctl', '--user', 'start', UNIT], check=True, timeout=18)
  if output('systemctl', '--user', 'show', UNIT, '-p', 'ActiveState', '--value') != 'active':
    raise RuntimeError('Locker exited before sleep readiness was checked')
  fd = os.environ.get('XSS_SLEEP_LOCK_FD')
  if fd:
    os.close(int(fd))
  if wait:
    while output('systemctl', '--user', 'show', UNIT, '-p', 'ActiveState', '--value') in ('active', 'activating'):
      time.sleep(0.25)
  return 0


if __name__ == '__main__':
  try:
    sys.exit(serve() if sys.argv[1] == 'serve' else client(sys.argv[1] == 'client'))
  except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
    print(f'Lock failed: {error}', file=sys.stderr)
    # xss-lock clients keep their delay FD on failure until logind's deadline;
    # returning early would release it immediately. This cannot veto sleep.
    if os.environ.get('XSS_SLEEP_LOCK_FD'):
      time.sleep(15)
    sys.exit(1)

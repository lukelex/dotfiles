#!/usr/bin/env python3
"""Isolated protocol and failure tests; never touches the live session."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[3]


def module(name):
  spec = importlib.util.spec_from_file_location(name, ROOT / f'linux/config/system-settings/{name}.py')
  result = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(result)
  return result


lock = module('session-lock')
idle = module('session-idle')


class Readiness(unittest.TestCase):
  def test_running_wayland_process_is_not_readiness(self):
    with patch.object(lock, 'wayland_locked', return_value=False):
      self.assertFalse(lock.wait_ready(Mock(poll=lambda: None), 'wayland', seconds=.1))

  def test_compositor_acknowledgement_is_readiness(self):
    with patch.object(lock, 'wayland_locked', return_value=True):
      self.assertTrue(lock.wait_ready(Mock(poll=lambda: None), 'wayland'))

  def test_dead_locker_cannot_acknowledge(self):
    with patch.object(lock, 'wayland_locked', return_value=True):
      self.assertFalse(lock.wait_ready(Mock(poll=lambda: 1), 'wayland'))

  def test_x11_requires_pipe_close_while_locker_survives(self):
    reader, writer = os.pipe()
    try:
      self.assertFalse(lock.wait_ready(Mock(poll=lambda: None), 'x11', reader, seconds=.1))
      os.close(writer)
      self.assertTrue(lock.wait_ready(Mock(poll=lambda: None), 'x11', reader))
      self.assertFalse(lock.wait_ready(Mock(poll=lambda: 1), 'x11', reader))
    finally:
      os.close(reader)

  def test_real_failed_exec_pipe_eof_is_not_readiness(self):
    reader, writer = os.pipe()
    process = subprocess.Popen([sys.executable, '-c', 'raise SystemExit(1)'], pass_fds=(writer,))
    os.close(writer)
    try:
      self.assertFalse(lock.wait_ready(process, 'x11', reader))
    finally:
      process.wait()
      os.close(reader)

  def test_foreign_screensaver_service_is_not_readiness(self):
    with patch.object(lock, 'output', side_effect=['s ":1.2"', f'u {os.getpid()}']):
      self.assertFalse(lock.wayland_locked())

  def test_x11_fd_survives_wrapper_and_stalled_render_without_extra_holders(self):
    with tempfile.TemporaryDirectory() as directory:
      home = Path(directory)
      binary = home / 'bin'
      binary.mkdir()
      (home / 'wallpaper.png').touch()
      # A stuck render subprocess inherits the FD too. Its process group must
      # be gone before the real locker closes the final writing endpoint.
      (binary / 'xrandr').write_text('#!/bin/sh\nsleep 60\n')
      (binary / 'xrandr').chmod(0o755)
      (binary / 'i3lock').write_text(f'#!{sys.executable}\n'
        'import os, sys, time\n'
        'assert "--nofork" in sys.argv\n'
        'fd = int(os.environ["XSS_SLEEP_LOCK_FD"])\n'
        'os.fstat(fd)\n'
        'os.close(fd)\n'
        'time.sleep(30)\n')
      (binary / 'i3lock').chmod(0o755)
      reader, writer = os.pipe()
      env = dict(os.environ, HOME=str(home), XDG_CACHE_HOME=str(home / 'cache'),
        PATH=f'{binary}:/usr/bin:/bin', XSS_SLEEP_LOCK_FD=str(writer))
      process = subprocess.Popen([str(ROOT / 'linux/scripts/blurlock')], env=env, pass_fds=(writer,))
      os.close(writer)
      try:
        self.assertTrue(lock.wait_ready(process, 'x11', reader, seconds=4))
      finally:
        process.terminate()
        process.wait(timeout=2)
        os.close(reader)

  def test_failed_service_start_retains_xss_delay_fd(self):
    reader, writer = os.pipe()
    try:
      with patch.dict(os.environ, XDG_SESSION_ID='7', XSS_SLEEP_LOCK_FD=str(writer)), \
          patch.object(lock, 'output', return_value='XDG_SESSION_ID=7'), \
          patch.object(lock.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'systemctl')):
        with self.assertRaises(subprocess.CalledProcessError):
          lock.client(False)
        os.fstat(writer)
    finally:
      os.close(reader)
      os.close(writer)

  def test_explicit_sleep_fails_closed(self):
    with tempfile.TemporaryDirectory() as directory:
      home = Path(directory)
      scripts = home / 'dotfiles/linux/scripts'
      scripts.mkdir(parents=True)
      helper = scripts / 'lock-before-sleep'
      helper.write_text('#!/bin/sh\nexit 1\n')
      helper.chmod(0o755)
      binary = home / 'systemctl'
      binary.write_text('#!/bin/sh\ntouch "$HOME/slept"\n')
      binary.chmod(0o755)
      env = dict(os.environ, HOME=str(home), PATH=f'{home}:/usr/bin:/bin')
      for action in ('suspend', 'hibernate'):
        result = subprocess.run(['bash', str(ROOT / 'linux/scripts/exit'), action], env=env,
          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((home / 'slept').exists())


class SessionOwnership(unittest.TestCase):
  def test_switch_clears_stale_environment_before_start(self):
    with patch.dict(os.environ, XDG_SESSION_ID='new', XDG_SESSION_TYPE='x11'), \
        patch.object(idle, 'session_alive', side_effect=lambda session=None: session is None), \
        patch.object(idle.subprocess, 'check_output', side_effect=[
          'XDG_SESSION_ID=old\n', 'LoadState=loaded\nActiveState=active\n']), \
        patch.object(idle, 'systemctl') as systemctl:
      idle.start()
      calls = [call.args for call in systemctl.call_args_list]
      self.assertEqual(calls[0], ('stop', 'dotfiles-lock.service'))
      self.assertEqual(calls[1], ('stop', 'dotfiles-idle.service'))
      self.assertEqual(calls[2], ('stop', 'xautolock.service'))
      self.assertEqual(calls[3][0], 'unset-environment')
      self.assertIn('WAYLAND_DISPLAY', calls[3])
      self.assertEqual(calls[4][0], 'import-environment')
      self.assertEqual(calls[-1], ('start', 'dotfiles-idle.service'))

  def test_fresh_wayland_profile_without_xautolock_starts_idle(self):
    with patch.dict(os.environ, XDG_SESSION_ID='new', XDG_SESSION_TYPE='wayland'), \
        patch.object(idle, 'session_alive', return_value=True), \
        patch.object(idle.subprocess, 'check_output', side_effect=[
          '', 'LoadState=not-found\nActiveState=inactive\n']), \
        patch.object(idle, 'systemctl') as systemctl:
      idle.start()
      calls = [call.args for call in systemctl.call_args_list]
      self.assertEqual(calls[0], ('stop', 'dotfiles-idle.service'))
      self.assertNotIn(('stop', 'xautolock.service'), calls)
      self.assertEqual(calls[-1], ('start', 'dotfiles-idle.service'))

  def test_same_session_restart_preserves_existing_lock(self):
    with patch.dict(os.environ, XDG_SESSION_ID='same', XDG_SESSION_TYPE='wayland'), \
        patch.object(idle, 'session_alive', return_value=True), \
        patch.object(idle.subprocess, 'check_output', side_effect=[
          'XDG_SESSION_ID=same\n', 'LoadState=not-found\nActiveState=inactive\n']), \
        patch.object(idle, 'systemctl') as systemctl:
      idle.start()
      self.assertNotIn(('stop', 'dotfiles-lock.service'), [call.args for call in systemctl.call_args_list])

  def test_retired_unit_stop_failure_is_not_ignored(self):
    with patch.object(idle.subprocess, 'check_output', return_value='LoadState=loaded\nActiveState=active\n'), \
        patch.object(idle, 'systemctl', side_effect=subprocess.CalledProcessError(1, 'systemctl')):
      with self.assertRaises(subprocess.CalledProcessError):
        idle.stop_retired_idle()

  def test_required_unit_stop_failure_blocks_startup(self):
    with patch.dict(os.environ, XDG_SESSION_ID='new'), \
        patch.object(idle, 'session_alive', return_value=True), \
        patch.object(idle.subprocess, 'check_output', return_value=''), \
        patch.object(idle, 'systemctl', side_effect=subprocess.CalledProcessError(1, 'systemctl')) as systemctl:
      with self.assertRaises(subprocess.CalledProcessError):
        idle.start()
      systemctl.assert_called_once_with('stop', 'dotfiles-idle.service')

  def test_concurrent_session_is_rejected_without_stopping_anything(self):
    with patch.dict(os.environ, XDG_SESSION_ID='new'), \
        patch.object(idle, 'session_alive', return_value=True), \
        patch.object(idle.subprocess, 'check_output', return_value='XDG_SESSION_ID=old\n'), \
        patch.object(idle, 'systemctl') as systemctl:
      with self.assertRaises(RuntimeError):
        idle.start()
      systemctl.assert_not_called()

  def test_closing_session_cannot_restart_idle(self):
    with patch.dict(os.environ, XDG_SESSION_ID='old', XDG_SESSION_TYPE='x11'), \
        patch.object(idle.subprocess, 'run', return_value=Mock(returncode=0, stdout='State=closing\nType=x11\n')):
      self.assertFalse(idle.session_alive())

  def test_tty_is_not_a_conflicting_graphical_session(self):
    with patch.dict(os.environ, XDG_SESSION_ID='new', XDG_SESSION_TYPE='wayland'), \
        patch.object(idle.subprocess, 'run', return_value=Mock(returncode=0, stdout='State=active\nType=tty\n')):
      self.assertFalse(idle.session_alive('old'))


if __name__ == '__main__':
  unittest.main()

#!/usr/bin/env python3
"""Monitor profiles, native backend adapters and independent trial rollback."""
import argparse
import atexit
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid

from settings import atomic_write

HERE = Path(__file__).resolve().parent
STORE = Path(os.environ.get('DOTFILES_MONITOR_PROFILES', HERE / 'monitor-profiles.json'))
SESSION = os.environ.get('XDG_SESSION_TYPE', 'x11')
SESSION_KEY = hashlib.sha256((os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '') + os.environ.get('DISPLAY', '')).encode()).hexdigest()[:12]
RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / f'dotfiles-monitors-{os.getuid()}-{SESSION_KEY}'
ROTATIONS = ['normal', 'left', 'inverted', 'right']
TRANSFORMS = {'normal': 0, 'left': 1, 'inverted': 2, 'right': 3}


def command(args, env=None):
  process = subprocess.Popen(args, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
  try:
    stdout, stderr = process.communicate(timeout=10)
  except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGKILL)
    process.communicate()
    raise RuntimeError(f'{args[0]} timed out')
  if process.returncode:
    raise RuntimeError(stderr.strip() or stdout.strip() or f'{args[0]} failed')
  return stdout


@contextmanager
def locked(name='operation'):
  RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
  path = RUNTIME.parent / f'dotfiles-monitor-store-{os.getuid()}.lock' if name == 'store' else RUNTIME / (name + '.lock')
  with path.open('a') as stream:
    fcntl.flock(stream, fcntl.LOCK_EX)
    yield


def write_json(path, value):
  atomic_write(path, json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def read_state(name, default=None):
  try:
    return json.loads((RUNTIME / name).read_text())
  except FileNotFoundError:
    return default


def validate_outputs(outputs):
  if not isinstance(outputs, list) or not 1 <= len(outputs) <= 32:
    raise ValueError('A layout needs between 1 and 32 displays')
  names = set()
  for o in outputs:
    if not isinstance(o, dict):
      raise ValueError('Invalid display')
    if not re.fullmatch(r'[A-Za-z0-9_.:-]{1,100}', o.get('connector', '')) or o['connector'] in names:
      raise ValueError('Display connectors must be unique names')
    names.add(o['connector'])
    if not isinstance(o.get('identity'), str) or len(o['identity']) > 4096 or any(ord(c) < 32 for c in o['identity']):
      raise ValueError('Invalid display identity')
    if type(o.get('enabled')) is not bool or type(o.get('primary')) is not bool:
      raise ValueError('Display enabled/primary must be boolean')
    if not re.fullmatch(r'[1-9][0-9]{1,4}x[1-9][0-9]{1,4}', o.get('mode', '')):
      raise ValueError('Invalid display resolution')
    for field, lower, upper in [('rate', 1, 1000), ('scale', 0.5, 4), ('x', 0, 65535), ('y', 0, 65535)]:
      v = o.get(field)
      if type(v) not in (float, int) or not math.isfinite(v) or not lower <= v <= upper:
        raise ValueError(f'Invalid display {field}')
      if field in ('x', 'y') and type(v) is not int:
        raise ValueError('Display positions must be whole numbers')
    if o.get('rotation') not in ROTATIONS:
      raise ValueError('Invalid display orientation')
  if not any(o['enabled'] for o in outputs):
    raise ValueError('At least one display must remain enabled')
  if sum(o['primary'] and o['enabled'] for o in outputs) > 1:
    raise ValueError('Only one display can be primary')
  return outputs


def validate(store):
  if not isinstance(store, dict) or store.get('version') != 1 or type(store.get('automatic')) is not bool or not isinstance(store.get('profiles'), list):
    raise ValueError('Invalid monitor profile store (expected version 1)')
  names = set()
  for profile in store['profiles']:
    if not isinstance(profile, dict):
      raise ValueError('Invalid monitor profile')
    name = profile.get('name', '')
    if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 _.-]{0,63}', name) or name in names:
      raise ValueError('Profile names must be unique, 1–64 letters, numbers, spaces, dots, underscores or hyphens')
    names.add(name)
    if profile.get('session') not in ('x11', 'wayland') or type(profile.get('preferred')) is not bool:
      raise ValueError('Invalid profile session/preference')
    validate_outputs(profile['outputs'])
  return store


def load():
  return validate(json.loads(STORE.read_text()))


def base_output(name):
  return dict(connector=name, identity='', enabled=False, mode='1920x1080', rate=60,
    scale=1, rotation='normal', x=0, y=0, primary=False)


def parse_autorandr(config, fingerprint):
  identities = dict(line.split(None, 1) for line in fingerprint.splitlines() if len(line.split(None, 1)) == 2)
  outputs = []
  current = None
  for line in config.splitlines():
    parts = line.split(None, 1)
    if not parts:
      continue
    key, value = parts[0], parts[1] if len(parts) > 1 else ''
    if key == 'output':
      current = base_output(value)
      current['identity'] = 'edid:' + identities[value].lower() if value in identities else ''
      outputs.append(current)
    elif current is not None:
      if key == 'mode':
        current.update(mode=value, enabled=True)
      elif key == 'pos':
        current['x'], current['y'] = map(int, value.split('x'))
      elif key == 'rate':
        current['rate'] = float(value)
      elif key == 'rotate':
        current['rotation'] = value
      elif key == 'primary':
        current['primary'] = True
      elif key == 'transform':
        matrix = [float(v) for v in value.split(',')]
        if len(matrix) != 9 or matrix[0] != matrix[4] or matrix[0] <= 0 or any(matrix[i] for i in (1, 2, 3, 5, 6, 7)) or matrix[8] != 1:
          raise ValueError('Non-uniform X11 transforms must be edited with xrandr')
        current['scale'] = round(1 / matrix[0], 4)
      elif key == 'reflect' and value != 'normal':
        raise ValueError('Reflected X11 layouts must be edited with xrandr')
  return [o for o in outputs if o['connector'] in identities]


def discover():
  if SESSION == 'wayland':
    result = []
    for raw in json.loads(command(['hyprctl', '-j', 'monitors', 'all'])):
      o = base_output(raw['name'])
      available = []
      for mode in raw.get('availableModes', []):
        match = re.fullmatch(r'(\d+x\d+)@([\d.]+)(?:Hz)?', mode)
        if match:
          available.append({'mode': match[1], 'rate': float(match[2])})
      rotation = int(raw.get('transform', 0))
      if rotation not in (0, 1, 2, 3):
        raise ValueError('Reflected Wayland displays must be edited with Hyprland')
      o.update(identity='description:' + raw['description'] if raw.get('description') else '',
        enabled=not raw.get('disabled', False), mode=f"{raw.get('width', 1920)}x{raw.get('height', 1080)}",
        rate=raw.get('refreshRate', 60) or 60, scale=raw.get('scale', 1), rotation=ROTATIONS[rotation],
        x=raw.get('x', 0), y=raw.get('y', 0), description=raw.get('description', raw['name']), modes=available)
      if not o['enabled'] and available:
        o.update(available[0])
      result.append(o)
    if result:
      min_x = min(0, *(o['x'] for o in result))
      min_y = min(0, *(o['y'] for o in result))
      for o in result:
        o['x'] -= min_x
        o['y'] -= min_y
    return result
  config = command(['autorandr', '--config'])
  fingerprint = command(['autorandr', '--fingerprint'])
  outputs = parse_autorandr(config, fingerprint)
  modes = {}
  name = None
  for line in command(['xrandr', '--query']).splitlines():
    match = re.match(r'^(\S+) connected', line)
    if match:
      name = match[1]
      modes[name] = []
    elif line and not line[0].isspace():
      name = None
    elif name:
      match = re.match(r'^\s+(\d+x\d+)\s+(.+)', line)
      if match:
        for rate in re.findall(r'([\d.]+)[*+]?', match[2]):
          item = {'mode': match[1], 'rate': float(rate)}
          if item not in modes[name]:
            modes[name].append(item)
  for o in outputs:
    o['modes'] = modes.get(o['connector'], [])
    o['description'] = edid_details(bytes.fromhex(o['identity'][5:]))['monitorName'] or o['connector']
    if not o['enabled'] and o['modes']:
      o.update(o['modes'][0])
  return outputs


def clean(outputs):
  keys = list(base_output(''))
  return [{key: o[key] for key in keys} for o in outputs]


def topology(outputs):
  return sorted(o['identity'] or o['connector'] for o in outputs)


def resolve(outputs, connected, exact=True):
  result = []
  used = set()
  for saved in outputs:
    matches = [o for o in connected if o['connector'] not in used and
      (o['identity'] == saved['identity'] if saved['identity'] else o['connector'] == saved['connector'])]
    if len(matches) > 1:
      matches = [o for o in matches if o['connector'] == saved['connector']]
    if len(matches) != 1:
      if exact:
        raise ValueError(f"Display unavailable or ambiguous: {saved['connector']}")
      continue
    o = dict(saved, connector=matches[0]['connector'], identity=matches[0]['identity'])
    used.add(o['connector'])
    if o['enabled'] and exact and not any(m['mode'] == o['mode'] and abs(m['rate'] - o['rate']) < 0.15 for m in matches[0]['modes']):
      raise ValueError(f"Unsupported mode for {o['connector']}: {o['mode']} @ {o['rate']} Hz")
    result.append(o)
  if exact and len(used) != len(connected):
    raise ValueError('Connected displays changed. Refresh the layout before applying.')
  if not exact:
    result.extend(clean([o for o in connected if o['connector'] not in used]))
    if result and not any(o['enabled'] for o in result):
      fallback = result[0]
      actual = next(o for o in connected if o['connector'] == fallback['connector'])
      fallback.update(enabled=True, x=0, y=0, scale=1, rotation='normal')
      if actual['modes']:
        fallback.update(actual['modes'][0])
  return validate_outputs(result)


def autorandr_config(outputs):
  lines = []
  for o in outputs:
    lines.append('output ' + o['connector'])
    if not o['enabled']:
      lines.append('off')
      continue
    factor = 1 / o['scale']
    lines += ['mode ' + o['mode'], f"pos {o['x']}x{o['y']}", f"rate {o['rate']}", 'rotate ' + o['rotation'],
      f'transform {factor:.6f},0,0,0,{factor:.6f},0,0,0,1']
    if o['primary']:
      lines.append('primary')
  return '\n'.join(lines) + '\n'


def kanshi_config(profiles):
  lines = []
  for index, profile in enumerate(profiles):
    lines.append(f'profile managed-{index} {{')
    for o in profile['outputs']:
      criteria = o['identity'].removeprefix('description:') if o['identity'].startswith('description:') else o['connector']
      line = '  output ' + json.dumps(criteria)
      if o['enabled']:
        transform = ['normal', '90', '180', '270'][TRANSFORMS[o['rotation']]]
        line += f" enable mode {o['mode']}@{o['rate']}Hz position {o['x']},{o['y']} scale {o['scale']} transform {transform}"
      else:
        line += ' disable'
      lines.append(line)
    lines.append('}')
  return '\n'.join(lines) + '\n'


def apply_layout(outputs):
  validate_outputs(outputs)
  if SESSION == 'wayland':
    # Enable first so transitions never intentionally disable the final active display.
    rules = []
    for o in sorted(outputs, key=lambda item: not item['enabled']):
      rule = f"{o['connector']},{o['mode']}@{o['rate']},{o['x']}x{o['y']},{o['scale']},transform,{TRANSFORMS[o['rotation']]}" if o['enabled'] else o['connector'] + ',disable'
      rules.append('keyword monitor ' + rule)
    response = command(['hyprctl', '--batch', '; '.join(rules)])
    if not response.strip() or any(line.strip() != 'ok' for line in response.splitlines() if line.strip()):
      raise RuntimeError(response.strip() or 'Hyprland rejected the monitor configuration')
  else:
    directory = RUNTIME / 'native/autorandr/trial'
    atomic_write(directory / 'config', autorandr_config(outputs))
    atomic_write(directory / 'setup', '\n'.join(o['connector'] + ' ' + o['identity'][5:] for o in outputs if o['identity'].startswith('edid:')) + '\n')
    command(['autorandr', '--load', 'trial', '--force', '--skip-options', 'gamma,brightness'],
      env=dict(os.environ, XDG_CONFIG_HOME=str(RUNTIME / 'native')))


def stop_kanshi():
  pid = read_state('kanshi-pid')
  if not pid:
    return
  try:
    args = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
    if str(RUNTIME / 'kanshi.conf').encode() in args:
      os.kill(pid, signal.SIGTERM)
      for _ in range(100):
        try:
          state = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[0]
          if state == 'Z':
            break
        except FileNotFoundError:
          break
        time.sleep(0.02)
      else:
        raise RuntimeError('Could not pause kanshi before changing displays')
  except (FileNotFoundError, ProcessLookupError):
    pass
  (RUNTIME / 'kanshi-pid').unlink(missing_ok=True)


def require_managed_kanshi():
  if SESSION != 'wayland':
    return
  for proc in Path('/proc').glob('[0-9]*'):
    try:
      if proc.stat().st_uid != os.getuid():
        continue
      args = (proc / 'cmdline').read_bytes().split(b'\0')
      if args and args[0].split(b'/')[-1] == b'kanshi' and str(RUNTIME / 'kanshi.conf').encode() not in args:
        raise RuntimeError('An unmanaged kanshi instance is running. Restart the desktop session to use the new monitor manager.')
    except (FileNotFoundError, PermissionError, ProcessLookupError):
      pass


def restore(pending):
  outputs = discover()
  try:
    if outputs:
      apply_layout(resolve(pending['before'], outputs, exact=False))
  except (ValueError, RuntimeError):
    # If a dock vanished or the previous mode is no longer supported, recover
    # one connected panel at its advertised mode rather than leaving it dark.
    fallback = clean(outputs)
    for index, o in enumerate(fallback):
      o.update(enabled=index == 0, primary=index == 0, x=0, y=0, scale=1, rotation='normal')
      if outputs[index]['modes']:
        o.update(outputs[index]['modes'][0])
    apply_layout(fallback)
  write_json(RUNTIME / 'hold', topology(outputs))
  (RUNTIME / 'pending').unlink(missing_ok=True)


def trial(outputs):
  with locked():
    if read_state('pending'):
      raise ValueError('Confirm or revert the current monitor change first')
    before = discover()
    draft = resolve(validate_outputs(outputs), before)
    if SESSION == 'x11':
      ensure_autorandr_block()
    require_managed_kanshi()
    stop_kanshi()
    token = uuid.uuid4().hex
    pending = dict(token=token, deadline=time.time() + 20, monotonicDeadline=time.monotonic() + 20,
      before=clean(before), after=draft, topology=topology(before))
    write_json(RUNTIME / 'pending', pending)
    try:
      # The guard exists before touching displays and survives the UI/shell closing.
      guard = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'guard', token],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
      for _ in range(100):
        if read_state('guard-ready') == token:
          break
        if guard.poll() is not None:
          raise RuntimeError('Could not start display rollback guard')
        time.sleep(0.02)
      else:
        raise RuntimeError('Display rollback guard did not become ready')
      apply_layout(draft)
    except Exception:
      restore(pending)
      raise
    return pending


def confirm(token, keep):
  with locked():
    pending = read_state('pending')
    if not pending or pending['token'] != token:
      raise ValueError('This display trial has already ended')
    current = discover()
    if not keep or time.monotonic() >= pending['monotonicDeadline'] or topology(current) != pending['topology']:
      restore(pending)
      if keep:
        raise ValueError('Trial expired or connected displays changed; restored the previous layout')
      return
    if not layout_equal(pending['after'], current):
      restore(pending)
      raise ValueError('The applied layout did not match the draft; restored the previous layout')
    write_json(RUNTIME / 'hold', pending['topology'])
    (RUNTIME / 'pending').unlink(missing_ok=True)


def guard(token):
  write_json(RUNTIME / 'guard-ready', token)
  while True:
    time.sleep(0.5)
    with locked():
      pending = read_state('pending')
      if not pending or pending['token'] != token:
        return
      if time.monotonic() >= pending['monotonicDeadline']:
        try:
          restore(pending)
          return
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
          write_json(RUNTIME / 'automation-error', 'Rollback retry: ' + str(error))


def save_profile(profile, replace_name=''):
  with locked('store'):
    store = load()
    if profile['name'] != replace_name and any(p['name'] == profile['name'] for p in store['profiles']):
      raise ValueError('A profile with that name already exists')
    if profile.get('preferred'):
      for other in store['profiles']:
        if other['session'] == profile['session'] and topology(other['outputs']) == topology(profile['outputs']):
          other['preferred'] = False
    store['profiles'] = [p for p in store['profiles'] if p['name'] != replace_name] + [profile]
    write_json(STORE, validate(store))


def preferred_profiles(store, session):
  result = []
  seen = set()
  for profile in sorted([p for p in store['profiles'] if p['session'] == session], key=lambda p: not p['preferred']):
    key = tuple(topology(profile['outputs']))
    if key not in seen:
      seen.add(key)
      result.append(profile)
  return result


def layout_equal(expected, actual):
  if len(expected) != len(actual):
    return False
  for wanted in expected:
    current = next((o for o in actual if o['connector'] == wanted['connector']), None)
    if current is None or current['enabled'] != wanted['enabled']:
      return False
    if wanted['enabled'] and (any(wanted[k] != current[k] for k in ['mode', 'x', 'y', 'rotation'])
        or abs(wanted['rate'] - current['rate']) > 0.15 or abs(wanted['scale'] - current['scale']) > 0.01
        or SESSION == 'x11' and wanted['primary'] != current['primary']):
      return False
  return True


def snapshot():
  store = load()
  outputs = discover()
  profiles = []
  for profile in store['profiles']:
    compatible = False
    current = False
    reason = 'Different desktop session'
    if profile['session'] == SESSION:
      try:
        resolved = resolve(profile['outputs'], outputs)
        current = layout_equal(resolved, outputs)
        compatible, reason = True, ''
      except ValueError as error:
        reason = str(error)
    profiles.append(dict(profile, available=compatible, current=current, reason=reason))
  return dict(session=SESSION, automatic=store['automatic'], outputs=outputs, profiles=profiles,
    pending=read_state('pending'), automationError=read_state('automation-error', ''))


def edid_details(data):
  result = {'monitorName': '', 'maxTmdsMHz': None}
  if len(data) < 128 or data[:8] != bytes.fromhex('00ffffffffffff00'):
    return result
  for offset in range(54, 126, 18):
    if data[offset:offset + 4] == b'\x00\x00\x00\xfc':
      result['monitorName'] = data[offset + 5:offset + 18].decode('ascii', errors='replace').strip()
  for offset in range(128, len(data) - 127, 128):
    block = data[offset:offset + 128]
    if block[0] != 2 or not 4 <= block[2] <= 127:
      continue
    pos = 4
    while pos < block[2]:
      length, tag = block[pos] & 31, block[pos] >> 5
      if pos + 1 + length > block[2]:
        break
      payload = block[pos + 1:pos + 1 + length]
      rate = 0
      if tag == 3 and len(payload) >= 7 and payload[:3] == bytes.fromhex('030c00'):
        rate = payload[6] * 5
      if tag == 3 and len(payload) >= 5 and payload[:3] == bytes.fromhex('d85dc4'):
        rate = payload[4] * 5
      if rate:
        result['maxTmdsMHz'] = max(result['maxTmdsMHz'] or 0, rate)
      pos += length + 1
  return result


def link_details(connector):
  if not re.fullmatch(r'[A-Za-z0-9_.:-]{1,100}', connector or ''):
    raise ValueError('Invalid connector')
  details = dict(connector=connector, pixelClockMHz=None, subconnector=None, linkStatus=None,
    maxBpc=None, activeBpc=None, negotiatedGbps=None, dsc=None, estimated8BitRgbGbps=None,
    monitorName='', maxTmdsMHz=None)
  names = [connector, connector.replace('HDMI-', 'HDMI-A-')]
  candidates = [p for name in names for p in Path('/sys/class/drm').glob('card*-' + name)]
  if len(set(candidates)) == 1:
    try:
      details.update(edid_details((candidates[0] / 'edid').read_bytes()))
    except OSError:
      pass
  if SESSION == 'x11':
    active = False
    for line in command(['xrandr', '--verbose']).splitlines():
      if line and not line[0].isspace():
        active = line.startswith(connector + ' connected')
      elif active:
        for prop, key in [('subconnector', 'subconnector'), ('link-status', 'linkStatus'), ('max bpc', 'maxBpc')]:
          match = re.match(r'\s*' + re.escape(prop) + r':\s*(.+)', line)
          if match:
            details[key] = match[1].strip()
        match = re.search(r'([\d.]+)MHz.*\*current', line)
        if match:
          details['pixelClockMHz'] = float(match[1])
    if details['pixelClockMHz']:
      details['estimated8BitRgbGbps'] = details['pixelClockMHz'] * 24 / 1000
  return details


def ensure_autorandr_block():
  # Do not overwrite custom hooks. Without coordination a udev-triggered
  # autorandr --change could undo the trial before its confirmation arrives.
  target = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'autorandr/block'
  source = HERE.parent / 'autorandr/block'
  target.parent.mkdir(parents=True, exist_ok=True)
  if not target.exists() and not target.is_symlink():
    target.symlink_to(source)
  if target.resolve() != source.resolve():
    raise ValueError('Existing autorandr block hook needs integration with the dotfiles monitor block hook')


def postswitch(name):
  if SESSION == 'x11':
    hook = HERE.parent / 'autorandr/postswitch'
    try:
      command([str(hook)], env=dict(os.environ, AUTORANDR_CURRENT_PROFILE=name))
    except (OSError, RuntimeError) as error:
      write_json(RUNTIME / 'automation-error', 'Layout applied; postswitch hook failed: ' + str(error))


def hardware_probe():
  # Read cheap kernel state between changes instead of repeatedly querying Xorg
  # through several autorandr/xrandr subprocesses while the desktop is idle.
  result = []
  for connector in sorted(Path('/sys/class/drm').glob('card*-*')):
    try:
      status = (connector / 'status').read_text().strip()
      edid = (connector / 'edid').read_bytes() if status == 'connected' else b''
      result.append([connector.name, status, hashlib.sha256(edid).hexdigest()])
    except OSError:
      continue
  for lid in sorted(Path('/proc/acpi/button/lid').glob('*/state')):
    try:
      result.append([str(lid), lid.read_text()])
    except OSError:
      pass
  return result


def watch(defer=False):
  RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
  with (RUNTIME / 'watch.lock').open('a') as stream:
    try:
      fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
      return
    atexit.register(stop_kanshi)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    if SESSION == 'x11':
      ensure_autorandr_block()
    if defer:
      write_json(RUNTIME / 'hold', topology(discover()))
    elif not read_state('pending'):
      (RUNTIME / 'hold').unlink(missing_ok=True)
    previous = None
    previous_probe = None
    child = None
    while True:
      session_id = os.environ.get('XDG_SESSION_ID')
      if session_id and Path('/run/systemd/sessions').is_dir() and not (Path('/run/systemd/sessions') / session_id).exists():
        return
      if SESSION == 'wayland' and os.environ.get('WAYLAND_DISPLAY') and not (Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / os.environ['WAYLAND_DISPLAY']).exists():
        return
      try:
        with locked():
          store = load()
          pending = read_state('pending')
          if pending and time.monotonic() >= pending['monotonicDeadline']:
            restore(pending)
            previous_probe = None
          elif not store['automatic'] or pending:
            stop_kanshi()
            previous = None
            previous_probe = None
          else:
            hold = read_state('hold')
            probe = json.dumps([store, hardware_probe(), hold], sort_keys=True)
            if probe == previous_probe and (SESSION == 'x11' or hold is not None or child is not None and child.poll() is None):
              continue
            connected = discover()
            hardware = topology(connected)
            if hold is not None and hold != hardware:
              (RUNTIME / 'hold').unlink(missing_ok=True)
              hold = None
            signature = json.dumps([store, hardware], sort_keys=True)
            if hold is None and (signature != previous or SESSION == 'wayland' and (child is None or child.poll() is not None)):
              write_json(RUNTIME / 'automation-error', '')
              profiles = preferred_profiles(store, SESSION)
              if SESSION == 'wayland':
                require_managed_kanshi()
                stop_kanshi()
                if child:
                  child.wait(timeout=5)
                path = RUNTIME / 'kanshi.conf'
                atomic_write(path, kanshi_config(profiles))
                child = subprocess.Popen(['kanshi', '-c', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                write_json(RUNTIME / 'kanshi-pid', child.pid)
                time.sleep(0.15)
                if child.poll() is not None:
                  raise RuntimeError('kanshi failed to start; check saved monitor profiles')
              else:
                matches = []
                for p in profiles:
                  try:
                    matches.append(resolve(p['outputs'], connected))
                  except ValueError:
                    pass
                if matches and not layout_equal(matches[0], connected):
                  apply_layout(matches[0])
                  postswitch('automatic')
                elif connected and not any(o['enabled'] for o in connected):
                  fallback = clean(connected)
                  fallback[0].update(enabled=True, x=0, y=0, scale=1, rotation='normal')
                  apply_layout(fallback)
              previous = signature
            previous_probe = probe
      except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        if 'open display' in str(error).lower():
          return
        write_json(RUNTIME / 'automation-error', str(error))
      finally:
        time.sleep(3)


def import_autorandr(directory):
  imported = []
  for path in sorted(Path(directory).iterdir()):
    if not (path / 'config').is_file() or not (path / 'setup').is_file():
      continue
    outputs = parse_autorandr((path / 'config').read_text(), (path / 'setup').read_text())
    profile = dict(name=path.name, session='x11', preferred=True, outputs=outputs)
    validate(dict(version=1, automatic=True, profiles=[profile]))
    imported.append(profile)
  return imported


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('command', choices=['snapshot', 'details', 'validate', 'apply', 'keep', 'revert', 'guard', 'save', 'delete', 'rename', 'automatic', 'import', 'import-autorandr', 'watch', 'start'])
  parser.add_argument('value', nargs='?')
  parser.add_argument('extra', nargs='?', default='')
  args = parser.parse_args()
  if args.command == 'snapshot':
    print(json.dumps(snapshot()))
  elif args.command == 'details':
    print(json.dumps(link_details(args.value)))
  elif args.command == 'validate':
    load()
  elif args.command == 'apply':
    print(json.dumps(trial(json.loads(args.value))))
  elif args.command in ('keep', 'revert'):
    confirm(args.value, args.command == 'keep')
    postswitch('manual')
  elif args.command == 'guard':
    guard(args.value)
  elif args.command == 'save':
    save_profile(json.loads(args.value), args.extra)
  elif args.command in ('automatic', 'delete', 'rename', 'import'):
    with locked('store'):
      store = load()
      if args.command == 'automatic':
        store['automatic'] = json.loads(args.value)
        (RUNTIME / 'hold').unlink(missing_ok=True)
      elif args.command == 'delete':
        store['profiles'] = [p for p in store['profiles'] if p['name'] != args.value]
      elif args.command == 'rename':
        if any(p['name'] == args.extra for p in store['profiles']):
          raise ValueError('A profile with that name already exists')
        profile = next((p for p in store['profiles'] if p['name'] == args.value), None)
        if profile is None:
          raise ValueError('Profile no longer exists')
        profile['name'] = args.extra
      else:
        path = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'autorandr'
        existing = {p['name'] for p in store['profiles']}
        store['profiles'].extend(p for p in import_autorandr(path) if p['name'] not in existing)
      write_json(STORE, validate(store))
  elif args.command == 'import-autorandr':
    print(json.dumps(import_autorandr(args.value), indent=2))
  elif args.command == 'watch':
    watch(args.value == 'defer')
  elif args.command == 'start':
    subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'watch', 'defer'],
      stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


if __name__ == '__main__':
  try:
    main()
  except (ValueError, KeyError, TypeError, OSError, RuntimeError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)

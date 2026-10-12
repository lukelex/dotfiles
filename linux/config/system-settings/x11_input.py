"""Discover and configure Xorg libinput devices without persisting device IDs."""
import re
import os
import subprocess


def command(*args):
  result = subprocess.run(['xinput', *args], capture_output=True, text=True, timeout=5,
    env={**os.environ, 'LC_ALL': 'C'})
  if result.returncode:
    raise RuntimeError(result.stderr.strip() or 'xinput failed')
  return result.stdout


def discover():
  devices = []
  for line in command('list', '--short').splitlines():
    match = re.search(r'id=(\d+)\s+\[slave\s+pointer', line)
    if not match:
      continue
    identifier = match[1]
    try:
      text = command('list-props', identifier)
    except RuntimeError:
      continue  # A device can disappear between enumeration and inspection.
    props = {}
    for prop in text.splitlines():
      parsed = re.match(r'\s+(.+?)\s+\(\d+\):\s*(.*)', prop)
      if parsed:
        props[parsed[1]] = parsed[2]
    if 'libinput Send Events Modes Available' not in props:
      continue
    touchpad = 'libinput Tapping Enabled' in props
    mapping = {
      'touchpadNaturalScroll' if touchpad else 'naturalScroll': 'libinput Natural Scrolling Enabled',
      'tapToClick': 'libinput Tapping Enabled',
      'disableWhileTyping': 'libinput Disable While Typing Enabled',
      'sensitivity': 'libinput Accel Speed',
    }
    supported = {key: prop for key, prop in mapping.items() if prop in props}
    profiles = [value.strip() for value in props.get('libinput Accel Profiles Available', '').split(',')]
    if profiles[:2] == ['1', '1'] and 'libinput Accel Profile Enabled' in props:
      supported['acceleration'] = 'libinput Accel Profile Enabled'
    devices.append(dict(id=identifier, node=props.get('Device Node', ''),
      name=line.split('id=')[0].strip(), settings=supported, profiles=len(profiles)))
  return devices


def describe():
  try:
    devices = discover()
    return dict(devices=devices, keys=sorted({key for device in devices for key in device['settings']}), error='')
  except (OSError, RuntimeError, subprocess.SubprocessError) as error:
    message = 'Install xorg-xinput to configure X11 pointing devices.' if isinstance(error, FileNotFoundError) else str(error)
    return dict(devices=[], keys=[], error=message)


def apply(preferences):
  snapshot = describe()
  if snapshot['error']:
    raise RuntimeError(snapshot['error'])
  for device in snapshot['devices']:
    for key, prop in device['settings'].items():
      value = preferences[key]
      if key == 'acceleration':
        values = ['1' if value == 'adaptive' else '0', '1' if value == 'flat' else '0']
        values += ['0'] * max(0, device['profiles'] - 2)
      else:
        values = [str(int(value)) if isinstance(value, bool) else str(value)]
      command('set-prop', device['id'], prop, *values)

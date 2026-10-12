#!/usr/bin/env python3
"""Bounded Pulse-compatible mixer operations; never persist live object IDs."""
import hashlib
import json
import math
import subprocess
import sys

KINDS = {'playback': 'sink-inputs', 'recording': 'source-outputs',
  'output': 'sinks', 'input': 'sources', 'card': 'cards'}


def run(*args):
  result = subprocess.run(['pactl', *args], capture_output=True, text=True, timeout=4, check=True)
  return result.stdout


def objects(kind):
  data = json.loads(run('-f', 'json', 'list', KINDS[kind]))
  if not isinstance(data, list):
    raise ValueError('Invalid mixer response')
  return data


def token(kind, item):
  properties = item.get('properties') or {}
  identity = [kind, item['index'], item.get('name'), item.get('client'),
    {key: properties.get(key) for key in ('object.serial', 'node.name',
      'application.process.id', 'application.process.binary', 'application.name', 'device.serial')}]
  return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()


def levels(item):
  return [{'name': name, 'value': round(value['value'] / 65536 * 100, 2)}
    for name, value in (item.get('volume') or {}).items()]


def base(kind, item):
  channels = levels(item)
  return {'kind': kind, 'index': item['index'], 'token': token(kind, item),
    'name': item.get('name', ''), 'channels': channels,
    'volume': max((c['value'] for c in channels), default=0), 'muted': bool(item.get('mute'))}


def snapshot():
  raw = {kind: objects(kind) for kind in KINDS}
  devices = []
  for kind in ('output', 'input'):
    for item in raw[kind]:
      device = base(kind, item)
      monitor = kind == 'input' and (item.get('monitor_of_sink') not in (None, '', 4294967295)
        or item.get('name', '').endswith('.monitor'))
      device.update(description=('System audio — ' if monitor else '') + item.get('description', item['name']),
        monitor=monitor, activePort=item.get('active_port', ''),
        ports=[{'name': p['name'], 'description': p.get('description', p['name'])}
          for p in item.get('ports', []) if p.get('availability', 'unknown') not in ('not available', 'no')])
      devices.append(device)
  streams = []
  for kind in ('playback', 'recording'):
    for item in raw[kind]:
      properties = item.get('properties') or {}
      if properties.get('application.name') == 'Quickshell Peak Detect' or str(properties.get('stream.monitor', '')).lower() in ('true', '1'):
        continue
      stream = base(kind, item)
      app = properties.get('application.name') or properties.get('application.process.binary') or 'Unknown application'
      stream.update(app=app, appKey=app.lower() + ':' + str(properties.get('application.process.id') or item.get('client', '')),
        description=properties.get('media.name') or app,
        deviceIndex=item.get('sink' if kind == 'playback' else 'source'),
        paused=bool(item.get('corked')))
      streams.append(stream)
  cards = []
  for item in raw['card']:
    card = base('card', item)
    profiles = item.get('profiles') or []
    if isinstance(profiles, dict):
      profiles = [dict(value, name=name) for name, value in profiles.items()]
    active = item.get('active_profile', '')
    card.update(description=(item.get('properties') or {}).get('device.description', item['name']),
      activeProfile=active.get('name', '') if isinstance(active, dict) else active,
      profiles=[{'name': p['name'], 'description': p.get('description', p['name'])}
        for p in profiles if p.get('available', 'unknown') not in ('no', False)])
    cards.append(card)
  return {'devices': devices, 'streams': streams, 'cards': cards}


def resolve(kind, identity):
  return next((item for item in objects(kind) if token(kind, item) == identity), None)


def change(request):
  kind, operation = request['kind'], request['operation']
  if kind not in KINDS:
    raise ValueError('Unsupported mixer target')
  item = resolve(kind, request['token'])
  if item is None:
    raise ValueError('That audio target is no longer available')
  index = str(item['index'])
  singular = {'playback': 'sink-input', 'recording': 'source-output', 'output': 'sink', 'input': 'source', 'card': 'card'}[kind]
  value = request.get('value')
  if operation in ('volume', 'channel') and kind != 'card':
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 150:
      raise ValueError('Volume must be between 0 and 150%')
    if operation == 'channel':
      channels = levels(item)
      if request.get('channel') not in [c['name'] for c in channels]:
        raise ValueError('That audio channel is no longer available')
      values = [f"{value if c['name'] == request['channel'] else c['value']}%" for c in channels]
    else:
      # Linked control preserves relative channel balance.
      channels = levels(item)
      peak = max((c['value'] for c in channels), default=0)
      values = [f"{value * c['value'] / peak if peak else value}%" for c in channels] or [f'{value}%']
    run('set-' + singular + '-volume', index, *values)
  elif operation == 'mute' and kind != 'card' and type(value) is bool:
    run('set-' + singular + '-mute', index, '1' if value else '0')
  elif operation == 'route' and kind in ('playback', 'recording'):
    target = resolve('output' if kind == 'playback' else 'input', request['deviceToken'])
    if target is None:
      raise ValueError('That audio device is no longer available')
    run('move-' + singular, index, str(target['index']))
    value = target['index']
  elif operation == 'port' and kind in ('output', 'input'):
    if value not in [p['name'] for p in item.get('ports', [])
        if p.get('availability') not in ('not available', 'no')]:
      raise ValueError('That device connector is unavailable')
    run('set-' + singular + '-port', index, value)
  elif operation == 'profile' and kind == 'card':
    profiles = item.get('profiles') or {}
    candidates = profiles.values() if isinstance(profiles, dict) else profiles
    names = {p.get('name', name): p for name, p in profiles.items()} if isinstance(profiles, dict) else {p['name']: p for p in candidates}
    if value not in names or names[value].get('available') in ('no', False):
      raise ValueError('That device mode is unavailable')
    run('set-card-profile', index, value)
  else:
    raise ValueError('Unsupported mixer operation')
  # Re-read the captured object, never resolve a replacement default. Profile
  # changes may replace device nodes, but the card identity must still match.
  current = resolve(kind, request['token'])
  if current is None:
    raise ValueError('Audio target disappeared before the change could be confirmed')
  if operation == 'volume':
    confirmed = abs(base(kind, current)['volume'] - value) < 1
  elif operation == 'channel':
    confirmed = any(c['name'] == request['channel'] and abs(c['value'] - value) < 1 for c in levels(current))
  elif operation == 'mute':
    confirmed = bool(current.get('mute')) == value
  elif operation == 'route':
    confirmed = current.get('sink' if kind == 'playback' else 'source') == value
  elif operation == 'port':
    confirmed = current.get('active_port') == value
  else:
    active = current.get('active_profile')
    confirmed = (active.get('name') if isinstance(active, dict) else active) == value
  if not confirmed:
    raise ValueError('Could not confirm the audio change; refresh and try again')


if __name__ == '__main__':
  try:
    if len(sys.argv) > 1:
      change(json.loads(sys.argv[1]))
    print(json.dumps(snapshot()))
  except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)

#!/usr/bin/env python3
"""Filter decorative hyprlock widgets, never authentication or lock behavior."""
import re
import sys

from settings import load

DEFAULTS = {key: True for key in (
  'showGreeting', 'showQuote', 'showBattery', 'showNetwork', 'showVpn', 'showAudio',
  'showDnd', 'showPrivacy', 'showSecurity', 'showWeather', 'showMedia', 'showMediaArtwork')}
DEFAULTS.update(wallpaperBlur=7, wallpaperBlurPasses=3, wallpaperBrightness=78)


def widget_setting(block):
  if 'linux/scripts/lock-greeting' in block:
    return 'showGreeting'
  if 'linux/scripts/lock-quote' in block:
    return 'showQuote'
  if 'lock-battery-ring' in block:
    return 'showBattery'
  if 'lock-media-art' in block:
    return 'showMediaArtwork'
  match = re.search(r'linux/scripts/lock-status"\s+(battery|network|vpn|audio|dnd|privacy|security|weather|media)\b', block)
  if match:
    return 'show' + match[1].capitalize()
  return None


def render(template, preferences):
  def filter_block(match):
    block = match[0]
    key = widget_setting(block)
    if key and not preferences[key]:
      return ''
    if block.startswith('image') and 'lock-media-art' in block and not preferences['showMedia']:
      return ''
    return block

  # Only top-level label/image blocks are filtered. Auth, general and input-field
  # settings remain untouched, including fingerprint enrollment detection.
  result = re.sub(r'^(?:label|image)\s*\{[^{}]*^\}', filter_block, template, flags=re.MULTILINE)
  def backdrop(match):
    block = match[0]
    block = re.sub(r'(blur_size\s*=\s*)\d+', lambda m: m[1] + str(preferences['wallpaperBlur']), block)
    block = re.sub(r'(blur_passes\s*=\s*)\d+', lambda m: m[1] + str(preferences['wallpaperBlurPasses']), block)
    # Preserve the launcher's bright-wallpaper protection. At defaults its
    # current 0.58/0.78 behavior is unchanged; the setting scales both values.
    block = re.sub(r'(brightness\s*=\s*)([\d.]+)', lambda m:
      m[1] + f"{float(m[2]) * preferences['wallpaperBrightness'] / 78:.4f}", block)
    return block
  return re.sub(r'^background\s*\{[^{}]*^\}', backdrop, result, flags=re.MULTILINE)


if __name__ == '__main__':
  template = sys.stdin.read()
  try:
    preferences = load()['lockScreen']
  except (ValueError, KeyError, TypeError, OSError) as error:
    # Bad preferences must never prevent session locking.
    print('Lock-screen preferences unavailable; using defaults: ' + str(error), file=sys.stderr)
    preferences = DEFAULTS
  sys.stdout.write(render(template, preferences))

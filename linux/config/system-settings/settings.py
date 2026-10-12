#!/usr/bin/env python3
"""Portable desktop preferences. No dependencies; stdout is machine-readable JSON."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

DIRECTORY = Path(__file__).resolve().parent
PREFERENCES = Path(os.environ.get("DOTFILES_PREFERENCES", DIRECTORY / "preferences.json"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "dotfiles/settings"

# key, label, kind, allowed values/range, session (empty means both)
FIELDS = [
  ("audio.volumeStep", "Volume key step (%)", "number", [1, 25], ""),
  ("audio.microphoneStep", "Microphone key step (%)", "number", [1, 25], ""),
  ("display.linkBrightness", "Link display and keyboard brightness", "boolean", [], ""),
  ("connectivity.bluetoothBatteryAlerts", "Bluetooth low-battery alerts", "boolean", [], ""),
  ("connectivity.bluetoothBatteryThreshold", "Bluetooth low-battery threshold (%)", "number", [1, 50], ""),
  ("lockScreen.showGreeting", "Greeting and username", "boolean", [], "wayland"),
  ("lockScreen.showQuote", "Daily quote", "boolean", [], "wayland"),
  ("lockScreen.showBattery", "Battery status", "boolean", [], "wayland"),
  ("lockScreen.showNetwork", "Network status", "boolean", [], "wayland"),
  ("lockScreen.showVpn", "VPN status", "boolean", [], "wayland"),
  ("lockScreen.showAudio", "Audio status", "boolean", [], "wayland"),
  ("lockScreen.showDnd", "Do Not Disturb status", "boolean", [], "wayland"),
  ("lockScreen.showPrivacy", "Microphone and camera activity", "boolean", [], "wayland"),
  ("lockScreen.showSecurity", "Failed unlock attempts", "boolean", [], "wayland"),
  ("lockScreen.showWeather", "Weather", "boolean", [], "wayland"),
  ("lockScreen.showMedia", "Media title and artist", "boolean", [], "wayland"),
  ("lockScreen.showMediaArtwork", "Media artwork", "boolean", [], "wayland"),
  ("lockScreen.wallpaperBlur", "Wallpaper blur size", "number", [0, 20], "wayland"),
  ("lockScreen.wallpaperBlurPasses", "Wallpaper blur passes", "number", [0, 6], "wayland"),
  ("lockScreen.wallpaperBrightness", "Wallpaper brightness (%)", "number", [30, 100], "wayland"),
  ("wallpaper.startupMode", "Wallpaper at login", "choice", ["random", "restore"], ""),
  ("wallpaper.folder", "Random wallpaper folder", "text", [], ""),
  ("power.lowWarningEnabled", "Low-battery warning", "boolean", [], ""),
  ("power.lowThreshold", "Low-battery threshold (%)", "number", [1, 50], ""),
  ("power.criticalWarningEnabled", "Critical-battery warning", "boolean", [], ""),
  ("power.criticalThreshold", "Critical threshold (%)", "number", [1, 50], ""),
  ("power.urgentWarningEnabled", "Urgent-battery warning", "boolean", [], ""),
  ("power.urgentThreshold", "Urgent threshold (%)", "number", [1, 50], ""),
  ("power.finalWarningEnabled", "Final-battery warning", "boolean", [], ""),
  ("power.finalThreshold", "Final threshold (%)", "number", [1, 50], ""),
  ("connectivity.wifiSuggestions", "Suggest stronger saved Wi-Fi", "boolean", [], ""),
  ("connectivity.weakThreshold", "Weak-signal threshold (%)", "number", [1, 90], ""),
  ("connectivity.recoveryThreshold", "Rearm suggestions above (%)", "number", [2, 100], ""),
  ("connectivity.suggestionDelaySeconds", "Weak signal before suggesting (seconds)", "number", [5, 300], ""),
  ("connectivity.minimumImprovement", "Minimum signal improvement (percentage points)", "number", [1, 50], ""),
  ("display.dayTemperature", "Day temperature (K)", "number", [2500, 10000], ""),
  ("display.nightTemperature", "Night temperature (K)", "number", [2500, 10000], ""),
  ("display.latitude", "Sunrise/sunset latitude", "number", [-90, 90], ""),
  ("display.longitude", "Sunrise/sunset longitude", "number", [-180, 180], ""),
  ("display.brightnessStep", "Brightness key step (%)", "number", [1, 25], ""),
  ("display.osdDurationMs", "On-screen indicator duration (ms)", "number", [500, 10000], ""),
  ("idle.dimSeconds", "Dim after (seconds; 0 disables)", "number", [0, 86400], "wayland"),
  ("idle.lockSeconds", "Lock after (seconds)", "number", [60, 86400], "wayland"),
  ("idle.screenOffSeconds", "Screen off after (seconds; 0 disables)", "number", [0, 86400], "wayland"),
  ("idle.x11LockSeconds", "Lock after (seconds; whole minutes)", "number", [60, 3600], "x11"),
  ("idle.x11ScreenOffSeconds", "Screen off after (seconds; 0 disables)", "number", [0, 65535], "x11"),
  ("idle.deferFullscreen", "Defer locking during fullscreen", "boolean", [], ""),
  ("idle.deferMicrophone", "Defer locking during microphone use", "boolean", [], "wayland"),
  ("idle.deferCamera", "Defer locking during camera use", "boolean", [], "wayland"),
  ("input.repeatDelay", "Key repeat delay (ms)", "number", [100, 2000], ""),
  ("input.repeatRate", "Key repeats per second", "number", [1, 100], ""),
  ("input.sensitivity", "Pointer sensitivity", "number", [-1, 1], "wayland"),
  ("input.acceleration", "Pointer acceleration", "choice", ["flat", "adaptive"], "wayland"),
  ("input.naturalScroll", "Mouse natural scrolling", "boolean", [], "wayland"),
  ("input.touchpadNaturalScroll", "Touchpad natural scrolling", "boolean", [], "wayland"),
  ("input.tapToClick", "Tap to click", "boolean", [], "wayland"),
  ("input.disableWhileTyping", "Disable touchpad while typing", "boolean", [], "wayland"),
  ("weather.locationMode", "Weather location", "choice", ["automatic", "fixed"], ""),
  ("weather.city", "Fixed city (city,country code)", "text", [], ""),
  ("weather.units", "Weather units", "choice", ["metric", "imperial"], ""),
  ("clock.hourFormat", "Clock format", "choice", ["24", "12"], ""),
  ("clock.dateFormat", "Date format", "choice", ["dd MMM - dddd", "ddd, d MMM", "yyyy-MM-dd"], ""),
  ("clock.firstDay", "First day of week", "choice", [1, 0], ""),
  ("desktop.density", "Bar sizing", "choice", ["comfortable", "compact"], ""),
  ("desktop.hoverPreviews", "Open panels on hover", "boolean", [], ""),
  ("desktop.hoverCloseDelayMs", "Hover close grace period (ms)", "number", [200, 2000], ""),
]
NOTIFICATIONS = {
  "soundFilePath": (str, None), "popupCorner": (str, ["top-right", "top-left", "bottom-right", "bottom-left"]),
  "popupDurationSeconds": (int, [0, 5, 10, 20, 30, 60]), "popupMonitor": (str, None),
  "popupPreviews": (bool, None), "lockScreenPrivacy": (str, ["show", "redact", "hide"]),
  "historyRetentionDays": (int, [0, 1, 7, 30]), "doNotDisturb": (bool, None),
  "dndScheduleEnabled": (bool, None), "dndStartMinutes": (int, range(1440)),
  "dndEndMinutes": (int, range(1440)), "dndScheduleDays": (int, range(1, 128)),
  "notificationSoundsMuted": (bool, None), "allowCriticalDuringDnd": (bool, None),
  "applications": (list, None),
}


def validate(data):
  if not isinstance(data, dict) or type(data.get("version")) is not int or data["version"] != 1:
    raise ValueError("Unsupported preferences version")
  allowed = {"version", "notifications"} | {field[0].split('.')[0] for field in FIELDS}
  if set(data) - allowed:
    raise ValueError("Unknown preferences section")
  for key, _, kind, values, _ in FIELDS:
    section, name = key.split('.')
    value = data[section][name]
    valid = (kind == "boolean" and type(value) is bool
      or kind == "text" and isinstance(value, str) and 0 < len(value) <= 200 and not any(ord(c) < 32 for c in value)
      or kind == "choice" and type(value) is type(values[0]) and value in values
      or kind == "number" and type(value) in (int, float) and values[0] <= value <= values[1])
    if not valid:
      raise ValueError(f"Invalid value for {key}")
    if kind == "number" and name not in ("latitude", "longitude", "sensitivity") and type(value) is not int:
      raise ValueError(f"{key} must be a whole number")
  for section in allowed - {"version", "notifications"}:
    names = {key.split('.')[1] for key, *_ in FIELDS if key.startswith(section + '.')}
    if set(data[section]) - names:
      raise ValueError(f"Unknown key in {section}")
  if data["idle"]["x11LockSeconds"] % 60:
    raise ValueError("X11 lock delay must be a whole number of minutes")
  p = data['power']
  if not p['lowThreshold'] > p['criticalThreshold'] > p['urgentThreshold'] > p['finalThreshold']:
    raise ValueError('Battery thresholds must descend: low > critical > urgent > final')
  if data['connectivity']['recoveryThreshold'] <= data['connectivity']['weakThreshold']:
    raise ValueError('Wi-Fi recovery threshold must be greater than the weak threshold')
  if not isinstance(data['notifications'], dict):
    raise ValueError('notifications must be an object')
  for key, value in data["notifications"].items():
    if key not in NOTIFICATIONS:
      raise ValueError(f"Unknown notification preference: {key}")
    kind, values = NOTIFICATIONS[key]
    if type(value) is not kind or values is not None and value not in values:
      raise ValueError(f"Invalid notification preference: {key}")
    if key == "applications":
      seen = set()
      for app in value:
        if not isinstance(app, dict) or set(app) != {"key", "appName", "enabled", "sound"} or not all(isinstance(app[k], str) for k in ("key", "appName")) or not all(type(app[k]) is bool for k in ("enabled", "sound")):
          raise ValueError("Invalid application preference")
        if not app['appName'].strip() or app['key'] != app['appName'].strip().lower() or app['key'] in seen:
          raise ValueError('Application keys must be unique normalized app names')
        seen.add(app['key'])
  return data


def load():
  return validate(json.loads(PREFERENCES.read_text()))


def atomic_write(path, text):
  path.parent.mkdir(parents=True, exist_ok=True)
  fd, name = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name)
  try:
    with os.fdopen(fd, 'w') as stream:
      stream.write(text)
      stream.flush()
      os.fsync(stream.fileno())
    os.chmod(name, 0o644)
    os.replace(name, path)
  finally:
    if os.path.exists(name):
      os.unlink(name)


def update(changes):
  if not isinstance(changes, dict) or not all(isinstance(key, str) and key.count('.') == 1 for key in changes):
    raise ValueError('patch must be an object with section.key names')
  # One lock across read/merge/validate/rename prevents simultaneous UI/CLI edits losing keys.
  lock = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"dotfiles-settings-{os.getuid()}.lock"
  with lock.open('a') as stream:
    fcntl.flock(stream, fcntl.LOCK_EX)
    data = load()
    for key, value in changes.items():
      section, name = key.split('.', 1)
      data[section][name] = value
    validate(data)
    atomic_write(PREFERENCES, json.dumps(data, indent=2, ensure_ascii=False) + '\n')
  return data


def run(*args):
  result = subprocess.run(args, capture_output=True, text=True, timeout=15)
  if result.returncode:
    raise RuntimeError(f"{args[0]}: {(result.stderr or result.stdout).strip() or 'command failed'}")


def night_config(data):
  d = data['display']
  path = CACHE / 'gammastep.ini'
  atomic_write(path, f"[general]\ntemp-day={d['dayTemperature']}\ntemp-night={d['nightTemperature']}\nlocation-provider=manual\n[manual]\nlat={d['latitude']}\nlon={d['longitude']}\n")
  return path


def idle_config(data):
  d = data['idle']
  path = CACHE / 'hypridle.conf'
  text = "general {\n  lock_cmd = u_exit lock\n  before_sleep_cmd = u_lock-before-sleep\n  after_sleep_cmd = hyprctl dispatch dpms on\n  ignore_dbus_inhibit = false\n}\n"
  listeners = [(d['dimSeconds'], 'u_backlight dim', 'u_backlight restore'),
    (d['lockSeconds'] - 60, 'u_autolocking warn 60', 'u_autolocking clear-warning'),
    (d['lockSeconds'] - 10, 'u_autolocking warn 10', 'u_autolocking clear-warning'),
    (d['lockSeconds'], 'u_autolocking lock', ''),
    (d['screenOffSeconds'], 'hyprctl dispatch dpms off', 'hyprctl dispatch dpms on')]
  for seconds, action, resume in listeners:
    if seconds > 0:
      text += f"listener {{\n  timeout = {seconds}\n  on-timeout = {action}\n"
      if resume:
        text += f"  on-resume = {resume}\n"
      text += "}\n"
  atomic_write(path, text)
  return path


def apply(data, section):
  if section not in ('all', 'display', 'input', 'idle'):
    raise ValueError('Unknown apply section')
  session = os.environ.get('XDG_SESSION_TYPE', '')
  if section in ('all', 'display'):
    night_config(data)
    run('systemctl', '--user', 'daemon-reload')
    run('systemctl', '--user', 'try-restart', 'gammastep.service')
  if section in ('all', 'input'):
    d = data['input']
    if session == 'wayland':
      options = {'repeat_delay': d['repeatDelay'], 'repeat_rate': d['repeatRate'],
        'sensitivity': d['sensitivity'], 'accel_profile': d['acceleration'],
        'natural_scroll': d['naturalScroll'], 'touchpad:natural_scroll': d['touchpadNaturalScroll'],
        'touchpad:tap-to-click': d['tapToClick'], 'touchpad:disable_while_typing': d['disableWhileTyping']}
      # Hyprland's option is tap-to-click in hyprctl, tap_to_click in the Lua configuration API.
      for key, value in options.items():
        run('hyprctl', 'keyword', 'input:' + key, str(value).lower())
    elif session == 'x11':
      run('xset', 'r', 'rate', str(d['repeatDelay']), str(d['repeatRate']))
  if section in ('all', 'idle'):
    if session in ('wayland', 'x11'):
      # A pending deferred lock belongs to the previous idle period/policy.
      run('u_autolocking', 'clear-warning')
    if session == 'wayland':
      path = idle_config(data)
      running = subprocess.run(['pgrep', '-u', str(os.getuid()), '-x', 'hypridle'], capture_output=True).returncode == 0
      if running:
        run('pkill', '-u', str(os.getuid()), '-x', 'hypridle')
        for _ in range(40):
          if subprocess.run(['pgrep', '-u', str(os.getuid()), '-x', 'hypridle'], capture_output=True).returncode != 0:
            break
          time.sleep(0.05)
        else:
          raise RuntimeError('Preferences saved, but hypridle did not stop. Restart the session to apply idle settings.')
        process = subprocess.Popen(['hypridle', '-c', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(0.1)
        if process.poll() is not None:
          raise RuntimeError('Preferences saved, but hypridle failed to start.')
    elif session == 'x11':
      run('systemctl', '--user', 'daemon-reload')
      run('systemctl', '--user', 'try-restart', 'xautolock.service')
      run('xset', 'dpms', str(data['idle']['x11ScreenOffSeconds']), '0', '0')


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('command', choices=['get', 'describe', 'set', 'patch', 'validate', 'apply', 'run-idle', 'run-night-light'])
  parser.add_argument('key', nargs='?')
  parser.add_argument('value', nargs='?')
  args = parser.parse_args()
  data = load()
  if args.command == 'describe':
    print(json.dumps({'data': data, 'fields': [dict(zip(['key', 'label', 'kind', 'values', 'session'], f)) for f in FIELDS]}))
  elif args.command == 'get':
    for key in args.key.split('.') if args.key else []:
      data = data[key]
    print(json.dumps(data, ensure_ascii=False))
  elif args.command in ('set', 'patch'):
    changes = {args.key: json.loads(args.value)} if args.command == 'set' else json.loads(args.key)
    print(json.dumps(update(changes)))
  elif args.command == 'apply':
    apply(data, args.key or 'all')
  elif args.command == 'run-night-light':
    os.execvp('gammastep', ['gammastep', '-c', str(night_config(data))])
  elif args.command == 'run-idle':
    if os.environ.get('XDG_SESSION_TYPE') == 'wayland':
      os.execvp('hypridle', ['hypridle', '-c', str(idle_config(data))])
    seconds = data['idle']['x11LockSeconds']
    run('xset', 'dpms', str(data['idle']['x11ScreenOffSeconds']), '0', '0')
    os.execvp('xautolock', ['xautolock', '-time', str(seconds // 60), '-locker', 'u_autolocking lock', '-detectsleep', '-corners', '----', '-notify', '10', '-notifier', 'u_autolocking warn 10'])


if __name__ == '__main__':
  try:
    main()
  except (ValueError, KeyError, TypeError, OSError, RuntimeError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)

#!/usr/bin/env python3
"""Wallpaper actions sharing the existing ~/wallpaper.png and native backends."""
import argparse
import errno
import filecmp
import json
import os
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse

from settings import load, run

EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif'}


def local_path(value):
  if value.startswith('file:'):
    url = urlparse(value)
    if url.netloc not in ('', 'localhost'):
      raise ValueError('Wallpaper must be a local file')
    value = unquote(url.path)
  return Path(value).expanduser()


def restore():
  path = Path.home() / 'wallpaper.png'
  if not path.is_file():
    raise ValueError('No saved wallpaper. Choose an image or use Random now.')
  if os.environ.get('XDG_SESSION_TYPE') == 'wayland':
    run('awww', 'img', str(path), '--resize', 'crop', '--transition-type', 'wipe')
  else:
    run('xwallpaper', '--zoom', str(path))


def choose(path, skip_current=False):
  path = local_path(str(path))
  if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
    raise ValueError('Choose a supported image file')
  destination = Path.home() / 'wallpaper.png'
  fd, name = tempfile.mkstemp(prefix='.wallpaper-', dir=Path.home())
  os.close(fd)
  backup = None
  try:
    shutil.copyfile(path, name)
    if skip_current and destination.is_file() and filecmp.cmp(name, destination, shallow=False):
      return False
    if destination.is_file():
      fd, backup = tempfile.mkstemp(prefix='.wallpaper-backup-', dir=Path.home())
      os.close(fd)
      shutil.copyfile(destination, backup)
    os.replace(name, destination)
    try:
      restore()
    except (OSError, RuntimeError, ValueError):
      if backup:
        os.replace(backup, destination)
      else:
        destination.unlink(missing_ok=True)
      raise
    return True
  finally:
    Path(name).unlink(missing_ok=True)
    if backup:
      Path(backup).unlink(missing_ok=True)


def screen_size():
  try:
    if os.environ.get('XDG_SESSION_TYPE') == 'wayland':
      monitors = json.loads(subprocess.check_output(['hyprctl', 'monitors', '-j'], text=True, stderr=subprocess.DEVNULL))
      monitor = next((m for m in monitors if m.get('focused')), monitors[0])
      return int(monitor['width']), int(monitor['height'])
    output = subprocess.check_output(['xrandr', '--current'], text=True, stderr=subprocess.DEVNULL)
    connected = [line for line in output.splitlines() if re.search(r'\bconnected\b', line) and ' disconnected' not in line]
    line = next((line for line in connected if ' primary ' in line), connected[0])
    size = re.search(r'\b(\d+)x(\d+)\+\d+\+\d+', line)
    if size:
      return int(size[1]), int(size[2])
  except (OSError, subprocess.CalledProcessError, ValueError, IndexError, KeyError, TypeError):
    pass
  return None


def suitable_images(images, width, height):
  def fits(image_width, image_height):
    # Allow a little cropping, but avoid upscaling or losing much of the image.
    return (image_width >= width and image_height >= height and image_width and image_height
            and min(image_width * height, image_height * width) / max(image_width * height, image_height * width) >= 0.85)

  suitable = []
  # Bound command-line length for large wallpaper collections.
  for offset in range(0, len(images), 128):
    batch = images[offset:offset + 128]
    by_name = {str(image): image for image in batch if '\n' not in str(image)}
    try:
      result = subprocess.run(
        ['magick', 'identify', '-ping', '-format', '%i\t%w %h\n',
         *(name + '[0]' for name in by_name)],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
      continue
    # ImageMagick can report a bad image while still returning dimensions for
    # the other files in the batch. Match by name rather than output position.
    for line in result.stdout.splitlines():
      name, separator, dimensions = line.rpartition('\t')
      if not separator or name not in by_name:
        continue
      try:
        image_width, image_height = map(int, dimensions.split())
      except ValueError:
        continue
      if fits(image_width, image_height):
        suitable.append(by_name[name])
    # Newlines in filenames cannot be unambiguously parsed from identify's
    # line-oriented output; inspect those rare images separately.
    for image in batch:
      if '\n' not in str(image):
        continue
      try:
        dimensions = subprocess.check_output(
          ['magick', 'identify', '-ping', '-format', '%w %h', str(image) + '[0]'],
          text=True, stderr=subprocess.DEVNULL)
        image_width, image_height = map(int, dimensions.split())
        if fits(image_width, image_height):
          suitable.append(image)
      except (OSError, subprocess.CalledProcessError, ValueError, ZeroDivisionError):
        continue
  return suitable


def random_wallpaper(folder):
  folder = local_path(folder)
  if not folder.is_dir():
    raise ValueError('Wallpaper folder does not exist: ' + str(folder))
  images = sorted(p for p in folder.rglob('*') if p.is_file() and p.suffix.lower() in EXTENSIONS)
  if not images:
    raise ValueError('No supported images in wallpaper folder')
  size = screen_size()
  matching = suitable_images(images, *size) if size and all(size) else []
  candidates = list(matching)
  random.shuffle(candidates)
  remaining = [image for image in images if image not in matching]
  random.shuffle(remaining)
  candidates.extend(remaining)
  last_error = None
  for image in candidates:
    try:
      if choose(image, skip_current=True):
        return image
    except OSError as error:
      # SeaDrive can expose an image's header but fail while reading the full
      # file. Try another candidate, without hiding local write/backend errors.
      if error.errno != errno.EIO or error.filename != str(image):
        raise
      last_error = error
  if last_error:
    raise last_error
  raise ValueError('No different wallpaper found in wallpaper folder')


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('action', choices=['startup', 'restore', 'random', 'choose'])
  parser.add_argument('path', nargs='?')
  args = parser.parse_args()
  preferences = load()['wallpaper']
  if args.action == 'choose':
    if not args.path:
      raise ValueError('Choose requires an image path')
    choose(args.path)
    selected = local_path(args.path)
  elif args.action == 'restore' or args.action == 'startup' and preferences['startupMode'] == 'restore':
    restore()
    selected = Path.home() / 'wallpaper.png'
  else:
    selected = random_wallpaper(args.path or preferences['folder'])
  print(selected)


if __name__ == '__main__':
  try:
    main()
  except (OSError, ValueError, RuntimeError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)

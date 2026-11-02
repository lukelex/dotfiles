#!/usr/bin/env python3
"""Wallpaper actions sharing the existing ~/wallpaper.png and native backends."""
import argparse
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


def choose(path):
  path = local_path(str(path))
  if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
    raise ValueError('Choose a supported image file')
  destination = Path.home() / 'wallpaper.png'
  fd, name = tempfile.mkstemp(prefix='.wallpaper-', dir=Path.home())
  os.close(fd)
  backup = None
  try:
    shutil.copyfile(path, name)
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
  suitable = []
  for image in images:
    try:
      dimensions = subprocess.check_output(
        ['magick', 'identify', '-ping', '-format', '%w %h', str(image) + '[0]'],
        text=True, stderr=subprocess.DEVNULL)
      image_width, image_height = map(int, dimensions.split())
      # Allow a little cropping, but avoid upscaling or losing much of the image.
      if (image_width >= width and image_height >= height
          and min(image_width * height, image_height * width) / max(image_width * height, image_height * width) >= 0.85):
        suitable.append(image)
    except (OSError, subprocess.CalledProcessError, ValueError, ZeroDivisionError):
      continue
  return suitable


def random_wallpaper(folder):
  folder = local_path(folder)
  if not folder.is_dir():
    raise ValueError('Wallpaper folder does not exist: ' + str(folder))
  images = sorted(p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS)
  if not images:
    raise ValueError('No supported images in wallpaper folder')
  size = screen_size()
  matching = suitable_images(images, *size) if size and all(size) else []
  choose(random.choice(matching or images))


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
  elif args.action == 'restore' or args.action == 'startup' and preferences['startupMode'] == 'restore':
    restore()
  else:
    random_wallpaper(args.path or preferences['folder'])


if __name__ == '__main__':
  try:
    main()
  except (OSError, ValueError, RuntimeError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)

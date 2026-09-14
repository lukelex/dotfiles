#!/usr/bin/bash

replace_existing=0
for arg in "$@"; do
  [ "$arg" = "--replace" ] && replace_existing=1
done

link_config() {
  local source="$1"
  local target="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      echo "ok: $target -> $source"
    elif [ -e "$target" ] || [ -L "$target" ]; then
      if [ "$replace_existing" = 1 ]; then
        echo "dry-run: would replace $target -> $source"
      else
        echo "dry-run: would skip $target (not a repo link; --replace to overwrite)"
      fi
    else
      echo "dry-run: would link $target -> $source"
    fi
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "ok: $target -> $source"
  elif [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$replace_existing" = 1 ]; then
      rm -rf "$target"
      ln -s "$source" "$target"
      echo "replaced: $target -> $source"
    else
      echo "skipping $target: exists and is not a repo link; rerun with --replace to overwrite" >&2
    fi
  else
    ln -s "$source" "$target"
    echo "linked: $target -> $source"
  fi
}

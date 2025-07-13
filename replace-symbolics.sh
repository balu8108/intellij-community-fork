#!/bin/bash

set -euo pipefail

ROOT_DIR="${1:-.}"  # Default to current directory

echo "🔍 Scanning for symbolic links in: $ROOT_DIR"

find "$ROOT_DIR" -type l | while read -r symlink; do
  target=$(readlink "$symlink")

  if [ -z "$target" ]; then
    echo "⚠️  Skipping broken symlink: $symlink"
    continue
  fi

  # Resolve full path relative to symlink's location
  real_target="$(cd "$(dirname "$symlink")" && realpath "$target")"

  if [ ! -e "$real_target" ]; then
    echo "⚠️  Skipping missing target: $real_target"
    continue
  fi

  echo "🔧 Replacing symlink: $symlink → $real_target"

  rm "$symlink"

  if [ -d "$real_target" ]; then
    cp -a "$real_target" "$symlink"
  else
    cp -p "$real_target" "$symlink"
  fi

  echo "✅ Replaced: $symlink"
done

echo "🎉 All symlinks replaced with actual files/directories."

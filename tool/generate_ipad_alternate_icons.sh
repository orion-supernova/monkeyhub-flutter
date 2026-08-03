#!/usr/bin/env bash
# Derives the iPad variants of every iOS alternate icon from its @3x (180px)
# artwork.
#
# App Store validation (ITMS-90892) wants an alternate icon at exactly 152x152
# (iPad, 76pt @2x) and 167x167 (iPad Pro, 83.5pt @2x) for every entry in
# Info.plist's CFBundleAlternateIcons. Without them the delivery still goes
# through, but Apple warns on every upload.
#
# Naming follows the convention actool uses for the primary icon, so
# CFBundleIconFiles entries resolve without extensions:
#   <name>76x76@2x~ipad.png       152x152
#   <name>83.5x83.5@2x~ipad.png   167x167
#
# Safe to re-run — existing files are overwritten.
#
# Usage:
#   ./tool/generate_ipad_alternate_icons.sh
#   ruby tool/setup_ios_alternate_icons.rb   # then register them with Xcode

set -euo pipefail

icons_dir="$(cd "$(dirname "$0")/.." && pwd)/ios/Runner/AlternateIcons"

if [[ ! -d "$icons_dir" ]]; then
  echo "AlternateIcons directory not found at $icons_dir — nothing to do." >&2
  exit 0
fi

generated=0
for src in "$icons_dir"/*@3x.png; do
  [[ -e "$src" ]] || continue
  base="$(basename "$src")"
  name="${base%@3x.png}"

  for spec in "76x76:152" "83.5x83.5:167"; do
    point="${spec%%:*}"
    px="${spec##*:}"
    out="$icons_dir/${name}${point}@2x~ipad.png"
    sips -s format png -z "$px" "$px" "$src" --out "$out" >/dev/null
    generated=$((generated + 1))
  done
done

echo "[generate_ipad_alternate_icons] wrote $generated files to $icons_dir"

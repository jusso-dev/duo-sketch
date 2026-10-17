#!/usr/bin/env bash
# Copies the screenshots attached by ScreenshotTests out of a result bundle,
# named after their attachment (for example 2-finished-drawing.png).
#
#   scripts/export_screenshots.sh App/build/TestResults.xcresult Screenshots/iphone-duo
set -euo pipefail

result="$1"
dest="$2"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

xcrun xcresulttool export attachments --path "$result" --output-path "$tmp" >/dev/null
mkdir -p "$dest"
# Drop the shots from an earlier export so a missing one can't pass as current.
rm -f "$dest"/[0-9]-*.png
python3 - "$tmp" "$dest" <<'PY'
import json, os, re, shutil, sys
src, dest = sys.argv[1], sys.argv[2]
count = 0
for test in json.load(open(os.path.join(src, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
        # Xcode adds "_0_<UUID>" to the name we gave the attachment.
        name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}", "", os.path.splitext(name)[0])
        if not re.match(r"^\d-", name):
            continue
        shutil.copy(os.path.join(src, a["exportedFileName"]), os.path.join(dest, name + ".png"))
        count += 1
if count == 0:
    raise SystemExit("No screenshots found in the result bundle.")
print(f"Exported {count} screenshots to {dest}")
PY

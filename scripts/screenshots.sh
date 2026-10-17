#!/usr/bin/env bash
# Regenerates the App Store screenshots into Screenshots/<device>/.
# Needs a Mac with Xcode 27.1 or later and XcodeGen. See docs/screenshots.md.
#
#   scripts/screenshots.sh                      # the default devices below
#   scripts/screenshots.sh "iPhone 17 Pro Max"  # just one device
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/Screenshots"
build="$root/App/build/screenshots"

if [ "$#" -gt 0 ]; then
  devices=("$@")
else
  # 6.9 inch iPhone, then iPhone Duo (inner display).
  devices=("iPhone 17 Pro Max" "iPhone Duo")
fi

cd "$root/App"
xcodegen generate >/dev/null

for device in "${devices[@]}"; do
  udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devs in sorted(json.load(sys.stdin)["devices"].items(), reverse=True):
    if "iOS" not in runtime:
        continue
    for d in devs:
        if d["name"] == name:
            print(d["udid"])
            raise SystemExit
raise SystemExit("No available simulator named " + repr(name) + ". Check xcrun simctl list devices available.")
' "$device")
  echo "== $device ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # Clean status bar: 9:41, full battery and signal.
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 --dataNetwork wifi

  slug=$(echo "$device" | tr '[:upper:] ' '[:lower:]-')
  result="$build/$slug.xcresult"
  rm -rf "$result" "$out/$slug"
  mkdir -p "$out/$slug"

  xcodebuild -project DuoSketch.xcodeproj -scheme DuoSketch \
    -destination "id=$udid" \
    -only-testing:DuoSketchUITests/ScreenshotTests \
    -resultBundlePath "$result" \
    CODE_SIGNING_ALLOWED=NO test | tail -n 5

  "$root/scripts/export_screenshots.sh" "$result" "$out/$slug"
  xcrun simctl status_bar "$udid" clear
done

echo "Screenshots are in $out"

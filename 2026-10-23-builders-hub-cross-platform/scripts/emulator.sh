#!/usr/bin/env bash
# Boot an Android emulator with a window, for D6, and wait until it is ready.
# A cold boot takes about 30 s: start it before the talk, not on stage.
#   emulator.sh              boots the first AVD in `emulator -list-avds`
#   emulator.sh <avd-name>   boots that one
# Stop it with: adb emu kill
set -euo pipefail
TALK_DIR="${TALK_DIR:-$HOME/talk}"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
EMULATOR="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"
LOG="$TALK_DIR/.emulator.log"
[[ -x "$EMULATOR" && -x "$ADB" ]] || { echo "emulator: no Android SDK at $SDK (set ANDROID_HOME)" >&2; exit 1; }

devices="$("$ADB" devices)"
if grep -q '^emulator-.*device$' <<<"$devices"; then
  echo "emulator: already running ($(grep '^emulator-' <<<"$devices" | cut -f1))"
  exit 0
fi
AVD="${1:-$("$EMULATOR" -list-avds | sed -n 1p)}"
[[ -n "$AVD" ]] || { echo "emulator: no AVD; create one in Android Studio's Device Manager" >&2; exit 1; }

echo "emulator: booting $AVD (log: $LOG)"
mkdir -p "$TALK_DIR"
# -no-snapshot-load: cold-boot every time, so a quick-boot snapshot that
#   fails to load can't stall the start.
# -no-snapshot-save: leave the AVD as it is when the emulator stops.
nohup "$EMULATOR" -avd "$AVD" -no-snapshot-load -no-snapshot-save -no-audio -no-boot-anim \
  >"$LOG" 2>&1 &
disown

"$ADB" wait-for-device
for ((i = 1; i <= 180; i++)); do
  if [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
    "$ADB" shell input keyevent 82 >/dev/null 2>&1 || true    # dismiss the lock screen
    "$ADB" shell svc power stayon true >/dev/null 2>&1 || true # keep the screen on
    echo "emulator: ready after ${i} s. In D6: $TALK_DIR/android.sh"
    exit 0
  fi
  sleep 1
done
echo "emulator: not booted after 180 s; see $LOG" >&2
exit 1

#!/usr/bin/env bash
# D6, optional: install and launch the finished Android app on the running
# emulator (emulator.sh). The APK is setup.sh's build of tutorial2-twins-complete.
set -euo pipefail
TALK_DIR="${TALK_DIR:-$HOME/talk}"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$(command -v adb || echo "$SDK/platform-tools/adb")"
APK="$TALK_DIR/.warm/tutorial2-twins-complete/src-android/app/build/outputs/apk/debug/app-debug.apk"
[[ -f "$APK" ]] || { echo "android: no APK at $APK; run setup.sh with the Android SDK installed" >&2; exit 1; }
"$ADB" install -r "$APK" >/dev/null
"$ADB" shell am start -n dev.modaal.foyer/dev.modaal.foyer.app.MainActivity

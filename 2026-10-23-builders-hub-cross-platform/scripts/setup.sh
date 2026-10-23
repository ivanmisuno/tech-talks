#!/usr/bin/env bash
# Prepare the stage folder for the live demo of "Cross-platform apps: iOS &
# Android with Claude and Modaal Studio" (Builders Hub, 2026-10-23).
# See ../SETUP.md.
#
#   scripts/setup.sh                     prepares ~/talk
#   TALK_DIR=~/stage scripts/setup.sh    prepares another folder
#
# Safe to run again: it keeps what is already in place and only rebuilds
# caches. It never touches $TALK_DIR/foyer, the tree D0 creates live.
set -euo pipefail

TALK_DIR="${TALK_DIR:-$HOME/talk}"
TUTORIALS_URL="${TUTORIALS_URL:-https://github.com/modaal-agent/duet-tutorials.git}"
# The duet-tutorials commit the talk ran on: Duet 0.7.0, duet-tools 0.34.0.
TUTORIALS_SHA=129a9925ee37073cb3081a810ea63af711d49171
DUET_VERSION=0.34.0
JDK=25
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALK_SRC="$(dirname "$HERE")"

step() { echo; echo "── setup · $*"; }
die() { echo "setup: $*" >&2; exit 1; }
commit() {
  # A fresh Mac may have no git identity; the demo trees' commits don't need one.
  if git config user.email >/dev/null; then git commit -qm "$1"
  else git -c user.name="Talk setup" -c user.email="setup@localhost" commit -qm "$1"; fi
}

# ── prerequisites
step "prerequisites"
[[ "$(uname -s) $(uname -m)" == "Darwin arm64" ]] \
  || die "needs a Mac with Apple silicon: the duet $DUET_VERSION release binary is macOS arm64 only"
for tool in git curl python3 rsync swift xcodebuild xcrun; do
  command -v "$tool" >/dev/null || die "$tool is not on PATH (install Xcode and its command line tools)"
done
command -v xcodegen >/dev/null || die "xcodegen is not on PATH (brew install xcodegen)"
JAVA_HOME="$(/usr/libexec/java_home -v "$JDK" 2>/dev/null || true)"
java_version="$("$JAVA_HOME/bin/java" -version 2>&1 || true)"
[[ "$java_version" == *"version \"$JDK"* ]] \
  || die "needs JDK $JDK, which the Kotlin replay runner is built for (/usr/libexec/java_home -v $JDK finds none)"
export JAVA_HOME
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [[ -x "$SDK/platform-tools/adb" ]]; then
  export ANDROID_HOME="$SDK"; android=1
else
  android=0
  echo "no Android SDK at $SDK: skipping the Android app (set ANDROID_HOME to include it)"
fi
echo "ok: Apple silicon, Xcode, xcodegen, JDK $JDK$( (( android )) && echo ", Android SDK" )"

# ── the tutorials, twice
# $1 = where from, $2 = the folder: a clone of duet-tutorials, checked out at the pin.
pinned_clone() {
  [[ -d "$2/.git" ]] || git clone -q "$1" "$2"
  if [[ "$(git -C "$2" rev-parse HEAD)" != "$TUTORIALS_SHA" ]]; then
    git -C "$2" cat-file -e "$TUTORIALS_SHA^{commit}" 2>/dev/null || git -C "$2" fetch -q origin
    git -C "$2" -c advice.detachedHead=false checkout -q "$TUTORIALS_SHA"
  fi
  echo "$2: $(git -C "$2" log --oneline -1)"
}
mkdir -p "$TALK_DIR"
cd "$TALK_DIR"
step "duet-tutorials at ${TUTORIALS_SHA:0:7}"
pinned_clone "$TUTORIALS_URL" duet-tutorials
# The demo copies files out of duet-tutorials, so nothing is built there. The
# finished trees are built in .warm, a second clone.
pinned_clone "$TALK_DIR/duet-tutorials" .warm

# ── the CLI, in one place, so no tree downloads it on stage
step "duet $DUET_VERSION CLI"
bin="$TALK_DIR/.duet-bin/$DUET_VERSION/duet"
if [[ "$("$bin" version 2>/dev/null || true)" != "duet $DUET_VERSION" ]]; then
  # tools/duet downloads the release binary into the tree's .duet-family/ ...
  tree=.warm/tutorial2-twins-complete
  (cd "$tree" && env -u DUET_BIN -u DUET_TOOLS_HOME tools/duet version >/dev/null)
  cached="$tree/.duet-family/duet-bin/$DUET_VERSION/duet"
  # ... unless a duet on PATH outranks the download.
  [[ -x "$cached" ]] || cached="$(command -v duet || true)"
  [[ "$("$cached" version 2>/dev/null || true)" == "duet $DUET_VERSION" ]] \
    || die "could not get duet $DUET_VERSION (see tools/duet in any tree)"
  mkdir -p "$(dirname "$bin")"
  cp "$cached" "$bin"
fi
export DUET_BIN="$bin"
echo "$("$bin" version): $bin"

# ── warm-up: the finished trees, checked the way CI checks them
step "warm-up: the finished trees (the first run takes several minutes)"
.warm/scripts/run-tree.sh tutorial1-swift-complete --lane macos
.warm/scripts/run-tree.sh tutorial2-twins-complete --lane macos
if (( android )); then
  .warm/scripts/run-tree.sh tutorial2-twins-complete --lane android
fi

# ── the stage files
step "stage files"
cp "$HERE/env.sh" "$HERE/reset.sh" "$HERE/emulator.sh" "$HERE/android.sh" "$TALK_DIR/"
chmod +x "$TALK_DIR/reset.sh" "$TALK_DIR/emulator.sh" "$TALK_DIR/android.sh"
cp "$TALK_SRC/AGENTS.md" "$TALK_SRC/prompts.md" "$TALK_SRC/DEMO.md" "$TALK_DIR/"
echo "env.sh reset.sh emulator.sh android.sh AGENTS.md prompts.md DEMO.md → $TALK_DIR"

# ── foyer-twins: the tree for D3–D5
step "foyer-twins, the tree for D3–D5"
if git -C foyer-twins rev-parse -q --verify refs/tags/prepared >/dev/null 2>&1; then
  echo "foyer-twins: already prepared ($(git -C foyer-twins log --oneline -1 prepared)); reset.sh returns it there"
else
  [[ ! -e foyer-twins ]] || die "$TALK_DIR/foyer-twins exists without the 'prepared' tag: move it aside, then run setup again"
  # Twins Tutorial 2 starts from the Swift tree. Tracked files only.
  mkdir foyer-twins
  git -C duet-tutorials archive "$TUTORIALS_SHA:tutorial2-twins-start" | tar -x -C foyer-twins
  (
    cd foyer-twins
    git init -q -b main && git add -A && commit start
    # The tutorial's steps 1 and 6, done ahead of the talk: the Gradle build
    # plane and the replay runner, from the finished tree. D3 writes the rest.
    complete=../duet-tutorials/tutorial2-twins-complete/src-android
    mkdir -p src-android/subtrees/splash/logic
    rsync -a --exclude build --exclude .gradle --exclude .kotlin \
      "$complete"/{gradlew,gradlew.bat,gradle,gradle.properties,build.gradle.kts,replay-runner} src-android/
    cp "$complete/subtrees/splash/logic/build.gradle.kts" src-android/subtrees/splash/logic/
    # Its settings without the Android app module: D3 builds the JVM modules only.
    grep -vE '^// The Android app:|^include\(":app"\)' "$complete/settings.gradle.kts" >src-android/settings.gradle.kts
    python3 - <<'EOF'
import pathlib
p = pathlib.Path("parity/manifest.yaml")
s = p.read_text()
anchor = "replayRunner: src-ios/Libraries/Replay\n\n"
assert s.count(anchor) == 1, "parity/manifest.yaml: no replayRunner line to anchor on"
p.write_text(s.replace(anchor, anchor
    + "# Every Kotlin module in this tree is a plain JVM module (src/main, src/test):\n"
    + "# the iPhone app runs the Swift twin and links no Kotlin.\n"
    + "kotlinCore: jvm\n\n"))
EOF
    { printf '# Gradle / JVM\n.gradle/\nbuild/\nlocal.properties\n.kotlin/\n\n'; cat .gitignore; } >.gitignore.new
    mv .gitignore.new .gitignore
    git add -A && commit "Kotlin build plane and replay runner (Twins Tutorial steps 1 and 6, prepared)"
    cp "$TALK_SRC/AGENTS.md" . && git add AGENTS.md && commit "Rules for agents"
    git tag prepared
  )
  echo "foyer-twins: $(git -C foyer-twins log --oneline -1), tagged prepared"
fi

step "warm foyer-twins: Gradle, verify, mocks, the Swift replay runner"
(
  cd foyer-twins
  # The splash module only: it has no sources yet, and the replay runner
  # imports the Kotlin twin, which D3 writes.
  (cd src-android && ./gradlew --console=plain -q :subtrees:splash:logic:compileKotlin)
  tools/duet lint
  TUTORIAL_SKIP_STUBS=1 tools/duet verify
  tools/duet mocks >/dev/null && git checkout -q -- .
  (cd src-ios/Libraries/Replay && swift build -q)
)

# ── the finished iPhone app, for D6
step "the finished iPhone app, for D6"
(
  cd .warm/tutorial2-twins-complete
  (cd src-ios/App && xcodegen generate --spec xcodegen.yml -q)
  xcodebuild build -project src-ios/App/Foyer.xcodeproj -scheme Foyer \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath build -quiet
)
app="$TALK_DIR/.warm/tutorial2-twins-complete/build/Build/Products/Debug-iphonesimulator/Foyer.app"
booted="$(xcrun simctl list devices booted)"
if [[ "$booted" == *"(Booted)"* ]]; then
  xcrun simctl install booted "$app"
  echo "Foyer.app: installed on the booted simulator"
else
  echo "Foyer.app: no simulator is booted. Boot one, then: xcrun simctl install booted '$app'"
fi
if (( android )); then
  echo "app-debug.apk: built; android.sh installs it on the running emulator"
fi

step "done in $((SECONDS / 60)) min $((SECONDS % 60)) s"
[[ "$TALK_DIR" == "$HOME/talk" ]] || echo "Export TALK_DIR=$TALK_DIR in each terminal tab first."
cat <<EOF
Before each run of the demo:
  $TALK_DIR/reset.sh
  source $TALK_DIR/env.sh     (in each terminal tab)
For the Android app in D6, boot the emulator early: $TALK_DIR/emulator.sh
The demo, step by step: $TALK_DIR/DEMO.md
EOF

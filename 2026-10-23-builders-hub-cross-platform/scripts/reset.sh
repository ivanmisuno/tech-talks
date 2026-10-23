#!/usr/bin/env bash
# Reset the stage folder for a fresh run of the live demo. Run it before each
# rehearsal and before the talk. Build caches (.build, Gradle) are kept.
set -euo pipefail
TALK_DIR="${TALK_DIR:-$HOME/talk}"
cd "$TALK_DIR"
if [[ -d foyer ]]; then
  echo "reset: removing $TALK_DIR/foyer (D0 recreates it live)"
  rm -rf foyer
fi
git -C foyer-twins reset -q --hard prepared
git -C foyer-twins clean -qfd    # untracked files only; ignored build caches stay
echo "reset: foyer-twins at $(git -C foyer-twins log --oneline -1)"
xcrun simctl terminate booted dev.modaal.foyer 2>/dev/null || true
echo "reset: done. In each terminal tab: source $TALK_DIR/env.sh && unset TUTORIAL_SKIP_STUBS"

# Source this in each terminal tab before the demo:  source ~/talk/env.sh
#   TALK_DIR   the stage folder. Export it first if it isn't ~/talk.
#   DUET_BIN   the duet 0.34.0 CLI that setup.sh put there, so no tree
#              downloads it on stage.
#   JAVA_HOME  JDK 25. The Kotlin replay runner is built for 25; under an
#              older JDK, protocol-run fails with "no valid handshake".
export TALK_DIR="${TALK_DIR:-$HOME/talk}"
export DUET_BIN="$TALK_DIR/.duet-bin/0.34.0/duet"
export JAVA_HOME="$(/usr/libexec/java_home -v 25)"
echo "duet: $("$DUET_BIN" version 2>&1 | head -1) · java: $("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"

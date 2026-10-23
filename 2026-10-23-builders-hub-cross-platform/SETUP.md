# Setup

How to reproduce the live demo, or just build and run the finished apps. The demo itself, step by step, is in [DEMO.md](DEMO.md).

## Requirements

| Tool | Version used for the talk | Notes |
| --- | --- | --- |
| Mac with Apple silicon | macOS 26.6 | The duet CLI's release binary is macOS arm64 only |
| Xcode | 27.1 (Swift 6.4) | With an iOS Simulator runtime |
| XcodeGen | 2.44.1 | `brew install xcodegen` |
| JDK 25 | Temurin 25.0.4 | Required: the Kotlin replay runner is built for 25 |
| Android SDK with platform 36, and an emulator (AVD) | | Optional, for the Android app. Android Studio installs both; `ANDROID_HOME` defaults to `~/Library/Android/sdk` |
| [Claude Code](https://claude.com/claude-code) | | For the agent steps. Each one has a fallback that works without it |
| VS Code, with `code` on `PATH` | | Optional, for showing files |

Git, curl, Python 3 and rsync come with macOS and Xcode's command line tools.

## Prepare the stage folder

Boot an iOS simulator first, so the script can install the iPhone app. Then:

```bash
git clone https://github.com/ivanmisuno/tech-talks.git
```
```bash
tech-talks/2026-10-23-builders-hub-cross-platform/scripts/setup.sh
```

It prepares `~/talk`. To use another folder, run it as `TALK_DIR=~/stage tech-talks/…/setup.sh`, and export `TALK_DIR` in each terminal tab before you source `env.sh`. [DEMO.md](DEMO.md) writes `~/talk`; substitute your folder.

The first run takes about 4 minutes on a Mac whose Gradle and SwiftPM caches are already warm. On a fresh Mac it also downloads Gradle, the Kotlin and Android dependencies and the Swift packages, so allow longer. It needs about 2 GB of disk. Later runs keep what is in place and take about a minute and a half.

What it does:
1. Checks the requirements.
2. Clones [duet-tutorials](https://github.com/modaal-agent/duet-tutorials) and checks out the commit the talk ran on, `129a992` (Duet 0.7.0, duet-tools 0.34.0).
3. Copies the duet CLI to `.duet-bin/0.34.0/`, so no tree downloads it on stage.
4. Clones duet-tutorials again into `.warm`, and runs CI's checks there (`scripts/run-tree.sh`) on the finished trees `tutorial1-swift-complete` and `tutorial2-twins-complete`. That fills the SwiftPM, Gradle and Xcode caches. With the Android SDK, it also builds the Android app.
5. Prepares `foyer-twins`, the tree for D3–D5, then commits it, tags it `prepared` and warms it. The tree is three parts:
   - Twins Tutorial 2's start tree;
   - the Gradle build plane and the replay runner, from the finished tree;
   - `AGENTS.md`.
6. Builds the finished iPhone app and installs it on the booted simulator.
7. Copies the helper scripts, `AGENTS.md`, `prompts.md` and `DEMO.md` into the folder.

What ends up in `~/talk`:

| Path | What it is |
| --- | --- |
| `duet-tutorials/` | The pinned clone. The demo copies files out of it; nothing is built there |
| `.warm/` | A second clone, where the finished trees were built: the caches, the iPhone app and the Android APK |
| `.duet-bin/0.34.0/duet` | The duet CLI |
| `foyer-twins/` | The tree for D3–D5, tagged `prepared` |
| `foyer/` | Not there yet: D0 creates it live, and `reset.sh` deletes it |
| `env.sh` | Sets `DUET_BIN`, and `JAVA_HOME` to JDK 25. Source it in each terminal tab |
| `reset.sh` | Deletes `foyer/`, resets `foyer-twins` to `prepared`, and stops the iPhone app |
| `emulator.sh [avd]` | Boots an Android emulator with a window and waits until it's ready |
| `android.sh` | Installs and launches the finished Android app on the running emulator |
| `AGENTS.md`, `prompts.md`, `DEMO.md` | The rules for agents, the prompts, the demo walkthrough |

Before each run of the demo:

```bash
~/talk/reset.sh
```
```bash
source ~/talk/env.sh
```
For the Android app in D6, boot the emulator early (a cold boot takes about 30 s):
```bash
~/talk/emulator.sh
```

## Build and run the finished apps

This is the finished dual-core tree, `tutorial2-twins-complete`. A Swift core runs the iPhone app and a Kotlin/JVM core runs the Android app; the two cores share only the recordings.

The commands below run it in `~/talk/.warm`, where `setup.sh` already built it. Any checkout of duet-tutorials at `129a992` works the same. The timings are warm.

```bash
cd ~/talk/.warm/tutorial2-twins-complete && source ~/talk/env.sh
```

1. **Verify both cores** (about 10 s):
   ```bash
   tools/duet lint && tools/duet verify && tools/duet record --check && tools/duet mocks --check && tools/duet protocol-run --platform both
   ```
   Expect, in order:
   - `lockstep-lint: OK`
   - `duet verify: … PASS` (the Swift and Kotlin lanes)
   - `fixtures are up to date with their scenarios`
   - `Generated code is current ✓`
   - `protocol-run: PASS`
2. **Run the shell tests that `verify` doesn't run** (about 5 s):
   ```bash
   (cd src-ios/Subtrees/Splash/SplashNode && swift test) && ./src-android/gradlew -p src-android :app:testDebugUnitTest
   ```
   Expect `Executed 4 tests, with 0 failures` for the SwiftUI shell, then Gradle with no errors for the Android host tests.
3. **Build the iPhone app** (a few seconds, since `setup.sh` built it already):
   ```bash
   (cd src-ios/App && xcodegen generate --spec xcodegen.yml -q) && xcodebuild build -project src-ios/App/Foyer.xcodeproj -scheme Foyer -destination 'generic/platform=iOS Simulator' -derivedDataPath build -quiet
   ```
   Then install and launch it on the booted simulator:
   ```bash
   xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Foyer.app && xcrun simctl launch booted dev.modaal.foyer
   ```
4. **Build the Android app**, then install and launch it (about 20 s). The emulator must be running (`~/talk/emulator.sh`):
   ```bash
   ./src-android/gradlew -p src-android :app:assembleDebug && adb install -r src-android/app/build/outputs/apk/debug/app-debug.apk && adb shell am start -n dev.modaal.foyer/dev.modaal.foyer.app.MainActivity
   ```

Both apps end on **"Foyer · Splash completed by the ceremony."**: one behavior, two cores.

**One-command alternative.** This runs everything CI runs: every check, the shell tests, the iOS build and the Android build. It installs nothing.
```bash
~/talk/.warm/scripts/run-tree.sh tutorial2-twins-complete
```

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `protocol-run` fails with "no valid handshake" | `JAVA_HOME` isn't JDK 25. Run `source ~/talk/env.sh` |
| `swift build` says "overlapping sources" | The package's empty `Tests/SplashFeatureTests` folder is missing. Create it with `mkdir -p` |
| `tools/duet mocks --check` says "Generated code is stale." after an edit | Expected: the fingerprint hashes every file under `Sources/`. Run `tools/duet mocks` |
| `swift test` in `foyer-twins` has 1 failure | The tutorial's exercise stub, which fails on purpose. `TUTORIAL_SKIP_STUBS=1` filters it; D5 turns it back on |
| The emulator stalls while it loads a snapshot | `emulator.sh` always cold-boots; start it before the talk |
| `tools/duet` downloads the CLI on first use | `env.sh` points `DUET_BIN` at the copy `setup.sh` made |

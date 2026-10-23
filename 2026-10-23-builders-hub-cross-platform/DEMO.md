# Live demo · slides 29–35

This walkthrough follows the live demo step by step. We start from an empty Swift tree and have Claude Code write a Swift feature core from a spec. Then we record that core's behavior and add a Kotlin/JVM twin that must replay the same recordings.

Each step lists:
- the commands;
- the prompt for Claude Code;
- the expected output;
- a **Fallback** that finishes the step without the agent.

The prompts are also in [prompts.md](prompts.md).

Paths assume the stage folder is `~/talk`, as [SETUP.md](SETUP.md) prepares it. If you use another `TALK_DIR`, substitute it.

## Before you start

Prepare the stage folder once with `scripts/setup.sh` ([SETUP.md](SETUP.md)). Then, before each run, reset it:

```bash
~/talk/reset.sh
```
Load the environment in **both** terminal tabs. It points `DUET_BIN` at the pinned CLI and `JAVA_HOME` at JDK 25:
```bash
source ~/talk/env.sh
```
- We use two terminal tabs: **shell**, for `tools/duet`, `swift` and Gradle, and **claude**, for Claude Code.
- For the Android app in D6, boot the emulator early with `~/talk/emulator.sh`. A cold boot takes about 30 s.
- If a step fails, its **Fallback** gets the tree to the same state.
- If the tree can't be saved, the finished tree builds and runs on its own: see [SETUP.md › Build and run the finished apps](SETUP.md#build-and-run-the-finished-apps).

---

## D0 · Workspace and agent rules

*Slide 29 · shell tab, in `~/talk`*

We're going to start from the template tree, with no Xcode or Android Studio wizard. Every project file is text that a script or an agent can produce and regenerate. `setup.sh` already cloned duet-tutorials, so nothing here needs the network.

1. Copy the Swift start tree and commit it:
   ```bash
   cp -R ~/talk/duet-tutorials/tutorial1-swift-start ~/talk/foyer && cd ~/talk/foyer && git init -q && git add -A && git commit -qm start
   ```
2. Open it in VS Code:
   ```bash
   code ~/talk/foyer
   ```
3. Walk the tree:

   | Path | What it is |
   | --- | --- |
   | `.modaal/project.json` | Template `duet-swift-ios`: the tree Modaal's iPhone template starts from |
   | `parity/manifest.yaml` | Features, scenarios and recordings; only the duet CLI parses it |
   | `parity/feature-specs/` | One page per feature; every change starts here |
   | `parity/fixtures/` | Recordings: build products, never edited |
   | `parity/duet-tools.ref` | The CLI pin, 0.34.0 |
   | `src-ios/Subtrees/` | Empty; each feature becomes a Swift package |
   | `tools/duet` | The CLI wrapper |

   There is no Gradle and no JDK in this tree yet.
4. Copy the rules for agents over, then open [`AGENTS.md`](AGENTS.md):
   ```bash
   cp ~/talk/AGENTS.md .
   ```
   Duet 0.7.0 and duet-tools 0.34.0 are newer than most models' training data, so the last rule points the agent at the tutorial pages.

---

## D1 · A Swift core from a spec

*Slide 30 · in `~/talk/foyer`*

We're going to have Claude Code write the splash feature's Swift core from its spec: state, actions, effect payloads and a pure reducer.

1. Copy the spec over, then open it. Sections §2–§4 hold the whole design: one state field, three actions, and the transitions table.
   ```bash
   cp ~/talk/duet-tutorials/tutorial1-swift-complete/parity/feature-specs/splash.md parity/feature-specs/
   ```
2. In the **claude** tab, give prompt D1:
   > Read AGENTS.md and parity/feature-specs/splash.md. Create the Swift package src-ios/Subtrees/Splash/SplashFeature (duet pinned exact 0.7.0; Duet and DuetTesting) with SplashFeature.swift (state, actions, effect payloads, reducer), SplashEnvironment.swift and SplashRuntime.swift, following ../duet-tutorials/docs/duet-swift-01-first-feature.md. Create the empty Tests/SplashFeatureTests folder too. Add the manifest row with the four recordings from §8. Run `tools/duet canonical-sum`, then `swift build` in the package. Do not write tests yet.

   The agent takes about 2 minutes. Expect `wrote 1 coder file(s)` from `canonical-sum`, then `Build complete!` from `swift build` (about 9 s).
3. While it works, follow principle 6, **effects as data**, through the agent's files as they appear: the reducer returns `armSafetyNet(afterMillis: 3000)` as a value, and the environment does the waiting. If a file isn't written yet, open the finished one; it's the same code:
   ```bash
   code -r ~/talk/duet-tutorials/tutorial1-swift-complete/src-ios/Subtrees/Splash/SplashFeature/Sources/SplashFeature/SplashFeature.swift
   ```
   The line numbers below are from the finished files at the pinned commit. In the agent's files, search for the symbol instead.

   **a. `SplashFeature.swift` → `enum SplashEffectPayload` (line 63).** It has two cases, `armSafetyNet(afterMillis: Int64)` (66) and `notifyListener(SplashDelegateEvent)` (68). Together they are every side effect this feature can have. The enum is `Equatable` and has one canonical JSON form, so a test compares effects like any other value.

   **b. Same file → `func splashReducer` (line 78), `case .appeared:` (83).**
   - The reducer returns `[Effect<SplashEffectPayload>]`. Line 89 returns `.armSafetyNet(afterMillis: SplashConfig.safetyNetMillis)`.
   - So the reducer doesn't wait and doesn't start a timer: it returns a description of the wait.
   - In a typical MVC app, this would be `DispatchQueue.main.asyncAfter` inside a view controller, and the only way to test it would be to wait three seconds.
   - TCA, for comparison, returns an effect closure here, and a test can't compare closures (slide 23).

   **c. `SplashEnvironment.swift` (18 lines).**
   - `var clock: any KernelClock` (14) and `func notifyHost(_:)` (17) are the feature's only door to the platform: a clock to wait on, and a sink for the result.
   - The `/// sourcery: CreateMock` annotation (9) gives the protocol a generated mock, which D5 uses.

   **d. `SplashRuntime.swift` → `func splashEffectHandler` (line 14), `case let .armSafetyNet(afterMillis):` (19).**
   - It calls `try await clock.sleep(…)` (24), then `continuation.yield(.safetyNetElapsed)` (25).
   - This is the only impure code in the package: the waiting happens here, on the environment's clock.
   - In a test that clock is a `TestClock`, so three seconds take no time.

   **e. Where the value goes next.** In D2 the value goes into the recording as `"afterMillis": 3000`. In D4 we change it to 2500 on the Swift side, and the Kotlin twin fails at exactly that field.
4. In the **shell** tab, run lint:
   ```bash
   tools/duet lint
   ```
   Expect `lockstep-lint: FAIL`, because the scenario file and the four fixtures are missing. The tool names the agent's next step.

**If `swift build` says "overlapping sources"**, the empty test folder is missing. Create it, then build again:
```bash
mkdir -p src-ios/Subtrees/Splash/SplashFeature/Tests/SplashFeatureTests
```

**Fallback**, if the agent stalls. Copy the finished feature over:
```bash
cp -R ~/talk/duet-tutorials/tutorial1-swift-complete/src-ios/Subtrees/Splash src-ios/Subtrees/
```
Then paste the `splash` row (features → splash, 10 lines) from that tree's `parity/manifest.yaml` into this tree's manifest. The copy also brings the scenario and the mock, so D2 can go straight to `record`.

---

## D2 · Record, replay, break

*Slide 31 · in `~/talk/foyer`*

We're going to record the feature's behavior as fixtures and replay them. Then we break the reducer on purpose to watch a replay fail.

1. In the **claude** tab, give prompt D2:
   > Write SplashScenarioTests.swift: one Given (a fresh store, then `appeared`) and the four branches in §8 of the spec. Run `tools/duet record --feature splash`, then `tools/duet verify`.

   The first `record` takes about 21 s, because it compiles the test target. Expect `duet record: rewrote 4 fixture(s)`, then `duet verify: 4/4 fixture report(s) passed · PASS`.
2. Commit:
   ```bash
   git add -A && git commit -qm splash
   ```
3. Open `parity/fixtures/splash.safety-net-fires.fixture.json`. It holds:
   - `expectedEffects`, with `afterMillis` 3000;
   - `expectedState`;
   - the source line of the scenario that recorded it.
4. Break the reducer by hand: in `SplashFeature.swift`, delete `guard !state.isArmed else { return [] }`. Then run verify:
   ```bash
   tools/duet verify
   ```
   Expect 3/4: ✗ `splash.repeat-appear-inert` at step 1. It expected ∅ and got the re-armed net. That recording is row 2 of the spec's transitions table, as a check that runs.
5. Restore the reducer and check the fixtures:
   ```bash
   git checkout -- src-ios && tools/duet record --check
   ```
   Expect `fixtures are up to date with their scenarios`.
6. *Optional:* copy Tutorial 1's Kotlin-recorded fixtures over the Swift ones:
   ```bash
   cp ~/talk/duet-tutorials/tutorial1-complete/parity/fixtures/splash.* parity/fixtures/ && git diff --stat
   ```
   Expect 4 files changed, 13+/13−: only the scenario path and the line numbers differ. Then run the check:
   ```bash
   tools/duet record --check
   ```
   Expect `metadata-only churn in 4 fixture(s) (admissible)`. The check writes the Swift metadata back, so there is nothing to clean up. A Swift reducer and a Kotlin reducer produced the same behavior, byte for byte.

An agent can't bend this check. Fixtures are regenerated from the scenario, and `record --check` fails a hand-edit.

---

## D3 · Add the Kotlin/JVM core

*Slide 32 · in `~/talk/foyer-twins`*

We're going to add a second core: a Kotlin/JVM twin of the splash feature, written against the recordings that already exist. The twin has an executable spec before its first line.

`setup.sh` prepared this tree, then committed it, tagged it `prepared` and warmed it. The tree is the Swift tree from `tutorial2-twins-start`, plus an empty Gradle build: a wrapper, a version catalog and the replay runner.

Switch to `~/talk/foyer-twins` in the shell tab and in VS Code, and start a new Claude Code session in that folder:
```bash
cd ~/talk/foyer-twins && export TUTORIAL_SKIP_STUBS=1
```
`TUTORIAL_SKIP_STUBS=1` filters out the tutorial's exercise stub. That stub is a test that fails on purpose until D5.

1. Look at what makes this a JVM build:
   - `src-android/settings.gradle.kts`
   - `src-android/subtrees/splash/logic/build.gradle.kts`, which applies `kotlin.jvm`, not `kotlin.multiplatform`
   - `kotlinCore: jvm` in `parity/manifest.yaml`
2. In the **claude** tab, give prompt D3:
   > Write the Kotlin twin of the Swift splash feature in src-android/subtrees/splash/logic/src/main/kotlin/dev/modaal/foyer/splash/: SplashFeature.kt and SplashSerializers.kt, with `@SerialName` values matching the Swift cases. Add the `kotlin:` line to the manifest row and run `tools/duet lint`. Then add SplashGoldenTest.kt so the four recordings replay on the JVM, and run `tools/duet verify`. Do not edit parity/fixtures or anything under src-ios.

   Expect `lockstep-lint: OK`; lint now also checks declaration parity by `@SerialName`. Then expect `duet verify: 8/8 fixture report(s) passed · PASS`.

**Fallback.** Tutorial 1's KMP `commonMain` files compile unchanged as `kotlin.jvm`, so copy them over:
```bash
cp ~/talk/duet-tutorials/tutorial1-complete/src-kmp/subtrees/splash/logic/src/commonMain/kotlin/dev/modaal/foyer/splash/{SplashFeature,SplashSerializers}.kt src-android/subtrees/splash/logic/src/main/kotlin/dev/modaal/foyer/splash/
```
Then:
- Add this line under the `swift:` line of the manifest row:
  `kotlin: src-android/subtrees/splash/logic/src/main/kotlin/dev/modaal/foyer/splash/SplashFeature.kt`
- Copy `SplashGoldenTest.kt` over from `tutorial2-twins-complete`:
  ```bash
  mkdir -p src-android/subtrees/splash/logic/src/test/kotlin/dev/modaal/foyer/splash && cp ~/talk/duet-tutorials/tutorial2-twins-complete/src-android/subtrees/splash/logic/src/test/kotlin/dev/modaal/foyer/splash/SplashGoldenTest.kt src-android/subtrees/splash/logic/src/test/kotlin/dev/modaal/foyer/splash/
  ```
- Run lint and verify:
  ```bash
  tools/duet lint && tools/duet verify
  ```

---

## D4 · The two cores disagree

*Slide 33 · in `~/talk/foyer-twins`*

We're going to change the behavior on the Swift side only, and watch the Kotlin lane catch it.

1. In `SplashFeature.swift` (line 16), change `SplashConfig.safetyNetMillis: Int64 = 3_000` to `2_500`. Then re-record and verify:
   ```bash
   tools/duet record && tools/duet verify
   ```
   Expect `record` to rewrite 4 fixtures, then `verify` to report **4/8 FAIL** with four ✗ `[kotlin]` blocks.
   - The first block is `splash.both-paths-notify-twice`, at `expectedEffects[0].payload.value.afterMillis`: expected 2500, actual 3000.
   - So the failure names the side, the recording, the step and the field.
2. In the **claude** tab, give prompt D4:
   > The Kotlin lane fails. Fix the Kotlin twin only. Do not touch parity/fixtures or src-ios. Run `tools/duet verify`.

   Expect 8/8 PASS. The fix is `SAFETY_NET_MILLIS: Long = 2_500L` in `SplashFeature.kt`.

   **Fallback:** make that one-line Kotlin edit by hand, then run `tools/duet verify`.
3. *Optional:* drive both cores over the replay protocol:
   ```bash
   tools/duet protocol-run --platform both
   ```
   Expect `protocol-run: PASS` in about 3 s. This needs JDK 25, which `env.sh` sets; under JDK 21 it fails with "no valid handshake". Then try to record from Kotlin:
   ```bash
   tools/duet record --feature splash --platform kotlin
   ```
   Expect **REFUSED**: the Swift scenario is the only writer of recordings.

---

## D5 · Generated mocks and a test

*Slide 34 · in `~/talk/foyer-twins`*

We're going to finish a test with the generated mock and a test clock, without writing a test double by hand.

1. Check the generated mock:
   ```bash
   tools/duet mocks --check
   ```
   Expect `Generated code is stale.` It always is after D4: the mock's fingerprint hashes every file under `Sources/`, including D4's edit. Regenerate the mock, then check it again:
   ```bash
   tools/duet mocks && tools/duet mocks --check
   ```
   Expect `SplashFeatureMocks.swift — 1 types, 57 lines`, then `Generated code is current ✓`. `git diff` shows one changed line, the input fingerprint; the body of the mock is the same. Generated code is regenerated, never edited.
2. Open `src-ios/Subtrees/Splash/SplashFeature/Tests/SplashFeatureTests/Generated/SplashFeatureMocks.swift`. Its 57 generated lines come from one `/// sourcery: CreateMock` annotation on `SplashEnvironment`.
3. Turn the exercise stub back on and run the tests:
   ```bash
   unset TUTORIAL_SKIP_STUBS && (cd src-ios/Subtrees/Splash/SplashFeature && swift test)
   ```
   Expect a failure: `Executed 6 tests, with 1 failure`, with the message "Tutorial 2 exercise: mount a second store and pin the fresh net".
4. In the **claude** tab, give prompt D5:
   > Tutorial2ExerciseMountBracketTests fails on purpose. Finish the test using TestClock and the generated SplashEnvironmentMock. Don't write a test double by hand, and don't change production code. Run swift test.

   Expect `Executed 6 tests, with 0 failures`.

   **Fallback:** replace the exercise with the finished test from `tutorial2-twins-complete`:
   ```bash
   cd src-ios/Subtrees/Splash/SplashFeature && rm Tests/SplashFeatureTests/Tutorial2ExerciseMountBracketTests.swift && cp ~/talk/duet-tutorials/tutorial2-twins-complete/src-ios/Subtrees/Splash/SplashFeature/Tests/SplashFeatureTests/SplashMountBracketTests.swift Tests/SplashFeatureTests/ && swift test
   ```

Slide 37 compares generated and hand-written mocks.

---

## D6 · Two apps, one set of recordings

*Slide 35*

We're going to run the finished apps, both built from `tutorial2-twins-complete`: the iPhone app on the Swift core and the Android app on the Kotlin core.

1. `setup.sh` built the iPhone app and installed it on the booted simulator. Relaunch it; the splash completes within about a second:
   ```bash
   xcrun simctl terminate booted dev.modaal.foyer; xcrun simctl launch booted dev.modaal.foyer
   ```
2. With the emulator running, install and launch the Android app:
   ```bash
   ~/talk/android.sh
   ```
   The splash shows mid-reveal, then "Splash completed by the ceremony.", the same end state as on the iPhone.
3. The iPhone app links no Kotlin. A Release build has 2,310 symbols, none with Kotlin/Native's `kfun:` prefix, and no Frameworks directory.
4. In CI, duet-tutorials' `.github/workflows/trees.yml` calls `scripts/run-tree.sh` for every tree; see [the workflow's runs](https://github.com/modaal-agent/duet-tutorials/actions/workflows/trees.yml).
   - Every lane runs `lint · doctor · verify · record --check · mocks --check · protocol-run --platform both`.
   - The macOS lane adds `swift test` and `xcodebuild`.
   - The Ubuntu lane adds the `:app` tests and `assemble`.

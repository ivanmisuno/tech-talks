# Live demo prompts

The prompts given to Claude Code in the live demo. Paste each into the
**claude** terminal tab. [DEMO.md](DEMO.md) has the steps around them: the
commands, the expected output, and a fallback for when the agent stalls.

## D1 · `~/talk/foyer` · slide 30

> Read AGENTS.md and parity/feature-specs/splash.md. Create the Swift package src-ios/Subtrees/Splash/SplashFeature (duet pinned exact 0.7.0; Duet and DuetTesting) with SplashFeature.swift (state, actions, effect payloads, reducer), SplashEnvironment.swift and SplashRuntime.swift, following ../duet-tutorials/docs/duet-swift-01-first-feature.md. Create the empty Tests/SplashFeatureTests folder too. Add the manifest row with the four recordings from §8. Run `tools/duet canonical-sum`, then `swift build` in the package. Do not write tests yet.

## D2 · `~/talk/foyer` · slide 31

> Write SplashScenarioTests.swift: one Given (a fresh store, then `appeared`) and the four branches in §8 of the spec. Run `tools/duet record --feature splash`, then `tools/duet verify`.

## D3 · `~/talk/foyer-twins`, new session · slide 32

> Write the Kotlin twin of the Swift splash feature in src-android/subtrees/splash/logic/src/main/kotlin/dev/modaal/foyer/splash/: SplashFeature.kt and SplashSerializers.kt, with `@SerialName` values matching the Swift cases. Add the `kotlin:` line to the manifest row and run `tools/duet lint`. Then add SplashGoldenTest.kt so the four recordings replay on the JVM, and run `tools/duet verify`. Do not edit parity/fixtures or anything under src-ios.

## D4 · `~/talk/foyer-twins` · slide 33

> The Kotlin lane fails. Fix the Kotlin twin only. Do not touch parity/fixtures or src-ios. Run `tools/duet verify`.

## D5 · `~/talk/foyer-twins` · slide 34

> Tutorial2ExerciseMountBracketTests fails on purpose. Finish the test using TestClock and the generated SplashEnvironmentMock. Don't write a test double by hand, and don't change production code. Run swift test.

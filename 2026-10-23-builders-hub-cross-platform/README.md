# Cross-platform apps: iOS & Android with Claude and Modaal Studio

Builders Hub · 23 October 2026 · Ivan Misuno, co-founder of [Modaal](https://modaal.dev)

Why the architecture decides how far an app can grow, and why that matters more once a coding agent writes the code. The talk includes a live demo: Claude Code writes a Swift feature core from a spec, then its Kotlin twin, and both are held to the same behavior by shared recordings.

## Slides

- [PDF](Builders-Hub-Cross-Platform-Setup-with-Duet-Talk_IMisuno_2026-10-23.pdf), 42 slides.
- [HTML](Builders-Hub-Cross-Platform-Setup-with-Duet-Talk_IMisuno_2026-10-23.html): self-contained. Download it and open it in a browser; GitHub shows only the source of an HTML file.

## Outline

| Slides | Part |
| --- | --- |
| 1–8 | A portfolio of apps and games, what MVC became in them, and the complexity wall |
| 9–18 | Architecture is not the framework. Uber's RIBs: the tree, five principles, what they didn't solve |
| 19–25 | Coding agents hit the same wall, higher up. Duet: RIBs plus cross-verification |
| 26–35 | Live demo |
| 36–38 | Shared core vs. twin cores; generated vs. hand-written mocks; the cost of keeping an agent on rails |
| 39–41 | Modaal Studio |
| 42 | Questions |

**The thesis.** The architecture decides whether change 200 costs what change 20 did. A framework draws the screens; the architecture decides where state lives, who may call whom, and what a test can check. A coding agent produces changes faster than anyone can review them by reading, so every rule it must follow has to be a check that runs.

## The live demo

| Step | Slide | What happens |
| --- | --- | --- |
| D0 | 29 | A project tree from the template, with no wizard, and the [rules for agents](AGENTS.md) |
| D1 | 30 | Claude writes a Swift feature core from a spec: state, actions, a pure reducer, effects as data |
| D2 | 31 | A scenario test records four fixtures; a deliberate bug fails the replay at the exact step |
| D3 | 32 | Claude writes the Kotlin/JVM twin against the recordings that already exist |
| D4 | 33 | A one-line change on the Swift side; the Kotlin lane fails at the exact field, and Claude fixes the twin |
| D5 | 34 | A test written with the generated mock and a test clock, with no hand-written double |
| D6 | 35 | The iPhone and Android apps reach the same end state; CI replays the recordings on both cores |

- [DEMO.md](DEMO.md): the demo step by step, with the commands, the prompts, the expected output and a fallback for every step.
- [prompts.md](prompts.md): the prompts given to Claude Code.
- [SETUP.md](SETUP.md): requirements, the setup script, and how to build, test and run the finished iPhone and Android apps.

## Links

- [duet-tutorials at the commit used in the talk](https://github.com/modaal-agent/duet-tutorials/tree/129a9925ee37073cb3081a810ea63af711d49171): the tutorial trees the demo starts from.
- [The Duet tutorials](https://docs.modaal.dev/tutorials/duet): the step-by-step pages for those trees.
- [Duet](https://github.com/modaal-agent/duet): the framework.
- [Modaal](https://modaal.dev).

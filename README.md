> Release for Steam build 25480438 / EXE 1.8.46015.0. Offline checks passed; checked in live play.

Performance update v1.0.13: Skips the second per-frame check while no sentries are deployed and reuses decode cells and one read buffer instead of allocating per read. Behavior is unchanged; aim holds and releases were confirmed live.

![Sentry Aim Retention](assets/banner.png)

# Sentry Aim Retention

Aims to keep autonomous sentries facing their last tracked target after losing it, instead of turning back toward the Helldiver while their burst may still be firing.

- **Hold through target loss.** Retains the last sampled aim and pauses rotation as soon as the previous target disappears, without waiting for the firing state to finish.
- **Resume tracking and scanning.** Releases the hold when a replacement target appears or a scanning transition is detected.
- **Find the next target sooner.** After losing a target while firing, Gatling and machine-gun sentries request another native target search without waiting out the usual one-second selection timer. Target choice remains with the game's AI.
- **Pause broad firing sweeps.** Gatling and machine-gun sentries can keep firing through small adjustments and nearby target changes, but pause shots during broad or prolonged turns and resume near the target. After a target-loss pause, a close replacement with a clear path can resume immediately. Their trigger and spin-up timer stay intact during the pause.
- **Stop wasted ground fire.** Gatling and machine-gun sentries pause shots when their target is lost, their aim still belongs to a previous target, or solid terrain blocks the current target point. Low, exposed targets remain eligible; firing resumes when the path clears and aim settles. Destructible cover, including fences in that collision class, keeps normal penetration and destruction behavior.

Aim retention applies to locally controlled Gatling, machine gun, laser cannon, rocket, flamethrower, mortar and EMS mortar sentries. Selective firing pauses apply to Gatling and machine-gun sentries.

Release **v1.0.13** reduces idle per-frame checks and per-read allocations. Offline checks cover this revision; aim holds and releases were confirmed live. Routine diagnostics are off by default; developers can set `CowboyBingusDiagnostics = true` before initialization to enable them.

Current version: **v1.0.13**, for game build **25480438**. See [changes](CHANGELOG.md) and [validation coverage](docs/MIGRATION_VALIDATION.md).

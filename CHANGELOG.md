# v1.0.12

- Refresh the game-build checks for Steam build 25480438.
- Preserve sentry aim retention and target handoffs.
- Offline builds and package checks pass; live gameplay validation remains pending.

# v1.0.11

- Update compatibility for game build 25327279.
- Restore sentry aim retention, target handoffs and firing checks.

# v1.0.9

- Batch targeting-registry pointer reads to reduce per-update work.
- Disable routine diagnostic file writes by default.
- Preserve fresh entity checks, aim retention and firing gates.
- Offline regression checks cover this update; live frame-time verification remains pending.

# v1.0.8

- Moves logs to `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs`.
- Requires Bingus Shared Loader v14 for the shared log folder.

# Changes since v1.0.0

- Reduced pauses between nearby enemies: Gatling sentries can keep firing through adjustments up to 16 degrees, and machine-gun sentries up to 14 degrees, increased from 12 and 8 degrees.
- Close replacement targets with a clear firing path can resume fire immediately after a target-loss pause. Time spent paused no longer counts toward the firing-sweep limit.
- Requests a new target search sooner after losing an enemy, reducing the wait caused by the native one-second selection timer.
- Stops residual firing when the target is lost or the aiming system still points at a previous target.
- Pauses shots when solid terrain blocks the target point, including buried crawler or retracting-tentacle aim points. Exposed low targets remain eligible, and the terrain check preserves normal firing through destructible cover such as fences.
- Fixed an aim-hold restoration bug that could leave a sentry unable to turn after acquiring another target or returning to scanning.

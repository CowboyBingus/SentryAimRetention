# Changes since v1.0.0

- Reduced pauses between nearby enemies: Gatling sentries can keep firing through adjustments up to 16 degrees, and machine-gun sentries up to 14 degrees, increased from 12 and 8 degrees.
- Close replacement targets with a clear firing path can resume fire immediately after a target-loss pause. Time spent paused no longer counts toward the firing-sweep limit.
- Requests a new target search sooner after losing an enemy, reducing the wait caused by the native one-second selection timer.
- Stops residual firing when the target is lost or the aiming system still points at a previous target.
- Pauses shots when solid terrain blocks the target point, including buried crawler or retracting-tentacle aim points. Exposed low targets remain eligible, and the terrain check preserves normal firing through destructible cover such as fences.
- Fixed an aim-hold restoration bug that could leave a sentry unable to turn after acquiring another target or returning to scanning.

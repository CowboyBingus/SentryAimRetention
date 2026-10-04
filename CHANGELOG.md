# v1.1.0

- A deployed sentry's memory layout is now kept and re-verified with a few reads instead of located from scratch on every check: 26-29 reads per check instead of 68-90.
- A check now leaves about 0.1-0.3 KB of garbage instead of about 10 KB.
- The second check after the game update runs only while a sentry tracks a target, holds aim, pauses fire or waits on a target search; an idle sentry is checked once per frame.
- Targeting entries that are not sentries this machine controls are classified once instead of read on every check, which lowers the cost outside missions and on the ship.
- The muzzle pose is read through a kept path per sentry: 7 reads instead of 12 per check.
- Memory fields now decode from their bytes, so a NaN in game memory always fails the range checks.
- Errors from the game's update and shutdown, or from other mods, now reach the game unchanged with their original traceback, so they no longer look like errors in this mod.
- After a failed update of the game or of a mod loaded before this one, the mod restores the sentry controls it holds and pauses; it resumes once 60 updates in a row have succeeded.
- Eight such failures, each within about a minute of the last, stop the mod for the session; while paused it reads no game memory.
- An error or a refused write in the mod's own checks no longer stops it for the session: it restores the sentry controls it holds and starts afresh on the next update.
- Eight errors of its own, each within about a minute of the last, stop the mod; each burst of errors gets one log line.
- The shutdown status and log keep the reason the mod stopped (for example `stopped after: the previous update failed`).
- An error in the mod's own shutdown work can no longer prevent the shutdown callbacks of the game and other mods.
- A lost target now costs 5 memory-protection checks instead of 8 on that frame, and restoring a pending search or undoing a half-finished hold costs 1 instead of 2.
- Windows functions are now declared under private names from Bingus Shared Runtime v1, so another mod's declaration of the same function can no longer break this mod's memory access.
- The game's module hashes are computed once per session and shared with every other mod that uses Bingus Shared Runtime v1.
- Another game build is now reported as `unsupported game build` and missing game modules as `game modules unavailable`.
- Another mod leaving the shared `BingusRuntime` table incomplete can no longer stop this mod from starting: the missing fields are filled in.
- Memory reads no longer allocate a 64-bit number per call, and the muzzle pose and terrain checks read into reused buffers.
- The clock is now the shared runtime's performance-counter clock, so the 60 ms settle time and 200 ms sweep limit are timed to the frame instead of the 10-16 ms system timer.
- Binding the game's sentry setters and terrain query no longer adds entries to the C type table that every mod shares (35 per binding before).
- The public source now includes a small read-only memory capture of one Gatling sentry from build 25327279, which the build replays; it holds no names, paths or account ids.
- The mod is now licensed under the Zero-Clause BSD license (0BSD).
- Requires Bingus Shared Loader v18 or newer.
- Measured in live play: 0.020 ms per frame in missions with a sentry deployed (0.178 before) and 0.012 on the ship (0.057 before).

# v1.0.13

- Skips the second per-frame check while no sentries are deployed; a sentry placed mid-frame is picked up on the next frame.
- Decodes fields through reused cells and reuses one read buffer instead of allocating per read.
- Behavior is unchanged; aim holds and releases were confirmed live.

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

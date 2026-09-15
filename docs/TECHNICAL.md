# Implementation and validation

The gameplay module uses Bingus Shared Loader loader-v6 or newer, API 1 or newer. It supports Steam build 24826606 / EXE 1.8.45317.0 and verifies both native module hashes. Earlier loaders do not discover the sentry module, even if its archive is installed. Confirm activation in the loader log after replacing the loader and deploying.

The targeting, behavior and turret registries identify seven autonomous sentry resource profiles. The module samples the current target and aim on both sides of the existing Lua update callback. After a tracked target disappears, it requests the native retention flag, temporarily sets both rotation speeds to zero and restores the last sampled raw/computed aim. Replacement targets release the hold. The saved per-instance turn speeds are restored when the hold ends.

Scanning is inferred from a different behavior node supplying a changed, nonzero explicit point. A dead target's ground point on the previous node and a zero-point transition do not release the hold. This is a heuristic, not a decoded named scanning state. It can delay release when a legitimate scan point is unchanged or zero.

Only validated, locally authoritative sentry instances are eligible. Entity mappings, identity, native setter signatures and writable-memory protections are checked. Writes target private writable runtime data. Existing native setters handle the retention flag and rotation speeds; no executable instructions, detours, custom DLLs, boot scripts or Wwise resources are supplied by this gameplay module.

The native zero-speed branches skip both angular and animation writes. Offline evidence does not establish that this preserves the visible barrel pose or projectile direction. The sampled aim is a tracked point, not a directly measured last-shot bearing. Lua/native scheduling may allow the first unwanted turn or shot before a hold is acquired. The `late_aim` counter indicates a changed aim before interception; it cannot establish whether a shot occurred.

Regression checks cover target loss, reacquisition, inferred scanning, control ownership, customized-speed restoration, component relocation, partial writes, shutdown, loader failures and memory protections. The anonymized Gatling fixture checks decisions through eight losses and releases. These checks do not prove live firing behavior, machine-gun acquisition, non-Gatling combat, or multiplayer authority transitions. In-game validation remains pending.

The fixture keeps the observed ordering and vector relationships, with remapped entity identifiers and normalized time. It contains no process addresses, player identifiers, machine details or source capture path. Raw research material is not distributed.

## Selective firing pauses

Gatling and machine-gun sentries now have a separate shot-permission gate. The
WeaponData runtime's replicated fire mode is temporarily set to `FireMode_None`
through its native setter. The projectile update tests this mode before its
shot loop, including continued fire. Targeting and behavior keep running. The
AI trigger and projectile spin-up countdown are neither cleared nor rewritten;
the countdown still follows the held trigger independently of fire permission.
Visual barrel effects and actual restart latency require live verification.

The muzzle matrix is read using the same unit generation, object and bone layout
as the engine's world-pose getter. Its forward vector is compared with the
computed aim point. No engine virtual call is needed to read that matrix.

| Sentry | Pause above | Resume within |
| --- | ---: | ---: |
| Gatling | 16 degrees | 4 degrees |
| Machine gun | 14 degrees | 3 degrees |

Resuming after a broad turn or obstruction requires 60 ms of settled aim. An
unsettled firing turn may last at most 200 ms. Angular travel accumulates until
the aim settles, so rapid small target changes cannot indefinitely extend one
firing sweep. Ordinary tracking near the selected target resets the sweep budget.
Time with shot permission closed does not consume that time budget.

Losing the selected target pauses residual shots even when the barrel is held
still. If that was the only reason for the pause, a synchronized replacement
within the short-turn allowance can resume immediately with a fresh clear
terrain query. A broad turn or obstruction observed during the pause cancels
that shortcut, retaining the alignment and settle requirements. Missing query
results do not qualify for the shortcut. An observed loss on the firing node
requests one earlier native candidate search, as described below. The module
does not fire into a retained point while no target exists.

These are tuning estimates, not friendly-fire protection. The captured Gatling
handoff began around 84 degrees from its target, while aligned shots were around
one degree. A later dense combat sample captured 297 Gatling and 160 MG rounds,
with close handoffs initially about 14 and 13.6 degrees off aim respectively.
At 20 metres, a 16-degree arc spans about 5.6 metres and a 14-degree arc about
4.9 metres, versus 62.8 metres for 180 degrees. At 1,600 and 630 rounds per minute,
200 ms corresponds to about 5.3 Gatling rounds or 2.1 MG rounds. The wider Gatling
allowance favors uninterrupted short transitions without permitting broad arcs.

The anonymized replay contains 613 observations. The policy suppresses all 26
observed rounds at more than 12 degrees from a live target and all 39 MG rounds
recorded after target loss. Three MG rounds remain eligible; two additional
reacquisition rounds wait for the settle interval. This is decision replay, not a simulation of how
changed damage would alter enemy survival or subsequent AI choices.

A lease saves the original fire mode before any native write. Restoration only
replaces the module's no-fire value, preserves external mode changes, refreshes
component mappings after relocation and checks entity authority. Failed updates
and shutdown release firing and aiming controls. Private writable data and
native signatures remain required; executable memory is never modified.

Other sentry profiles retain the existing target-loss behavior. Their firing
controls or ballistic aim relationships are not yet validated for this gate.
Lua/native ordering may permit a first unwanted shot before interception; an
in-game test of this module is required before claiming the sweep is fixed.

## Terrain-obstructed targets

Before permitting Gatling or machine-gun shots, the module casts from the muzzle
to the current raw target point, before prediction and ballistic correction.
It uses the original synchronous engine ray query and the game's existing
static-obstacle preset: closest hit, actor class 3, damage filter 0x393d9518,
flags 0x80000009, and the sentry unit excluded. The native body filter maps class
3 to the static body bit; it excludes the non-static character/ragdoll volumes
that can surround the muzzle or cross the ray. This is a terrain/static-geometry
check, not a veto on every intervening unit or a guarantee against friendly fire.

A solid hit more than 5 cm before the endpoint pauses firing. An endpoint on the
surface does not. The FactionComponent map resolves the selected target's unit
so that its own collision surface does not veto firing. The ordinary closest
query uses a private 44-byte buffer. No downward-angle or health threshold rejects living crawlers. Target
identity guards remain separate from sentry ownership, so target removal does
not prevent restoration of the original fire mode.

The world-ID getter and ray-query signatures are checked alongside both module
hashes. Queries run only with zero pending native ray queries and all 24 workers
complete. A pending check preserves an observed obstruction for that target;
a replacement target discards it. Targeting and the trigger keep running.
A clear path plus 60 ms of aligned aim permits resumption. The module allocates
no engine ray handles and does not modify scheduler records.

This addresses static-geometry-blocked target points and residual shots after
target loss. It does not choose a different body part when the selected node
remains buried, detect invulnerable above-ground animations, or prevent every
shot queued before Lua runs. Other sentries receive aim retention only.

The live regression captured an aligned MG with live targets and unchanged
ammunition. Its obstruction log identified other units at zero distance and
6.342 m along a 22.243 m ray. Read-only physics inspection found 39 bodies across
the two blocking units, all non-static. The previous broad query admitted those
bodies; the native static-only predicate rejects all of them. A regression scene
covers these body flags and distances, plus genuine static terrain behind them.
Other tests cover exposed crawlers, buried points, endpoint tolerance, target
identity, restoration and the native query contract. These checks do not replace
live verification of the corrected build.

Diagnostics retain the most recent query's reason, hit unit/actor, target unit,
hit distance, target distance, collision filter and age. Aged results show when native workers have
prevented a fresh query. Private captures and native decompilation are excluded
from both distribution ZIPs.

The adjacent-handoff regression uses angles from the dense combat sample and
target gaps up to 700 ms. It checks immediate close reacquisition, missing or
unsynchronized queries, cancellation by broad turns or terrain, and time spent
paused. A further live capture recorded 89 Gatling rounds and clear-path pauses
at less than one degree of aim error with the preceding policy installed.
The revised handoff rule has passed offline checks; its in-game cadence still
requires verification after reinstalling the package.

## Destructible cover

The fence regression captured an aligned Gatling vetoed by a static collider
11.286 m along a 29.736 m target ray. Read-only actor/body inspection identified
the current collision filter as `destructible` (0x04a8fbf9). Static geometry is
not necessarily bulletproof: the ground check must not prevent normal shots
through, or damage to, destructible cover.

The module resolves a hit's actor pool, body ownership and live filter-name table
using guarded reads. It verifies the handle and owning unit before and after
reading, and rejects recycled or unavailable mappings. A confirmed destructible
hit does not veto firing. This delegates penetration and destruction to native
weapon behavior; it does not simulate material thickness or armor penetration,
or exempt every collision class that might contain penetrable objects.

When the closest hit is destructible, the same native ray function is called in
all-hit mode (collection 2) with capacity 32 and private storage for 44-byte
records. Native code bounds stored records by the supplied capacity and returns
the total hit count. The module examines each stored hit and selects the nearest
remaining solid obstruction. It does not ignore a whole unit: another solid
body in the same unit, or terrain behind several fences, can still pause shots.
If more than 32 hits exist and none of the stored hits proves obstruction, the
check defers to native ballistics rather than latching an unproven pause.

The fence decision regression fails against the preceding package and passes
with the corrected classifier. Other checks cover terrain behind cover,
same-unit solid bodies, stale actor handles, read-time identity changes and
buffer overflow. The production reader also recognizes a captured live fence
mapping. These checks do not establish live firing after reinstalling this build.

## Hold ownership and target synchronization

A live MG capture showed a retained aim surviving several replacement targets
and a later scanning state: both turn speeds stayed zero even though the module
reported no active hold. A native entity-map replacement can invalidate map
guards without moving component data. Retiring the old guard set in that case
dropped the module's restoration record while leaving its controls installed.

Aim leases now refresh identity guards on every validated snapshot of the same
instance, including when the component addresses are unchanged. Original saved
turn speeds remain intact. A regression reproduces the old failure and checks
reacquisition, scanning and shutdown after a map-only replacement.

The shot gate also treats a selected/runtime target mismatch as unavailable aim.
It cannot reopen merely because an old retained point is aligned while the AI
has selected someone else. The regression holds this mismatch for ten seconds,
then verifies immediate recovery for a synchronized close replacement with a
fresh clear query. The reported continuous-fire incident was not reproduced in
that MG capture; this test closes a concrete stale-aim firing path, without
claiming that every cause of continuous firing has been identified.

## Target search after loss

The hash-locked Gatling and MG firing handlers at game.dll+0x280410 and
game.dll+0x32ac00 compare the behavior runtime's 64-bit deadline at +152 with
the native microsecond clock (game.dll+0x276c068, pointee +24). Behavior context
points eight bytes into that runtime. A nonzero source-flags value schedules
the next query one second ahead; zero flags use 250 ms. The loss fallback uses
nonzero point flags, so the one-second deadline can outlive the selected enemy.

A read-only Gatling sample recorded 304 rounds and repeated losses with roughly
0.6-0.9 seconds left on that deadline. New selections coincided with its expiry.
The short-turn gate was already reopening for close synchronized replacements;
the remaining no-target interval was a native selection delay.

After an observed tracked-to-no-target transition, the module shortens that
pending deadline once, only for enabled, locally authoritative MG/Gatling
instances on firing node 12. It only accepts a future deadline within one second
of the current clock. Accelerated queries are at least 100 ms apart, bounding
retries when native perception repeatedly offers an immediately invalid target.
Initial idle, scanning, live-target selection intervals and other profiles are
unchanged. The native handler still performs perception, candidate scoring,
range checks and target assignment. No target is fabricated or forced.

This is an eight-byte private-data request, separate from projectile spin-up.
Identity, state-transition, clock-root, expected-value and memory-protection
guards precede the write. An unconsumed request is journaled and restored on
shutdown or error; a new native deadline is preserved. Partial writes and
component relocation are covered by regression checks. The `reselections`
counter records accepted requests. Native ordering and the resulting combat
cadence still need verification after installing this build.

# Implementation and validation

The experimental gameplay module uses Bingus Shared Loader loader-v6 or newer, API 1 or newer. It supports Steam build 24826606 / EXE 1.8.45317.0 and verifies both native module hashes. Earlier loaders do not discover the sentry module, even if its archive is installed. Confirm activation in the loader log after replacing the loader and deploying.

The targeting, behavior and turret registries identify seven autonomous sentry resource profiles. The module samples the current target and aim on both sides of the existing Lua update callback. After a tracked target disappears, it requests the native retention flag, temporarily sets both rotation speeds to zero and restores the last sampled raw/computed aim. Replacement targets release the hold. The saved per-instance turn speeds are restored when the hold ends.

Scanning is inferred from a different behavior node supplying a changed, nonzero explicit point. A dead target's ground point on the previous node and a zero-point transition do not release the hold. This is a heuristic, not a decoded named scanning state. It can delay release when a legitimate scan point is unchanged or zero.

Only validated, locally authoritative sentry instances are eligible. Entity mappings, identity, native setter signatures and writable-memory protections are checked. Writes target private writable runtime data. Existing native setters handle the retention flag and rotation speeds; no executable instructions, detours, custom DLLs, boot scripts or Wwise resources are supplied by this gameplay module.

The native zero-speed branches skip both angular and animation writes. Offline evidence does not establish that this preserves the visible barrel pose or projectile direction. The sampled aim is a tracked point, not a directly measured last-shot bearing. Lua/native scheduling may allow the first unwanted turn or shot before a hold is acquired. The `late_aim` counter indicates a changed aim before interception; it cannot establish whether a shot occurred.

Regression checks cover target loss, reacquisition, inferred scanning, control ownership, customized-speed restoration, component relocation, partial writes, shutdown, loader failures and memory protections. The anonymized Gatling fixture checks decisions through eight losses and releases. These checks do not prove live firing behavior, machine-gun acquisition, non-Gatling combat, or multiplayer authority transitions. In-game validation remains pending; the package is experimental.

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
| Gatling | 12 degrees | 4 degrees |
| Machine gun | 8 degrees | 3 degrees |

Resuming requires 60 ms of settled aim. An unsettled firing turn may last at most
200 ms. Angular travel accumulates until the aim settles, so rapid small target
changes cannot indefinitely extend one firing sweep. Ordinary tracking near the
selected target resets the sweep budget. A stationary retained aim may finish
its burst; losing a target does not by itself require a firing pause.

These are tuning estimates, not friendly-fire protection. The captured Gatling
handoff began around 84 degrees from its target, while aligned shots were around
one degree. The sampled MG handoffs peaked near 5 degrees once firing began.
At 20 metres, a 12-degree arc spans about 4.2 metres and an 8-degree arc about
2.8 metres, versus 62.8 metres for 180 degrees. At 1,600 and 630 rounds per minute,
200 ms corresponds to about 5.3 Gatling rounds or 2.1 MG rounds. The wider Gatling
allowance favors uninterrupted short transitions without permitting broad arcs.

The anonymized replay contains 613 observations. The policy suppresses all 26
observed rounds at more than 12 degrees from a live target while retaining all
44 MG rounds in that sample. This is decision replay, not a simulation of how
changed damage would alter enemy survival or subsequent AI choices.

A lease saves the original fire mode before any native write. Restoration only
replaces the module's no-fire value, preserves external mode changes, refreshes
component mappings after relocation and checks entity authority. Failed updates
and shutdown release firing and aiming controls. Private writable data and
native signatures remain required; executable memory is never modified.

Other sentry profiles retain the existing target-loss behavior. Their firing
controls or ballistic aim relationships are not yet validated for this gate.
Lua/native ordering may permit a first unwanted shot before interception; an
in-game test of this candidate is required before claiming the sweep is fixed.

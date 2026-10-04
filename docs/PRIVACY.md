# Publication privacy review

The publication inventory contains authored Lua code, portable build scripts, regression fixtures, one small read-only memory capture (described below), dependency pins, documentation and reviewed PNG artwork. It excludes runtime logs, screenshots, player profiles, other process captures, memory dumps, extracted native code/game resources, compiler checkouts and build caches.

The Gatling decision fixture (`tests/gatling_target_loss.lua`) uses remapped transient entity IDs and relative timing. Native behavior nodes and vector relationships remain for the regression. No account or player identity, process address, capture date or source capture path is included. Reference screenshots used for artwork are not distributed.

The snapshot replay's fixture (`tests/current_game_25327279.lua`) holds 2,526 bytes in 99 ranges that a sentry snapshot read from one locally controlled Gatling sentry on Steam build 25327279. It contains game object data only: registry and map headers, component records, aim points in mission coordinates, weapon settings and the game's microsecond clock. Its addresses are that session's randomized module and heap addresses; they identify no machine or account. A scan of every captured byte, as ASCII and UTF-16 text and as 64-bit Steam id patterns, found no names, paths, Steam ids or other account identifiers. It keeps no capture date or source path.

`scripts/privacy_audit.py` scans the explicit source inventory and installable ZIP for home and network-share paths, local user/machine identities, contact/account patterns, network addresses, private keys, common credentials and process-session labels. It checks UTF-8 and both UTF-16 byte orders. Reports contain relative filenames, categories and hashes; matching values are never printed.

Only image-critical PNG chunks are retained. Visible AI-development disclosure remains. ZIP entries use fixed timestamps and permissions without comments or extra fields; Lua bytecode is stripped. The source release contains no `.git` metadata or surrounding workspace history.

Public dependency names, loader resource identifiers, native module hashes, relative virtual addresses, synthetic test addresses, the replay capture's session addresses, game build IDs and the mod-manager GUID are intentional compatibility data. They are not account or machine identifiers.

The audit covers the explicit publication inventory, not the surrounding private workspace. Pattern checks cannot prove the absence of every conceivable identifying value. Optional Git history checks require a standalone repository and do not rewrite history.

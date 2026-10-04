Supports Helldivers 2 Steam build 25480438 / EXE 1.8.46015.0.

Offline source, package and read-only module checks passed. Aim holds and
releases were confirmed live on earlier releases. The v1.1.0 build ran in real
play on 2026-10-04 with 13 aim holds and no errors, and its per-frame cost was
measured there. Multiplayer authority transitions and visual checks remain
pending. The 21
external live checks did not write game memory or installed files.

Public source includes one read-only memory capture from build 25327279 for the
snapshot replay test (`tests/current_game_25327279.lua`). It excludes other raw
memory captures and private session recordings.
Install with the game closed, then Purge / Deploy in one mod manager.
Use Bingus Shared Loader v18 or newer (v19 is current).

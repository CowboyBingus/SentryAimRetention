# Build and release preparation

Use Windows x64, Python 3.10 or newer, Visual Studio C++ Build Tools with an x64 Windows SDK, and the LuaJIT revision in `dependencies.json`.

```powershell
git clone https://github.com/LuaJIT/LuaJIT.git tools/src/LuaJIT
git -C tools/src/LuaJIT checkout 24c20c94e7db195b640854619577441f9b4bc6be
```

From an x64 Native Tools Command Prompt, build Windows x64 non-GC64 LuaJIT:

```bat
cd tools\src\LuaJIT\src
msvcbuild.bat nogc64
```

From this repository's root:

```powershell
python -B scripts/build.py
```

Set `HD2_LUAJIT` to an existing compatible compiler or `HD2_GAME_ROOT` for a nonstandard game installation. No neighboring mod, parent-project test, private capture or extracted resource is required. Supported executable hashes are checked before compilation.

The build runs the aim, loader, registry and Windows memory-adapter checks, verifies the installable archive, audits the publication inventory, and creates `releases/Sentry-Aim-Retention-v1.0.1.zip` and `releases/SentryAimRetention-source.zip`. In the shared mod workspace, both ZIPs go to the existing base `releases/` directory. Build output stays in ignored `build/`. Building does not install or launch the game.

The source ZIP contains only the explicit inventory in `scripts/privacy_audit.py`. It excludes Git metadata, other projects, dependency checkouts, logs, captures and build output. Extract it to obtain an independent source tree. No repository history is copied or rewritten.

Run the publication audit separately with:

```powershell
python -B scripts/privacy_audit.py --git --zip releases/Sentry-Aim-Retention-v1.0.1.zip
```

Use the shared release path when building inside the development workspace. In a standalone Git repository, `--history` checks reachable history and commit identities; `--staged` checks the index. Before publishing commits, use an appropriate public author identity and review their metadata. Publishing and tagging are separate from building.

See [installation](INSTALL.txt), [implementation and validation limits](docs/TECHNICAL.md), [privacy scope](docs/PRIVACY.md), and [artwork prompts](assets/ARTWORK.md).

# Resident Evil HD Remaster — One-Click Door Skip

A small, readable **Windows + Steam** launcher that starts *Resident Evil HD Remaster* and applies a door-animation skip in memory. No Python installation, compiled trainer, or game file replacement is required.

> **Community project — not affiliated with Capcom, Steam, or FluffyQuack.**

## Quick start

1. Download the project files (click **Code → Download ZIP** above) and extract them.
2. Double-click **`Play Resident Evil - Door Skip.cmd`**.
3. Steam launches the game; the launcher waits for `bhd.exe` and applies the patch. Confirm the success message, then play.

To apply the patch when the game is already running, you can use `Enable Door Skip.cmd` instead.

## Compatibility

- **Windows, Steam, Resident Evil HD Remaster (Steam app 304240)**.
- **Tested by one player on a particular September 2026 game build**. The patch validates the on-disk `bhd.exe` SHA-256 and checks the expected bytes at all patch points before writing memory. Other builds are **not** automatically supported.
- If the game is updated, the tool should refuse the mismatch rather than guessing patch locations.
- The patch affects **only the running game process**, not save files or `bhd.exe` on disk. Close and restart the game to clear it.
- Runtime behavior has been confirmed by one player; this repository is not a broad compatibility guarantee.

## What the scripts do

| File | Purpose |
| --- | --- |
| `Play Resident Evil - Door Skip.cmd` | One-click entry point. |
| `LaunchDoorSkip.ps1` | Launches Steam URL `steam://rungameid/304240`, waits for the game, then invokes the patch. |
| `DoorSkipLive.ps1` | Checks process identity, SHA-256, module base, and original bytes; applies four memory patches, verifies writes, and rolls back on failure. |
| `Enable Door Skip.cmd` | Manual fallback if the game is already running. |

The `.cmd` files invoke Windows PowerShell using `-NoProfile -ExecutionPolicy Bypass` for that PowerShell process. Review scripts before running them; memory modification and execution-policy overrides may be flagged by security products. **Do not disable antivirus protection to run this project.** This repo does not bundle an `.exe` or download any executable.

## Known limitations

- Exact-build checks are intentionally strict; an unsupported build will fail safely.
- Steam needs to be installed and the game available on your account.
- Console windows or a game-startup prompt may be visible while launching.
- Only **Resident Evil HD Remaster**, not *Resident Evil 0*, is supported here.

## Credits and provenance

Door-skip memory patching for the remasters was pioneered by **FluffyQuack**. The patch values/approach here were adapted with reference to the publicly available [FluffyQuack/rehd-nodoors](https://github.com/FluffyQuack/rehd-nodoors) work. Please credit that original project when redistributing or discussing this launcher. This repository is not an official release or endorsement by FluffyQuack.

## Licensing note

No general-purpose open-source license is asserted for this bundle. It includes patch logic adapted from an existing project whose redistribution permissions should be reviewed before selecting a license or accepting external contributions. Source visibility alone does not grant unrestricted reuse rights.

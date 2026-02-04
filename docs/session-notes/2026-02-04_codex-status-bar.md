# 2026-02-04 — Codex status bar app (percent UI)

## What changed
- Built a macOS menu bar app (`codesh`) that reads local Codex session logs and shows session/weekly **rate-limit percentages** in the status bar.
- Implemented a fast startup path: cached last known percentages + quick scan of the most recent JSONL file.
- Added a local release automation script for Developer ID signing + notarization and updated README/docs.
- Added MIT license and repo hygiene (.gitignore); removed Xcode user data.
- Created a private GitHub repo and published a notarized release (`v0.1.0`) with `codesh.app.zip` attached.

## Why
- The token totals were misleading; CodexMonitor uses `rate_limits.primary/secondary.used_percent`, so the UI is now accurate and compact.
- Startup felt slow due to full log scan; cached + fast path makes it instant.
- Needed a repeatable, notarized release flow for distribution.

## Key decisions
- **Percent-only UI** (no weekly/today toggles, no token totals).
- **Monospaced, compact** status bar text with neon accents (session = green, weekly = blue), adaptive to light/dark.
- **App Sandbox disabled** to read `~/.codex/sessions` directly.
- **Notarization** done via `notarytool` on a zipped `.app`.

## How to verify
1. Build and run from Xcode: `codesh/codesh.xcodeproj`.
2. Confirm status bar shows `session%/weekly%` (no prefix text).
3. Quit and relaunch — percentages should appear immediately (cached) and refresh shortly after.
4. Run release automation:
   ```bash
   ./scripts/release.sh
   ```
   Output should be `./dist/codesh.app.zip` and notarization should succeed.

## Known issues / notes
- Release script uses `.env` for secrets and team/bundle IDs; `.env` is git-ignored.
- If the Developer ID Application certificate isn’t installed, export will fail.

## Next steps
- Optional: rename project/app to a clearer OSS name.
- Optional: add a GitHub Actions workflow to notarize on tags.
- Optional: add UI toggles for coloring only the % sign (if preferred).

## Pointers
- Status bar UI and color: `codesh/codesh/AppDelegate.swift`
- Rate-limit parsing + fast path: `codesh/codesh/UsageScanner.swift`, `codesh/codesh/UsageController.swift`
- Cached values: `codesh/codesh/SettingsStore.swift`
- Release automation: `scripts/release.sh`

## Diff / env summary
- `git status --porcelain`: clean
- `git diff --name-only`: none
- `git diff`: none
- Repo: private `zibs/codesh`, release `v0.1.0`

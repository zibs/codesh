# Codex Usage Menu Bar (Local-Only)

<p align="center">
  <img src="docs/assets/codesh.png" alt="codesh logo" width="420" />
</p>
<p align="center">
  <img src="docs/assets/menu.png" alt="status bar preview" width="720" />
</p>

Minimal macOS menu bar app that reads Codex session logs from disk and shows session/weekly usage percentages in the status bar.

Inspired by [CodexMonitor](https://github.com/Dimillian/CodexMonitor). Built because the newly shipped Codex app from OpenAI doesn’t surface session/weekly usage at a glance.

“Codesh” is a short nod to **Codex Session** / **Codex Shell**—a tiny status‑bar companion for your local Codex usage.

## How it works
- Reads JSONL session logs from `~/.codex/sessions/YYYY/MM/DD/*.jsonl`
- Uses `rate_limits.primary.used_percent` (session) and `rate_limits.secondary.used_percent` (weekly)
- Falls back to cached values on startup for instant display

## Setup (Xcode)
1. Open `codesh/codesh.xcodeproj`.
2. Ensure the Swift files in `codesh/codesh/` are added to the app target.
3. In your target's **Info** tab, add:
   - `Application is agent (UIElement)` = `YES` (hides Dock icon)
4. Build and run.

## Installation (Users)
1. Download `codesh.app.zip` from the latest GitHub Release.
2. Unzip it to get `codesh.app`.
3. Drag `codesh.app` into `/Applications`.
4. Launch it from Applications.

## Notes
- If you set `CODEX_HOME`, the app will read sessions from `$CODEX_HOME/sessions`.
- App Sandbox is disabled so the app can read `~/.codex/sessions` directly.

## Files
- `codesh/codesh/AppDelegate.swift`
- `codesh/codesh/UsageScanner.swift`
- `codesh/codesh/UsageController.swift`
- `codesh/codesh/UsageSnapshot.swift`
- `codesh/codesh/SettingsStore.swift`
- `codesh/codesh/Formatters.swift`

## Releases
### Automated (recommended)
Run the release script to archive, sign, notarize, and zip the app.

```bash
TEAM_ID=ABCDE12345 \\
APPLE_ID=you@appleid.com \\
APP_PASSWORD=app-specific-password \\
BUNDLE_ID=com.your.bundleid \\
./scripts/release.sh
```

Output: `./dist/codesh.app.zip`

### Manual (Xcode)
1. In Xcode, set your **Signing & Capabilities** team and update the bundle identifier.
2. Use **Product → Archive** to create a signed build.
3. Distribute the `.app` from the Organizer, or export it and zip the app bundle for release.

## License
MIT

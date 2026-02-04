# Codex Usage Menu Bar (Local-Only)

Minimal macOS menu bar app that reads Codex session logs from disk and shows session/weekly usage percentages in the status bar.

## How it works
- Reads JSONL session logs from `~/.codex/sessions/YYYY/MM/DD/*.jsonl`
- Parses `payload.type == "token_count"` events
- Uses `rate_limits.primary.used_percent` (session) and `rate_limits.secondary.used_percent` (weekly)
- Falls back to cached values on startup for instant display

## Setup (Xcode)
1. Open `codesh/codesh.xcodeproj`.
2. Ensure the Swift files in `codesh/codesh/` are added to the app target.
3. In your target's **Info** tab, add:
   - `Application is agent (UIElement)` = `YES` (hides Dock icon)
4. Build and run.

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

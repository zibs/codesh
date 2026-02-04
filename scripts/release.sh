#!/bin/bash
set -euo pipefail

if [[ -f ".env" ]]; then
  set -a
  source .env
  set +a
fi

PROJECT_PATH="${PROJECT_PATH:-./codesh/codesh.xcodeproj}"
SCHEME="${SCHEME:-codesh}"
APP_NAME="${APP_NAME:-codesh}"
BUNDLE_ID="${BUNDLE_ID:-com.example.codesh}"
TEAM_ID="${TEAM_ID:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./dist}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"
APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"

if [[ -z "$TEAM_ID" ]]; then
  echo "TEAM_ID is required (your Apple Developer Team ID)." >&2
  echo "Example: TEAM_ID=ABCDE12345" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
ZIP_PATH="$OUTPUT_DIR/$APP_NAME.app.zip"
NOTARY_ZIP_PATH="$OUTPUT_DIR/$APP_NAME.notary.zip"

EXPORT_PLIST="$OUTPUT_DIR/exportOptions.plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
</dict>
</plist>
PLIST

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$ZIP_PATH" "$NOTARY_ZIP_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST"

if [[ -n "$APPLE_ID" && -n "$APP_PASSWORD" ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP_PATH"

  xcrun notarytool store-credentials "$NOTARY_PROFILE" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD"

  xcrun notarytool submit "$NOTARY_ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  xcrun stapler staple "$APP_PATH"
else
  echo "Skipping notarization (APPLE_ID / APP_PASSWORD not set)." >&2
fi

xcrun stapler validate "$APP_PATH" || true
spctl -a -vv "$APP_PATH" || true

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Done: $ZIP_PATH"

#!/bin/bash
# Archive MVP for App Store Connect / TestFlight (avoids "Invalid Run Destination" in Xcode)
# Run from Terminal: cd to the folder containing MVP.xcodeproj, then: ./archive-for-testflight.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
ARCHIVE_PATH="build/MVP.xcarchive"
rm -rf build
mkdir -p build
echo "Archiving MVP for iOS (generic device)..."
xcodebuild -scheme MVP -destination 'generic/platform=iOS' archive -archivePath "$ARCHIVE_PATH" -quiet
echo "Archive created at: $ARCHIVE_PATH"
echo ""
echo "Next steps:"
echo "1. Open Xcode → Window → Organizer (or Product → Organizer)"
echo "2. In Archives tab, click the + at bottom left and add: $SCRIPT_DIR/$ARCHIVE_PATH"
echo "3. Select the MVP archive and click 'Distribute App' → App Store Connect → Upload"
open "$ARCHIVE_PATH" 2>/dev/null || true

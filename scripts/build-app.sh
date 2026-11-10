#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if [[ "${1:-}" != "--skip-build" ]]; then
  swift build -c release
fi
app="dist/uMacCleaner-GUI.app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/uMacCleaner-GUI "$app/Contents/MacOS/uMacCleaner-GUI"
cp .build/release/uMacCleaner-CLI "$app/Contents/MacOS/uMacCleaner-CLI"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.umaccleaner.app</string>
<key>CFBundleName</key><string>uMacCleaner GUI</string>
<key>CFBundleExecutable</key><string>uMacCleaner-GUI</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
version="$(<VERSION)"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $version" "$app/Contents/Info.plist"
echo "Built $app"

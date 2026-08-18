#!/usr/bin/env bash
#
# Build a double-clickable macOS app that launches the MoneyPrinterTurbo web UI.
#
# Creates MoneyPrinterTurbo.app in /Applications (falling back to the Desktop
# when /Applications is not writable) and points it at this checkout.
#
# Usage:  sh make-app.sh

set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP_NAME="MoneyPrinterTurbo"

[ -f "$PROJECT_DIR/webui.sh" ] || { echo "Error: run this from the MoneyPrinterTurbo folder" >&2; exit 1; }

if [ -w /Applications ]; then
  DEST="/Applications"
else
  DEST="$HOME/Desktop"
  echo "  /Applications is not writable; installing to the Desktop instead."
fi

APP="$DEST/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>local.moneyprinterturbo.launcher</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# The bundle records an absolute path, so moving the checkout means rebuilding.
cat > "$APP/Contents/MacOS/$APP_NAME" <<LAUNCHER
#!/usr/bin/env bash
PROJECT_DIR="$PROJECT_DIR"

if [ ! -d "\$PROJECT_DIR" ]; then
  osascript -e 'display alert "MoneyPrinterTurbo" message "The project folder has moved. Re-run make-app.sh from its new location."'
  exit 1
fi

cd "\$PROJECT_DIR"
# uv installs outside the GUI PATH, so add the usual locations back.
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"
exec sh webui.sh
LAUNCHER

chmod +x "$APP/Contents/MacOS/$APP_NAME"

echo "  Created: $APP"
echo "  Double-click it to launch. Drag it to your Dock to keep it handy."

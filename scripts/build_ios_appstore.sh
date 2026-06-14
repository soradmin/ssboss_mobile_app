#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Flutter dependencies"
flutter pub get

echo "==> CocoaPods"
cd ios
pod install
cd ..

echo "==> Build IPA for App Store"
flutter build ipa --export-options-plist=ios/ExportOptions.plist

IPA_PATH="$(ls -1 build/ios/ipa/*.ipa | head -n 1)"
echo ""
echo "IPA ready: $IPA_PATH"
echo ""
echo "Upload options:"
echo "  1) Transporter app (drag & drop the IPA)"
echo "  2) Xcode -> Window -> Organizer -> Distribute App"
echo "  3) xcrun altool --upload-app -f \"$IPA_PATH\" -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD"

#!/bin/bash
# FMLAB Emulator: compila l'IPA senza firma (la mettono LiveContainer, SideStore o AltStore all'installazione).
# Sul Mac di GitHub: xcodegen + xcodebuild. I core (emulatori) arrivano dal disco di fmlab-retro, impronta fissata
# in ios/DISCO-CORE, e vanno in Frameworks/ firmati "ad hoc" come l'app.
set -euo pipefail
ios="$(cd "$(dirname "$0")/.." && pwd)"; radice="$(cd "$ios/.." && pwd)"
V="$(tr -d '[:space:]' < "$radice/VERSIONE")"
B="$radice/build"; mkdir -p "$B"
cd "$ios"
xcodegen generate --quiet
xcodebuild -project FMLABEmulator.xcodeproj -scheme FMLABEmulator -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath "$B/dd" \
  MARKETING_VERSION="$V" CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build > "$B/xcodebuild.log" 2>&1 || {
    grep -E "error:|warning: unable|\*\* BUILD" "$B/xcodebuild.log" | sort -u | head -80; tail -20 "$B/xcodebuild.log"; exit 1; }
app="$B/dd/Build/Products/Release-iphoneos/FMLABEmulator.app"
[ -d "$app" ] || { echo "manca $app"; exit 1; }
if [ -d "$B/FMLAB-Core" ]; then
  mkdir -p "$app/Frameworks"
  for fw in "$B"/FMLAB-Core/*.framework; do rm -rf "$app/Frameworks/$(basename "$fw")"; cp -R "$fw" "$app/Frameworks/"; done
  cp "$B/FMLAB-Core/core.json" "$app/Frameworks/FMLAB-Core.json" 2>/dev/null || true
  for fw in "$app"/Frameworks/*.framework; do codesign --force --sign - --timestamp=none "$fw"; done
fi
codesign --force --sign - --timestamp=none "$app"
rm -rf "$B/ipa" && mkdir -p "$B/ipa/Payload" && ditto "$app" "$B/ipa/Payload/FMLABEmulator.app"
(cd "$B/ipa" && zip -qry "$B/FMLAB-Emulator.ipa" Payload)
ls -la "$B/FMLAB-Emulator.ipa"

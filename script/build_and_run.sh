#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "$ROOT/script/swift_environment.sh"
MODE="${1:-run}"
case "$MODE" in run|--verify|--preview|--build|--render-previews) ;; *) echo 'Usage: build_and_run.sh [--verify|--preview|--build|--render-previews]';exit 2;;esac
swift build "${SWIFT_OPTIONS[@]}" -c release
BIN="$(swift build "${SWIFT_OPTIONS[@]}" -c release --show-bin-path)"
APP="$ROOT/dist/Starfolio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "$MODE" == run || "$MODE" == --preview ]];then pkill -x Starfolio 2>/dev/null || true;fi
cp "$BIN/Starfolio" "$APP/Contents/MacOS/Starfolio"
for resource in "$BIN"/*.bundle;do [[ -d "$resource" ]] && ditto "$resource" "$APP/Contents/Resources/$(basename "$resource")";done
python3 - "$APP" <<'PY'
from pathlib import Path
import plistlib,sys
app=Path(sys.argv[1])
p=dict(CFBundleExecutable='Starfolio',CFBundleIdentifier='com.starfolio.wallpaper',CFBundleName='Starfolio',CFBundleIconFile='AppIcon',LSMultipleInstancesProhibited=True,CFBundleDisplayName='Starfolio',CFBundlePackageType='APPL',CFBundleShortVersionString='0.3.1',CFBundleVersion='4',LSMinimumSystemVersion='15.0',NSPrincipalClass='NSApplication',CFBundleDevelopmentRegion='en',CFBundleLocalizations=['en','zh-Hans','ko'],NSHumanReadableCopyright='Starfolio. Image credits are included in the application.')
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(p))
for lang,name in [('en','Starfolio'),('zh-Hans','星笺'),('ko','스타폴리오')]:
 d=app/'Contents/Resources'/f'{lang}.lproj';d.mkdir(exist_ok=True);(d/'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{name}";\n')
PY
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
case "$MODE" in
--verify) "$APP/Contents/MacOS/Starfolio" --verify ;;
--build) echo "$APP" ;;
--render-previews) "$APP/Contents/MacOS/Starfolio" --render-previews "$ROOT/dist/previews" ;;
--preview) open -n "$APP" --args --preview ;;
run) open -n "$APP" ;;
esac

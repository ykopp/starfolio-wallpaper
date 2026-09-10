#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/script/swift_environment.sh"
DEVELOPER_DIR_PATH="$(xcode-select -p)"
# Some Command Line Tools releases ship Testing outside SwiftPM's search paths.
# Use those bundled frameworks; do not install another test library or change Xcode selection.
if [[ "$DEVELOPER_DIR_PATH" == */CommandLineTools && -d "$DEVELOPER_DIR_PATH/Library/Developer/Frameworks/Testing.framework" ]]; then
  FRAMEWORKS="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
  exec swift test "${SWIFT_OPTIONS[@]}" --disable-xctest \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker "-F$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$DEVELOPER_DIR_PATH/Library/Developer/usr/lib" "$@"
fi
exec swift test "${SWIFT_OPTIONS[@]}" "$@"

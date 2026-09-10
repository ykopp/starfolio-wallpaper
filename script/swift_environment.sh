# Shared by build and test scripts. Never changes the machine's selected toolchain.
SWIFT_OPTIONS=(--build-system native)
STARFOLIO_DEVELOPER_PATH="$(xcode-select -p)"
# The macOS 27 CLT SDK declares SwiftUI macros whose plug-in is absent from CLT.
# Use the installed stable SDK when available; full Xcode keeps its selected SDK.
if [[ "$STARFOLIO_DEVELOPER_PATH" == */CommandLineTools && -d "$STARFOLIO_DEVELOPER_PATH/SDKs/MacOSX26.5.sdk" ]]; then
  SWIFT_OPTIONS+=(--sdk "$STARFOLIO_DEVELOPER_PATH/SDKs/MacOSX26.5.sdk")
fi

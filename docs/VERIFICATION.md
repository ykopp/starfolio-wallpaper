# 0.1.0 verification — 2026-09-10

Verified on an Apple Silicon Mac with Swift 6.4 and the installed stable SDK compatibility option in the build scripts.

- Release build and packaged `--verify` pass. Three catalog cards have Chinese, English and Korean text, matching original-image hashes and pixel dimensions. Packaged verification checks that resource loading uses the .app bundle rather than a local SwiftPM build directory.
- Six Swift tests pass: content/language coverage; renderer language/mode output; browsing without applying; per-display partial failure and retry; preference persistence; failed automatic rotation retries the same card; stable immutable render names. Some tests cover several behaviors.
- All nine knowledge wallpapers (three images × three languages) render at 1470 × 956. Representative Chinese Carina, English Saturn and Korean Milky Way outputs were visually inspected. Portrait rendering is also exercised in tests.
- Native windows were opened and checked in all three languages. An English layout compression defect was fixed, then rechecked. Korean reading details, original-source links, pure-image credit retention and settings controls were inspected. Screenshots in this folder show the running app, not a browser mockup.
- The explicit real-desktop diagnostic applied a rendered image to two connected displays, read back the macOS wallpaper URLs, restored both original URLs/options, and verified restoration: `applied=2/2, restored=2/2`.
- Ad-hoc signature integrity passes. The executable declares macOS 15 as its minimum. TOML parsing, shell syntax checks, Swift formatting lint and a source scan for machine paths/private-key/token patterns passed.
- A vendored CelestialKit snapshot was compared byte-for-byte with the canonical package. Sightline's 31 tests pass, including additive content, hiding persistence, assets and rendering. Its packaged verification reports 45 cards (42 existing + 3 astronomy).

## Limits

This is a development preview, not an Apple-notarized distribution. Intel and macOS 15 runtime execution, login-item registration, long-duration rotation, and every multi-Space/sleep/reconnect scenario have not been manually exercised. Automated tests cover timer selection and partial-failure behavior. Korean copy has not had an independent native-speaker review. No automatic remote content delivery or app update service is included.

The real-desktop diagnostic is opt-in: `dist/Starfolio.app/Contents/MacOS/Starfolio --smoke-desktop`. It briefly changes connected desktops and restores their previous URLs and options; normal verification and preview never write the desktop.

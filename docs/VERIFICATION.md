# Verification — 2026-09-10

Verified on an Apple Silicon Mac with Swift 6.4 and the installed stable SDK compatibility option in the build scripts.

## Original 0.1.0 baseline

- Release build and packaged `--verify` pass. Three catalog cards have Chinese, English and Korean text, matching original-image hashes and pixel dimensions. Packaged verification checks that resource loading uses the .app bundle rather than a local SwiftPM build directory.
- Six Swift tests pass: content/language coverage; renderer language/mode output; browsing without applying; per-display partial failure and retry; preference persistence; failed automatic rotation retries the same card; stable immutable render names. Some tests cover several behaviors.
- All nine knowledge wallpapers (three images × three languages) render at 1470 × 956. Representative Chinese Carina, English Saturn and Korean Milky Way outputs were visually inspected. Portrait rendering is also exercised in tests.
- Native windows were opened and checked in all three languages. An English layout compression defect was fixed, then rechecked. Korean reading details, original-source links, pure-image credit retention and settings controls were inspected. Screenshots in this folder show the running app, not a browser mockup.
- The explicit real-desktop diagnostic applied a rendered image to two connected displays, read back the macOS wallpaper URLs, restored both original URLs/options, and verified restoration: `applied=2/2, restored=2/2`.
- Ad-hoc signature integrity passes. The executable declares macOS 15 as its minimum. TOML parsing, shell syntax checks, Swift formatting lint and a source scan for machine paths/private-key/token patterns passed.
- A vendored CelestialKit snapshot was compared byte-for-byte with the canonical package. Sightline's 31 tests pass, including additive content, hiding persistence, assets and rendering. Its packaged verification reports 45 cards (42 existing + 3 astronomy).

## 0.2.0 update checks

- Thirteen deterministic tests pass, covering the original six behaviors plus full update/restart/rotation, failed translation, cancellation/network failure, atomic indexing/corrupt files/quota, untrusted-source parsing, byte-level image deduplication and source-conditioned terminology corrections.
- A real click on Content update fetched three observations from the official ESA sources, translated and rendered all three languages, and expanded the active library from three cards to six. The selected image stayed Cosmic Cliffs and the update did not apply a wallpaper. Titles in that first pass exposed specific translation issues; the glossary and caption selection were then refined.
- After terminology and caption refinements, an independent real-source acquisition test passed in 121 seconds and produced three cards and nine wallpapers. Their files, translations and hashes passed library validation; representative Chinese and Korean wallpaper outputs were visually inspected with readable titles and full credits.
- The shared package is synchronized byte-for-byte to Sightline's local development branch. Its 31 tests pass with the new package sources included in the build graph. Sightline's interface does not yet invoke live acquisition.
- Final UI follow-up is pending because the Mac locked during the session. The view-bound translation session and first-time language download consent have compiled but have not been exercised manually. Existing installed-language translation succeeded on this Mac.
- There is an opt-in real-source acceptance test: set `STARFOLIO_LIVE_QA_ROOT` to a new empty directory and run `./script/test.sh --filter liveAcquisitionProducesThreeLanguageLibrary`. It requires macOS 26 with both translation languages installed, writes no desktop or preferences, and is excluded from ordinary CI. It exercises the production acquisition/translation/render/storage pipeline and retains its outputs for inspection.

## Limits

This is a development preview, not an Apple-notarized distribution. Intel and macOS 15 runtime execution, login-item registration, long-duration rotation, and every multi-Space/sleep/reconnect scenario have not been manually exercised. Automated tests cover timer selection and partial-failure behavior. Korean copy has not had an independent native-speaker review. Live content acquisition is manual, through Content update; no background schedule or app update service is included.

The real-desktop diagnostic is opt-in: `dist/Starfolio.app/Contents/MacOS/Starfolio --smoke-desktop`. It briefly changes connected desktops and restores their previous URLs and options; normal verification and preview never write the desktop.


## 0.3.0 verification — 2026-09-12

- 20 deterministic tests executed and passed; one separately enabled live test downloaded three official observations, translated Chinese/Korean, rendered and committed successfully.
- New regression coverage: stale delayed reapply, rotation deadline preservation, cancellation during availability and during pending session followed by restart, restrictive credits, independent favorites rotation, hidden exclusions, missing/corrupt index recovery, safe preview clearing, framing cache identity.
- Two independent review lanes: code APPROVE, architecture CLEAR after repairing missing-index recovery, suppressing unknown recovered newest order and caching storage totals.
- Native isolated UI: favorite and favorites filter verified; full-image framing inspected; Chinese, English and Korean layouts inspected. No real desktop changes were made.
- Unverified: macOS 15, first language-download consent, long-running physical multi-Space/multi-monitor behavior, large-library performance and complete native Korean editorial review.
- Existing-user-library copy: all 12 cards validated; downloaded Trifid Chinese title corrected at read time, originals untouched. Shared CelestialKit snapshot checked (12 files); Sightline compatibility suite passed all 31 tests.
- Ad-hoc signed development preview; no Developer ID signing identity is configured on this machine, so Apple notarization remains pending.

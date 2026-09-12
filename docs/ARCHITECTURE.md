# Independent apps, one astronomy collection

Starfolio owns `Packages/CelestialKit`, a local Swift package containing the schema, trilingual editorial content, original credited images and native wallpaper renderer. Its UI, preferences, release cycle and application identity are independent of Sightline. The applications are intended to be used separately; there is no process coordination or takeover mechanism.

Sightline consumes a vendored snapshot in `Vendor/CelestialKit`. `UPSTREAM.json` records the source repository, component version and SHA-256 of each exported file. The adapter maps Chinese and English astronomy text into Sightline's existing models. Korean remains available in the shared package and is presented by Starfolio. Sightline's other categories and interface language scope are preserved.

The supplemental astronomy collection is combined with the active Sightline catalog at read time. This works whether Sightline uses its bundled catalog or a previously installed signed catalog. Signed catalog IDs take precedence; revocations and user-hidden IDs are respected. The supplemental version participates in rotation invalidation. The existing signed catalog pointer and update trust remain independent.

## Bundled editorial changes

1. Select an institutional image with explicit reuse terms and attribution. Store the unmodified original under the pack's `assets` directory. Record its official image page, usage-policy link, full credit, observing method and factual sources.
2. Edit all three languages in `script/seed_content.py`; regenerate `catalog.json` with `python3 script/seed_content.py`. The generator checks local image dimensions and writes content hashes. It does not fetch images.
3. Bump the component's content version in the generator and regenerate. Render all three languages using `./script/build_and_run.sh --render-previews`. Inspect cropping, image claims, credits and readable text. Never treat infrared mapping as visible natural color.
4. Run tests, package verification and visual acceptance. Commit the editorial source and generated catalog together.
5. Export to Sightline with `script/sync_sightline.py`, inspect the target diff, and run its tests/package verification before releasing either application. The two app releases can happen independently.

## Rendering and state

Rendering uses AppKit/CoreGraphics and original image assets. A sorted, encoded card fingerprint, size, language, mode and renderer version identify each immutable PNG. Saturn uses fit framing to preserve its rings; nebula and ground-sky images use fill framing. Image-only renders retain credits.

Application work is serialized on the main actor. Desktop operations are injected for tests and preview mode; no test double claims a real system update. Apply results are recorded per display and success is reported only when all requested displays succeed. The OS-selected URL is read back after a real apply. Previews use a temporary directory and a unique preference domain. Persistent renders are retained, because macOS may still reference them from a disconnected display or inactive Space.

This version renders on the main actor, which can briefly pause the interface on very large displays. There is a 50-million-pixel cap per display. There is no destructive cache eviction; many language/size combinations will use more disk space.

## User-triggered acquisition (0.2.0)

`SkyDiscovery` reads the current ESA/Webb and ESA/Hubble copyright pages and RSS feeds, then inspects candidate image pages. It requires explicit CC BY 4.0 policy text, an Observation type, astronomy category, full image credit and the official publication-JPEG download link. Each click considers up to 25 feed entries per source and inspects at most 16 eligible lead images, adding at most three. IDs, source URLs and image SHA-256 values prevent repeat acquisition. A suffix rule accepts only the lead `a` image from a release; the result is intentionally a selection, not a complete archive or guaranteed daily addition.

`SkyHTTP` accepts HTTPS only, with exact ESA source/CDN hosts, bounded responses and pre-follow redirect validation. XML external entities and DOCTYPE are rejected; remote HTML is reduced to text without running it. Images must decode as JPEG, be at least 1600 × 900, at most 50 megapixels and at most 20 MB. Non-observation art/diagrams and oversized or unqualified candidates are skipped. Generic source policies do not replace individual source notices; unusual credits or explicit restrictive notices are rejected. This is conservative filtering, not an independent legal review of each new item.

`ContentUpdater` uses complete source paragraphs (up to three) and a short complete source sentence; it does not fabricate facts. Apple Translation supplies Chinese and Korean locally. On macOS 26, installed languages use a direct session; missing models and macOS 15 use SwiftUI's view-bound session so the OS can request language-download consent. `--view-translation` exercises that path on newer systems for QA. Source-conditioned terminology corrections and simplified-Chinese conversion run afterward. New cards clearly identify machine translation and retain English originals, source URLs, release dates, image credits and retrieval times in `provenance.json`. See [translation notes](TRANSLATION.md).

Every new card is rendered in three languages before publication. An immutable batch folder contains the images, catalog, previews and provenance. `SkyLibrary` validates image hashes and trilingual fields, checks a 512 MB acquired-library limit, moves staging into a new UUID batch, and then atomically replaces the index. Existing data is not overwritten or evicted. A failed/cancelled update leaves the visible catalog and selected wallpaper intact. Invalid stored batches are reported and skipped on read; they are retained for recovery. Unreferenced files after a crash may remain on disk and count toward the quota.

The model reloads the local library before restoring the selected ID. Adding cards changes the catalog only, so manual selection, application and existing hourly/daily rotation work with the new cards. Rotation defaults to off. A running rotation can select an added card at a later tick. The newest successful batch is available via View new after relaunch. Thumbnails are downsampled and displayed in a lazy list; wallpaper output names include content fingerprints.


## Library controls and recovery (0.3)

Favorites and hidden IDs are per-app preferences. The rotation cursor follows the requested/applied wallpaper, never the browsing selection. Hidden cards are excluded and an empty favorites-only pool does not fall back to all cards. Reapply requests preserve the rotation anchor; successful manual/rotation requests advance it. Delayed system events resolve the latest desired ID and explicit requests cancel delayed work.

Index repair is explicit, preserves batch folders, and backs up the existing index before atomic replacement. Missing or corrupt indexes are reconstructed from validated UUID batches. A valid index only repairs its referenced batches, so previously excluded folders are not automatically reintroduced. Unknown recovered order suppresses the newest badge until another successful commit. Preview cleanup only removes indexed batches' `previews` folders; source assets and desktop render paths are never evicted. Storage totals refresh after mutations instead of every view render.

Known source-conditioned terminology corrections apply when merging downloaded cards. Downloaded JSON stays unchanged. Framing and corrected card content both participate in immutable renderer cache identity. The optional framing API preserves compatibility with Sightline's existing call sites.

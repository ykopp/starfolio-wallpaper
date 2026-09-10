# Independent apps, one astronomy collection

Starfolio owns `Packages/CelestialKit`, a local Swift package containing the schema, trilingual editorial content, original credited images and native wallpaper renderer. Its UI, preferences, release cycle and application identity are independent of Sightline. The applications are intended to be used separately; there is no process coordination or takeover mechanism.

Sightline consumes a vendored snapshot in `Vendor/CelestialKit`. `UPSTREAM.json` records the source repository, component version and SHA-256 of each exported file. The adapter maps Chinese and English astronomy text into Sightline's existing models. Korean remains available in the shared package and is presented by Starfolio. Sightline's other categories and interface language scope are preserved.

The supplemental astronomy collection is combined with the active Sightline catalog at read time. This works whether Sightline uses its bundled catalog or a previously installed signed catalog. Signed catalog IDs take precedence; revocations and user-hidden IDs are respected. The supplemental version participates in rotation invalidation. The existing signed catalog pointer and update trust remain independent.

## Content changes

1. Select an institutional image with explicit reuse terms and attribution. Store the unmodified original under the pack's `assets` directory. Record its official image page, usage-policy link, full credit, observing method and factual sources.
2. Edit all three languages in `script/seed_content.py`; regenerate `catalog.json` with `python3 script/seed_content.py`. The generator checks local image dimensions and writes content hashes. It does not fetch images.
3. Bump the component's content version in the generator and regenerate. Render all three languages using `./script/build_and_run.sh --render-previews`. Inspect cropping, image claims, credits and readable text. Never treat infrared mapping as visible natural color.
4. Run tests, package verification and visual acceptance. Commit the editorial source and generated catalog together.
5. Export to Sightline with `script/sync_sightline.py`, inspect the target diff, and run its tests/package verification before releasing either application. The two app releases can happen independently.

## Rendering and state

Rendering uses AppKit/CoreGraphics and original image assets. A sorted, encoded card fingerprint, size, language, mode and renderer version identify each immutable PNG. Saturn uses fit framing to preserve its rings; nebula and ground-sky images use fill framing. Image-only renders retain credits.

Application work is serialized on the main actor. Desktop operations are injected for tests and preview mode; no test double claims a real system update. Apply results are recorded per display and success is reported only when all requested displays succeed. The OS-selected URL is read back after a real apply. Previews use a temporary directory and a unique preference domain. Persistent renders are retained, because macOS may still reference them from a disconnected display or inactive Space.

This version renders on the main actor, which can briefly pause the interface on very large displays. There is a 50-million-pixel cap per display. There is no destructive cache eviction; many language/size combinations will use more disk space.

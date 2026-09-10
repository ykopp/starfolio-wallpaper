import AppKit
import CelestialKit

/// Explicit developer diagnostic: apply one image, verify the OS URL, then
/// restore every original URL/options pair. Not part of normal application launch.
@MainActor enum DesktopSmoke {
  static func run(catalog: SkyCatalog) async -> Int32 {
    let desktop = MacDesktop()
    let screens = NSScreen.screens
    let targets = desktop.screens
    guard !targets.isEmpty, screens.count == targets.count else {
      print("No stable display set")
      return 1
    }
    let originals = screens.compactMap {
      screen -> (NSScreen, URL, [NSWorkspace.DesktopImageOptionKey: Any])? in
      guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
      return (screen, url, NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:])
    }
    guard originals.count == targets.count else {
      print("Could not snapshot every original wallpaper")
      return 1
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "starfolio-desktop-check-\(UUID().uuidString)")
    var applied = 0
    do {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      let recovery = originals.enumerated().map { index, item in
        ["display": targets[index].id, "url": item.1.absoluteString]
      }
      try JSONSerialization.data(withJSONObject: recovery, options: .prettyPrinted).write(
        to: root.appendingPathComponent("originals.json"))
      for target in targets {
        let card = catalog.cards[1]
        let url = try SkyRenderer.render(
          card: card, imageURL: catalog.imageURL(card), size: target.size, language: .chinese,
          mode: .knowledge, directory: root)
        try await desktop.apply(url, to: target)
        applied += 1
      }
    } catch { print("Apply diagnostic failed: \(error)") }
    var restored = 0
    for (screen, url, options) in originals {
      do {
        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        for _ in 0..<5 {
          if NSWorkspace.shared.desktopImageURL(for: screen)?.standardizedFileURL
            == url.standardizedFileURL
          {
            restored += 1
            break
          }
          try await Task.sleep(for: .milliseconds(150))
        }
      } catch { print("Restore failed: \(error)") }
    }
    // Keep diagnostic renders if a screen still references one.
    if restored == originals.count {
      try? FileManager.default.removeItem(at: root)
    } else {
      print("Recovery record retained at \(root.path)")
    }
    print(
      "Real desktop diagnostic: applied=\(applied)/\(targets.count), restored=\(restored)/\(originals.count)"
    )
    return applied == targets.count && restored == originals.count ? 0 : 1
  }
}

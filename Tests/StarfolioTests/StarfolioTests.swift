import AppKit
import CelestialKit
import Testing

@testable import Starfolio

@MainActor final class FakeDesktop: DesktopApplying {
  var screens = [
    ScreenTarget(id: "a", name: "A", size: CGSize(width: 1470, height: 956)),
    ScreenTarget(id: "b", name: "B", size: CGSize(width: 1920, height: 1080)),
  ]
  var failures: Set<String> = []
  var applied: [String] = []
  func apply(_ url: URL, to screen: ScreenTarget) async throws {
    if failures.contains(screen.id) { throw SkyError.renderFailed }
    applied.append(url.lastPathComponent)
  }
}
@Suite(.serialized) @MainActor struct StarfolioTests {
  @Test func everyCardAndInterfaceKeyHasThreeLanguages() throws {
    let catalog = try SkyCatalog.load()
    try catalog.validate(verifyImages: true)
    #expect(catalog.cards.count == 3)
    for language in SkyLanguage.allCases {
      for key in Copy.allCases { #expect(!key.text(language).isEmpty) }
    }
    #expect(SkyLanguage.preferred(["ko-KR"]) == .korean)
    #expect(SkyLanguage.preferred(["zh-Hant-TW"]) == .chinese)
    #expect(SkyLanguage.preferred(["fr-FR"]) == .english)
    #expect(catalog.cards.first { $0.matches("토성") }?.id == "sky-saturn")
  }
  @Test func rendererVariesLanguageModeAndPreservesDimensions() throws {
    let catalog = try SkyCatalog.load()
    let card = catalog.cards[1]
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    var paths: Set<String> = []
    for language in SkyLanguage.allCases {
      for mode in SkyWallpaperMode.allCases {
        let result = try SkyRenderer.render(
          card: card, imageURL: catalog.imageURL(card), size: CGSize(width: 1470, height: 956),
          language: language, mode: mode, directory: dir)
        paths.insert(result.path)
        #expect(NSImage(contentsOf: result) != nil)
      }
    }
    #expect(paths.count == 6)
    #expect(throws: SkyError.self) {
      try SkyRenderer.render(
        card: card, imageURL: catalog.imageURL(card), size: .zero, language: .english, mode: .pure,
        directory: dir)
    }
  }
  @Test func browsingDoesNotApplyAndPartialFailureIsVisible() async throws {
    let catalog = try SkyCatalog.load()
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    let desktop = FakeDesktop()
    defer {
      defaults.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: dir)
    }
    let model = StarModel(
      catalog: catalog, defaults: defaults, directory: dir, isolated: true, desktop: desktop)
    defer { model.stop() }
    model.step(1)
    model.languageChoice = "ko"
    #expect(desktop.applied.isEmpty)
    desktop.failures = ["b"]
    await model.applySelected()
    #expect(model.status == .failure)
    #expect(model.displayResults.filter(\.succeeded).count == 1)
    desktop.failures = []
    await model.applySelected()
    #expect(model.status == .applied)
    #expect(defaults.string(forKey: "appliedID") == model.selectedID)
  }
  @Test func selectionLanguageAndModeSurviveRestartWithoutApplying() async throws {
    let catalog = try SkyCatalog.load()
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    let desktop = FakeDesktop()
    defer {
      defaults.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: dir)
    }
    let model = StarModel(
      catalog: catalog, defaults: defaults, directory: dir, isolated: true, desktop: desktop)
    model.step(2)
    model.languageChoice = "ko"
    model.mode = .pure
    let selected = model.selectedID
    model.stop()
    let reopened = StarModel(
      catalog: catalog, defaults: defaults, directory: dir, isolated: true, desktop: desktop)
    defer { reopened.stop() }
    #expect(reopened.selectedID == selected)
    #expect(reopened.language == .korean)
    #expect(reopened.mode == .pure)
    #expect(desktop.applied.isEmpty)
  }
  @Test func failedRotationRetriesTheSameCard() async throws {
    let catalog = try SkyCatalog.load()
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    let desktop = FakeDesktop()
    defer {
      defaults.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: dir)
    }
    let model = StarModel(
      catalog: catalog, defaults: defaults, directory: dir, isolated: true, desktop: desktop)
    defer { model.stop() }
    model.rotation = 3600
    desktop.failures = ["a", "b"]
    await model.rotationTick()
    let target = defaults.string(forKey: "pendingRotationID")
    #expect(model.status == .failure)
    #expect(defaults.string(forKey: "pendingRotationID") == target)
    desktop.failures = []
    await model.rotationTick()
    #expect(defaults.string(forKey: "appliedID") == target)
    #expect(model.status == .applied)
    #expect(defaults.string(forKey: "pendingRotationID") == nil)
    let count = desktop.applied.count
    await model.rotationTick()
    #expect(desktop.applied.count == count)
  }
  @Test func rendersHaveStableNamesAcrossRepeatedEncodes() throws {
    let catalog = try SkyCatalog.load()
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let card = catalog.cards[0]
    let first = try SkyRenderer.render(
      card: card, imageURL: catalog.imageURL(card), size: CGSize(width: 900, height: 1440),
      language: .korean, mode: .knowledge, directory: dir)
    let bytes = try Data(contentsOf: first)
    for _ in 0..<10 {
      let next = try SkyRenderer.render(
        card: card, imageURL: catalog.imageURL(card), size: CGSize(width: 900, height: 1440),
        language: .korean, mode: .knowledge, directory: dir)
      #expect(first == next)
    }
    #expect(try Data(contentsOf: first) == bytes)
  }

}

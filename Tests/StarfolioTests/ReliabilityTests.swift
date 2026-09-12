import AppKit
import Testing
import Translation

@testable import CelestialKit
@testable import Starfolio

@MainActor final class ReviewDesktop: DesktopApplying {
  var screens = [ScreenTarget(id: "fake", name: "Fake", size: CGSize(width: 100, height: 100))]
  var names: [String] = []
  func apply(_ url: URL, to screen: ScreenTarget) async throws {
    names.append(url.lastPathComponent)
  }
}

@Suite(.serialized) @MainActor struct ReliabilityTests {
  @Test func delayedReapplyPreservesNewManualChoice() async throws {
    let catalog = try SkyCatalog.load()
    let name = "com.starfolio.review." + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    let desktop = ReviewDesktop()
    let model = StarModel(
      catalog: catalog, defaults: defaults, directory: directory, isolated: true, desktop: desktop)
    defer {
      model.stop()
      defaults.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: directory)
    }
    await model.applySelected()
    model.scheduleReapply()
    try await Task.sleep(for: .milliseconds(100))
    model.step(1)
    let chosen = model.selectedID
    await model.applySelected()
    #expect(desktop.names.last?.hasPrefix(chosen) == true)
    try await Task.sleep(for: .seconds(1))
    #expect(model.selectedID == chosen)
    #expect(defaults.string(forKey: "desiredID") == chosen)
    #expect(defaults.string(forKey: "appliedID") == chosen)
    #expect(desktop.names.last?.hasPrefix(chosen) == true)
  }

  @Test func appearanceReapplyPreservesRotationDeadline() async throws {
    let catalog = try SkyCatalog.load()
    let name = "com.starfolio.review." + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    let desktop = ReviewDesktop()
    let model = StarModel(
      catalog: catalog, defaults: defaults, directory: directory, isolated: true, desktop: desktop)
    defer {
      model.stop()
      defaults.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: directory)
    }
    await model.applySelected()
    model.rotation = 3600
    let anchor = Date().timeIntervalSince1970 - 3500
    defaults.set(anchor, forKey: "lastRotation")
    model.mode = .pure
    try await Task.sleep(for: .milliseconds(300))
    let afterReapply = defaults.double(forKey: "lastRotation")
    let count = desktop.names.count
    await model.rotationTick(now: Date(timeIntervalSince1970: anchor + 3601))
    #expect(afterReapply == anchor)
    #expect(desktop.names.count > count)
  }

  @Test func explicitRestrictionInCreditIsRejected() throws {
    let item = SkyFeedItem(
      title: "Fixture observation", link: URL(string: "https://esahubble.org/images/testa/")!,
      html:
        "<p>This is a sufficiently long description of an observation image to pass the existing source paragraph selection rules.</p>",
      date: "fixture")
    let page =
      "<tr><th>Type:</th><td>Observation</td></tr><tr><th>Category:</th><td>Galaxies</td></tr><div class=\"credit\">Example photographer. All rights reserved.</div><a href=\"https://cdn.esahubble.org/archives/images/publicationjpg/testa.jpg\">Image</a>"
    let metadata = try SkyDiscovery.metadata(item: item, page: page)
    #expect(metadata == nil)
  }
}

@MainActor final class AvailabilityGate {
  var entered = false
  var continuation: CheckedContinuation<LanguageAvailability.Status, Never>?
  func wait() async -> LanguageAvailability.Status {
    entered = true
    return await withCheckedContinuation { continuation = $0 }
  }
}
@Suite(.serialized) @MainActor struct CancellationRegressionTests {
  @Test func cancelDuringAvailabilityCanRestart() async throws {
    let (base, draft) = try ContentUpdateTests().fixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let gate = AvailabilityGate()
    let updater = ContentUpdater(
      base: base, root: root,
      discover: { _ in DiscoveryBatch(drafts: [draft], failedSources: 0, skipped: 0) },
      availability: { _, _ in await gate.wait() })
    updater.start()
    while !gate.entered { await Task.yield() }
    updater.cancel()
    gate.continuation?.resume(returning: .supported)
    await updater.waitUntilFinished()
    for _ in 0..<10 { await Task.yield() }
    #expect(!updater.running)
    #expect(updater.configuration == nil)
    #expect(updater.sessionRequestID == nil)
    gate.entered = false
    updater.start()
    while !gate.entered { await Task.yield() }
    gate.continuation?.resume(returning: .supported)
    while updater.configuration == nil { await Task.yield() }
    updater.cancel()
    await updater.waitUntilFinished()
    for _ in 0..<10 { await Task.yield() }
    #expect(!updater.running)
    #expect(updater.configuration == nil)
  }
}

@Suite(.serialized) @MainActor struct LibraryControlsTests {
  @Test func favoritesHiddenAndBrowsingUseIndependentRotation() async throws {
    let catalog = try SkyCatalog.load()
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    defer {
      defaults.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: root)
    }
    let desktop = ReviewDesktop()
    let model = StarModel(
      catalog: catalog, defaults: defaults, directory: root, isolated: true, desktop: desktop)
    defer { model.stop() }
    await model.applySelected()
    model.step(1)
    let favorite = model.selectedID
    model.toggleFavorite()
    model.step(1)
    let browsing = model.selectedID
    model.rotation = 3600
    model.favoritesOnly = true
    defaults.set(0, forKey: "lastRotation")
    await model.rotationTick()
    #expect(defaults.string(forKey: "appliedID") == favorite)
    #expect(model.selectedID == browsing)
    model.selectedID = favorite
    model.hideSelected()
    #expect(model.rotationCards.isEmpty)
    let count = desktop.names.count
    await model.rotationTick(now: .distantFuture)
    #expect(desktop.names.count == count)
    model.restoreHidden()
    #expect(model.rotationCards.map(\.id) == [favorite])
    model.hideSelected()
    model.hideSelected()
    model.hideSelected()
    #expect(model.availableCards.count == 1)
  }
  @Test func corruptIndexCanRecoverAndCachesCanBeClearedWithoutLosingImages() async throws {
    let (base, draft) = try ContentUpdateTests().fixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let updater = ContentUpdater(
      base: base, root: root,
      discover: { _ in DiscoveryBatch(drafts: [draft], failedSources: 0, skipped: 0) },
      translation: ContentUpdateTests().translated)
    updater.start()
    await updater.waitUntilFinished()
    let before = try updater.library.storageBytes()
    let image = updater.catalog.imageURL(updater.catalog.cards.last!)
    updater.clearPreviewCaches()
    #expect(try updater.library.storageBytes() < before)
    #expect(FileManager.default.fileExists(atPath: image.path))
    try Data("broken index".utf8).write(to: root.appendingPathComponent("index.json"))
    updater.repairLibrary()
    #expect(updater.catalog.cards.count == 2)
    #expect(updater.warnings == 0)
    #expect(updater.addedIDs.isEmpty)
    let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
    #expect(files.contains { $0.hasPrefix("index-backup-") })
    #expect(updater.catalog.cards.last?.category.en == "Solar system")
    try FileManager.default.removeItem(at: root.appendingPathComponent("index.json"))
    updater.repairLibrary()
    #expect(updater.catalog.cards.count == 2)
    #expect(FileManager.default.fileExists(atPath: image.path))
  }
  @Test func framingProducesSeparateImmutableFiles() throws {
    let catalog = try SkyCatalog.load()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    var urls: Set<URL> = []
    for framing in SkyFraming.allCases {
      urls.insert(
        try SkyRenderer.render(
          card: catalog.cards[0], imageURL: catalog.imageURL(catalog.cards[0]),
          size: CGSize(width: 640, height: 400), language: .chinese, mode: .knowledge,
          directory: root, framing: framing))
    }
    #expect(urls.count == 3)
    #expect(
      AstronomyTerms.normalize("三叉戍星云与三角星云", source: "Trifid Nebula", language: .chinese)
        == "三裂星云与三裂星云")
  }
}

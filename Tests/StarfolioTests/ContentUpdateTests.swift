import AppKit
import Testing
import Translation

@testable import CelestialKit
@testable import Starfolio

private struct FixtureHTTP: SkyFetching {
  let pages: [URL: Data]
  func fetch(_ url: URL, limit: Int) async throws -> Data {
    guard let data = pages[url] else { throw DiscoveryError.network }
    guard data.count <= limit else { throw DiscoveryError.tooLarge }
    return data
  }
}

@Suite(.serialized) @MainActor struct ContentUpdateTests {
  func fixture() throws -> (SkyCatalog, SkyDraft) {
    let bundled = try SkyCatalog.load()
    let image = bundled.cards[1]
    let base = SkyCatalog(version: "test", cards: [bundled.cards[0]])
    let item = SkyFeedItem(
      title: "Fixture observation", link: URL(string: "https://esahubble.org/images/testa/")!,
      html: "", date: "fixture date")
    let draft = SkyDraft(
      item: item, credit: "Fixture credit", category: "Solar System",
      caption: "Fixture text for validation, not published astronomical content.",
      paragraphs: [
        "A fixture paragraph used to verify that a card, its image and all translations are installed together."
      ],
      imageURL: URL(string: "https://cdn.esahubble.org/archives/images/publicationjpg/testa.jpg")!,
      image: try Data(contentsOf: bundled.imageURL(image)), width: image.width, height: image.height
    )
    return (base, draft)
  }
  func translated(_ strings: [String], _ language: SkyLanguage) -> [String] {
    strings.map { (language == .chinese ? "测试 " : "테스트 ") + $0 }
  }
  @Test func updateCreatesFilesWithoutSelectingOrApplyingAndSurvivesRestart() async throws {
    let (base, draft) = try fixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    let desktop = FakeDesktop()
    defer {
      defaults.removePersistentDomain(forName: name)
      try? FileManager.default.removeItem(at: root)
    }
    let model = StarModel(
      catalog: base, defaults: defaults, directory: root, isolated: true, desktop: desktop,
      contentDiscovery: { _ in DiscoveryBatch(drafts: [draft], failedSources: 0, skipped: 0) },
      contentTranslation: translated)
    let selection = model.selectedID
    model.contentUpdater.start()
    model.contentUpdater.start()
    await model.contentUpdater.waitUntilFinished()
    #expect(model.contentUpdater.state == .updateDone)
    #expect(model.catalog.cards.count == 2)
    #expect(model.selectedID == selection)
    #expect(desktop.applied.isEmpty)
    let card = try #require(model.catalog.cards.first { $0.id == draft.item.id })
    #expect(FileManager.default.fileExists(atPath: model.catalog.imageURL(card).path))
    model.selectedID = card.id
    model.stop()
    let reopened = StarModel(
      catalog: base, defaults: defaults, directory: root, isolated: true, desktop: desktop)
    defer { reopened.stop() }
    #expect(reopened.catalog.cards.count == 2)
    #expect(reopened.selectedID == card.id)
    #expect(reopened.contentUpdater.addedIDs == [card.id])
    #expect(desktop.applied.isEmpty)
    reopened.rotation = 3600
    reopened.step(-1)
    await reopened.rotationTick()
    #expect(reopened.selectedID == card.id)
    #expect(desktop.applied.count == 2)
  }
  @Test func incompleteTranslationCannotPublishHalfACard() async throws {
    let (base, draft) = try fixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let updater = ContentUpdater(
      base: base, root: root,
      discover: { _ in DiscoveryBatch(drafts: [draft], failedSources: 0, skipped: 0) },
      translation: { _, _ in [] })
    updater.start()
    await updater.waitUntilFinished()
    #expect(updater.state == .translationFailed)
    #expect(updater.catalog.cards.count == 1)
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("index.json").path))
  }
  @Test func cancellationAndNetworkFailurePreserveLibrary() async throws {
    let (base, _) = try fixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let slow = ContentUpdater(
      base: base, root: root,
      discover: { _ in
        try await Task.sleep(for: .seconds(100))
        throw DiscoveryError.network
      })
    slow.start()
    await Task.yield()
    slow.cancel()
    await slow.waitUntilFinished()
    #expect(slow.state == .updateCancelled)
    #expect(slow.catalog.cards.count == 1)
    let failed = ContentUpdater(
      base: base, root: root, discover: { _ in throw DiscoveryError.network })
    failed.start()
    await failed.waitUntilFinished()
    #expect(failed.state == .updateFailed)
    #expect(failed.catalog.cards.count == 1)
  }
  @Test func atomicIndexRejectsDuplicatesCorruptionAndStorageOverflow() throws {
    let (base, draft) = try fixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let library = SkyLibrary(root: root)
    let card = try draft.makeCard(
      chinese: translated(draft.texts, .chinese), korean: translated(draft.texts, .korean))
    func stage() throws -> URL {
      let folder = try library.makeStagingDirectory()
      try draft.image.write(to: folder.appendingPathComponent(card.image))
      return folder
    }
    let first = try stage()
    #expect(throws: DiscoveryError.self) {
      try SkyLibrary(root: root, byteLimit: 10).commit(staging: first, cards: [card], base: base)
    }
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("index.json").path))
    let catalog = try library.commit(staging: first, cards: [card], base: base)
    let before = try Data(contentsOf: root.appendingPathComponent("index.json"))
    let duplicate = try stage()
    #expect(throws: SkyError.self) {
      try library.commit(staging: duplicate, cards: [card], base: base)
    }
    #expect(try Data(contentsOf: root.appendingPathComponent("index.json")) == before)
    try Data("damaged fixture".utf8).write(to: catalog.imageURL(card))
    let loaded = library.read(onto: base)
    #expect(loaded.unreadableBatches == 1)
    #expect(loaded.catalog.cards.count == 1)
    #expect(try Data(contentsOf: root.appendingPathComponent("index.json")) == before)
  }
  @Test func sourceParserRejectsExternalEntitiesUntrustedURLsAndNonObservations() throws {
    #expect(!SkyHTTP.allowed(URL(string: "https://esawebb.org.evil.example/a")!))
    #expect(!SkyHTTP.allowed(URL(string: "http://esawebb.org/images/")!))
    #expect(!SkyHTTP.allowed(URL(string: "https://person:password@esawebb.org/images/")!))
    #expect(throws: DiscoveryError.self) { try FeedReader.parse(Data("<!DOCTYPE rss><rss/>".utf8)) }
    let paragraph =
      "An example long paragraph for a test fixture. It contains enough characters to exercise the parser without being a claim about a real object."
    let feed =
      "<rss><channel><item><title>Fixture</title><link>https://esawebb.org/images/testa/</link><description>&lt;p&gt;\(paragraph)&lt;/p&gt;</description></item><item><title>Bad</title><link>https://evil.example/images/testa/</link></item></channel></rss>"
    let items = try FeedReader.parse(Data(feed.utf8))
    #expect(items.count == 1)
    let item = try #require(items.first)
    let page =
      "<table><tr><th>Type:</th><td>Observation</td></tr><tr><th>Category:</th><td>Galaxies</td></tr></table><div class=\"credit\"><p>NASA &amp; ESA</p></div><a href=\"https://cdn.esawebb.org/archives/images/publicationjpg/testa.jpg\">Image</a>"
    let metadata = try SkyDiscovery.metadata(item: item, page: page)
    #expect(metadata?.credit == "NASA & ESA")
    #expect(
      try SkyDiscovery.metadata(
        item: item, page: page.replacingOccurrences(of: "Observation", with: "Illustration"))
        == nil)
    #expect(
      try SkyDiscovery.metadata(
        item: item, page: page.replacingOccurrences(of: "Galaxies", with: "People")) == nil)
    #expect(
      try SkyDiscovery.metadata(
        item: item,
        page: page.replacingOccurrences(of: "cdn.esawebb.org", with: "untrusted.example")) == nil)
  }
  @Test func discoveryChecksPolicyAndDeduplicatesDownloadedBytes() async throws {
    let (base, draft) = try fixture()
    let host = "https://esahubble.org"
    let source = draft.item.link
    let paragraph = draft.paragraphs[0]
    let feed =
      "<rss><channel><item><title>Fixture observation</title><link>\(source)</link><description>&lt;p&gt;\(paragraph)&lt;/p&gt;</description></item></channel></rss>"
    let page =
      "<tr><th>Type:</th><td>Observation</td></tr><tr><th>Category:</th><td>Solar System</td></tr><div class=\"credit\">Fixture credit</div><a href=\"\(draft.imageURL)\">Image</a>"
    let http = FixtureHTTP(pages: [
      URL(string: host + "/copyright/")!: Data("Creative Commons Attribution 4.0".utf8),
      URL(string: host + "/images/feed/")!: Data(feed.utf8), source: Data(page.utf8),
      draft.imageURL: draft.image,
    ])
    let found = try await SkyDiscovery(http: http).discover(excluding: base)
    #expect(found.drafts.count == 1)
    #expect(found.failedSources == 1)
    let bundled = try SkyCatalog.load()
    let duplicate = try await SkyDiscovery(http: http).discover(excluding: bundled)
    #expect(duplicate.drafts.isEmpty)
  }
  @Test func astronomyTerminologyKeepsMilkyWayDistinctAndNormalizesChinese() {
    #expect(
      AstronomyTerms.normalize("超級泡沫場景", source: "A superbubble scene", language: .chinese)
        == "超泡场景")
    #expect(
      AstronomyTerms.normalize("银河系合并", source: "A galactic merger", language: .chinese) == "星系合并")
    #expect(
      AstronomyTerms.normalize("银河系中心", source: "Our galaxy, the Milky Way", language: .chinese)
        == "银河系中心")
    #expect(
      AstronomyTerms.normalize("IRS 3 字段", source: "IRS 3 Field", language: .chinese) == "IRS 3 视场")
    #expect(
      AstronomyTerms.normalize("대형 마젤란 구름", source: "Large Magellanic Cloud", language: .korean)
        == "대마젤란 은하")
  }

  // Opt-in acceptance using real institutional sources and installed Apple languages.
  // Kept out of CI; no desktop writes, preference changes or network mocks.
  @Test(.enabled(if: ProcessInfo.processInfo.environment["STARFOLIO_LIVE_QA_ROOT"] != nil))
  func liveAcquisitionProducesThreeLanguageLibrary() async throws {
    guard #available(macOS 26, *) else {
      Issue.record("Headless live QA requires macOS 26 and installed translation languages")
      return
    }
    for language in ["zh-Hans", "ko"] {
      let status = await LanguageAvailability().status(
        from: Locale.Language(identifier: "en"), to: Locale.Language(identifier: language))
      try #require(status == .installed)
    }
    let path = try #require(ProcessInfo.processInfo.environment["STARFOLIO_LIVE_QA_ROOT"])
    let root = URL(fileURLWithPath: path)
    try #require(
      !FileManager.default.fileExists(atPath: root.appendingPathComponent("index.json").path))
    let base = try SkyCatalog.load()
    let updater = ContentUpdater(base: base, root: root)
    updater.start()
    await updater.waitUntilFinished()
    #expect(updater.state == .updateDone)
    #expect(!updater.addedIDs.isEmpty)
    let stored = SkyLibrary(root: root).read(onto: base)
    #expect(stored.unreadableBatches == 0)
    #expect(stored.newestCardIDs == updater.addedIDs)
    try stored.catalog.validate(verifyImages: true)
    for card in stored.catalog.cards where updater.addedIDs.contains(card.id) {
      print("Live QA: \(card.id) | \(card.title.zhHans) | \(card.title.ko)")
    }
  }
}

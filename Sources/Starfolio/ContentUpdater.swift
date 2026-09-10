import AppKit
import CelestialKit
import Combine
import Translation

enum AppleContentTranslation {
  static func perform(_ strings: [String], session: sending TranslationSession) async throws
    -> [String]
  {
    let responses = try await session.translations(
      from: strings.map { TranslationSession.Request(sourceText: $0) })
    guard responses.count == strings.count else { throw DiscoveryError.translation }
    return responses.map(\.targetText)
  }
  @available(macOS 26, *) static func installed(_ strings: [String], target: Locale.Language)
    async throws -> [String]
  {
    let session = TranslationSession(
      installedSource: Locale.Language(identifier: "en"), target: target)
    return try await perform(strings, session: session)
  }
}

@MainActor final class ContentUpdater: ObservableObject {
  @Published private(set) var catalog: SkyCatalog
  @Published private(set) var running = false
  @Published private(set) var state: Copy = .updateReady
  @Published private(set) var addedIDs: Set<String> = []
  @Published private(set) var warnings = 0
  @Published var configuration: TranslationSession.Configuration?
  @Published private(set) var sessionRequestID: UUID?
  var onCatalog: ((SkyCatalog) -> Void)?
  let library: SkyLibrary
  private let translateOverride: (@MainActor ([String], SkyLanguage) async throws -> [String])?
  private let base: SkyCatalog
  private let discover: @Sendable (SkyCatalog) async throws -> DiscoveryBatch
  private var work: Task<Void, Never>?
  private var job: UUID?
  private var pending: CheckedContinuation<[String], Error>?
  private var pendingStrings: [String] = []
  private var pendingJob: UUID?
  private var activeSessions: Set<UUID> = []
  init(
    base: SkyCatalog, root: URL,
    discover: (@Sendable (SkyCatalog) async throws -> DiscoveryBatch)? = nil,
    translation: (@MainActor ([String], SkyLanguage) async throws -> [String])? = nil
  ) {
    self.translateOverride = translation
    self.base = base
    self.library = SkyLibrary(root: root)
    let loaded = library.read(onto: base)
    self.catalog = loaded.catalog
    self.addedIDs = loaded.newestCardIDs
    self.warnings = loaded.unreadableBatches
    self.discover = discover ?? { try await SkyDiscovery().discover(excluding: $0) }
    if loaded.unreadableBatches > 0 { state = .libraryWarning }
  }
  func start() {
    guard !running else { return }
    let id = UUID()
    job = id
    running = true
    warnings = 0
    addedIDs = []
    state = .finding
    work = Task { [weak self] in await self?.run(id: id) }
  }
  func cancel() {
    job = nil
    let cancelledWork = work
    work?.cancel()
    configuration = nil
    sessionRequestID = nil
    pending?.resume(throwing: CancellationError())
    pending = nil
    pendingStrings = []
    pendingJob = nil
    state = .updateCancelled
    Task { [weak self] in
      await cancelledWork?.value
      guard let self, self.job == nil else { return }
      self.running = false
      self.work = nil
    }
  }
  private func check(_ id: UUID) throws {
    try Task.checkCancellation()
    guard job == id else { throw CancellationError() }
  }
  private func run(id: UUID) async {
    var staging: URL?
    defer {
      if let staging { try? FileManager.default.removeItem(at: staging) }
      if job == id {
        running = false
        configuration = nil
        work = nil
      }
    }
    do {
      let found = try await discover(catalog)
      try check(id)
      warnings = found.failedSources + found.skipped
      guard !found.drafts.isEmpty else {
        state = .updateEmpty
        return
      }
      let folder = try library.makeStagingDirectory()
      staging = folder
      var cards: [SkyCard] = []
      state = .translating
      let english = found.drafts.flatMap(\.texts)
      let chinese = try await translate(english, to: .chinese, job: id)
      let korean = try await translate(english, to: .korean, job: id)
      try check(id)
      guard chinese.count == english.count, korean.count == english.count else {
        throw DiscoveryError.translation
      }
      state = .makingCards
      var offset = 0
      for draft in found.drafts {
        let end = offset + draft.texts.count
        let card = try draft.makeCard(
          chinese: Array(chinese[offset..<end]), korean: Array(korean[offset..<end]))
        offset = end
        try draft.image.write(to: folder.appendingPathComponent(card.image), options: .atomic)
        // Produce actual wallpaper files for all supported languages before indexing.
        for language in SkyLanguage.allCases {
          try check(id)
          _ = try SkyRenderer.render(
            card: card, imageURL: folder.appendingPathComponent(card.image),
            size: CGSize(width: 1470, height: 956), language: language, mode: .knowledge,
            directory: folder.appendingPathComponent("previews"))
          await Task.yield()
        }
        cards.append(card)
      }
      let provenance = found.drafts.map { draft in
        [
          "id": draft.item.id, "source": draft.item.link.absoluteString,
          "image": draft.imageURL.absoluteString, "credit": draft.credit,
          "releaseDate": draft.item.date, "originalEnglish": draft.texts.joined(separator: "\n\n"),
          "translation":
            "Apple Translation, on device; machine translated; terminology normalization v1",
          "retrievedAt": ISO8601DateFormatter().string(from: Date()),
        ]
      }
      try JSONSerialization.data(
        withJSONObject: provenance, options: [.prettyPrinted, .sortedKeys]
      ).write(to: folder.appendingPathComponent("provenance.json"), options: .atomic)
      try check(id)
      catalog = try library.commit(staging: folder, cards: cards, base: base)
      addedIDs = Set(cards.map(\.id))
      state = .updateDone
      onCatalog?(catalog)
    } catch is CancellationError {
      if job == id { state = .updateCancelled }
    } catch DiscoveryError.libraryFull {
      if job == id { state = .libraryFull }
    } catch DiscoveryError.translation {
      if job == id { state = .translationFailed }
    } catch {
      if job == id { state = .updateFailed }
    }
  }
  private func translate(_ strings: [String], to language: SkyLanguage, job id: UUID) async throws
    -> [String]
  {
    try check(id)
    if let translateOverride { return try await translateOverride(strings, language) }
    let source = Locale.Language(identifier: "en")
    let target = Locale.Language(identifier: language.rawValue)
    let availability = await LanguageAvailability().status(from: source, to: target)
    guard availability != .unsupported else { throw DiscoveryError.translation }
    if #available(macOS 26, *), availability == .installed,
      !CommandLine.arguments.contains("--view-translation")
    {
      do {
        let result = try await AppleContentTranslation.installed(strings, target: target)
        try check(id)
        return result
      } catch is CancellationError { throw CancellationError() } catch {
        throw DiscoveryError.translation
      }
    }
    // macOS 15 and missing models use a view-bound session so the system can
    // present its language-download consent instead of pretending translation succeeded.
    return try await withCheckedThrowingContinuation { continuation in
      pending = continuation
      pendingStrings = strings
      pendingJob = id
      sessionRequestID = UUID()
      configuration = TranslationSession.Configuration(source: source, target: target)
    }
  }
  func handleSession(_ session: sending TranslationSession, requestID: UUID?) async {
    guard let id = pendingJob, id == job, let continuation = pending,
      let requestID, requestID == sessionRequestID, !activeSessions.contains(requestID)
    else { return }
    activeSessions.insert(requestID)
    defer { activeSessions.remove(requestID) }
    let strings = pendingStrings
    do {
      let responses = try await AppleContentTranslation.perform(strings, session: session)
      guard pendingJob == id, job == id, pending != nil, requestID == sessionRequestID else {
        return
      }
      pending = nil
      pendingJob = nil
      configuration = nil
      sessionRequestID = nil
      guard responses.count == strings.count else {
        continuation.resume(throwing: DiscoveryError.translation)
        return
      }
      continuation.resume(returning: responses)
    } catch {
      guard pendingJob == id, pending != nil, requestID == sessionRequestID else { return }
      pending = nil
      pendingJob = nil
      configuration = nil
      sessionRequestID = nil
      continuation.resume(throwing: DiscoveryError.translation)
    }
  }
  func waitUntilFinished() async { await work?.value }
}

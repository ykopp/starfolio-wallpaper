import AppKit
import CelestialKit
import ServiceManagement
import SwiftUI

struct ScreenTarget: Identifiable, Sendable {
  let id: String
  let name: String
  let size: CGSize
}
@MainActor protocol DesktopApplying {
  var screens: [ScreenTarget] { get }
  func apply(_ url: URL, to screen: ScreenTarget) async throws
}
@MainActor final class MacDesktop: DesktopApplying {
  var screens: [ScreenTarget] {
    NSScreen.screens.compactMap { s in
      guard
        let id = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
      else { return nil }
      return ScreenTarget(
        id: String(id), name: s.localizedName,
        size: CGSize(width: CGDisplayPixelsWide(id), height: CGDisplayPixelsHigh(id)))
    }
  }
  func apply(_ url: URL, to target: ScreenTarget) async throws {
    guard
      let screen = NSScreen.screens.first(where: {
        String(
          ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
            ?? 0) == target.id
      })
    else { throw SkyError.invalidSize }
    try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
    for _ in 0..<5 {
      if NSWorkspace.shared.desktopImageURL(for: screen)?.standardizedFileURL
        == url.standardizedFileURL
      {
        return
      }
      try await Task.sleep(for: .milliseconds(150))
    }
    throw SkyError.renderFailed
  }
}
@MainActor final class PreviewDesktop: DesktopApplying {
  var screens: [ScreenTarget] {
    [ScreenTarget(id: "preview", name: "1470 × 956", size: CGSize(width: 1470, height: 956))]
  }
  func apply(_ url: URL, to screen: ScreenTarget) async throws {}
}
struct DisplayResult: Identifiable {
  let id: String
  let name: String
  let succeeded: Bool
}
@MainActor final class StarModel: ObservableObject {
  let catalog: SkyCatalog
  let defaults: UserDefaults
  let directory: URL
  let isolated: Bool
  private let desktop: any DesktopApplying
  @Published var selectedID: String {
    didSet {
      defaults.set(selectedID, forKey: "selection")
      status = .ready
      displayResults = []
      refreshPreview()
    }
  }
  @Published var languageChoice: String {
    didSet {
      defaults.set(languageChoice, forKey: "language")
      refreshPreview()
      reapplyIfActive()
    }
  }
  @Published var mode: SkyWallpaperMode {
    didSet {
      defaults.set(mode.rawValue, forKey: "mode")
      refreshPreview()
      reapplyIfActive()
    }
  }
  @Published var rotation: Int {
    didSet {
      defaults.set(rotation, forKey: "rotation")
      configureTimer()
    }
  }
  @Published private(set) var previewURL: URL?
  @Published private(set) var status: Copy = .ready
  @Published private(set) var busy = false
  @Published private(set) var displayResults: [DisplayResult] = []
  @Published private(set) var loginEnabled = false
  private var timer: Timer?
  private var eventTokens: [NSObjectProtocol] = []
  private var workspaceTokens: [NSObjectProtocol] = []
  private var delayed: Task<Void, Never>?
  private var previewTask: Task<Void, Never>?
  private var appliedID: String?
  private var desiredID: String?
  private var pendingRotationID: String?
  private var requestedApply: String?
  private var previewGeneration = 0
  private var stopped = false
  var language: SkyLanguage { SkyLanguage(rawValue: languageChoice) ?? SkyLanguage.preferred() }
  var selected: SkyCard { catalog.cards.first { $0.id == selectedID } ?? catalog.cards[0] }
  var brand: String {
    switch language {
    case .chinese: "星笺"
    case .english: "Starfolio"
    case .korean: "스타폴리오"
    }
  }
  func text(_ key: Copy) -> String { key.text(language) }
  init(
    catalog: SkyCatalog, defaults: UserDefaults = .standard, directory: URL? = nil,
    isolated: Bool = false, desktop: (any DesktopApplying)? = nil
  ) {
    self.catalog = catalog
    self.defaults = defaults
    self.isolated = isolated
    self.directory =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Starfolio/rendered")
    self.desktop = desktop ?? (isolated ? PreviewDesktop() : MacDesktop())
    selectedID =
      defaults.string(forKey: "selection").flatMap { id in
        catalog.cards.contains { $0.id == id } ? id : nil
      } ?? catalog.cards[0].id
    languageChoice = defaults.string(forKey: "language") ?? "system"
    mode = SkyWallpaperMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .knowledge
    rotation =
      [0, 3600, 86400].contains(defaults.integer(forKey: "rotation"))
      ? defaults.integer(forKey: "rotation") : 0
    appliedID = defaults.string(forKey: "appliedID").flatMap { id in
      catalog.cards.contains { $0.id == id } ? id : nil
    }
    desiredID = defaults.string(forKey: "desiredID") ?? appliedID
    pendingRotationID = defaults.string(forKey: "pendingRotationID")
    refreshPreview()
    configureTimer()
    if !isolated {
      loginEnabled = SMAppService.mainApp.status == .enabled
      eventTokens.append(
        NotificationCenter.default.addObserver(
          forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.scheduleReapply() } })
      for event in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didWakeNotification] {
        workspaceTokens.append(
          NSWorkspace.shared.notificationCenter.addObserver(
            forName: event, object: nil, queue: .main
          ) { [weak self] _ in Task { @MainActor in self?.scheduleReapply() } })
      }
    }
  }
  func step(_ direction: Int) {
    let i = catalog.cards.firstIndex { $0.id == selectedID } ?? 0
    selectedID = catalog.cards[(i + direction + catalog.cards.count) % catalog.cards.count].id
  }
  func refreshPreview() {
    previewTask?.cancel()
    previewGeneration += 1
    let generation = previewGeneration
    let card = selected
    let lang = language
    let mode = mode
    let dir = directory.appendingPathComponent("previews")
    let image = catalog.imageURL(selected)
    previewURL = nil
    previewTask = Task { [weak self] in
      await Task.yield()
      guard !Task.isCancelled else { return }
      do {
        let url = try SkyRenderer.render(
          card: card, imageURL: image, size: CGSize(width: 1470, height: 956), language: lang,
          mode: mode, directory: dir)
        guard let self, !Task.isCancelled, generation == self.previewGeneration else { return }
        self.previewURL = url
      } catch { if let self, generation == self.previewGeneration { self.status = .failure } }
    }
  }
  private func reapplyIfActive() {
    if let desiredID {
      requestedApply = desiredID
      Task { await drain() }
    }
  }
  func applySelected() async {
    pendingRotationID = nil
    defaults.removeObject(forKey: "pendingRotationID")
    await request(selectedID)
  }
  private func request(_ id: String) async {
    desiredID = id
    defaults.set(id, forKey: "desiredID")
    requestedApply = id
    await drain()
  }
  private func drain() async {
    guard !busy, !stopped else { return }
    busy = true
    defer { busy = false }
    while let id = requestedApply {
      requestedApply = nil
      guard let card = catalog.cards.first(where: { $0.id == id }) else { continue }
      let targets = desktop.screens
      let lang = language
      let currentMode = mode
      guard !targets.isEmpty else {
        status = .noDisplay
        continue
      }
      status = .applying
      var results: [DisplayResult] = []
      for target in targets {
        do {
          let url = try SkyRenderer.render(
            card: card, imageURL: catalog.imageURL(card), size: target.size, language: lang,
            mode: currentMode, directory: directory)
          // Render files are immutable and retained after use, including across disconnected displays and Spaces.
          try await desktop.apply(url, to: target)
          results.append(DisplayResult(id: target.id, name: target.name, succeeded: true))
        } catch {
          results.append(DisplayResult(id: target.id, name: target.name, succeeded: false))
        }
      }
      displayResults = results
      if results.contains(where: { $0.succeeded }) {
        appliedID = id
        defaults.set(id, forKey: "appliedID")
      }
      if results.allSatisfy(\.succeeded) {
        status = .applied
        defaults.set(Date().timeIntervalSince1970, forKey: "lastRotation")
        if pendingRotationID == id {
          pendingRotationID = nil
          defaults.removeObject(forKey: "pendingRotationID")
        }
      } else {
        status = .failure
      }
    }
  }
  func configureTimer() {
    timer?.invalidate()
    timer = nil
    guard rotation > 0, !isolated else { return }
    if defaults.double(forKey: "lastRotation") == 0 {
      defaults.set(Date().timeIntervalSince1970, forKey: "lastRotation")
    }
    timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor in await self?.rotationTick() }
    }
    Task { await rotationTick() }
  }
  func rotationTick(now: Date = Date()) async {
    guard rotation > 0, !busy else { return }
    let last = defaults.double(forKey: "lastRotation")
    if now.timeIntervalSince1970 - last >= Double(rotation) {
      if pendingRotationID == nil {
        step(1)
        pendingRotationID = selectedID
        defaults.set(selectedID, forKey: "pendingRotationID")
      }
      if let pendingRotationID { await request(pendingRotationID) }
    }
  }
  private func scheduleReapply() {
    delayed?.cancel()
    guard let desiredID else { return }
    delayed = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(650))
      guard !Task.isCancelled, let self else { return }
      self.requestedApply = desiredID
      await self.drain()
    }
  }
  func setLogin(_ enabled: Bool) {
    guard !isolated else { return }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      loginEnabled = SMAppService.mainApp.status == .enabled
      if enabled && !loginEnabled { status = .loginError }
    } catch { status = .loginError }
  }
  func export() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = selected.id + "-" + language.rawValue + ".png"
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    do {
      let url = try SkyRenderer.render(
        card: selected, imageURL: catalog.imageURL(selected),
        size: CGSize(width: 2560, height: 1440), language: language, mode: mode,
        directory: directory.appendingPathComponent("exports"))
      try Data(contentsOf: url).write(to: destination, options: .atomic)
      status = .exportDone
    } catch { status = .failure }
  }
  func stop() {
    stopped = true
    requestedApply = nil
    timer?.invalidate()
    previewTask?.cancel()
    delayed?.cancel()
    for t in eventTokens { NotificationCenter.default.removeObserver(t) }
    for t in workspaceTokens { NSWorkspace.shared.notificationCenter.removeObserver(t) }
  }
}

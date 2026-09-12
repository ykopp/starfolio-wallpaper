import AppKit
import CelestialKit
import ImageIO
import SwiftUI
import Translation

@MainActor enum Session {
  static var model: StarModel!
  static var isolatedRoot: URL?
  static var suite: String?
  static func cleanup() {
    model?.stop()
    if let suite { UserDefaults.standard.removePersistentDomain(forName: suite) }
    if let isolatedRoot { try? FileManager.default.removeItem(at: isolatedRoot) }
  }
}
@main enum Entry {
  @MainActor static func main() {
    do {
      let catalog = try SkyCatalog.load()
      let args = CommandLine.arguments
      if let i = args.firstIndex(of: "--inspect-library"), args.indices.contains(i + 1) {
        let read = SkyLibrary(root: URL(fileURLWithPath: args[i + 1])).read(onto: catalog)
        try read.catalog.validate(verifyImages: true)
        guard read.unreadableBatches == 0 else { throw SkyError.invalidContent }
        print("Library PASS: \(read.catalog.cards.count) cards")
        for card in read.catalog.cards {
          print("\(card.id) | \(card.title.zhHans) | \(card.title.en) | \(card.title.ko)")
        }
        return
      }
      if args.contains("--verify") {
        try catalog.validate(verifyImages: true)
        if Bundle.main.bundleURL.pathExtension == "app"
          && !SkyCatalog.root.path.hasPrefix(Bundle.main.bundleURL.path + "/")
        {
          throw SkyError.invalidContent
        }
        print(
          "Starfolio verify PASS: \(catalog.cards.count) astronomy cards, zh-Hans/en/ko complete")
        return
      }
      if let i = args.firstIndex(of: "--render-previews"), args.indices.contains(i + 1) {
        let dir = URL(fileURLWithPath: args[i + 1])
        try catalog.validate(verifyImages: true)
        for language in SkyLanguage.allCases {
          for card in catalog.cards {
            let url = try SkyRenderer.render(
              card: card, imageURL: catalog.imageURL(card), size: CGSize(width: 1470, height: 956),
              language: language, mode: .knowledge, directory: dir)
            print(url.path)
          }
        }
        return
      }
      if args.contains("--smoke-desktop") {
        Task { @MainActor in exit(await DesktopSmoke.run(catalog: catalog)) }
        NSApplication.shared.run()
        return
      }
      let isolated = args.contains("--preview")
      var defaults = UserDefaults.standard
      var directory: URL?
      if isolated {
        let suite = "com.starfolio.wallpaper.preview.\(UUID().uuidString)"
        Session.suite = suite
        defaults = UserDefaults(suiteName: suite)!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        Session.isolatedRoot = root
        directory = root
      }
      if let i = args.firstIndex(of: "--language"), args.indices.contains(i + 1),
        SkyLanguage(rawValue: args[i + 1]) != nil
      {
        defaults.set(args[i + 1], forKey: "language")
      }
      Session.model = StarModel(
        catalog: catalog, defaults: defaults, directory: directory, isolated: isolated)
      StarfolioApp.main()
    } catch {
      fputs("Starfolio: \(error)\n", stderr)
      exit(1)
    }
  }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  weak var window: NSWindow?
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    if !Session.model.isolated { Task { await Session.model.appUpdater.check() } }
  }
  func applicationWillTerminate(_ notification: Notification) { Session.cleanup() }
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    return false
  }
  func show() {
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    show()
    return true
  }
}
struct StarfolioApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var model = Session.model!
  var body: some Scene {
    Window("Starfolio", id: "main") {
      MainView(model: model).background(
        WindowHook { window in
          delegate.window = window
          window.delegate = delegate
        }
      ).preferredColorScheme(.dark)
    }
    .defaultSize(width: 1180, height: 800).windowResizability(.contentMinSize)
    .commands {
      CommandGroup(replacing: .appSettings) {
        SettingsLink { Text(model.text(.settings)) }.keyboardShortcut(",")
      }
    }
    Settings { Preferences(model: model).preferredColorScheme(.dark) }
    MenuBarExtra {
      Button(model.text(.open)) { delegate.show() }
      Divider()
      Text(model.selected.title.value(model.language))
      Button(model.text(.next)) { model.step(1) }
      Button(model.text(.apply)) { Task { await model.applySelected() } }.disabled(model.busy)
      SettingsLink { Text(model.text(.settings)) }
      Divider()
      Button(model.text(.quit)) { NSApp.terminate(nil) }
    } label: {
      Image(systemName: "sparkles")
    }
  }
}
struct WindowHook: NSViewRepresentable {
  let register: (NSWindow) -> Void
  func makeNSView(context: Context) -> NSView { NSView() }
  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async { if let window = nsView.window { register(window) } }
  }
}
@MainActor enum StarThumbnails {
  static let cache: NSCache<NSURL, NSImage> = {
    let cache = NSCache<NSURL, NSImage>()
    cache.countLimit = 48
    return cache
  }()
  static func image(_ url: URL) -> NSImage? {
    if let image = cache.object(forKey: url as NSURL) { return image }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 512,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary)
    else { return nil }
    let image = NSImage(cgImage: thumbnail, size: .zero)
    cache.setObject(image, forKey: url as NSURL)
    return image
  }
}
struct MainView: View {
  @ObservedObject var model: StarModel
  @ObservedObject var updates: ContentUpdater
  init(model: StarModel) {
    self.model = model
    self.updates = model.contentUpdater
  }
  @State private var reading = false
  @State private var search = ""
  @State private var onlyNew = false
  @State private var onlyFavorites = false
  private var visibleCards: [SkyCard] {
    model.availableCards.filter {
      $0.matches(search) && (!onlyNew || updates.addedIDs.contains($0.id))
        && (!onlyFavorites || model.favorites.contains($0.id))
    }
  }
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text(model.brand).font(.system(size: 26, weight: .semibold))
          if model.language != .english {
            Text("Starfolio").font(.caption).foregroundStyle(.secondary)
          }
        }.padding(.top, 12)
        Text(model.text(.library)).font(.headline)
        VStack(alignment: .leading, spacing: 7) {
          Button {
            updates.start()
          } label: {
            Label(model.text(.update), systemImage: "arrow.down.circle")
          }.disabled(updates.running)
          if updates.running {
            ProgressView().controlSize(.small)
            Button(model.text(.cancelUpdate)) { updates.cancel() }
          }
          Text(model.text(updates.state)).font(.caption).foregroundStyle(.secondary)
          if updates.warnings > 0 {
            Text(model.text(.updateSkipped)).font(.caption2).foregroundStyle(.secondary)
          }
          if !updates.addedIDs.isEmpty {
            Button {
              onlyNew.toggle()
            } label: {
              Text(model.text(onlyNew ? .allImages : .showNew) + " · \(updates.addedIDs.count)")
            }.font(.caption)

          }
        }

        DisclosureGroup(model.text(.storage)) {
          Text(updates.storageDescription).font(.caption)
          Button(model.text(.clearCache)) { updates.clearPreviewCaches() }.disabled(updates.running)
          Button(model.text(.repairLibrary)) { updates.repairLibrary() }.disabled(updates.running)
        }.font(.caption)
        TextField(model.text(.search), text: $search).textFieldStyle(.roundedBorder)
        Toggle(model.text(.showFavorites), isOn: $onlyFavorites).font(.caption)
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(visibleCards) { card in
              Button {
                model.selectedID = card.id
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  if let image = StarThumbnails.image(model.catalog.imageURL(card)) {
                    Image(nsImage: image).resizable().aspectRatio(
                      contentMode: card.fit ? .fit : .fill
                    ).frame(height: 88).frame(maxWidth: .infinity).clipped().background(.black)
                      .clipShape(RoundedRectangle(cornerRadius: 6))
                  }
                  Text(
                    (updates.addedIDs.contains(card.id) ? model.text(.newCard) + " · " : "")
                      + card.title.value(model.language)
                  ).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                  Text(card.category.value(model.language)).font(.caption).foregroundStyle(
                    .secondary)
                }.padding(9).background(
                  model.selectedID == card.id ? Color.white.opacity(0.10) : .clear
                ).clipShape(RoundedRectangle(cornerRadius: 9))
              }.buttonStyle(.plain)
            }
            if visibleCards.isEmpty {
              Text(model.text(.noMatches)).foregroundStyle(.secondary).padding(.top, 12)
            }
          }
        }
        Spacer(minLength: 0)
        Picker(model.text(.language), selection: $model.languageChoice) {
          Text(model.text(.system)).tag("system")
          ForEach(SkyLanguage.allCases) { Text($0.label).tag($0.rawValue) }
        }.labelsHidden().accessibilityLabel(model.text(.language))
        SettingsLink { Label(model.text(.settings), systemImage: "gearshape") }.buttonStyle(.plain)
          .foregroundStyle(.secondary)
      }.padding(20).frame(width: 238).background(Color(white: 0.075))
      Divider()
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text(model.text(.today)).font(.title3.weight(.semibold))
          Spacer()
          Text(
            "\((model.catalog.cards.firstIndex{$0.id==model.selectedID} ?? 0)+1) / \(model.catalog.cards.count)"
          ).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        ZStack {
          Color.black
          if let url = model.previewURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
          } else {
            ProgressView(model.text(.loading))
          }
        }.aspectRatio(1470.0 / 956, contentMode: .fit).accessibilityLabel(
          model.selected.title.value(model.language))
        HStack(spacing: 10) {
          Button {
            model.step(-1)
          } label: {
            Image(systemName: "chevron.left")
          }.help(model.text(.previous)).accessibilityLabel(model.text(.previous))
          Button {
            model.step(1)
          } label: {
            Image(systemName: "chevron.right")
          }.help(model.text(.next)).accessibilityLabel(model.text(.next))
          Picker(model.text(.mode), selection: $model.mode) {
            Text(model.text(.knowledge)).tag(SkyWallpaperMode.knowledge)
            Text(model.text(.pure)).tag(SkyWallpaperMode.pure)
          }.pickerStyle(.segmented).labelsHidden().frame(width: 210)
          Spacer(minLength: 4)
          Button(model.text(.aboutImage)) { reading = true }
          Button(model.text(.apply)) { Task { await model.applySelected() } }.buttonStyle(
            .borderedProminent
          ).tint(Color(red: 0.57, green: 0.67, blue: 0.79)).disabled(model.busy)
        }
        HStack {
          Button(model.text(model.favorites.contains(model.selectedID) ? .unfavorite : .favorite)) {
            model.toggleFavorite()
          }
          Button(model.text(.hideImage)) { model.hideSelected() }.disabled(
            model.availableCards.count <= 1)
          Spacer()
          Picker(model.text(.framing), selection: $model.framing) {
            Text(model.text(.original)).tag(SkyFraming.original)
            Text(model.text(.fit)).tag(SkyFraming.fit)
            Text(model.text(.fill)).tag(SkyFraming.fill)
          }.frame(maxWidth: 300)
        }
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text(model.text(model.status)).font(.callout)
            Text(model.text(model.isolated ? .preview : .browse)).font(.caption).foregroundStyle(
              .secondary)
          }
          Spacer()
          Button {
            model.export()
          } label: {
            Image(systemName: "square.and.arrow.up")
          }.help(model.text(.export)).accessibilityLabel(model.text(.export))
        }
        if !model.displayResults.isEmpty {
          HStack {
            ForEach(model.displayResults) { result in
              Label(
                result.name,
                systemImage: result.succeeded ? "checkmark.circle" : "exclamationmark.circle"
              ).foregroundStyle(result.succeeded ? .green : .orange)
            }
          }.font(.caption)
        }
        Spacer(minLength: 0)
      }.padding(26).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.045))
    }.frame(minWidth: 1000, minHeight: 730).sheet(isPresented: $reading) {
      ReadingView(model: model)
    }.translationTask(updates.configuration) { [requestID = updates.sessionRequestID] session in
      await updates.handleSession(session, requestID: requestID)
    }
    .onChange(of: updates.running) { _, running in if running { onlyNew = false } }
  }
}
struct ReadingView: View {
  @ObservedObject var model: StarModel
  @Environment(\.dismiss) var dismiss
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(model.text(.aboutImage)).font(.headline)
        Spacer()
        Button(model.text(.close)) { dismiss() }.keyboardShortcut(.cancelAction)
      }.padding(22)
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if let image = NSImage(contentsOf: model.catalog.imageURL(model.selected)) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 270)
              .frame(maxWidth: .infinity).background(.black)
          }
          Text(model.selected.title.value(model.language)).font(.largeTitle.weight(.semibold))
          Text(model.selected.capture.value(model.language)).font(.callout).foregroundStyle(
            .secondary)
          ForEach(model.selected.sections) { section in
            VStack(alignment: .leading, spacing: 8) {
              Text(section.title.value(model.language)).font(.headline)
              Text(section.text.value(model.language)).font(.system(size: 15)).lineSpacing(6)
                .textSelection(.enabled)
            }
          }
          Divider()
          Text(model.text(.rights)).font(.headline)
          Text(model.selected.credit).font(.caption).textSelection(.enabled)
          Link(model.text(.source), destination: model.selected.sourceURL)
          ForEach(
            Array(Set(model.selected.sections.map(\.sourceURL))).filter {
              $0 != model.selected.sourceURL
            }.sorted { $0.absoluteString < $1.absoluteString }, id: \.self
          ) { Link($0.host() ?? "Source", destination: $0) }
          Link(model.selected.license, destination: model.selected.licenseURL)
        }.padding(24)
      }
    }.frame(width: 670, height: 760).preferredColorScheme(.dark)
  }
}
struct Preferences: View {
  @ObservedObject var model: StarModel
  var body: some View {
    Form {
      Section {
        Picker(model.text(.language), selection: $model.languageChoice) {
          Text(model.text(.system)).tag("system")
          ForEach(SkyLanguage.allCases) { Text($0.label).tag($0.rawValue) }
        }
        Picker(model.text(.mode), selection: $model.mode) {
          Text(model.text(.knowledge)).tag(SkyWallpaperMode.knowledge)
          Text(model.text(.pure)).tag(SkyWallpaperMode.pure)
        }
        Picker(model.text(.rotation), selection: $model.rotation) {
          Text(model.text(.off)).tag(0)
          Text(model.text(.hourly)).tag(3600)
          Text(model.text(.daily)).tag(86400)
        }
        Toggle(model.text(.favoritesOnly), isOn: $model.favoritesOnly)
        Button(model.text(.restoreHidden) + " · \(model.hidden.count)") { model.restoreHidden() }
          .disabled(model.hidden.isEmpty)
        Toggle(
          model.text(.login),
          isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })
        ).disabled(model.isolated)
      }
      Section {
        AppUpdateView(updater: model.appUpdater, language: model.language)
        Text(model.text(.version)).foregroundStyle(.secondary)
        Text(model.text(model.status)).font(.caption)
        if model.isolated { Text(model.text(.preview)).font(.caption) }
      }
    }.formStyle(.grouped).frame(width: 540, height: 540).padding().environment(
      \.locale, Locale(identifier: model.language.rawValue))
  }
}

struct AppUpdateView: View {
  @ObservedObject var updater: AppUpdating
  let language: SkyLanguage
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button(Copy.checkAppUpdate.text(language)) { Task { await updater.check() } }.disabled(
        updater.checking)
      Text(updater.state.text(language)).font(.caption)
      if let url = updater.releaseURL, let version = updater.availableVersion {
        Link(Copy.downloadAppUpdate.text(language) + " · " + version, destination: url)
      }
      Text(Copy.appInstallHint.text(language)).font(.caption).foregroundStyle(.secondary)
    }
  }
}

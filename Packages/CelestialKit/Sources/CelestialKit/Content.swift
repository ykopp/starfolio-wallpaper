import CryptoKit
import Foundation
import ImageIO

public enum SkyLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
  case chinese = "zh-Hans"
  case english = "en"
  case korean = "ko"
  public var id: String { rawValue }
  public var label: String {
    switch self {
    case .chinese: "简体中文"
    case .english: "English"
    case .korean: "한국어"
    }
  }
  public static func preferred(_ languages: [String] = Locale.preferredLanguages) -> Self {
    for language in languages {
      if language.hasPrefix("zh") { return .chinese }
      if language.hasPrefix("ko") { return .korean }
      if language.hasPrefix("en") { return .english }
    }
    return .english
  }
}
public struct SkyText: Codable, Hashable, Sendable {
  public let zhHans: String
  public let en: String
  public let ko: String
  public init(zhHans: String, en: String, ko: String) {
    self.zhHans = zhHans
    self.en = en
    self.ko = ko
  }
  public func value(_ language: SkyLanguage) -> String {
    switch language {
    case .chinese: zhHans
    case .english: en
    case .korean: ko
    }
  }
}
public struct SkySection: Codable, Hashable, Identifiable, Sendable {
  public let id: String
  public let title: SkyText
  public let text: SkyText
  public let sourceURL: URL
  public init(id: String, title: SkyText, text: SkyText, sourceURL: URL) {
    self.id = id
    self.title = title
    self.text = text
    self.sourceURL = sourceURL
  }
}
public struct SkyCard: Codable, Hashable, Identifiable, Sendable {
  public let id: String
  public let title: SkyText
  public let subtitle: SkyText
  public let caption: SkyText
  public let category: SkyText
  public let capture: SkyText
  public let credit: String
  public let sourceURL: URL
  public let license: String
  public let licenseURL: URL
  public let image: String
  public let sha256: String
  public let width: Int
  public let height: Int
  public let fit: Bool
  public let sections: [SkySection]
  public func matches(_ query: String) -> Bool {
    let haystack = [title, subtitle, category].flatMap { [$0.zhHans, $0.en, $0.ko] }.joined(
      separator: " ")
    return query.split(whereSeparator: \.isWhitespace).allSatisfy {
      haystack.localizedStandardContains(String($0))
    }
  }
}
public struct SkyCatalog: Codable, Sendable {
  public let schemaVersion: Int
  public let version: String
  public private(set) var cards: [SkyCard]
  private var imageRoots: [String: URL] = [:]
  private enum CodingKeys: String, CodingKey { case schemaVersion, version, cards }
  public init(version: String, cards: [SkyCard]) {
    self.schemaVersion = 1
    self.version = version
    self.cards = cards
  }
  public func adding(_ addition: SkyCatalog, root: URL) -> SkyCatalog {
    var result = self
    let known = Set(cards.map(\.id))
    for card in addition.cards where !known.contains(card.id) {
      result.cards.append(card.corrected)
      result.imageRoots[card.id] = root
    }
    return result
  }
  public func located(at root: URL) -> SkyCatalog {
    var result = self
    for card in cards { result.imageRoots[card.id] = root }
    return result
  }
  public static var root: URL {
    // SwiftPM's generated accessor looks beside the executable; an installed
    // macOS app keeps resource bundles inside Contents/Resources.
    if let resources = Bundle.main.resourceURL,
      let packaged = Bundle(
        url: resources.appendingPathComponent("CelestialKit_CelestialKit.bundle")),
      let root = packaged.resourceURL
    {
      return root.appendingPathComponent("astronomy")
    }
    return Bundle.module.resourceURL!.appendingPathComponent("astronomy")
  }
  public static func load() throws -> Self {
    let result = try JSONDecoder().decode(
      Self.self, from: Data(contentsOf: root.appendingPathComponent("catalog.json")))
    try result.validate(verifyImages: false)
    return result
  }
  public func imageURL(_ card: SkyCard) -> URL {
    (imageRoots[card.id] ?? Self.root).appendingPathComponent(card.image)
  }
  public func validate(verifyImages: Bool) throws {
    guard schemaVersion == 1, !cards.isEmpty, Set(cards.map(\.id)).count == cards.count else {
      throw SkyError.invalidContent
    }
    for card in cards {
      guard card.id.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil,
        card.image.hasPrefix("assets/"), !card.image.contains(".."), !card.image.contains("\\"),
        card.width > 0, card.height > 0, card.width <= 16000, card.height <= 16000,
        Int64(card.width) * Int64(card.height) <= 80_000_000, !card.sections.isEmpty,
        !card.credit.isEmpty, card.sourceURL.scheme == "https", card.licenseURL.scheme == "https"
      else { throw SkyError.invalidContent }
      let texts =
        [card.title, card.subtitle, card.caption, card.category, card.capture]
        + card.sections.flatMap { [$0.title, $0.text] }
      guard
        texts.allSatisfy({ t in
          SkyLanguage.allCases.allSatisfy {
            !t.value($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          }
        }), card.sections.allSatisfy({ $0.sourceURL.scheme == "https" })
      else { throw SkyError.invalidContent }
      if verifyImages {
        let data = try Data(contentsOf: imageURL(card))
        guard Self.hash(data) == card.sha256,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          properties[kCGImagePropertyPixelWidth] as? Int == card.width,
          properties[kCGImagePropertyPixelHeight] as? Int == card.height
        else { throw SkyError.invalidContent }
      }
    }
  }
  public static func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
public enum SkyError: Error { case invalidContent, invalidSize, renderFailed }

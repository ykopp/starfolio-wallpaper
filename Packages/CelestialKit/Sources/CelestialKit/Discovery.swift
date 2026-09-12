import Foundation
import ImageIO
import NaturalLanguage

public enum DiscoveryError: Error {
  case network, invalidSource, noUsableImages, tooLarge, libraryFull, translation, cancelled
}

public protocol SkyFetching: Sendable {
  func fetch(_ url: URL, limit: Int) async throws -> Data
}

/// Explicit source and redirect allow-list. Remote documents are always data.
public final class SkyHTTP: NSObject, SkyFetching, URLSessionTaskDelegate, @unchecked Sendable {
  public static let hosts: Set<String> = [
    "esawebb.org", "esahubble.org", "cdn.esawebb.org", "cdn.esahubble.org",
  ]
  public static func allowed(_ url: URL) -> Bool {
    url.scheme == "https" && url.user == nil && url.password == nil
      && (url.port == nil || url.port == 443) && hosts.contains(url.host ?? "")
  }
  public override init() { super.init() }
  public func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(request.url.map(Self.allowed) == true ? request : nil)
  }
  public func fetch(_ url: URL, limit: Int) async throws -> Data {
    guard Self.allowed(url) else { throw DiscoveryError.invalidSource }
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 90
    let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(url: url)
    request.setValue("Starfolio/0.2 (astronomy wallpaper app)", forHTTPHeaderField: "User-Agent")
    let (bytes, response) = try await session.bytes(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200,
      let final = response.url, Self.allowed(final)
    else { throw DiscoveryError.network }
    guard response.expectedContentLength <= limit else { throw DiscoveryError.tooLarge }
    var result = Data()
    var buffer = [UInt8]()
    buffer.reserveCapacity(16384)
    for try await byte in bytes {
      buffer.append(byte)
      if buffer.count == 16384 {
        try Task.checkCancellation()
        guard result.count + buffer.count <= limit else { throw DiscoveryError.tooLarge }
        result.append(contentsOf: buffer)
        buffer.removeAll(keepingCapacity: true)
      }
    }
    guard result.count + buffer.count <= limit else { throw DiscoveryError.tooLarge }
    result.append(contentsOf: buffer)
    return result
  }
}

public struct SkyFeedItem: Sendable {
  public let title: String
  public let link: URL
  public let html: String
  public let date: String
  public var sourceID: String { link.lastPathComponent }
  public var id: String { "live-" + (link.host == "esawebb.org" ? "webb-" : "hubble-") + sourceID }
}

final class FeedReader: NSObject, XMLParserDelegate {
  var items: [SkyFeedItem] = []
  var inside = false
  var field = ""
  var values: [String: String] = [:]
  func parser(
    _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
    qualifiedName: String?, attributes: [String: String]
  ) {
    if name == "item" {
      inside = true
      values = [:]
    }
    field = name
  }
  func parser(_ parser: XMLParser, foundCharacters string: String) {
    if inside { values[field, default: ""] += string }
  }
  func parser(_ parser: XMLParser, foundCDATA block: Data) {
    if let text = String(data: block, encoding: .utf8) {
      self.parser(parser, foundCharacters: text)
    }
  }
  func parser(
    _ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?
  ) {
    if name == "item" {
      defer { inside = false }
      guard
        let link = URL(
          string: (values["link"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
        ["esawebb.org", "esahubble.org"].contains(link.host ?? ""), SkyHTTP.allowed(link),
        link.path.range(of: "^/images/[a-z0-9-]+/?$", options: .regularExpression) != nil
      else { return }
      items.append(
        SkyFeedItem(
          title: values["title"] ?? "", link: link, html: values["description"] ?? "",
          date: values["pubDate"] ?? ""))
    }
    field = ""
  }
  static func parse(_ data: Data) throws -> [SkyFeedItem] {
    guard data.count <= 1_000_000,
      !String(decoding: data, as: UTF8.self).localizedCaseInsensitiveContains("<!DOCTYPE")
    else { throw DiscoveryError.invalidSource }
    let reader = FeedReader()
    let parser = XMLParser(data: data)
    parser.shouldResolveExternalEntities = false
    parser.delegate = reader
    guard parser.parse() else { throw DiscoveryError.invalidSource }
    return reader.items
  }
}

public enum SourceHTML {
  public static func matches(_ pattern: String, in text: String) -> [String] {
    guard
      let regex = try? NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    else { return [] }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
      match in
      guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else {
        return nil
      }
      return String(text[range])
    }
  }
  /// No HTML renderer, scripts, external entities or remote attachments are evaluated.
  public static func plain(_ html: String) -> String {
    var result = html.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
    for (entity, value) in [
      ("&nbsp;", " "), ("&amp;", "&"), ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"),
      ("&gt;", ">"),
    ] { result = result.replacingOccurrences(of: entity, with: value) }
    let numeric = matches("&#(x[0-9a-f]+|[0-9]+);", in: result)
    for value in numeric {
      let number =
        value.lowercased().hasPrefix("x") ? UInt32(value.dropFirst(), radix: 16) : UInt32(value)
      if let number, let scalar = UnicodeScalar(number) {
        result = result.replacingOccurrences(of: "&#\(value);", with: String(scalar))
      }
    }
    return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  static func row(_ label: String, in html: String) -> String {
    matches("<th[^>]*>\\s*" + label + ":\\s*</th>\\s*<td[^>]*>(.*?)</td>", in: html).first.map(
      plain) ?? ""
  }
}

public struct SkyDraft: Sendable {
  public let item: SkyFeedItem
  public let credit: String
  public let category: String
  public let caption: String
  public let paragraphs: [String]
  public let imageURL: URL
  public let image: Data
  public let width: Int
  public let height: Int
  public var texts: [String] { [item.title, caption] + paragraphs }
  public var hash: String { SkyCatalog.hash(image) }
  public var origin: String { item.link.host == "esawebb.org" ? "ESA/Webb" : "ESA/Hubble" }
  public func makeCard(chinese: [String], korean: [String]) throws -> SkyCard {
    guard chinese.count == texts.count, korean.count == texts.count,
      (chinese + korean).allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    else { throw DiscoveryError.translation }
    func text(_ i: Int) -> SkyText {
      .init(
        zhHans: AstronomyTerms.normalize(chinese[i], source: texts[i], language: .chinese),
        en: texts[i],
        ko: AstronomyTerms.normalize(korean[i], source: texts[i], language: .korean))
    }
    let sections = paragraphs.indices.map { index in
      SkySection(
        id: "source-\(index)",
        title: .init(
          zhHans: "观测笔记 \(index+1)", en: "Observation notes \(index+1)", ko: "관측 노트 \(index+1)"),
        text: text(index + 2), sourceURL: item.link)
    }
    let categories: [(String, SkyText)] = [
      ("nebula", .init(zhHans: "星云", en: "Nebulae", ko: "성운")),
      ("galax", .init(zhHans: "星系", en: "Galaxies", ko: "은하")),
      ("cluster", .init(zhHans: "星团", en: "Star clusters", ko: "성단")),
      ("exoplanet", .init(zhHans: "系外行星", en: "Exoplanets", ko: "외계 행성")),
      ("solar system", .init(zhHans: "太阳系", en: "Solar system", ko: "태양계")),
      ("star", .init(zhHans: "恒星", en: "Stars", ko: "별")),
      ("black hole", .init(zhHans: "黑洞", en: "Black holes", ko: "블랙홀")),
    ]
    let category =
      categories.first { category.localizedCaseInsensitiveContains($0.0) }?.1
      ?? SkyText(zhHans: "天文观测", en: "Astronomical observation", ko: "천체 관측")
    let capture = SkyText(
      zhHans: "\(origin) 官方说明摘录 · 本机机器翻译",
      en: "\(origin) source excerpts · On-device machine translation",
      ko: "\(origin) 공식 설명 발췌 · 기기 내 기계 번역")
    return SkyCard(
      id: item.id, title: text(0), subtitle: .init(zhHans: origin, en: origin, ko: origin),
      caption: text(1), category: category, capture: capture,
      credit: credit, sourceURL: item.link, license: "CC BY 4.0",
      licenseURL: URL(string: "https://\(item.link.host!)/copyright/")!,
      image: "assets/\(item.id).jpg", sha256: hash, width: width, height: height, fit: false,
      sections: sections)
  }
}

public struct DiscoveryBatch: Sendable {
  public let drafts: [SkyDraft]
  public let failedSources: Int
  public let skipped: Int
}

public struct SkyDiscovery: Sendable {
  public let http: any SkyFetching
  public init(http: any SkyFetching = SkyHTTP()) { self.http = http }
  public func discover(excluding catalog: SkyCatalog, maximum: Int = 3) async throws
    -> DiscoveryBatch
  {
    let hosts = ["esawebb.org", "esahubble.org"]
    var feeds: [[SkyFeedItem]] = []
    var failed = 0
    var skipped = 0
    for host in hosts {
      try Task.checkCancellation()
      do {
        let policy = String(
          decoding: try await http.fetch(
            URL(string: "https://\(host)/copyright/")!, limit: 1_000_000), as: UTF8.self)
        guard SourceHTML.plain(policy).contains("Creative Commons Attribution 4.0") else {
          throw DiscoveryError.invalidSource
        }
        feeds.append(
          Array(
            try FeedReader.parse(
              await http.fetch(URL(string: "https://\(host)/images/feed/")!, limit: 1_000_000)
            ).prefix(25)))
      } catch is CancellationError { throw CancellationError() } catch {
        failed += 1
        feeds.append([])
      }
    }
    guard failed < hosts.count else { throw DiscoveryError.network }
    var queue: [SkyFeedItem] = []
    for index in 0..<(feeds.map(\.count).max() ?? 0) {
      for feed in feeds where feed.indices.contains(index) { queue.append(feed[index]) }
    }
    let knownURLs = Set(catalog.cards.map(\.sourceURL))
    var knownIDs = Set(catalog.cards.map(\.id))
    var hashes = Set(catalog.cards.map(\.sha256))
    var drafts: [SkyDraft] = []
    var inspected = 0
    for item in queue {
      try Task.checkCancellation()
      if drafts.count >= maximum || inspected >= 16 { break }
      // Only the lead observation in a release; exclude charts, crops and comparison panels.
      guard item.sourceID.hasSuffix("a"), !knownIDs.contains(item.id),
        !knownURLs.contains(item.link)
      else { continue }
      inspected += 1
      do {
        let page = String(
          decoding: try await http.fetch(item.link, limit: 1_000_000), as: UTF8.self)
        guard let metadata = try Self.metadata(item: item, page: page) else {
          skipped += 1
          continue
        }
        let bytes = try await http.fetch(metadata.imageURL, limit: 20_000_000)
        guard let image = CGImageSourceCreateWithData(bytes as CFData, nil),
          CGImageSourceGetType(image) as String? == "public.jpeg",
          let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
          let w = properties[kCGImagePropertyPixelWidth] as? Int,
          let h = properties[kCGImagePropertyPixelHeight] as? Int,
          w >= 1600, h >= 900, w <= 16000, h <= 16000, Int64(w) * Int64(h) <= 50_000_000
        else {
          skipped += 1
          continue
        }
        let hash = SkyCatalog.hash(bytes)
        guard !hashes.contains(hash) else { continue }
        drafts.append(
          SkyDraft(
            item: item, credit: metadata.credit, category: metadata.category,
            caption: metadata.caption, paragraphs: metadata.paragraphs, imageURL: metadata.imageURL,
            image: bytes, width: w, height: h))
        hashes.insert(hash)
        knownIDs.insert(item.id)
      } catch is CancellationError { throw CancellationError() } catch { skipped += 1 }
    }
    return DiscoveryBatch(drafts: drafts, failedSources: failed, skipped: skipped)
  }
  struct Metadata {
    let credit: String
    let category: String
    let caption: String
    let paragraphs: [String]
    let imageURL: URL
  }
  static func metadata(item: SkyFeedItem, page: String) throws -> Metadata? {
    guard !item.title.isEmpty, item.title.count <= 180,
      SourceHTML.row("Type", in: page) == "Observation"
    else { return nil }
    let category = SourceHTML.row("Category", in: page)
    let astronomy = [
      "galax", "nebula", "star", "solar system", "exoplanet", "quasar", "black hole",
    ]
    guard astronomy.contains(where: { category.localizedCaseInsensitiveContains($0) }),
      let creditHTML = SourceHTML.matches(
        "<div[^>]*class=[\"']credit[\"'][^>]*>(.*?)</div>", in: page
      ).first
    else { return nil }
    let credit = SourceHTML.plain(creditHTML)
    let rightsText = SourceHTML.plain(item.html + " " + page + " " + credit)
    let restrictions = ["all rights reserved", "permission required", "permission is required"]
    guard !credit.isEmpty, credit.count <= 350,
      !restrictions.contains(where: { rightsText.localizedCaseInsensitiveContains($0) })
    else { return nil }
    let paragraphs = SourceHTML.matches("<p[^>]*>(.*?)</p>", in: item.html).map(SourceHTML.plain)
      .filter {
        $0.count > 70 && $0.count <= 3500 && !$0.hasPrefix("[")
          && !$0.localizedCaseInsensitiveContains("Image Description:")
          && !$0.localizedCaseInsensitiveContains("Links")
      }.prefix(3).map { $0 }
    guard !paragraphs.isEmpty else { return nil }
    let tokenizer = NLTokenizer(unit: .sentence)
    var sentences: [String] = []
    for paragraph in paragraphs {
      tokenizer.string = paragraph
      tokenizer.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { range, _ in
        let sentence = String(paragraph[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        if sentence.count >= 30 && sentence.count <= 300 { sentences.append(sentence) }
        return true
      }
    }
    // Prefer a complete factual sentence over the publisher's recurring introduction.
    let caption =
      sentences.first {
        !$0.localizedCaseInsensitiveContains("picture of the month")
          && !$0.localizedCaseInsensitiveContains("picture of the week")
          && !$0.localizedCaseInsensitiveContains("today")
          && !$0.lowercased().hasPrefix("it ") && !$0.lowercased().hasPrefix("this ")
      } ?? sentences.first ?? item.title
    let expected =
      "https://cdn.\(item.link.host!)/archives/images/publicationjpg/\(item.sourceID).jpg"
    let links = SourceHTML.matches("href=[\"']([^\"']+)[\"']", in: page)
    guard links.contains(expected), let image = URL(string: expected), SkyHTTP.allowed(image) else {
      return nil
    }
    return Metadata(
      credit: credit, category: category, caption: caption, paragraphs: paragraphs, imageURL: image)
  }
}

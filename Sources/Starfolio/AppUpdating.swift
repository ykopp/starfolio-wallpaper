import Foundation

struct AppRelease: Decodable, Sendable {
  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case htmlURL = "html_url"
    case draft, prerelease, assets
  }
  let tagName: String
  let htmlURL: String
  let draft: Bool
  let prerelease: Bool
  let assets: [Asset]
  struct Asset: Decodable, Sendable {
    enum CodingKeys: String, CodingKey {
      case name
      case browserDownloadURL = "browser_download_url"
    }
    let name: String
    let browserDownloadURL: String
  }
}
@MainActor final class AppUpdating: ObservableObject {
  nonisolated static let version =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.1"
  static let repository = "https://github.com/ykopp/starfolio-wallpaper"
  @Published private(set) var checking = false
  @Published private(set) var state: Copy = .appUpdateReady
  @Published private(set) var availableVersion: String?
  @Published private(set) var releaseURL: URL?
  private let fetch: @Sendable () async throws -> Data
  init(fetch: (@Sendable () async throws -> Data)? = nil) {
    self.fetch = fetch ?? Self.download
  }
  nonisolated static func download() async throws -> Data {
    var request = URLRequest(
      url: URL(
        string: "https://api.github.com/repos/ykopp/starfolio-wallpaper/releases?per_page=100")!)
    request.timeoutInterval = 20
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }
    var data = Data()
    for try await byte in bytes {
      guard data.count < 2_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
      data.append(byte)
    }
    return data
  }
  nonisolated static func components(_ version: String) -> [Int]? {
    let parts = version.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3,
      parts.allSatisfy({ !$0.isEmpty && $0.count <= 6 && $0.allSatisfy({ $0 >= "0" && $0 <= "9" }) }
      )
    else { return nil }
    return parts.compactMap { Int($0) }
  }
  func check(current: String = AppUpdating.version) async {
    guard !checking else { return }
    checking = true
    state = .appChecking
    availableVersion = nil
    releaseURL = nil
    defer { checking = false }
    do {
      let data = try await fetch()
      guard data.count <= 2_000_000, let local = Self.components(current) else {
        throw URLError(.cannotParseResponse)
      }
      let releases = try JSONDecoder().decode([AppRelease].self, from: data)
      // Development previews are explicitly included; /releases/latest excludes them.
      let candidates = releases.compactMap { release -> (String, [Int], URL)? in
        guard !release.draft, release.tagName.hasPrefix("v") else { return nil }
        let version = String(release.tagName.dropFirst())
        guard let numbers = Self.components(version), local.lexicographicallyPrecedes(numbers),
          release.htmlURL == Self.repository + "/releases/tag/v" + version,
          let url = URL(string: release.htmlURL),
          release.assets.contains(where: {
            $0.name == "Starfolio-\(version)-macOS-arm64.zip"
              && $0.browserDownloadURL == Self.repository
                + "/releases/download/v\(version)/Starfolio-\(version)-macOS-arm64.zip"
          })
        else { return nil }
        return (version, numbers, url)
      }
      if let newest = candidates.max(by: { $0.1.lexicographicallyPrecedes($1.1) }) {
        availableVersion = newest.0
        releaseURL = newest.2
        state = .appUpdateFound
      } else {
        state = .appUpToDate
      }
    } catch { state = .appUpdateFailed }
  }
}

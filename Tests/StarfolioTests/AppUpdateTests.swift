import Foundation
import Testing

@testable import Starfolio

@Suite @MainActor struct AppUpdateTests {
  func release(
    _ version: String, draft: Bool = false, asset: Bool = true,
    host: String = AppUpdating.repository
  ) -> [String: Any] {
    [
      "tag_name": "v" + version, "html_url": host + "/releases/tag/v" + version,
      "draft": draft, "prerelease": true,
      "assets": asset
        ? [
          [
            "name": "Starfolio-\(version)-macOS-arm64.zip",
            "browser_download_url": host
              + "/releases/download/v\(version)/Starfolio-\(version)-macOS-arm64.zip",
          ]
        ] : [],
    ]
  }
  @Test func selectsNewestPreviewNumericallyAndRejectsUntrustedOrIncompleteReleases() async throws {
    let data = try JSONSerialization.data(withJSONObject: [
      release("0.3.2"), release("0.3.10"), release("0.3.99", draft: true),
      release("0.4.0", asset: false), release("9.0.0", host: "https://example.com"),
    ])
    let updater = AppUpdating(fetch: { data })
    await updater.check(current: "0.3.1")
    #expect(updater.availableVersion == "0.3.10")
    #expect(updater.releaseURL?.absoluteString == AppUpdating.repository + "/releases/tag/v0.3.10")
    await updater.check(current: "0.3.10")
    #expect(updater.availableVersion == nil)
    #expect(updater.releaseURL == nil)
    #expect(updater.state == .appUpToDate)
  }
  @Test func malformedResponsesAndFailuresHaveRetryableState() async {
    let updater = AppUpdating(fetch: { Data("invalid".utf8) })
    await updater.check()
    #expect(!updater.checking)
    #expect(updater.state == .appUpdateFailed)
    let offline = AppUpdating(fetch: { throw URLError(.notConnectedToInternet) })
    await offline.check()
    #expect(offline.state == .appUpdateFailed)
    #expect(offline.releaseURL == nil)
    #expect(AppUpdating.components("0.3.10") == [0, 3, 10])
    #expect(AppUpdating.components("0.3.-1") == nil)
    #expect(AppUpdating.components("0.3.1/evil") == nil)
  }
  @Test(.enabled(if: ProcessInfo.processInfo.environment["STARFOLIO_APP_UPDATE_LIVE"] == "1"))
  func liveGitHubChannelFindsPublishedInstallableRelease() async {
    let updater = AppUpdating()
    await updater.check(
      current: ProcessInfo.processInfo.environment["STARFOLIO_APP_UPDATE_FROM"] ?? "0.0.0")
    #expect(updater.state == .appUpdateFound)
    #expect(updater.releaseURL != nil)
    #expect(updater.availableVersion != nil)
    if let expected = ProcessInfo.processInfo.environment["STARFOLIO_APP_UPDATE_EXPECT"] {
      #expect(updater.availableVersion == expected)
    }
  }
}

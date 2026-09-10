import Foundation

public struct LibraryRead: Sendable {
  public let catalog: SkyCatalog
  public let unreadableBatches: Int
  public let newestCardIDs: Set<String>
}

/// Each transaction is moved into place before an atomic index update. Existing
/// image files and the previous index are never modified in place or evicted.
public struct SkyLibrary: Sendable {
  public let root: URL
  public let byteLimit: Int
  public init(root: URL, byteLimit: Int = 512_000_000) {
    self.root = root
    self.byteLimit = byteLimit
  }
  private struct Index: Codable {
    let version: Int
    let batches: [String]
  }
  private var indexURL: URL { root.appendingPathComponent("index.json") }
  private func index() throws -> Index {
    if !FileManager.default.fileExists(atPath: indexURL.path) {
      return Index(version: 1, batches: [])
    }
    let data = try Data(contentsOf: indexURL)
    guard data.count <= 256_000 else { throw SkyError.invalidContent }
    let index = try JSONDecoder().decode(Index.self, from: data)
    guard index.version == 1, index.batches.count <= 200,
      Set(index.batches).count == index.batches.count,
      index.batches.allSatisfy({
        $0.range(of: "^[A-Fa-f0-9-]{36}$", options: .regularExpression) != nil
      })
    else { throw SkyError.invalidContent }
    return index
  }
  public func read(onto base: SkyCatalog) -> LibraryRead {
    var catalog = base
    var failed = 0
    var newest: Set<String> = []
    do {
      for name in try index().batches {
        do {
          let folder = root.appendingPathComponent("batches/\(name)")
          let metadata = try Data(contentsOf: folder.appendingPathComponent("catalog.json"))
          guard metadata.count <= 2_000_000 else { throw SkyError.invalidContent }
          let pack = try JSONDecoder().decode(SkyCatalog.self, from: metadata).located(at: folder)
          guard pack.cards.count <= 3 else { throw SkyError.invalidContent }
          for card in pack.cards {
            guard
              pack.imageURL(card).resolvingSymlinksInPath().path.hasPrefix(
                folder.resolvingSymlinksInPath().path + "/")
            else { throw SkyError.invalidContent }
          }
          try pack.validate(verifyImages: true)
          catalog = catalog.adding(pack, root: folder)
          newest = Set(pack.cards.map(\.id))
        } catch { failed += 1 }
      }
    } catch { failed += 1 }
    return LibraryRead(catalog: catalog, unreadableBatches: failed, newestCardIDs: newest)
  }
  public func makeStagingDirectory() throws -> URL {
    let folder = root.appendingPathComponent("staging/\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: folder.appendingPathComponent("assets"), withIntermediateDirectories: true)
    return folder
  }
  public func commit(staging: URL, cards: [SkyCard], base: SkyCatalog) throws -> SkyCatalog {
    try Task.checkCancellation()
    guard
      staging.deletingLastPathComponent().standardizedFileURL
        == root.appendingPathComponent("staging").standardizedFileURL,
      !cards.isEmpty, cards.count <= 3
    else { throw SkyError.invalidContent }
    let old = try index()
    let current = read(onto: base)
    guard current.unreadableBatches == 0 else { throw SkyError.invalidContent }
    let knownIDs = Set(current.catalog.cards.map(\.id))
    let knownHashes = Set(current.catalog.cards.map(\.sha256))
    guard cards.allSatisfy({ !knownIDs.contains($0.id) && !knownHashes.contains($0.sha256) }) else {
      throw SkyError.invalidContent
    }
    let pack = SkyCatalog(version: "live-1", cards: cards).located(at: staging)
    try pack.validate(verifyImages: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(pack).write(
      to: staging.appendingPathComponent("catalog.json"), options: .atomic)
    let files = FileManager.default.enumerator(
      at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
    var total = 0
    while let file = files?.nextObject() as? URL {
      let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      if values.isRegularFile == true { total += values.fileSize ?? 0 }
      guard total <= byteLimit else { throw DiscoveryError.libraryFull }
    }
    guard old.batches.count < 200 else { throw DiscoveryError.libraryFull }
    let name = UUID().uuidString
    let folder = root.appendingPathComponent("batches/\(name)")
    try FileManager.default.createDirectory(
      at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Task.checkCancellation()
    try FileManager.default.moveItem(at: staging, to: folder)
    do {
      try encoder.encode(Index(version: 1, batches: old.batches + [name])).write(
        to: indexURL, options: .atomic)
    } catch {
      // This newly created batch is not referenced by the index or any desktop.
      try? FileManager.default.removeItem(at: folder)
      throw error
    }
    return current.catalog.adding(pack, root: folder)
  }
}

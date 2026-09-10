import AppKit
import ImageIO

public enum SkyWallpaperMode: String, Codable, CaseIterable, Sendable { case knowledge, pure }
@MainActor public enum SkyRenderer {
  public static let version = 2
  public static func render(
    card: SkyCard, imageURL: URL, size: CGSize, language: SkyLanguage, mode: SkyWallpaperMode,
    directory: URL
  ) throws -> URL {
    guard size.width.isFinite, size.height.isFinite, size.width >= 100, size.height >= 100,
      size.width <= 10000, size.height <= 10000, size.width * size.height <= 50_000_000
    else { throw SkyError.invalidSize }
    let w = Int(size.width)
    let h = Int(size.height)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let identity = try encoder.encode(card)
    let key = String(SkyCatalog.hash(identity).prefix(16))
    let url = directory.appendingPathComponent(
      "\(card.id)-\(w)x\(h)-\(language.rawValue)-\(mode.rawValue)-v\(version)-\(key).png")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: url.path) {
      guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
        props[kCGImagePropertyPixelWidth] as? Int == w,
        props[kCGImagePropertyPixelHeight] as? Int == h
      else { throw SkyError.renderFailed }
      return url
    }
    guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
      let photo = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw SkyError.renderFailed }
    let width = CGFloat(w)
    let height = CGFloat(h)
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(canvas)
    let field =
      card.fit && mode == .knowledge
      ? CGRect(x: width * 0.02, y: height * 0.22, width: width * 0.96, height: height * 0.78)
      : canvas
    let scale =
      card.fit
      ? min(field.width / CGFloat(photo.width), field.height / CGFloat(photo.height))
      : max(field.width / CGFloat(photo.width), field.height / CGFloat(photo.height))
    let pw = CGFloat(photo.width) * scale
    let ph = CGFloat(photo.height) * scale
    ctx.saveGState()
    ctx.clip(to: field)
    ctx.interpolationQuality = .high
    ctx.draw(
      photo, in: CGRect(x: field.midX - pw / 2, y: field.midY - ph / 2, width: pw, height: ph))
    ctx.restoreGState()
    if mode == .knowledge && !card.fit {
      let colors =
        [
          NSColor.black.withAlphaComponent(0.77).cgColor,
          NSColor.black.withAlphaComponent(0).cgColor,
        ] as CFArray
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
      ctx.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height * 0.48), options: [])
    }
    let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    defer { NSGraphicsContext.restoreGraphicsState() }
    let unit = max(0.72, width / 1470)
    let left = width * 0.057
    let textWidth = width * 0.84
    func text(
      _ value: String, _ rect: CGRect, _ font: CGFloat, _ weight: NSFont.Weight, _ color: NSColor
    ) {
      let para = NSMutableParagraphStyle()
      para.lineBreakMode = .byWordWrapping
      para.lineSpacing = 3 * unit
      (value as NSString).draw(
        with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [
          .font: NSFont.systemFont(ofSize: font, weight: weight), .foregroundColor: color,
          .paragraphStyle: para,
        ])
    }
    func fittedFont(
      _ value: String, rect: CGRect, maximum: CGFloat, minimum: CGFloat, weight: NSFont.Weight
    ) -> CGFloat {
      var font = maximum
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineSpacing = 3 * unit
      while font > minimum {
        let measured = (value as NSString).boundingRect(
          with: CGSize(width: rect.width, height: 10000),
          options: [.usesLineFragmentOrigin, .usesFontLeading],
          attributes: [
            .font: NSFont.systemFont(ofSize: font, weight: weight), .paragraphStyle: paragraph,
          ])
        if measured.height <= rect.height { break }
        font -= unit
      }
      return font
    }
    if mode == .knowledge {
      let bottom = height * 0.11
      let factSize = 18 * unit
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineSpacing = 3 * unit
      let factHeight =
        (card.caption.value(language) as NSString).boundingRect(
          with: CGSize(width: textWidth, height: height),
          options: [.usesLineFragmentOrigin, .usesFontLeading],
          attributes: [.font: NSFont.systemFont(ofSize: factSize), .paragraphStyle: paragraph]
        ).height + 5 * unit
      text(
        card.caption.value(language),
        CGRect(x: left, y: bottom, width: textWidth, height: factHeight), factSize, .regular, .white
      )
      var baseline = bottom + factHeight + 20 * unit
      if language != .english {
        text(
          card.title.en, CGRect(x: left, y: baseline, width: textWidth, height: 30 * unit),
          fittedFont(
            card.title.en, rect: CGRect(x: 0, y: 0, width: textWidth, height: 30 * unit),
            maximum: 20 * unit, minimum: 12 * unit, weight: .medium), .medium,
          NSColor(white: 0.85, alpha: 1))
        baseline += 37 * unit
      }
      let titleRect = CGRect(x: left, y: baseline, width: textWidth, height: 65 * unit)
      text(
        card.title.value(language), titleRect,
        fittedFont(
          card.title.value(language), rect: titleRect, maximum: 44 * unit, minimum: 18 * unit,
          weight: .bold), .bold, .white)
      baseline += 68 * unit
      text(
        card.subtitle.value(language),
        CGRect(x: left, y: baseline, width: textWidth, height: 26 * unit), 15 * unit, .medium,
        NSColor(red: 0.9, green: 0.85, blue: 0.76, alpha: 1))
    }
    let creditRect = CGRect(x: left, y: height * 0.035, width: textWidth, height: height * 0.060)
    let creditSize = fittedFont(
      card.credit, rect: creditRect, maximum: max(10, width * 0.0082), minimum: 8 * unit,
      weight: .regular)
    if mode == .pure {
      ctx.setFillColor(NSColor.black.withAlphaComponent(0.4).cgColor)
      let measured = (card.credit as NSString).size(withAttributes: [
        .font: NSFont.systemFont(ofSize: creditSize)
      ])
      ctx.fill(
        CGRect(
          x: left - 4, y: creditRect.minY, width: min(textWidth, measured.width + 8),
          height: creditRect.height))
    }
    text(card.credit, creditRect, creditSize, .regular, NSColor(white: 0.87, alpha: 1))
    guard let image = ctx.makeImage() else { throw SkyError.renderFailed }
    let staging = directory.appendingPathComponent(".\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: staging) }
    guard
      let destination = CGImageDestinationCreateWithURL(
        staging as CFURL, "public.png" as CFString, 1, nil)
    else { throw SkyError.renderFailed }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw SkyError.renderFailed }
    try FileManager.default.moveItem(at: staging, to: url)
    return url
  }
}

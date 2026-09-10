import AppKit
import ImageIO

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let graphics = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = graphics
let rounded = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 205, yRadius: 205)
NSGradient(starting: NSColor(red: 0.10, green: 0.17, blue: 0.26, alpha: 1), ending: NSColor(red: 0.018, green: 0.03, blue: 0.065, alpha: 1))!.draw(in: rounded, angle: -75)
let back = NSBezierPath(roundedRect: NSRect(x: 260, y: 235, width: 480, height: 555), xRadius: 32, yRadius: 32)
let transform = AffineTransform(rotationByDegrees: -9)
back.transform(using: transform)
NSColor(red: 0.35, green: 0.48, blue: 0.62, alpha: 0.45).setFill(); back.fill()
let front = NSBezierPath(roundedRect: NSRect(x: 285, y: 235, width: 490, height: 580), xRadius: 36, yRadius: 36)
NSColor(red: 0.68, green: 0.77, blue: 0.85, alpha: 0.88).setStroke(); front.lineWidth = 9; front.stroke()
func star(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) {
    let path = NSBezierPath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        let length = i.isMultiple(of: 2) ? radius : radius * 0.22
        let p = NSPoint(x: x + sin(angle) * length, y: y + cos(angle) * length)
        if i == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close(); NSColor(red: 0.91, green: 0.94, blue: 0.98, alpha: 1).setFill(); path.fill()
}
star(533, 564, 166); star(678, 728, 40); star(382, 377, 25)
let line = NSBezierPath(); line.move(to: NSPoint(x: 435, y: 334)); line.line(to: NSPoint(x: 647, y: 334)); line.lineWidth = 7
NSColor(red: 0.69, green: 0.79, blue: 0.87, alpha: 0.65).setStroke(); line.stroke()
let output = CGImageDestinationCreateWithURL(destination as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(output))

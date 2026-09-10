import AppKit
import CoreImage

enum SampleArtwork {
    // Original procedural artwork; used instead of capturing the desktop in Settings.
    static func sample() -> CIImage {
        let size = CGSize(width: 1000, height: 625)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(calibratedRed: 0.05, green: 0.16, blue: 0.32, alpha: 1).setFill()
            rect.fill()
            let colors: [NSColor] = [
                .init(calibratedRed: 0.10, green: 0.39, blue: 0.66, alpha: 1),
                .init(calibratedRed: 0.17, green: 0.66, blue: 0.76, alpha: 1),
                .init(calibratedRed: 0.55, green: 0.83, blue: 0.87, alpha: 1)
            ]
            for i in 0..<3 {
                colors[i].setFill()
                let path = NSBezierPath()
                let y = CGFloat(i) * 115
                path.move(to: CGPoint(x: -80, y: y))
                path.curve(to: CGPoint(x: 1080, y: y + 130), controlPoint1: CGPoint(x: 260, y: y + 720), controlPoint2: CGPoint(x: 730, y: y - 80))
                path.line(to: CGPoint(x: 1080, y: -80))
                path.line(to: CGPoint(x: -80, y: -80))
                path.close(); path.fill()
            }
            NSColor.black.withAlphaComponent(0.14).setFill()
            NSBezierPath(roundedRect: CGRect(x: 260, y: 24, width: 480, height: 63), xRadius: 20, yRadius: 20).fill()
            for i in 0..<8 {
                NSColor(calibratedHue: CGFloat(i) / 9, saturation: 0.45, brightness: 0.96, alpha: 1).setFill()
                NSBezierPath(roundedRect: CGRect(x: 279 + i * 56, y: 34, width: 43, height: 43), xRadius: 11, yRadius: 11).fill()
            }
            NSColor.white.withAlphaComponent(0.17).setFill()
            CGRect(x: 0, y: 594, width: 1000, height: 31).fill()
            let text = "Desktop     File     Edit     View"
            text.draw(at: CGPoint(x: 20, y: 602), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.white])
            return true
        }
        var rect = CGRect(origin: .zero, size: size)
        return CIImage(cgImage: image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!)
    }
}

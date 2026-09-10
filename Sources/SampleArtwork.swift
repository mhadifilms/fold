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
            drawContent()
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
    private static func text(_ value:String,_ x:CGFloat,_ y:CGFloat,size:CGFloat,weight:NSFont.Weight = .regular,color:NSColor = .darkGray) {
        let attributes:[NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color]
        value.draw(at:CGPoint(x:x,y:y),withAttributes:attributes)
    }
    private static func drawContent() {
        NSColor.white.withAlphaComponent(0.94).setFill()
        NSBezierPath(roundedRect:CGRect(x:92,y:176,width:455,height:352),xRadius:16,yRadius:16).fill()
        let colors:[NSColor] = [.systemRed,.systemYellow,.systemGreen]
        for (i,color) in colors.enumerated() {
            color.setFill(); NSBezierPath(ovalIn:CGRect(x:CGFloat(110+i*19),y:501,width:10,height:10)).fill()
        }
        text("A little room to think.",120,446,size:25,weight:.semibold)
        text("IDEAS FOR A SLOW MORNING",120,414,size:11,weight:.bold,color:.systemBlue)
        let lines = ["Open the window.","Make something worth keeping.","Take the long way home.","Leave a little space for surprise."]
        for (i,line) in lines.enumerated() {
            text(line,142,CGFloat(365-i*37),size:16)
            NSColor.systemBlue.setStroke()
            NSBezierPath(ovalIn:CGRect(x:121,y:CGFloat(368-i*37),width:10,height:10)).stroke()
        }
        for i in 0..<2 {
            let y = CGFloat(346-i*175)
            NSColor.white.withAlphaComponent(0.86).setFill()
            NSBezierPath(roundedRect:CGRect(x:596,y:y,width:288,height:150),xRadius:18,yRadius:18).fill()
            text(i == 0 ? "September" : "Evening walk",620,y+112,size:20,weight:.semibold)
            if i == 0 {
                for day in 0..<21 {
                    text(String(day+1),CGFloat(620+(day%7)*35),y+CGFloat(76-(day/7)*25),size:13,weight:.medium,color:day == 9 ? .systemBlue : .darkGray)
                }
            } else {
                text("18:30   ·   By the water",620,y+76,size:15)
                NSColor.systemTeal.withAlphaComponent(0.3).setFill()
                NSBezierPath(roundedRect:CGRect(x:620,y:y+24,width:230,height:23),xRadius:8,yRadius:8).fill()
            }
        }
    }

}

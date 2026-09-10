import AppKit
import CoreImage

enum SelfTests {
    static func run() throws {
        var count=0
        func check(_ value: Bool,_ label: String) {
            guard value else { print("FAIL: \(label)");exit(1) }
            count += 1;print("PASS: \(label)")
        }
        check(LidSensor.decode([1,95,0]) == 95,"Sensor reads degrees")
        check(LidSensor.decode([1,104,1]) == 360,"Little-endian sensor report")
        check(LidSensor.decode([1,255,255]) == nil && LidSensor.decode([1]) == nil,"Reject invalid sensor data")
        check(FoldSettings(angle:.nan).progress == 0,"Invalid angle fails clear")
        check(FoldSettings(angle:130).progress == 0 && FoldSettings(angle:-5).progress == 1,"Angle range clamped")
        var auth=CaptureAuthorization(),requests=0
        for _ in 0..<100 { _=auth.startup(preflight:{false},request:{requests += 1;return false}) }
        check(requests == 1,"Permission requested at most once in a launch after denial")
        auth=CaptureAuthorization();requests=0
        _=auth.startup(preflight:{true},request:{requests += 1;return false})
        check(requests == 0,"No prompt when already authorized")
        var a=MotionSmoother(),b=MotionSmoother()
        for _ in 0..<60 { _=a.step(target:1,dt:1.0/60) }
        for _ in 0..<120 { _=b.step(target:1,dt:1.0/120) }
        check(abs(a.value-b.value)<0.00001,"Motion consistent at 60 and 120 Hz")
        check(a.value>0.999 && a.value<=1,"Motion converges without overshoot")
        var reversal=MotionSmoother();var finite=true
        for i in 0..<240 {
            let x=reversal.step(target:i<120 ? 0.8 : 0,dt:1.0/120)
            finite = finite && x.isFinite && x>=0 && x<=1
        }
        check(finite && reversal.value<0.0001,"Rapid reversal stays stable and clears")
        var safety=FoldSafety()
        check(!safety.permitsEffect(angle:120,clearAngle:90,now:0),"Normal working angles stay clear")
        check(!safety.permitsEffect(angle:95,clearAngle:90,now:0.1),"Closing above 90 degrees stays clear")
        check(safety.permitsEffect(angle:89,clearAngle:90,now:0.2),"Crossing below 90 degrees while closing starts the effect")
        check(!safety.permitsEffect(angle:90,clearAngle:90,now:0.3),"Returning to 90 degrees clears immediately")
        check(!safety.permitsEffect(angle:110,clearAngle:90,now:0.4),"Opening farther never rearms the effect")
        _=safety.permitsEffect(angle:50,clearAngle:90,now:0.5)
        check(safety.permitsEffect(angle:60,clearAngle:90,now:0.6),"An active fold follows reopening")
        check(safety.permitsEffect(angle:60,clearAngle:90,now:0.70),"Brief gaps between opening sensor steps remain smooth")
        check(!safety.permitsEffect(angle:60,clearAngle:90,now:0.73),"Pausing reopening clears in 120 milliseconds")
        check(!safety.permitsEffect(angle:65,clearAngle:90,now:0.8),"Continuing to open after a pause cannot bring the blur back")
        check(safety.permitsEffect(angle:64,clearAngle:90,now:0.9),"Closing again rearms below the fixed trigger")
        check(!safety.permitsEffect(angle:64,clearAngle:90,now:1.36),"A closing hold clears in 450 milliseconds")
        check(!safety.permitsEffect(angle:63.8,clearAngle:90,now:1.4),"Tiny sensor jitter cannot rearm")
        check(safety.permitsEffect(angle:62,clearAngle:90,now:1.5),"Further closing rearms without opening fully")
        _=safety.permitsEffect(angle:7,clearAngle:90,now:1.6)
        check(!safety.permitsEffect(angle:7,clearAngle:90,now:1.71),"Nearly closed clears in 100 milliseconds")
        check(!safety.permitsEffect(angle:359,clearAngle:90,now:1.8),"Sensor wraparound clears the effect")
        check(!safety.permitsEffect(angle:nil,clearAngle:90,now:1.9),"Lost sensor clears the effect")
        _=safety.permitsEffect(angle:50,clearAngle:90,now:2)
        check(safety.permitsEffect(angle:49,clearAngle:90,now:2.1),"Sensor recovery accepts the next closing movement")
        safety.suspend()
        check(safety.permitsEffect(angle:48,clearAngle:90,now:2.2),"Wake can resume by closing from the current position")
        var bounded=FoldSafety()
        _=bounded.permitsEffect(angle:80,clearAngle:90,now:0)
        for i in 1...160 { _=bounded.permitsEffect(angle:i%2==0 ? 40 : 50,clearAngle:90,now:Double(i)*0.05) }
        check(!bounded.permitsEffect(angle:45,clearAngle:90,now:8.06),"A continuously moving fold still has an eight-second ceiling")
        let gpu=try FoldGPU()
        let top=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:CGRect(x:0,y:50,width:100,height:50))
        let bottom=CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:CGRect(x:0,y:0,width:100,height:50))
        let orientation=try gpu.renderOffscreen(top.composited(over:bottom),settings:FoldSettings(angle:100),size:CGSize(width:100,height:100)).0
        let orientationPixels=NSBitmapImageRep(cgImage:orientation)
        check((orientationPixels.colorAt(x:50,y:10)?.redComponent ?? 0)>0.9 && (orientationPixels.colorAt(x:50,y:90)?.blueComponent ?? 0)>0.9,"Desktop orientation stays upright")
        let sample=SampleArtwork.sample()
        let size=CGSize(width:1280,height:800)
        let outputIndex=CommandLine.arguments.firstIndex(of:"--render-dir")
        let folder=outputIndex.map { URL(fileURLWithPath:CommandLine.arguments[$0+1]) }
        if let folder { try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true) }
        var timings=[Double]()
        for angle in [100.0,75,50,25,5] {
            let result=try gpu.renderOffscreen(sample,settings:FoldSettings(angle:angle),size:size)
            timings.append(result.1)
            let bitmap=NSBitmapImageRep(cgImage:result.0)
            let corners=[(0,0),(1279,0),(0,799),(1279,799)]
            let filled=corners.allSatisfy { x,y in
                guard let c=bitmap.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else { return false }
                return c.alphaComponent>0.99 && (c.redComponent+c.greenComponent+c.blueComponent)>0.02
            }
            check(filled,"\(Int(angle))° has no black or empty corners")
            if let folder { try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("angle-\(Int(angle)).png")) }
        }
        // A single horizontal feature must not split into repeated bands as it
        // defocuses. Scan its vertical intensity profile for secondary peaks.
        let dark=CIImage(color:CIColor(red:0,green:0,blue:0)).cropped(to:CGRect(x:0,y:0,width:1000,height:625))
        let stripe=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:350,width:1000,height:6)).composited(over:dark)
        for angle in stride(from:95.0,through:5.0,by:-5.0) {
            let result=try gpu.renderOffscreen(stripe,settings:FoldSettings(angle:angle),size:CGSize(width:1000,height:625)).0
            let bitmap=NSBitmapImageRep(cgImage:result)
            let profile=(0..<625).map { Double(bitmap.colorAt(x:500,y:$0)!.redComponent) }
            let peak=profile.indices.max(by:{profile[$0]<profile[$1]})!
            let rise=(0..<peak).map { max(0,profile[$0]-profile[$0+1]) }.reduce(0,+)
            let fall=(peak..<624).map { max(0,profile[$0+1]-profile[$0]) }.reduce(0,+)
            print("BAND \(Int(angle)) excess=\(rise+fall) peak=\(profile[peak])")
            if let folder { try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("stripe-\(Int(angle)).png")) }
            check(rise+fall <= 1.0/255.0+0.0001,"A horizontal edge stays one smooth blur at \(Int(angle))°")
        }
        // The same detail stays readable and anchored near the hinge while
        // defocusing at the moving edge. This catches whole-screen stretching.
        let hingeBar=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:40,width:1000,height:6))
        let outerBar=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:550,width:1000,height:6))
        let focusFixture=hingeBar.composited(over:outerBar.composited(over:dark))
        let focus=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(focusFixture,settings:FoldSettings(angle:30),size:CGSize(width:1000,height:625)).0)
        let focusProfile=(0..<625).map { Double(focus.colorAt(x:500,y:$0)!.redComponent) }
        let hingePeak=(550..<625).max(by:{focusProfile[$0]<focusProfile[$1]})!
        check(abs(hingePeak-582)<=4,"Detail near the hinge stays anchored during a deep fold")
        check(focusProfile[hingePeak]>0.75,"Detail near the hinge retains its contrast")
        check(focusProfile[0..<300].max()!<0.25,"The same detail defocuses strongly near the outer edge")
        // Encode coordinates as color. Linear ramps survive Gaussian blur;
        // dividing by the constant blue channel cancels the edge shading.
        // Any actual UV stretch, scale or translation still changes the ratios.
        let ramp=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1000,pixelsHigh:625,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:4000,bitsPerPixel:32)!
        for y in 0..<625 { for x in 0..<1000 {
            let i=y*4000+x*4
            ramp.bitmapData![i]=UInt8(x*255/999)
            ramp.bitmapData![i+1]=UInt8(y*255/624)
            ramp.bitmapData![i+2]=255; ramp.bitmapData![i+3]=255
        } }
        let coordinateImage=CIImage(cgImage:ramp.cgImage!)
        let original=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(coordinateImage,settings:FoldSettings(angle:100),size:CGSize(width:1000,height:625)).0)
        for angle in [75.0,50,25] {
            let result=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(coordinateImage,settings:FoldSettings(angle:angle),size:CGSize(width:1000,height:625)).0)
            var error:CGFloat=0
            for y in [156,312,468] { for x in [250,500,750] {
                let a=original.colorAt(x:x,y:y)!,b=result.colorAt(x:x,y:y)!
                error=max(error,abs(a.redComponent/a.blueComponent-b.redComponent/b.blueComponent),abs(a.greenComponent/a.blueComponent-b.greenComponent/b.blueComponent))
            } }
            check(error<0.012,"Desktop coordinates stay fixed across the display at \(Int(angle))°")
        }
        // A white field must remain filled at all sampled angles, including every edge pixel.
        let white=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:0,width:1000,height:625))
        let whiteResult=try gpu.renderOffscreen(white,settings:FoldSettings(angle:1),size:CGSize(width:320,height:200)).0
        let pixels=NSBitmapImageRep(cgImage:whiteResult)
        let perimeter=(0..<320).flatMap { [($0,0),($0,199)] }+(0..<200).flatMap { [(0,$0),(319,$0)] }
        check(perimeter.allSatisfy { x,y in (pixels.colorAt(x:x,y:y)?.redComponent ?? 0)>0.10 },"Shaded edges retain image content at nearly closed angle")
        let shaded=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(white,settings:FoldSettings(angle:50),size:CGSize(width:320,height:200)).0)
        let left=shaded.colorAt(x:0,y:30)!.redComponent
        let right=shaded.colorAt(x:319,y:30)!.redComponent
        let center=shaded.colorAt(x:160,y:30)!.redComponent
        check(left < center-0.25 && right < center-0.25,"Side shadows give the fold visible depth")
        check(abs(left-right)<0.01,"Side shading is balanced")
        let clear=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(white,settings:FoldSettings(angle:100),size:CGSize(width:320,height:200)).0)
        check(clear.colorAt(x:0,y:30)!.redComponent>0.99,"Side shadows disappear completely at rest")
        let reduced=try gpu.renderOffscreen(sample,settings:FoldSettings(angle:50,reducedMotion:true),size:size)
        check(reduced.0.width==1280,"Reduced Motion renders")
        let sorted=timings.sorted()
        print(String(format:"GPU at 1280x800: median %.3f ms, max %.3f ms",sorted[sorted.count/2],sorted.last!))
        var fullTimings=[Double]()
        let large=sample.transformed(by:CGAffineTransform(scaleX:2.56,y:2.56))
        for _ in 0..<35 {
            let r=try gpu.renderOffscreen(large,settings:FoldSettings(angle:30),size:CGSize(width:2560,height:1600))
            fullTimings.append(r.1)
        }
        fullTimings=Array(fullTimings.dropFirst(5)).sorted()
        print(String(format:"GPU at 2560x1600 including upload/mipmaps: median %.3f ms, p95 %.3f ms",fullTimings[15],fullTimings[28]))
        let sensor=LidSensor()
        if sensor.connect(),let angle=sensor.read() { print("SENSOR: \(angle)°") } else { print("SENSOR: unavailable") }
        print("\(count) checks passed")
        if CommandLine.arguments.contains("--render-video"),let folder {
            for frame in 0..<240 {
                let t=Double(frame)/60
                let angle=100-88*(0.5-0.5*cos(t/4*2*Double.pi))
                let image=try gpu.renderOffscreen(sample,settings:FoldSettings(angle:angle),size:CGSize(width:1280,height:800)).0
                try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(String(format:"motion-%04d.png",frame)))
            }
        }
    }
}

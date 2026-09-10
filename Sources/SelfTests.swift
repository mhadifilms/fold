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
        for posture in [45.0,80,90,112,140] {
            var gesture=FoldSafety()
            check(!gesture.permitsEffect(angle:posture,now:0),"Launch at \(Int(posture)) degrees stays clear")
            check(gesture.permitsEffect(angle:posture-1,now:0.1) && gesture.progress>0.02,"One degree of closing starts at \(Int(posture)) degrees")
            _=gesture.permitsEffect(angle:posture-12,now:0.2)
            let deep=gesture.progress
            check(gesture.permitsEffect(angle:posture-11,now:0.22) && gesture.progress>0 && gesture.progress<deep,"One degree of opening reverses proportionally at \(Int(posture)) degrees")
            _=gesture.permitsEffect(angle:posture-6,now:0.3)
            check(abs(gesture.progress-(1-exp(-6.0/40)))<0.000001,"Closing and opening use the identical position curve")
            check(!gesture.permitsEffect(angle:posture,now:0.4) && gesture.progress == 0,"Undoing the original movement clears without extra travel")
            check(gesture.permitsEffect(angle:posture-1,now:0.5) && gesture.progress<0.03,"Next gesture starts fresh without remembered travel")
        }
        var safety=FoldSafety()
        _=safety.permitsEffect(angle:120,now:0)
        _=safety.permitsEffect(angle:60,now:0.1)
        let held=safety.progress
        _=safety.permitsEffect(angle:60,now:1.15)
        check(safety.progress == held,"A one-second closing hold preserves the reference sequence")
        _=safety.permitsEffect(angle:60,now:1.4)
        check(safety.progress>0 && safety.progress<held,"A longer hold recovers without moving the image plane")
        check(!safety.permitsEffect(angle:60,now:1.54),"A stationary lid eventually clears without further movement")
        check(!safety.permitsEffect(angle:59.8,now:1.6),"Sub-degree jitter cannot rearm")
        check(safety.permitsEffect(angle:59,now:1.7) && safety.progress<0.03,"Closing from a new rest starts with only new travel")
        _=safety.permitsEffect(angle:40,now:1.8)
        _=safety.permitsEffect(angle:41,now:1.9)
        check(safety.progress>0,"Opening does not dismiss a deep fold")
        check(!safety.permitsEffect(angle:41,now:2.31),"An opening pause clears without needing to reopen farther")
        check(!safety.permitsEffect(angle:42,now:2.4),"Continuing to open after recovery cannot restore blur")
        _=safety.permitsEffect(angle:7,now:2.5)
        check(!safety.permitsEffect(angle:7,now:2.61),"Nearly closed clears in 100 milliseconds")
        check(!safety.permitsEffect(angle:359,now:3),"Sensor wraparound clears the effect")
        check(!safety.permitsEffect(angle:nil,now:3.1),"Lost sensor clears the effect")
        check(!safety.permitsEffect(angle:50,now:3.2),"Sensor recovery does not interpret missing travel as movement")
        check(safety.permitsEffect(angle:49,now:3.3),"Sensor recovery accepts the next closing movement")
        safety.suspend()
        check(!safety.permitsEffect(angle:30,now:3.4),"Wake discards all pre-sleep angle history")
        check(safety.permitsEffect(angle:29,now:3.5),"Wake accepts the next closing step")
        var referenceRun=FoldSafety()
        _=referenceRun.permitsEffect(angle:120,now:0)
        for i in 1...120 { _=referenceRun.permitsEffect(angle:120-Double(i)*0.8,now:Double(i)/30) }
        _=referenceRun.permitsEffect(angle:24,now:5)
        check(referenceRun.progress>0,"The low-lid hold does not discard the reference fold")
        for i in 1...120 { _=referenceRun.permitsEffect(angle:24+Double(i)*0.8,now:5+Double(i)/30) }
        check(referenceRun.progress == 0,"A full nine-second close, hold and reopen returns naturally to clear")
        var release=MotionSmoother()
        _=release.step(target:0.8,dt:1.0/60)
        let beforeRelease=release.value
        check(release.step(target:0,dt:1.0/60)<beforeRelease,"Reversal immediately removes closing momentum")
        for _ in 0..<24 { _=release.step(target:0,dt:1.0/120) }
        check(release.value<0.0001,"Full undo reaches a clear desktop without a long spring tail")
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
            check(bitmap.colorAt(x:640,y:799)!.alphaComponent>0.99,"\(Int(angle))° keeps the hinge opaque")
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
        // The same detail stays readable at the hinge in the viewer's projected
        // image while defocusing at the moving edge.
        let hingeBar=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:40,width:1000,height:6))
        let outerBar=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:550,width:1000,height:6))
        let focusFixture=hingeBar.composited(over:outerBar.composited(over:dark))
        let focus=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(focusFixture,settings:FoldSettings(angle:30),size:CGSize(width:1000,height:625)).0)
        let focusProfile=(0..<625).map { Double(focus.colorAt(x:500,y:$0)!.redComponent) }
        let hingePeak=(550..<625).max(by:{focusProfile[$0]<focusProfile[$1]})!
        let rotation=min(72.0,-40*log(0.3)) * Double.pi/180
        let physicalY=Double(625-hingePeak)/625
        let projectedY=physicalY*(0.4+0.6*cos(rotation))/(1-physicalY*sin(rotation)/2.7)
        check(abs(projectedY-43.0/625)<0.01,"Hinge detail follows the bounded projection")
        check(focusProfile[hingePeak]>0.75,"Detail near the hinge retains its contrast")
        check(focusProfile[0..<300].max()!<0.25,"The same detail defocuses strongly near the outer edge")
        // Encode coordinates as color. Linear ramps survive Gaussian blur;
        // dividing by the constant blue channel cancels the edge shading.
        // Check sample placement separately from the shape limits below.
        let ramp=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1000,pixelsHigh:625,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:4000,bitsPerPixel:32)!
        for y in 0..<625 { for x in 0..<1000 {
            let i=y*4000+x*4
            ramp.bitmapData![i]=UInt8(x*255/999)
            ramp.bitmapData![i+1]=UInt8(y*255/624)
            ramp.bitmapData![i+2]=255; ramp.bitmapData![i+3]=255
        } }
        let coordinateImage=CIImage(cgImage:ramp.cgImage!)
        for angle in [95.0,75,50,25] {
            let result=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(coordinateImage,settings:FoldSettings(angle:angle),size:CGSize(width:1000,height:625)).0)
            var error:CGFloat=0
            for y in [156,312,468] { for x in [250,500,750] {
                let b=result.colorAt(x:x,y:y)!
                let rotation=min(72.0,-40*log(angle/100)) * Double.pi/180
                let outer=1-(Double(y)+0.5)/625
                let perspective=1/(1-outer*sin(rotation)/2.7)
                let sourceX=0.5+((Double(x)+0.5)/1000-0.5)*perspective
                let sourceY=1-outer*(0.4+0.6*cos(rotation))*perspective
                error=max(error,abs(CGFloat(sourceX)-b.redComponent/b.blueComponent),abs(CGFloat(sourceY)-b.greenComponent/b.blueComponent))
            } }
            check(error<0.014,"Bounded perspective samples the expected image position at \(Int(angle))°")
        }
        // Measure a rendered square, not a restatement of the UV formula.
        // Full compensation made this near-hinge shape roughly 2.8x as tall
        // as wide at deep folds. Bound anisotropy while preserving side width.
        let square=CIImage(color:CIColor(red:1,green:1,blue:1))
            .cropped(to:CGRect(x:450,y:45,width:100,height:100)).composited(over:dark)
        for travel in [0.0,20,40,60,72,100] {
            let settings=FoldSettings(projectionProgress:1-exp(-travel/40))
            let rendered=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(square,settings:settings,size:CGSize(width:1000,height:625)).0)
            var minX=1000,maxX=0,minY=625,maxY=0
            for y in 250..<625 { for x in 400..<600 {
                if rendered.colorAt(x:x,y:y)!.redComponent>0.5 {
                    minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)
                }
            } }
            let width=Double(maxX-minX+1),height=Double(maxY-minY+1)
            print("SHAPE travel=\(travel) width=\(width) height=\(height) aspect=\(height/width)")
            check(width>=85 && width<=101 && height/width<=1.7 && height/width>=0.85,
                  "A square retains bounded proportions through \(Int(travel)) degrees of folding")
        }
        // A white field must remain filled at all sampled angles, including every edge pixel.
        let white=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:0,y:0,width:1000,height:625))
        let whiteResult=try gpu.renderOffscreen(white,settings:FoldSettings(angle:1),size:CGSize(width:320,height:200)).0
        let pixels=NSBitmapImageRep(cgImage:whiteResult)
        let perimeter=(0..<320).flatMap { [($0,0),($0,199)] }+(0..<200).flatMap { [(0,$0),(319,$0)] }
        check(perimeter.allSatisfy { x,y in (pixels.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.99 },"Revealed side wedges stay opaque at nearly closed angle")
        let shaded=NSBitmapImageRep(cgImage:try gpu.renderOffscreen(white,settings:FoldSettings(angle:50),size:CGSize(width:320,height:200)).0)
        let left=shaded.colorAt(x:0,y:30)!.redComponent
        let right=shaded.colorAt(x:319,y:30)!.redComponent
        let center=shaded.colorAt(x:160,y:30)!.redComponent
        check(left < 0.03 && right < 0.03 && center>0.85,"Projection reveals dark side wedges without dimming the whole image")
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
            var gesture = FoldSafety(), motion = MotionSmoother(), visibility = MotionSmoother()
            for frame in 0..<300 {
                let t=Double(frame)/60
                _=gesture.permitsEffect(angle:FoldPreview.angle(at:t),now:t)
                let angle=100*(1-motion.step(target:gesture.poseProgress,dt:1.0/60))
                let opacity=visibility.step(target:gesture.opacity,dt:1.0/60)
                let image=try gpu.renderOffscreen(sample,settings:FoldSettings(angle:angle,opacity:opacity),size:CGSize(width:1280,height:800)).0
                try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(String(format:"motion-%04d.png",frame)))
            }
        }
    }
}

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
        for restingAngle in [70.0,105,120,140] {
            var reference=LidReference(), gate=FoldSafety()
            reference.observe(restingAngle)
            _=gate.permitsEffect(angle:restingAngle,clearAngle:reference.clearAngle,now:0)
            reference.observe(restingAngle-1)
            let active=gate.permitsEffect(angle:restingAngle-1,clearAngle:reference.clearAngle,now:1.0/60)
            check(active && FoldSettings(angle:restingAngle-1,clearAngle:reference.clearAngle).progress>0,"First closing degree starts blur from \(Int(restingAngle))°")
            reference.observe(restingAngle)
            check(FoldSettings(angle:restingAngle,clearAngle:reference.clearAngle).progress==0,"Returning to the open position clears from \(Int(restingAngle))°")
        }
        var reference=LidReference()
        reference.observe(359); reference.observe(120); reference.observe(360)
        check(reference.clearAngle==120,"Closed-sensor wraparound cannot become the open reference")
        // Reproduce a user changing their desk posture after opening farther.
        for posture in [110.0,95,70] {
            var reference=LidReference(), gate=FoldSafety()
            reference.observe(140)
            _=gate.permitsEffect(angle:140,clearAngle:reference.clearAngle,now:0)
            reference.observe(posture)
            _=gate.permitsEffect(angle:posture,clearAngle:reference.clearAngle,now:0.1)
            let wasWaiting=gate.waitingForMotion
            _=gate.permitsEffect(angle:posture,clearAngle:reference.clearAngle,now:2.7)
            if gate.waitingForMotion && !wasWaiting { reference.rebase(posture) }
            check(reference.clearAngle==posture,"Settling at \(Int(posture))° forgets the earlier 140° position")
            reference.observe(posture-1)
            check(gate.permitsEffect(angle:posture-1,clearAngle:reference.clearAngle,now:2.8),"A new fold starts from the remembered \(Int(posture))° posture")
            reference.observe(posture-25)
            check(reference.clearAngle==posture,"The return point stays fixed while closing from \(Int(posture))°")
            reference.observe(posture)
            check(FoldSettings(angle:posture,clearAngle:reference.clearAngle).progress==0,"Returning to \(Int(posture))° clears without opening farther")
        }
        var safety = FoldSafety()
        check(!safety.permitsEffect(angle:70,clearAngle:100,now:0),"Stationary launch leaves desktop clear")
        check(safety.permitsEffect(angle:68,clearAngle:100,now:0.1),"Closing from a partly open startup works without opening first")
        check(!safety.permitsEffect(angle:68.1,clearAngle:100,now:2.7),"Held lid clears after 2.5 seconds despite jitter")
        check(!safety.permitsEffect(angle:68.3,clearAngle:100,now:3),"Small sensor jitter does not rearm")
        check(safety.permitsEffect(angle:66,clearAngle:100,now:3.1),"Further closing rearms at any angle")
        check(!safety.permitsEffect(angle:66,clearAngle:100,now:5.7),"Second held position also clears")
        check(safety.permitsEffect(angle:69,clearAngle:100,now:6),"Small reopening rearms below the old threshold")
        _ = safety.permitsEffect(angle:7,clearAngle:100,now:6.5)
        check(!safety.permitsEffect(angle:6,clearAngle:100,now:6.9),"Nearly closed clears within 350 ms")
        check(safety.permitsEffect(angle:15,clearAngle:100,now:7.1),"Moving away from nearly closed resumes immediately")
        check(!safety.permitsEffect(angle:nil,clearAngle:100,now:7.2),"Missing sensor fails clear")
        _ = safety.permitsEffect(angle:50,clearAngle:100,now:8)
        check(safety.permitsEffect(angle:48,clearAngle:100,now:8.1),"Sensor recovery resumes on movement without opening fully")
        safety.suspend()
        check(safety.permitsEffect(angle:46,clearAngle:100,now:8.3),"Wake can resume by moving further closed")
        var bounded = FoldSafety()
        _ = bounded.permitsEffect(angle:60,clearAngle:100,now:0)
        for i in 0..<80 { _ = bounded.permitsEffect(angle:50+sin(Double(i))*10,clearAngle:100,now:1+Double(i)/10) }
        check(!bounded.permitsEffect(angle:50,clearAngle:100,now:9.1),"Continuous transition still has an eight-second limit")
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
        for angle in [80.0,50,20] {
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

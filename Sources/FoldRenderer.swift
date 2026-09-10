import AppKit
import CoreImage
import MetalKit

struct FoldSettings: Equatable {
    var angle: Double = 58
    var clearAngle: Double = 100
    var perspective: Double = 0.72
    var blur: Double = 0.85
    var shadow: Double = 0.28
    var style: Int = 0
    var reducedMotion = false
    var progress: Double {
        guard angle.isFinite, clearAngle.isFinite, clearAngle > 0 else { return 0 }
        return min(1,max(0,(clearAngle-angle)/clearAngle))
    }
}

/// An analytic critically damped spring. Unlike a per-frame lerp, its behavior
/// is independent of frame rate and it retains velocity during reversals.
struct MotionSmoother {
    var value: Double = 0
    var velocity: Double = 0
    mutating func step(target: Double, dt: Double) -> Double {
        guard target.isFinite, dt.isFinite, dt > 0 else { return value }
        let t = min(dt,0.05), omega = 42.0
        let displacement = value-target
        let c = velocity+omega*displacement
        let decay = exp(-omega*t)
        value = target+(displacement+c*t)*decay
        velocity = (velocity-omega*c*t)*decay
        if abs(value-target) < 0.00002 && abs(velocity) < 0.001 { value=target; velocity=0 }
        value = min(1,max(0,value))
        return value
    }
}

struct FoldUniforms {
    var progress, perspective, blur, shade, style, width, height, reducedMotion: Float
}

final class FoldGPU {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let context: CIContext
    private let pipeline: MTLRenderPipelineState
    private var input: MTLTexture?
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "FoldGPU", code: 1,userInfo:[NSLocalizedDescriptionKey:"A Metal-capable GPU is required."])
        }
        self.device=device; self.queue=queue
        context=CIContext(mtlDevice:device,options:[.cacheIntermediates:false])
        guard let url=Bundle.main.url(forResource:"Fold",withExtension:"metal") else {
            throw NSError(domain:"FoldGPU",code:2,userInfo:[NSLocalizedDescriptionKey:"The fold shader is missing. Reinstall the app."])
        }
        let library=try device.makeLibrary(source:String(contentsOf:url),options:nil)
        let descriptor=MTLRenderPipelineDescriptor()
        descriptor.vertexFunction=library.makeFunction(name:"foldVertex")
        descriptor.fragmentFunction=library.makeFunction(name:"foldFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline=try device.makeRenderPipelineState(descriptor:descriptor)
    }
    /// Upload only when ScreenCaptureKit delivers a new frame. The same input
    /// texture can be animated at 120 Hz even while the desktop itself is idle.
    func upload(_ image: CIImage, command: MTLCommandBuffer) {
        let extent=image.extent
        let scale=min(1,2560/extent.width)
        let width=max(1,Int(extent.width*scale)),height=max(1,Int(extent.height*scale))
        if input?.width != width || input?.height != height {
            let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:true)
            desc.usage=[.shaderRead,.shaderWrite,.renderTarget];desc.storageMode = .private
            input=device.makeTexture(descriptor:desc)
        }
        guard let input else { return }
        let normalized=image.transformed(by:CGAffineTransform(translationX:-extent.minX,y:-extent.minY))
            .transformed(by:CGAffineTransform(scaleX:CGFloat(width)/extent.width,y:CGFloat(height)/extent.height))
        context.render(normalized,to:input,commandBuffer:command,bounds:CGRect(x:0,y:0,width:width,height:height),colorSpace:colorSpace)
        let blit=command.makeBlitCommandEncoder();blit?.generateMipmaps(for:input);blit?.endEncoding()
    }
    func encode(target: MTLTexture, command: MTLCommandBuffer, settings: FoldSettings, progress: Double) {
        guard let input else { return }
        var uniforms=FoldUniforms(progress:Float(progress),perspective:Float(settings.perspective),blur:Float(settings.blur),shade:Float(settings.shadow),style:Float(settings.style),width:Float(input.width),height:Float(input.height),reducedMotion:settings.reducedMotion ? 1 : 0)
        let pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=target
        pass.colorAttachments[0].loadAction = .dontCare;pass.colorAttachments[0].storeAction = .store
        guard let encoder=command.makeRenderCommandEncoder(descriptor:pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(input,index:0)
        encoder.setFragmentBytes(&uniforms,length:MemoryLayout<FoldUniforms>.stride,index:0)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        encoder.endEncoding()
    }
    func renderOffscreen(_ image: CIImage, settings: FoldSettings, size: CGSize) throws -> (CGImage, Double) {
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:Int(size.width),height:Int(size.height),mipmapped:false)
        desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
        guard let output=device.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else { throw NSError(domain:"FoldGPU",code:3) }
        upload(image,command:command);encode(target:output,command:command,settings:settings,progress:settings.progress)
        command.commit();command.waitUntilCompleted()
        if let error=command.error { throw error }
        let row=Int(size.width)*4
        var bytes=[UInt8](repeating:0,count:row*Int(size.height))
        output.getBytes(&bytes,bytesPerRow:row,from:MTLRegionMake2D(0,0,Int(size.width),Int(size.height)),mipmapLevel:0)
        let provider=CGDataProvider(data:Data(bytes) as CFData)!
        let cg=CGImage(width:Int(size.width),height:Int(size.height),bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:row,space:colorSpace,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
        return (cg,(command.gpuEndTime-command.gpuStartTime)*1000)
    }
}

final class FoldMetalView: MTKView, MTKViewDelegate {
    private var gpu: FoldGPU?
    private var pendingSource: CIImage?
    private var hasSource=false
    private var smoother=MotionSmoother()
    private var lastTime: CFTimeInterval?
    private var inflight=DispatchSemaphore(value:3)
    var source: CIImage? { didSet { pendingSource=source; isPaused=false } }
    var settings=FoldSettings() { didSet { if settings != oldValue { isPaused=false } } }
    var onPresented: (() -> Void)?
    func resetMotion() {
        smoother = MotionSmoother(); lastTime = nil; isPaused = false
    }
    var initializationError: String?
    var settled: Bool { abs(smoother.value-settings.progress)<0.0001 && abs(smoother.velocity)<0.002 }
    init() {
        super.init(frame:.zero,device:MTLCreateSystemDefaultDevice())
        do { gpu=try FoldGPU() } catch { initializationError=error.localizedDescription }
        framebufferOnly=false;colorPixelFormat = .bgra8Unorm
        isPaused=true;enableSetNeedsDisplay=false
        preferredFramesPerSecond=120
        delegate=self;autoresizingMask=[.width,.height]
    }
    required init(coder:NSCoder) { fatalError("init(coder:) not supported") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        preferredFramesPerSecond=min(120,window?.screen?.maximumFramesPerSecond ?? 60)
        if window == nil { isPaused=true;lastTime=nil }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { isPaused=false }
    func draw(in view: MTKView) {
        guard let gpu,hasSource || pendingSource != nil,drawableSize.width>0,drawableSize.height>0 else { return }
        guard inflight.wait(timeout:.now()) == .success else { return }
        guard let drawable=currentDrawable,let command=gpu.queue.makeCommandBuffer() else { inflight.signal();return }
        let now=CACurrentMediaTime();let dt=lastTime.map { now-$0 } ?? 1.0/Double(preferredFramesPerSecond);lastTime=now
        let progress=smoother.step(target:settings.progress,dt:dt)
        if let pendingSource { gpu.upload(pendingSource,command:command);self.pendingSource=nil;hasSource=true }
        gpu.encode(target:drawable.texture,command:command,settings:settings,progress:progress)
        command.present(drawable)
        command.addCompletedHandler { [weak self] _ in
            self?.inflight.signal()
            DispatchQueue.main.async { [weak self] in self?.onPresented?() }
        }
        command.commit()
        if settled { isPaused=true;lastTime=nil }
    }
}

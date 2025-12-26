import UIKit
import MetalKit
import MetalPerformanceShaders

public final class LiquidGlassGroupView: LiquidGlassBaseView {
    private let contentView = UIView()

    public override func setupBase() {
        super.setupBase()

        clipsToBounds = false
        visualPadding = 80.0
        
        metalView.isUserInteractionEnabled = false

        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        
        addSubview(contentView)
    }

    public override func addSubview(_ view: UIView) {
        if view === metalView || view === contentView {
            super.addSubview(view)
        } else {
            contentView.addSubview(view)
            if let glassView = view as? LiquidGlassView {
                glassView.isGrouped = true
                glassView.delegate = self
            }
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        var maxInteractionDeviation: CGFloat = 0.0
        
        if #available(iOS 13.0, *) {
            for subview in contentView.subviews {
                for interaction in subview.interactions {
                    if let glassInteraction = interaction as? LiquidGlassInteraction {
                        if glassInteraction.resistance > 0.001 {
                            let deviation = 1.0 / glassInteraction.resistance
                            maxInteractionDeviation = max(maxInteractionDeviation, deviation)
                        } else {
                            maxInteractionDeviation = max(maxInteractionDeviation, 150.0)
                        }
                    }
                }
            }
        }

        let blurBuffer = CGFloat(settings.effectiveBlur * 3.0)
        let thicknessBuffer = CGFloat(settings.effectiveThickness)
        let safeMargin: CGFloat = 20.0
        
        let calculatedPadding = maxInteractionDeviation + blurBuffer + thicknessBuffer + safeMargin

        let effectivePadding = max(visualPadding, calculatedPadding)

        let paddedFrame = bounds.insetBy(dx: -effectivePadding, dy: -effectivePadding)
        if metalView.frame != paddedFrame {
            metalView.frame = paddedFrame
        }
        
        contentView.frame = bounds

        metalView.draw()
    }

    public override func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        guard let device = view.device else { return }
        let scale = view.contentScaleFactor
       

        let (bgTextureOpt, _, captureOffset) = captureBackground(device: device)
        guard let bgTexture = bgTextureOpt else { return }

        guard let pipelineState = pipelineState,
              let queue = commandQueue,
              let buffer = queue.makeCommandBuffer() else {
            return
        }

        var textureToRender = bgTexture
        
        let blurSigma = settings.effectiveBlur
        if blurSigma > 0.1 {
            let downsampledWidth = Int(Float(bgTexture.width) / Float(scale))
            let downsampledHeight = Int(Float(bgTexture.height) / Float(scale))
            
            let blurDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: bgTexture.pixelFormat,
                width: downsampledWidth,
                height: downsampledHeight,
                mipmapped: false
            )
            blurDesc.usage = [.shaderRead, .shaderWrite]

            if blurredTexture == nil ||
                blurredTexture?.width != downsampledWidth ||
                blurredTexture?.height != downsampledHeight ||
                blurredTexture?.pixelFormat != bgTexture.pixelFormat {
                blurredTexture = device.makeTexture(descriptor: blurDesc)
            }
            
            if let blurred = blurredTexture {
                let scaler = MPSImageBilinearScale(device: device)
                scaler.encode(commandBuffer: buffer, sourceTexture: bgTexture, destinationTexture: blurred)

                let blur = MPSImageGaussianBlur(device: device, sigma: blurSigma)
                blur.edgeMode = .clamp
                blur.encode(commandBuffer: buffer, sourceTexture: blurred, destinationTexture: blurred)
                
                textureToRender = blurred
            }
        }
        
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        var shapesList = LiquidGlassShapeUniforms()
        var count: Int = 0
        
        for subview in contentView.subviews {
            if let glass = subview as? LiquidGlassView, !glass.isHidden, glass.alpha > 0.01 {
                if count >= MAX_SHAPES { break }

                let centerInMetal = glass.convert(CGPoint(x: glass.bounds.midX, y: glass.bounds.midY), to: metalView)

                let t = glass.transform
                let scaleX = sqrt(t.a * t.a + t.c * t.c)
                let scaleY = sqrt(t.b * t.b + t.d * t.d)

                let rotation = atan2(t.b, t.a)
                
                var shapeData = LiquidGlassShapeData()
                shapeData.type = Int32(glass.shapeType)

                shapeData.center = SIMD2<Float>(Float(centerInMetal.x * scale), Float(centerInMetal.y * scale))
                shapeData.size = SIMD2<Float>(Float(glass.bounds.width * scale), Float(glass.bounds.height * scale))
                
                shapeData.scale = SIMD2<Float>(Float(scaleX), Float(scaleY))
                shapeData.rotation = Float(rotation)
                shapeData.cornerRadius = Float(glass.glassCornerRadius * scale)

                shapeData.visibility = Float(glass.alpha) * glass.settings.visibility

                withUnsafeMutablePointer(to: &shapesList.shapes) { ptr in
                    let rawPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: LiquidGlassShapeData.self)
                    rawPtr[count] = shapeData
                }
                
                count += 1
            }
        }
        shapesList.count = Int32(count)

        encoder.setRenderPipelineState(pipelineState)
        
        var uniforms = LiquidGlassUniforms()
        uniforms.size = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        uniforms.thickness = settings.effectiveThickness * Float(scale)
        uniforms.refractiveIndex = settings.refractiveIndex
        uniforms.blur = settings.effectiveBlur * Float(scale)
        uniforms.chromaticAberration = settings.effectiveChromaticAberration
        uniforms.lightIntensity = settings.effectiveLightIntensity
        uniforms.ambientStrength = settings.effectiveAmbientStrength
        uniforms.saturation = settings.effectiveSaturation
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        settings.effectiveGlassColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        uniforms.glassColor = SIMD4<Float>(
            Float(r),
            Float(g),
            Float(b),
            Float(a)
        )
        uniforms.blend = settings.blend * Float(scale)
        uniforms.visibility = settings.visibility

        let time = Float(CACurrentMediaTime().truncatingRemainder(dividingBy: 100))
        uniforms.time = time
        let angle = settings.lightAngle
        uniforms.lightDirection = SIMD2<Float>(cos(angle), sin(angle))

        uniforms.textureOffset = SIMD2<Float>(Float(captureOffset.x * scale), Float(captureOffset.y * scale))
        
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidGlassUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&shapesList, length: MemoryLayout<LiquidGlassShapeUniforms>.stride, index: 1)


        encoder.setFragmentTexture(bgTexture, index: 0)
        encoder.setFragmentTexture(textureToRender, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        
        buffer.present(drawable)
        buffer.commit()
    }
}

extension LiquidGlassGroupView: LiquidGlassGeometryDelegate {
    public func geometryDidUpdate(_ view: LiquidGlassView) {
        metalView.draw()
    }
}

import UIKit
import MetalKit
import MetalPerformanceShaders

public protocol LiquidGlassGeometryDelegate: AnyObject {
    func geometryDidUpdate(_ view: LiquidGlassView)
}

public class LiquidGlassView: LiquidGlassBaseView {

    public var glassCornerRadius: CGFloat = 12.0 {
        didSet {
            delegate?.geometryDidUpdate(self)
            setNeedsDisplay()
        }
    }

    public var shapeType: Int = Int(SHAPE_TYPE_ROUNDED_RECT) {
        didSet {
            delegate?.geometryDidUpdate(self)
            setNeedsDisplay()
        }
    }

    public weak var delegate: LiquidGlassGeometryDelegate?

    public var isGrouped: Bool = false {
        didSet {
            metalView.isHidden = isGrouped
            metalView.isPaused = isGrouped
        }
    }

    public var lightPosition: CGPoint? {
        didSet {
            notifyGeometryUpdate()
        }
    }

    public override func setupBase() {
        super.setupBase()
    }

    public func notifyGeometryUpdate() {
        delegate?.geometryDidUpdate(self)
        if !isGrouped {
            metalView.draw()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        if metalView.frame != bounds {
            metalView.frame = bounds
        }

        delegate?.geometryDidUpdate(self)
        if !isGrouped {
            metalView.draw()
        }
    }

    public override func draw(in view: MTKView) {
        guard !isGrouped,
              let drawable = view.currentDrawable,
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

            if blurredTexture == nil ||
                blurredTexture?.width != downsampledWidth ||
                blurredTexture?.height != downsampledHeight ||
                blurredTexture?.pixelFormat != bgTexture.pixelFormat {

                let blurDesc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: bgTexture.pixelFormat,
                    width: downsampledWidth,
                    height: downsampledHeight,
                    mipmapped: false
                )
                blurDesc.usage = [.shaderRead, .shaderWrite]
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

        encoder.setRenderPipelineState(pipelineState)


        var uniforms = LiquidGlassUniforms()

        uniforms.size = SIMD2<Float>(Float(bounds.width * scale), Float(bounds.height * scale))

        uniforms.textureOffset = SIMD2<Float>(Float(captureOffset.x * scale), Float(captureOffset.y * scale))

        uniforms.thickness = settings.effectiveThickness * Float(scale)
        uniforms.refractiveIndex = settings.refractiveIndex
        uniforms.blur = settings.effectiveBlur * Float(scale)
        uniforms.chromaticAberration = settings.effectiveChromaticAberration
        uniforms.lightIntensity = settings.effectiveLightIntensity
        uniforms.ambientStrength = settings.effectiveAmbientStrength
        uniforms.saturation = settings.effectiveSaturation
        uniforms.blend = settings.blend * Float(scale)
        uniforms.visibility = settings.visibility

        let time = Float(CACurrentMediaTime().truncatingRemainder(dividingBy: 100))
        uniforms.time = time


        if let lightPos = lightPosition {
            let centerX = bounds.width / 2.0
            let centerY = bounds.height / 2.0
            let dx = Float(lightPos.x - centerX)
            let dy = Float(lightPos.y - centerY)

            let length = sqrt(dx*dx + dy*dy)
            if length > 0.001 {
                uniforms.lightDirection = SIMD2<Float>(dx / length, dy / length)
            } else {
                uniforms.lightDirection = SIMD2<Float>(0, 0)
            }
        } else {
            let angle = settings.lightAngle
            uniforms.lightDirection = SIMD2<Float>(cos(angle), sin(angle))
        }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        settings.effectiveGlassColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        uniforms.glassColor = SIMD4<Float>(
            Float(r),
            Float(g),
            Float(b),
            Float(a)
        )

        var shape = LiquidGlassShapeData()
        shape.type = Int32(shapeType)

        let padding = Float(visualPadding * scale)
        let w = Float(bounds.width * scale)
        let h = Float(bounds.height * scale)

        shape.size = SIMD2<Float>(w - 2 * padding, h - 2 * padding)
        shape.center = SIMD2<Float>(w / 2.0, h / 2.0)
        shape.cornerRadius = Float(glassCornerRadius * scale)
        shape.scale = SIMD2<Float>(1, 1)
        shape.visibility = 1.0

        var shapes = LiquidGlassShapeUniforms()
        shapes.count = 1
        shapes.shapes.0 = shape

        encoder.setVertexBytes(&shapes, length: MemoryLayout<LiquidGlassShapeUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidGlassUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&shapes, length: MemoryLayout<LiquidGlassShapeUniforms>.stride, index: 1)


        encoder.setFragmentTexture(bgTexture, index: 0)
        encoder.setFragmentTexture(textureToRender, index: 1)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        buffer.present(drawable)
        buffer.commit()
    }
}

import UIKit
import MetalKit
import MetalPerformanceShaders
import IOSurface
import CoreVideo

public struct LiquidGlassSettings {
    public var visibility: Float = 1.0

    public var glassColor: UIColor = .init(white: 0.95, alpha: 0.3)
    public var effectiveGlassColor: UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        glassColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r, green: g, blue: b, alpha: a * CGFloat(visibility))
    }

    public var thickness: Float = 30.0
    public var effectiveThickness: Float {
        thickness * visibility
    }

    public var blur: Float = 5.0
    public var effectiveBlur: Float {
        blur * visibility
    }

    public var chromaticAberration: Float = 0.015
    public var effectiveChromaticAberration: Float {
        chromaticAberration * visibility
    }

    public var lightAngle: Float = .pi / 4.0

    public var lightIntensity: Float = 0.9
    public var effectiveLightIntensity: Float {
        lightIntensity * visibility
    }

    public var ambientStrength: Float = 0.4
    public var effectiveAmbientStrength: Float {
        ambientStrength * visibility
    }

    public var refractiveIndex: Float = 1.15

    public var saturation: Float = 1.1
    public var effectiveSaturation: Float {
        1.0 + (saturation - 1.0) * visibility
    }

    public var blend: Float = 25.0

    public init(visibility: Float, glassColor: UIColor, thickness: Float, blur: Float, chromaticAberration: Float, lightAngle: Float, lightIntensity: Float, ambientStrength: Float, refractiveIndex: Float, saturation: Float, blend: Float) {
        self.visibility = visibility
        self.glassColor = glassColor
        self.thickness = thickness
        self.blur = blur
        self.chromaticAberration = chromaticAberration
        self.lightAngle = lightAngle
        self.lightIntensity = lightIntensity
        self.ambientStrength = ambientStrength
        self.refractiveIndex = refractiveIndex
        self.saturation = saturation
        self.blend = blend
    }

    public init() {
    }
}

public class LiquidGlassBaseView: UIView, MTKViewDelegate {

    public var settings = LiquidGlassSettings() {
        didSet {
            metalView.draw()
        }
    }

    public var onDebugImageUpdate: ((UIImage) -> Void)?

    public let metalView = MTKView()
    var commandQueue: MTLCommandQueue?
    var pipelineState: MTLRenderPipelineState?
    var blurredTexture: MTLTexture?

    public var visualPadding: CGFloat = 0.0 {
        didSet {
            setNeedsLayout()
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupBase()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBase()
    }

    func setupBase() {
        backgroundColor = .clear

        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.backgroundColor = .clear
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.isOpaque = false
        metalView.layer.disableUpdateMask = 18
        metalView.layer.allowsGroupOpacity = false

        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = true
        metalView.delegate = self

        metalView.frame = bounds
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addSubview(metalView)

        setupPipeline()
    }

    func setupPipeline() {
        guard let device = metalView.device else { return }
        commandQueue = device.makeCommandQueue()

        guard let library = metalLibrary(device: device) else { return }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "LiquidGlassPipeline"
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "liquid_vertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "liquid_fragment")

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat

        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        device.makeRenderPipelineState(descriptor: pipelineDescriptor) { [weak self] state, error in
            if let error = error {
                print("LiquidGlassBase: Failed to create pipeline state - \(error)")
                return
            }

            self?.pipelineState = state

            DispatchQueue.main.async {
                self?.metalView.draw()
            }
        }
    }

    func captureBackground(device: MTLDevice) -> (MTLTexture?, MTLPixelFormat, CGPoint) {
        guard let window = self.window else { return (nil, .bgra8Unorm, .zero) }

        let targetLayer = metalView.layer.presentation() ?? metalView.layer
        let realRect = targetLayer.convert(targetLayer.bounds, to: window.layer)
        let captureRect = realRect.integral

        let offset = CGPoint(x: realRect.minX - captureRect.minX, y: realRect.minY - captureRect.minY)

        let surfaceRef = window.createIOSurface(withFrame: captureRect)


        guard let ref = surfaceRef else { return (nil, .bgra8Unorm, .zero) }
        let ioSurface = ref.takeRetainedValue()

        if let callback = onDebugImageUpdate {
            //            let cgImage = UICreateCGImageFromIOSurface(ioSurface).takeRetainedValue()
            //            callback(UIImage(cgImage: cgImage))
        }

        let width = IOSurfaceGetWidth(ioSurface)
        let height = IOSurfaceGetHeight(ioSurface)
        if width == 0 || height == 0 { return (nil, .bgra8Unorm, .zero) }

        let pixelFormat: MTLPixelFormat
        let surfaceFormat = IOSurfaceGetPixelFormat(ioSurface)

        switch surfaceFormat {
        case kCVPixelFormatType_32BGRA:
            pixelFormat = .bgra8Unorm
        case kCVPixelFormatType_30RGBLE_8A_BiPlanar:
            pixelFormat = .rgba10_xr ?? .bgra8Unorm
        default:
            pixelFormat = .bgra8Unorm
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        return (device.makeTexture(descriptor: descriptor, iosurface: ioSurface, plane: 0), pixelFormat, offset)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    public func draw(in view: MTKView) {
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            DispatchQueue.main.async {
                self.metalView.draw()
            }
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            RunLoop.main.add(Timer(timeInterval: 0.2, repeats: false, block: { _ in
                self.metalView.setNeedsDisplay()
            }), forMode: .common)
        }
    }
}

private final class BundleMarker: NSObject {
    private override init() {
        super.init()
    }
}

private var metalLibraryValue: MTLLibrary?
func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }

    let mainBundle = Bundle(for: BundleMarker.self)
    guard let path = mainBundle.path(forResource: "LiquidGlassMetalSourcesBundle", ofType: "bundle") else {
        return nil
    }
    guard let bundle = Bundle(path: path) else {
        return nil
    }
    guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        return nil
    }

    metalLibraryValue = library
    return library
}

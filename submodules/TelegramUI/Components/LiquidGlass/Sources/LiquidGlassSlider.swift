import UIKit

@available(iOS, obsoleted: 26.0)
public final class LiquidGlassSlider: UISlider {
    private var initialTouchLocation: CGPoint = .zero

    var onDebugImageUpdate: ((UIImage) -> Void)? {
        get { glassThumbView.onDebugImageUpdate }
        set { glassThumbView.onDebugImageUpdate = newValue }
    }
    
    private let customThumbContainer = UIView()
    private let solidThumbView = UIView()
    private let glassThumbView = LiquidGlassView()

    private var lastLocation: CGPoint = .zero
    private var lastTimestamp: TimeInterval = 0
    private var currentVelocity: CGPoint = .zero

    private var presentationScale: CGFloat = 1.0
    private var jellyScale: CGSize = CGSize(width: 1, height: 1)

    private var jellySpringLink: CADisplayLink?
    private var jellySpringVelocity: CGSize = .zero
    
    private var animator: UIViewPropertyAnimator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCommon()
    }
    
    deinit {
        jellySpringLink?.invalidate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil {
            RunLoop.main.add(Timer(timeInterval: 0.0, repeats: false, block: { [self] _ in
                tg_liquidGlass_thumbImageView?.image = nil

                tg_liquidGlass_minTrackClipView?.layer.allowsEdgeAntialiasing = true
                tg_liquidGlass_minTrackClipView?.layer.cornerCurve = .continuous
                tg_liquidGlass_minTrackClipView?.layer.cornerRadius = 3.0
                tg_liquidGlass_minTrackClipView?.clipsToBounds = true

                tg_liquidGlass_maxTrackClipView?.layer.allowsEdgeAntialiasing = true
                tg_liquidGlass_maxTrackClipView?.layer.cornerCurve = .continuous
                tg_liquidGlass_maxTrackClipView?.layer.cornerRadius = 3.0
                tg_liquidGlass_maxTrackClipView?.clipsToBounds = true

                maximumTrackTintColor = UIColor {
                    $0.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.1) : UIColor(white: 0.0, alpha: 0.1)
                }
            }), forMode: .common)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateTrackClipViews()

        let tRect = trackRect(forBounds: bounds)
        let thRect = thumbRect(forBounds: bounds, trackRect: tRect, value: value)
        let center = CGPoint(x: thRect.midX, y: thRect.midY)
        
        let baseSize = Constants.defaultThumbSize
        let finalWidth = baseSize.width * presentationScale * jellyScale.width
        let finalHeight = baseSize.height * presentationScale * jellyScale.height
        
        customThumbContainer.bounds = CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight)
        customThumbContainer.center = center

        solidThumbView.frame = customThumbContainer.bounds

        let padding: CGFloat = 20.0
        glassThumbView.frame = customThumbContainer.bounds.insetBy(dx: -padding, dy: -padding)
        glassThumbView.visualPadding = padding

        glassThumbView.glassCornerRadius = 12.0 * presentationScale
        
        glassThumbView.notifyGeometryUpdate()
    }

    public override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.trackRect(forBounds: bounds)
        let minimumValueImageRect = minimumValueImageRect(forBounds: bounds)
        let maximumValueImageRect = maximumValueImageRect(forBounds: bounds)
        rect.origin.x = minimumValueImageRect.maxX + Constants.defaultTrackClipOffset
        rect.origin.y = bounds.height / 2.0 - Constants.defaultTrackClipHeight / 2.0
        rect.size.width = bounds.width - minimumValueImageRect.width - maximumValueImageRect.width - 2.0 * Constants.defaultTrackClipOffset
        rect.size.height = Constants.defaultTrackClipHeight
        return rect
    }

    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let result = super.beginTracking(touch, with: event)
        if result {
            animateToGlassState(true)
            lastLocation = touch.location(in: self)
            lastTimestamp = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
            currentVelocity = .zero
        }
        return result
    }

    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let result = super.continueTracking(touch, with: event)
        updateRubberBandingTrackClipViews(on: touch, with: event)

        let currentLocation = touch.location(in: self)
        let currentTimestamp = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
        let dt = CGFloat(currentTimestamp - lastTimestamp)
        
        if dt > 0.001 {
            let dx = currentLocation.x - lastLocation.x
            let dy = currentLocation.y - lastLocation.y
            let newVelocity = CGPoint(x: dx / dt, y: dy / dt)

            currentVelocity = CGPoint(
                x: currentVelocity.x * 0.6 + newVelocity.x * 0.4,
                y: currentVelocity.y * 0.6 + newVelocity.y * 0.4
            )
        }
        
        lastLocation = currentLocation
        lastTimestamp = currentTimestamp
        
        updateJellyScale(velocity: currentVelocity)
        glassThumbView.notifyGeometryUpdate()
        
        return result
    }

    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        resetRubberBandingTrackClipViews()
        animateToGlassState(false)
        resetJellyScale()
    }

    public override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        resetRubberBandingTrackClipViews()
        animateToGlassState(false)
        resetJellyScale()
    }
}

extension LiquidGlassSlider {
    private func setupCommon() {

        addSubview(customThumbContainer)
        customThumbContainer.isUserInteractionEnabled = false
        customThumbContainer.bounds = CGRect(origin: .zero, size: Constants.defaultThumbSize)

        customThumbContainer.addSubview(solidThumbView)
        solidThumbView.frame = customThumbContainer.bounds
        solidThumbView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        solidThumbView.backgroundColor = .white
        solidThumbView.layer.cornerCurve = .continuous
        solidThumbView.layer.cornerRadius = 12.0

        customThumbContainer.addSubview(glassThumbView)

        var settings = LiquidGlassSettings()
        settings.refractiveIndex = 1.15
        settings.thickness = 20.0
        settings.blur = 0.0
        settings.saturation = 1.5
        settings.lightIntensity = 2.0
        settings.ambientStrength = 0.5
        settings.chromaticAberration = 0.5
        settings.lightAngle = Float.pi / 4
        settings.glassColor = UIColor.white.withAlphaComponent(0.1)
        settings.visibility = 0.0

        glassThumbView.settings = settings
        glassThumbView.glassCornerRadius = 12.0
        glassThumbView.shapeType = Int(SHAPE_TYPE_ROUNDED_RECT)
        glassThumbView.visualPadding = 20.0

        glassThumbView.layer.shadowColor = UIColor.white.cgColor
        glassThumbView.layer.shadowOpacity = 0.1
        glassThumbView.layer.shadowRadius = 12.0
        glassThumbView.layer.shadowOffset = .zero
        
        glassThumbView.alpha = 0.0
    }

    private func updateThumbPosition() {
        // Handled in layoutSubviews now
    }

    private func animateToGlassState(_ isGlass: Bool) {
        animator?.stopAnimation(true)

        animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1.0) {
            if isGlass {
                self.solidThumbView.alpha = 0.0
                self.glassThumbView.alpha = 1.0
            } else {
                self.solidThumbView.alpha = 1.0
                self.glassThumbView.alpha = 0.0
            }
        }

        let startVis = glassThumbView.settings.visibility
        let endVis: Float = isGlass ? 1.0 : 0.0

        let startScale = presentationScale
        let endScale: CGFloat = isGlass ? 1.7 : 1.0

        let startTime = CACurrentMediaTime()
        let duration: TimeInterval = 0.3

        let timer = Timer(timeInterval: 1/60, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let now = CACurrentMediaTime()
            let progress = min(1.0, Float(now - startTime) / Float(duration))
            let t = progress

            let currentVis = startVis + (endVis - startVis) * t
            self.glassThumbView.settings.visibility = currentVis

            let currentScale = startScale + (endScale - startScale) * CGFloat(t)
            self.presentationScale = currentScale
            self.setNeedsLayout()
            self.layoutIfNeeded()

            if progress >= 1.0 {
                timer.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)

        animator?.startAnimation()
    }

    private func updateJellyScale(velocity: CGPoint) {
        jellySpringLink?.invalidate()
        jellySpringLink = nil
        
        let scale = calculateJellyScale(velocity: velocity)
        self.jellyScale = scale
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    private func resetJellyScale() {
        jellySpringLink?.invalidate()
        jellySpringVelocity = .zero
        
        jellySpringLink = CADisplayLink(target: self, selector: #selector(updateJellySpring))
        jellySpringLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateJellySpring(link: CADisplayLink) {
        let dt = CGFloat(link.targetTimestamp - link.timestamp)
        if dt > 1.0 { return }

        let stiffness: CGFloat = 120.0
        let damping: CGFloat = 15.0
        let mass: CGFloat = 1.0
        
        let currentWidth = jellyScale.width
        let currentHeight = jellyScale.height

        let displacementX = currentWidth - 1.0
        let forceX = -stiffness * displacementX - damping * jellySpringVelocity.width
        let accelX = forceX / mass
        
        let displacementY = currentHeight - 1.0
        let forceY = -stiffness * displacementY - damping * jellySpringVelocity.height
        let accelY = forceY / mass

        jellySpringVelocity.width += accelX * dt
        jellySpringVelocity.height += accelY * dt

        jellyScale.width += jellySpringVelocity.width * dt
        jellyScale.height += jellySpringVelocity.height * dt
        
        self.setNeedsLayout()
        self.layoutIfNeeded()

        if abs(displacementX) < 0.001 && abs(displacementY) < 0.001 &&
           abs(jellySpringVelocity.width) < 0.01 && abs(jellySpringVelocity.height) < 0.01 {
            jellyScale = CGSize(width: 1, height: 1)
            link.invalidate()
            jellySpringLink = nil
        }
    }

    private func calculateJellyScale(velocity: CGPoint) -> CGSize {
        let maxDistortion: CGFloat = 1.5
        let velocityScale: CGFloat = 1000.0

        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)

        if speed < 0.001 { return CGSize(width: 1, height: 1) }

        let direction = CGPoint(x: velocity.x / speed, y: velocity.y / speed)

        let distortionFactor = min(max(speed / velocityScale, 0.0), 1.0) * maxDistortion

        if distortionFactor == 0 { return CGSize(width: 1, height: 1) }

        let absDirX = abs(direction.x)
        let absDirY = abs(direction.y)

        let squashX = 1.0 - (absDirX * distortionFactor * 0.5)
        let squashY = 1.0 - (absDirY * distortionFactor * 0.5)
        let stretchX = 1.0 + (absDirY * distortionFactor * 0.3)
        let stretchY = 1.0 + (absDirX * distortionFactor * 0.3)

        let scaleX = squashX * stretchX
        let scaleY = squashY * stretchY

        return CGSize(width: scaleX, height: scaleY)
    }
}

extension LiquidGlassSlider {
    private func updateTrackClipViews() {
        guard let minTrackClipView = tg_liquidGlass_minTrackClipView,
              let maxTrackClipView = tg_liquidGlass_maxTrackClipView,
              let minTrackImageView = tg_liquidGlass_minTrackImageView,
              let maxTrackImageView = tg_liquidGlass_maxTrackImageView
        else { return }

        let trackRect = trackRect(forBounds: bounds)
        let value = Double(self.value)


        let minTrackClipCompensateThresholdValue = Constants.defaultMinTrackClipWidth / (trackRect.width - Constants.defaultMinTrackClipWidth)
        let maxTrackClipCompensateThresholdValue = 1.0 - minTrackClipCompensateThresholdValue

        if  value <= minTrackClipCompensateThresholdValue {
            let width = simd_mix(
                0.0,
                2.0 * Constants.defaultMinTrackClipWidth,
                value / minTrackClipCompensateThresholdValue
            )

            minTrackClipView.frameUsingCenterAndBounds = CGRect(origin: trackRect.origin, size: CGSize(width: width, height: trackRect.height))

        } else if maxTrackClipCompensateThresholdValue <= value {
            let width = simd_mix(
                trackRect.width - 2.0 * Constants.defaultMinTrackClipWidth,
                trackRect.width,
                (value - maxTrackClipCompensateThresholdValue) / (1.0 - maxTrackClipCompensateThresholdValue)
            )

            minTrackClipView.frameUsingCenterAndBounds = CGRect(origin: trackRect.origin, size: CGSize(width: width, height: trackRect.height))
        }

        maxTrackClipView.frameUsingCenterAndBounds = trackRect
        minTrackImageView.frameUsingCenterAndBounds = CGRect(origin: .zero, size: trackRect.size)
        maxTrackImageView.frameUsingCenterAndBounds = CGRect(origin: .zero, size: trackRect.size)
    }

    private func updateRubberBandingTrackClipViews(on touch: UITouch, with event: UIEvent?) {
        if value <= 0.0 || value >= 1.0 {
            let currentTouchLocation = touch.location(in: self)
            var translationX: CGFloat = 0.0
            var scaleY: CGFloat = 1.0

            if initialTouchLocation == .zero {
                initialTouchLocation = currentTouchLocation
                return
            }

            var offset1 = rubberBandingOffset(currentTouchLocation.x - initialTouchLocation.x, limit: 8.0)
            var offset2 = rubberBandingOffset(currentTouchLocation.x - initialTouchLocation.x, limit: 3.5)
            if value == 0 {
                offset1 = min(offset1, 0.0)
                offset2 = min(offset2, 0.0)
            } else {
                offset1 = max(0.0, offset1)
                offset2 = max(0.0, offset2)
            }
            translationX = offset1
            scaleY = 1.0 - abs(offset2) / 6.0

            tg_liquidGlass_minTrackClipView!.transform = CGAffineTransform(scaleX: 1.0, y: scaleY)
            tg_liquidGlass_maxTrackClipView!.transform = CGAffineTransform(scaleX: 1.0, y: scaleY)
            transform = CGAffineTransform(translationX: translationX, y: 0.0)
        } else {
            resetRubberBandingTrackClipViews()
        }
    }

    private func resetRubberBandingTrackClipViews() {
        initialTouchLocation = .zero
        tg_liquidGlass_minTrackClipView?.transform = .identity
        tg_liquidGlass_maxTrackClipView?.transform = .identity
        transform = .identity
    }
}

extension LiquidGlassSlider {
    private enum Constants {
        static let defaultTrackClipOffset = 11.0
        static let defaultMinTrackClipWidth = 13.0
        static let defaultTrackClipHeight = 6.0
        static let defaultThumbSize = CGSize(width: 37.0, height: 24.0)
    }
}

func rubberBandingOffset(_ offset: Double, limit: Double, stiffness: Double = 0.55) -> Double {
    let absOffset = abs(offset)
    let result = (absOffset * stiffness * limit) / (absOffset * stiffness + limit)
    return sign(offset) * result
}

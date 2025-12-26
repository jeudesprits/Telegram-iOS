import UIKit

@available(iOS, obsoleted: 26.0)
public final class LiquidGlassSwitch: UISwitch, UIGestureRecognizerDelegate {

    var onDebugImageUpdate: ((UIImage) -> Void)? {
        get { glassThumbView.onDebugImageUpdate }
        set { glassThumbView.onDebugImageUpdate = newValue }
    }
    
    private let customThumbContainer = UIView()
    private let solidThumbView = UIView()
    private let glassThumbView = LiquidGlassView()

    private var isInteracting: Bool = false
    private var touchLocation: CGPoint = .zero
    private var initialTouchOffset: CGFloat = 0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0
    private var lastThumbPosition: CGPoint = .zero

    private var jellyScale: CGSize = CGSize(width: 1, height: 1)
    private var jellyVelocity: CGSize = .zero
    private var currentVelocity: CGPoint = .zero
    
    private var glassAnimator: UIViewPropertyAnimator?
    
    private weak var debugWindowView: UIImageView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCommon()
        
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleTouch(_:)))
        gesture.minimumPressDuration = 0
        gesture.delegate = self
        addGestureRecognizer(gesture)

        addTarget(self, action: #selector(handleValueChanged), for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    deinit {
        stopDisplayLink()
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil {
            RunLoop.main.add(Timer(timeInterval: 0.0, repeats: false, block: { [self] _ in
                tg_liquidGlass_switchWellView?.layer.allowsEdgeAntialiasing = true
                tg_liquidGlass_switchWellView?.layer.cornerCurve = .continuous
                tg_liquidGlass_switchWellView?.layer.cornerRadius = 14.0

                tg_liquidGlass_switchWellContainerView?.layer.allowsEdgeAntialiasing = true
                tg_liquidGlass_switchWellContainerView?.layer.cornerCurve = .continuous
                tg_liquidGlass_switchWellContainerView?.layer.cornerRadius = 14.0

                tg_liquidGlass_knobImageView?.layer.allowsEdgeAntialiasing = true
                tg_liquidGlass_knobImageView?.layer.cornerCurve = .continuous
                tg_liquidGlass_knobImageView?.layer.cornerRadius = 12.0
                tg_liquidGlass_knobImageView?.backgroundColor = .white
                tg_liquidGlass_knobImageView?.alpha = 0.0

                if let knob = tg_liquidGlass_knobImageView {
                    customThumbContainer.center = knob.center
                }
            }), forMode: .common)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if displayLink == nil {
             if let knob = tg_liquidGlass_knobImageView {
                 customThumbContainer.center = knob.center
                 bringSubviewToFront(customThumbContainer)
             }

             updateThumbAppearance()
        }
    }

    @objc private func handleTouch(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            isInteracting = true
            touchLocation = gesture.location(in: self)
            initialTouchOffset = customThumbContainer.center.x - touchLocation.x
            animateToGlassState(true)
            startDisplayLink()
            
        case .changed:
            touchLocation = gesture.location(in: self)
            
        case .ended, .cancelled:
            isInteracting = false
            animateToGlassState(false)

            
        default:
            break
        }
    }
    
    @objc private func handleValueChanged() {
        startDisplayLink()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        lastTimestamp = ProcessInfo.processInfo.systemUptime
        let link = CADisplayLink(target: self, selector: #selector(updateLoop))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateLoop(link: CADisplayLink) {
        let dt = CGFloat(link.targetTimestamp - link.timestamp)
        
        guard let knob = tg_liquidGlass_knobImageView else { return }
        
        var targetCenter: CGPoint
        
        if isInteracting {

            let trackPadding = 2.0

            let halfKnobW = Constants.effectiveKnobSize.width / 2.0
            
            let minX = trackPadding + halfKnobW
            let maxX = bounds.width - trackPadding - halfKnobW

            let rawX = touchLocation.x + initialTouchOffset
            var finalX = rawX

            if rawX < minX {
                finalX = minX + rubberBandingOffset(rawX - minX, limit: 10.0)
            } else if rawX > maxX {
                finalX = maxX + rubberBandingOffset(rawX - maxX, limit: 10.0)
            }
            
            targetCenter = CGPoint(x: finalX, y: bounds.height / 2.0)
            
        } else {
            let knobLayer = knob.layer.presentation() ?? knob.layer
            targetCenter = knobLayer.position
        }

        customThumbContainer.center = targetCenter

        if dt > 0.001 {
            let dx = targetCenter.x - lastThumbPosition.x
            let dy = targetCenter.y - lastThumbPosition.y
            let instantVelocity = CGPoint(x: dx / dt, y: dy / dt)

            currentVelocity = CGPoint(
                x: currentVelocity.x * 0.7 + instantVelocity.x * 0.3,
                y: currentVelocity.y * 0.7 + instantVelocity.y * 0.3
            )
        }
        lastThumbPosition = targetCenter

        updateJelly(dt: dt)

        if !isInteracting && glassThumbView.alpha < 0.01 && abs(currentVelocity.x) < 1.0 {
             stopDisplayLink()
             resetJellyScale()
        }
    }

    private func updateJelly(dt: CGFloat) {
        if isInteracting || glassThumbView.alpha > 0.1 {
            jellyScale = calculateJellyScale(velocity: currentVelocity)
        } else {
             let stiffness: CGFloat = 120.0
             let damping: CGFloat = 15.0
             let mass: CGFloat = 1.0
             
             let currentWidth = jellyScale.width
             let currentHeight = jellyScale.height
             

             let displacementX = currentWidth - 1.0
             let forceX = -stiffness * displacementX - damping * jellyVelocity.width
             let accelX = forceX / mass
             
             let displacementY = currentHeight - 1.0
             let forceY = -stiffness * displacementY - damping * jellyVelocity.height
             let accelY = forceY / mass

             jellyVelocity.width += accelX * dt
             jellyVelocity.height += accelY * dt
             
             jellyScale.width += jellyVelocity.width * dt
             jellyScale.height += jellyVelocity.height * dt
        }
        
        updateThumbAppearance()
    }
    
    private func updateThumbAppearance() {
        let baseSize = Constants.defaultThumbSize
        let finalWidth = baseSize.width * presentationScale * jellyScale.width
        let finalHeight = baseSize.height * presentationScale * jellyScale.height
        
        customThumbContainer.bounds = CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight)
        
        solidThumbView.frame = customThumbContainer.bounds
        solidThumbView.layer.cornerRadius = 12.0 * presentationScale
        
        let visualPadding: CGFloat = 20.0
        glassThumbView.frame = customThumbContainer.bounds.insetBy(dx: -visualPadding, dy: -visualPadding)
        glassThumbView.visualPadding = visualPadding
        glassThumbView.glassCornerRadius = 12.0 * presentationScale
        
        glassThumbView.notifyGeometryUpdate()
    }
    
    private func calculateJellyScale(velocity: CGPoint) -> CGSize {
        let maxDistortion: CGFloat = 1.5
        let velocityScale: CGFloat = 1000.0
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)

        if speed < 0.001 { return CGSize(width: 1, height: 1) }

        let distortionFactor = min(max(speed / velocityScale, 0.0), 1.0) * maxDistortion
        if distortionFactor == 0 { return CGSize(width: 1, height: 1) }
        
        let direction = CGPoint(x: velocity.x / speed, y: velocity.y / speed)
        
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
    
    private func resetJellyScale() {
        jellyScale = CGSize(width: 1, height: 1)
        jellyVelocity = .zero
        updateThumbAppearance()
    }

    private var presentationScale: CGFloat = 1.0

    private var isAnimatingUp: Bool = false
    private var pendingReset: Bool = false

    private func animateToGlassState(_ isGlass: Bool) {
        if !isGlass && isAnimatingUp {
            pendingReset = true
            return
        }

        if isGlass {
            isAnimatingUp = true
            pendingReset = false
        }
        
        glassAnimator?.stopAnimation(true)
        
        glassAnimator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1.0) {
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
        let endScale: CGFloat = isGlass ? 1.4 : 1.0

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

            if self.displayLink == nil {
                self.updateThumbAppearance()
            }

            if progress >= 1.0 {
                timer.invalidate()

                if isGlass {
                    self.isAnimatingUp = false
                    if self.pendingReset {
                        self.pendingReset = false
                        self.animateToGlassState(false)
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)

        glassAnimator?.startAnimation()
    }
    
    private func setupCommon() {
        addSubview(customThumbContainer)
        customThumbContainer.isUserInteractionEnabled = false
        customThumbContainer.bounds = CGRect(origin: .zero, size: Constants.defaultThumbSize)

        customThumbContainer.addSubview(solidThumbView)
        solidThumbView.backgroundColor = .white
        solidThumbView.layer.cornerCurve = .continuous
        solidThumbView.layer.cornerRadius = 12.0
        solidThumbView.layer.allowsEdgeAntialiasing = true

        customThumbContainer.addSubview(glassThumbView)
        
        var settings = LiquidGlassSettings()
        settings.refractiveIndex = 1.08
        settings.thickness = 10.0
        settings.blur = 0.0
        settings.saturation = 1.5
        settings.lightIntensity = 0.7
        settings.ambientStrength = 0.5
        settings.chromaticAberration = 1.0
        settings.lightAngle = Float.pi / 4
        settings.glassColor = UIColor.white.withAlphaComponent(0.1)
        settings.visibility = 0.0

        glassThumbView.settings = settings
        glassThumbView.shapeType = Int(SHAPE_TYPE_ROUNDED_RECT)
        

        glassThumbView.layer.shadowColor = UIColor.white.cgColor
        glassThumbView.layer.shadowOpacity = 0.5
        glassThumbView.layer.shadowRadius = 12.0
        glassThumbView.layer.shadowOffset = .zero
        
        glassThumbView.alpha = 0.0
        
        glassThumbView.onDebugImageUpdate = { [weak self] image in
            guard let self = self, let window = self.window else { return }
            if self.debugWindowView == nil {
                let v = UIImageView(frame: CGRect(x: window.bounds.width - 160, y: 60, width: 150, height: 150))
                v.backgroundColor = .black
                v.layer.borderWidth = 1
                v.layer.borderColor = UIColor.red.cgColor
                v.contentMode = .scaleAspectFit
                window.addSubview(v)
                self.debugWindowView = v
            }
            self.debugWindowView?.image = image
            self.debugWindowView?.isHidden = false
            window.bringSubviewToFront(self.debugWindowView!)
        }
    }

    private enum Constants {
        static let defaultThumbSize = CGSize(width: 37.0, height: 24.0)
        static let effectiveKnobSize = CGSize(width: 28.0, height: 28.0)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

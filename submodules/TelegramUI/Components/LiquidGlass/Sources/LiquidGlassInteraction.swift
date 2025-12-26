import UIKit

final class LiquidGlassInteraction: NSObject, UIInteraction {
    weak var view: UIView?
    
    var isStretchEnabled: Bool = true
    var isGlowEnabled: Bool = true

    var stretchFactor: CGFloat = 0.5
    var resistance: CGFloat = 0.08
    var maxScale: CGFloat = 1.05

    private var velocity: CGPoint = .zero
    private var currentStretch: CGPoint = .zero
    private var displayLink: CADisplayLink?
    private var targetStretch: CGPoint = .zero
    
    private let spring = SpringSimulation(stiffness: 300, damping: 20)

    private lazy var panGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        pan._setHysteresis(0.0)
        return pan
    }()

    func willMove(to view: UIView?) {
    }
    
    func didMove(to view: UIView?) {
        self.view?.removeGestureRecognizer(panGesture)
        
        self.view = view
        
        if let view = view {
            view.addGestureRecognizer(panGesture)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isStretchEnabled else { return }
        
        switch gesture.state {
        case .began, .changed:
            let translation = gesture.translation(in: view)

            let resisted = applyResistance(to: translation)
            targetStretch = resisted
            
            startPhysics()

            updateGlow(location: gesture.location(in: view))
            
        case .ended, .cancelled, .failed:
            targetStretch = .zero
            if let glassView = view as? LiquidGlassView {
                glassView.lightPosition = nil
            }
            
        default:
            break
        }
    }
    
    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
    }

    private func startPhysics() {
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink?.add(to: .main, forMode: .common)
        }
    }
    
    private func stopPhysics() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func tick(link: CADisplayLink) {
        let dt = CGFloat(link.duration)

        let (newStretch, newVelocity) = spring.simulate(
            current: currentStretch,
            target: targetStretch,
            velocity: velocity,
            dt: dt
        )
        currentStretch = newStretch
        velocity = newVelocity

        applyTransform(stretch: currentStretch)
        
        if let glassView = view as? LiquidGlassView {
            glassView.notifyGeometryUpdate()
        }

        if targetStretch == .zero && abs(currentStretch.x) < 0.1 && abs(currentStretch.y) < 0.1 && abs(velocity.x) < 5 && abs(velocity.y) < 5 {
            stopPhysics()
            applyTransform(stretch: .zero)
        }
    }
    
    private func applyTransform(stretch: CGPoint) {
        guard let view = view else { return }

        let size = view.bounds.size
        if size.width == 0 || size.height == 0 { return }
        
        let relativeX = stretch.x / size.width
        let relativeY = stretch.y / size.height
        
        let volumeFactor: CGFloat = 0.5
        
        let baseScaleX = 1 + abs(relativeX) * stretchFactor
        let baseScaleY = 1 + abs(relativeY) * stretchFactor

        let magnitude = sqrt(relativeX * relativeX + relativeY * relativeY)
        let targetVolume = 1 + magnitude * volumeFactor
        let currentVolume = baseScaleX * baseScaleY
        let volumeCorrection = sqrt(targetVolume / currentVolume)
        
        var scaleX = baseScaleX * volumeCorrection
        var scaleY = baseScaleY * volumeCorrection

        scaleX = max(0.5, min(scaleX, 2.0))
        scaleY = max(0.5, min(scaleY, 2.0))

        let translation = CGAffineTransform(translationX: stretch.x, y: stretch.y)
        let scaling = CGAffineTransform(scaleX: scaleX, y: scaleY)
        
        view.transform = translation.concatenating(scaling)
    }
    
    private func updateGlow(location: CGPoint) {
        guard isGlowEnabled, let glassView = view as? LiquidGlassView else { return }
        glassView.lightPosition = location
    }

    private func applyResistance(to translation: CGPoint) -> CGPoint {
        return CGPoint(
            x: resist(translation.x),
            y: resist(translation.y)
        )
    }
    
    private func resist(_ value: CGFloat) -> CGFloat {
        if resistance == 0 { return value }
        let magnitude = abs(value)
        let resisted = magnitude / (1 + magnitude * resistance)
        return value > 0 ? resisted : -resisted
    }
}

fileprivate struct SpringSimulation {
    let stiffness: CGFloat
    let damping: CGFloat
    
    func simulate(current: CGPoint, target: CGPoint, velocity: CGPoint, dt: CGFloat) -> (CGPoint, CGPoint) {
        // F = -kx - cv
        let displacementX = current.x - target.x
        let displacementY = current.y - target.y
        
        let forceX = -stiffness * displacementX - damping * velocity.x
        let forceY = -stiffness * displacementY - damping * velocity.y
        
        // Acceleration (mass = 1)
        let ax = forceX
        let ay = forceY
        
        // Euler integration
        let newVx = velocity.x + ax * dt
        let newVy = velocity.y + ay * dt
        
        let newX = current.x + newVx * dt
        let newY = current.y + newVy * dt
        
        return (CGPoint(x: newX, y: newY), CGPoint(x: newVx, y: newVy))
    }
}

extension LiquidGlassInteraction: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

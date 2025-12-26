import UIKit

extension UIView {

    var frameUsingCenterAndBounds: CGRect {
        get {
            let savedAnchorPoint = layer.anchorPoint
            layer.setAnchorPointWithoutChangingPosition(CGPoint(x: 0.5, y: 0.5))

            let bounds = self.bounds
            let center = self.center
            let origin = CGPoint(x: center.x - bounds.width * 0.5, y: center.y - bounds.height * 0.5)

            layer.setAnchorPointWithoutChangingPosition(savedAnchorPoint)
            return CGRect(origin: origin, size: bounds.size)
        }
        set {
            let savedTransform = layer.transform
            let savedAnchorPoint = layer.anchorPoint

            layer.transform = CATransform3DIdentity
            layer.setAnchorPointWithoutChangingPosition(CGPoint(x: 0.5, y: 0.5))

            let newCenter = CGPoint(x: newValue.origin.x + newValue.width * 0.5, y: newValue.origin.y + newValue.height * 0.5)

            bounds = CGRect(origin: bounds.origin, size: newValue.size)
            center = newCenter

            layer.setAnchorPointWithoutChangingPosition(savedAnchorPoint)
            layer.transform = savedTransform
        }
    }
}

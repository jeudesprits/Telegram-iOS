extension CALayer {

    func setAnchorPointWithoutChangingPosition(_ newAnchorPoint: CGPoint) {
        let bounds = self.bounds

        let newAnchorOffset = CGPoint(
            x: newAnchorPoint.x * bounds.width,
            y: newAnchorPoint.y * bounds.height
        )

        let currentAnchorPoint = anchorPoint
        let oldAnchorOffset = CGPoint(
            x: currentAnchorPoint.x * bounds.width,
            y: currentAnchorPoint.y * bounds.height
        )

        let affine = CATransform3DGetAffineTransform(transform)

        let newTransformed = CGPoint(
            x: affine.tx + affine.a * newAnchorOffset.x + affine.c * newAnchorOffset.y,
            y: affine.ty + affine.b * newAnchorOffset.x + affine.d * newAnchorOffset.y
        )

        let oldTransformed = CGPoint(
            x: affine.tx + affine.a * oldAnchorOffset.x + affine.c * oldAnchorOffset.y,
            y: affine.ty + affine.b * oldAnchorOffset.x + affine.d * oldAnchorOffset.y
        )

        let position = self.position
        let newPosition = CGPoint(
            x: position.x - oldTransformed.x + newTransformed.x,
            y: position.y - oldTransformed.y + newTransformed.y
        )

        self.position = newPosition
        anchorPoint = newAnchorPoint
    }

    var frameUsingCenterAndBounds: CGRect {
        get {
            let savedAnchorPoint = anchorPoint

            setAnchorPointWithoutChangingPosition(CGPoint(x: 0.5, y: 0.5))

            let bounds = bounds
            let position = position

            let originX = position.x - bounds.width * 0.5
            let originY = position.y - bounds.height * 0.5

            setAnchorPointWithoutChangingPosition(savedAnchorPoint)

            return CGRect(x: originX, y: originY, width: bounds.width, height: bounds.height)
        }
        set {
            let savedTransform = transform
            let savedAnchorPoint = anchorPoint

            transform = CATransform3DIdentity

            setAnchorPointWithoutChangingPosition(CGPoint(x: 0.5, y: 0.5))

            let centerX = newValue.origin.x + newValue.size.width * 0.5
            let centerY = newValue.origin.y + newValue.size.height * 0.5

            let currentBounds = self.bounds
            bounds = CGRect(x: currentBounds.origin.x, y: currentBounds.origin.y, width: newValue.size.width, height: newValue.size.height)
            position = CGPoint(x: centerX, y: centerY)

            setAnchorPointWithoutChangingPosition(savedAnchorPoint)

            transform = savedTransform
        }
    }
}


#ifndef UIKitCorePrivate_h
#define UIKitCorePrivate_h

#import <UIKit/UIKit.h>

UIKIT_EXTERN_C_BEGIN
UIKIT_EXTERN CGImageRef UICreateCGImageFromIOSurface(IOSurfaceRef);
UIKIT_EXTERN_C_END

@interface UIWindow ()
- (IOSurfaceRef)createIOSurfaceWithFrame:(CGRect)arg1;
@end

@interface UIView ()
- (IOSurfaceRef)_createIOSurfaceWithPadding:(UIEdgeInsets)arg1;
@end

@interface UIPanGestureRecognizer ()
- (void)_setHysteresis:(double)arg1;
@end

#endif // UIKitCorePrivate_h

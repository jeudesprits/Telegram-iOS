#import "UISwitch+LiquidGlass.h"
#include <objc/runtime.h>
#include <objc/message.h>

CGSize (*uiswitchModernVisualElement_preferredContentSize_original)(Class self, SEL _cmd);
CGSize uiswitchModernVisualElement_preferredContentSize_custom(Class self, SEL _cmd) {
    return CGSizeMake(63.0, 28.0);
}

UIColor *(*uiswitchModernVisualElement_effectiveTintColor_original)(UIView *self, SEL _cmd);
UIColor *uiswitchModernVisualElement_effectiveTintColor_custom(UIView *self, SEL _cmd) {
    return [UIColor tertiaryLabelColor];
}

UIImage *(*uiswitchModernVisualElement_effectiveThumbImage_original)(UIView *self, SEL _cmd);
UIImage *uiswitchModernVisualElement_effectiveThumbImage_custom(UIView *self, SEL _cmd) {
    return nil;
}

CGRect (*uiswitchModernVisualElement_knobBoundsPressed_original)(UIView *self, SEL _cmd, bool arg1);
CGRect uiswitchModernVisualElement_knobBoundsPressed_custom(UIView *self, SEL _cmd, bool arg1) {
    return CGRectMake(0.0, 0.0, 37.0, 24.0);
}

CGPoint (*uiswitchModernVisualElement_knobPositionOnPressedForBounds_original)(UIView *self, SEL _cmd, bool arg1, bool arg2, CGRect arg3);
CGPoint uiswitchModernVisualElement_knobPositionOnPressedForBounds_custom(UIView *self, SEL _cmd, bool arg1, bool arg2, CGRect arg3) {
    if (arg1) {
        return  CGPointMake(42.5, 14.0);
    } else {
        return  CGPointMake(20.5, 14.0);
    }
}

CGPoint (*uiswitchModernVisualElement_offImagePosition_original)(UIView *self, SEL _cmd);
CGPoint uiswitchModernVisualElement_offImagePosition_custom(UIView *self, SEL _cmd) {
    return CGPointMake(48.0, 14.0);
}

CGPoint (*uiswitchModernVisualElement_onImagePosition_original)(UIView *self, SEL _cmd);
CGPoint uiswitchModernVisualElement_onImagePosition_custom(UIView *self, SEL _cmd) {
    return CGPointMake(15.0, 14.0);
}

//__attribute__((objc_direct_members))
@implementation UISwitch (TG_LiquidGlass)

- (UIView *)tg_liquidGlass_modernVisualElement {
    return ((UIView *(*)(UISwitch *, SEL))objc_msgSend)(self, sel_registerName("visualElement"));
}

- (UIView *)tg_liquidGlass_switchWellView {
    UIView *modernVisualElement = self.tg_liquidGlass_modernVisualElement;
    if (modernVisualElement == nil) {
        return  nil;
    }
    return object_getIvar(modernVisualElement, class_getInstanceVariable(NSClassFromString(@"UISwitchModernVisualElement"), "_switchWellView"));
}

- (UIView *)tg_liquidGlass_switchWellContainerView {
    UIView *modernVisualElement = self.tg_liquidGlass_modernVisualElement;
    if (modernVisualElement == nil) {
        return  nil;
    }
    return object_getIvar(modernVisualElement, class_getInstanceVariable(NSClassFromString(@"UISwitchModernVisualElement"), "_switchWellContainerView"));
}

- (UIView *)tg_liquidGlass_switchWellImageViewContainer {
    UIView *modernVisualElement = self.tg_liquidGlass_modernVisualElement;
    if (modernVisualElement == nil) {
        return  nil;
    }
    return object_getIvar(modernVisualElement, class_getInstanceVariable(NSClassFromString(@"UISwitchModernVisualElement"), "_switchWellImageViewContainer"));
}

- (UIImageView *)tg_liquidGlass_knobImageView {
    UIView *modernVisualElement = self.tg_liquidGlass_modernVisualElement;
    if (modernVisualElement == nil) {
        return  nil;
    }
    return object_getIvar(modernVisualElement, class_getInstanceVariable(NSClassFromString(@"UISwitchModernVisualElement"), "_knobView"));
}

+ (void)load {
    Class UISwitchModernVisualElement = objc_lookUpClass("UISwitchModernVisualElement");
    {
        Method method = class_getClassMethod(UISwitchModernVisualElement, sel_registerName("preferredContentSize"));
        uiswitchModernVisualElement_preferredContentSize_original = (typeof(uiswitchModernVisualElement_preferredContentSize_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uiswitchModernVisualElement_preferredContentSize_custom);
    }
    {
        Method method = class_getInstanceMethod(UISwitchModernVisualElement, sel_registerName("_effectiveTintColor"));
        uiswitchModernVisualElement_effectiveTintColor_original = (typeof(uiswitchModernVisualElement_effectiveTintColor_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uiswitchModernVisualElement_effectiveTintColor_custom);
    }
    {
        Method method = class_getInstanceMethod(UISwitchModernVisualElement, sel_registerName("_effectiveThumbImage"));
        uiswitchModernVisualElement_effectiveThumbImage_original = (typeof(uiswitchModernVisualElement_effectiveThumbImage_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uiswitchModernVisualElement_effectiveThumbImage_custom);
    }
    {
        Method method = class_getInstanceMethod(UISwitchModernVisualElement, sel_registerName("_knobBoundsPressed:"));
        uiswitchModernVisualElement_knobBoundsPressed_original = (typeof(uiswitchModernVisualElement_knobBoundsPressed_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uiswitchModernVisualElement_knobBoundsPressed_custom);

    }
    {
        Method method = class_getInstanceMethod(UISwitchModernVisualElement, sel_registerName("_knobPositionOn:pressed:forBounds:"));
        uiswitchModernVisualElement_knobPositionOnPressedForBounds_original = (typeof(uiswitchModernVisualElement_knobPositionOnPressedForBounds_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uiswitchModernVisualElement_knobPositionOnPressedForBounds_custom);

    }
    {
        Method method = class_getInstanceMethod(UISwitchModernVisualElement, sel_registerName("_offImagePosition"));
        uiswitchModernVisualElement_offImagePosition_original = (typeof(uiswitchModernVisualElement_offImagePosition_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uiswitchModernVisualElement_offImagePosition_custom);

    }
    {
        Method method = class_getInstanceMethod(UISwitchModernVisualElement, sel_registerName("_onImagePosition"));
        uiswitchModernVisualElement_onImagePosition_original = (typeof(uiswitchModernVisualElement_onImagePosition_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uiswitchModernVisualElement_onImagePosition_custom);

    }
}

@end

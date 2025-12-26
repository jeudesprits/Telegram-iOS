#import "UISlider+LiquidGlass.h"
#include <objc/runtime.h>
#include <objc/message.h>

CGSize (*uislider_intrinsicSizeWithinSize_original)(Class self, SEL _cmd, CGSize arg1);
CGSize uislider_intrinsicSizeWithinSize_custom(Class self, SEL _cmd, CGSize arg1) {
    CGSize size = uislider_intrinsicSizeWithinSize_original(self, _cmd, arg1);
    return CGSizeMake(size.width, 34.0);
}

@implementation UISlider (TG_LiquidGlass)

- (UIView *)tg_liquidGlass_thumbView  {
    SEL selector = sel_registerName("_thumbViewNeue");
    if ([self respondsToSelector:selector]) {
        return ((UIView *(*)(UISlider *, SEL))objc_msgSend)(self, selector);
    }
    return nil;
}

- (UIImageView *)tg_liquidGlass_thumbImageView  {
    UIView *thumbView = [self tg_liquidGlass_thumbView];
    if (thumbView.subviews.count == 0) {
        return nil;
    }
    __kindof UIView *subview = thumbView.subviews[0];
    if ([subview isKindOfClass:UIImageView.class]) {
        return subview;
    }
    return nil;
}

- (UIView *)tg_liquidGlass_minValueView {
    SEL selector = sel_registerName("_minValueView");
    if ([self respondsToSelector:selector]) {
        return ((UIView *(*)(UISlider *d, SEL))objc_msgSend)(self, selector);
    }
    return nil;
}

- (UIView *)tg_liquidGlass_maxValueView {
    SEL selector = sel_registerName("_maxValueView");
    if ([self respondsToSelector:selector]) {
        return ((UIView *(*)(UISlider *, SEL))objc_msgSend)(self, selector);
    }
    return nil;
}

- (UIView *)tg_liquidGlass_minTrackClipView {
    return [self tg_liquidGlass_minTrackImageView].superview;
}

- (UIView *)tg_liquidGlass_maxTrackClipView {
    return [self tg_liquidGlass_maxTrackImageView].superview;
}

- (UIImageView *)tg_liquidGlass_minTrackImageView {
    SEL selector = sel_registerName("_minTrackView");
    if ([self respondsToSelector:selector]) {
        return ((UIImageView *(*)(UISlider *, SEL))objc_msgSend)(self, selector);
    }
    return nil;
}

- (UIImageView *)tg_liquidGlass_maxTrackImageView {
    SEL selector = sel_registerName("_maxTrackView");
    if ([self respondsToSelector:selector]) {
        return ((UIImageView *(*)(UISlider *, SEL))objc_msgSend)(self, selector);
    }
    return nil;
}

+ (void)load {
    if (@available(iOS 26.0, *)) {
        return;
    }
    {
        Method method = class_getInstanceMethod(UISlider.class, sel_registerName("_intrinsicSizeWithinSize:"));
        uislider_intrinsicSizeWithinSize_original = (typeof(uislider_intrinsicSizeWithinSize_original))method_getImplementation(method);
        method_setImplementation(method, (IMP)uislider_intrinsicSizeWithinSize_custom);
    }

}

@end

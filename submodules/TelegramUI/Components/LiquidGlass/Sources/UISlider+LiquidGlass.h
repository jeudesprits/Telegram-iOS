#ifndef UISlider_LiquidGlass_h
#define UISlider_LiquidGlass_h

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UISlider (TG_LiquidGlass)
@property (nullable, nonatomic, readonly) UIView *tg_liquidGlass_thumbView;
@property (nullable, nonatomic, readonly) UIImageView *tg_liquidGlass_thumbImageView;
@property (nullable, nonatomic, readonly) UIView *tg_liquidGlass_minValueView;
@property (nullable, nonatomic, readonly) UIView *tg_liquidGlass_maxValueView;
@property (nullable, nonatomic, readonly) UIView *tg_liquidGlass_minTrackClipView;
@property (nullable, nonatomic, readonly) UIView *tg_liquidGlass_maxTrackClipView;
@property (nullable, nonatomic, readonly) UIImageView *tg_liquidGlass_minTrackImageView;
@property (nullable, nonatomic, readonly) UIImageView *tg_liquidGlass_maxTrackImageView;
@end

NS_ASSUME_NONNULL_END

#endif // UISlider_LiquidGlass_h

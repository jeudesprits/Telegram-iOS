#ifndef QuartzCorePrivate_h
#define QuartzCorePrivate_h

#import <QuartzCore/QuartzCore.h>

@interface CALayer ()
@property BOOL punchoutShadow;
@property BOOL shadowPathIsBounds;
@property unsigned int disableUpdateMask;
@end

@interface CAPortalLayer : CALayer
@property bool allowedInContextTransform;
@property bool allowsBackdropGroups;
@property bool crossDisplay;
@property bool excludeSeparated;
@property bool hidesSourceLayer;
@property bool hidesSourceLayerInOtherPortals;
@property bool matchesOpacity;
@property bool matchesPosition;
@property bool matchesTransform;
@property (copy) NSDictionary *overrides;
@property uint32_t sourceContextId;
@property CALayer *sourceLayer;
@property float sourceLayerOpacityScale;
@property uint64_t sourceLayerRenderId;
- (void)setAllowedInContextTransform:(bool)arg1;
- (void)setAllowsBackdropGroups:(bool)arg1;
- (void)setCrossDisplay:(bool)arg1;
- (void)setExcludeSeparated:(bool)arg1;
- (void)setHidesSourceLayer:(bool)arg1;
- (void)setHidesSourceLayerInOtherPortals:(bool)arg1;
- (void)setMatchesOpacity:(bool)arg1;
- (void)setMatchesPosition:(bool)arg1;
- (void)setMatchesTransform:(bool)arg1;
- (void)setOverrides:(NSDictionary *)arg1;
- (void)setSourceContextId:(uint32_t)arg1;
- (void)setSourceLayer:(CALayer *)arg1;
- (void)setSourceLayerOpacityScale:(float)arg1;
- (void)setSourceLayerRenderId:(uint64_t)arg1;
@end

#endif // QuartzCorePrivate_h

#import "SceneSizeRequest.h"
#include <math.h>

@interface UIScene (ProbeClientSize)
- (void)_updateUIClientSettingsWithBlock:(void (^)(id settings))block;
- (id)_FBSScene;
@end

@interface NSObject (ProbeClientSize)
- (void)setPreferredContentSize:(CGSize)size;
- (CGSize)preferredContentSize;
- (id)clientSettings;
@end

BOOL ProbeRequestSceneContentSize(UIWindowScene *scene, CGSize size) {
    if (!isfinite(size.width) || !isfinite(size.height) || size.width <= 0 || size.height <= 0 ||
        ![scene respondsToSelector:@selector(_updateUIClientSettingsWithBlock:)] ||
        ![NSClassFromString(@"FBSSceneClientSettings") instancesRespondToSelector:@selector(setPreferredContentSize:)]) {
        return NO;
    }
    [scene _updateUIClientSettingsWithBlock:^(id settings) {
        if ([settings respondsToSelector:@selector(setPreferredContentSize:)]) {
            [settings setPreferredContentSize:size];
        }
    }];
    return YES;
}

CGSize ProbeSceneClientPreferredSize(UIWindowScene *scene) {
    if (![scene respondsToSelector:@selector(_FBSScene)]) return CGSizeZero;
    id backend = [scene _FBSScene];
    if (![backend respondsToSelector:@selector(clientSettings)]) return CGSizeZero;
    id settings = [backend clientSettings];
    return [settings respondsToSelector:@selector(preferredContentSize)] ? [settings preferredContentSize] : CGSizeZero;
}

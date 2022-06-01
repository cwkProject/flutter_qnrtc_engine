#import <Flutter/Flutter.h>
#import <QNRTCKit/QNRTCKit.h>
@interface FlutterQnrtcEnginePlugin : NSObject<FlutterPlugin>

+ (void)addView:(UIView *)view id:(NSNumber *)viewId;

+ (void)removeViewForId:(NSNumber *)viewId;

+ (UIView *)viewForId:(NSNumber *)viewId;

@end

@interface QnrtcRendererView : QNVideoView<FlutterPlatformView>

@end

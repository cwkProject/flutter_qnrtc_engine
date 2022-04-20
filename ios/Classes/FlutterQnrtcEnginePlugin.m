#import "FlutterQnrtcEnginePlugin.h"
#if __has_include(<flutter_qnrtc_engine/flutter_qnrtc_engine-Swift.h>)
#import <flutter_qnrtc_engine/flutter_qnrtc_engine-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_qnrtc_engine-Swift.h"
#endif

@implementation FlutterQnrtcEnginePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterQnrtcEnginePlugin registerWithRegistrar:registrar];
}
@end

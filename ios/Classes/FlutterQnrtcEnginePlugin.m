#import "FlutterQnrtcEnginePlugin.h"
#if __has_include(<flutter_qnrtc_engine/flutter_qnrtc_engine-Swift.h>)
#import <flutter_qnrtc_engine/flutter_qnrtc_engine-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_qnrtc_engine-Swift.h"
#endif
@interface QnrtcRendererView()

@property (nonatomic, assign) int64_t viewId;

@end
@implementation QnrtcRendererView

- (instancetype)initWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId
{
    if (self = [super initWithFrame:frame])
    {
        self.viewId = viewId;
    }
    return self;
}

- (nonnull UIView *)view
{
    return self;
}
-(void)removeFromSuperview
{
    [super removeFromSuperview];
    NSLog(@"test13:remove from super view");
    [FlutterQnrtcEnginePlugin removeViewForId:[NSNumber numberWithUnsignedLongLong: self.viewId]];
}
@end

@interface QnrtcRendererViewFactory : NSObject<FlutterPlatformViewFactory>

@end

@implementation QnrtcRendererViewFactory

- (nonnull NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id _Nullable)args
{
    QnrtcRendererView *rendererView = [[QnrtcRendererView alloc] initWithFrame:frame viewIdentifier:viewId];
    [FlutterQnrtcEnginePlugin addView:rendererView id:@(viewId)];
    return rendererView;
}



@end


@interface FlutterQnrtcEnginePlugin()<
QNRTCClientDelegate,
QNLocalVideoTrackDelegate,
QNLocalAudioTrackDelegate,
QNRemoteAudioTrackDelegate,
QNRemoteVideoTrackDelegate,
QNAudioMusicMixerDelegate
>

@property (strong, nonatomic) NSMutableDictionary<NSNumber*,QnrtcRendererView *> *rendererViews;

@property (strong, nonatomic) FlutterMethodChannel *channel;

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNScreenVideoTrack *screenTrack;
@property (nonatomic, strong) QNCameraVideoTrack *cameraTrack;
@property (nonatomic, strong) QNMicrophoneAudioTrack *audioTrack;
@property (nonatomic, strong) QNAudioMusicMixer * audioMixer;
@property (nonatomic, strong) NSMutableDictionary * viewDictionary;
@property (nonatomic, strong) NSString * musicPath;
@property (nonatomic, strong) NSMutableDictionary<NSString *,QNRemoteTrack *> *remoteTracks;
@property (nonatomic, strong) NSMutableDictionary<NSString *,QNLocalTrack *> *localTracks;



@end


@implementation FlutterQnrtcEnginePlugin
static FlutterQnrtcEnginePlugin * formatTrtcManager = nil;

+ (FlutterQnrtcEnginePlugin *)sharedQnrtcPluginlManager
{
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^(){
        formatTrtcManager = [[FlutterQnrtcEnginePlugin alloc] init];
    });
    return formatTrtcManager;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_qnrtc_engine"
                                     binaryMessenger:[registrar messenger]];
    
    FlutterQnrtcEnginePlugin* instance = [FlutterQnrtcEnginePlugin sharedQnrtcPluginlManager];
    instance.channel = channel;
    [registrar addMethodCallDelegate:instance channel:channel];
    
    QnrtcRendererViewFactory * fac = [[QnrtcRendererViewFactory alloc]init];
    [registrar registerViewFactory:fac withId:@"QNVideoGLView"];
    
    [[NSNotificationCenter defaultCenter] addObserver:instance selector:@selector(onDeviceOrientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
}

-(void)onDeviceOrientationChanged
{
    if(_cameraTrack)
    {
        switch(UIDevice.currentDevice.orientation)
        {
            case UIDeviceOrientationLandscapeLeft:
                _cameraTrack.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            case UIDeviceOrientationLandscapeRight:
                _cameraTrack.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
        }
    }
}
- (NSMutableDictionary *)rendererViews
{
    if (!_rendererViews) {
        _rendererViews = [[NSMutableDictionary alloc] init];
    }
    return _rendererViews;
}
-(void) removeSubView:(NSNumber * )viewId
{
    [_rendererViews removeObjectForKey:viewId];
}

+ (void)addView:(UIView *)view id:(NSNumber *)viewId
{
    if (!viewId) {
        return;
    }
    if (view) {
        [[[FlutterQnrtcEnginePlugin sharedQnrtcPluginlManager] rendererViews] setObject:view forKey:viewId];
    } else {
        [self removeViewForId:viewId];
    }
}

+ (void)removeViewForId:(NSNumber *)viewId {
    if (!viewId) {
        return;
    }
    [[[FlutterQnrtcEnginePlugin sharedQnrtcPluginlManager] rendererViews] removeObjectForKey:viewId];
}

+ (UIView *)viewForId:(NSNumber *)viewId {
    if (!viewId) {
        return nil;
    }
    return [[[FlutterQnrtcEnginePlugin sharedQnrtcPluginlManager] rendererViews] objectForKey:viewId];
}
-(void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result
{
    
    NSLog(@"test13:flutter call:%@",call.method);
    if([call.method isEqualToString:@"init"])
    {
        _localTracks = [[NSMutableDictionary alloc] init];
        _remoteTracks = [[NSMutableDictionary alloc] init];
        
        _viewDictionary = [[NSMutableDictionary alloc] init];
        
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"deinit"])
    {
        [QNRTC deinit];
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"createClient"])
    {
        // 1. 初始配置 QNRTC
        
        QNClientRole role = (QNClientRole)([call.arguments[@"role"] intValue]);
        QNClientMode mode = (QNClientMode)([call.arguments[@"mode"] intValue]);
        
        [QNRTC initRTC:[QNRTCConfiguration defaultConfiguration]];
        
        // 1.创建初始化 RTC 核心类 QNRTCClient
        self.client = [QNRTC createRTCClient:[[QNClientConfig defaultClientConfig] initWithMode:mode role:role]];
    
        // 2.设置 QNRTCClientDelegate 状态回调的代理
        self.client.delegate = self;
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"createMicrophoneAudioTrack"])
    {
        NSString *tag = call.arguments[@"tag"];
        int bitrate = [call.arguments[@"bitrate"] intValue];
        
        //not used by ios
        /*
        BOOL communicationModeOn = [call.arguments[@"communicationModeOn"] boolValue];
        
        int sampleRate = [call.arguments[@"sampleRate"] intValue];
        int channelCount = [call.arguments[@"channelCount"] intValue];
        int bitsPerSample = [call.arguments[@"bitsPerSample"] intValue];
        */
        
        QNMicrophoneAudioTrackConfig * microphoneConfig = [[QNMicrophoneAudioTrackConfig alloc] initWithTag:tag audioQuality:[[QNAudioQuality alloc] initWithBitrate:bitrate]];
        
        
        _audioTrack = [QNRTC createMicrophoneAudioTrackWithConfig:microphoneConfig];
        [_localTracks setObject:_audioTrack forKey:tag];
        
        NSDictionary * dic = @{@"trackId":_audioTrack.trackID?_audioTrack.trackID:@"",@"tag":tag,@"kind":@(_audioTrack.kind)};
        result(dic);
        return;
    }
    if([call.method isEqualToString:@"createCameraVideoTrack"])
    {
        NSString * tag = call.arguments[@"tag"];
        BOOL multiProfileEnabled = [call.arguments[@"multiProfileEnabled"] boolValue];
        int captureWidth = [call.arguments[@"encoderWidth"] intValue];
        int captureHeight = [call.arguments[@"encoderHeight"] intValue];
        int bitrate = [call.arguments[@"encoderBitrate"] intValue];
        CGSize encodeSize = {captureWidth,captureHeight};
        
        QNVideoEncoderConfig * config = [[QNVideoEncoderConfig alloc] initWithBitrate:bitrate videoEncodeSize:encodeSize];
        _cameraTrack = [QNRTC createCameraVideoTrackWithConfig:[[QNCameraVideoTrackConfig alloc] initWithSourceTag:tag config:config multiStreamEnable:multiProfileEnabled]];
        _cameraTrack.delegate = self;
        NSLog(@"test12:create track");
        
        switch(UIDevice.currentDevice.orientation)
        {
            case UIDeviceOrientationPortrait:
            case UIDeviceOrientationLandscapeLeft:
                _cameraTrack.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
            case UIDeviceOrientationLandscapeRight:
                _cameraTrack.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
        }
        
        [_localTracks setObject:_cameraTrack forKey:tag];
        
        result(@{@"trackId":_cameraTrack.trackID?_cameraTrack.trackID:@"",@"tag":tag,@"kind":@(_cameraTrack.kind)});
        return;
    }
    if([call.method isEqualToString:@"setAudioRouteToSpeakerphone"])
    {
        [QNRTC setAudioRouteToSpeakerphone:[call.arguments[@"audioRouteToSpeakerphone"] boolValue]];
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"setLogFileEnabled"])
    {
//        [QNRTC enableFileLogging];
//        [QNRTC setLogLevel:QNRTCLogLevelVerbose];
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"setAutoSubscribe"])
    {
        [_client setAutoSubscribe:[call.arguments[@"autoSubscribe"] boolValue]];
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"join"])
    {
//        [_client join:call.arguments[@"token"] userData:call.arguments[@"userData"]];
        [_client join:call.arguments[@"token"]];
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"leave"])
    {
        [_client leave];
        [_remoteTracks removeAllObjects];
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"publish"])
    {
        NSArray * trackListString = call.arguments;
       
        NSMutableArray<QNLocalTrack * > * trackList = [[NSMutableArray alloc] init];
        
        for(NSString * trackTag in trackListString)
        {
            QNLocalTrack * track = [_localTracks objectForKey:trackTag];
            if(track)
            {
                [trackList addObject:track];
            }
        }
        
        [_client publish:trackList completeCallback:^(BOOL onPublished, NSError *error) {
                //publish result
            if(error)
            {
                NSLog(@"test12:failed to publish local stream:%@",error.description);
            }
        }];
        
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"unpublish"])
    {
        NSArray * trackListString = call.arguments;
        NSMutableArray<QNLocalTrack * > * trackList = [[NSMutableArray alloc] init];
        
        for(NSString * trackTag in trackListString)
        {
            QNLocalTrack * track = [_localTracks objectForKey:trackTag];
            if(track)
            {
                [trackList addObject:track];
            }
        }
//        [_client unpublish: trackList];
        
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"subscribe"])
    {
        NSArray * trackListString = call.arguments;
        
        NSMutableArray<QNRemoteTrack *> * tracksList = [[NSMutableArray alloc] init];
        for(NSString * name in trackListString)
        {
            NSLog(@"subscribe :%@",name);
            QNRemoteTrack * track = [_remoteTracks objectForKey:name];
            if(track)
            {
                [tracksList addObject:track];
            }
        }
        
        if(tracksList.count > 0)
        [_client subscribe: tracksList];
        
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"unsubscribe"])
    {
        NSArray * trackListString = call.arguments;
        NSMutableArray<QNRemoteTrack *> * trackList = [[NSMutableArray alloc] init];
        for(NSString * trackId in trackListString)
        {
            NSLog(@"unsubscribe :%@",trackId);
            QNRemoteTrack * track = [_remoteTracks objectForKey:trackId];
            
            if(track)
            {
                [trackList addObject:track];
            }
            
        }
        if(trackList.count)
            [_client unsubscribe: trackList];
        
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"getUserNetworkQuality"])
    {
        NSDictionary * qualityMap = [_client getUserNetworkQuality];
                      
        result(qualityMap);
        return;
    }
    if([call.method isEqualToString:@"setClientRole"])
    {
        QNClientRole role = (QNClientRole)([call.arguments[@"role"] intValue]);
        [_client setClientRole:role completeCallback:^(QNClientRole newRole, NSError *error) {
            if(error != nil)
            {
                
            }
            
        }];
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"isLocalTrackMuted"])
    {
        QNLocalTrack * track = [_localTracks objectForKey:call.arguments[@"tag"]];
        if(track)
        {
            result(@(track.muted));
            return;
        }
        result(@(NO));
        return;
    }
    if([call.method isEqualToString:@"setLocalTrackMuted"])
    {
        QNLocalTrack * track = [_localTracks objectForKey:call.arguments[@"tag"]];
        if(track)
        {
            [track updateMute:[call.arguments[@"muted"] boolValue]];
            result(nil);
            return;
        }
        result(@(NO));
        return;
    }
    if([call.method isEqualToString:@"localTrackDestroy"])
    {
        QNLocalTrack * track = [_localTracks objectForKey:call.arguments[@"tag"]];
        if(track.kind == QNTrackKindAudio)
        {
            [_audioTrack destroy];
            _audioTrack = nil;
        }
        else
        {
            NSLog(@"test12:destroys track");
//            [NSThread sleepForTimeInterval:5.f];
            [_cameraTrack destroy];
            _cameraTrack = nil;
        }
        [_localTracks removeObjectForKey:call.arguments[@"tag"]];
    
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"isRemoteTrackMuted"])
    {
        QNRemoteTrack * track = [_remoteTracks objectForKey:call.arguments[@"trackId"]];
        if(track)
        {
            result([NSNumber numberWithBool:track.muted]);
            return;
        }
        result(@(NO));
        return;
    }
    if([call.method isEqualToString:@"isRemoteTrackSubscribed"])
    {
        QNRemoteTrack * track = [_remoteTracks objectForKey:call.arguments[@"trackId"]];
        if(track)
        {
            result([NSNumber numberWithBool:track.isSubscribed]);
            return;
        }
        result(@(NO));
        return;
    }
    if([call.method isEqualToString:@"remoteVideoPlay"])
    {
        QNRemoteTrack * track = [_remoteTracks objectForKey:call.arguments[@"trackId"]];
        NSLog(@"test13:remoteVideoPlay:%@",call.arguments);
        
        if(track && [track isKindOfClass:[QNRemoteVideoTrack class]])
        {
            
            
            QNRemoteVideoTrack * videoTrack = (QNRemoteVideoTrack * )track;
            if(call.arguments[@"viewId"] != [NSNull null])
            {
                NSNumber * viewId = call.arguments[@"viewId"];
                QnrtcRendererView * view = (QnrtcRendererView *)([FlutterQnrtcEnginePlugin viewForId:viewId]);
                [_viewDictionary setObject:viewId forKey:videoTrack.trackID];
                NSLog(@"test13:bind to view %d %p",[viewId intValue],view);
                [videoTrack play:view];
            }
        }

        result(nil);
        return;
        
    }
    if([call.method isEqualToString:@"setRemoteVideoProfile"])
    {
        QNRemoteTrack * track = [_remoteTracks objectForKey:call.arguments[@"trackId"]];
        if(track && [track isKindOfClass:[QNRemoteVideoTrack class]])
        {
            QNRemoteVideoTrack * videoTrack = (QNRemoteVideoTrack * )track;
            QNTrackProfile profile = (QNTrackProfile)([call.arguments[@"profile"] intValue]);
            [videoTrack setProfile:profile];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"isMultiProfileEnabled"])
    {
        QNRemoteTrack * track = [_remoteTracks objectForKey:call.arguments[@"trackId"]];
        if(track && [track isKindOfClass:[QNRemoteVideoTrack class]])
        {
            QNRemoteVideoTrack * videoTrack = (QNRemoteVideoTrack * )track;
           
            result([NSNumber numberWithInt:(int)(videoTrack.profile)]);
        }
        else
            result(nil);
        return;
    }
    if([call.method isEqualToString:@"getRemoteAudioVolume"])
    {
        QNRemoteTrack * track = [_remoteTracks objectForKey:call.arguments[@"trackId"]];
        if(track && [track isKindOfClass:[QNRemoteAudioTrack class]])
        {
            QNRemoteAudioTrack * audioTrack = (QNRemoteAudioTrack * )track;
           
            result([NSNumber numberWithInt:(int)([audioTrack getVolumeLevel])]);
        }
        else
            result(nil);
        return;
    }
    
    if([call.method isEqualToString:@"cameraPlay"])
    {
        if(_cameraTrack)
        {
            QnrtcRendererView * view = (QnrtcRendererView *)([FlutterQnrtcEnginePlugin viewForId:@([call.arguments[@"viewId"] integerValue])]);
            [_cameraTrack play:view];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"cameraStartCapture"])
    {
        if(_cameraTrack)
        {
            [_cameraTrack startCapture];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"cameraStopCapture"])
    {
        if(_cameraTrack)
        {
            [_cameraTrack stopCapture];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"switchCamera"])
    {
        if(_cameraTrack)
        {
            [_cameraTrack switchCamera];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"turnLightOn"])
    {
        //not implement for ios
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"turnLightOff"])
    {
        //not implement for ios
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"setExposureCompensation"])
    {
        //not implement for ios
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"getMaxExposureCompensation"])
    {
    
        //not implement for ios
        result(@(0));
        return;
    }
    if([call.method isEqualToString:@"getMinExposureCompensation"])
    {
        //not implement for ios
        result(@(0));
        return;
    }
    if([call.method isEqualToString:@"setCameraMirror"])
    {
        BOOL mirror = [call.arguments[@"mirror"] boolValue];
        if(_cameraTrack)
            [_cameraTrack setEncodeMirrorRearFacing:mirror];
//        [_camera]
        result(@(0));
        return;
    }
    if([call.method isEqualToString:@"setPreviewEnabled"])
    {
        //not implement for ios
        result(@(0));
        return;
        
    }
    if([call.method isEqualToString:@"setBeauty"])
    {
        bool enabled = [call.arguments[@"enabled"] boolValue];
        float smooth = [call.arguments[@"smooth"] floatValue];
        float whiten = [call.arguments[@"whiten"]  floatValue];
        float redden = [call.arguments[@"redden"] floatValue];
        if(_cameraTrack)
        {
            [_cameraTrack setBeautifyModeOn:enabled];
            [_cameraTrack setSmoothLevel:smooth];
            [_cameraTrack setWhiten:whiten];
            [_cameraTrack setRedden:redden];
        }
        
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"setMicrophoneVolume"])
    {
        if(_audioTrack)
        {
            float volume = [call.arguments[@"volume"] floatValue];
            [_audioTrack setVolume:volume];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"createAudioMixer"])
    {
        _musicPath = call.arguments[@"musicPath"];
        NSString * musicPath = [_musicPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
     
        if(_audioTrack)
        {
            _audioMixer = [_audioTrack createAudioMusicMixer:_musicPath musicMixerDelegate:self];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"audioMixerStart"])
    {
        if(_audioTrack)
        {
            [_audioMixer start];
        }
        result(nil);
        return;
    }
   
    if([call.method isEqualToString:@"audioMixerStop"])
    {
        if(_audioTrack)
        {
            [_audioMixer stop];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"audioMixerPause"])
    {
        if(_audioTrack)
        {
            [_audioMixer pause];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"audioMixerResume"])
    {
        if(_audioTrack)
        {
            [_audioMixer resume];
        }
        result(nil);
        return;
    }
    if([call.method isEqualToString:@"audioMixerGetDuration"])
    {
        if(_audioTrack)
        {
            int duration = (int)([QNAudioMusicMixer getDuration:call.arguments[@"musicPath"]]) * 1000;
            result([NSNumber numberWithInt:duration]);
            return;
        }
        result(nil);
        return;
    }
    
    if([call.method isEqualToString:@"audioMixerEnableEarMonitor"])
    {

        [_audioTrack setEarMonitorEnabled:[call.arguments[@"enable"] boolValue]];
        result(nil);
        return;
    }
    
    result(nil);
    return;
}
    

/**
 * 房间状态变更的回调。当状态变为 QNRoomStateReconnecting 时，SDK 会为您自动重连，如果希望退出，直接调用 leaveRoom 即可
 */
- (void)RTCClient:(QNRTCClient *)client didConnectionStateChanged:(QNConnectionState)state disconnectedInfo:(QNConnectionDisconnectedInfo *)info {
    
    NSDictionary *roomStateDictionary =  @{
                                           @(QNConnectionStateDisconnected) : @"Idle",
                                           @(QNConnectionStateConnecting) : @"Connecting",
                                           @(QNConnectionStateConnected): @"Connected",
                                           @(QNConnectionStateReconnecting) : @"Reconnecting",
                                           @(QNConnectionStateReconnected) : @"Reconnected"
                                           };
    NSString *str = [NSString stringWithFormat:@"房间状态变更的回调。当状态变为 QNRoomStateReconnecting 时，SDK 会为您自动重连，如果希望退出，直接调用 leaveRoom 即可:\nroomState: %@\ninfo:%lu",  roomStateDictionary[@(state)], (unsigned long)info.reason];
    
    NSLog(@"%@", str);
    NSError * error = info?info.error:nil;
    [_channel invokeMethod:@"onConnectionStateChanged" arguments:@{@"state":@(state),@"errorCode:":error?@(error.code):@(0),@"errorMessage:":error?error.description:@""}];
#if 0
    if (QNConnectionStateConnected == state || QNConnectionStateReconnected == state) {
        //tobefixed:
//        [self startGetStatsTimer];
        
    } else {
        //tobefixed:
//        [self stopGetStatsTimer];
    }
    //tobefixed:
//    [self addLogString:str];
    if (QNConnectionStateIdle == state) {
        switch (info.reason) {
            case QNConnectionDisconnectedReasonKickedOut:{
                str =[NSString stringWithFormat:@"被远端服务器踢出的回调"];
//               tobefixed:
//                [self addLogString:str];
            }
                break;
            case QNConnectionDisconnectedReasonLeave:{
                str = [NSString stringWithFormat:@"本地用户离开房间"];
                //tobefixed:
//                [self addLogString:str];
            }
                break;
                
            default:{
                str = [NSString stringWithFormat:@"SDK 运行过程中发生错误会通过该方法回调，具体错误码的含义可以见 QNTypeDefines.h 文件:\nerror: %@",  info.error];
                //tobefixed:
//                [self addLogString:str];
                switch (info.error.code) {
                    case QNRTCErrorAuthFailed:
                        NSLog(@"鉴权失败，请检查鉴权");
                        break;
                    case QNRTCErrorTokenError:
                        //关于 token 签算规则, 详情请参考【服务端开发说明.RoomToken 签发服务】https://doc.qnsdk.com/rtn/docs/server_overview#1
                        NSLog(@"roomToken 错误");
                        break;
                    case QNRTCErrorTokenExpired:
                        NSLog(@"roomToken 过期");
                        break;
                    case QNRTCErrorReconnectTokenError:
                        NSLog(@"重新进入房间超时，请务必调用 leave, 重新进入房间");
                        break;
                    default:
                        break;
                }
            }
                break;
        }
    }
#endif
}
/**
 * 远端用户加入房间的回调
 */
- (void)RTCClient:(QNRTCClient *)client didJoinOfUserID:(NSString *)userID userData:(NSString *)userData {
    NSString *str = [NSString stringWithFormat:@"远端用户加入房间的回调:userID: %@, userData: %@",  userID, userData];
    NSLog(@"%@", str);
    [_channel invokeMethod:@"onUserJoined" arguments:@{@"remoteUserId":userID,@"userData":userData}];
    
}

/**
 * 远端用户离开房间的回调
 */
- (void)RTCClient:(QNRTCClient *)client didLeaveOfUserID:(NSString *)userID {
    NSString *str = [NSString stringWithFormat:@"远端用户: %@ 离开房间的回调", userID];
    
    
    NSLog(@"%@",str);
    
    [_channel invokeMethod:@"onUserLeft" arguments:@{@"remoteUserId":userID}];
    
}

/**
 * 订阅远端用户成功的回调
 */
- (void)RTCClient:(QNRTCClient *)client didSubscribedRemoteVideoTracks:(NSArray<QNRemoteVideoTrack *> *)videoTracks audioTracks:(NSArray<QNRemoteAudioTrack *> *)audioTracks ofUserID:(NSString *)userID {
    NSString *str = [NSString stringWithFormat:@"订阅远端用户: %@ 成功的回调:\nvideoTracks: %@\naudioTracks: %@", userID, videoTracks,audioTracks];
    
    NSLog(@"%@",str);
    
    NSMutableArray<NSDictionary *> * videoList = [[NSMutableArray alloc] init];
    for(QNRemoteTrack * track in videoTracks)
    {
        [videoList addObject:@{@"trackId":track.trackID,@"tag":track.tag,@"kind":@(track.kind)}];
    }
    
    NSMutableArray<NSDictionary *> * audioList = [[NSMutableArray alloc] init];
    for(QNRemoteTrack * track in audioTracks)
    {
        [audioList addObject:@{@"trackId":track.trackID,@"tag":track.tag,@"kind":@(track.kind)}];
    }
    
    [_channel invokeMethod:@"onSubscribed" arguments:@{@"remoteUserId":userID,@"remoteAudioTracks":videoList,@"remoteVideoTracks":audioList}];
    
}

/**
 * 远端用户发布音/视频的回调
 */
- (void)RTCClient:(QNRTCClient *)client didUserPublishTracks:(NSArray<QNRemoteTrack *> *)tracks ofUserID:(NSString *)userID {
    NSString *str = [NSString stringWithFormat:@"远端用户: %@ 发布成功的回调:\nTracks: %@",  userID, tracks];
    
    NSLog(@"%@",str);
    
    NSMutableArray<NSDictionary *> * tracksArray = [[NSMutableArray alloc] init];
    for(QNRemoteTrack * track in tracks)
    {
        [tracksArray addObject:@{@"trackId":track.trackID,@"tag":track.tag,@"kind":@(track.kind)}];
        [_remoteTracks setObject:track forKey:track.trackID];
    }
    [_channel invokeMethod:@"onUserPublished" arguments:@{@"remoteUserId":userID,@"trackList":tracksArray}];
    
}

/**
 * 远端用户取消发布音/视频的回调
 */
- (void)RTCClient:(QNRTCClient *)client didUserUnpublishTracks:(NSArray<QNRemoteTrack *> *)tracks ofUserID:(NSString *)userID {
    NSString *str = [NSString stringWithFormat:@"远端用户: %@ 取消发布的回调:\nTracks: %@",  userID, tracks];
    
    NSLog(@"%@",str);
    NSMutableArray<NSDictionary *> * tracksArray = [[NSMutableArray alloc] init];
    for(QNRemoteTrack * track in tracks)
    {
        [tracksArray addObject:@{@"trackId":track.trackID,@"tag":track.tag,@"kind":@(track.kind)}];
        [_remoteTracks removeObjectForKey:track.trackID];
    }
    [_channel invokeMethod:@"onUserUnpublished" arguments:@{@"remoteUserId":userID,@"trackList":tracksArray}];
    
}

/**
* 创建转推的回调
*/
- (void)RTCClient:(QNRTCClient *)client didStartLiveStreamingWith:(NSString *)streamID {
    NSString *str = [NSString stringWithFormat:@"创建转推的回调:\nStreamID: %@",  streamID];
    //tobefixed:
//    [self addLogString:str];
}

/**
 * 远端用户视频首帧解码后的回调，如果需要渲染，则调用当前 videoTrack.play(QNVideoView*) 方法
 */
- (void)RTCClient:(QNRTCClient *)client firstVideoDidDecodeOfTrack:(QNRemoteVideoTrack *)videoTrack remoteUserID:(NSString *)userID {
    NSString *str = [NSString stringWithFormat:@"远端用户: %@ trackID: %@ 视频首帧解码后的回调",  userID, videoTrack.trackID];
    
    //tobefixed:
//    [self addLogString:str];
}

/**
 * 远端用户视频取消渲染到 renderView 上的回调
 */
- (void)RTCClient:(QNRTCClient *)client didDetachRenderTrack:(QNRemoteVideoTrack *)videoTrack remoteUserID:(NSString *)userID {
    NSString *str = [NSString stringWithFormat:@"远端用户: %@ trackID: %@ 视频取消渲染到 renderView 上的回调",  userID, videoTrack.trackID];
    //tobefixed:
//    [self addLogString:str];
    
    NSNumber * viewId = [_viewDictionary objectForKey:videoTrack.trackID];
    NSLog(@"viewID:%llu ,%@",[viewId longLongValue],str);
    if(viewId)
        [[FlutterQnrtcEnginePlugin sharedQnrtcPluginlManager] removeSubView:viewId];
    [videoTrack play:nil];
}


/**
* 远端用户发生重连
*/
- (void)RTCClient:(QNRTCClient *)client didReconnectingOfUserID:(NSString *)userID {
    NSString *logStr = [NSString stringWithFormat:@"userId 为 %@ 的远端用户发生了重连！", userID];
    
    NSLog(@"%@", logStr);
    [_channel invokeMethod:@"onUserReconnecting" arguments:@{@"remoteUserId":userID}];
}

/**
* 远端用户重连成功
*/
- (void)RTCClient:(QNRTCClient *)client didReconnectedOfUserID:(NSString *)userID {
    NSString *logStr = [NSString stringWithFormat:@"userId 为 %@ 的远端用户重连成功了！", userID];
    
    NSLog(@"%@", logStr);
    [_channel invokeMethod:@"onUserReconnected" arguments:@{@"remoteUserId":userID}];
}



#pragma mark QNRemoteTrackDelegate

/**
 * 远端用户 Track 状态变更为 muted 的回调
 */
- (void)remoteTrack:(QNRemoteTrack *)remoteTrack didMutedByRemoteUserID:(NSString *)userID {
    NSString *str = [NSString stringWithFormat:@"远端用户: %@ trackId: %@ Track 状态变更为: %d 的回调",  userID, remoteTrack.trackID, remoteTrack.muted];
    
    
    NSLog(@"%@",str);
    
    [_channel invokeMethod:@"onMuteStateChanged" arguments:@{@"trackId":remoteTrack.trackID,@"isMuted":@(remoteTrack.muted)}];
    
}


#pragma mark QNRemoteTrackAudioDataDelegate

/**
 * 远端用户视频数据的回调
 *
 * 注意：回调远端用户视频数据会带来一定的性能消耗，如果没有相关需求，请不要实现该回调
 */
/*
- (void)remoteVideoTrack:(QNRemoteVideoTrack *)remoteVideoTrack didGetPixelBuffer:(CVPixelBufferRef)pixelBuffer; {
    static int i = 0;
    if (i % 300 == 0) {
        NSString *str = [NSString stringWithFormat:@"远端用户视频数据的回调:\ntrackID: %@ size: %zux%zu",remoteVideoTrack.trackID, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer)];
        
        //tobefixed:
//                [self addLogString:str];
    }
    i ++;
    
}
*/

#pragma mark QNRemoteTrackAudioDataDelegate

/**
 * 远端用户音频数据的回调
 *
 * 注意：回调远端用户音频数据会带来一定的性能消耗，如果没有相关需求，请不要实现该回调
 */
- (void)remoteAudioTrack:(QNRemoteAudioTrack *)remoteAudioTrack didGetAudioBuffer:(AudioBuffer *)audioBuffer bitsPerSample:(NSUInteger)bitsPerSample sampleRate:(NSUInteger)sampleRate {
    static int i = 0;
    if (i % 500 == 0) {
        NSString *str = [NSString stringWithFormat:@"远端用户音频数据的回调:\ntrackID: %@\NbufferCount: %d\nbitsPerSample:%lu\nsampleRate:%lu,dataLen = %u",remoteAudioTrack.trackID, i, (unsigned long)bitsPerSample, (unsigned long)sampleRate, (unsigned int)audioBuffer->mDataByteSize];
        
        //tobefixed:
//                [self addLogString:str];
    }
    i ++;
}


#pragma mark QNCameraTrackVideoDataDelegate

/**
 * 获取到摄像头原数据时的回调, 便于开发者做滤镜等处理，需要注意的是这个回调在 camera 数据的输出线程，请不要做过于耗时的操作，否则可能会导致编码帧率下降
 */
- (void)cameraVideoTrack:(QNCameraVideoTrack *)cameraVideoTrack didGetSampleBuffer:(CMSampleBufferRef)sampleBuffer; {
    static int i = 0;
    if (i % 300 == 0) {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        NSString *str = [NSString stringWithFormat:@"获取到摄像头原数据时的回调:\nbufferCount: %d, size = %zux%zu",  i, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer)];
        
        //tobefixed:
        //        [self addLogString:str];
    }
    i ++;
}


#pragma mark QNMicrophoneAudioTrackDataDelegate

/**
 * 获取到麦克风原数据时的回调，需要注意的是这个回调在 AU Remote IO 线程，请不要做过于耗时的操作，否则可能阻塞该线程影响音频输出或其他未知问题
 */
- (void)microphoneAudioTrack:(QNMicrophoneAudioTrack *)microphoneAudioTrack didGetAudioBuffer:(AudioBuffer *)audioBuffer bitsPerSample:(NSUInteger)bitsPerSample sampleRate:(NSUInteger)sampleRate {
    static int i = 0;
    if (i % 500 == 0) {
        NSString *str = [NSString stringWithFormat:@"获取到麦克风原数据时的回调:\nbufferCount: %d, dataLen = %u",  i, (unsigned int)audioBuffer->mDataByteSize];
        
        //tobefixed:
        //        [self addLogString:str];
    }
    i ++;
}


#pragma mark QNAudioMixerDelegate


//QNAudioMixer 在运行过程中，发生错误的回调
- (void)audioMusicMixer:(QNAudioMusicMixer *)audioMusicMixer didFailWithError:(NSError *)error
{
   
        [_channel invokeMethod:@"onAudioMixerError" arguments:@{@"musicPath":_musicPath,@"errorCode":@(error.code)}];
}
//QNAudioMixer 在运行过程中，音频状态发生变化的回调
- (void)audioMusicMixer:(QNAudioMusicMixer *)audioMusicMixer didStateChanged:(QNAudioMusicMixerState)musicMixerState
{
    int resultCode = -1;
    switch(musicMixerState)
    {
        case QNAudioMusicMixerStateMixing:
            resultCode = 0;
            break;
        case QNAudioMusicMixerStatePaused:
            resultCode = 1;
            break;
        case QNAudioMusicMixerStateStopped:
            resultCode = 2;
            break;
        case QNAudioMusicMixerStateCompleted:
            resultCode = 3;
            break;
        default:
            break;
            
    }
    if(resultCode >= 0)
    [_channel invokeMethod:@"onAudioMixerStateChanged" arguments:@{@"musicPath":_musicPath,@"state":@(resultCode)}];
}
//QNAudioMixer 在运行过程中，混音进度的回调
- (void)audioMusicMixer:(QNAudioMusicMixer *)audioMusicMixer didMixing:(int64_t)currentPosition;
{
    NSLog(@"current duration :%@",@(currentPosition));
    [_channel invokeMethod:@"onAudioMixerMixing" arguments:@{@"musicPath":_musicPath,@"current":@((int)(currentPosition * 1000))}];
}

@end

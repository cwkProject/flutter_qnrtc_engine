import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通道事件处理器
class _MethodCallHandler {
  _MethodCallHandler() {
    FlutterQnrtcEngine._channel.setMethodCallHandler(handler);
  }

  /// 通道处理器
  Future<dynamic> handler(MethodCall call) async => inner?.call(call);

  /// 实际关联的内部处理器
  Future<dynamic> Function(MethodCall call)? inner;
}

/// 七牛音视频引擎
class FlutterQnrtcEngine {
  static const MethodChannel _channel = MethodChannel('flutter_qnrtc_engine');

  /// 通道处理器
  static final _MethodCallHandler _handler = _MethodCallHandler();

  /// 初始化音视频组件
  ///
  /// [handler]事件回调处理器
  /// 不使用时必须调用[deinit]释放音视频组件资源
  static Future<void> init(QNRTCSetting rtcSetting,
      QNRTCClientConfig clientConfig, QNEventListener listener) async {
    _handler.inner = listener._handle;
    await _channel.invokeMethod('init', rtcSetting.toMap());
    await _channel.invokeMethod('createClient', clientConfig.toMap());
  }

  /// 销毁音视频组件
  static Future<void> deinit() async {
    _handler.inner = null;
    await _channel.invokeMethod('deinit');
  }

  static Future<QNMicrophoneAudioTrack?> createMicrophoneAudioTrack(
      QNMicrophoneAudioTrackConfig config) async {
    final result = await _channel.invokeMapMethod(
        'createMicrophoneAudioTrack', config.toMap());

    if (result == null) {
      return null;
    }

    return QNMicrophoneAudioTrack(
      trackId: result['trackId'] ?? '',
      tag: result['tag'] ?? '',
      kind: QNTrackKind.values[result['kind']],
    );
  }

  static Future<QNCameraVideoTrack?> createCameraVideoTrack(
      QNCameraVideoTrackConfig config) async {
    final result = await _channel.invokeMapMethod(
        'createCameraVideoTrack', config.toMap());

    if (result == null) {
      return null;
    }

    return QNCameraVideoTrack(
      trackId: result['trackId'] ?? '',
      tag: result['tag'] ?? '',
      kind: QNTrackKind.values[result['kind']],
    );
  }

  static Future<void> setAudioRouteToSpeakerphone(
      bool audioRouteToSpeakerphone) async {
    await _channel.invokeMethod('setAudioRouteToSpeakerphone',
        {'audioRouteToSpeakerphone': audioRouteToSpeakerphone});
  }

  static Future<void> setLogFileEnabled(bool enable) async {
    await _channel.invokeMethod('setLogFileEnabled', {'enable': enable});
  }

  static Future<void> setAutoSubscribe(bool autoSubscribe) async {
    await _channel
        .invokeMethod('setAutoSubscribe', {'autoSubscribe': autoSubscribe});
  }

  static Future<void> join(String token, [String? userData]) async {
    await _channel.invokeMethod('join', {'token': token, 'userData': userData});
  }

  static Future<void> leave() async {
    await _channel.invokeMethod('leave');
  }

  static Future<void> publish(List<QNLocalTrack> trackList) async {
    try {
      await _channel.invokeMethod(
          'publish', trackList.map((e) => e.tag).toList());
    } on PlatformException catch (e) {
      throw 'track publish error ${e.code} , ${e.message}';
    }
  }

  static Future<void> unpublish(List<QNLocalTrack> trackList) async {
    await _channel.invokeMethod(
        'unpublish', trackList.map((e) => e.tag).toList());
  }

  static Future<void> subscribe(List<QNRemoteTrack> trackList) async {
    await _channel.invokeMethod(
        'subscribe', trackList.map((e) => e.trackId).toList());
  }

  static Future<void> unsubscribe(List<QNRemoteTrack> trackList) async {
    await _channel.invokeMethod(
        'unsubscribe', trackList.map((e) => e.trackId).toList());
  }

  static Future<Map<String, QNNetworkQuality>> getUserNetworkQuality() async {
    final result = await _channel.invokeMapMethod('getUserNetworkQuality');

    if (result == null) {
      return const {};
    }

    return result.map((key, value) => MapEntry(
          key,
          QNNetworkQuality.fromMap(value),
        ));
  }

  static Future<void> setClientRole(QNClientRole role) async {
    try {
      await _channel.invokeMethod('setClientRole', {'role': role.index});
    } on PlatformException catch (e) {
      throw 'setClientRole error ${e.code}';
    }
  }

  /// [QNLocalTrack.isMuted]
  static Future<bool> _isLocalTrackMuted(String tag) async {
    final bool? result =
        await _channel.invokeMethod('isLocalTrackMuted', {'tag': tag});
    return result ?? false;
  }

  /// [QNLocalTrack.setMuted]
  static Future<void> _setLocalTrackMuted(String tag, bool muted) async {
    await _channel
        .invokeMethod('setLocalTrackMuted', {'tag': tag, 'muted': muted});
  }

  /// [QNLocalTrack.destroy]
  static Future<void> _localTrackDestroy(String tag) async {
    await _channel.invokeMethod('localTrackDestroy', {'tag': tag});
  }

  /// [QNRemoteTrack.isMuted]
  static Future<bool> _isRemoteTrackMuted(String trackId) async {
    final bool? result =
        await _channel.invokeMethod('isRemoteTrackMuted', {'trackId': trackId});
    return result ?? false;
  }

  /// [QNRemoteTrack.isSubscribed]
  static Future<bool> _isSubscribed(String trackId) async {
    final bool? result = await _channel
        .invokeMethod('isRemoteTrackSubscribed', {'trackId': trackId});
    return result ?? false;
  }

  /// [QNRemoteVideoTrack.play]
  static Future<void> _remoteVideoPlay(String trackId, int? viewId) async {
    await _channel.invokeMethod('remoteVideoPlay', {
      'trackId': trackId,
      'viewId': viewId,
    });
  }

  /// [QNRemoteVideoTrack.setProfile]
  static Future<void> _setRemoteVideoProfile(
      String trackId, QNTrackProfile profile) async {
    await _channel.invokeMethod('setRemoteVideoProfile', {
      'trackId': trackId,
      'profile': profile.index,
    });
  }

  /// [QNRemoteVideoTrack.isMultiProfileEnabled]
  static Future<bool> _isMultiProfileEnabled(String trackId) async {
    final bool? result = await _channel
        .invokeMethod('isMultiProfileEnabled', {'trackId': trackId});
    return result ?? false;
  }

  /// [QNRemoteAudioTrack.getVolume]
  static Future<double> _getRemoteAudioVolume(String trackId) async {
    final double? result = await _channel
        .invokeMethod('getRemoteAudioVolume', {'trackId': trackId});
    return result ?? 1;
  }

  /// [QNRemoteAudioTrack.setVolume]
  static Future<void> _setRemoteAudioVolume(
      String trackId, double volume) async {
    await _channel.invokeMethod('setRemoteAudioVolume', {
      'trackId': trackId,
      'volume': volume,
    });
  }

  /// [QNCameraVideoTrack.play]
  static Future<void> _cameraPlay(String tag, int? viewId) async {
    await _channel.invokeMethod('cameraPlay', {
      'tag': tag,
      'viewId': viewId,
    });
  }

  /// [QNCameraVideoTrack.startCapture]
  static Future<void> _cameraStartCapture(String tag) async {
    await _channel.invokeMethod('cameraStartCapture', {'tag': tag});
  }

  /// [QNCameraVideoTrack.stopCapture]
  static Future<void> _cameraStopCapture(String tag) async {
    await _channel.invokeMethod('cameraStopCapture', {'tag': tag});
  }

  /// [QNCameraVideoTrack.switchCamera]
  ///
  /// 返回是否前摄像头，失败抛出异常
  static Future<bool> _switchCamera(String tag) async {
    try {
      final bool? result =
          await _channel.invokeMethod('switchCamera', {'tag': tag});
      return result ?? true;
    } on PlatformException catch (e) {
      throw 'switchCamera error ${e.message}';
    }
  }

  /// [QNCameraVideoTrack.turnLightOn]
  static Future<bool> _turnLightOn(String tag) async {
    final bool? result =
        await _channel.invokeMethod('turnLightOn', {'tag': tag});
    return result ?? false;
  }

  /// [QNCameraVideoTrack.turnLightOff]
  static Future<bool> _turnLightOff(String tag) async {
    final bool? result =
        await _channel.invokeMethod('turnLightOff', {'tag': tag});
    return result ?? false;
  }

  /// [QNCameraVideoTrack.setExposureCompensation]
  static Future<void> _setExposureCompensation(String tag, int value) async {
    await _channel
        .invokeMethod('setExposureCompensation', {'tag': tag, 'value': value});
  }

  /// [QNCameraVideoTrack.getMaxExposureCompensation]
  static Future<int> _getMaxExposureCompensation(String tag) async {
    final int? result =
        await _channel.invokeMethod('getMaxExposureCompensation', {'tag': tag});
    return result ?? 0;
  }

  /// [QNCameraVideoTrack.getMinExposureCompensation]
  static Future<int> _getMinExposureCompensation(String tag) async {
    final int? result =
        await _channel.invokeMethod('getMinExposureCompensation', {'tag': tag});
    return result ?? 0;
  }

  /// [QNCameraVideoTrack.setMirror]
  static Future<void> _setCameraMirror(String tag, bool mirror) async {
    await _channel
        .invokeMethod('setCameraMirror', {'tag': tag, 'mirror': mirror});
  }

  /// [QNCameraVideoTrack.setPreviewEnabled]
  static Future<void> _setPreviewEnabled(String tag, bool enabled) async {
    await _channel
        .invokeMethod('setPreviewEnabled', {'tag': tag, 'enabled': enabled});
  }

  /// [QNCameraVideoTrack.setBeauty]
  static Future<void> _setBeauty(
      String tag, QNBeautySetting beautySetting) async {
    await _channel
        .invokeMethod('setBeauty', {'tag': tag, ...beautySetting.toMap()});
  }

  /// [QNMicrophoneAudioTrack.setVolume]
  static Future<void> _setMicrophoneVolume(String tag, double volume) async {
    await _channel.invokeMethod('setMicrophoneVolume', {
      'tag': tag,
      'volume': volume,
    });
  }

  /// [QNMicrophoneAudioTrack.createAudioMixer]
  static Future<void> _createAudioMixer(String tag, String musicPath) async {
    await _channel.invokeMethod('createAudioMixer', {
      'tag': tag,
      'musicPath': musicPath,
    });
  }

  /// [QNAudioMixer.start]
  static Future<void> _audioMixerStart(String musicPath) async {
    await _channel.invokeMethod('audioMixerStart', {'musicPath': musicPath});
  }

  /// [QNAudioMixer.stop]
  static Future<void> _audioMixerStop(String musicPath) async {
    await _channel.invokeMethod('audioMixerStop', {'musicPath': musicPath});
  }

  /// [QNAudioMixer.resume]
  static Future<void> _audioMixerResume(String musicPath) async {
    await _channel.invokeMethod('audioMixerResume', {'musicPath': musicPath});
  }

  /// [QNAudioMixer.pause]
  static Future<void> _audioMixerPause(String musicPath) async {
    await _channel.invokeMethod('audioMixerPause', {'musicPath': musicPath});
  }

  /// [QNAudioMixer.getDuration]
  static Future<Duration> _audioMixerGetDuration(String musicPath) async {
    final int? result = await _channel
        .invokeMethod('audioMixerGetDuration', {'musicPath': musicPath});
    return Duration(microseconds: result ?? 0);
  }

  /// [QNAudioMixer.enableEarMonitor]
  static Future<void> _audioMixerEnableEarMonitor(
      String musicPath, bool enable) async {
    await _channel.invokeMethod('audioMixerEnableEarMonitor', {
      'musicPath': musicPath,
      'enable': enable,
    });
  }
}

/// 七牛音视频事件回调集合
class QNEventListener {
  QNEventListener({
    this.onConnectionStateChanged,
    this.onUserJoined,
    this.onUserReconnecting,
    this.onUserReconnected,
    this.onUserLeft,
    this.onUserPublished,
    this.onUserUnpublished,
    this.onSubscribed,
    this.onAudioRouteChanged,
    this.onNetworkQualityNotified,
    this.onVideoProfileChanged,
    this.onMuteStateChanged,
    this.onAudioMixerStateChanged,
    this.onAudioMixerMixing,
    this.onAudioMixerError,
  });

  final void Function(
          QNConnectionState state, int? errorCode, String? errorMessage)?
      onConnectionStateChanged;

  final void Function(String remoteUserId, String? userData)? onUserJoined;

  final void Function(String remoteUserId)? onUserReconnecting;

  final void Function(String remoteUserId)? onUserReconnected;

  final void Function(String remoteUserId)? onUserLeft;

  final void Function(String remoteUserId, List<QNRemoteTrack> trackList)?
      onUserPublished;

  final void Function(String remoteUserId, List<QNRemoteTrack> trackList)?
      onUserUnpublished;

  final void Function(
      String remoteUserID,
      List<QNRemoteAudioTrack> remoteAudioTracks,
      List<QNRemoteVideoTrack> remoteVideoTracks)? onSubscribed;

  final void Function(QNAudioDevice device)? onAudioRouteChanged;

  final void Function(QNNetworkQuality quality)? onNetworkQualityNotified;

  final void Function(String trackId, QNTrackProfile profile)?
      onVideoProfileChanged;

  final void Function(String trackId, bool isMuted)? onMuteStateChanged;

  final void Function(String musicPath, QNAudioMixerState state)?
      onAudioMixerStateChanged;

  final void Function(String musicPath, Duration current)? onAudioMixerMixing;

  final void Function(String musicPath, int errorCode)? onAudioMixerError;

  /// 处理回调事件
  Future<dynamic> _handle(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'onConnectionStateChanged':
        onConnectionStateChanged?.call(
            QNConnectionState.values[arguments['state']],
            arguments['errorCode'],
            arguments['errorMessage']);
        break;
      case 'onUserJoined':
        onUserJoined?.call(arguments['remoteUserId'], arguments['userData']);
        break;
      case 'onUserReconnecting':
        onUserReconnecting?.call(arguments['remoteUserId']);
        break;
      case 'onUserReconnected':
        onUserReconnected?.call(arguments['remoteUserId']);
        break;
      case 'onUserLeft':
        onUserLeft?.call(arguments['remoteUserId']);
        break;
      case 'onUserPublished':
        final List trackList = arguments['trackList'];
        onUserPublished?.call(arguments['remoteUserId'],
            trackList.map((e) => QNRemoteTrack.fromMap(e)).toList());
        break;
      case 'onUserUnpublished':
        final List trackList = arguments['trackList'];
        onUserUnpublished?.call(arguments['remoteUserId'],
            trackList.map((e) => QNRemoteTrack.fromMap(e)).toList());
        break;
      case 'onSubscribed':
        final List remoteAudioTracks = arguments['remoteAudioTracks'];
        final List remoteVideoTracks = arguments['remoteVideoTracks'];
        onSubscribed?.call(
          arguments['remoteUserId'],
          remoteAudioTracks.map((e) => QNRemoteAudioTrack.fromMap(e)).toList(),
          remoteVideoTracks.map((e) => QNRemoteVideoTrack.fromMap(e)).toList(),
        );
        break;
      case 'onAudioRouteChanged':
        onAudioRouteChanged?.call(QNAudioDevice.values[arguments['device']]);
        break;
      case 'onNetworkQualityNotified':
        onNetworkQualityNotified?.call(QNNetworkQuality.fromMap(arguments));
        break;
      case 'onVideoProfileChanged':
        onVideoProfileChanged?.call(
            arguments['trackId'], QNTrackProfile.values[arguments['profile']]);
        break;
      case 'onMuteStateChanged':
        onMuteStateChanged?.call(arguments['trackId'], arguments['isMuted']);
        break;
      case 'onAudioMixerStateChanged':
        onAudioMixerStateChanged?.call(arguments['musicPath'],
            QNAudioMixerState.values[arguments['state']]);
        break;
      case 'onAudioMixerMixing':
        onAudioMixerMixing?.call(arguments['musicPath'],
            Duration(microseconds: arguments['current']));
        break;
      case 'onAudioMixerError':
        onAudioMixerError?.call(arguments['musicPath'], arguments['errorCode']);
        break;
    }
  }
}

/// 摄像头视频采集 Track 的配置类
class QNCameraVideoTrackConfig {
  QNCameraVideoTrackConfig({
    this.tag = 'camera',
    this.cameraFacing = QNCameraFacing.front,
    required this.captureConfig,
    required this.encoderConfig,
    this.multiProfileEnabled = false,
  });

  final String tag;
  final QNCameraFacing cameraFacing;
  final QNVideoCaptureConfig captureConfig;
  final QNVideoEncoderConfig encoderConfig;
  final bool multiProfileEnabled;

  Map<String, dynamic> toMap() => {
        'tag': tag,
        'cameraFacing': cameraFacing.index,
        ...captureConfig.toMap(),
        ...encoderConfig.toMap(),
        'multiProfileEnabled': multiProfileEnabled,
      };
}

/// 视频采集配置类
class QNVideoCaptureConfig {
  QNVideoCaptureConfig({
    required this.width,
    required this.height,
    required this.frameRate,
  });

  final int width;
  final int height;
  final int frameRate;

  Map<String, dynamic> toMap() => {
        'captureWidth': width,
        'captureHeight': height,
        'captureFrameRate': frameRate,
      };
}

class QNVideoEncoderConfig {
  QNVideoEncoderConfig({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrate,
  });

  final int width;
  final int height;
  final int frameRate;
  final int bitrate;

  Map<String, dynamic> toMap() => {
        'encoderWidth': width,
        'encoderHeight': height,
        'encoderFrameRate': frameRate,
        'encoderBitrate': bitrate,
      };
}

/// 麦克风音频采集 Track 的配置类
class QNMicrophoneAudioTrackConfig {
  QNMicrophoneAudioTrackConfig({
    this.tag = 'microphone',
    required this.audioQuality,
    this.communicationModeOn = true,
  });

  final String tag;

  final QNAudioQuality audioQuality;

  final bool communicationModeOn;

  Map<String, dynamic> toMap() => {
        'tag': tag,
        'communicationModeOn': communicationModeOn,
        ...audioQuality.toMap(),
      };
}

/// 描述音频质量的配置类
class QNAudioQuality {
  QNAudioQuality({
    required this.sampleRate,
    required this.channelCount,
    required this.bitsPerSample,
    required this.bitrate,
  });

  final int sampleRate;
  final int channelCount;
  final int bitsPerSample;
  final int bitrate;

  Map<String, dynamic> toMap() => {
        'sampleRate': sampleRate,
        'channelCount': channelCount,
        'bitsPerSample': bitsPerSample,
        'bitrate': bitrate,
      };
}

/// SDK 的核心参数配置接口类
class QNRTCSetting {
  QNRTCSetting({
    this.HWCodecEnabled,
    this.maintainResolution,
    this.fieldTrials,
    this.transportPolicy,
    this.encoderQualityMode,
    this.logLevel,
    this.AEC3Enabled,
    this.defaultAudioRouteToSpeakerphone,
  });

  final bool? HWCodecEnabled;

  final bool? maintainResolution;

  final String? fieldTrials;

  final TransportPolicy? transportPolicy;

  final bool? encoderQualityMode;

  final QNLogLevel? logLevel;

  final bool? AEC3Enabled;

  final bool? defaultAudioRouteToSpeakerphone;

  Map<String, dynamic> toMap() => {
        if (HWCodecEnabled != null) 'HWCodecEnabled': HWCodecEnabled,
        if (maintainResolution != null)
          'maintainResolution': maintainResolution,
        if (fieldTrials != null) 'fieldTrials': fieldTrials,
        if (transportPolicy != null) 'transportPolicy': transportPolicy!.index,
        if (encoderQualityMode != null)
          'encoderQualityMode': encoderQualityMode,
        if (logLevel != null)
          'logLevel': Platform.isIOS && logLevel == QNLogLevel.error
              ? QNLogLevel.warning.index
              : logLevel!.index,
        if (AEC3Enabled != null) 'AEC3Enabled': AEC3Enabled,
        if (defaultAudioRouteToSpeakerphone != null)
          'defaultAudioRouteToSpeakerphone': defaultAudioRouteToSpeakerphone,
      };
}

/// QNRTCClient 创建配置类
class QNRTCClientConfig {
  QNRTCClientConfig({
    this.mode = QNClientMode.rtc,
    this.role = QNClientRole.broadcaster,
  });

  final QNClientMode mode;

  final QNClientRole role;

  Map<String, dynamic> toMap() => {
        'mode': mode.index,
        'role': role.index,
      };
}

/// 使用场景
enum QNClientMode {
  rtc,
  live,
}

/// 角色类型
enum QNClientRole {
  broadcaster,
  audience,
}

/// 描述日志等级的枚举类
enum QNLogLevel {
  verbose,
  info,
  warning,
  error,
  none,
}

/// 传输模式
enum TransportPolicy {
  forceUdp,
  forceTcp,
  preferUdp,
}

/// 七牛连接状态枚举
enum QNConnectionState {
  /// 断开连接
  disconnected,

  /// 正在连接
  connecting,

  /// 连接成功
  connected,

  /// 正在重连
  reconnecting,

  /// 重连成功
  reconnected,
}

/// 音频设备类型
enum QNAudioDevice {
  speakerPhone,
  earpiece,
  wiredHeadset,
  bluetooth,
  none,
}

/// Track 质量等级
enum QNTrackProfile {
  low,
  medium,
  high,
}

/// 描述摄像头朝向的枚举类
enum QNCameraFacing {
  back,
  front,
}

/// 内置美颜参数设置类
class QNBeautySetting {
  QNBeautySetting({
    this.enabled = true,
    this.smooth = 0.5,
    this.whiten = 0.5,
    this.redden = 0.1,
  });

  final bool enabled;

  final double smooth;

  final double whiten;

  final double redden;

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'smooth': smooth,
        'whiten': whiten,
        'redden': redden,
      };
}

/// 网络上下行质量
class QNNetworkQuality {
  QNNetworkQuality(
    this.uplinkNetworkGrade,
    this.downlinkNetworkGrade,
  );

  factory QNNetworkQuality.fromMap(Map<dynamic, dynamic> quality) =>
      QNNetworkQuality(
        QNNetworkGrade.values[quality['uplinkNetworkGrade']],
        QNNetworkGrade.values[quality['downlinkNetworkGrade']],
      );

  final QNNetworkGrade uplinkNetworkGrade;
  final QNNetworkGrade downlinkNetworkGrade;
}

/// 网络状态
enum QNNetworkGrade {
  invalid,
  excellent,
  good,
  fair,
  poor,
}

/// Track 的类型
enum QNTrackKind {
  audio,
  video,
}

/// 音视频 Track 基类
abstract class QNTrack {
  QNTrack({
    required this.trackId,
    required this.tag,
    required this.kind,
  });

  final String trackId;

  final String tag;

  final QNTrackKind kind;

  Future<bool> get isMuted;

  @override
  String toString() {
    return '$runtimeType{trackId: $trackId, tag: $tag, kind: $kind}';
  }
}

/// 音视频远端 Track 基类
abstract class QNRemoteTrack extends QNTrack {
  QNRemoteTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );

  factory QNRemoteTrack.fromMap(Map<dynamic, dynamic> track) =>
      track['kind'] == QNTrackKind.audio.index
          ? QNRemoteAudioTrack.fromMap(track)
          : QNRemoteVideoTrack.fromMap(track);

  @override
  Future<bool> get isMuted => FlutterQnrtcEngine._isRemoteTrackMuted(trackId);

  Future<bool> get isSubscribed => FlutterQnrtcEngine._isSubscribed(trackId);
}

/// 视频远端 Track 类
class QNRemoteVideoTrack extends QNRemoteTrack {
  QNRemoteVideoTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );

  factory QNRemoteVideoTrack.fromMap(Map<dynamic, dynamic> track) =>
      QNRemoteVideoTrack(
        trackId: track['trackId'],
        tag: track['tag'],
        kind: QNTrackKind.video,
      );

  Future<void> setProfile(QNTrackProfile profile) =>
      FlutterQnrtcEngine._setRemoteVideoProfile(trackId, profile);

  Future<bool> get isMultiProfileEnabled =>
      FlutterQnrtcEngine._isMultiProfileEnabled(trackId);
}

/// 音频远端 Track 类
class QNRemoteAudioTrack extends QNRemoteTrack {
  QNRemoteAudioTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );

  factory QNRemoteAudioTrack.fromMap(Map<dynamic, dynamic> track) =>
      QNRemoteAudioTrack(
        trackId: track['trackId'],
        tag: track['tag'],
        kind: QNTrackKind.audio,
      );

  Future<double> getVolume() =>
      FlutterQnrtcEngine._getRemoteAudioVolume(trackId);

  Future<void> setVolume(double value) =>
      FlutterQnrtcEngine._setRemoteAudioVolume(trackId, value);
}

abstract class QNLocalTrack extends QNTrack {
  QNLocalTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );

  @override
  Future<bool> get isMuted => FlutterQnrtcEngine._isLocalTrackMuted(tag);

  Future<void> setMuted(bool muted) =>
      FlutterQnrtcEngine._setLocalTrackMuted(tag, muted);

  Future<void> destroy() => FlutterQnrtcEngine._localTrackDestroy(tag);
}

/// 本地视频 Track 基类
abstract class QNLocalVideoTrack extends QNLocalTrack {
  QNLocalVideoTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );
}

/// 本地音频 Track 基类
abstract class QNLocalAudioTrack extends QNLocalTrack {
  QNLocalAudioTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );
}

/// 本地视频相机 Track 类
class QNCameraVideoTrack extends QNLocalVideoTrack {
  QNCameraVideoTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );

  Future<void> startCapture() => FlutterQnrtcEngine._cameraStartCapture(tag);

  Future<void> stopCapture() => FlutterQnrtcEngine._cameraStopCapture(tag);

  /// 切换前后摄像头
  ///
  /// 返回是否前摄像头，失败抛出异常
  Future<bool> switchCamera() => FlutterQnrtcEngine._switchCamera(tag);

  Future<bool> turnLightOn() => FlutterQnrtcEngine._turnLightOn(tag);

  Future<bool> turnLightOff() => FlutterQnrtcEngine._turnLightOff(tag);

  Future<void> setExposureCompensation(int value) =>
      FlutterQnrtcEngine._setExposureCompensation(tag, value);

  Future<int> getMaxExposureCompensation() =>
      FlutterQnrtcEngine._getMaxExposureCompensation(tag);

  Future<int> getMinExposureCompensation() =>
      FlutterQnrtcEngine._getMinExposureCompensation(tag);

  Future<void> setMirror(bool mirror) =>
      FlutterQnrtcEngine._setCameraMirror(tag, mirror);

  Future<void> setPreviewEnabled(bool enabled) =>
      FlutterQnrtcEngine._setPreviewEnabled(tag, enabled);

  Future<void> setBeauty(QNBeautySetting beautySetting) =>
      FlutterQnrtcEngine._setBeauty(tag, beautySetting);
}

/// 本地音频麦克风 Track 类
class QNMicrophoneAudioTrack extends QNLocalAudioTrack {
  QNMicrophoneAudioTrack({
    required String trackId,
    required String tag,
    required QNTrackKind kind,
  }) : super(
          trackId: trackId,
          tag: tag,
          kind: kind,
        );

  Future<void> setVolume(double value) =>
      FlutterQnrtcEngine._setMicrophoneVolume(tag, value);

  Future<QNAudioMixer> createAudioMixer(String musicPath) async {
    await FlutterQnrtcEngine._createAudioMixer(tag, musicPath);
    return QNAudioMixer(musicPath);
  }
}

/// 混音控制类
class QNAudioMixer {
  QNAudioMixer(this.musicPath);

  final String musicPath;

  Future<void> start() => FlutterQnrtcEngine._audioMixerStart(musicPath);

  Future<void> stop() => FlutterQnrtcEngine._audioMixerStop(musicPath);

  Future<void> resume() => FlutterQnrtcEngine._audioMixerResume(musicPath);

  Future<void> pause() => FlutterQnrtcEngine._audioMixerPause(musicPath);

  Future<Duration> getDuration() =>
      FlutterQnrtcEngine._audioMixerGetDuration(musicPath);

  Future<void> enableEarMonitor(bool enable) =>
      FlutterQnrtcEngine._audioMixerEnableEarMonitor(musicPath, enable);
}

/// 混音操作相关的状态
enum QNAudioMixerState {
  mixing,
  paused,
  stopped,
  completed,
}

/// 渲染视图
class QNRenderWidget extends StatefulWidget {
  QNRenderWidget({Key? key, required this.track})
      : assert(track.value.kind == QNTrackKind.video),
        super(key: key);

  /// 绑定的视频track
  final ValueListenable<QNTrack> track;

  @override
  State<StatefulWidget> createState() => QNRenderWidgetState();
}

class QNRenderWidgetState extends State<QNRenderWidget> {
  /// 原生组件id
  int? _viewId;

  /// 绑定用户和原生控件
  Future<void> _bindView() async {
    if (_viewId == null) {
      return;
    }

    final track = widget.track.value;
    if (track is QNRemoteVideoTrack) {
      await FlutterQnrtcEngine.subscribe([track]);
      await FlutterQnrtcEngine._remoteVideoPlay(track.trackId, _viewId);
    } else {
      await FlutterQnrtcEngine._cameraPlay(track.tag, _viewId);
    }
  }

  /// 解绑旧用户
  Future<void> _unbindView(ValueListenable<QNTrack> old) async {
    old.removeListener(_bindView);
    final track = old.value;
    if (track is QNRemoteVideoTrack) {
      await FlutterQnrtcEngine.unsubscribe([track]);
    } else {
      await FlutterQnrtcEngine._cameraPlay(track.tag, null);
    }
  }

  /// 平台原生控件创建完成回调
  ///
  /// [viewId]控件id
  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    _bindView();
  }

  @override
  void initState() {
    super.initState();
    widget.track.addListener(_bindView);
  }

  @override
  void didUpdateWidget(QNRenderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.track != widget.track) {
      _unbindView(oldWidget.track).then((_) {
        if (oldWidget.track.value is QNRemoteVideoTrack &&
            widget.track.value is QNRemoteVideoTrack) {
          _bindView();
        } else if (oldWidget.track.value is! QNRemoteVideoTrack &&
            widget.track.value is! QNRemoteVideoTrack) {
          _bindView();
        }
      });
      widget.track.addListener(_bindView);
    }
  }

  @override
  void dispose() {
    _unbindView(widget.track);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Platform.isIOS
      ? UiKitView(
          viewType: 'QNVideoGLView',
          onPlatformViewCreated: _onPlatformViewCreated,
        )
      : AndroidView(
          viewType: 'QNTextureView',
          onPlatformViewCreated: _onPlatformViewCreated,
        );
}

import 'package:flutter/material.dart';
import 'package:flutter_qnrtc_engine/flutter_qnrtc_engine.dart';

const _tag = 'rtc_example';

const _token =
// '9w2nFNB2AGF3oAuny042uIaSmP069RfBoCTd6aW-:ORYVfI8IxCD1_pAyDqdyYpy9gLI=:eyJhcHBJZCI6ImdjNG5qNTIwbiIsImV4cGlyZUF0IjoxNjUwNTI3NzMxLCJwZXJtaXNzaW9uIjoidXNlciIsInJvb21OYW1lIjoiMDY3YmI3OTBhNDA0NDA5MGJkYmFiYmVjMzYyODcyNzAiLCJ1c2VySWQiOiI4ZDQ0OWQyOS03YzUwLTRhOTAtOWI4Mi03N2ZlY2JhMDIyYWUifQ==';
    '9w2nFNB2AGF3oAuny042uIaSmP069RfBoCTd6aW-:qmqvv_3rt3tSu6qxCuR50LPM6_A=:eyJhcHBJZCI6ImdjNG5qNTIwbiIsImV4cGlyZUF0IjoxNjUwOTQyNDU1LCJwZXJtaXNzaW9uIjoidXNlciIsInJvb21OYW1lIjoiMDY3YmI3OTBhNDA0NDA5MGJkYmFiYmVjMzYyODcyNzAiLCJ1c2VySWQiOiIzOTVjZWZjOS0xNzVmLTQ4ZjItOGExMC03M2VkZDMzOTcyZTYifQ==';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ValueNotifier<QNCameraVideoTrack>? _cameraVideoTrack;

  QNMicrophoneAudioTrack? _microphoneAudioTrack;

  final _remoteVideoTracks = <ValueNotifier<QNRemoteVideoTrack>>[];

  bool _isBeauty = false;

  bool _isVideoLow = true;

  @override
  void initState() {
    super.initState();
    _initRtc();
  }

  @override
  void dispose() {
    _cameraVideoTrack?.value.destroy();
    _microphoneAudioTrack?.destroy();
    FlutterQnrtcEngine.leave();
    FlutterQnrtcEngine.deinit();
    super.dispose();
  }

  Future<void> _initRtc() async {
    await FlutterQnrtcEngine.init(
      QNRTCSetting(),
      QNRTCClientConfig(mode: QNClientMode.rtc, role: QNClientRole.broadcaster),
      QNEventListener(
        onConnectionStateChanged: (state, errorCode) async {
          debugPrint('$_tag onConnectionStateChanged $state $errorCode');
          if (state == QNConnectionState.connected) {
            await _createVideoTrack();
            try {
              await FlutterQnrtcEngine.publish(
                  [_cameraVideoTrack!.value, _microphoneAudioTrack!]);
              debugPrint('$_tag local published');
            } catch (e) {
              debugPrint('$e');
            }
            setState(() {});
          }
        },
        onUserJoined: (remoteUserId, userData) {
          debugPrint('$_tag onUserJoined $remoteUserId');
        },
        onUserLeft: (remoteUserId) {
          debugPrint('$_tag onUserLeft $remoteUserId');
        },
        onUserPublished: (remoteUserId, trackList) {
          debugPrint(
              '$_tag onUserPublished $remoteUserId ${trackList.map((e) => e.kind)}');
          for (final track in trackList) {
            if (track.kind == QNTrackKind.audio) {
              FlutterQnrtcEngine.subscribe([track]);
            } else {
              _remoteVideoTracks
                  .add(ValueNotifier(track as QNRemoteVideoTrack));
            }
          }
        },
        onUserUnpublished: (remoteUserId, trackList) {
          debugPrint(
              '$_tag onUserUnpublished $remoteUserId ${trackList.map((e) => e.kind)}');
          _remoteVideoTracks.removeWhere(
              (a) => trackList.any((b) => b.trackId == a.value.trackId));
        },
        onSubscribed: (remoteUserId, remoteAudioTracks, remoteVideoTracks) {
          debugPrint(
              '$_tag onSubscribed $remoteUserId ${remoteAudioTracks.length}, ${remoteVideoTracks.length}');
        },
        onNetworkQualityNotified: (quality) {
          debugPrint('$_tag onNetworkQualityNotified ${[
            quality.uplinkNetworkGrade,
            quality.downlinkNetworkGrade,
          ]}');
        },
      ),
    );

    await FlutterQnrtcEngine.setAutoSubscribe(false);

    _microphoneAudioTrack = await FlutterQnrtcEngine.createMicrophoneAudioTrack(
      QNMicrophoneAudioTrackConfig(
        audioQuality: QNAudioQuality(
          sampleRate: 48000,
          channelCount: 2,
          bitsPerSample: 16,
          bitrate: 80,
        ),
      ),
    );

    await FlutterQnrtcEngine.join(_token);
    setState(() {});
  }

  Future<void> _createVideoTrack() async {
    final vTrack =
        await FlutterQnrtcEngine.createCameraVideoTrack(_createVideoConfig());

    if (vTrack != null) {
      _cameraVideoTrack = ValueNotifier(vTrack);
    }
  }

  QNCameraVideoTrackConfig _createVideoConfig() {
    int width;
    int height;
    int frameRate;
    int bitrate;

    if (_isVideoLow) {
      width = 320;
      height = 240;
      frameRate = 20;
      bitrate = 300;
    } else {
      width = 640;
      height = 480;
      frameRate = 20;
      bitrate = 800;
    }

    return QNCameraVideoTrackConfig(
      captureConfig: QNVideoCaptureConfig(
        width: width,
        height: height,
        frameRate: frameRate,
      ),
      encoderConfig: QNVideoEncoderConfig(
        width: width,
        height: height,
        frameRate: frameRate,
        bitrate: bitrate,
      ),
    );
  }

  Future<void> _switchClarity() async {
    _isVideoLow = !_isVideoLow;

    await FlutterQnrtcEngine.unpublish([_cameraVideoTrack!.value]);
    await _cameraVideoTrack!.value.destroy();

    final vTrack =
        await FlutterQnrtcEngine.createCameraVideoTrack(_createVideoConfig());

    if (vTrack == null) {
      throw '_switchClarity failed';
    }

    await FlutterQnrtcEngine.publish([vTrack]);

    _cameraVideoTrack?.value = vTrack;

    setState(() {});
  }

  Widget get _localRender {
    Widget result = QNRenderWidget(
      key: const ValueKey('localCamera'),
      track: _cameraVideoTrack!,
    );

    result = Stack(
      children: [
        result,
        Align(
          alignment: Alignment.bottomLeft,
          child: IconButton(
            icon: const Icon(Icons.switch_camera_outlined),
            color: Colors.yellow,
            onPressed: () {
              _cameraVideoTrack?.value.switchCamera();
            },
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            color: _isBeauty ? Colors.green : Colors.grey,
            onPressed: () async {
              await _cameraVideoTrack?.value.setBeauty(QNBeautySetting(
                  enabled: !_isBeauty, smooth: 0.5, whiten: 0.5, redden: 0.5));
              setState(() {
                _isBeauty = !_isBeauty;
              });
            },
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(Icons.hd),
            color: _isVideoLow ? Colors.grey : Colors.green,
            onPressed: () {
              _switchClarity();
            },
          ),
        ),
      ],
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('七牛插件示例')),
        body: GridView.count(
          crossAxisCount: 3,
          children: [
            if (_cameraVideoTrack != null) _localRender,
            for (final track in _remoteVideoTracks)
              QNRenderWidget(key: ValueKey(track.value.trackId), track: track),
          ],
        ),
      ),
    );
  }
}

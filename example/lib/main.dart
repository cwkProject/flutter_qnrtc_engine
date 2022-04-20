import 'package:flutter/material.dart';
import 'package:flutter_qnrtc_engine/flutter_qnrtc_engine.dart';

const _tag = 'rtc_example';

const _token =
    // '9w2nFNB2AGF3oAuny042uIaSmP069RfBoCTd6aW-:ORYVfI8IxCD1_pAyDqdyYpy9gLI=:eyJhcHBJZCI6ImdjNG5qNTIwbiIsImV4cGlyZUF0IjoxNjUwNTI3NzMxLCJwZXJtaXNzaW9uIjoidXNlciIsInJvb21OYW1lIjoiMDY3YmI3OTBhNDA0NDA5MGJkYmFiYmVjMzYyODcyNzAiLCJ1c2VySWQiOiI4ZDQ0OWQyOS03YzUwLTRhOTAtOWI4Mi03N2ZlY2JhMDIyYWUifQ==';
     '9w2nFNB2AGF3oAuny042uIaSmP069RfBoCTd6aW-:-WPKr1YKHZO7vDlzdKrn5yZLKg4=:eyJhcHBJZCI6ImdjNG5qNTIwbiIsImV4cGlyZUF0IjoxNjUwNTI3NDUwLCJwZXJtaXNzaW9uIjoidXNlciIsInJvb21OYW1lIjoiMDY3YmI3OTBhNDA0NDA5MGJkYmFiYmVjMzYyODcyNzAiLCJ1c2VySWQiOiIwOGMwNjUwNS1kZjJlLTRjMDctYjFlMy0yNzc3M2QxYzJjYmYifQ==';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  QNCameraVideoTrack? _cameraVideoTrack;

  QNMicrophoneAudioTrack? _microphoneAudioTrack;

  final _remoteVideoTracks = <QNRemoteVideoTrack>[];

  bool _isBeauty = false;

  @override
  void initState() {
    super.initState();
    _initRtc();
  }

  @override
  void dispose() {
    _cameraVideoTrack?.destroy();
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
          debugPrint('$_tag onConnectionStateChanged $state');
          if (state == QNConnectionState.connected) {
            try {
              await FlutterQnrtcEngine.publish(
                  [_cameraVideoTrack!, _microphoneAudioTrack!]);
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
          FlutterQnrtcEngine.subscribe(trackList);
        },
        onUserUnpublished: (remoteUserId, trackList) {
          debugPrint(
              '$_tag onUserUnpublished $remoteUserId ${trackList.map((e) => e.kind)}');
          _remoteVideoTracks
              .removeWhere((a) => trackList.any((b) => b.trackId == a.trackId));
        },
        onSubscribed: (remoteUserId, remoteAudioTracks, remoteVideoTracks) {
          debugPrint(
              '$_tag onSubscribed $remoteUserId ${remoteAudioTracks.length}, ${remoteVideoTracks.length}');
          _remoteVideoTracks.addAll(remoteVideoTracks);
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

    _cameraVideoTrack = await FlutterQnrtcEngine.createCameraVideoTrack(
        QNCameraVideoTrackConfig(
      captureConfig: QNVideoCaptureConfig(
        width: 640,
        height: 480,
        frameRate: 30,
      ),
      encoderConfig: QNVideoEncoderConfig(
        width: 640,
        height: 480,
        frameRate: 20,
        bitrate: 800,
      ),
    ));

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
              _cameraVideoTrack?.switchCamera();
            },
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            color: _isBeauty ? Colors.green : Colors.grey,
            onPressed: () async {
              await _cameraVideoTrack?.setBeauty(QNBeautySetting(
                  enabled: !_isBeauty, smooth: 0.5, whiten: 0.5, redden: 0.5));
              setState(() {
                _isBeauty = !_isBeauty;
              });
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
              QNRenderWidget(key: ValueKey(track.trackId), track: track),
          ],
        ),
      ),
    );
  }
}

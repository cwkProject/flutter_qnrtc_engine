import 'package:flutter/material.dart';
import 'package:flutter_qnrtc_engine/flutter_qnrtc_engine.dart';

const _tag = 'rtc_example';

const _token1 =
    '9w2nFNB2AGF3oAuny042uIaSmP069RfBoCTd6aW-:z-n3Hd23QRGSyYZ8aDjxSZ5gWJw=:eyJhcHBJZCI6ImdjNG5qNTIwbiIsImV4cGlyZUF0IjoxNjUyMzQwMTA4LCJwZXJtaXNzaW9uIjoidXNlciIsInJvb21OYW1lIjoiNGU2MzY1OGQzNTM0NGMyMjk2YjI5MDU2ZjVjMWZlODkiLCJ1c2VySWQiOiJlMDk4MmQyNy1iNTgwLTQ4N2QtYTYzNS0zZDY0MzA0OTRkYjQifQ==';

const _token2 =
    '9w2nFNB2AGF3oAuny042uIaSmP069RfBoCTd6aW-:i5FPfUMlH4NuM0MFzLvvsgAnNpU=:eyJhcHBJZCI6ImdjNG5qNTIwbiIsImV4cGlyZUF0IjoxNjUyMzQwMTc2LCJwZXJtaXNzaW9uIjoidXNlciIsInJvb21OYW1lIjoiNGU2MzY1OGQzNTM0NGMyMjk2YjI5MDU2ZjVjMWZlODkiLCJ1c2VySWQiOiJhMzBlMWExMi02YTUwLTQ2N2UtYTdiYi04OWIwYjY2OTdkY2YifQ==';

String get token => _token2;

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

  bool _isPublished = true;

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
        onConnectionStateChanged: (state, errorCode, errorMessage) async {
          debugPrint(
              '$_tag onConnectionStateChanged $state $errorCode $errorMessage');
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
              setState(() {
                _remoteVideoTracks
                    .add(ValueNotifier(track as QNRemoteVideoTrack));
              });
            }
          }
        },
        onUserUnpublished: (remoteUserId, trackList) {
          debugPrint(
              '$_tag onUserUnpublished $remoteUserId ${trackList.map((e) => e.kind)}');
          setState(() {
            _remoteVideoTracks.removeWhere(
                (a) => trackList.any((b) => b.trackId == a.value.trackId));
          });
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

    await FlutterQnrtcEngine.join(token);
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

  Future<void> _switchPublished() async {
    if (_isPublished) {
      await FlutterQnrtcEngine.unpublish([_cameraVideoTrack!.value]);
      await _cameraVideoTrack!.value.destroy();
    } else {
      final vTrack =
          await FlutterQnrtcEngine.createCameraVideoTrack(_createVideoConfig());

      if (vTrack != null) {
        _cameraVideoTrack!.value = vTrack;
      }

      await FlutterQnrtcEngine.publish([_cameraVideoTrack!.value]);
    }

    setState(() {
      _isPublished = !_isPublished;
    });
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
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: _isPublished
                ? const Icon(Icons.videocam)
                : const Icon(Icons.videocam_off),
            color: !_isPublished ? Colors.blueGrey : Colors.green,
            onPressed: () {
              _switchPublished();
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

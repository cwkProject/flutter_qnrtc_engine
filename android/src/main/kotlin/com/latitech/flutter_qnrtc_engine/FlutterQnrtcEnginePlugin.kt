package com.latitech.flutter_qnrtc_engine

import android.content.Context
import android.os.Handler
import androidx.annotation.NonNull
import com.qiniu.droid.rtc.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec

/**
 * 七牛音视频插件
 */
class FlutterQnrtcEnginePlugin : FlutterPlugin, MethodCallHandler {

    /**
     * 插件通道
     */
    private lateinit var channel: MethodChannel

    /**
     * Android上下文
     */
    private lateinit var context: Context

    /**
     * 主线程执行器
     */
    private lateinit var handler: Handler

    /**
     * 音视频客户端
     */
    private var rtcClient: QNRTCClient? = null

    /**
     * 本地麦克风音轨
     */
    private var microphone: QNMicrophoneAudioTrack? = null

    /**
     * 本地相机
     */
    private var camera: QNCameraVideoTrack? = null

    /**
     * 本地track <tag,track>映射
     */
    private val localTracks = mutableMapOf<String, QNLocalTrack>()

    /**
     * 远端track <trackId,track>映射
     */
    private val remoteTracks = mutableMapOf<String, QNRemoteTrack>()

    /**
     * 混音器 <musicPath,QNAudioMixer>映射
     */
    private val audioMixers = mutableMapOf<String, QNAudioMixer>()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_qnrtc_engine")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        handler = Handler(context.mainLooper)
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "QNTextureView", QNRenderViewFactory(StandardMessageCodec.INSTANCE)
        )
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "init" -> QNRTC.init(context, QNRTCSetting().apply {
                when {
                    call.hasArgument("HWCodecEnabled") -> isHWCodecEnabled =
                        call.argument("HWCodecEnabled")!!
                    call.hasArgument("maintainResolution") -> isMaintainResolution =
                        call.argument("maintainResolution")!!
                    call.hasArgument("fieldTrials") -> fieldTrials = call.argument("fieldTrials")!!
                    call.hasArgument("transportPolicy") -> transportPolicy =
                        QNRTCSetting.TransportPolicy.values()[call.argument("transportPolicy")!!]
                    call.hasArgument("encoderQualityMode") -> isEncoderQualityMode =
                        call.argument("encoderQualityMode")!!
                    call.hasArgument("AEC3Enabled") -> isAEC3Enabled =
                        call.argument("AEC3Enabled")!!
                    call.hasArgument("defaultAudioRouteToSpeakerphone") -> isDefaultAudioRouteToSpeakerphone =
                        call.argument("defaultAudioRouteToSpeakerphone")!!
                    call.hasArgument("logLevel") -> logLevel =
                        QNLogLevel.values()[call.argument("logLevel")!!]
                }
            }) {
                channel.postInvoke(
                    "onAudioRouteChanged", mapOf(
                        "device" to it.ordinal,
                    )
                )
            }
            "deinit" -> {
                rtcClient = null
                QNRTC.deinit()
            }
            "createClient" -> rtcClient = QNRTC.createClient(QNRTCClientConfig().apply {
                mode = QNClientMode.values()[call.argument("mode")!!]
                role = QNClientRole.values()[call.argument("role")!!]
            }, ClientEventListener()).also {
                it.setNetworkQualityListener { q ->
                    channel.postInvoke(
                        "onNetworkQualityNotified", mapOf(
                            "uplinkNetworkGrade" to q.uplinkNetworkGrade.ordinal,
                            "downlinkNetworkGrade" to q.downlinkNetworkGrade.ordinal,
                        )
                    )
                }
            }
            "createMicrophoneAudioTrack" -> QNRTC.createMicrophoneAudioTrack(
                QNMicrophoneAudioTrackConfig(call.argument("tag")).apply {
                    isCommunicationModeOn = call.argument("communicationModeOn")!!
                    audioQuality = QNAudioQuality(
                        call.argument("sampleRate")!!,
                        call.argument("channelCount")!!,
                        call.argument("bitsPerSample")!!,
                        call.argument("bitrate")!!,
                    )
                })?.let {
                microphone = it
                localTracks[it.tag] = it
                result.success(
                    mapOf(
                        "trackId" to it.trackID,
                        "tag" to it.tag,
                        "kind" to 0,
                    )
                )
                return
            }
            "createCameraVideoTrack" -> QNRTC.createCameraVideoTrack(
                QNCameraVideoTrackConfig(call.argument("tag")).apply {
                    cameraFacing = QNCameraFacing.values()[call.argument("cameraFacing")!!]
                    isMultiProfileEnabled = call.argument("multiProfileEnabled")!!
                    videoCaptureConfig = QNVideoCaptureConfig(
                        call.argument("captureWidth")!!,
                        call.argument("captureHeight")!!,
                        call.argument("captureFrameRate")!!
                    )
                    videoEncoderConfig = QNVideoEncoderConfig(
                        call.argument("encoderWidth")!!,
                        call.argument("encoderHeight")!!,
                        call.argument("encoderFrameRate")!!,
                        call.argument("encoderBitrate")!!
                    )
                })?.also {
                camera = it
                localTracks[it.tag] = it
                result.success(
                    mapOf(
                        "trackId" to it.trackID,
                        "tag" to it.tag,
                        "kind" to 1,
                    )
                )
                return
            }
            "setAudioRouteToSpeakerphone" -> QNRTC.setAudioRouteToSpeakerphone(call.argument("audioRouteToSpeakerphone")!!)
            "setLogFileEnabled" -> QNRTC.setLogFileEnabled(call.argument("enable")!!)
            "setAutoSubscribe" -> rtcClient?.setAutoSubscribe(call.argument("autoSubscribe")!!)
            "join" -> rtcClient?.join(call.argument("token"), call.argument("userData"))
            "leave" -> {
                rtcClient?.leave()
                remoteTracks.clear()
            }
            "publish" -> {
                rtcClient?.publish(
                    object : QNPublishResultCallback {
                        override fun onPublished() {
                            result.postSuccess()
                        }

                        override fun onError(p0: Int, p1: String?) {
                            result.postError("$p0", p1)
                        }
                    }, call.arguments<List<String>>().mapNotNull { localTracks[it] }
                )?.also {
                    return
                }
            }
            "unpublish" -> rtcClient?.unpublish(
                call.arguments<List<String>>().mapNotNull { localTracks[it] })
            "subscribe" -> rtcClient?.subscribe(
                call.arguments<List<String>>().mapNotNull { remoteTracks[it] })
            "unsubscribe" -> rtcClient?.unsubscribe(
                call.arguments<List<String>>().mapNotNull { remoteTracks[it] })
            "getUserNetworkQuality" -> rtcClient?.userNetworkQuality?.mapValues {
                mapOf(
                    "uplinkNetworkGrade" to it.value.uplinkNetworkGrade.ordinal,
                    "downlinkNetworkGrade" to it.value.downlinkNetworkGrade.ordinal,
                )
            }?.also {
                result.success(it)
                return
            }
            "setClientRole" -> rtcClient?.setClientRole(QNClientRole.values()[call.argument("role")!!],
                object : QNClientRoleResultCallback {
                    override fun onResult(p0: QNClientRole?) {
                        result.postSuccess()
                    }

                    override fun onError(p0: Int, p1: String?) {
                        result.postError("$p0", p1)
                    }
                })?.also {
                return
            }
            "isLocalTrackMuted" -> {
                result.success(localTracks[call.argument("tag")]?.isMuted)
                return
            }
            "setLocalTrackMuted" -> localTracks[call.argument("tag")]?.isMuted =
                call.argument("muted")!!
            "localTrackDestroy" -> localTracks.remove(call.argument("tag"))?.also {
                if (it.isAudio) {
                    microphone = null
                    audioMixers.clear()
                } else {
                    camera = null
                }
                it.destroy()
            }
            "isRemoteTrackMuted" -> {
                result.success(remoteTracks[call.argument("trackId")]?.isMuted)
                return
            }
            "isRemoteTrackSubscribed" -> {
                result.success(remoteTracks[call.argument("trackId")]?.isSubscribed)
                return
            }
            "remoteVideoPlay" -> remoteTracks[call.argument("trackId")]?.also {
                if (it is QNRemoteVideoTrack) {
                    it.play(QNRenderPlatformView.getViewById(call.argument("viewId")))
                }
            }
            "setRemoteVideoProfile" -> remoteTracks[call.argument("trackId")]?.also {
                if (it is QNRemoteVideoTrack) {
                    it.setProfile(QNTrackProfile.values()[call.argument("profile")!!])
                }
            }
            "isMultiProfileEnabled" -> remoteTracks[call.argument("trackId")]?.also {
                if (it is QNRemoteVideoTrack) {
                    result.success(it.isMultiProfileEnabled)
                    return
                }
            }
            "getRemoteAudioVolume" -> remoteTracks[call.argument("trackId")]?.also {
                if (it is QNRemoteAudioTrack) {
                    result.success(it.volumeLevel)
                    return
                }
            }
            "setRemoteAudioVolume" -> remoteTracks[call.argument("trackId")]?.also {
                if (it is QNRemoteAudioTrack) {
                    it.setVolume(call.argument("volume")!!)
                }
            }
            "cameraPlay" -> camera?.play(QNRenderPlatformView.getViewById(call.argument("viewId")))
            "cameraStartCapture" -> camera?.startCapture()
            "cameraStopCapture" -> camera?.stopCapture()
            "switchCamera" -> camera?.also {
                it.switchCamera(object : QNCameraSwitchResultCallback {
                    override fun onSwitched(p0: Boolean) {
                        result.postSuccess(p0)
                    }

                    override fun onError(p0: String?) {
                        result.postError("-1", p0)
                    }
                })
                return
            }
            "turnLightOn" -> result.success(camera?.turnLightOn())
            "turnLightOff" -> result.success(camera?.turnLightOff())
            "setExposureCompensation" -> camera?.setExposureCompensation(call.argument("value")!!)
            "getMaxExposureCompensation" -> result.success(camera?.maxExposureCompensation)
            "getMinExposureCompensation" -> result.success(camera?.minExposureCompensation)
            "setCameraMirror" -> camera?.setMirror(call.argument("mirror")!!)
            "setPreviewEnabled" -> camera?.setPreviewEnabled(call.argument("enabled")!!)
            "setBeauty" -> camera?.setBeauty(
                QNBeautySetting(
                    call.argument("smooth")!!,
                    call.argument("whiten")!!,
                    call.argument("redden")!!
                ).apply { setEnable(call.argument("enabled")!!) })
            "setMicrophoneVolume" -> microphone?.setVolume(call.argument("volume")!!)
            "createAudioMixer" -> call.argument<String>("musicPath")!!.also { musicPath ->
                microphone?.createAudioMixer(musicPath,
                    object : QNAudioMixerListener {
                        override fun onStateChanged(p0: QNAudioMixerState) {
                            channel.postInvoke(
                                "onAudioMixerStateChanged", mapOf(
                                    "musicPath" to musicPath,
                                    "state" to p0.ordinal,
                                )
                            )
                        }

                        override fun onMixing(p0: Long) {
                            channel.postInvoke(
                                "onAudioMixerMixing", mapOf(
                                    "musicPath" to musicPath,
                                    "current" to p0,
                                )
                            )
                        }

                        override fun onError(p0: Int) {
                            channel.postInvoke(
                                "onAudioMixerError", mapOf(
                                    "musicPath" to musicPath,
                                    "errorCode" to p0,
                                )
                            )
                        }
                    })?.also {
                    audioMixers[musicPath] = it
                }
            }
            "audioMixerStart" -> audioMixers[call.argument("musicPath")]?.start()
            "audioMixerStop" -> audioMixers[call.argument("musicPath")]?.stop()
            "audioMixerResume" -> audioMixers[call.argument("musicPath")]?.resume()
            "audioMixerPause" -> audioMixers[call.argument("musicPath")]?.pause()
            "audioMixerGetDuration" -> audioMixers[call.argument("musicPath")]?.also {
                result.success(it.duration)
                return
            }
        }

        result.success(null)
    }

    /**
     * 主线程调用[MethodChannel.invokeMethod]
     */
    private fun MethodChannel.postInvoke(method: String, arguments: Any? = null) {
        handler.post {
            invokeMethod(method, arguments)
        }
    }

    /**
     * 主线程调用[Result.success]
     */
    private fun Result.postSuccess(result: Any? = null) {
        handler.post {
            success(result)
        }
    }

    /**
     * 主线程调用[Result.error]
     */
    private fun Result.postError(
        errorCode: String,
        errorMessage: String? = null,
        errorDetails: Any? = null
    ) {
        handler.post {
            error(errorCode, errorMessage, errorDetails)
        }
    }

    private inner class ClientEventListener : QNClientEventListener {
        override fun onConnectionStateChanged(
            p0: QNConnectionState,
            p1: QNConnectionDisconnectedInfo?
        ) {
            channel.postInvoke(
                "onConnectionStateChanged", mapOf(
                    "state" to p0.ordinal,
                    "errorCode" to p1?.errorCode,
                )
            )
        }

        override fun onUserJoined(p0: String, p1: String?) {
            channel.postInvoke(
                "onUserJoined", mapOf(
                    "remoteUserId" to p0,
                    "userData" to p1,
                )
            )
        }

        override fun onUserReconnecting(p0: String) {
            channel.postInvoke(
                "onUserReconnecting", mapOf(
                    "remoteUserId" to p0,
                )
            )
        }

        override fun onUserReconnected(p0: String) {
            channel.postInvoke(
                "onUserReconnected", mapOf(
                    "remoteUserId" to p0,
                )
            )
        }

        override fun onUserLeft(p0: String) {
            channel.postInvoke(
                "onUserLeft", mapOf(
                    "remoteUserId" to p0,
                )
            )
        }

        override fun onUserPublished(p0: String, p1: List<QNRemoteTrack>) {
            p1.forEach {
                remoteTracks[it.trackID] = it
                it.setTrackInfoChangedListener(object : QNTrackInfoChangedListener {
                    override fun onVideoProfileChanged(profile: QNTrackProfile) {
                        channel.postInvoke(
                            "onVideoProfileChanged", mapOf(
                                "trackId" to it.trackID,
                                "profile" to profile.ordinal,
                            )
                        )
                    }

                    override fun onMuteStateChanged(isMuted: Boolean) {
                        channel.postInvoke(
                            "onMuteStateChanged", mapOf(
                                "trackId" to it.trackID,
                                "isMuted" to isMuted,
                            )
                        )
                    }
                })
            }

            channel.postInvoke("onUserPublished", mapOf(
                "remoteUserId" to p0,
                "trackList" to p1.map {
                    mapOf(
                        "trackId" to it.trackID,
                        "tag" to it.tag,
                        "kind" to if (it.isAudio) 0 else 1,
                    )
                }
            ))
        }

        override fun onUserUnpublished(p0: String, p1: List<QNRemoteTrack>) {
            p1.forEach {
                remoteTracks -= it.trackID
            }
            channel.postInvoke("onUserUnpublished", mapOf(
                "remoteUserId" to p0,
                "trackList" to p1.map {
                    mapOf(
                        "trackId" to it.trackID,
                        "tag" to it.tag,
                        "kind" to if (it.isAudio) 0 else 1,
                    )
                }
            ))
        }

        override fun onSubscribed(
            p0: String,
            p1: List<QNRemoteAudioTrack>,
            p2: List<QNRemoteVideoTrack>
        ) {
            channel.postInvoke("onSubscribed", mapOf(
                "remoteUserId" to p0,
                "remoteAudioTracks" to p1.map {
                    mapOf(
                        "trackId" to it.trackID,
                        "tag" to it.tag,
                        "kind" to if (it.isAudio) 0 else 1,
                    )
                },
                "remoteVideoTracks" to p2.map {
                    mapOf(
                        "trackId" to it.trackID,
                        "tag" to it.tag,
                        "kind" to if (it.isAudio) 0 else 1,
                    )
                }
            ))
        }

        override fun onMessageReceived(p0: QNCustomMessage?) {
        }

        override fun onMediaRelayStateChanged(p0: String?, p1: QNMediaRelayState?) {
        }
    }
}

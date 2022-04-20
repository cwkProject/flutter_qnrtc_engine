// Created by 超悟空 on 2022/4/18.

package com.latitech.flutter_qnrtc_engine

import android.content.Context
import android.view.View
import com.qiniu.droid.rtc.QNTextureView
import io.flutter.plugin.common.MessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 七牛渲染控件工厂
 */
class QNRenderViewFactory(createArgsCodec: MessageCodec<Any>) :
    PlatformViewFactory(createArgsCodec) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        QNRenderPlatformView(QNTextureView(context.applicationContext), viewId)
}

/**
 * 七牛平台插件渲染控件
 */
class QNRenderPlatformView(private val videoView: QNTextureView, private val viewId: Int) :
    PlatformView {
    init {
        views[viewId] = videoView
    }

    override fun getView(): View = videoView

    override fun dispose() {
        views -= viewId
    }

    companion object {

        /**
         * 缓存的控件集合
         */
        private val views = hashMapOf<Int, QNTextureView>()

        /**
         * 根据控件id获取控件
         *
         * @param viewId 控件id
         *
         * @return 原生渲染控件
         */
        fun getViewById(viewId: Int?): QNTextureView? = views[viewId]
    }
}
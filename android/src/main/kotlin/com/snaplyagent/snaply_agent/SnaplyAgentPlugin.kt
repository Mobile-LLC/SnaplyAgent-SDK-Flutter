//
//  SnaplyAgentPlugin.kt
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

package com.snaplyagent.snaply_agent

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.RectF
import android.view.View
import android.view.ViewGroup
import com.snaply.agent.CaptureResult
import com.snaply.agent.LiveSession
import com.snaply.agent.Snaply
import com.snaply.agent.SnaplyCallbacks
import com.snaply.agent.SnaplyEnvironment
import com.snaply.agent.SnaplyException
import com.snaply.agent.SnaplyHostedControlMode
import com.snaply.agent.SnaplyHostedInput
import com.snaply.agent.SnaplyHostedRedaction
import com.snaply.agent.SnaplyHostedSnapshot
import com.snaply.agent.SnaplyHostedSnapshotRequest
import com.snaply.agent.SnaplyHostedView
import com.snaply.agent.SnaplyRedactionRule
import com.snaply.agent.SnaplyUser
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.ByteBuffer

/** Bridges the Dart API to the native SDK and hands the Flutter view over to it as a hosted view. */
class SnaplyAgentPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler,
    SnaplyHostedView {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var flutterView: View? = null

    override val controlMode: SnaplyHostedControlMode get() = SnaplyHostedControlMode.Exclusive

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "snaply_agent")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        handOver(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        handOver(findFlutterView(activity?.window?.decorView))
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activity = null
        handOver(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "configure" -> {
                    val context = context ?: return result.error("not_attached", "The plugin is not attached to an engine.", 0)
                    Snaply.on(callbacks)
                    // The activity, when there is one: it is already on screen by the time Dart runs, and the SDK
                    // can only learn that from being handed it.
                    Snaply.init(
                        context = activity ?: context,
                        key = call.argument<String>("key").orEmpty(),
                        environment = call.argument<String>("environment")?.let { SnaplyEnvironment.Custom(it) } ?: SnaplyEnvironment.Live,
                        user = call.argument<String>("userId")?.let { SnaplyUser(it, call.argument<String>("userName")) },
                        collectVendorId = call.argument<Boolean>("collectVendorId") ?: true,
                        language = call.argument<String>("language") ?: "en",
                    )
                    val decor = activity?.window?.decorView
                    handOver(findFlutterView(decor))
                    if (flutterView == null) decor?.post { handOver(findFlutterView(decor)) }
                    result.success(null)
                }
                "identify" -> {
                    Snaply.identify(
                        id = call.argument<String>("id").orEmpty(),
                        name = call.argument("name"),
                        phone = call.argument("phone"),
                        identitySignature = call.argument("identitySignature"),
                    )
                    result.success(null)
                }
                "reset" -> {
                    Snaply.reset()
                    result.success(null)
                }
                "supportCode" -> result.success(Snaply.supportCode())
                "showSupportCode" -> {
                    Snaply.showSupportCode()
                    result.success(null)
                }
                "stop" -> {
                    Snaply.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: SnaplyException) {
            result.error(error.code, error.message, error.status)
        }
    }

    private fun handOver(view: View?) {
        if (view === flutterView) return
        flutterView?.let { Snaply.registerHostedView(it, null) }
        flutterView = view
        view?.let { Snaply.registerHostedView(it, this) }
    }

    private fun findFlutterView(root: View?): View? = when (root) {
        is FlutterView -> root
        is ViewGroup -> (0 until root.childCount).firstNotNullOfOrNull { findFlutterView(root.getChildAt(it)) }
        else -> null
    }

    override fun snapshot(request: SnaplyHostedSnapshotRequest, done: (SnaplyHostedSnapshot?) -> Unit) {
        val arguments = mapOf(
            "width" to request.width,
            "height" to request.height,
            "rules" to request.rules.map {
                mapOf("kind" to if (it.kind == SnaplyRedactionRule.KIND_ID) "id" else "text", "value" to it.value, "label" to it.label)
            },
        )
        channel.invokeMethod(
            "snapshot",
            arguments,
            object : Result {
                override fun success(frame: Any?) = done(runCatching { decode(frame) }.getOrNull())

                override fun error(code: String, message: String?, details: Any?) = done(null)

                override fun notImplemented() = done(null)
            },
        )
    }

    private fun decode(frame: Any?): SnaplyHostedSnapshot? {
        val map = frame as? Map<*, *> ?: return null
        val width = map["width"] as? Int ?: return null
        val height = map["height"] as? Int ?: return null
        val pixels = map["pixels"] as? ByteArray ?: return null
        if (width <= 0 || height <= 0 || pixels.size != width * height * 4) return null
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(pixels))
        val hidden = map["hidden"] as? DoubleArray ?: DoubleArray(0)
        val labels = map["labels"] as? List<*> ?: emptyList<Any?>()
        val redactions = (0 until hidden.size / 4).map { i ->
            SnaplyHostedRedaction(
                RectF(hidden[i * 4].toFloat(), hidden[i * 4 + 1].toFloat(), hidden[i * 4 + 2].toFloat(), hidden[i * 4 + 3].toFloat()),
                labels.getOrNull(i) as? String,
            )
        }
        return SnaplyHostedSnapshot(bitmap, redactions)
    }

    override fun control(input: SnaplyHostedInput): Boolean {
        val density = flutterView?.resources?.displayMetrics?.density?.takeIf { it > 0f } ?: 1f
        channel.invokeMethod(
            "control",
            mapOf(
                "action" to input.action,
                "x" to (input.x / density).toDouble(),
                "y" to (input.y / density).toDouble(),
                "dx" to (input.dx / density).toDouble(),
                "dy" to (input.dy / density).toDouble(),
                "text" to input.text,
                "key" to input.key,
            ),
        )
        return true
    }

    private val callbacks = object : SnaplyCallbacks {
        override fun onRequestShown() = emit("requestShown")

        override fun onAllowed(capture: CaptureResult) = emit("allowed", "captureId" to capture.captureId, "imageUrl" to capture.imageUrl)

        override fun onDenied() = emit("denied")

        override fun onExpired() = emit("expired")

        override fun onError(error: Exception) {
            val snaply = error as? SnaplyException
            emit("error", "code" to (snaply?.code ?: "error"), "message" to error.message.orEmpty(), "status" to (snaply?.status ?: 0))
        }

        override fun onRemoteControl(active: Boolean) = emit("remoteControl", "active" to active)

        override fun onLiveEnded(session: LiveSession) = emit("liveEnded", "sessionId" to session.sessionId)
    }

    private fun emit(name: String, vararg fields: Pair<String, Any?>) {
        channel.invokeMethod("event", mapOf("name" to name, *fields))
    }
}

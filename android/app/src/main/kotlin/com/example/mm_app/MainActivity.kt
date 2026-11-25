package com.example.mm_app

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "liqua/notices").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enabled" -> result.success(
                        NotificationManagerCompat.getEnabledListenerPackages(this@MainActivity).contains(packageName))
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "peek" -> result.success(NoticeQueue.peek(this@MainActivity))
                    "ack" -> {
                        NoticeQueue.ack(this@MainActivity, call.arguments as Int)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
    }

    companion object {
        private var channel: MethodChannel? = null
        fun notifyArrived() {
            android.os.Handler(android.os.Looper.getMainLooper()).post { channel?.invokeMethod("arrived", null) }
        }
    }
}

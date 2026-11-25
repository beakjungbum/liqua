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
        mine = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "liqua/notices").apply {
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
                        @Suppress("UNCHECKED_CAST")
                        NoticeQueue.ack(this@MainActivity, call.arguments as List<String>)
                        result.success(null)
                    }
                    "setOwner" -> {
                        NoticeQueue.setOwner(this@MainActivity, call.arguments as String?)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        channel = mine
    }

    private var mine: MethodChannel? = null

    override fun onDestroy() {
        if (channel === mine) channel = null
        super.onDestroy()
    }

    companion object {
        private var channel: MethodChannel? = null
        fun notifyArrived() {
            android.os.Handler(android.os.Looper.getMainLooper()).post { channel?.invokeMethod("arrived", null) }
        }
    }
}

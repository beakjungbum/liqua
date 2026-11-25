package com.example.mm_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject

/** 결제로 보이는 알림만 기기 안 대기열에 넣는다. 나머지는 읽고 바로 버린다. */
class PaymentNoticeService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val ex = sbn.notification.extras
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val text = listOf(title, body).filter { it.isNotBlank() }.joinToString("\n")
        if (!PAYMENT.containsMatchIn(text) || !AMOUNT.containsMatchIn(text)) return
        val app = runCatching {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(sbn.packageName, 0)).toString()
        }.getOrDefault(sbn.packageName)
        NoticeQueue.add(this, JSONObject().put("raw", text.take(2000)).put("app", app).put("at", sbn.postTime).toString())
        MainActivity.notifyArrived()
    }

    private companion object {
        val PAYMENT = Regex("승인|결제")
        val AMOUNT = Regex("\\d\\s*원")
    }
}

object NoticeQueue {
    private const val KEY = "queue"
    private fun prefs(c: android.content.Context) = c.getSharedPreferences("liqua_notices", android.content.Context.MODE_PRIVATE)

    @Synchronized
    fun add(c: android.content.Context, json: String) {
        val a = org.json.JSONArray(prefs(c).getString(KEY, "[]"))
        a.put(json)
        while (a.length() > 200) a.remove(0)
        prefs(c).edit().putString(KEY, a.toString()).commit()
    }

    /** 지우지 않고 읽는다. 앱이 저장을 마치면 [ack] 로 지운다. */
    @Synchronized
    fun peek(c: android.content.Context): List<String> {
        val a = org.json.JSONArray(prefs(c).getString(KEY, "[]"))
        return List(a.length()) { a.getString(it) }
    }

    @Synchronized
    fun ack(c: android.content.Context, n: Int) {
        val a = org.json.JSONArray(prefs(c).getString(KEY, "[]"))
        repeat(minOf(n, a.length())) { a.remove(0) }
        prefs(c).edit().putString(KEY, a.toString()).commit()
    }
}

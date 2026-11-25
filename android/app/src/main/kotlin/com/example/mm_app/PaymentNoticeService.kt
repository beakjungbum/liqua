package com.example.mm_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.util.UUID

/** 결제로 보이는 알림만 기기 안 대기열에 넣는다. 나머지는 읽고 바로 버린다. */
class PaymentNoticeService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!allowed(sbn.packageName)) return
        val owner = NoticeQueue.owner(this) ?: return
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val ex = sbn.notification.extras
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val text = listOf(title, body).filter { it.isNotBlank() }.joinToString("\n")
        if (!PAYMENT.containsMatchIn(text) || !AMOUNT.containsMatchIn(text)) return
        val app = runCatching {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(sbn.packageName, 0)).toString()
        }.getOrDefault(sbn.packageName)
        NoticeQueue.add(this, JSONObject().put("id", UUID.randomUUID().toString()).put("owner", owner).put("raw", text.take(2000)).put("app", app).put("at", sbn.postTime).toString())
        MainActivity.notifyArrived()
    }

    /** 카드, 은행, 간편결제, 문자, 카카오톡만 읽는다. 그 밖의 앱은 문구를 보지 않는다. */
    private fun allowed(pkg: String): Boolean {
        val debug = applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        return pkg in PACKAGES || (debug && pkg == "com.android.shell")
    }

    private companion object {
        val PACKAGES = setOf(
            "com.google.android.apps.messaging", "com.samsung.android.messaging", "com.android.mms", "com.kakao.talk",
            "com.kbcard.cxh.appcard", "com.kbstar.kbbank", "com.shcard.smartpay", "com.shinhan.sbanking",
            "kr.co.samsungcard.mpocket", "com.hyundaicard.appcard", "com.lcacApp", "com.hanaskcard.paycla",
            "com.kebhana.hanapush", "com.wooricard.smartapp", "com.wooribank.smart.npib", "nh.smart.nhallonepay",
            "nh.smart.banking", "com.kakaobank.channel", "com.kakaopay.app", "viva.republica.toss", "com.nhn.android.search",
            "com.naverfin.payapp", "com.samsung.android.spay", "com.nhnent.payapp")
        val PAYMENT = Regex("승인|결제|취소|환불")
        val AMOUNT = Regex("\\d\\s*원")
    }
}

object NoticeQueue {
    private const val KEY = "queue"
    private fun prefs(c: android.content.Context) = c.getSharedPreferences("liqua_notices", android.content.Context.MODE_PRIVATE)

    fun owner(c: android.content.Context): String? = prefs(c).getString("owner", null)

    /** 계정이 바뀌면 이전 계정의 알림을 지운다. */
    @Synchronized
    fun setOwner(c: android.content.Context, uid: String?) {
        if (owner(c) == uid) return
        prefs(c).edit().clear().apply { if (uid != null) putString("owner", uid) }.commit()
    }

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
    fun ack(c: android.content.Context, ids: List<String>) {
        val a = org.json.JSONArray(prefs(c).getString(KEY, "[]"))
        val keep = org.json.JSONArray()
        for (i in 0 until a.length()) if (JSONObject(a.getString(i)).optString("id") !in ids) keep.put(a.getString(i))
        prefs(c).edit().putString(KEY, keep.toString()).commit()
    }
}

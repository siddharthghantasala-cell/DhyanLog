package org.heartfulness.dhyanlog

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Silences notifications for the duration of a meditation, via Do Not Disturb.
 *
 * Uses INTERRUPTION_FILTER_ALARMS rather than _NONE deliberately: _NONE also
 * swallows alarms, and a meditation app that eats someone's wake-up alarm is a
 * bug report waiting to happen. ALARMS suppresses every notification and call
 * while still letting a set alarm ring.
 *
 * The filter that was in effect before we muted is persisted to SharedPreferences,
 * not just held in memory, so that an unmute after a process death still restores
 * the user's original state (notably: a user who was ALREADY in Do Not Disturb
 * before meditating must stay in Do Not Disturb afterwards).
 */
class NotificationMutePlugin(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "org.heartfulness.dhyanlog/notification_mute"
        private const val PREFS = "dhyanlog_notification_mute"
        private const val KEY_PREVIOUS_FILTER = "previous_filter"

        fun register(activity: Activity, messenger: BinaryMessenger) {
            MethodChannel(messenger, CHANNEL)
                .setMethodCallHandler(NotificationMutePlugin(activity))
        }
    }

    private val notificationManager: NotificationManager
        get() = activity.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager

    private val prefs
        get() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "openSettings" -> {
                openSettings()
                result.success(null)
            }
            "mute" -> result.success(mute())
            "unmute" -> {
                unmute()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return notificationManager.isNotificationPolicyAccessGranted
    }

    private fun openSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    private fun mute(): Boolean {
        if (!hasPermission()) return false
        val current = notificationManager.currentInterruptionFilter
        // Don't clobber a remembered filter if mute() is called twice — the first
        // call captured the user's real pre-meditation state.
        if (!prefs.contains(KEY_PREVIOUS_FILTER)) {
            prefs.edit().putInt(KEY_PREVIOUS_FILTER, current).apply()
        }
        notificationManager.setInterruptionFilter(
            NotificationManager.INTERRUPTION_FILTER_ALARMS
        )
        return true
    }

    private fun unmute() {
        if (!hasPermission()) return
        // Absent a remembered filter there was nothing of ours to undo; restoring
        // ALL anyway could switch off a DND the user set themselves.
        val previous = prefs.getInt(
            KEY_PREVIOUS_FILTER,
            NotificationManager.INTERRUPTION_FILTER_UNKNOWN
        )
        prefs.edit().remove(KEY_PREVIOUS_FILTER).apply()
        if (previous == NotificationManager.INTERRUPTION_FILTER_UNKNOWN) return
        notificationManager.setInterruptionFilter(previous)
    }
}

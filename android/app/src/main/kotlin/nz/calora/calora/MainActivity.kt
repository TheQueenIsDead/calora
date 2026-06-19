package nz.calora.calora

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val healthChannel = "nz.calora.calora/health"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, healthChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openHealthPermissions" -> {
                        openHealthConnectPermissions()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openHealthConnectPermissions() {
        // The per-app permission deep link (MANAGE_HEALTH_PERMISSIONS) is
        // signature-protected and not callable from third-party apps, so we
        // open HC's home screen instead — one tap from there to App permissions.

        // Android 14+ (built-in Health Connect).
        val home = Intent("android.health.connect.action.HEALTH_HOME_SETTINGS").apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            startActivity(home)
            return
        } catch (_: Exception) {}

        // Pre-14: the legacy Health Connect APK.
        val legacy = packageManager.getLaunchIntentForPackage("com.google.android.apps.healthdata")
        if (legacy != null) {
            legacy.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            try {
                startActivity(legacy)
            } catch (_: Exception) {}
        }
    }
}

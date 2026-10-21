package co.edu.ucc.eyesight_ai

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Canal "eyesight/vibrator": vibra con el tipo de uso de Android que se
 * elija (alarma, notificacion, accesibilidad, tactil o multimedia).
 * Algunos telefonos bloquean ciertos tipos mientras la camara esta activa.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eyesight/vibrator")
            .setMethodCallHandler { call, result ->
                if (call.method == "vibrate") {
                    val pattern = (call.argument<List<Int>>("pattern") ?: emptyList())
                        .map { it.toLong() }
                        .toLongArray()
                    val usage = call.argument<String>("usage") ?: "alarm"
                    try {
                        result.success(vibrate(pattern, usage))
                    } catch (e: Exception) {
                        result.error("vibrate", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private fun vibrate(pattern: LongArray, usage: String): Boolean {
        val v = vibrator() ?: return false
        if (!v.hasVibrator() || pattern.isEmpty()) {
            return false
        }
        val effect = VibrationEffect.createWaveform(pattern, -1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val u = when (usage) {
                "notification" -> VibrationAttributes.USAGE_NOTIFICATION
                "accessibility" -> VibrationAttributes.USAGE_ACCESSIBILITY
                "touch" -> VibrationAttributes.USAGE_TOUCH
                "media" -> VibrationAttributes.USAGE_MEDIA
                else -> VibrationAttributes.USAGE_ALARM
            }
            v.vibrate(effect, VibrationAttributes.createForUsage(u))
        } else {
            val u = when (usage) {
                "notification" -> AudioAttributes.USAGE_NOTIFICATION
                "accessibility" -> AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY
                "touch" -> AudioAttributes.USAGE_ASSISTANCE_SONIFICATION
                "media" -> AudioAttributes.USAGE_MEDIA
                else -> AudioAttributes.USAGE_ALARM
            }
            @Suppress("DEPRECATION")
            v.vibrate(effect, AudioAttributes.Builder().setUsage(u).build())
        }
        return true
    }
}

package co.edu.ucc.eyesight_ai

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Canales nativos de EyeSight AI:
 *
 * - "eyesight/vibrator": vibra con el tipo de uso de Android que se elija
 *   (diagnostico del modo de pruebas).
 * - "eyesight/tones": pitidos suaves (ondas seno con entrada y salida
 *   graduales) para las alertas. Respaldo de la vibracion en telefonos que
 *   la bloquean mientras la camara esta activa, como el vivo Y22s.
 */
class MainActivity : FlutterActivity() {
    private var track: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eyesight/tones")
            .setMethodCallHandler { call, result ->
                if (call.method == "play") {
                    val tones = call.argument<List<List<Number>>>("tones") ?: emptyList()
                    val volume = (call.argument<Number>("volume") ?: 0.35).toDouble()
                    try {
                        playTones(tones, volume)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("tones", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
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

    /**
     * Cada tono es [frecuencia Hz, duracion ms, pausa despues ms]. Se generan
     * ondas seno con 12 ms de entrada y salida suaves (sin chasquidos) y se
     * reproducen por el canal de guia de navegacion, que sigue el volumen
     * multimedia como la voz.
     */
    private fun playTones(tones: List<List<Number>>, volume: Double) {
        val rate = 44100
        val fade = rate * 12 / 1000
        val amp = volume.coerceIn(0.0, 1.0) * Short.MAX_VALUE
        var total = 0
        for (t in tones) {
            total += rate * (t[1].toInt() + t[2].toInt()) / 1000
        }
        if (total == 0) {
            return
        }
        val pcm = ShortArray(total)
        var pos = 0
        for (t in tones) {
            val freq = t[0].toDouble()
            val n = rate * t[1].toInt() / 1000
            for (i in 0 until n) {
                val edge = minOf(i, n - 1 - i)
                val env = if (edge < fade) 0.5 - 0.5 * cos(PI * edge / fade) else 1.0
                pcm[pos + i] = (amp * env * sin(2 * PI * freq * i / rate)).toInt().toShort()
            }
            pos += n + rate * t[2].toInt() / 1000
        }
        track?.let {
            try {
                it.stop()
            } catch (e: IllegalStateException) {
                // Ya estaba detenido.
            }
            it.release()
        }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(rate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()
        val next = AudioTrack(attributes, format, total * 2, AudioTrack.MODE_STATIC, 0)
        next.write(pcm, 0, total)
        next.play()
        track = next
    }

    override fun onDestroy() {
        track?.release()
        track = null
        super.onDestroy()
    }
}

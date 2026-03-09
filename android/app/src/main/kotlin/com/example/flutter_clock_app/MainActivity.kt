package com.example.flutter_clock_app

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.flutter_clock_app/alarm_volume"

    // Saves the ALARM stream volume before we override it so we can restore it.
    private var savedAlarmVolume: Int = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            val audioManager =
                getSystemService(Context.AUDIO_SERVICE) as AudioManager

            when (call.method) {
                // Called before alarm starts: override ALARM stream volume to the
                // percentage the user configured, regardless of the current system
                // alarm volume setting.
                "setAlarmVolume" -> {
                    val percentage = call.argument<Double>("percentage") ?: 1.0
                    val maxVolume =
                        audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)

                    // Save only the first time (don't overwrite an already-saved value)
                    if (savedAlarmVolume < 0) {
                        savedAlarmVolume =
                            audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                    }

                    val targetVolume =
                        (maxVolume * percentage).toInt().coerceIn(0, maxVolume)
                    audioManager.setStreamVolume(
                        AudioManager.STREAM_ALARM,
                        targetVolume,
                        0 // no UI flags — silent volume change
                    )
                    result.success(null)
                }

                // Called when alarm is dismissed / snoozed: restore the original
                // ALARM stream volume so the user does not notice any change.
                "restoreAlarmVolume" -> {
                    if (savedAlarmVolume >= 0) {
                        val maxVolume =
                            audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        val safeVolume = savedAlarmVolume.coerceIn(0, maxVolume)
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_ALARM,
                            safeVolume,
                            0
                        )
                        savedAlarmVolume = -1
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}

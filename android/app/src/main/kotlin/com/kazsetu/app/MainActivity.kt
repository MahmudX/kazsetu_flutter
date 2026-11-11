package com.kazsetu.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel the server targets for chat pushes; high importance pops up like WhatsApp.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("messages", "Messages", NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // In-app tone for a message that arrives while the app is open. Silent and vibrate modes mute it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kazsetu/sound").setMethodCallHandler { _, result ->
            val audio = getSystemService(AudioManager::class.java)
            if (audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                MediaPlayer.create(this, R.raw.incoming, attributes, audio.generateAudioSessionId())
                    ?.apply { setOnCompletionListener { it.release() }; start() }
            }
            result.success(null)
        }
    }
}

package com.kazsetu.app

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        /** On screen now: the app plays its own tone, so no chat notification is drawn. */
        @Volatile var inForeground = false
    }

    private var channel: MethodChannel? = null
    // A chat notification tapped while the app was closed, collected by Dart once it is ready.
    private var launchChat: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel chat notifications use; high importance pops up like WhatsApp.
        ChatNotifications.createChannel(this)
        launchChat = intent?.getStringExtra(ChatNotifications.EXTRA_CHAT)
    }

    override fun onResume() {
        super.onResume()
        inForeground = true
    }

    override fun onPause() {
        inForeground = false
        super.onPause()
    }

    // A chat notification tapped while the app is running: open that chat now.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(ChatNotifications.EXTRA_CHAT)?.let { channel?.invokeMethod("openChat", it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kazsetu/sound").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "incoming" -> playTone()
                    "setApiBase" -> ChatNotifications.setApiBase(this@MainActivity, call.arguments as String)
                    "launchChat" -> {
                        result.success(launchChat)
                        launchChat = null
                        return@setMethodCallHandler
                    }
                }
                result.success(null)
            }
        }
    }

    // In-app tone for a message that arrives while the app is open. Silent and vibrate modes mute it.
    private fun playTone() {
        val audio = getSystemService(AudioManager::class.java)
        if (audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            MediaPlayer.create(this, R.raw.incoming, attributes, audio.generateAudioSessionId())
                ?.apply { setOnCompletionListener { it.release() }; start() }
        }
    }
}

package com.kazsetu.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Shader
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.min

/**
 * Receives pushes in place of the plugin's service (see AndroidManifest.xml). The plugin still
 * hands every message to Dart through its own receiver, so the open app plays its tone and
 * refreshes; this only draws the chat notification while the app is not on screen.
 */
class ChatMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val data = message.data
        if (data["type"] == "chat" && data["title"] != null && !MainActivity.inForeground) {
            ChatNotifications.show(this, data)
        }
    }
}

/**
 * A WhatsApp-style notification: the sender's round photo in place of the app icon, messages from
 * one person stacked in one conversation, and a tap that opens that chat. Android shows the photo
 * this way only for a conversation, which needs a long-lived shortcut for the person.
 */
object ChatNotifications {
    const val CHANNEL = "messages"
    const val EXTRA_CHAT = "chatUserId"
    private const val PREFS = "kazsetu_native"
    private const val API_BASE = "apiBase"

    /** Called by the app at start, so a site-relative photo URL (/files/...) can be resolved. */
    fun setApiBase(context: Context, base: String) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(API_BASE, base).apply()

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Messages", NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    fun show(context: Context, data: Map<String, String>) {
        val userId = data["userId"] ?: return
        val name = data["title"] ?: return
        val tag = data["tag"] ?: "chat-$userId"
        createChannel(context) // the app may never have opened since install

        val photo = data["picture"]?.takeIf { it.isNotBlank() }?.let { loadRound(context, it) }
        val icon = photo?.let { IconCompat.createWithBitmap(it) }
        val sender = Person.Builder().setKey(userId).setName(name).setIcon(icon).build()

        val open = PendingIntent.getActivity(
            context,
            userId.hashCode(),
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .putExtra(EXTRA_CHAT, userId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val shortcutId = "chat-$userId"
        ShortcutManagerCompat.pushDynamicShortcut(
            context,
            ShortcutInfoCompat.Builder(context, shortcutId)
                .setLongLived(true)
                .setShortLabel(name)
                .setPerson(sender)
                .setIcon(icon ?: IconCompat.createWithResource(context, R.mipmap.ic_launcher))
                .setIntent(
                    Intent(context, MainActivity::class.java)
                        .setAction(Intent.ACTION_VIEW)
                        .putExtra(EXTRA_CHAT, userId)
                )
                .build(),
        )

        // Add to the conversation already showing for this person, like a chat app.
        val manager = NotificationManagerCompat.from(context)
        val earlier = context.getSystemService(NotificationManager::class.java)
            .activeNotifications.firstOrNull { it.tag == tag }?.notification
        val style = earlier?.let { NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(it) }
            // The reader; never shown in a one-to-one conversation, but the style requires one.
            ?: NotificationCompat.MessagingStyle(Person.Builder().setName("You").setKey("me").build())
        style.addMessage(data["body"] ?: "", System.currentTimeMillis(), sender)

        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setStyle(style)
            .setShortcutId(shortcutId)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(tag, 0, notification)
        } catch (_: SecurityException) {
            // Notification permission withdrawn: nothing to show.
        }
    }

    /** The sender's photo as a circle, or null when it cannot be fetched quickly. */
    private fun loadRound(context: Context, picture: String): Bitmap? = try {
        val base = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(API_BASE, "https://kazsetu.com")!!
        val url = if (picture.startsWith("http")) picture else base.trimEnd('/') + picture
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 5000
            readTimeout = 5000
            instanceFollowRedirects = true
        }
        val bytes = connection.inputStream.use { it.readBytes() }
        connection.disconnect()
        // Decode at about 2x the 48dp avatar, not at full photo size.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (min(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 256) sample *= 2
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
            ?.let(::circle)
    } catch (e: Exception) {
        android.util.Log.w("ChatNotifications", "Sender photo unavailable: $e")
        null // No photo: the shortcut falls back to the app icon.
    }

    private fun circle(source: Bitmap): Bitmap {
        val size = min(source.width, source.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
            val matrix = android.graphics.Matrix()
            matrix.setTranslate(-(source.width - size) / 2f, -(source.height - size) / 2f)
            setLocalMatrix(matrix)
        }
        Canvas(output).drawCircle(size / 2f, size / 2f, size / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.shader = shader })
        return output
    }
}

package com.vibely.music.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.media.app.NotificationCompat.MediaStyle
import androidx.core.app.NotificationCompat
import fi.iki.elonen.NanoHTTPD
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class PlaybackService : Service() {

    private var server: LocalServer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        setupMediaSession()

        // Regista esta instância para o AndroidBridge conseguir falar com o serviço
        // (atualizar notificação/MediaSession a partir do WebView)
        PlaybackServiceInstance.instance = this

        val notification = buildNotification(null, null, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "vibely:playback").apply {
            setReferenceCounted(false)
            acquire()
        }

        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "vibely:wifi").apply {
            setReferenceCounted(false)
            acquire()
        }

        Thread {
            try {
                server = LocalServer(applicationContext)
                server?.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
                Log.d("VibelyService", "LocalServer arrancado: ${server?.isAlive}")
            } catch (e: Exception) {
                Log.e("VibelyService", "Falha ao arrancar o servidor", e)
            }
        }.start()
    }

    private fun setupMediaSession() {
        mediaSession = MediaSessionCompat(this, "VibelySession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() { sendCommandToWeb("play") }
                override fun onPause() { sendCommandToWeb("pause") }
                override fun onSkipToNext() { sendCommandToWeb("next") }
                override fun onSkipToPrevious() { sendCommandToWeb("prev") }
                override fun onSeekTo(pos: Long) { sendCommandToWeb("seek:$pos") }
            })
            isActive = true
        }
    }

    private fun sendCommandToWeb(cmd: String) {
        val intent = Intent("com.vibely.music.app.MEDIA_COMMAND").apply { putExtra("cmd", cmd) }
        sendBroadcast(intent)
    }

    fun updateNowPlaying(title: String, artist: String, thumbnailUrl: String?, isPlaying: Boolean, position: Long, duration: Long) {
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)

        mediaSession?.setMetadata(metadataBuilder.build())

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_SEEK_TO
                )
                .setState(state, position, 1f)
                .build()
        )

        if (thumbnailUrl.isNullOrEmpty()) {
            postNotification(title, artist, null, isPlaying)
        } else {
            Thread {
                val bmp = try {
                    http.newCall(Request.Builder().url(thumbnailUrl).build()).execute().use { resp ->
                        resp.body?.byteStream()?.let { BitmapFactory.decodeStream(it) }
                    }
                } catch (e: Exception) { null }
                postNotification(title, artist, bmp, isPlaying)
            }.start()
        }
    }

    private fun postNotification(title: String?, artist: String?, art: Bitmap?, isPlaying: Boolean) {
        val notification = buildNotification(title, artist, isPlaying, art)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(title: String?, artist: String?, isPlaying: Boolean, art: Bitmap? = null): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPending = PendingIntent.getActivity(
            this, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val playPauseAction = NotificationCompat.Action(
            if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (isPlaying) "Pausar" else "Tocar",
            mediaPendingIntent(if (isPlaying) PlaybackStateCompat.ACTION_PAUSE else PlaybackStateCompat.ACTION_PLAY)
        )
        val prevAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous, "Anterior",
            mediaPendingIntent(PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)
        )
        val nextAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next, "Próxima",
            mediaPendingIntent(PlaybackStateCompat.ACTION_SKIP_TO_NEXT)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title ?: "Vibely")
            .setContentText(artist ?: "Tocando em segundo plano")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setLargeIcon(art)
            .setContentIntent(contentPending)
            .setOngoing(isPlaying)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun mediaPendingIntent(action: Long): PendingIntent {
        val keycode = PlaybackStateCompat.toKeyCode(action)
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(packageName)
            putExtra(Intent.EXTRA_KEY_EVENT, android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, keycode))
        }
        return PendingIntent.getBroadcast(this, action.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        server?.stop()
        server = null
        mediaSession?.release()
        mediaSession = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wifiLock?.let { if (it.isHeld) it.release() }

        // Remove o registo desta instância — evita o AndroidBridge falar com um serviço morto
        PlaybackServiceInstance.instance = null

        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Reprodução", NotificationManager.IMPORTANCE_LOW)
            channel.setShowBadge(false)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "vibely_playback"
        private const val NOTIFICATION_ID = 1
        var mediaSession: MediaSessionCompat? = null
    }
}
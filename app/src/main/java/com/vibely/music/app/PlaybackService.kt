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
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import fi.iki.elonen.NanoHTTPD
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class PlaybackService : Service() {

    private var server: LocalServer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var eventNotifId = 1000

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    private var lastTitle: String? = null
    private var lastArtist: String? = null
    private var lastPlaying: Boolean = false
    private var lastArt: Bitmap? = null
    private var lastArtUrl: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
        setupMediaSession()

        PlaybackServiceInstance.instance = this

        val notification = buildNotification(null, null, false, null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "vibely:playback").apply {
            setReferenceCounted(false); acquire()
        }
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "vibely:wifi").apply {
            setReferenceCounted(false); acquire()
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
        val session = MediaSessionCompat(this, "VibelySession")
        session.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() { sendCommandToWeb("play") }
            override fun onPause() { sendCommandToWeb("pause") }
            override fun onSkipToNext() { sendCommandToWeb("next") }
            override fun onSkipToPrevious() { sendCommandToWeb("prev") }
            override fun onStop() { sendCommandToWeb("pause") }
            override fun onSeekTo(pos: Long) { sendCommandToWeb("seek:$pos") }
        })
        session.setPlaybackState(
            PlaybackStateCompat.Builder().setActions(ALL_ACTIONS).setState(PlaybackStateCompat.STATE_PAUSED, 0L, 1f).build()
        )
        session.isActive = true
        mediaSession = session
    }

    private fun sendCommandToWeb(cmd: String) {
        val intent = Intent("com.vibely.music.app.MEDIA_COMMAND").apply {
            setPackage(packageName); putExtra("cmd", cmd)
        }
        sendBroadcast(intent)
    }

    fun updateNowPlaying(title: String, artist: String, thumbnailUrl: String?, isPlaying: Boolean, position: Long, duration: Long) {
        lastTitle = title; lastArtist = artist; lastPlaying = isPlaying
        val safeDuration = if (duration > 0) duration else -1L
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, safeDuration)
        lastArt?.let { metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it) }
        mediaSession?.setMetadata(metadataBuilder.build())

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder().setActions(ALL_ACTIONS)
                .setState(state, position.coerceAtLeast(0L), if (isPlaying) 1f else 0f).build()
        )

        postNotification(title, artist, lastArt, isPlaying)

        if (thumbnailUrl.isNullOrEmpty()) { lastArt = null; lastArtUrl = null; return }
        if (thumbnailUrl == lastArtUrl && lastArt != null) return
        lastArtUrl = thumbnailUrl
        Thread {
            val bmp = try {
                http.newCall(Request.Builder().url(thumbnailUrl).build()).execute().use { resp ->
                    resp.body?.byteStream()?.let { android.graphics.BitmapFactory.decodeStream(it) }
                }
            } catch (e: Exception) { null }
            if (bmp != null && thumbnailUrl == lastArtUrl) {
                lastArt = bmp
                val md = MediaMetadataCompat.Builder()
                    .putString(MediaMetadataCompat.METADATA_KEY_TITLE, lastTitle ?: "")
                    .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, lastArtist ?: "")
                    .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, safeDuration)
                    .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bmp)
                    .build()
                mediaSession?.setMetadata(md)
                postNotification(lastTitle, lastArtist, bmp, lastPlaying)
            }
        }.start()
    }

    private fun postNotification(title: String?, artist: String?, art: Bitmap?, isPlaying: Boolean) {
        val notification = buildNotification(title, artist, isPlaying, art)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }

    fun postEventNotification(title: String, message: String) {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPending = PendingIntent.getActivity(
            this, eventNotifId, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID_EVENTS)
            .setContentTitle(title).setContentText(message)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(contentPending).setAutoCancel(true).setOnlyAlertOnce(false)
            .build()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(eventNotifId++, notification)
    }

    private fun buildNotification(title: String?, artist: String?, isPlaying: Boolean, art: Bitmap?): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPending = PendingIntent.getActivity(this, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val playPauseAction = NotificationCompat.Action(
            if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (isPlaying) "Pausar" else "Tocar",
            mediaPendingIntent(if (isPlaying) PlaybackStateCompat.ACTION_PAUSE else PlaybackStateCompat.ACTION_PLAY)
        )
        val prevAction = NotificationCompat.Action(android.R.drawable.ic_media_previous, "Anterior", mediaPendingIntent(PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS))
        val nextAction = NotificationCompat.Action(android.R.drawable.ic_media_next, "Próxima", mediaPendingIntent(PlaybackStateCompat.ACTION_SKIP_TO_NEXT))

        return NotificationCompat.Builder(this, CHANNEL_ID_PLAYBACK)
            .setContentTitle(title ?: "Vibely").setContentText(artist ?: "Pronto para tocar")
            .setSmallIcon(R.drawable.ic_notification).setLargeIcon(art)
            .setContentIntent(contentPending).setOngoing(isPlaying).setOnlyAlertOnce(true)
            .addAction(prevAction).addAction(playPauseAction).addAction(nextAction)
            .setStyle(MediaStyle().setMediaSession(mediaSession?.sessionToken).setShowActionsInCompactView(0, 1, 2))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun mediaPendingIntent(action: Long): PendingIntent {
        val name = when (action) {
            PlaybackStateCompat.ACTION_PLAY -> ACTION_PLAY
            PlaybackStateCompat.ACTION_PAUSE -> ACTION_PAUSE
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT -> ACTION_NEXT
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS -> ACTION_PREV
            else -> ACTION_PLAY
        }
        val intent = Intent(this, PlaybackService::class.java).apply { this.action = name }
        return PendingIntent.getService(this, action.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> sendCommandToWeb("play")
            ACTION_PAUSE -> sendCommandToWeb("pause")
            ACTION_NEXT -> sendCommandToWeb("next")
            ACTION_PREV -> sendCommandToWeb("prev")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        server?.stop(); server = null
        mediaSession?.release(); mediaSession = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wifiLock?.let { if (it.isHeld) it.release() }
        PlaybackServiceInstance.instance = null
        super.onDestroy()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val playback = NotificationChannel(CHANNEL_ID_PLAYBACK, "Reprodução", NotificationManager.IMPORTANCE_LOW)
            playback.setShowBadge(false)
            nm.createNotificationChannel(playback)
            val events = NotificationChannel(CHANNEL_ID_EVENTS, "Eventos da app", NotificationManager.IMPORTANCE_DEFAULT)
            events.description = "Downloads concluídos e outros avisos da Vibely"
            nm.createNotificationChannel(events)
        }
    }

    companion object {
        private const val CHANNEL_ID_PLAYBACK = "vibely_playback"
        private const val CHANNEL_ID_EVENTS = "vibely_events"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_PLAY = "com.vibely.music.app.ACTION_PLAY"
        private const val ACTION_PAUSE = "com.vibely.music.app.ACTION_PAUSE"
        private const val ACTION_NEXT = "com.vibely.music.app.ACTION_NEXT"
        private const val ACTION_PREV = "com.vibely.music.app.ACTION_PREV"
        private const val ALL_ACTIONS =
            PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or PlaybackStateCompat.ACTION_STOP
        var mediaSession: MediaSessionCompat? = null
    }
}
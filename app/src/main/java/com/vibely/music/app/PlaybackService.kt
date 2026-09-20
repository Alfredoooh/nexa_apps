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

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    // Último estado conhecido, para reconstruir a notificação quando a capa termina de descarregar
    private var lastTitle: String? = null
    private var lastArtist: String? = null
    private var lastPlaying: Boolean = false
    private var lastArt: Bitmap? = null
    private var lastArtUrl: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        setupMediaSession()

        // Regista esta instância para o AndroidBridge conseguir falar com o serviço
        // (atualizar notificação/MediaSession a partir do WebView)
        PlaybackServiceInstance.instance = this

        val notification = buildNotification(null, null, false, null)
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
        val session = MediaSessionCompat(this, "VibelySession")
        session.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() { sendCommandToWeb("play") }
            override fun onPause() { sendCommandToWeb("pause") }
            override fun onSkipToNext() { sendCommandToWeb("next") }
            override fun onSkipToPrevious() { sendCommandToWeb("prev") }
            override fun onStop() { sendCommandToWeb("pause") }
            override fun onSeekTo(pos: Long) { sendCommandToWeb("seek:$pos") }
        })

        // Estado inicial COMPLETO: sem as ações declaradas desde o início, o Android
        // esconde/ignora os botões de próxima e anterior na notificação e no ecrã bloqueado.
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(ALL_ACTIONS)
                .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 1f)
                .build()
        )
        session.isActive = true
        mediaSession = session
    }

    // Broadcast EXPLÍCITO (com setPackage): a partir do Android 8 os broadcasts implícitos
    // não chegam a receivers registados em runtime de forma fiável, e a partir do 14
    // é obrigatório declarar o pacote. Sem isto o comando perde-se.
    private fun sendCommandToWeb(cmd: String) {
        val intent = Intent("com.vibely.music.app.MEDIA_COMMAND").apply {
            setPackage(packageName)
            putExtra("cmd", cmd)
        }
        sendBroadcast(intent)
    }

    fun updateNowPlaying(title: String, artist: String, thumbnailUrl: String?, isPlaying: Boolean, position: Long, duration: Long) {
        lastTitle = title
        lastArtist = artist
        lastPlaying = isPlaying

        val safeDuration = if (duration > 0) duration else -1L
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, safeDuration)
        lastArt?.let { metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it) }
        mediaSession?.setMetadata(metadataBuilder.build())

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(ALL_ACTIONS)
                .setState(state, position.coerceAtLeast(0L), if (isPlaying) 1f else 0f)
                .build()
        )

        // Publica logo a notificação com o que já temos (rápido), e depois refresca com a capa
        postNotification(title, artist, lastArt, isPlaying)

        if (thumbnailUrl.isNullOrEmpty()) {
            lastArt = null
            lastArtUrl = null
            return
        }
        if (thumbnailUrl == lastArtUrl && lastArt != null) return
        lastArtUrl = thumbnailUrl
        Thread {
            val bmp = try {
                http.newCall(Request.Builder().url(thumbnailUrl).build()).execute().use { resp ->
                    resp.body?.byteStream()?.let { BitmapFactory.decodeStream(it) }
                }
            } catch (e: Exception) { null }
            // Só aplica se ainda for a faixa atual (evita a capa antiga aparecer depois de trocar)
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

    private fun buildNotification(title: String?, artist: String?, isPlaying: Boolean, art: Bitmap?): Notification {
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
            .setContentText(artist ?: "Pronto para tocar")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setLargeIcon(art)
            .setContentIntent(contentPending)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
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

    // Os botões da notificação chamam este serviço diretamente (onStartCommand), sem passar
    // pelo MediaButtonReceiver do manifesto: mais direto e sem depender de KeyEvents.
    private fun mediaPendingIntent(action: Long): PendingIntent {
        val name = when (action) {
            PlaybackStateCompat.ACTION_PLAY -> ACTION_PLAY
            PlaybackStateCompat.ACTION_PAUSE -> ACTION_PAUSE
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT -> ACTION_NEXT
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS -> ACTION_PREV
            else -> ACTION_PLAY
        }
        val intent = Intent(this, PlaybackService::class.java).apply { this.action = name }
        return PendingIntent.getService(
            this, action.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
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
        private const val ACTION_PLAY = "com.vibely.music.app.ACTION_PLAY"
        private const val ACTION_PAUSE = "com.vibely.music.app.ACTION_PAUSE"
        private const val ACTION_NEXT = "com.vibely.music.app.ACTION_NEXT"
        private const val ACTION_PREV = "com.vibely.music.app.ACTION_PREV"

        private const val ALL_ACTIONS =
            PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or PlaybackStateCompat.ACTION_STOP

        var mediaSession: MediaSessionCompat? = null
    }
}
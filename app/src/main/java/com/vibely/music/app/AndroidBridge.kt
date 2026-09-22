package com.vibely.music.app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.util.Log
import android.webkit.JavascriptInterface
import androidx.core.content.FileProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer

class AndroidBridge(private val context: Context) {

    private val prefs = PreferencesStore(context)
    private val downloads = DownloadManager(context)
    private val bluetooth = BluetoothManager(context)
    private val podcasts = PodcastProvider()

    @JavascriptInterface
    fun isInsideApp(): Boolean = true

    // ─── Estado da barra de status ───
    @JavascriptInterface
    fun setStatusBarTheme(lightIcons: Boolean) {
        (context as? MainActivity)?.setStatusBarIcons(lightIcons)
    }

    // ─── Preferências persistentes ───
    @JavascriptInterface
    fun getPreferences(): String {
        val map = prefs.getAll()
        val json = JSONObject()
        map.forEach { (k, v) -> json.put(k, v) }
        return json.toString()
    }

    @JavascriptInterface
    fun setPreference(key: String, value: String) {
        prefs.set(key, value)
    }

    @JavascriptInterface
    fun isSystemDarkMode(): Boolean = prefs.isSystemDarkMode()

    // ─── Rede ───
    @JavascriptInterface
    fun isOnWifi(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }

    @JavascriptInterface
    fun isOnline(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    // ─── Volume do sistema (stream de música) ───
    @JavascriptInterface
    fun getVolume(): Int {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0
        return ((current.toFloat() / max) * 100).toInt()
    }

    @JavascriptInterface
    fun setVolume(percent: Int) {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val clamped = percent.coerceIn(0, 100)
        val target = ((clamped / 100f) * max).toInt().coerceIn(0, max)
        try {
            am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
        } catch (e: Exception) {
            Log.e("VibelyBridge", "setVolume falhou: ${e.message}")
        }
    }

    // ─── Câmera (só fotos) + flash, com navegação nativa (ver CameraActivity) ───
    @JavascriptInterface
    fun openCamera() {
        val activity = context as? MainActivity ?: return
        val intent = Intent(activity, CameraActivity::class.java)
        intent.putExtra("appUrl", activity.currentUrl())
        activity.startActivity(intent)
    }

    // ─── Downloads persistentes reais ───
    @JavascriptInterface
    fun downloadTrack(videoId: String, title: String, quality: String) {
        Thread {
            try {
                val server = "http://localhost:8080"
                val streamRes = java.net.URL("$server/stream?id=$videoId&quality=$quality").readText()
                val streamUrl = JSONObject(streamRes).optString("streamUrl")
                if (streamUrl.isNotEmpty()) {
                    downloads.download(videoId, streamUrl, emptyMap()) { success ->
                        val intent = Intent("com.vibely.music.app.DOWNLOAD_RESULT").apply {
                            setPackage(context.packageName)
                            putExtra("id", videoId)
                            putExtra("success", success)
                        }
                        context.sendBroadcast(intent)
                        notifyEvent(
                            if (success) "Download concluído" else "Falha no download",
                            if (success) "$title está pronto para ouvir offline. Verifica na app Vibely." else "Não foi possível descarregar $title."
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e("VibelyBridge", "downloadTrack falhou: ${e.message}")
                notifyEvent("Falha no download", "Não foi possível descarregar $title.")
            }
        }.start()
    }

    @JavascriptInterface
    fun removeDownload(videoId: String): Boolean = downloads.remove(videoId)

    @JavascriptInterface
    fun isDownloaded(videoId: String): Boolean = downloads.isDownloaded(videoId)

    @JavascriptInterface
    fun downloadedFileUrl(videoId: String): String {
        val file = downloads.fileFor(videoId)
        return if (file.exists() && file.length() > 0) "http://localhost:8080/downloaded?id=$videoId" else ""
    }

    // ─── Bluetooth ───
    @JavascriptInterface
    fun scanDevices(): String = bluetooth.listPairedDevices()

    @JavascriptInterface
    fun connectDevice(deviceId: String): Boolean = bluetooth.connect(deviceId)

    @JavascriptInterface
    fun disconnectDevice(deviceId: String): Boolean = true

    @JavascriptInterface
    fun openBluetoothSettings() {
        val intent = Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    // ─── Partilha nativa ───
    @JavascriptInterface
    fun shareTo(app: String, title: String, artist: String, url: String) {
        val text = "$title • $artist\n$url"
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_SUBJECT, title)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val targetPackage = when (app) {
            "whatsapp" -> "com.whatsapp"
            "telegram" -> "org.telegram.messenger"
            "instagram" -> "com.instagram.android"
            "facebook" -> "com.facebook.katana"
            "x" -> "com.twitter.android"
            else -> null
        }
        if (targetPackage != null) {
            intent.setPackage(targetPackage)
            try { context.startActivity(intent); return } catch (e: Exception) { intent.setPackage(null) }
        }
        val chooser = Intent.createChooser(intent, "Partilhar via").apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
        context.startActivity(chooser)
    }

    @JavascriptInterface
    fun openUrl(url: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        } catch (e: Exception) { }
    }

    @JavascriptInterface
    fun shareDownloadedFile(videoId: String, title: String) {
        val file = downloads.fileFor(videoId)
        if (!file.exists()) return
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "audio/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val chooser = Intent.createChooser(intent, "Enviar áudio").apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
        context.startActivity(chooser)
    }

    // ─── Notificação nativa / MediaSession ───
    @JavascriptInterface
    fun updateNowPlaying(title: String, artist: String, thumbnailUrl: String, isPlaying: Boolean, positionMs: Long, durationMs: Long) {
        val service = PlaybackServiceInstance.instance ?: return
        service.updateNowPlaying(title, artist, thumbnailUrl, isPlaying, positionMs, durationMs)
    }

    @JavascriptInterface
    fun notifyEvent(title: String, message: String) {
        PlaybackServiceInstance.instance?.postEventNotification(title, message)
    }

    // ─── Músicas locais, com cache (evita "ficar sempre a recarregar") ───
    @JavascriptInterface
    fun getLocalTracks(): String = scanLocalTracks()

    @JavascriptInterface
    fun getLocalTracksCached(): String {
        val (cachedJson, cachedCount) = prefs.getLocalTracksCache()
        val currentCount = countLocalTracks()
        if (cachedJson != null && cachedCount != null && cachedCount == currentCount) return cachedJson
        val fresh = scanLocalTracks()
        prefs.setLocalTracksCache(fresh, currentCount)
        return fresh
    }

    @JavascriptInterface
    fun forceRescanLocalTracks(): String {
        val fresh = scanLocalTracks()
        prefs.setLocalTracksCache(fresh, countLocalTracks())
        return fresh
    }

    private fun countLocalTracks(): Long {
        return try {
            val media = android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            val selection = "${android.provider.MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
                "${android.provider.MediaStore.Audio.Media.DURATION} > 0"
            context.contentResolver.query(media, arrayOf(android.provider.MediaStore.Audio.Media._ID), selection, null, null)
                ?.use { it.count.toLong() } ?: 0L
        } catch (e: Exception) { 0L }
    }

    // Normaliza um nome de álbum para agrupamento: minúsculas, sem espaços extra, sem acentos.
    // Resolve o problema de "vários álbuns duplicados" causado por pequenas variações no MediaStore.
    private fun normalizeAlbumKey(raw: String): String {
        val trimmed = raw.trim().lowercase(java.util.Locale.ROOT)
        val noAccents = Normalizer.normalize(trimmed, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")
        return noAccents.replace(Regex("\\s+"), " ").trim()
    }

    private fun scanLocalTracks(): String {
        val arr = JSONArray()
        val media = android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            android.provider.MediaStore.Audio.Media._ID,
            android.provider.MediaStore.Audio.Media.TITLE,
            android.provider.MediaStore.Audio.Media.ARTIST,
            android.provider.MediaStore.Audio.Media.ALBUM,
            android.provider.MediaStore.Audio.Media.DURATION
        )
        val selection = "${android.provider.MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
            "${android.provider.MediaStore.Audio.Media.DURATION} > 0"
        val customCovers = prefs.getCustomCovers()
        try {
            context.contentResolver.query(
                media, projection, selection, null,
                "${android.provider.MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.ALBUM)
                val durCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.DURATION)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val trackId = "local_$id"
                    val artist = cursor.getString(artistCol)?.takeIf { it.isNotBlank() && it != "<unknown>" } ?: "Artista desconhecido"
                    val album = cursor.getString(albumCol)?.takeIf { it.isNotBlank() && it != "<unknown>" } ?: ""
                    val hasCustomCover = customCovers.has(trackId)
                    arr.put(JSONObject().apply {
                        put("id", trackId)
                        put("title", cursor.getString(titleCol) ?: "Sem título")
                        put("artist", artist)
                        put("album", album)
                        put("albumKey", normalizeAlbumKey(if (album.isNotBlank()) album else artist))
                        put("duration", (cursor.getLong(durCol) / 1000))
                        put("localUri", "http://localhost:8080/local?id=$trackId")
                        put("thumbnail", if (hasCustomCover) "http://localhost:8080/customcover?id=$trackId&t=${System.currentTimeMillis()}" else "http://localhost:8080/cover?id=$trackId")
                        put("isLocal", true)
                    })
                }
            }
        } catch (e: SecurityException) {
            Log.w("VibelyBridge", "scanLocalTracks: sem permissão de áudio")
        } catch (e: Exception) {
            Log.e("VibelyBridge", "scanLocalTracks falhou", e)
        }
        return arr.toString()
    }

    @JavascriptInterface
    fun hasLocalMusicPermission(): Boolean {
        val perm = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU)
            android.Manifest.permission.READ_MEDIA_AUDIO
        else android.Manifest.permission.READ_EXTERNAL_STORAGE
        return androidx.core.content.ContextCompat.checkSelfPermission(context, perm) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    @JavascriptInterface
    fun requestLocalMusicPermission() {
        (context as? MainActivity)?.requestLocalMusicPermission()
    }

    // ─── Galeria de imagens do dispositivo (para escolher capa de faixa local) ───
    @JavascriptInterface
    fun hasImagesPermission(): Boolean {
        val perm = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU)
            android.Manifest.permission.READ_MEDIA_IMAGES
        else android.Manifest.permission.READ_EXTERNAL_STORAGE
        return androidx.core.content.ContextCompat.checkSelfPermission(context, perm) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    @JavascriptInterface
    fun requestImagesPermission() {
        (context as? MainActivity)?.requestImagesPermission()
    }

    // Lista as imagens do dispositivo (mais recentes primeiro) para o grid do modal "Escolher capa".
    @JavascriptInterface
    fun listDeviceImages(limit: Int): String {
        val arr = JSONArray()
        val media = android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(android.provider.MediaStore.Images.Media._ID, android.provider.MediaStore.Images.Media.DATE_ADDED)
        try {
            context.contentResolver.query(
                media, projection, null, null,
                "${android.provider.MediaStore.Images.Media.DATE_ADDED} DESC LIMIT ${limit.coerceIn(1, 300)}"
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media._ID)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    arr.put(JSONObject().apply {
                        put("id", id.toString())
                        put("thumbUrl", "http://localhost:8080/deviceimage?id=$id&thumb=1")
                        put("fullUrl", "http://localhost:8080/deviceimage?id=$id")
                    })
                }
            }
        } catch (e: SecurityException) {
            Log.w("VibelyBridge", "listDeviceImages: sem permissão")
        } catch (e: Exception) {
            Log.e("VibelyBridge", "listDeviceImages falhou", e)
        }
        return arr.toString()
    }

    // Abre o picker nativo do sistema (botão "Dispositivo" no modal). O resultado volta
    // via MainActivity.onActivityResult -> window.onNativeImagePicked(uri) no WebView.
    @JavascriptInterface
    fun openSystemImagePicker() {
        (context as? MainActivity)?.openSystemImagePicker()
    }

    // Define a imagem escolhida (content:// URI, tanto do grid como do picker do sistema)
    // como capa de uma faixa local. Guardada só localmente, como pedido.
    @JavascriptInterface
    fun setTrackCover(trackId: String, imageContentUri: String): Boolean {
        return try {
            prefs.setCustomCover(trackId, imageContentUri)
            true
        } catch (e: Exception) {
            Log.e("VibelyBridge", "setTrackCover falhou: ${e.message}")
            false
        }
    }

    // ─── Podcasts: iTunes Search API (descoberta) + RSS direto (episódios), sem token ───
    @JavascriptInterface
    fun searchPodcasts(query: String): String = podcasts.search(query)

    @JavascriptInterface
    fun featuredPodcasts(): String = podcasts.featured()

    @JavascriptInterface
    fun getPodcastEpisodes(feedUrl: String): String = podcasts.episodes(feedUrl)
}

object PlaybackServiceInstance {
    @Volatile
    var instance: PlaybackService? = null
}

object MainActivityInstance {
    @Volatile
    var instance: MainActivity? = null
}
package com.vibely.music.app

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.util.Log
import android.webkit.JavascriptInterface
import androidx.core.content.FileProvider
import org.json.JSONArray

class AndroidBridge(private val context: Context) {

    private val prefs = PreferencesStore(context)
    private val downloads = DownloadManager(context)
    private val bluetooth = BluetoothManager(context)

    @JavascriptInterface
    fun isInsideApp(): Boolean = true

    // ─── Estado da barra de status (chamado da app quando o tema muda) ───
    @JavascriptInterface
    fun setStatusBarTheme(lightIcons: Boolean) {
        (context as? MainActivity)?.setStatusBarIcons(lightIcons)
    }

    // ─── Preferências persistentes (sobrevivem a limpeza de cache do WebView) ───
    @JavascriptInterface
    fun getPreferences(): String {
        val map = prefs.getAll()
        val json = org.json.JSONObject()
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

    // ─── Downloads persistentes reais (ficam guardados no armazenamento da app) ───
    @JavascriptInterface
    fun downloadTrack(videoId: String, title: String, quality: String) {
        Thread {
            try {
                val server = "http://localhost:8080"
                val streamRes = java.net.URL("$server/stream?id=$videoId&quality=$quality").readText()
                val streamUrl = org.json.JSONObject(streamRes).optString("streamUrl")
                if (streamUrl.isNotEmpty()) {
                    downloads.download(videoId, streamUrl, emptyMap()) { success ->
                        val intent = Intent("com.vibely.music.app.DOWNLOAD_RESULT").apply {
                            setPackage(context.packageName)
                            putExtra("id", videoId)
                            putExtra("success", success)
                        }
                        context.sendBroadcast(intent)
                    }
                }
            } catch (e: Exception) {
                Log.e("VibelyBridge", "downloadTrack falhou: ${e.message}")
            }
        }.start()
    }

    @JavascriptInterface
    fun removeDownload(videoId: String): Boolean = downloads.remove(videoId)

    @JavascriptInterface
    fun isDownloaded(videoId: String): Boolean = downloads.isDownloaded(videoId)

    // file:// é bloqueado pelo WebView (a página é https), por isso o download é servido
    // pelo LocalServer em /downloaded, que suporta Range (seek) e volta a funcionar offline.
    @JavascriptInterface
    fun downloadedFileUrl(videoId: String): String {
        val file = downloads.fileFor(videoId)
        return if (file.exists() && file.length() > 0) "http://localhost:8080/downloaded?id=$videoId" else ""
    }

    // ─── Bluetooth: dispositivos emparelhados reais ───
    @JavascriptInterface
    fun scanDevices(): String = bluetooth.listPairedDevices()

    @JavascriptInterface
    fun connectDevice(deviceId: String): Boolean = bluetooth.connect(deviceId)

    @JavascriptInterface
    fun disconnectDevice(deviceId: String): Boolean = true // gerido pelo sistema Android

    @JavascriptInterface
    fun openBluetoothSettings() {
        val intent = Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    // ─── Partilha nativa (usa o share sheet real do Android) ───
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
            try {
                context.startActivity(intent)
                return
            } catch (e: Exception) {
                intent.setPackage(null) // app não instalada: cai para o chooser genérico
            }
        }

        val chooser = Intent.createChooser(intent, "Partilhar via").apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
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

    // ─── Partilha de ficheiro descarregado (ex: enviar o áudio por WhatsApp) ───
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
        val chooser = Intent.createChooser(intent, "Enviar áudio").apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(chooser)
    }

    // ─── Notificação nativa / MediaSession: chamado a cada mudança de faixa/estado ───
    // Corre fora da thread do WebView (as chamadas @JavascriptInterface já vêm de uma
    // thread própria), por isso é seguro falar diretamente com o serviço.
    @JavascriptInterface
    fun updateNowPlaying(title: String, artist: String, thumbnailUrl: String, isPlaying: Boolean, positionMs: Long, durationMs: Long) {
        val service = PlaybackServiceInstance.instance
        if (service == null) {
            Log.w("VibelyBridge", "updateNowPlaying: serviço ainda não está pronto")
            return
        }
        service.updateNowPlaying(title, artist, thumbnailUrl, isPlaying, positionMs, durationMs)
    }

    // ─── Músicas locais do aparelho ───
    // Devolve título, artista, ÁLBUM e capa. O áudio e a capa são servidos pelo LocalServer
    // (localhost:8080), porque o WebView (origem https) não consegue abrir content:// diretamente.
    @JavascriptInterface
    fun getLocalTracks(): String {
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
                    val artist = cursor.getString(artistCol)?.takeIf { it.isNotBlank() && it != "<unknown>" } ?: "Artista desconhecido"
                    val album = cursor.getString(albumCol)?.takeIf { it.isNotBlank() && it != "<unknown>" } ?: ""
                    arr.put(org.json.JSONObject().apply {
                        put("id", "local_$id")
                        put("title", cursor.getString(titleCol) ?: "Sem título")
                        put("artist", artist)
                        put("album", album)
                        put("duration", (cursor.getLong(durCol) / 1000))
                        put("localUri", "http://localhost:8080/local?id=local_$id")
                        put("thumbnail", "http://localhost:8080/cover?id=local_$id")
                        put("isLocal", true)
                    })
                }
            }
        } catch (e: SecurityException) {
            Log.w("VibelyBridge", "getLocalTracks: sem permissão de áudio")
        } catch (e: Exception) {
            Log.e("VibelyBridge", "getLocalTracks falhou", e)
        }
        return arr.toString()
    }

    // O JS pergunta antes de listar: evita mostrar "nenhuma música" quando na verdade falta permissão.
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
}

// Ponte simples para falar com o PlaybackService já em execução sem precisar de bind complexo
object PlaybackServiceInstance {
    @Volatile
    var instance: PlaybackService? = null
}
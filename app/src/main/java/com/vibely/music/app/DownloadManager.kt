package com.vibely.music.app

import android.content.Context
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.concurrent.TimeUnit

// Guarda os áudios descarregados na pasta privada da app (sobrevive a reinícios,
// não precisa de permissão de escrita em armazenamento partilhado no Android 10+).
class DownloadManager(private val context: Context) {

    private val tag = "VibelyDownloads"

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val downloadsDir: File
        get() = File(context.filesDir, "downloads").apply { mkdirs() }

    fun fileFor(videoId: String): File = File(downloadsDir, "$videoId.audio")

    fun isDownloaded(videoId: String): Boolean = fileFor(videoId).exists() && fileFor(videoId).length() > 0

    fun download(videoId: String, streamUrl: String, headers: Map<String, String>, onResult: (Boolean) -> Unit) {
        Thread {
            try {
                val rb = Request.Builder().url(streamUrl)
                headers.forEach { (k, v) -> rb.header(k, v) }
                http.newCall(rb.build()).execute().use { resp ->
                    if (!resp.isSuccessful) {
                        Log.e(tag, "Download falhou: ${resp.code}")
                        onResult(false)
                        return@Thread
                    }
                    val out = fileFor(videoId)
                    resp.body?.byteStream()?.use { input ->
                        out.outputStream().use { output -> input.copyTo(output) }
                    }
                    Log.d(tag, "Download concluído: $videoId (${out.length()} bytes)")
                    onResult(true)
                }
            } catch (e: Exception) {
                Log.e(tag, "Erro no download: ${e.message}")
                onResult(false)
            }
        }.start()
    }

    fun remove(videoId: String): Boolean = fileFor(videoId).delete()

    fun totalSizeBytes(): Long = downloadsDir.listFiles()?.sumOf { it.length() } ?: 0L
}
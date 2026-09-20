package com.vibely.music.app

import android.content.Context
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Response as NPResponse
import org.schabi.newpipe.extractor.downloader.Request as NPRequest
import org.schabi.newpipe.extractor.search.SearchInfo
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import java.util.concurrent.TimeUnit

class MusicExtractor(private val context: Context) {

    private val tag = "VibelyExtract"

    init {
        NewPipe.init(OkHttpDownloader())
    }

    private val youtube = ServiceList.YouTube

    private val userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .followRedirects(true)
        .build()

    // Cache mais generoso agora (10 min): reduz reextrações repetidas da mesma música
    // (menos invocações do processo Python = menos calor/bateria), mas ainda revalidamos
    // sempre a URL de verdade antes de a devolver, porque ela pode expirar antes disso.
    private val urlCache = HashMap<String, Pair<StreamSource, Long>>()
    private val cacheTtl = 10L * 60 * 1000 // 10 min

    private val debugLog = ArrayList<String>()

    @Volatile private var ytdlpReady = false
    @Volatile private var ytdlpInitError: String? = null

    data class StreamSource(
        val url: String,
        val mime: String,
        val headers: Map<String, String>,
        val origin: String
    )

    private fun note(msg: String) {
        Log.d(tag, msg)
        synchronized(debugLog) {
            debugLog.add(msg)
            if (debugLog.size > 80) debugLog.removeAt(0)
        }
    }

    @Synchronized
    fun initYtDlp() {
        if (ytdlpReady) return
        try {
            YoutubeDL.getInstance().init(context.applicationContext)
            ytdlpReady = true
            ytdlpInitError = null
            note("yt-dlp inicializado")
        } catch (e: Throwable) {
            ytdlpInitError = "${e.javaClass.simpleName}: ${e.message}"
            note("yt-dlp NÃO inicializou: $ytdlpInitError")
        }
    }

    fun updateYtDlp() {
        try {
            val status = YoutubeDL.getInstance().updateYoutubeDL(
                context.applicationContext,
                YoutubeDL.UpdateChannel.STABLE
            )
            note("yt-dlp update: $status")
        } catch (e: Throwable) {
            note("yt-dlp update falhou: ${e.message}")
        }
    }

    fun debugReport(): String {
        val sb = StringBuilder()
        sb.append("yt-dlp pronto: $ytdlpReady\n")
        if (ytdlpInitError != null) sb.append("yt-dlp erro de init: $ytdlpInitError\n")
        sb.append("--- últimos eventos ---\n")
        synchronized(debugLog) { debugLog.forEach { sb.append(it).append('\n') } }
        return sb.toString()
    }

    fun search(query: String): String {
        val handler = youtube.searchQHFactory.fromQuery(query)
        val info = SearchInfo.getInfo(youtube, handler)
        val arr = JSONArray()
        for (item in info.relatedItems) {
            if (item !is StreamInfoItem) continue
            val id = extractId(item.url)
            if (id.isEmpty()) continue
            arr.put(JSONObject().apply {
                put("id", id)
                put("title", item.name ?: "")
                put("artist", item.uploaderName ?: "")
                put("duration", item.duration)
                put("thumbnail", item.thumbnails?.lastOrNull()?.url ?: "")
                put("url", item.url ?: "")
                put("views", formatViews(item.viewCount))
                put("uploadDate", item.textualUploadDate ?: "")
            })
            if (arr.length() >= 25) break
        }
        return arr.toString()
    }

    fun getRelated(videoId: String): String {
        val url = "https://www.youtube.com/watch?v=$videoId"
        val info = StreamInfo.getInfo(youtube, url)
        val arr = JSONArray()
        for (item in info.relatedItems) {
            if (item !is StreamInfoItem) continue
            val id = extractId(item.url)
            if (id.isEmpty()) continue
            arr.put(JSONObject().apply {
                put("id", id)
                put("title", item.name ?: "")
                put("artist", item.uploaderName ?: "")
                put("duration", item.duration)
                put("thumbnail", item.thumbnails?.lastOrNull()?.url ?: "")
                put("url", item.url ?: "")
            })
            if (arr.length() >= 20) break
        }
        return arr.toString()
    }

    @Synchronized
    fun getStreamSource(videoId: String): StreamSource? {
        val now = System.currentTimeMillis()

        urlCache[videoId]?.let { (src, time) ->
            if (now - time < cacheTtl) {
                if (validate(src)) {
                    note("cache HIT revalidado para $videoId")
                    return src
                } else {
                    note("cache STALE para $videoId — refazendo extração")
                    urlCache.remove(videoId)
                }
            } else {
                urlCache.remove(videoId)
            }
        }

        note("=== extraindo $videoId via yt-dlp ===")
        val candidates = fromYtDlp(videoId)
        note("yt-dlp devolveu ${candidates.size} candidato(s)")

        for (c in candidates) {
            if (validate(c)) {
                note("OK via ${c.origin} (${c.mime})")
                urlCache[videoId] = Pair(c, now)
                return c
            } else {
                note("candidato de ${c.origin} recusado na validação")
            }
        }

        note("yt-dlp não devolveu stream válido para $videoId")
        return null
    }

    @Synchronized
    fun invalidate(videoId: String) {
        urlCache.remove(videoId)
    }

    private fun validate(src: StreamSource): Boolean {
        return try {
            val rb = Request.Builder().url(src.url).header("Range", "bytes=0-1")
            src.headers.forEach { (k, v) -> rb.header(k, v) }
            val call = http.newBuilder()
                .connectTimeout(5, TimeUnit.SECONDS)
                .readTimeout(5, TimeUnit.SECONDS)
                .build()
                .newCall(rb.build())
            call.execute().use { r ->
                val ok = r.code == 200 || r.code == 206
                if (!ok) note("validate ${src.origin}: HTTP ${r.code}")
                ok
            }
        } catch (e: Exception) {
            note("validate ${src.origin}: ${e.javaClass.simpleName}: ${e.message}")
            false
        }
    }

    // yt-dlp: uma só tentativa direta (android_vr, o cliente mais confiável nos testes).
    // Menos invocações do processo Python = extração mais rápida e menos aquecimento.
    // Só cai para o cliente padrão se a primeira tentativa falhar de vez.
    private fun fromYtDlp(videoId: String): List<StreamSource> {
        if (!ytdlpReady) initYtDlp()
        if (!ytdlpReady) {
            note("yt-dlp indisponível: $ytdlpInitError")
            return emptyList()
        }

        val attempts = listOf(
            "android_vr" to "youtube:player_client=android_vr"
        )

        for ((label, extractorArgs) in attempts) {
            val url = runYtDlp(videoId, extractorArgs, label)
            if (url != null) {
                return listOf(
                    StreamSource(
                        url = url,
                        mime = if (url.contains("mime=audio%2Fwebm")) "audio/webm" else "audio/mp4",
                        headers = mapOf("User-Agent" to userAgent),
                        origin = "yt-dlp($label)"
                    )
                )
            }
        }

        // Falhou o cliente rápido: tenta o padrão como último recurso
        val fallback = runYtDlp(videoId, null, "padrão")
        if (fallback != null) {
            return listOf(
                StreamSource(
                    url = fallback,
                    mime = if (fallback.contains("mime=audio%2Fwebm")) "audio/webm" else "audio/mp4",
                    headers = mapOf("User-Agent" to userAgent),
                    origin = "yt-dlp(padrão)"
                )
            )
        }
        return emptyList()
    }

    private fun runYtDlp(videoId: String, extractorArgs: String?, label: String): String? {
        return try {
            val request = YoutubeDLRequest("https://www.youtube.com/watch?v=$videoId")
            // abr<=96: limite de bitrate mais baixo — poupa dados móveis e reduz
            // o volume transferido/processado (menos calor no aparelho)
            request.addOption("-f", "bestaudio[ext=m4a][abr<=96]/bestaudio[abr<=96]/bestaudio[ext=m4a]/bestaudio")
            request.addOption("--no-playlist")
            request.addOption("--no-warnings")
            // timeout mais curto: falha rápido em vez de ficar pendurado, acelera a cascata
            request.addOption("--socket-timeout", "8")
            if (extractorArgs != null) request.addOption("--extractor-args", extractorArgs)
            request.addOption("-g")

            val response = YoutubeDL.getInstance().execute(request)
            val url = response.out.trim().lines().firstOrNull { it.startsWith("http") }
            if (url != null) {
                note("yt-dlp ($label) devolveu URL")
            } else {
                note("yt-dlp ($label) sem URL. stderr: ${response.err.take(300)}")
            }
            url
        } catch (e: Throwable) {
            note("yt-dlp ($label) erro: ${e.javaClass.simpleName}: ${e.message?.take(300)}")
            null
        }
    }

    private fun extractId(url: String?): String {
        if (url.isNullOrEmpty()) return ""
        val regex = Regex("[?&]v=([^&]+)")
        return regex.find(url)?.groupValues?.get(1) ?: url.substringAfterLast("/")
    }

    private fun formatViews(views: Long): String {
        if (views <= 0) return ""
        return when {
            views >= 1_000_000_000 -> "%.1fB".format(views / 1_000_000_000.0)
            views >= 1_000_000 -> "%.1fM".format(views / 1_000_000.0)
            views >= 1_000 -> "%.1fK".format(views / 1_000.0)
            else -> views.toString()
        }
    }
}

private class OkHttpDownloader : Downloader() {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    override fun execute(request: NPRequest): NPResponse {
        val rb = Request.Builder().url(request.url())

        request.headers().forEach { (name, values) ->
            values.forEach { rb.addHeader(name, it) }
        }
        rb.header(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        )

        when (request.httpMethod()) {
            "GET" -> rb.get()
            "POST" -> {
                val body = (request.dataToSend() ?: ByteArray(0))
                    .toRequestBody("application/octet-stream".toMediaTypeOrNull())
                rb.post(body)
            }
            else -> rb.method(request.httpMethod(), null)
        }

        val response = client.newCall(rb.build()).execute()
        return NPResponse(
            response.code,
            response.message,
            response.headers.toMultimap(),
            response.body?.string() ?: "",
            response.request.url.toString()
        )
    }
}
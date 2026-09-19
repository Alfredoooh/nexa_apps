package com.vibely.music.app

import android.content.Context
import android.util.Log
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

    // Cache das URLs de áudio já validadas
    private val urlCache = HashMap<String, Pair<StreamSource, Long>>()
    private val cacheTtl = 90L * 60 * 1000 // 90 min

    // Diário de tudo que aconteceu na última extração (lido pelo /debug)
    private val debugLog = ArrayList<String>()

    private val pipedInstances = listOf(
        "https://pipedapi.kavin.rocks",
        "https://pipedapi.adminforge.de",
        "https://api.piped.private.coffee",
        "https://pipedapi.reallyaweso.me",
        "https://pipedapi.darkness.services"
    )
    private val invidiousInstances = listOf(
        "https://inv.nadeko.net",
        "https://yewtu.be",
        "https://invidious.nerdvpn.de",
        "https://invidious.privacyredirect.com"
    )

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

    fun debugReport(): String {
        val sb = StringBuilder()
        sb.append("--- últimos eventos ---\n")
        synchronized(debugLog) { debugLog.forEach { sb.append(it).append('\n') } }
        return sb.toString()
    }

    // ─── BUSCA ───────────────────────────────────────────────
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

    // ─── STREAM: VÁRIOS MÉTODOS EM CASCATA ───────────────────
    @Synchronized
    fun getStreamSource(videoId: String): StreamSource? {
        val now = System.currentTimeMillis()
        urlCache[videoId]?.let { (src, time) ->
            if (now - time < cacheTtl) return src
        }

        note("=== extraindo $videoId ===")

        val methods: List<Pair<String, () -> List<StreamSource>>> = listOf(
            "NewPipe" to { fromNewPipe(videoId) },
            "InnerTube-ANDROID_VR" to { fromInnerTube(videoId, InnerClient.ANDROID_VR) },
            "InnerTube-ANDROID" to { fromInnerTube(videoId, InnerClient.ANDROID) },
            "InnerTube-IOS" to { fromInnerTube(videoId, InnerClient.IOS) },
            "Piped" to { fromPiped(videoId) },
            "Invidious" to { fromInvidious(videoId) }
        )

        for ((name, method) in methods) {
            val candidates = try {
                method()
            } catch (e: Throwable) {
                note("$name FALHOU: ${e.javaClass.simpleName}: ${e.message}")
                emptyList()
            }
            note("$name devolveu ${candidates.size} candidato(s)")

            for (c in candidates) {
                if (validate(c)) {
                    note("OK via ${c.origin} (${c.mime})")
                    urlCache[videoId] = Pair(c, now)
                    return c
                } else {
                    note("candidato de ${c.origin} recusado na validação")
                }
            }
        }

        note("NENHUM método funcionou para $videoId")
        return null
    }

    @Synchronized
    fun invalidate(videoId: String) {
        urlCache.remove(videoId)
    }

    // Testa a URL de verdade: pede 2 bytes. Se não devolver 200/206, descarta.
    private fun validate(src: StreamSource): Boolean {
        return try {
            val rb = Request.Builder().url(src.url).header("Range", "bytes=0-1")
            src.headers.forEach { (k, v) -> rb.header(k, v) }
            http.newCall(rb.build()).execute().use { r ->
                val ok = r.code == 200 || r.code == 206
                if (!ok) note("validate ${src.origin}: HTTP ${r.code}")
                ok
            }
        } catch (e: Exception) {
            note("validate ${src.origin}: ${e.message}")
            false
        }
    }

    // Método 1: NewPipeExtractor
    private fun fromNewPipe(videoId: String): List<StreamSource> {
        val info = StreamInfo.getInfo(youtube, "https://www.youtube.com/watch?v=$videoId")
        return info.audioStreams
            .filter { !it.content.isNullOrEmpty() && it.isUrl }
            .sortedWith(
                compareByDescending<org.schabi.newpipe.extractor.stream.AudioStream> {
                    it.format?.suffix == "m4a"
                }.thenByDescending { it.averageBitrate }
            )
            .map {
                StreamSource(
                    url = it.content,
                    mime = mimeFor(it.format?.suffix),
                    headers = mapOf("User-Agent" to userAgent),
                    origin = "NewPipe"
                )
            }
    }

    // Métodos 2-4: InnerTube direto com clientes que devolvem URL sem cifra
    private enum class InnerClient(
        val clientName: String,
        val clientVersion: String,
        val clientId: String,
        val userAgent: String,
        val extra: Map<String, Any>
    ) {
        ANDROID_VR(
            "ANDROID_VR", "1.60.19", "28",
            "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
            mapOf("deviceMake" to "Oculus", "deviceModel" to "Quest 3", "androidSdkVersion" to 32, "osName" to "Android", "osVersion" to "12L")
        ),
        ANDROID(
            "ANDROID", "19.44.38", "3",
            "com.google.android.youtube/19.44.38 (Linux; U; Android 14) gzip",
            mapOf("androidSdkVersion" to 34, "osName" to "Android", "osVersion" to "14")
        ),
        IOS(
            "IOS", "19.45.4", "5",
            "com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)",
            mapOf("deviceMake" to "Apple", "deviceModel" to "iPhone16,2", "osName" to "iPhone", "osVersion" to "18.1.0.22B83")
        )
    }

    private fun fromInnerTube(videoId: String, client: InnerClient): List<StreamSource> {
        val clientJson = JSONObject().apply {
            put("clientName", client.clientName)
            put("clientVersion", client.clientVersion)
            put("hl", "pt")
            put("gl", "BR")
            client.extra.forEach { (k, v) -> put(k, v) }
        }
        val body = JSONObject().apply {
            put("videoId", videoId)
            put("contentCheckOk", true)
            put("racyCheckOk", true)
            put("context", JSONObject().put("client", clientJson))
            put("playbackContext", JSONObject().put(
                "contentPlaybackContext", JSONObject().put("html5Preference", "HTML5_PREF_WANTS")
            ))
        }

        val req = Request.Builder()
            .url("https://www.youtube.com/youtubei/v1/player?prettyPrint=false")
            .header("User-Agent", client.userAgent)
            .header("X-YouTube-Client-Name", client.clientId)
            .header("X-YouTube-Client-Version", client.clientVersion)
            .header("Origin", "https://www.youtube.com")
            .post(body.toString().toRequestBody("application/json".toMediaTypeOrNull()))
            .build()

        val text = http.newCall(req).execute().use { it.body?.string() ?: "" }
        if (text.isEmpty()) return emptyList()

        val json = JSONObject(text)
        val status = json.optJSONObject("playabilityStatus")?.optString("status")
        if (status != null && status != "OK") {
            note("InnerTube ${client.clientName}: playabilityStatus=$status")
            return emptyList()
        }

        val formats = json.optJSONObject("streamingData")?.optJSONArray("adaptiveFormats")
            ?: return emptyList()

        val list = ArrayList<Triple<String, String, Int>>()
        for (i in 0 until formats.length()) {
            val f = formats.getJSONObject(i)
            val mime = f.optString("mimeType")
            if (!mime.startsWith("audio/")) continue
            val url = f.optString("url")
            if (url.isEmpty()) continue
            list.add(Triple(url, mime, f.optInt("bitrate")))
        }

        return list
            .sortedWith(
                compareByDescending<Triple<String, String, Int>> { it.second.contains("mp4") }
                    .thenByDescending { it.third }
            )
            .map {
                StreamSource(
                    url = it.first,
                    mime = it.second.substringBefore(";"),
                    headers = mapOf("User-Agent" to client.userAgent),
                    origin = "InnerTube-${client.clientName}"
                )
            }
    }

    // Método 5: Piped
    private fun fromPiped(videoId: String): List<StreamSource> {
        for (base in pipedInstances) {
            try {
                val req = Request.Builder()
                    .url("$base/streams/$videoId")
                    .header("User-Agent", userAgent)
                    .build()
                val text = http.newCall(req).execute().use { if (it.isSuccessful) it.body?.string() else null }
                    ?: continue
                val streams = JSONObject(text).optJSONArray("audioStreams") ?: continue

                val list = ArrayList<Triple<String, String, Int>>()
                for (i in 0 until streams.length()) {
                    val s = streams.getJSONObject(i)
                    val url = s.optString("url")
                    if (url.isEmpty()) continue
                    list.add(Triple(url, s.optString("mimeType", "audio/mp4"), s.optInt("bitrate")))
                }
                if (list.isEmpty()) continue

                return list
                    .sortedWith(
                        compareByDescending<Triple<String, String, Int>> { it.second.contains("mp4") }
                            .thenByDescending { it.third }
                    )
                    .map { StreamSource(it.first, it.second, mapOf("User-Agent" to userAgent), "Piped($base)") }
            } catch (e: Exception) {
                note("Piped $base: ${e.message}")
            }
        }
        return emptyList()
    }

    // Método 6: Invidious
    private fun fromInvidious(videoId: String): List<StreamSource> {
        for (base in invidiousInstances) {
            try {
                val req = Request.Builder()
                    .url("$base/api/v1/videos/$videoId?fields=adaptiveFormats")
                    .header("User-Agent", userAgent)
                    .build()
                val text = http.newCall(req).execute().use { if (it.isSuccessful) it.body?.string() else null }
                    ?: continue
                val formats = JSONObject(text).optJSONArray("adaptiveFormats") ?: continue

                val list = ArrayList<Triple<String, String, Int>>()
                for (i in 0 until formats.length()) {
                    val f = formats.getJSONObject(i)
                    val type = f.optString("type")
                    if (!type.startsWith("audio/")) continue
                    val url = f.optString("url")
                    if (url.isEmpty()) continue
                    list.add(Triple(url, type.substringBefore(";"), f.optString("bitrate").toIntOrNull() ?: 0))
                }
                if (list.isEmpty()) continue

                return list
                    .sortedWith(
                        compareByDescending<Triple<String, String, Int>> { it.second.contains("mp4") }
                            .thenByDescending { it.third }
                    )
                    .map { StreamSource(it.first, it.second, mapOf("User-Agent" to userAgent), "Invidious($base)") }
            } catch (e: Exception) {
                note("Invidious $base: ${e.message}")
            }
        }
        return emptyList()
    }

    private fun mimeFor(suffix: String?): String = when (suffix) {
        "m4a" -> "audio/mp4"
        "webm" -> "audio/webm"
        "opus" -> "audio/ogg"
        else -> "audio/mp4"
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
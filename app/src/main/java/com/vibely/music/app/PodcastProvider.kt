package com.vibely.music.app

import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.StringReader
import java.util.concurrent.TimeUnit

// Podcasts 100% sem token: descoberta via iTunes Search API (pública, gratuita,
// sem chave) e episódios via leitura direta do feed RSS de cada podcast.
class PodcastProvider {

    private val tag = "VibelyPodcasts"

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val searchCache = HashMap<String, Pair<String, Long>>()
    private val episodesCache = HashMap<String, Pair<String, Long>>()
    private val cacheTtl = 15L * 60 * 1000

    // ─── Descoberta: iTunes Search API (sem token) ───
    fun search(query: String, limit: Int = 30): String {
        val cacheKey = "search|$query|$limit"
        searchCache[cacheKey]?.let { (json, time) ->
            if (System.currentTimeMillis() - time < cacheTtl) return json
        }

        val arr = JSONArray()
        try {
            val url = "https://itunes.apple.com/search?term=${java.net.URLEncoder.encode(query, "UTF-8")}" +
                "&entity=podcast&limit=$limit"
            val body = fetch(url) ?: return arr.toString()
            val root = JSONObject(body)
            val results = root.optJSONArray("results") ?: JSONArray()
            for (i in 0 until results.length()) {
                val item = results.getJSONObject(i)
                arr.put(JSONObject().apply {
                    put("id", item.optLong("collectionId").toString())
                    put("title", item.optString("collectionName"))
                    put("author", item.optString("artistName"))
                    put("thumbnail", item.optString("artworkUrl600", item.optString("artworkUrl100")))
                    put("feedUrl", item.optString("feedUrl"))
                    put("genre", item.optString("primaryGenreName"))
                    put("episodeCount", item.optInt("trackCount"))
                })
            }
        } catch (e: Exception) {
            Log.e(tag, "search falhou: ${e.message}")
        }

        val json = arr.toString()
        searchCache[cacheKey] = Pair(json, System.currentTimeMillis())
        return json
    }

    // Aproximação de "populares": a iTunes Search API não tem endpoint de
    // trending público sem token, por isso usa-se um termo genérico.
    fun featured(): String = search("podcast", 30)

    // ─── Episódios: lê o RSS do podcast diretamente (sem token) ───
    fun episodes(feedUrl: String, limit: Int = 50): String {
        val cacheKey = "ep|$feedUrl|$limit"
        episodesCache[cacheKey]?.let { (json, time) ->
            if (System.currentTimeMillis() - time < cacheTtl) return json
        }

        val arr = JSONArray()
        try {
            val xml = fetch(feedUrl) ?: return arr.toString()
            val factory = XmlPullParserFactory.newInstance()
            factory.isNamespaceAware = true
            val parser = factory.newPullParser()
            parser.setInput(StringReader(xml))

            var eventType = parser.eventType
            var inItem = false
            var title = ""; var audioUrl = ""; var duration = ""; var pubDate = ""
            var description = ""; var episodeImage = ""
            var podcastImage = ""

            loop@ while (eventType != XmlPullParser.END_DOCUMENT) {
                when (eventType) {
                    XmlPullParser.START_TAG -> {
                        when (parser.name) {
                            "item" -> {
                                inItem = true; title = ""; audioUrl = ""; duration = ""
                                pubDate = ""; description = ""; episodeImage = ""
                            }
                            "title" -> if (inItem) title = safeNextText(parser)
                            "enclosure" -> if (inItem) {
                                val url = parser.getAttributeValue(null, "url")
                                val type = parser.getAttributeValue(null, "type") ?: ""
                                if (url != null && (type.startsWith("audio") || url.contains(".mp3") || url.contains(".m4a"))) {
                                    audioUrl = url
                                }
                            }
                            "duration" -> if (inItem && parser.namespace.contains("itunes")) duration = safeNextText(parser)
                            "pubDate" -> if (inItem) pubDate = safeNextText(parser)
                            "description" -> if (inItem && description.isEmpty()) description = safeNextText(parser)
                            "image" -> {
                                if (parser.namespace.contains("itunes")) {
                                    val href = parser.getAttributeValue(null, "href")
                                    if (href != null) { if (inItem) episodeImage = href else podcastImage = href }
                                }
                            }
                        }
                    }
                    XmlPullParser.END_TAG -> {
                        if (parser.name == "item") {
                            inItem = false
                            if (audioUrl.isNotEmpty()) {
                                arr.put(JSONObject().apply {
                                    put("title", title)
                                    put("audioUrl", audioUrl)
                                    put("duration", parseDurationToSeconds(duration))
                                    put("pubDate", pubDate)
                                    put("description", description.take(500))
                                    put("thumbnail", episodeImage.ifEmpty { podcastImage })
                                })
                            }
                            if (arr.length() >= limit) break@loop
                        }
                    }
                }
                eventType = parser.next()
            }
        } catch (e: Exception) {
            Log.e(tag, "episodes falhou: ${e.message}")
        }

        val json = arr.toString()
        episodesCache[cacheKey] = Pair(json, System.currentTimeMillis())
        return json
    }

    private fun safeNextText(parser: XmlPullParser): String =
        try { parser.nextText().trim() } catch (e: Exception) { "" }

    // Duração pode vir como "1234" (segundos) ou "01:23:45" (hh:mm:ss)
    private fun parseDurationToSeconds(raw: String): Int {
        if (raw.isBlank()) return 0
        if (raw.all { it.isDigit() }) return raw.toIntOrNull() ?: 0
        val parts = raw.split(":").map { it.toIntOrNull() ?: 0 }
        return when (parts.size) {
            3 -> parts[0] * 3600 + parts[1] * 60 + parts[2]
            2 -> parts[0] * 60 + parts[1]
            else -> 0
        }
    }

    private fun fetch(url: String): String? {
        return try {
            val request = Request.Builder().url(url)
                .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
                .build()
            http.newCall(request).execute().use { r ->
                if (!r.isSuccessful) { Log.w(tag, "fetch ${r.code} em $url"); return null }
                r.body?.string()
            }
        } catch (e: Exception) {
            Log.e(tag, "fetch falhou ($url): ${e.message}")
            null
        }
    }
}
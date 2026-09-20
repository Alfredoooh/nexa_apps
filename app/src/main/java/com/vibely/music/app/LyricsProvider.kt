package com.vibely.music.app

import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

// Usa a API pública lrclib.net (gratuita, sem chave necessária) para obter letras.
class LyricsProvider {

    private val http = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()

    fun fetch(title: String, artist: String): String {
        return try {
            val url = "https://lrclib.net/api/search?track_name=${java.net.URLEncoder.encode(title, "UTF-8")}" +
                "&artist_name=${java.net.URLEncoder.encode(artist, "UTF-8")}"
            val req = Request.Builder().url(url).header("User-Agent", "Vibely/1.0").build()
            val text = http.newCall(req).execute().use { if (it.isSuccessful) it.body?.string() else null } ?: return emptyResult()
            val arr = org.json.JSONArray(text)
            if (arr.length() == 0) return emptyResult()
            val first = arr.getJSONObject(0)
            JSONObject().apply {
                put("found", true)
                put("plainLyrics", first.optString("plainLyrics", ""))
                put("syncedLyrics", first.optString("syncedLyrics", ""))
            }.toString()
        } catch (e: Exception) {
            emptyResult()
        }
    }

    private fun emptyResult() = JSONObject().apply { put("found", false) }.toString()
}
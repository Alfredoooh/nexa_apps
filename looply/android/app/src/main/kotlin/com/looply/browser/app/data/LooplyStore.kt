package com.looply.browser.app.data

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Uses Flutter's original SharedPreferences file/key names so existing data remains readable. */
class LooplyStore(context: Context) {
    val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun getString(key: String, fallback: String = ""): String = prefs.getString(key, fallback) ?: fallback
    fun getBoolean(key: String, fallback: Boolean): Boolean = prefs.getBoolean(key, fallback)
    fun putString(key: String, value: String) { prefs.edit().putString(key, value).apply() }
    fun putBoolean(key: String, value: Boolean) { prefs.edit().putBoolean(key, value).apply() }

    fun readArray(key: String): JSONArray = try { JSONArray(getString("flutter.$key", "[]")) } catch (_: Exception) { JSONArray() }
    fun writeArray(key: String, value: JSONArray) = putString("flutter.$key", value.toString())

    fun addHistory(title: String, url: String, kind: String = "site") {
        if (url.isBlank()) return
        val array = readArray("looply_browsing_history_v1")
        if (array.length() > 0) {
            val last = array.optJSONObject(array.length() - 1)
            if (last?.optString("url") == url) {
                val lastAt = last.optString("timestamp")
                val lastMs = try { java.time.Instant.parse(lastAt).toEpochMilli() } catch (_: Exception) { 0L }
                if (System.currentTimeMillis() - lastMs < 3000L) return
            }
        }
        val item = JSONObject().put("kind", kind).put("title", title.ifBlank { url }).put("url", url)
            .put("timestamp", java.time.Instant.now().toString())
        array.put(item)
        while (array.length() > 200) array.remove(0)
        writeArray("looply_browsing_history_v1", array)
    }

    fun addBookmark(title: String, url: String) {
        if (url.isBlank()) return
        val array = readArray("looply_bookmarks_v1")
        for (i in 0 until array.length()) if (array.optJSONObject(i)?.optString("url") == url) return
        array.put(JSONObject().put("id", UUID.randomUUID().toString()).put("title", title.ifBlank { url })
            .put("url", url).put("createdAt", java.time.Instant.now().toString()))
        while (array.length() > 300) array.remove(0)
        writeArray("looply_bookmarks_v1", array)
    }

    fun removeArrayItem(key: String, index: Int) {
        val array = readArray(key)
        if (index in 0 until array.length()) array.remove(index)
        writeArray(key, array)
    }

    fun clearArray(key: String) = writeArray(key, JSONArray())

    fun addDownload(url: String, fileName: String, mime: String?) {
        val array = readArray("looply_download_requests_v1")
        array.put(JSONObject().put("id", UUID.randomUUID().toString()).put("url", url).put("filename", fileName)
            .put("mimeType", mime ?: JSONObject.NULL).put("createdAt", java.time.Instant.now().toString()))
        while (array.length() > 100) array.remove(0)
        writeArray("looply_download_requests_v1", array)
    }

    fun loadTabs(): MutableList<LooplyTab> {
        val result = mutableListOf<LooplyTab>()
        val raw = getString("flutter.looply_open_tabs_v1", "[]")
        try {
            val a = JSONArray(raw)
            for (i in 0 until a.length()) {
                val o = a.optJSONObject(i) ?: continue
                if (o.optString("kind") !in setOf("browser", "orbitBrowser")) continue
                val id = o.optString("id")
                val url = o.optString("url")
                if (id.isBlank() || url.isBlank() || url.startsWith("looply://")) continue
                result += LooplyTab(id, url, o.optString("title", url), false)
            }
        } catch (_: Exception) { }
        return result
    }

    fun saveTabs(tabs: List<LooplyTab>, activeId: String?) {
        val array = JSONArray()
        tabs.filterNot { it.incognito }.forEach { tab ->
            array.put(JSONObject().put("id", tab.id).put("kind", "browser").put("url", tab.url)
                .put("title", tab.title).put("isIncognito", false).put("lastActivity", java.time.Instant.now().toString()))
        }
        putString("flutter.looply_open_tabs_v1", array.toString())
        if (activeId != null && tabs.any { it.id == activeId && !it.incognito }) putString("flutter.looply_active_tab_v1", activeId)
        else prefs.edit().remove("flutter.looply_active_tab_v1").apply()
    }
}

data class LooplyTab(val id: String, var url: String, var title: String, val incognito: Boolean)

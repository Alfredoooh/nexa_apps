package com.vibely.music.app

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

private val Context.dataStore by preferencesDataStore(name = "vibely_prefs")

class PreferencesStore(private val context: Context) {

    private val keyTheme = stringPreferencesKey("theme")
    private val keyLang = stringPreferencesKey("lang")
    private val keyQuality = stringPreferencesKey("quality")
    private val keyDlQuality = stringPreferencesKey("dl_quality")
    private val keyWifiOnly = stringPreferencesKey("wifi_only")
    private val keySaveData = stringPreferencesKey("save_data")

    private val keyLocalTracksJson = stringPreferencesKey("local_tracks_json")
    private val keyLocalTracksCount = longPreferencesKey("local_tracks_count")

    // Capas locais escolhidas pelo usuário: mapa "local_<id>" -> content:// URI da imagem escolhida.
    // Guardado como um único JSON (chave -> uri) para não multiplicar chaves no DataStore.
    private val keyCustomCovers = stringPreferencesKey("custom_covers_json")

    fun getAll(): Map<String, String> = runBlocking {
        val prefs = context.dataStore.data.first()
        mapOf(
            "theme" to (prefs[keyTheme] ?: "system"),
            "lang" to (prefs[keyLang] ?: detectSystemLanguage()),
            "quality" to (prefs[keyQuality] ?: "auto"),
            "dlQuality" to (prefs[keyDlQuality] ?: "normal"),
            "wifiOnly" to (prefs[keyWifiOnly] ?: "false"),
            "saveData" to (prefs[keySaveData] ?: "false")
        )
    }

    fun set(key: String, value: String) = runBlocking {
        context.dataStore.edit { prefs ->
            when (key) {
                "theme" -> prefs[keyTheme] = value
                "lang" -> prefs[keyLang] = value
                "quality" -> prefs[keyQuality] = value
                "dlQuality" -> prefs[keyDlQuality] = value
                "wifiOnly" -> prefs[keyWifiOnly] = value
                "saveData" -> prefs[keySaveData] = value
            }
        }
    }

    fun getLocalTracksCache(): Pair<String?, Long?> = runBlocking {
        val prefs = context.dataStore.data.first()
        Pair(prefs[keyLocalTracksJson], prefs[keyLocalTracksCount])
    }

    fun setLocalTracksCache(json: String, count: Long) = runBlocking {
        context.dataStore.edit { prefs ->
            prefs[keyLocalTracksJson] = json
            prefs[keyLocalTracksCount] = count
        }
    }

    fun clearLocalTracksCache() = runBlocking {
        context.dataStore.edit { prefs ->
            prefs.remove(keyLocalTracksJson)
            prefs.remove(keyLocalTracksCount)
        }
    }

    fun getCustomCovers(): org.json.JSONObject = runBlocking {
        val prefs = context.dataStore.data.first()
        val raw = prefs[keyCustomCovers]
        if (raw.isNullOrEmpty()) org.json.JSONObject() else try { org.json.JSONObject(raw) } catch (e: Exception) { org.json.JSONObject() }
    }

    fun setCustomCover(trackId: String, contentUri: String) = runBlocking {
        context.dataStore.edit { prefs ->
            val current = prefs[keyCustomCovers]
            val obj = if (current.isNullOrEmpty()) org.json.JSONObject() else try { org.json.JSONObject(current) } catch (e: Exception) { org.json.JSONObject() }
            obj.put(trackId, contentUri)
            prefs[keyCustomCovers] = obj.toString()
        }
    }

    private fun detectSystemLanguage(): String {
        val sysLang = java.util.Locale.getDefault().language
        return when (sysLang) {
            "pt" -> "pt"
            "es" -> "es"
            "fr" -> "fr"
            else -> "en"
        }
    }

    fun isSystemDarkMode(): Boolean {
        val mode = context.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return mode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }
}
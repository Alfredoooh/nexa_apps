package com.vibely.music.app

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

private val Context.dataStore by preferencesDataStore(name = "vibely_prefs")

// Guarda as preferências do usuário (tema, idioma, qualidade, etc) de forma persistente
// e nativa, em vez de depender só do localStorage do WebView (que pode ser limpo pelo sistema).
class PreferencesStore(private val context: Context) {

    private val keyTheme = stringPreferencesKey("theme")
    private val keyLang = stringPreferencesKey("lang")
    private val keyQuality = stringPreferencesKey("quality")
    private val keyDlQuality = stringPreferencesKey("dl_quality")
    private val keyWifiOnly = stringPreferencesKey("wifi_only")
    private val keySaveData = stringPreferencesKey("save_data")

    // Cache da biblioteca local: guarda o JSON já montado e a contagem de faixas
    // vista da última vez, para não voltar a interrogar o MediaStore sempre que
    // o JS pede as músicas locais — só refaz quando o número de faixas muda.
    private val keyLocalTracksJson = stringPreferencesKey("local_tracks_json")
    private val keyLocalTracksCount = longPreferencesKey("local_tracks_count")

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

    // Devolve o cache (json, contagemGuardada) — ambos nulos se nunca foi gravado.
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

    // Deteta o idioma do sistema Android e mapeia para um dos suportados pela app
    private fun detectSystemLanguage(): String {
        val sysLang = java.util.Locale.getDefault().language
        return when (sysLang) {
            "pt" -> "pt"
            "es" -> "es"
            "fr" -> "fr"
            else -> "en"
        }
    }

    // true se o sistema estiver em modo escuro (usado quando a preferência é "system")
    fun isSystemDarkMode(): Boolean {
        val mode = context.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return mode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }
}
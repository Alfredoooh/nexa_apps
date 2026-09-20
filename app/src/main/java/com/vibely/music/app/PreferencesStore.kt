package com.vibely.music.app

import android.content.Context
import androidx.datastore.preferences.core.edit
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
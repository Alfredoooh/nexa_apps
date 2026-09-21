este foi a resposta da secção anterior 

Tenho tudo que preciso. Aqui vai tudo, completo, ficheiro a ficheiro.

## 1. `AndroidManifest.xml` (completo)

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" tools:targetApi="s"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>

    <uses-feature android:name="android.hardware.bluetooth" android:required="false"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.flash" android:required="false"/>

    <application
        android:name=".VibelyApp"
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.Vibely"
        android:usesCleartextTraffic="true"
        android:requestLegacyExternalStorage="true"
        android:extractNativeLibs="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:configChanges="orientation|screenSize|keyboardHidden|uiMode"
            android:theme="@style/Theme.Vibely.Splash">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <activity
            android:name=".CameraActivity"
            android:exported="false"
            android:theme="@style/Theme.Vibely"
            android:screenOrientation="portrait"/>

        <service
            android:name=".PlaybackService"
            android:exported="false"
            android:foregroundServiceType="mediaPlayback"/>

        <receiver android:name=".MediaButtonReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths"/>
        </provider>

    </application>
</manifest>
```

## 2. `app/build.gradle.kts` (completo)

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.vibely.music.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.vibely.music.app"
        minSdk = 24
        targetSdk = 35
        versionCode = 2
        versionName = "1.1"
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a")
            isUniversalApk = false
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions { jvmTarget = "17" }

    packaging { jniLibs { useLegacyPackaging = true } }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.github.TeamNewPipe:NewPipeExtractor:v0.24.4")
    implementation("org.nanohttpd:nanohttpd:2.3.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.3")

    // yt-dlp (apenas para obter a URL do stream de áudio do YouTube). ffmpeg removido: não é usado.
    implementation("io.github.junkfood02.youtubedl-android:library:0.17.2")

    // Splash screen nativo (fundo azul fixo + símbolo, Android 6+ e 12+)
    implementation("androidx.core:core-splashscreen:1.0.1")

    // Notificação nativa de media (MediaSession + estilo de notificação padrão do Android)
    implementation("androidx.media:media:1.7.0")

    // Preferências persistentes do usuário
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Câmera (preview nativo, controlo de flash/tocha)
    implementation("androidx.camera:camera-core:1.4.1")
    implementation("androidx.camera:camera-camera2:1.4.1")
    implementation("androidx.camera:camera-lifecycle:1.4.1")
    implementation("androidx.camera:camera-view:1.4.1")

    // Parsing de RSS de podcasts
    implementation("org.xmlpull:xmlpull:1.1.3.1")
    implementation("xpp3:xpp3:1.1.4c")
}
```

## 3. `CameraActivity.kt` (novo, completo)

```kotlin
package com.vibely.music.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale

// Activity nativa de câmera: só fotos (sem vídeo). O preview em si é 100% nativo
// (CameraX + PreviewView). A "aparência" do ecrã com a câmera aberta (botões,
// overlay, moldura) é desenhada por um WebView transparente sobreposto ao
// preview, carregando a mesma app web em modo câmera (?camera no fim da URL).
//
// Fluxo:
//  1. O JS chama Android.openCamera() (ver AndroidBridge.kt)
//  2. Esta Activity abre, arranca o preview nativo da câmera
//  3. O WebView transparente por cima desenha só a UI da câmera
//  4. Ao tirar foto, grava o ficheiro e devolve o caminho para a MainActivity
//     via window.onNativePhotoCaptured(uri) no WebView principal
class CameraActivity : AppCompatActivity() {

    private lateinit var previewView: PreviewView
    private lateinit var overlayWeb: android.webkit.WebView
    private lateinit var root: FrameLayout

    private var imageCapture: ImageCapture? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var torchOn = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        root = FrameLayout(this)
        setContentView(root)

        previewView = PreviewView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        root.addView(previewView)

        overlayWeb = android.webkit.WebView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            addJavascriptInterface(CameraBridge(), "AndroidCamera")
        }
        root.addView(overlayWeb)

        val appUrl = intent.getStringExtra("appUrl") ?: "https://vibelywebapp.onrender.com"
        val separator = if (appUrl.contains("?")) "&" else "?"
        overlayWeb.loadUrl("$appUrl${separator}camera=1")

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 2001)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2001) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera()
            } else {
                Log.w("VibelyCamera", "Permissão de câmera negada")
                finish()
            }
        }
    }

    private fun startCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            try {
                cameraProvider = providerFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .build()

                val selector = CameraSelector.DEFAULT_BACK_CAMERA
                cameraProvider?.unbindAll()
                camera = cameraProvider?.bindToLifecycle(this, selector, preview, imageCapture)
            } catch (e: Exception) {
                Log.e("VibelyCamera", "Falha ao iniciar câmera: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun hasFlashUnit(): Boolean = camera?.cameraInfo?.hasFlashUnit() == true

    private fun setTorch(on: Boolean): Boolean {
        val cam = camera ?: return false
        if (!hasFlashUnit()) return false
        return try {
            cam.cameraControl.enableTorch(on)
            torchOn = on
            true
        } catch (e: Exception) { false }
    }

    private fun takePhoto() {
        val capture = imageCapture ?: return
        val dir = File(cacheDir, "camera").apply { mkdirs() }
        val name = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(java.util.Date()) + ".jpg"
        val file = File(dir, name)
        val output = ImageCapture.OutputFileOptions.Builder(file).build()

        capture.takePicture(output, ContextCompat.getMainExecutor(this), object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(results: ImageCapture.OutputFileResults) {
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this@CameraActivity, "$packageName.fileprovider", file
                )
                runOnUiThread {
                    notifyMainWebView(uri.toString())
                    finish()
                }
            }

            override fun onError(exception: ImageCaptureException) {
                Log.e("VibelyCamera", "Erro ao capturar: ${exception.message}")
                runOnUiThread { finish() }
            }
        })
    }

    private fun notifyMainWebView(fileUriString: String) {
        val safe = fileUriString.replace("\\", "\\\\").replace("'", "\\'")
        val js = "(function(){try{if(window.onNativePhotoCaptured){window.onNativePhotoCaptured('$safe');}}catch(e){}})()"
        MainActivityInstance.instance?.let { activity ->
            activity.runOnUiThread { activity.evaluateInWebView(js) }
        }
    }

    override fun onDestroy() {
        try { if (torchOn) setTorch(false) } catch (_: Exception) {}
        cameraProvider?.unbindAll()
        super.onDestroy()
    }

    // Ponte JS exposta só ao overlay transparente desta Activity
    inner class CameraBridge {
        @android.webkit.JavascriptInterface
        fun isInsideApp(): Boolean = true

        @android.webkit.JavascriptInterface
        fun capture() { runOnUiThread { takePhoto() } }

        @android.webkit.JavascriptInterface
        fun hasFlash(): Boolean = hasFlashUnit()

        @android.webkit.JavascriptInterface
        fun toggleFlash(on: Boolean): Boolean = setTorch(on)

        @android.webkit.JavascriptInterface
        fun isFlashOn(): Boolean = torchOn

        @android.webkit.JavascriptInterface
        fun closeCamera() { runOnUiThread { finish() } }
    }
}
```

## 4. `PodcastProvider.kt` (novo, completo — com a correção do `return@let`)

```kotlin
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
```

## 5. `PreferencesStore.kt` (completo — cache da biblioteca local adicionada)

```kotlin
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
```

## 6. `AndroidBridge.kt` (completo)

```kotlin
package com.vibely.music.app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
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
    private val podcasts = PodcastProvider()

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

    // true se há alguma ligação de dados ativa (wifi ou móvel) — usado para decidir
    // se o WebView deve carregar a versão online ou cair para o assets/index.html offline.
    @JavascriptInterface
    fun isOnline(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    // ─── Volume do sistema (stream de música) ───
    @JavascriptInterface
    fun getVolume(): Int {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0
        return ((current.toFloat() / max) * 100).toInt()
    }

    // percent: 0-100
    @JavascriptInterface
    fun setVolume(percent: Int) {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val clamped = percent.coerceIn(0, 100)
        val target = ((clamped / 100f) * max).toInt().coerceIn(0, max)
        try {
            am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
        } catch (e: Exception) {
            Log.e("VibelyBridge", "setVolume falhou: ${e.message}")
        }
    }

    // ─── Câmera (só fotos) + flash ───
    @JavascriptInterface
    fun openCamera() {
        val activity = context as? MainActivity ?: return
        val intent = Intent(activity, CameraActivity::class.java)
        intent.putExtra("appUrl", activity.currentUrl())
        activity.startActivity(intent)
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
                        notifyEvent(
                            if (success) "Download concluído" else "Falha no download",
                            if (success) "$title está pronto para ouvir offline. Verifica na app Vibely." else "Não foi possível descarregar $title."
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e("VibelyBridge", "downloadTrack falhou: ${e.message}")
                notifyEvent("Falha no download", "Não foi possível descarregar $title.")
            }
        }.start()
    }

    @JavascriptInterface
    fun removeDownload(videoId: String): Boolean = downloads.remove(videoId)

    @JavascriptInterface
    fun isDownloaded(videoId: String): Boolean = downloads.isDownloaded(videoId)

    // file:// é bloqueado pelo WebView (a página é https), por isso o download é servido
    // pelo LocalServer em /downloaded, que suporta Range (seek) e volta a funcionar offline.
    // O ficheiro em si NUNCA sai da pasta privada da app por esta via — só /shareDownloadedFile
    // (abaixo) expõe uma cópia temporária a outra app, e só quando o usuário pede explicitamente.
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
    // Esta é a ÚNICA via que expõe o áudio descarregado a outra app — sempre por
    // pedido explícito do usuário (botão "Exibir no telemóvel"), nunca automático.
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
    @JavascriptInterface
    fun updateNowPlaying(title: String, artist: String, thumbnailUrl: String, isPlaying: Boolean, positionMs: Long, durationMs: Long) {
        val service = PlaybackServiceInstance.instance
        if (service == null) {
            Log.w("VibelyBridge", "updateNowPlaying: serviço ainda não está pronto")
            return
        }
        service.updateNowPlaying(title, artist, thumbnailUrl, isPlaying, positionMs, durationMs)
    }

    // ─── Notificações de eventos da app (download concluído, etc), canal separado
    // do de reprodução — não é "ongoing", aparece e some como notificação normal.
    @JavascriptInterface
    fun notifyEvent(title: String, message: String) {
        val service = PlaybackServiceInstance.instance
        service?.postEventNotification(title, message)
    }

    // ─── Músicas locais do aparelho (com cache — ver getLocalTracksCached) ───
    @JavascriptInterface
    fun getLocalTracks(): String = scanLocalTracks()

    // Usa cache gravado em DataStore; só volta a interrogar o MediaStore se:
    // (a) nunca houve cache, ou (b) a contagem de faixas no MediaStore mudou.
    // Isto resolve o "ficar sempre a recarregar" — o JS deve chamar sempre esta,
    // não getLocalTracks(), exceto quando quiser forçar um scan (ex: pull-to-refresh).
    @JavascriptInterface
    fun getLocalTracksCached(): String {
        val (cachedJson, cachedCount) = prefs.getLocalTracksCache()
        val currentCount = countLocalTracks()

        if (cachedJson != null && cachedCount != null && cachedCount == currentCount) {
            return cachedJson
        }
        val fresh = scanLocalTracks()
        prefs.setLocalTracksCache(fresh, currentCount)
        return fresh
    }

    @JavascriptInterface
    fun forceRescanLocalTracks(): String {
        val fresh = scanLocalTracks()
        prefs.setLocalTracksCache(fresh, countLocalTracks())
        return fresh
    }

    private fun countLocalTracks(): Long {
        return try {
            val media = android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            val selection = "${android.provider.MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
                "${android.provider.MediaStore.Audio.Media.DURATION} > 0"
            context.contentResolver.query(media, arrayOf(android.provider.MediaStore.Audio.Media._ID), selection, null, null)
                ?.use { it.count.toLong() } ?: 0L
        } catch (e: Exception) { 0L }
    }

    // Devolve título, artista, ÁLBUM e capa. O áudio e a capa são servidos pelo LocalServer
    // (localhost:8080), porque o WebView (origem https) não consegue abrir content:// diretamente.
    private fun scanLocalTracks(): String {
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
            Log.w("VibelyBridge", "scanLocalTracks: sem permissão de áudio")
        } catch (e: Exception) {
            Log.e("VibelyBridge", "scanLocalTracks falhou", e)
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

    // ─── Podcasts: iTunes Search API (descoberta) + RSS direto (episódios), sem token ───
    @JavascriptInterface
    fun searchPodcasts(query: String): String = podcasts.search(query)

    @JavascriptInterface
    fun featuredPodcasts(): String = podcasts.featured()

    @JavascriptInterface
    fun getPodcastEpisodes(feedUrl: String): String = podcasts.episodes(feedUrl)
}

// Ponte simples para falar com o PlaybackService já em execução sem precisar de bind complexo
object PlaybackServiceInstance {
    @Volatile
    var instance: PlaybackService? = null
}

// Ponte simples para o CameraActivity conseguir devolver a foto à MainActivity
object MainActivityInstance {
    @Volatile
    var instance: MainActivity? = null
}
```

## 7. `LocalServer.kt` (completo — endpoints de podcast e letra local adicionados)

```kotlin
package com.vibely.music.app

import android.content.Context
import android.util.Log
import fi.iki.elonen.NanoHTTPD
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class LocalServer(private val context: Context) : NanoHTTPD(8080) {

    private val tag = "VibelyServer"
    private val extractor = MusicExtractor(context)
    private val lyricsProvider = LyricsProvider()
    private val podcasts = PodcastProvider()

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    init {
        Thread {
            extractor.initYtDlp()
            extractor.updateYtDlp()
        }.start()
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val params = session.parameters
        Log.d(tag, "${session.method} $uri")

        if (session.method == Method.OPTIONS) {
            return withCors(newFixedLengthResponse(Response.Status.OK, "text/plain", ""))
        }

        return try {
            when (uri) {
                "/search" -> {
                    val query = params["q"]?.firstOrNull() ?: return badRequest("Missing q")
                    val limit = params["limit"]?.firstOrNull()?.toIntOrNull() ?: 100
                    jsonResponse(extractor.search(query, limit))
                }
                "/stream" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    jsonResponse("""{"streamUrl":"http://localhost:8080/audio?id=$id"}""")
                }
                "/audio" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    proxyAudio(id, session.headers["range"])
                }
                "/related" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    jsonResponse(extractor.getRelated(id))
                }
                "/shorts" -> {
                    val query = params["q"]?.firstOrNull() ?: "trending"
                    jsonResponse(extractor.searchShorts(query))
                }
                "/local" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    serveLocalAudio(id, session.headers["range"])
                }
                "/downloaded" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    serveDownloaded(id, session.headers["range"])
                }
                "/cover" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    serveLocalCover(id)
                }
                "/lyrics" -> {
                    val title = params["title"]?.firstOrNull() ?: return badRequest("Missing title")
                    val artist = params["artist"]?.firstOrNull() ?: ""
                    jsonResponse(lyricsProvider.fetch(title, artist))
                }
                "/podcasts/search" -> {
                    val query = params["q"]?.firstOrNull() ?: return badRequest("Missing q")
                    jsonResponse(podcasts.search(query))
                }
                "/podcasts/featured" -> jsonResponse(podcasts.featured())
                "/podcasts/episodes" -> {
                    val feedUrl = params["feedUrl"]?.firstOrNull() ?: return badRequest("Missing feedUrl")
                    jsonResponse(podcasts.episodes(feedUrl))
                }
                "/debug" -> {
                    val id = params["id"]?.firstOrNull()
                    if (id != null) {
                        extractor.invalidate(id)
                        extractor.getStreamSource(id)
                    }
                    withCors(newFixedLengthResponse(Response.Status.OK, "text/plain; charset=utf-8", extractor.debugReport()))
                }
                else -> withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found"))
            }
        } catch (e: Exception) {
            Log.e(tag, "Erro em $uri", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "application/json", """{"error":"${(e.message ?: "erro").replace("\"", "'")}"}"""))
        }
    }

    // ─── Músicas locais: o WebView (origem https) não abre content:// diretamente,
    // por isso o áudio do telemóvel é servido por aqui, com suporte a Range (seek). ───
    private fun localUri(id: String): android.net.Uri? {
        val numeric = id.removePrefix("local_").toLongOrNull() ?: return null
        return android.content.ContentUris.withAppendedId(
            android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, numeric
        )
    }

    private fun serveLocalAudio(id: String, rangeHeader: String?): Response {
        val uri = localUri(id) ?: return withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "text/plain", "id inválido"))
        return try {
            val resolver = context.contentResolver
            val mime = resolver.getType(uri)?.takeIf { it.startsWith("audio/") } ?: "audio/mpeg"
            val total = resolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: -1L
            if (total <= 0) return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Ficheiro não encontrado"))

            var start = 0L
            var end = total - 1
            var partial = false
            if (rangeHeader != null && rangeHeader.startsWith("bytes=")) {
                val parts = rangeHeader.removePrefix("bytes=").split("-")
                start = parts.getOrNull(0)?.toLongOrNull() ?: 0L
                end = parts.getOrNull(1)?.takeIf { it.isNotEmpty() }?.toLongOrNull() ?: (total - 1)
                end = minOf(end, total - 1)
                if (start > end || start < 0) {
                    val r = newFixedLengthResponse(Response.Status.RANGE_NOT_SATISFIABLE, "text/plain", "")
                    r.addHeader("Content-Range", "bytes */$total")
                    return withCors(r)
                }
                partial = true
            }

            val length = end - start + 1
            val input = resolver.openInputStream(uri) ?: return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Sem acesso"))
            var skipped = 0L
            while (skipped < start) {
                val n = input.skip(start - skipped)
                if (n <= 0) break
                skipped += n
            }
            val limited = object : java.io.FilterInputStream(input) {
                private var remaining = length
                override fun read(): Int {
                    if (remaining <= 0) return -1
                    val b = super.read(); if (b >= 0) remaining--; return b
                }
                override fun read(b: ByteArray, off: Int, len: Int): Int {
                    if (remaining <= 0) return -1
                    val n = super.read(b, off, minOf(len.toLong(), remaining).toInt())
                    if (n > 0) remaining -= n
                    return n
                }
            }

            val resp = newFixedLengthResponse(
                if (partial) Response.Status.PARTIAL_CONTENT else Response.Status.OK, mime, limited, length
            )
            resp.addHeader("Accept-Ranges", "bytes")
            if (partial) resp.addHeader("Content-Range", "bytes $start-$end/$total")
            withCors(resp)
        } catch (e: SecurityException) {
            withCors(newFixedLengthResponse(Response.Status.FORBIDDEN, "text/plain", "Sem permissão de áudio"))
        } catch (e: Exception) {
            Log.e(tag, "Erro a servir local $id", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Erro ao ler ficheiro"))
        }
    }

    // Capa do álbum embutida no ficheiro (ID3/MediaStore). Devolve 404 se não tiver.
    private fun serveLocalCover(id: String): Response {
        val uri = localUri(id) ?: return withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "text/plain", "id inválido"))
        return try {
            val mmr = android.media.MediaMetadataRetriever()
            mmr.setDataSource(context, uri)
            val art = mmr.embeddedPicture
            mmr.release()
            if (art == null || art.isEmpty()) {
                withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Sem capa"))
            } else {
                val r = newFixedLengthResponse(Response.Status.OK, "image/jpeg", java.io.ByteArrayInputStream(art), art.size.toLong())
                r.addHeader("Cache-Control", "public, max-age=86400")
                withCors(r)
            }
        } catch (e: Exception) {
            withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Sem capa"))
        }
    }

    // Áudio descarregado (guardado na pasta privada da app), servido com suporte a Range.
    private fun serveDownloaded(id: String, rangeHeader: String?): Response {
        val safeId = id.filter { it.isLetterOrDigit() || it == '_' || it == '-' }
        val file = java.io.File(java.io.File(context.filesDir, "downloads"), "$safeId.audio")
        if (!file.exists() || file.length() <= 0) {
            return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Download não encontrado"))
        }
        return try {
            val total = file.length()
            var start = 0L
            var end = total - 1
            var partial = false
            if (rangeHeader != null && rangeHeader.startsWith("bytes=")) {
                val parts = rangeHeader.removePrefix("bytes=").split("-")
                start = parts.getOrNull(0)?.toLongOrNull() ?: 0L
                end = parts.getOrNull(1)?.takeIf { it.isNotEmpty() }?.toLongOrNull() ?: (total - 1)
                end = minOf(end, total - 1)
                if (start > end || start < 0) {
                    val r = newFixedLengthResponse(Response.Status.RANGE_NOT_SATISFIABLE, "text/plain", "")
                    r.addHeader("Content-Range", "bytes */$total")
                    return withCors(r)
                }
                partial = true
            }
            val length = end - start + 1
            val raf = java.io.RandomAccessFile(file, "r")
            raf.seek(start)
            val stream = object : java.io.InputStream() {
                private var remaining = length
                override fun read(): Int {
                    if (remaining <= 0) return -1
                    val b = raf.read(); if (b >= 0) remaining--; return b
                }
                override fun read(b: ByteArray, off: Int, len: Int): Int {
                    if (remaining <= 0) return -1
                    val n = raf.read(b, off, minOf(len.toLong(), remaining).toInt())
                    if (n > 0) remaining -= n
                    return n
                }
                override fun close() { try { raf.close() } catch (_: Exception) {} }
            }
            val resp = newFixedLengthResponse(
                if (partial) Response.Status.PARTIAL_CONTENT else Response.Status.OK, "audio/mp4", stream, length
            )
            resp.addHeader("Accept-Ranges", "bytes")
            if (partial) resp.addHeader("Content-Range", "bytes $start-$end/$total")
            withCors(resp)
        } catch (e: Exception) {
            Log.e(tag, "Erro a servir download $id", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Erro ao ler download"))
        }
    }

    private fun proxyAudio(videoId: String, rangeHeader: String?): Response {
        var opened = openUpstream(videoId, rangeHeader)

        if (opened == null || !isGood(opened.second)) {
            opened?.second?.close()
            extractor.invalidate(videoId)
            opened = openUpstream(videoId, rangeHeader)
        }

        if (opened == null || !isGood(opened.second)) {
            val code = opened?.second?.code ?: 0
            opened?.second?.close()
            return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Extração falhou ($code)"))
        }

        val (source, upstream) = opened
        val body = upstream.body ?: run {
            upstream.close()
            return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Sem corpo"))
        }

        val mime = upstream.header("Content-Type")?.takeIf { it.startsWith("audio/") || it.startsWith("video/") } ?: source.mime
        val length = body.contentLength()
        val status = if (upstream.code == 206) Response.Status.PARTIAL_CONTENT else Response.Status.OK

        if (length < 0) {
            body.close(); upstream.close()
            val total = fetchTotalLength(source)
            if (total == null || total <= 0) {
                return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Stream sem tamanho conhecido"))
            }
            val reopened = openUpstream(videoId, rangeHeader) ?: return withCors(
                newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Falha ao reabrir stream")
            )
            val (source2, upstream2) = reopened
            val body2 = upstream2.body ?: run {
                upstream2.close()
                return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Sem corpo"))
            }
            val mime2 = upstream2.header("Content-Type")?.takeIf { it.startsWith("audio/") || it.startsWith("video/") } ?: source2.mime
            val status2 = if (upstream2.code == 206) Response.Status.PARTIAL_CONTENT else Response.Status.OK
            val effectiveLength = body2.contentLength().takeIf { it >= 0 } ?: total
            val resp2 = newFixedLengthResponse(status2, mime2, body2.byteStream(), effectiveLength)
            resp2.addHeader("Accept-Ranges", "bytes")
            upstream2.header("Content-Range")?.let { resp2.addHeader("Content-Range", it) }
            if (status2 == Response.Status.OK) resp2.addHeader("Content-Range", "bytes 0-${total - 1}/$total")
            return withCors(resp2)
        }

        val resp = newFixedLengthResponse(status, mime, body.byteStream(), length)
        resp.addHeader("Accept-Ranges", "bytes")
        upstream.header("Content-Range")?.let { resp.addHeader("Content-Range", it) }
        return withCors(resp)
    }

    private fun fetchTotalLength(source: MusicExtractor.StreamSource): Long? {
        return try {
            val rb = Request.Builder().url(source.url).header("Range", "bytes=0-1")
            source.headers.forEach { (k, v) -> rb.header(k, v) }
            http.newCall(rb.build()).execute().use { r ->
                r.header("Content-Range")?.substringAfterLast("/")?.toLongOrNull()
                    ?: r.header("Content-Length")?.toLongOrNull()
            }
        } catch (e: Exception) { null }
    }

    private fun isGood(r: okhttp3.Response) = r.isSuccessful || r.code == 206

    private fun openUpstream(videoId: String, rangeHeader: String?): Pair<MusicExtractor.StreamSource, okhttp3.Response>? {
        val source = try { extractor.getStreamSource(videoId) } catch (e: Exception) { null } ?: return null
        val rb = Request.Builder().url(source.url)
        source.headers.forEach { (k, v) -> rb.header(k, v) }
        rb.header("Range", rangeHeader ?: "bytes=0-")
        return try { Pair(source, http.newCall(rb.build()).execute()) } catch (e: Exception) { null }
    }

    private fun jsonResponse(json: String): Response = withCors(newFixedLengthResponse(Response.Status.OK, "application/json", json))
    private fun badRequest(msg: String): Response = withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", """{"error":"$msg"}"""))

    private fun withCors(r: Response): Response {
        r.addHeader("Access-Control-Allow-Origin", "*")
        r.addHeader("Access-Control-Allow-Headers", "Range, Content-Type")
        r.addHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
        r.addHeader("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")
        return r
    }
}
```

## 8. `MainActivity.kt` (completo — deteção offline, `MainActivityInstance`, `evaluateInWebView`, `currentUrl`, callback da câmera)

```kotlin
package com.vibely.music.app

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowInsetsController
import android.webkit.ConsoleMessage
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var reloadBtn: Button
    private val appUrl = "https://vibelywebapp.onrender.com"
    private val offlineUrl = "file:///android_asset/index.html"
    private var loadFailed = false
    private var receiverRegistered = false
    private var currentlyOffline = false

    // Recebe os comandos da notificação, dos fones e do ecrã bloqueado
    // (enviados pelo PlaybackService) e entrega-os ao JavaScript do player.
    private val mediaCommandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val cmd = intent?.getStringExtra("cmd") ?: return
            dispatchMediaCommand(cmd)
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        MainActivityInstance.instance = this

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webView)
        reloadBtn = findViewById(R.id.reloadBtn)

        ViewCompat.setOnApplyWindowInsetsListener(webView) { _, insets -> insets }

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowContentAccess = true
            allowFileAccess = true
            builtInZoomControls = false
            displayZoomControls = false
            setSupportZoom(false)
            cacheMode = WebSettings.LOAD_DEFAULT
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        }

        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false
        webView.setBackgroundColor(Color.TRANSPARENT)

        webView.addJavascriptInterface(AndroidBridge(this), "Android")

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                Log.d("VibelyWeb", "${message.message()} (${message.sourceId()}:${message.lineNumber()})")
                return true
            }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean = false

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                loadFailed = false
                reloadBtn.visibility = View.GONE
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) {
                    // Falhou a carregar o site online: cai para a versão offline
                    // (só músicas/álbuns locais) em vez de mostrar o botão de erro,
                    // exceto se a versão offline TAMBÉM já tiver falhado.
                    if (!currentlyOffline) {
                        currentlyOffline = true
                        view.loadUrl(offlineUrl)
                    } else {
                        loadFailed = true
                        view.stopLoading()
                        view.visibility = View.INVISIBLE
                        reloadBtn.visibility = View.VISIBLE
                    }
                }
            }

            override fun onPageFinished(view: WebView, url: String?) {
                super.onPageFinished(view, url)
                if (!loadFailed) {
                    view.visibility = View.VISIBLE
                    reloadBtn.visibility = View.GONE
                }
            }
        }

        reloadBtn.setOnClickListener {
            reloadBtn.visibility = View.GONE
            webView.visibility = View.VISIBLE
            loadFailed = false
            loadBestAvailableUrl()
        }

        // Botão voltar: primeiro o JS tenta fechar o que estiver aberto (diálogo, sheet,
        // menu, player, página, tab). Só se o JS disser que não há nada para fechar é que
        // a app vai para segundo plano.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                webView.evaluateJavascript(
                    "(function(){try{return window.onNativeBack ? window.onNativeBack() : false;}catch(e){return false;}})()"
                ) { result ->
                    val consumed = result == "true"
                    if (!consumed) {
                        moveTaskToBack(true)
                    }
                }
            }
        })

        registerMediaReceiver()
        requestNotificationPermission()
        requestLocalMusicPermission()
        requestBluetoothPermission()
        startPlaybackService()

        if (savedInstanceState != null) webView.restoreState(savedInstanceState)
        else loadBestAvailableUrl()
    }

    // Decide, ao arrancar, se carrega a versão online ou já vai direto para a
    // offline (assets/index.html) quando não há rede nenhuma.
    private fun loadBestAvailableUrl() {
        val bridge = AndroidBridge(this)
        if (bridge.isOnline()) {
            currentlyOffline = false
            webView.loadUrl(appUrl)
        } else {
            currentlyOffline = true
            webView.loadUrl(offlineUrl)
        }
    }

    // URL atualmente carregada — usado pelo CameraActivity para abrir a mesma origem.
    fun currentUrl(): String = if (currentlyOffline) offlineUrl else appUrl

    // Chamado pela CameraActivity (via MainActivityInstance) para injetar JS na WebView principal.
    fun evaluateInWebView(js: String) {
        webView.evaluateJavascript(js, null)
    }

    // ─── Comandos da notificação → JavaScript ───
    private fun dispatchMediaCommand(cmd: String) {
        val safe = cmd.replace("\\", "\\\\").replace("'", "\\'")
        val js = "(function(){try{if(window.nativeMediaCommand){window.nativeMediaCommand('$safe');}}catch(e){}})()"
        runOnUiThread { webView.evaluateJavascript(js, null) }
    }

    private fun registerMediaReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter("com.vibely.music.app.MEDIA_COMMAND")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(mediaCommandReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(mediaCommandReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
        }
    }

    // Permissão para ler músicas guardadas localmente no aparelho
    fun requestLocalMusicPermission() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(permission), 1002)
        }
    }

    private fun requestBluetoothPermission() {
        val perms = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            perms.add(Manifest.permission.BLUETOOTH_CONNECT)
            perms.add(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val missing = perms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1003)
        }
    }

    private fun startPlaybackService() {
        val intent = Intent(this, PlaybackService::class.java)
        ContextCompat.startForegroundService(this, intent)
    }

    fun setStatusBarIcons(dark: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val controller = window.insetsController
                if (dark) controller?.setSystemBarsAppearance(WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
                else controller?.setSystemBarsAppearance(0, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = if (dark) {
                    window.decorView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                } else {
                    window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                }
            }
        }
    }

    override fun onPause() {
        super.onPause()
        webView.resumeTimers()
    }

    override fun onResume() {
        super.onResume()
        webView.onResume()
        webView.resumeTimers()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    override fun onDestroy() {
        if (receiverRegistered) {
            try { unregisterReceiver(mediaCommandReceiver) } catch (_: Exception) {}
            receiverRegistered = false
        }
        if (MainActivityInstance.instance === this) {
            MainActivityInstance.instance = null
        }
        super.onDestroy()
    }
}
```

## 9. `PlaybackService.kt` (completo — canal de eventos separado + `postEventNotification`)

```kotlin
package com.vibely.music.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import fi.iki.elonen.NanoHTTPD
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class PlaybackService : Service() {

    private var server: LocalServer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var eventNotifId = 1000

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    // Último estado conhecido, para reconstruir a notificação quando a capa termina de descarregar
    private var lastTitle: String? = null
    private var lastArtist: String? = null
    private var lastPlaying: Boolean = false
    private var lastArt: Bitmap? = null
    private var lastArtUrl: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
        setupMediaSession()

        PlaybackServiceInstance.instance = this

        val notification = buildNotification(null, null, false, null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "vibely:playback").apply {
            setReferenceCounted(false)
            acquire()
        }

        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "vibely:wifi").apply {
            setReferenceCounted(false)
            acquire()
        }

        Thread {
            try {
                server = LocalServer(applicationContext)
                server?.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
                Log.d("VibelyService", "LocalServer arrancado: ${server?.isAlive}")
            } catch (e: Exception) {
                Log.e("VibelyService", "Falha ao arrancar o servidor", e)
            }
        }.start()
    }

    private fun setupMediaSession() {
        val session = MediaSessionCompat(this, "VibelySession")
        session.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() { sendCommandToWeb("play") }
            override fun onPause() { sendCommandToWeb("pause") }
            override fun onSkipToNext() { sendCommandToWeb("next") }
            override fun onSkipToPrevious() { sendCommandToWeb("prev") }
            override fun onStop() { sendCommandToWeb("pause") }
            override fun onSeekTo(pos: Long) { sendCommandToWeb("seek:$pos") }
        })

        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(ALL_ACTIONS)
                .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 1f)
                .build()
        )
        session.isActive = true
        mediaSession = session
    }

    private fun sendCommandToWeb(cmd: String) {
        val intent = Intent("com.vibely.music.app.MEDIA_COMMAND").apply {
            setPackage(packageName)
            putExtra("cmd", cmd)
        }
        sendBroadcast(intent)
    }

    fun updateNowPlaying(title: String, artist: String, thumbnailUrl: String?, isPlaying: Boolean, position: Long, duration: Long) {
        lastTitle = title
        lastArtist = artist
        lastPlaying = isPlaying

        val safeDuration = if (duration > 0) duration else -1L
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, safeDuration)
        lastArt?.let { metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it) }
        mediaSession?.setMetadata(metadataBuilder.build())

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(ALL_ACTIONS)
                .setState(state, position.coerceAtLeast(0L), if (isPlaying) 1f else 0f)
                .build()
        )

        postNotification(title, artist, lastArt, isPlaying)

        if (thumbnailUrl.isNullOrEmpty()) {
            lastArt = null
            lastArtUrl = null
            return
        }
        if (thumbnailUrl == lastArtUrl && lastArt != null) return
        lastArtUrl = thumbnailUrl
        Thread {
            val bmp = try {
                http.newCall(Request.Builder().url(thumbnailUrl).build()).execute().use { resp ->
                    resp.body?.byteStream()?.let { BitmapFactory.decodeStream(it) }
                }
            } catch (e: Exception) { null }
            if (bmp != null && thumbnailUrl == lastArtUrl) {
                lastArt = bmp
                val md = MediaMetadataCompat.Builder()
                    .putString(MediaMetadataCompat.METADATA_KEY_TITLE, lastTitle ?: "")
                    .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, lastArtist ?: "")
                    .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, safeDuration)
                    .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bmp)
                    .build()
                mediaSession?.setMetadata(md)
                postNotification(lastTitle, lastArtist, bmp, lastPlaying)
            }
        }.start()
    }

    private fun postNotification(title: String?, artist: String?, art: Bitmap?, isPlaying: Boolean) {
        val notification = buildNotification(title, artist, isPlaying, art)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }

    // Notificação de evento (download concluído, etc): canal separado (IMPORTANCE_DEFAULT,
    // com som), NÃO ongoing, id incremental para não sobrepor eventos anteriores.
    fun postEventNotification(title: String, message: String) {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPending = PendingIntent.getActivity(
            this, eventNotifId, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID_EVENTS)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(contentPending)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .build()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(eventNotifId++, notification)
    }

    private fun buildNotification(title: String?, artist: String?, isPlaying: Boolean, art: Bitmap?): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPending = PendingIntent.getActivity(
            this, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val playPauseAction = NotificationCompat.Action(
            if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (isPlaying) "Pausar" else "Tocar",
            mediaPendingIntent(if (isPlaying) PlaybackStateCompat.ACTION_PAUSE else PlaybackStateCompat.ACTION_PLAY)
        )
        val prevAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous, "Anterior",
            mediaPendingIntent(PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)
        )
        val nextAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next, "Próxima",
            mediaPendingIntent(PlaybackStateCompat.ACTION_SKIP_TO_NEXT)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID_PLAYBACK)
            .setContentTitle(title ?: "Vibely")
            .setContentText(artist ?: "Pronto para tocar")
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(art)
            .setContentIntent(contentPending)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun mediaPendingIntent(action: Long): PendingIntent {
        val name = when (action) {
            PlaybackStateCompat.ACTION_PLAY -> ACTION_PLAY
            PlaybackStateCompat.ACTION_PAUSE -> ACTION_PAUSE
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT -> ACTION_NEXT
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS -> ACTION_PREV
            else -> ACTION_PLAY
        }
        val intent = Intent(this, PlaybackService::class.java).apply { this.action = name }
        return PendingIntent.getService(
            this, action.toInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> sendCommandToWeb("play")
            ACTION_PAUSE -> sendCommandToWeb("pause")
            ACTION_NEXT -> sendCommandToWeb("next")
            ACTION_PREV -> sendCommandToWeb("prev")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        server?.stop()
        server = null
        mediaSession?.release()
        mediaSession = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wifiLock?.let { if (it.isHeld) it.release() }

        PlaybackServiceInstance.instance = null

        super.onDestroy()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val playback = NotificationChannel(CHANNEL_ID_PLAYBACK, "Reprodução", NotificationManager.IMPORTANCE_LOW)
            playback.setShowBadge(false)
            nm.createNotificationChannel(playback)

            val events = NotificationChannel(CHANNEL_ID_EVENTS, "Eventos da app", NotificationManager.IMPORTANCE_DEFAULT)
            events.description = "Downloads concluídos e outros avisos da Vibely"
            nm.createNotificationChannel(events)
        }
    }

    companion object {
        private const val CHANNEL_ID_PLAYBACK = "vibely_playback"
        private const val CHANNEL_ID_EVENTS = "vibely_events"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_PLAY = "com.vibely.music.app.ACTION_PLAY"
        private const val ACTION_PAUSE = "com.vibely.music.app.ACTION_PAUSE"
        private const val ACTION_NEXT = "com.vibely.music.app.ACTION_NEXT"
        private const val ACTION_PREV = "com.vibely.music.app.ACTION_PREV"

        private const val ALL_ACTIONS =
            PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or PlaybackStateCompat.ACTION_STOP

        var mediaSession: MediaSessionCompat? = null
    }
}
```

**Falta 1 ficheiro fora do Kotlin**: coloca o teu PNG (silhueta branca, fundo transparente, 48x48) em `app/src/main/res/drawable/ic_notification.png` — os dois ficheiros acima já referenciam `R.drawable.ic_notification`.

---

## `MUDANCAS_HTML.md`

```markdown
# Vibely — mudanças pendentes no `index.html`

Estas são as pontes nativas novas que o `index.html` (o do site, completo) já
pode passar a usar. O `index.html` do APK (assets/, versão só-local, sem
shorties/letras/config online) ainda não foi tratado — fica para quando
mandares o HTML de referência.

## Câmera + flash

```js
// Abre a Activity nativa de câmera (o overlay carrega a própria app em ?camera=1)
Android.openCamera();

// Dentro do modo câmera (deteta pela querystring/hash "camera"), usa a ponte
// AndroidCamera em vez de Android:
if (typeof AndroidCamera !== 'undefined') {
  AndroidCamera.capture();               // tira a foto
  AndroidCamera.hasFlash();              // true/false
  AndroidCamera.toggleFlash(true/false); // liga/desliga a tocha
  AndroidCamera.isFlashOn();
  AndroidCamera.closeCamera();
}

// Na página principal, recebe a foto capturada:
window.onNativePhotoCaptured = function (fileUri) {
  // fileUri é um content:// do FileProvider — usar como src de <img> ou enviar
};
```

## Volume do sistema

```js
const vol = Android.getVolume();     // 0-100
Android.setVolume(50);               // 0-100
```

## Letra de faixas locais

Sem mudança de endpoint — só passar o título/artista já lidos do `MediaStore`
(`track.title`, `track.artist`) para o mesmo `fetchLyrics()` que já existe.

## Músicas locais — parar de recarregar sempre

Trocar todas as chamadas a `Android.getLocalTracks()` por
`Android.getLocalTracksCached()`. Usar `Android.forceRescanLocalTracks()` só
num botão explícito de "atualizar biblioteca" (ex: pull-to-refresh), se
quiseres um.

## Notificações de evento

Não precisa de chamada do JS para downloads (já é automático no
`downloadTrack`). Para notificar outros eventos:

```js
Android.notifyEvent('Título', 'Mensagem');
```

## Downloads — exibir noutro app

```js
Android.shareDownloadedFile(videoId, title); // já existe, é a "opção exibir"
```

## Modo offline

Automático (feito no nativo): se não há rede, a app já carrega
`assets/index.html`. O `index.html` do site pode opcionalmente detetar
`location.protocol === 'file:'` para se saber "estou na versão offline" e
esconder shorties/letras/configurações online, já que nesse modo `isApp`
continua `true` mas os endpoints do YouTube não vão responder.

## Filtro de pesquisa (local / internet / tudo)

Segmented control a implementar no JS: decide se a função de busca chama
`Android.getLocalTracksCached()` (filtra localmente por texto), `/search`
(YouTube), ou ambos e junta os resultados, marcando cada resultado com
`isLocal: true/false` (o `local` já vem com essa flag).

## Podcasts

```js
const res = await fetch(BASE + '/podcasts/search?q=' + encodeURIComponent(query));
const podcasts = await res.json();
// [{ id, title, author, thumbnail, feedUrl, genre, episodeCount }, ...]

const featuredRes = await fetch(BASE + '/podcasts/featured');

const epRes = await fetch(BASE + '/podcasts/episodes?feedUrl=' + encodeURIComponent(feedUrl));
const episodes = await epRes.json();
// [{ title, audioUrl, duration, pubDate, description, thumbnail }, ...]
// tocar: audio.src = episode.audioUrl (é uma URL direta do podcast, sem passar pelo /audio do YouTube)
```
```

Quando me mandares o `index.html` de referência, aplico estas mudanças diretamente nele.

este foi o meu pedido 

Ok, é o seguinte:

Esse index enviado é do web então tens que fazer com que ele carregue as músicas locais rapidamente e que ele também use essas novas mudanças aplicadas no app...
Quero que o botão de câmera esteja no appBar não ao lado do input e já agora sem estar em um container e o botão de mais no tab playlist também não pode estar num container.

Quero que ao abrir a câmera que ele também aplique a navegação nativa assim é muitíssimo melhor e já agora bem ajustado respeitando o limite assim como o do appbar em outras telas.

Também quero que no popup menu tenha uma opção alterar app que ao clicar abre um modal com a seguinte informação, sem apps para abrir de momento e também quero que os dialogs subam sempre um pouquinho quando o teclado do telemóvel aparecer ( que ao seubir a animação seja super super suave ).


Remove o tab de shorties para que seja somente uma tela com botão de voltar ou seja na tela início já tem o botão abrir para o shorties e quero que essa tel de shorties não seja um tab mas sim uma tela assim como as outras telas e quero um novo tab chamada downloads que mostra todas as músicas baixadas ao invés do mostrá-las em settings e já agora o tab downloads estará na última posição.

Já agora o mini player tem um problema que quando clico nele ele também clica ao mesmo tempo um qualquer conteúdo que esteja detrás desse container mini player e isso é frustrante e já agora não quero que não dependa mais do link vibelyweb para exibir o app mas quero que este mesmo html do web que esteja como o index do app assim estará muitíssimo melhor e muitíssimo mais organizado funcionando tanto offline tanto online


E também aparece sempre muitos albuns duplicados nas músicas locais então o app tem que evitar isso e também quero que no player tenha um equalizador ou seja ao clicar em opções no player expandido que mostre uma opção de equalizador funcional e também quero opção de velocidade de reprodução, alterar a capa do álbum da música e que também tenha configurações de reprodução etc etc.

Mantém o mesmo design a mesma navegação e tudo restante na mesma

No popup tire de fora todas as opções mantenha somente configurações, notificações, ajuda e suporte e também uma opção atualizar plano


Terás que dar o arquivo inteiro da primeira a última linha e também acho que alguns ficheiros kotlin vão precisar de ser atualizados então atualize também numa só resposta

uma vez que o index usa ionicons quero que o meu codemagic seja responsável para baixar os ícones IONicons assim os ícones também vão funcionar offline


estes são as outras perguntas e respostas que a outra secção debug
P: 'Alterar app' no popup menu — o que é isto exatamente? É para trocar entre múltiplas instâncias/perfis da app, ou é outra coisa (ex: 'sobre a app', 'trocar de conta')?
R: remove essa opção ela não é mais necessária

P: 'Atualizar plano' no popup — a app vai ter planos pagos (premium/assinatura) de verdade, ou é só um item de menu place holder por agora (abre um modal vazio/"em breve")?
R: crie dois arquivos que estaram em assets/app/plans/plans.html e já agora o index tem que estar em assets/app/index.html ela será uma tela com diferente estilo onde terá apenas 2 planos indiviual e família, indiviual terá plano de 3 meses por 2.99$, 6 meses por 4.99$ e 12 meses por 7.99$. No plano família é idêntico com individual mas com menos 30% e só aceita até 5 pessoas então o preço é o valor de dos planos individuais multiplicados por 5 pessoas e

P: Equalizador funcional — como? O Android tem um Equalizer nativo (android.media.audiofx) que só funciona se o áudio passar por um AudioSessionId específico (MediaPlayer/ExoPlayer nativo), não dá para aplicar a um <audio> do WebView diretamente.
  R: equalizador nativo mas que o WebView é que trata do visual
  
  P: Confirmas a migração da reprodução de <audio>(WebView) para ExoPlayer nativo em Kotlin, para o equalizador nativo funcionar de verdade? É mais trabalho e mexe em muita coisa do player.
  R: Não, mantém o <audio> do WebView e faz equalizador visual (JS) por agora
  
  
  P: Álbuns duplicados nas músicas locais — a causa mais comum é o MediaStore tratar o mesmo nome de álbum como IDs diferentes por pequenas variações (maiúsculas, espaços, artist vs albumartist). Concordas que a correção seja normalizar o nome do álbum (lowercase, trim, sem acentos) para agrupar, em vez de usar o ID do MediaStore?
R: ter filtro para agrupamento

P: 'Alterar a capa do álbum' — a nova capa escolhida pelo usuário fica guardada só localmente (no telemóvel, substituindo a capa mostrada) ou precisa ficar disponu00edvel remotamente também?
R: Guardar no telemóvel (galeria/MediaStore) e ler local

P: Essa troca de capa aplica-se a faixas do YouTube (que não têm ficheiro próprio, só metadados guardados no app) ou também a músicas locais (que exigiria escrever no ID3 do ficheiro real)?
R: somente as locais

P: Trocar a capa de uma música local — a nova imagem vem de escolher da galeria (picker), ou também da câmera que já fizemos?
R: o index terá um modal que carrega todas imagens do dispositivo e terá mais um botão nesse modal " dispositivo" que ao clicar agora mostra o picker nativo

P: Equalizador visual (Web Audio API) — quantas bandas?
R: Completo: 5–8 bandas tipo equalizador gráfico

P: No popup, 'Notificações' e 'Ajuda e suporte' — também ficam como telas simples/placeholder por agora (tipo a de planos), só 'Configurações' fica completa como já está?
R: cada um tem que ter uma tela real mas a tela de notificações por agora apenas terá uma notificação sobre o boas vinda e o usuário estar usando a versão mais atual e também notificação de que tem o plano premium ativo no período de um mês inteiro são três notificações e quero que ao clicar na notificações que mostre todos os conteúdos das notificações e na tela de ajuda e suporte precisa de ter um bottom input e na tela já com algumas questões prontas etc etc


P: Tela de Ajuda e suporte: a pergunta escrita no input tem de ir para algum sítio real (email, WhatsApp, endpoint), ou por agora só simula o envio (fica local/mock) até teres um backend de suporte?
R: eu depois vou criar um worker mas não por agora

P: plans.html — os botões de 'assinar' cada plano já precisam de ligar a alguma coisa (ex: abrir um link de pagamento/checkout), ou ficam só visuais/decorativos por agora, sem lógica de pagamento?
R: por agora são somente visuais


Seu burrrrrrrrro será que tenho mais que repetir que odeio ficheiros para baixar?
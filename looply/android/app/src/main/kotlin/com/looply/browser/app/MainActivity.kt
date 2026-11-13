package com.looply.browser.app

import android.app.UiModeManager
import android.Manifest
import android.app.AlertDialog
import android.app.role.RoleManager
import android.content.pm.PackageManager
import android.net.Uri
import android.webkit.PermissionRequest
import android.webkit.GeolocationPermissions
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.CustomCredential
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.security.SecureRandom
import java.io.File
import android.util.Base64
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MenuItem
import android.view.SubMenu
import android.view.ViewGroup
import android.view.View
import android.widget.ImageView
import android.widget.Button
import android.widget.LinearLayout
import android.widget.FrameLayout
import android.widget.PopupWindow
import android.widget.TextView
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.Typeface
import androidx.appcompat.view.menu.MenuBuilder
import androidx.appcompat.widget.PopupMenu
import androidx.appcompat.widget.SwitchCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "looply/native_ui"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_THEME_MODE = "flutter.looply_theme_mode"
        private const val ORBIT_BROWSER_REQUEST_CODE = 7418
        private const val PREF_AI_SEARCH_ENABLED = "looply_ai_search_enabled"
        private const val ORBIT_TAB_STATE_PREFS = "looply_orbit_native_tab_state_v1"
        private const val MAX_ORBIT_STATE_CHARS = 3_000_000
        private var nativeDownloadChannel: MethodChannel? = null
        private var nativeDownloadBridgeReady = false
        private val pendingNativeDownloadEvents = java.util.ArrayDeque<HashMap<String, Any?>>()

        fun notifyNativeDownloadRequested(
            url: String,
            filename: String,
            mimeType: String?,
            headers: Map<String, String>,
        ) {
            Handler(Looper.getMainLooper()).post {
                val payload = hashMapOf<String, Any?>(
                    "url" to url,
                    "filename" to filename,
                    "mimeType" to mimeType,
                    "headers" to HashMap(headers),
                )
                val channel = nativeDownloadChannel
                if (channel != null && nativeDownloadBridgeReady) {
                    channel.invokeMethod("downloadRequested", payload)
                } else {
                    pendingNativeDownloadEvents.addLast(payload)
                }
            }
        }
    }


    private val mainHandler = Handler(Looper.getMainLooper())
    private val nativeAuthScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val pendingExternalUrls = java.util.ArrayDeque<String>()
    private var defaultBrowserIntentChannel: MethodChannel? = null
    private var defaultBrowserBridgeReady = false
    private var pendingRuntimePermissionCallback: ((Boolean) -> Unit)? = null
    private var pendingRuntimePermissionNames: Set<String> = emptySet()
    private var pendingLocationPermissionAcceptAny = false
    private val webPermissionPreferences by lazy {
        getSharedPreferences("browseit_web_permissions", Context.MODE_PRIVATE)
    }
    private val nativeUiPreferences by lazy {
        getSharedPreferences("looply_native_ui", Context.MODE_PRIVATE)
    }
    private val runtimePermissionRequestCode = 7401
    private var pendingOrbitBrowserResult: MethodChannel.Result? = null
    private var nativeStatsChannel: MethodChannel? = null
    private var nativeUiChannel: MethodChannel? = null
    private lateinit var appPreferences: SharedPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        // O Android guarda o modo de aparência escolhido pela aplicação.
        // Aplicá-lo antes de criar a janela permite que os recursos values-night
        // do splash acompanhem a preferência da Looply, não apenas o tema global.
        val savedMode = readSavedThemeMode()
        val savedPureBlack = readSavedPureBlack()
        applyApplicationNightMode(savedMode)
        extractBrowsableUrl(intent)?.let(pendingExternalUrls::addLast)
        super.onCreate(savedInstanceState)

        // Splash agora é 100% nativo (LaunchTheme / windowSplashScreen*):
        // nenhuma View Kotlin é desenhada por cima. applyWindowTheme só
        // ajusta as cores de status/navigation bar para a Activity.
        applyWindowTheme(savedMode, savedPureBlack)

        appPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeUiChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        nativeDownloadBridgeReady = false
        nativeDownloadChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "looply/native_downloads").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> {
                        nativeDownloadBridgeReady = true
                        while (pendingNativeDownloadEvents.isNotEmpty()) {
                            channel.invokeMethod("downloadRequested", pendingNativeDownloadEvents.removeFirst())
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        nativeUiChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAppThemeMode" -> {
                        val mode = call.argument<String>("mode") ?: "system"
                        val pureBlack = call.argument<Boolean>("pureBlack") ?: false
                        applyApplicationNightMode(mode)
                        applyWindowTheme(mode, pureBlack)
                        result.success(true)
                    }
                    "showNativePopup" -> showNativePopup(call, result)
                    "showNativeDialog" -> showNativeDialog(call, result)
                    "openNativeBrowser" -> openNativeBrowser(call, result)
                    "openNativeFileViewer" -> openNativeFileViewer(call, result)
                    "exportOrbitSessions" -> exportOrbitSessions(result)
                    "importOrbitSessions" -> importOrbitSessions(call, result)
                    "showNativeDrawer" -> showNativeDrawer(call, result)
                    "isDefaultBrowser" -> result.success(isDefaultBrowser())
                    "requestDefaultBrowser" -> result.success(requestDefaultBrowser())
                    "getAiSearchEnabled" -> result.success(readAiSearchEnabled())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "browseit/google_auth")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "signInGoogle" -> startGoogleSignIn(call, result)
                    else -> result.notImplemented()
                }
            }

        defaultBrowserIntentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "browseit/default_browser",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialUrl" -> {
                        defaultBrowserBridgeReady = true
                        result.success(if (pendingExternalUrls.isEmpty()) null else pendingExternalUrls.removeFirst())
                    }
                    else -> result.notImplemented()
                }
            }
        }

        nativeStatsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "looply/native_adblock",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> result.success(false)
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        nativeStatsChannel = null
        nativeUiChannel = null
        nativeDownloadChannel = null
        nativeDownloadBridgeReady = false
        defaultBrowserIntentChannel = null
        defaultBrowserBridgeReady = false
        nativeAuthScope.cancel()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val url = extractBrowsableUrl(intent) ?: return
        if (defaultBrowserBridgeReady) {
            defaultBrowserIntentChannel?.invokeMethod("openUrl", url)
        } else {
            pendingExternalUrls.addLast(url)
        }
    }

    private fun extractBrowsableUrl(source: Intent?): String? {
        if (source?.action != Intent.ACTION_VIEW) return null
        val uri = source.data ?: return null
        if (uri.scheme != "http" && uri.scheme != "https") return null
        return uri.toString().takeIf { it.isNotBlank() }
    }

    private fun readSavedThemeMode(): String {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(PREF_THEME_MODE, "system") ?: "system"
    }

    private fun readSavedPureBlack(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("flutter.looply_theme_pure_dark", false)
    }

    private fun readAiSearchEnabled(): Boolean {
        return nativeUiPreferences.getBoolean(PREF_AI_SEARCH_ENABLED, false)
    }

    private fun writeAiSearchEnabled(enabled: Boolean) {
        nativeUiPreferences.edit().putBoolean(PREF_AI_SEARCH_ENABLED, enabled).apply()
        try {
            nativeUiChannel?.invokeMethod("aiSearchEnabledChanged", enabled)
        } catch (_: RuntimeException) {
            // A tela Flutter pode não estar anexada no momento da alteração.
        }
    }

    private fun applyApplicationNightMode(mode: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val nightMode = when (mode) {
            "light" -> UiModeManager.MODE_NIGHT_NO
            "dark" -> UiModeManager.MODE_NIGHT_YES
            // MODE_NIGHT_AUTO é a opção automática oferecida por UiModeManager;
            // o SDK Android não expõe FOLLOW_SYSTEM neste método.
            else -> UiModeManager.MODE_NIGHT_AUTO
        }
        try {
            getSystemService(UiModeManager::class.java)?.setApplicationNightMode(nightMode)
        } catch (_: RuntimeException) {
            // A configuração Flutter continua funcional mesmo em dispositivos
            // Android modificados que não implementem o modo por aplicação.
        }
    }


    private fun applyWindowTheme(mode: String, pureBlack: Boolean) {
        val dark = when (mode) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        val background = when {
            !dark -> Color.WHITE
            pureBlack -> Color.BLACK
            else -> Color.rgb(23, 24, 26)
        }
        window.setBackgroundDrawable(ColorDrawable(background))
        window.statusBarColor = background
        window.navigationBarColor = background
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            @Suppress("DEPRECATION")
            var flags = window.decorView.systemUiVisibility
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = if (dark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                }
            }
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = flags
        } else {
            window.insetsController?.let { controller ->
                if (dark) {
                    controller.setSystemBarsAppearance(0, android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
                    controller.setSystemBarsAppearance(0, android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS)
                } else {
                    controller.setSystemBarsAppearance(
                        android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS,
                        android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS,
                    )
                    controller.setSystemBarsAppearance(
                        android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                        android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                    )
                }
            }
        }
    }

    private fun startGoogleSignIn(call: MethodCall, result: MethodChannel.Result) {
        nativeAuthScope.launch {
            try {
                // Reutiliza o challenge devolvido pelo Worker. O token Google
                // passa a conter exatamente o nonce que o backend vai validar.
                val suppliedNonce = call.argument<String>("nonce")
                val nonce = suppliedNonce?.takeIf {
                    it.length in 16..256 && it.matches(Regex("^[A-Za-z0-9_-]+$"))
                } ?: generateNonce()
                val googleIdOption = GetGoogleIdOption.Builder()
                    .setFilterByAuthorizedAccounts(false)
                    .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
                    .setNonce(nonce)
                    .build()
                val request = GetCredentialRequest.Builder()
                    .addCredentialOption(googleIdOption)
                    .build()
                val credentialManager = CredentialManager.create(this@MainActivity)
                val response = credentialManager.getCredential(this@MainActivity, request)
                val credential = response.credential
                if (credential is CustomCredential &&
                    credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                ) {
                    val googleCredential = GoogleIdTokenCredential.createFrom(credential.data)
                    result.success(
                        mapOf(
                            "idToken" to googleCredential.idToken,
                            "nonce" to nonce,
                        ),
                    )
                } else {
                    result.error("invalid_credential", "A credencial devolvida não é do Google.", null)
                }
            } catch (_: NoCredentialException) {
                result.error("no_credential", "Nenhuma conta Google disponível neste dispositivo.", null)
            } catch (error: Exception) {
                result.error("google_sign_in_failed", error.message, null)
            }
        }
    }

    private fun generateNonce(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun isDefaultBrowser(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val roleManager = getSystemService(RoleManager::class.java)
                roleManager?.isRoleHeld(RoleManager.ROLE_BROWSER) == true
            } else {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
                val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                resolveInfo?.activityInfo?.packageName == packageName
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun requestDefaultBrowser(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val roleManager = getSystemService(RoleManager::class.java) ?: return false
                if (!roleManager.isRoleAvailable(RoleManager.ROLE_BROWSER)) return false
                if (roleManager.isRoleHeld(RoleManager.ROLE_BROWSER)) return true
                startActivityForResult(roleManager.createRequestRoleIntent(RoleManager.ROLE_BROWSER), 7402)
            } else {
                startActivity(Intent("android.settings.MANAGE_DEFAULT_APPS_SETTINGS"))
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Called only after an individual website asks to use the camera/microphone. */
    internal fun requestOrbitWebPermissions(request: PermissionRequest, origin: String) {
        val parsedOrigin = Uri.parse(origin)
        if (parsedOrigin.scheme != "https" && parsedOrigin.host != "localhost") {
            request.deny()
            return
        }
        val resources = request.resources?.toSet().orEmpty()
        val video = PermissionRequest.RESOURCE_VIDEO_CAPTURE
        val audio = PermissionRequest.RESOURCE_AUDIO_CAPTURE
        if (resources.isEmpty() || resources.any { it != video && it != audio }) {
            request.deny()
            return
        }
        val androidPermissions = buildList {
            if (video in resources) add(Manifest.permission.CAMERA)
            if (audio in resources) add(Manifest.permission.RECORD_AUDIO)
        }.toTypedArray()
        val displayName = origin.removePrefix("https://").removePrefix("http://").substringBefore('/')
        AlertDialog.Builder(this)
            .setTitle("Permitir acesso ao dispositivo?")
            .setMessage("$displayName pretende utilizar ${buildList { if (video in resources) add("a câmara"); if (audio in resources) add("o microfone") }.joinToString(" e ")}.")
            .setNegativeButton("Bloquear") { _, _ -> request.deny() }
            .setPositiveButton("Permitir") { _, _ ->
                requestRuntimePermissions(androidPermissions) { granted ->
                    try {
                        if (granted) request.grant(resources.toTypedArray()) else request.deny()
                    } catch (_: RuntimeException) {
                        // O site pode ter cancelado o pedido enquanto o diálogo Android estava aberto.
                    }
                }
            }
            .setOnCancelListener { request.deny() }
            .show()
    }

    /** A geolocalização também exige a permissão do Android e consentimento do site. */
    internal fun requestOrbitGeolocation(origin: String, callback: GeolocationPermissions.Callback) {
        val parsedOrigin = Uri.parse(origin)
        if (parsedOrigin.scheme != "https" && parsedOrigin.host != "localhost") {
            callback.invoke(origin, false, false)
            return
        }
        val host = origin.removePrefix("https://").removePrefix("http://").substringBefore('/')
        val savedDecision = webPermissionPreferences.getString("geo:$origin", null)
        val hasSystemPermission = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (savedDecision == "allow" && hasSystemPermission) {
            callback.invoke(origin, true, false)
            return
        }
        if (savedDecision == "deny") {
            callback.invoke(origin, false, false)
            return
        }
        AlertDialog.Builder(this)
            .setTitle("Permitir localização?")
            .setMessage("$host pretende aceder à localização deste dispositivo.")
            .setNegativeButton("Bloquear") { _, _ ->
                webPermissionPreferences.edit().putString("geo:$origin", "deny").apply()
                callback.invoke(origin, false, false)
            }
            .setPositiveButton("Permitir") { _, _ ->
                requestRuntimeLocationPermissions { granted ->
                    webPermissionPreferences.edit().putString("geo:$origin", if (granted) "allow" else "deny").apply()
                    callback.invoke(origin, granted, false)
                }
            }
            .setOnCancelListener { callback.invoke(origin, false, false) }
            .show()
    }

    private fun requestRuntimeLocationPermissions(callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            callback(true)
            return
        }
        val hasCoarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasFine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (hasCoarse || hasFine) {
            callback(true)
            return
        }
        if (pendingRuntimePermissionCallback != null) {
            callback(false)
            return
        }
        pendingRuntimePermissionNames = setOf(
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )
        pendingLocationPermissionAcceptAny = true
        pendingRuntimePermissionCallback = callback
        requestPermissions(
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION),
            runtimePermissionRequestCode,
        )
    }

    private fun requestRuntimePermissions(permissions: Array<String>, callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            callback(true)
            return
        }
        val missing = permissions.distinct().filter {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            callback(true)
            return
        }
        if (pendingRuntimePermissionCallback != null) {
            callback(false)
            return
        }
        pendingRuntimePermissionNames = missing.toSet()
        pendingLocationPermissionAcceptAny = false
        pendingRuntimePermissionCallback = callback
        requestPermissions(missing.toTypedArray(), runtimePermissionRequestCode)
    }

    @Deprecated("Deprecated in Android API; retained for compatibility with the FlutterActivity permission callback")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != runtimePermissionRequestCode) return
        val callback = pendingRuntimePermissionCallback
        val required = pendingRuntimePermissionNames
        pendingRuntimePermissionCallback = null
        pendingRuntimePermissionNames = emptySet()
        val granted = required.isNotEmpty() && if (pendingLocationPermissionAcceptAny) {
            required.any { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
        } else {
            required.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
        }
        pendingLocationPermissionAcceptAny = false
        callback?.invoke(granted)
    }

    @Deprecated("Deprecated in Android API; retained for Flutter compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ORBIT_BROWSER_REQUEST_CODE) return
        val callback = pendingOrbitBrowserResult
        pendingOrbitBrowserResult = null
        if (callback == null) return
        if (resultCode == android.app.Activity.RESULT_OK) {
            callback.success(hashMapOf<String, Any?>(
                "url" to data?.getStringExtra(OrbitBrowserActivity.RESULT_URL),
                "title" to data?.getStringExtra(OrbitBrowserActivity.RESULT_TITLE),
                "tabId" to data?.getStringExtra(OrbitBrowserActivity.RESULT_TAB_ID),
                "action" to data?.getStringExtra(OrbitBrowserActivity.RESULT_ACTION),
                "newUrl" to data?.getStringExtra(OrbitBrowserActivity.RESULT_NEW_URL),
                "thumbnail" to data?.getByteArrayExtra(OrbitBrowserActivity.RESULT_THUMBNAIL),
                "transitionScreenshot" to data?.getByteArrayExtra(OrbitBrowserActivity.RESULT_TRANSITION_SCREENSHOT),
            ))
        } else callback.success(hashMapOf("action" to "home"))
    }

    /**
     * Menu popup 100% nativo do Android: usa androidx.appcompat.widget.PopupMenu,
     * o mesmo componente usado nos menus de overflow do sistema. A animação de
     * abertura/fecho, a elevação e o ripple dos itens vêm todos do próprio
     * Android — nada disso é desenhado manualmente pelo Flutter ou pela app.
     *
     * O primeiro item ("Pesquisa com IA") usa um actionView customizado com um
     * SwitchCompat, a forma suportada pelo Android de colocar um controlo
     * interativo dentro de um item de menu nativo.
     */
    private fun openNativeBrowser(call: MethodCall, result: MethodChannel.Result) {
        if (pendingOrbitBrowserResult != null) {
            result.error("browser_already_open", "O browser nativo já está aberto.", null)
            return
        }
        val rawUrl = call.argument<String>("url")?.trim().takeUnless { it.isNullOrEmpty() }
            ?: "https://www.google.com"
        val uri = runCatching { Uri.parse(rawUrl) }.getOrNull()
        if (uri == null || uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) {
            result.error("invalid_native_browser_url", "O endereço do browser é inválido.", null)
            return
        }
        val intent = Intent(this, OrbitBrowserActivity::class.java).apply {
            putExtra(OrbitBrowserActivity.EXTRA_URL, uri.toString())
            putExtra(OrbitBrowserActivity.EXTRA_TAB_ID, call.argument<String>("tabId") ?: "")
            putExtra(OrbitBrowserActivity.EXTRA_INCOGNITO, call.argument<Boolean>("isIncognito") ?: false)
            putExtra(OrbitBrowserActivity.EXTRA_TAB_COUNT, call.argument<Int>("tabCount") ?: 1)
            putExtra(OrbitBrowserActivity.EXTRA_PREVIEW_ONLY, call.argument<Boolean>("previewOnly") ?: false)
            val labels = call.argument<Map<String, String>>("menuLabels") ?: emptyMap()
            putExtra(OrbitBrowserActivity.EXTRA_MENU_LABELS_JSON, JSONObject(labels).toString())
            putExtra("com.looply.browser.app.orbit.SKIP_ENTER_ANIMATION", call.argument<Boolean>("skipNativeEnterAnimation") ?: false)
        }
        pendingOrbitBrowserResult = result
        try {
            startActivityForResult(intent, ORBIT_BROWSER_REQUEST_CODE)
            if (intent.getBooleanExtra("com.looply.browser.app.orbit.SKIP_ENTER_ANIMATION", false)) {
                overridePendingTransition(0, 0)
            } else {
                overridePendingTransition(R.anim.browser_slide_up, R.anim.browser_stay)
            }
        } catch (error: Exception) {
            pendingOrbitBrowserResult = null
            result.error("native_browser_unavailable", error.message, null)
        }
    }

    private fun openNativeFileViewer(call: MethodCall, result: MethodChannel.Result) {
        val rawPath = call.argument<String>("path")?.takeIf { it.isNotBlank() }
        if (rawPath == null) {
            result.error("invalid_file_path", "O caminho do ficheiro está vazio.", null)
            return
        }
        val file = runCatching { File(rawPath).canonicalFile }.getOrNull()
        val root = runCatching { File(applicationInfo.dataDir).canonicalFile }.getOrNull()
        if (file == null || root == null || !file.isFile ||
            !file.path.startsWith(root.path + File.separator)) {
            result.error("file_not_available", "O ficheiro não existe ou não pertence ao armazenamento privado da aplicação.", null)
            return
        }
        try {
            val viewer = Intent(this, NativeFileViewerActivity::class.java).apply {
                putExtra(NativeFileViewerActivity.EXTRA_PATH, file.path)
                putExtra(NativeFileViewerActivity.EXTRA_NAME, call.argument<String>("filename") ?: file.name)
                putExtra(NativeFileViewerActivity.EXTRA_MIME, call.argument<String>("mimeType") ?: "")
            }
            startActivity(viewer)
            overridePendingTransition(R.anim.browser_slide_up, R.anim.browser_stay)
            result.success(true)
        } catch (error: Exception) {
            result.error("file_viewer_failed", error.message ?: "Não foi possível abrir o visualizador.", null)
        }
    }

    private fun exportOrbitSessions(result: MethodChannel.Result) {
        val sessions = getSharedPreferences(ORBIT_TAB_STATE_PREFS, Context.MODE_PRIVATE)
            .all
            .filter { (key, value) -> key.startsWith("tab_") && value is String && value.length <= MAX_ORBIT_STATE_CHARS }
            .mapValues { it.value as String }
        result.success(sessions)
    }

    private fun importOrbitSessions(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<Map<*, *>>("sessions")
        if (raw == null) {
            result.error("invalid_orbit_sessions", "O backup não contém sessões nativas válidas.", null)
            return
        }
        val editor = getSharedPreferences(ORBIT_TAB_STATE_PREFS, Context.MODE_PRIVATE).edit().clear()
        var accepted = 0
        raw.forEach { (key, value) ->
            if (key is String && key.matches(Regex("tab_[A-Za-z0-9_-]{1,100}")) &&
                value is String && value.length <= MAX_ORBIT_STATE_CHARS) {
                editor.putString(key, value)
                accepted++
            }
        }
        editor.apply()
        result.success(accepted)
    }

    /** Mostra um diálogo Android real, mantendo o conteúdo de texto em Views nativas. */
    private fun showNativeDialog(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title")
        val message = call.argument<String>("message")
        val actions = call.argument<List<Map<String, Any?>>>("actions")
        if (title == null || message == null || actions.isNullOrEmpty()) {
            result.error("invalid_dialog", "Título, mensagem ou ações do diálogo são inválidos.", null)
            return
        }

        val secondaryMessage = call.argument<String>("secondaryMessage")
        val barrierDismissible = call.argument<Boolean>("barrierDismissible") ?: true
        val dark = isAppDarkTheme()
        val backgroundColor = if (dark) Color.rgb(33, 35, 37) else Color.WHITE
        val textColor = if (dark) Color.rgb(230, 230, 232) else Color.rgb(32, 33, 36)
        val mutedColor = if (dark) Color.rgb(178, 180, 184) else Color.rgb(95, 99, 104)
        val accentColor = if (dark) Color.rgb(138, 180, 248) else Color.rgb(26, 115, 232)
        val destructiveColor = Color.rgb(255, 69, 58)
        val themedContext = ContextThemeWrapper(
            this,
            if (dark) R.style.LooplyDialog_Dark else R.style.LooplyDialog_Light,
        )
        val dialogView = LayoutInflater.from(themedContext).inflate(R.layout.dialog_native, null, false)
        val titleView = dialogView.findViewById<TextView>(R.id.dialog_title)
        val messageView = dialogView.findViewById<TextView>(R.id.dialog_message)
        val secondaryView = dialogView.findViewById<TextView>(R.id.dialog_secondary_message)
        val actionsContainer = dialogView.findViewById<LinearLayout>(R.id.dialog_actions)

        titleView.text = title
        titleView.setTextColor(textColor)
        messageView.text = message
        messageView.setTextColor(mutedColor)
        if (!secondaryMessage.isNullOrBlank()) {
            // No diálogo de informação do site, a primeira linha é o nome/título
            // e a segunda é o endereço, com peso e contraste secundário.
            messageView.setTextColor(textColor)
            messageView.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
            secondaryView.text = secondaryMessage
            secondaryView.setTextColor(mutedColor)
            secondaryView.visibility = View.VISIBLE
        } else {
            secondaryView.visibility = View.GONE
        }

        dialogView.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(20).toFloat()
            setColor(backgroundColor)
        }

        val dialog = AlertDialog.Builder(themedContext)
            .setView(dialogView)
            .setCancelable(barrierDismissible)
            .create()

        var completed = false
        fun finish(value: Any?) {
            if (completed) return
            completed = true
            result.success(value)
        }

        actions.forEach { action ->
            val label = action["label"]?.toString().orEmpty()
            val value = action["value"]
            val isPrimary = action["isPrimary"] as? Boolean ?: false
            val isDestructive = action["isDestructive"] as? Boolean ?: false
            val button = Button(themedContext).apply {
                text = label
                isAllCaps = false
                textSize = 14f
                minWidth = 0
                minimumWidth = dpToPx(52)
                minHeight = 0
                minimumHeight = dpToPx(40)
                setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
                when {
                    isPrimary -> {
                        background = GradientDrawable().apply {
                            shape = GradientDrawable.RECTANGLE
                            cornerRadius = dpToPx(22).toFloat()
                            setColor(accentColor)
                        }
                        setTextColor(Color.WHITE)
                    }
                    else -> {
                        background = GradientDrawable().apply {
                            shape = GradientDrawable.RECTANGLE
                            cornerRadius = dpToPx(22).toFloat()
                            setColor(Color.TRANSPARENT)
                        }
                        setTextColor(if (isDestructive) destructiveColor else accentColor)
                    }
                }
                setOnClickListener {
                    finish(value)
                    dialog.dismiss()
                }
            }
            actionsContainer.addView(button, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginStart = dpToPx(6)
            })
        }

        dialog.setOnDismissListener { finish(null) }
        dialog.setOnCancelListener { finish(null) }
        try {
            dialog.show()
            dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            val maxWidth = dpToPx(560)
            val screenWidth = resources.displayMetrics.widthPixels - dpToPx(40)
            dialog.window?.setLayout(minOf(maxWidth, screenWidth), ViewGroup.LayoutParams.WRAP_CONTENT)
        } catch (error: RuntimeException) {
            finish(null)
        }
    }

    private fun dpToPx(value: Int): Int =
        (value * resources.displayMetrics.density).roundToInt()

    private fun showNativePopup(call: MethodCall, result: MethodChannel.Result) {
        val items = call.argument<List<Map<String, Any?>>>("items")
        val anchor = call.argument<Map<String, Any>>("anchor")
        if (items.isNullOrEmpty() || anchor == null) {
            result.error("invalid_popup", "Os itens ou a âncora do menu são inválidos.", null)
            return
        }
        val includeAiToggle = call.argument<Boolean>("includeAiToggle") ?: false

        val content = findViewById<ViewGroup>(android.R.id.content)
        val flutterView = findFlutterView(content) ?: content
        val flutterLocation = IntArray(2)
        flutterView.getLocationOnScreen(flutterLocation)

        val density = resources.displayMetrics.density
        fun dp(value: Number): Int = (value.toDouble() * density).roundToInt()
        val anchorLeft = flutterLocation[0] + dp(anchor["left"] as? Number ?: 0)
        val anchorTop = flutterLocation[1] + dp(anchor["top"] as? Number ?: 0)
        val anchorRight = flutterLocation[0] + dp(anchor["right"] as? Number ?: 0)
        val anchorBottom = flutterLocation[1] + dp(anchor["bottom"] as? Number ?: 0)
        val anchorWidth = (anchorRight - anchorLeft).coerceAtLeast(dp(24))
        val anchorHeight = (anchorBottom - anchorTop).coerceAtLeast(dp(24))

        val dark = isAppDarkTheme()
        val themeRes = if (dark) R.style.LooplyPopupMenu_Dark else R.style.LooplyPopupMenu_Light
        val themedContext = ContextThemeWrapper(this, themeRes)

        // Âncora invisível posicionada exatamente sobre o botão que originou o
        // pedido, para que o PopupMenu nativo abra encostado ao mesmo sítio
        // onde o LooplyPopupMenuButton do Flutter estava.
        val anchorView = View(themedContext)
        val anchorParams = FrameLayoutParamsAt(anchorLeft - flutterLocation[0], anchorTop - flutterLocation[1], anchorWidth, anchorHeight)
        content.addView(anchorView, anchorParams)

        val popupMenu = PopupMenu(themedContext, anchorView, Gravity.END)
        val menu = popupMenu.menu

        var completed = false
        fun finish(value: Any?) {
            if (completed) return
            completed = true
            content.removeView(anchorView)
            result.success(value)
        }

        if (includeAiToggle) {
            val aiItem = menu.add(0, 1, 0, "Pesquisa com IA")
            inflateSwitchActionView(themedContext, aiItem, dark)
        }

        items.forEachIndexed { index, item ->
            val menuItem = menu.add(0, index + 100, index + 1, item["label"]?.toString().orEmpty())
            val iconBytes = item["icon"] as? ByteArray
            if (iconBytes != null) {
                val bitmap = android.graphics.BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
                if (bitmap != null) {
                    val drawable = android.graphics.drawable.BitmapDrawable(resources, bitmap)
                    menuItem.icon = drawable
                }
            }
        }
        // Os ícones dos itens de texto só aparecem no overflow menu quando
        // forçados via reflection em versões antigas de appcompat; em vez de
        // depender disso, o MenuBuilder expõe diretamente esta flag pública.
        try {
            (menu as? MenuBuilder)?.setOptionalIconsVisible(true)
        } catch (_: Exception) {
            // Caso a versão de appcompat não exponha o método, os itens
            // continuam a funcionar, apenas sem ícone à esquerda do texto.
        }

        popupMenu.setOnMenuItemClickListener { clicked ->
            when {
                clicked.itemId == 1 -> {
                    // O próprio clique no item alterna o switch; o listener do
                    // switch (definido em inflateSwitchActionView) trata da
                    // persistência. Aqui apenas evitamos fechar prematuramente
                    // sem reportar nada ao Flutter.
                    val switchView = clicked.actionView?.findViewById<SwitchCompat>(R.id.popup_switch_item_toggle)
                    switchView?.toggle()
                    false
                }
                clicked.itemId >= 100 -> {
                    val chosen = items[clicked.itemId - 100]
                    finish(chosen["value"])
                    true
                }
                else -> false
            }
        }
        popupMenu.setOnDismissListener {
            finish(null)
        }

        try {
            popupMenu.show()
        } catch (error: RuntimeException) {
            finish(null)
        }
    }

    private var nativeDrawerWindow: PopupWindow? = null

    /** Drawer nativo exclusivo do browser, sem formas/cantos do Material. */
    private fun showNativeDrawer(call: MethodCall, result: MethodChannel.Result) {
        nativeDrawerWindow?.dismiss()
        val items = call.argument<List<Map<String, Any?>>>("items").orEmpty()
        val dark = isAppDarkTheme()
        val background = if (dark) Color.rgb(23, 24, 26) else Color.WHITE
        val textColor = if (dark) Color.rgb(230, 230, 232) else Color.rgb(32, 33, 36)
        val dividerColor = if (dark) Color.rgb(45, 47, 51) else Color.rgb(228, 229, 231)
        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).roundToInt()
        val root = findViewById<ViewGroup>(android.R.id.content)
        val screenHeight = root.height
        val drawerWidth = (resources.displayMetrics.widthPixels * 0.82f).roundToInt().coerceAtMost(dp(320))
        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(background)
            setPadding(0, dp(24), 0, dp(24))
        }
        var resolved = false
        fun resolveOnce(value: Any?) {
            if (resolved) return
            resolved = true
            result.success(value)
        }
        items.forEachIndexed { index, item ->
            val label = item["label"]?.toString().orEmpty()
            val value = item["value"]?.toString().orEmpty()
            val row = android.widget.LinearLayout(this).apply {
                orientation = android.widget.LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                isClickable = true
                isFocusable = true
                setPadding(dp(20), dp(14), dp(20), dp(14))
                val outValue = android.util.TypedValue()
                theme.resolveAttribute(android.R.attr.selectableItemBackground, outValue, true)
                setBackgroundResource(outValue.resourceId)
            }
            val labelView = TextView(this).apply {
                text = label
                setTextColor(textColor)
                textSize = 15f
                typeface = Typeface.DEFAULT
            }
            row.addView(labelView)
            row.setOnClickListener {
                resolveOnce(value)
                nativeDrawerWindow?.dismiss()
            }
            container.addView(row)
            if (index != items.lastIndex) container.addView(View(this).apply {
                setBackgroundColor(dividerColor)
                layoutParams = android.widget.LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1))
            })
        }
        val popup = PopupWindow(container, drawerWidth,
            if (screenHeight > 0) screenHeight else ViewGroup.LayoutParams.MATCH_PARENT, true).apply {
            setBackgroundDrawable(ColorDrawable(background))
            elevation = 0f
            isOutsideTouchable = true
            animationStyle = 0
        }
        nativeDrawerWindow = popup
        popup.setOnDismissListener {
            nativeDrawerWindow = null
            resolveOnce(null)
        }
        popup.showAtLocation(root, Gravity.START or Gravity.TOP, 0, 0)
    }

    private fun inflateSwitchActionView(themedContext: Context, item: MenuItem, dark: Boolean) {
        val inflater = LayoutInflater.from(themedContext)
        val view = inflater.inflate(R.layout.popup_menu_switch_item, null, false)
        val icon = view.findViewById<ImageView>(R.id.popup_switch_item_icon)
        val label = view.findViewById<TextView>(R.id.popup_switch_item_label)
        val toggle = view.findViewById<SwitchCompat>(R.id.popup_switch_item_toggle)

        val textColor = if (dark) Color.rgb(230, 230, 232) else Color.rgb(32, 33, 36)
        val iconTint = if (dark) Color.rgb(178, 180, 184) else Color.rgb(95, 99, 104)

        label.text = "Pesquisa com IA"
        label.setTextColor(textColor)
        icon.setImageDrawable(
            MaterialSymbolsRounded.bitmapDrawable(
                this,
                "search",
                iconTint,
                dpToPx(20),
            )
        )
        toggle.isChecked = readAiSearchEnabled()
        toggle.setOnCheckedChangeListener { _, isChecked ->
            writeAiSearchEnabled(isChecked)
        }
        // O clique em qualquer parte da linha também alterna o switch,
        // replicando o comportamento dos itens equivalentes na tela de
        // Definições (toque na linha inteira, não só no controlo).
        view.setOnClickListener { toggle.toggle() }

        item.actionView = view
        item.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
    }

    private fun FrameLayoutParamsAt(x: Int, y: Int, width: Int, height: Int): ViewGroup.LayoutParams {
        return if (android.R.id.content != 0) {
            android.widget.FrameLayout.LayoutParams(width, height).apply {
                leftMargin = x
                topMargin = y
                gravity = Gravity.TOP or Gravity.START
            }
        } else {
            ViewGroup.LayoutParams(width, height)
        }
    }

    private fun isAppDarkTheme(): Boolean {
        val mode = readSavedThemeMode()
        return when (mode) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
    }

    private fun isAppPureBlackTheme(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("flutter.looply_theme_pure_dark", false)
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findFlutterView(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }
}
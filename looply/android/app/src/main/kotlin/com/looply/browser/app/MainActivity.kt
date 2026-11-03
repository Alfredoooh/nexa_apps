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
import android.util.Base64
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.view.animation.AlphaAnimation
import android.view.animation.AnimationSet
import android.view.animation.DecelerateInterpolator
import android.view.animation.ScaleAnimation
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.BitmapFactory
import android.graphics.drawable.GradientDrawable
import android.graphics.Typeface
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview.InAppWebView
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
        private const val PREF_AD_BLOCK_ENABLED = "flutter.looply_ad_block_enabled"
        private const val PREF_ADBLOCK_STATS = "flutter.looply_adblock_daily_history_v2"
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
    private val runtimePermissionRequestCode = 7401
    private val nativeStatsLock = Any()
    private var pendingNativeBlocks = 0
    private var nativeStatsChannel: MethodChannel? = null
    private lateinit var appPreferences: SharedPreferences
    private val flushNativeBlocksRunnable = Runnable { flushNativeBlockCount() }
    private val adBlockPreferenceListener =
        SharedPreferences.OnSharedPreferenceChangeListener { preferences, key ->
            if (key == PREF_AD_BLOCK_ENABLED) {
                val enabled = preferences.getBoolean(PREF_AD_BLOCK_ENABLED, true)
                LooplyNativeAdBlockState.enabled = enabled
                mainHandler.post { updateNativeAdBlockerOnCurrentWebViews(enabled) }
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        // O Android guarda o modo de aparência escolhido pela aplicação.
        // Aplicá-lo antes de criar a janela permite que os recursos values-night
        // do splash acompanhem a preferência da Looply, não apenas o tema global.
        val savedMode = readSavedThemeMode()
        val savedPureBlack = readSavedPureBlack()
        applyApplicationNightMode(savedMode)
        extractBrowsableUrl(intent)?.let(pendingExternalUrls::addLast)
        super.onCreate(savedInstanceState)
        appPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        LooplyNativeAdBlockState.enabled = appPreferences.getBoolean(PREF_AD_BLOCK_ENABLED, true)
        appPreferences.registerOnSharedPreferenceChangeListener(adBlockPreferenceListener)
        applyWindowTheme(savedMode, savedPureBlack)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "looply/orbit_native_webview",
            OrbitNativeWebViewFactory(flutterEngine.dartExecutor.binaryMessenger, ::recordNativeBlockedRequest),
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAppThemeMode" -> {
                        val mode = call.argument<String>("mode") ?: "system"
                        val pureBlack = call.argument<Boolean>("pureBlack") ?: false
                        applyApplicationNightMode(mode)
                        applyWindowTheme(mode, pureBlack)
                        result.success(true)
                    }
                    "showNativePopup" -> showNativePopup(call, result)
                    "isDefaultBrowser" -> result.success(isDefaultBrowser())
                    "requestDefaultBrowser" -> result.success(requestDefaultBrowser())
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
                    "install" -> {
                        val count = installNativeAdBlockerOnCurrentWebViews()
                        if (count == 0) scheduleNativeAdBlockerInstallRetry(0)
                        result.success(count > 0)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(flushNativeBlocksRunnable)
        if (::appPreferences.isInitialized) {
            flushNativeBlockCount()
            appPreferences.unregisterOnSharedPreferenceChangeListener(adBlockPreferenceListener)
        }
        nativeStatsChannel = null
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

    /** Instala a implementação nativa diretamente em cada InAppWebView ativo. */
    private fun installNativeAdBlockerOnCurrentWebViews(): Int {
        val root = findViewById<View>(android.R.id.content) ?: return 0
        var found = 0

        fun visit(view: View) {
            if (view is InAppWebView) {
                found++
                val currentHandler = view.contentBlockerHandler
                if (currentHandler !is LooplyNativeContentBlockerHandler) {
                    val nativeHandler = LooplyNativeContentBlockerHandler(::recordNativeBlockedRequest)
                    nativeHandler.setRuleList(currentHandler.getRuleList())
                    view.contentBlockerHandler = nativeHandler
                }
            }
            if (view is ViewGroup) {
                for (index in 0 until view.childCount) visit(view.getChildAt(index))
            }
        }

        visit(root)
        return found
    }

    /** Atualiza os filtros cosméticos das WebViews sem recarregar a página. */
    private fun updateNativeAdBlockerOnCurrentWebViews(enabled: Boolean) {
        OrbitNativeWebViewRegistry.updateAll(enabled)
        val root = findViewById<View>(android.R.id.content) ?: return
        val script = "window.__looplyAdBlockSetEnabled && window.__looplyAdBlockSetEnabled($enabled);"

        fun visit(view: View) {
            if (view is InAppWebView) {
                val handler = view.contentBlockerHandler
                if (handler is LooplyNativeContentBlockerHandler) {
                    handler.updateCosmeticFilter(view, enabled)
                } else {
                    try {
                        view.evaluateJavascript(script, null)
                    } catch (_: RuntimeException) {
                        // A WebView pode estar a ser destruída durante a alteração.
                    }
                }
            }
            if (view is ViewGroup) {
                for (index in 0 until view.childCount) visit(view.getChildAt(index))
            }
        }

        visit(root)
    }

    private fun scheduleNativeAdBlockerInstallRetry(attempt: Int) {
        if (attempt >= 7) return
        val delay = 70L + (attempt * 70L)
        mainHandler.postDelayed({
            val installed = installNativeAdBlockerOnCurrentWebViews()
            if (installed == 0) scheduleNativeAdBlockerInstallRetry(attempt + 1)
        }, delay)
    }

    /** Chamado no worker thread do WebView; só acumula um contador em memória. */
    private fun recordNativeBlockedRequest(isIncognito: Boolean) {
        if (isIncognito) return
        synchronized(nativeStatsLock) {
            pendingNativeBlocks++
            if (pendingNativeBlocks == 1) {
                mainHandler.postDelayed(flushNativeBlocksRunnable, 420L)
            }
        }
    }

    /** Persiste os bloqueios em lote no mesmo JSON que o widget Flutter lê. */
    private fun flushNativeBlockCount() {
        val increment = synchronized(nativeStatsLock) {
            val value = pendingNativeBlocks
            pendingNativeBlocks = 0
            value
        }
        if (increment <= 0) return

        try {
            val raw = appPreferences.getString(PREF_ADBLOCK_STATS, "{}") ?: "{}"
            val daily = try {
                JSONObject(raw)
            } catch (_: Exception) {
                JSONObject()
            }
            val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            daily.put(day, daily.optInt(day, 0) + increment)

            val cutoff = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                .format(Date(System.currentTimeMillis() - 730L * 24L * 60L * 60L * 1000L))
            val staleKeys = ArrayList<String>()
            val keys = daily.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                if (key.matches(Regex("\\d{4}-\\d{2}-\\d{2}")) && key < cutoff) {
                    staleKeys.add(key)
                }
            }
            staleKeys.forEach { daily.remove(it) }
            appPreferences.edit().putString(PREF_ADBLOCK_STATS, daily.toString()).apply()

            try {
                nativeStatsChannel?.invokeMethod("statsChanged", null)
            } catch (_: RuntimeException) {
                // A persistência local não depende da tela Flutter estar visível.
            }
        } catch (_: Exception) {
            // Uma falha de estatísticas nunca deve interromper a navegação.
        }
    }

    private fun readSavedThemeMode(): String {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(PREF_THEME_MODE, "system") ?: "system"
    }

    private fun readSavedPureBlack(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("flutter.looply_theme_pure_dark", false)
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                flags = if (dark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                }
            }
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = flags
        }
    }

    private fun startGoogleSignIn(call: MethodCall, result: MethodChannel.Result) {
        val serverClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID.trim()
        if (serverClientId.isBlank() || serverClientId.contains("PASTE_WEB_CLIENT_ID_HERE", ignoreCase = true)) {
            result.error(
                "google_web_client_id_missing",
                "Falta configurar o OAuth Client ID do tipo Web em BROWSEIT_GOOGLE_WEB_CLIENT_ID. O Client ID Android não substitui o Web Client ID usado como audience do ID token.",
                null,
            )
            return
        }

        val suppliedNonce = call.argument<String>("nonce")?.trim().orEmpty()
        val nonce = suppliedNonce.ifBlank { createSecureNonce() }
        nativeAuthScope.launch {
            try {
                val manager = CredentialManager.create(this@MainActivity)

                suspend fun requestGoogleCredential(onlyAuthorized: Boolean) = manager.getCredential(
                    context = this@MainActivity,
                    request = GetCredentialRequest.Builder()
                        .addCredentialOption(
                            GetGoogleIdOption.Builder()
                                .setFilterByAuthorizedAccounts(onlyAuthorized)
                                .setServerClientId(serverClientId)
                                .setNonce(nonce)
                                .setAutoSelectEnabled(onlyAuthorized)
                                .build(),
                        )
                        .build(),
                )

                val response = try {
                    requestGoogleCredential(true)
                } catch (_: NoCredentialException) {
                    requestGoogleCredential(false)
                }

                val credential = response.credential
                if (credential !is CustomCredential ||
                    credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                ) {
                    result.error("google_credential_unexpected", "O Google não devolveu uma credencial de ID token compatível.", null)
                    return@launch
                }

                val googleCredential = GoogleIdTokenCredential.createFrom(credential.data)
                result.success(
                    mapOf(
                        "idToken" to googleCredential.idToken,
                        "email" to googleCredential.id,
                        "displayName" to googleCredential.displayName,
                        "photoUrl" to googleCredential.profilePictureUri?.toString(),
                        "nonce" to nonce,
                    ),
                )
            } catch (error: Exception) {
                val name = error.javaClass.simpleName
                val code = if (name.contains("Cancellation", true)) "google_cancelled" else "google_sign_in_failed"
                result.error(code, error.message ?: "Não foi possível iniciar sessão com Google.", null)
            }
        }
    }

    private fun createSecureNonce(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun isDefaultBrowser(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getSystemService(RoleManager::class.java)?.isRoleHeld(RoleManager.ROLE_BROWSER) == true
        } else {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://browseit.invalid"))
            val resolved = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            resolved?.activityInfo?.packageName == packageName
        }
    }

    private fun requestDefaultBrowser(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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

    @Deprecated("Deprecated in Android API; retained for compatibility with WebView file chooser")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OrbitFileChooserRegistry.REQUEST_CODE) {
            OrbitFileChooserRegistry.onActivityResult(resultCode, data)
        }
    }

    private fun showNativePopup(call: MethodCall, result: MethodChannel.Result) {
        val items = call.argument<List<Map<String, Any?>>>("items")
        val anchor = call.argument<Map<String, Any>>("anchor")
        if (items.isNullOrEmpty() || anchor == null) {
            result.error("invalid_popup", "Os itens ou a âncora do menu são inválidos.", null)
            return
        }

        val content = findViewById<FrameLayout>(android.R.id.content)
        val flutterView = findFlutterView(content) ?: content
        val flutterLocation = IntArray(2)
        val contentLocation = IntArray(2)
        flutterView.getLocationOnScreen(flutterLocation)
        content.getLocationOnScreen(contentLocation)

        val density = resources.displayMetrics.density
        fun dp(value: Number): Int = (value.toDouble() * density).roundToInt()
        val anchorLeft = flutterLocation[0] + dp(anchor["left"] as? Number ?: 0)
        val anchorTop = flutterLocation[1] + dp(anchor["top"] as? Number ?: 0)
        val anchorRight = flutterLocation[0] + dp(anchor["right"] as? Number ?: 0)

        val screenWidth = resources.displayMetrics.widthPixels
        val availableContentHeight = (content.height - dp(16)).coerceAtLeast(dp(180))
        val requestedWidth = call.argument<Number>("width")?.toDouble() ?: 252.0
        val popupWidth = dp(requestedWidth).coerceAtMost(screenWidth - dp(16)).coerceAtLeast(dp(190))
        val rowHeight = dp(48)
        val desiredHeight = rowHeight * items.size
        val popupHeight = desiredHeight.coerceAtMost(availableContentHeight)

        val dark = isAppDarkTheme()
        val pureBlack = isAppPureBlackTheme()
        val backgroundColor = when {
            dark && pureBlack -> Color.rgb(25, 25, 25)
            dark -> Color.rgb(43, 45, 48)
            else -> Color.rgb(255, 255, 255)
        }
        val textColor = if (dark) Color.rgb(230, 230, 232) else Color.rgb(32, 33, 36)
        val iconTint = if (dark) Color.rgb(178, 180, 184) else Color.rgb(95, 99, 104)

        fun newPopupBackground() = GradientDrawable().apply {
            setColor(backgroundColor)
            cornerRadius = dp(19).toFloat()
        }
        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        val scroll = ScrollView(this).apply {
            isFillViewport = false
            clipToOutline = true
            background = newPopupBackground()
            overScrollMode = View.OVER_SCROLL_NEVER
            addView(
                list,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }

        lateinit var popup: PopupWindow
        var completed = false
        items.forEach { item ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16), 0, dp(16), 0)
                isClickable = true
                isFocusable = true
                minimumHeight = rowHeight
            }

            val iconBytes = item["icon"] as? ByteArray
            if (iconBytes != null) {
                val bitmap = BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
                if (bitmap != null) {
                    val image = ImageView(this).apply {
                        // Mantém o tamanho visual dos símbolos Flutter; apenas
                        // o peso é controlado na rasterização, não na dimensão.
                        layoutParams = LinearLayout.LayoutParams(dp(20), dp(20)).apply {
                            marginEnd = dp(14)
                        }
                        scaleType = ImageView.ScaleType.FIT_CENTER
                        setImageBitmap(bitmap)
                        setColorFilter(iconTint)
                    }
                    row.addView(image)
                } else {
                    row.addView(View(this), LinearLayout.LayoutParams(dp(20), dp(20)).apply {
                        marginEnd = dp(14)
                    })
                }
            } else {
                row.addView(View(this), LinearLayout.LayoutParams(dp(20), dp(20)).apply {
                    marginEnd = dp(14)
                })
            }

            val label = TextView(this).apply {
                text = item["label"]?.toString().orEmpty()
                setTextColor(textColor)
                textSize = 14f
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                gravity = Gravity.CENTER_VERTICAL
                includeFontPadding = false
            }
            row.addView(
                label,
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f),
            )
            row.setOnClickListener {
                if (!completed) {
                    completed = true
                    result.success(item["value"])
                }
                popup.dismiss()
            }
            list.addView(
                row,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    rowHeight,
                ),
            )

        }

        popup = PopupWindow(scroll, popupWidth, popupHeight, true).apply {
            setBackgroundDrawable(newPopupBackground())
            isOutsideTouchable = true
            isFocusable = true
            isClippingEnabled = true
            elevation = dp(12).toFloat()
            setOnDismissListener {
                if (!completed) {
                    completed = true
                    result.success(null)
                }
            }
        }

        // O menu sobrepõe o controlo que o abriu e cresce a partir da âncora.
        // O menu cobre a região do botão que o abriu: a âncora fica por
        // baixo do popup, em vez de deixar um intervalo lateral visível.
        val opensRight = anchorLeft < popupWidth + dp(16)
        val rawPopupX = if (opensRight) {
            anchorRight - dp(16)
        } else {
            anchorRight - popupWidth + dp(16)
        }
        val popupXOnScreen = rawPopupX.coerceIn(
            dp(8),
            (screenWidth - popupWidth - dp(8)).coerceAtLeast(dp(8)),
        )

        val minY = contentLocation[1] + dp(8)
        val maxY = (contentLocation[1] + content.height - popupHeight - dp(8)).coerceAtLeast(minY)
        val popupYOnScreen = (anchorTop - dp(4)).coerceIn(minY, maxY)
        val popupX = popupXOnScreen - contentLocation[0]
        val popupY = popupYOnScreen - contentLocation[1]

        try {
            popup.showAtLocation(content, Gravity.TOP or Gravity.LEFT, popupX, popupY)
            val pivotX = if (opensRight) 0.0f else 1.0f
            val animation = AnimationSet(true).apply {
                interpolator = DecelerateInterpolator(1.8f)
                duration = 190
                addAnimation(
                    ScaleAnimation(
                        .92f, 1f, .94f, 1f,
                        ScaleAnimation.RELATIVE_TO_SELF, pivotX,
                        ScaleAnimation.RELATIVE_TO_SELF, .5f,
                    ),
                )
                addAnimation(AlphaAnimation(0f, 1f))
            }
            scroll.startAnimation(animation)
        } catch (error: RuntimeException) {
            if (!completed) {
                completed = true
                result.error("popup_failed", error.message, null)
            }
            popup.dismiss()
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

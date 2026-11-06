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
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MenuItem
import android.view.SubMenu
import android.view.ViewGroup
import android.view.View
import android.widget.ImageView
import android.widget.FrameLayout
import android.widget.PopupWindow
import android.widget.TextView
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.Typeface
import androidx.appcompat.view.menu.MenuBuilder
import androidx.appcompat.widget.PopupMenu
import androidx.appcompat.widget.SwitchCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterRenderer
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
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
        private const val PREF_AI_SEARCH_ENABLED = "looply_ai_search_enabled"
    }


    private val mainHandler = Handler(Looper.getMainLooper())
    private var flutterRenderer: FlutterRenderer? = null
    private var hasFlutterUiDisplayed = false
    private var shimmerSplashOverlay: ShimmerSplashView? = null
    private val splashHideRunnable = Runnable { hideShimmerSplash() }
    private val splashFallbackRunnable = Runnable { hideShimmerSplash() }
    // Duração mínima garantida do shimmer, contada a partir do onCreate.
    // Mesmo que o Flutter termine de inicializar antes disso (aparelhos
    // rápidos), o shimmer continua visível até completar este tempo, para
    // que o efeito seja sempre perceptível e nunca pareça "piscar uma vez".
    private val minShimmerDurationMs = 3000L
    private var shimmerStartUptimeMs = 0L
    private val flutterUiDisplayListener = object : FlutterUiDisplayListener {
        override fun onFlutterUiDisplayed() {
            hasFlutterUiDisplayed = true
            // Mantém o shimmer visível até cumprir o tempo mínimo garantido
            // e, só depois disso, mais 700ms para a transição de saída do
            // splash transparente do sistema terminar sem sobreposição.
            val elapsed = android.os.SystemClock.uptimeMillis() - shimmerStartUptimeMs
            val remaining = (minShimmerDurationMs - elapsed).coerceAtLeast(0L)
            mainHandler.removeCallbacks(splashHideRunnable)
            mainHandler.postDelayed(splashHideRunnable, remaining + 700L)
        }

        override fun onFlutterUiNoLongerDisplayed() = Unit
    }
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
    private val nativeStatsLock = Any()
    private var pendingNativeBlocks = 0
    private var nativeStatsChannel: MethodChannel? = null
    private var nativeUiChannel: MethodChannel? = null
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

        // O splash nativo do Android contém apenas o fundo. Colocar a camada
        // animada antes de qualquer inicialização adicional garante que o
        // primeiro conteúdo da Activity já seja o logótipo com shimmer.
        applyWindowTheme(savedMode, savedPureBlack)
        if (savedInstanceState == null) {
            showShimmerSplash(savedMode, savedPureBlack)
        }

        appPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        LooplyNativeAdBlockState.enabled = appPreferences.getBoolean(PREF_AD_BLOCK_ENABLED, true)
        appPreferences.registerOnSharedPreferenceChangeListener(adBlockPreferenceListener)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        flutterRenderer = flutterEngine.renderer
        flutterRenderer?.addIsDisplayingFlutterUiListener(flutterUiDisplayListener)
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "looply/orbit_native_webview",
            OrbitNativeWebViewFactory(flutterEngine.dartExecutor.binaryMessenger, ::recordNativeBlockedRequest),
        )
        nativeUiChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
        mainHandler.removeCallbacks(splashHideRunnable)
        mainHandler.removeCallbacks(splashFallbackRunnable)
        shimmerSplashOverlay?.let { overlay ->
            (overlay.parent as? ViewGroup)?.removeView(overlay)
            overlay.dispose()
        }
        shimmerSplashOverlay = null
        flutterRenderer?.removeIsDisplayingFlutterUiListener(flutterUiDisplayListener)
        flutterRenderer = null
        if (::appPreferences.isInitialized) {
            flushNativeBlockCount()
            appPreferences.unregisterOnSharedPreferenceChangeListener(adBlockPreferenceListener)
        }
        nativeStatsChannel = null
        nativeUiChannel = null
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

    private fun showShimmerSplash(mode: String, pureBlack: Boolean) {
        val content = findViewById<ViewGroup>(android.R.id.content) ?: return
        if (shimmerSplashOverlay != null) return

        val dark = when (mode) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        val overlay = ShimmerSplashView(this, dark, pureBlack)
        shimmerSplashOverlay = overlay
        shimmerStartUptimeMs = android.os.SystemClock.uptimeMillis()
        content.addView(
            overlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        overlay.bringToFront()
        mainHandler.removeCallbacks(splashHideRunnable)
        mainHandler.removeCallbacks(splashFallbackRunnable)
        // Evita deixar a camada presa caso uma falha externa impeça o primeiro
        // frame Flutter de ser apresentado. Sempre maior que o mínimo garantido.
        mainHandler.postDelayed(splashFallbackRunnable, minShimmerDurationMs + 12000L)
        if (hasFlutterUiDisplayed) {
            val elapsed = android.os.SystemClock.uptimeMillis() - shimmerStartUptimeMs
            val remaining = (minShimmerDurationMs - elapsed).coerceAtLeast(0L)
            mainHandler.postDelayed(splashHideRunnable, remaining + 700L)
        }
    }

    private fun hideShimmerSplash() {
        mainHandler.removeCallbacks(splashHideRunnable)
        mainHandler.removeCallbacks(splashFallbackRunnable)
        val overlay = shimmerSplashOverlay ?: return
        shimmerSplashOverlay = null

        if (overlay.parent == null) {
            overlay.dispose()
            return
        }

        overlay.animate()
            .alpha(0f)
            .setDuration(160L)
            .withEndAction {
                (overlay.parent as? ViewGroup)?.removeView(overlay)
                overlay.dispose()
            }
            .start()
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
                val nonce = generateNonce()
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

    @Deprecated("Deprecated in Android API; retained for compatibility with WebView file chooser")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OrbitFileChooserRegistry.REQUEST_CODE) {
            OrbitFileChooserRegistry.onActivityResult(resultCode, data)
        }
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
        icon.setImageResource(android.R.drawable.ic_menu_search)
        icon.setColorFilter(iconTint)
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
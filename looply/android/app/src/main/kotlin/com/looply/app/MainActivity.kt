package com.looply.app

import android.app.UiModeManager
import android.content.Context
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
                    else -> result.notImplemented()
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
        super.onDestroy()
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

package com.looply.browser.app

import android.app.Activity
import android.animation.ValueAnimator
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Parcel
import android.os.SystemClock
import android.util.Base64
import android.print.PrintAttributes
import android.print.PrintManager
import android.text.InputType
import android.view.Gravity
import android.widget.PopupWindow
import android.widget.ScrollView
import android.transition.Fade
import android.view.animation.DecelerateInterpolator
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.slider.Slider
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.URLConnection
import java.util.Locale
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.roundToInt

class OrbitBrowserActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_URL = "com.looply.browser.app.orbit.URL"
        const val EXTRA_TAB_ID = "com.looply.browser.app.orbit.TAB_ID"
        const val EXTRA_INCOGNITO = "com.looply.browser.app.orbit.INCOGNITO"
        const val EXTRA_TAB_COUNT = "com.looply.browser.app.orbit.TAB_COUNT"
        const val EXTRA_PREVIEW_ONLY = "com.looply.browser.app.orbit.PREVIEW_ONLY"
        const val EXTRA_MENU_LABELS_JSON = "com.looply.browser.app.orbit.MENU_LABELS_JSON"

        const val RESULT_URL = "com.looply.browser.app.orbit.RESULT_URL"
        const val RESULT_TITLE = "com.looply.browser.app.orbit.RESULT_TITLE"
        const val RESULT_TAB_ID = "com.looply.browser.app.orbit.RESULT_TAB_ID"
        const val RESULT_ACTION = "com.looply.browser.app.orbit.RESULT_ACTION"
        const val RESULT_THUMBNAIL = "com.looply.browser.app.orbit.RESULT_THUMBNAIL"
        const val RESULT_TRANSITION_SCREENSHOT = "com.looply.browser.app.orbit.RESULT_TRANSITION_SCREENSHOT"
        const val RESULT_NEW_URL = "com.looply.browser.app.orbit.RESULT_NEW_URL"

        private const val PREFS = "FlutterSharedPreferences"
        private const val PREF_THEME_MODE = "flutter.looply_theme_mode"
        private const val PREF_PURE_BLACK = "flutter.looply_theme_pure_dark"
        private const val PREF_AD_BLOCK = "flutter.looply_ad_block_enabled"
        private const val PREF_FORCE_DARK = "flutter.looply_force_dark_websites"
        private const val PREF_ADAPTIVE_TOOLBAR = "flutter.looply_adaptive_toolbar_color"
        private const val PREF_ADBLOCK_STATS = "flutter.looply_adblock_daily_history_v2"

        private const val STATE_WEBVIEW = "orbit.webview.state"
        private const val STATE_URL = "orbit.url"
        private const val STATE_TITLE = "orbit.title"
        private const val STATE_SCROLL_X = "orbit.scroll.x"
        private const val STATE_SCROLL_Y = "orbit.scroll.y"

        private const val TAB_STATE_PREFS = "looply_orbit_native_tab_state_v1"
        private const val MAX_TAB_STATE_CHARS = 3_000_000

        private const val DESKTOP_UA =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

        private val blockedDomains = setOf(
            "doubleclick.net", "googlesyndication.com",
            "googleadservices.com", "google-analytics.com",
            "googletagmanager.com", "googletagservices.com",
            "adservice.google.com", "adsystem.com",
            "amazon-adsystem.com", "facebook.net",
            "connect.facebook.net", "fbcdn.net",
            "ads.facebook.com", "taboola.com",
            "outbrain.com", "criteo.com",
            "criteo.net", "adroll.com",
            "adnxs.com", "rubiconproject.com",
            "pubmatic.com", "openx.net",
            "casalemedia.com", "smartadserver.com",
            "advertising.com", "adform.net",
            "adtech.com", "media.net",
            "yieldmo.com", "bidswitch.net",
            "contextweb.com", "exoclick.com",
            "popads.net", "propellerads.com",
            "revcontent.com", "mgid.com",
            "zedo.com", "adblade.com",
            "adcolony.com", "applovin.com",
            "chartboost.com", "unityads.unity3d.com",
            "vungle.com", "inmobi.com",
            "mopub.com", "scorecardresearch.com",
            "quantserve.com", "hotjar.com",
            "mixpanel.com", "segment.io",
            "segment.com", "amplitude.com",
            "crazyegg.com", "optimizely.com",
            "newrelic.com", "nr-data.net",
            "bugsnag.com", "sentry.io",
            "intercom.io", "drift.com",
            "onesignal.com", "pushwoosh.com",
            "branch.io", "adjust.com",
            "appsflyer.com", "kochava.com",
            "tapjoy.com", "ironsrc.com",
            "smaato.net", "sharethrough.com",
            "teads.tv", "triplelift.com",
            "spotxchange.com", "adsrvr.org",
            "turn.com", "mathtag.com",
            "bluekai.com", "krxd.net",
            "demdex.net", "everesttech.net",
            "serving-sys.com", "atdmt.com",
            "adbrite.com", "adtechus.com",
            "burstnet.com", "chitika.com",
            "clicksor.com", "infolinks.com",
            "kontera.com", "lijit.com",
            "media6degrees.com", "pointroll.com",
            "quantcast.com", "rlcdn.com",
            "simpli.fi", "tribalfusion.com",
            "tremorhub.com", "undertone.com",
            "yieldlab.net", "zergnet.com",
            "popcash.net", "adsterra.com",
            "propellerclick.com", "clickadu.com",
            "galaksion.com", "adspyglass.com",
            "hilltopads.net", "juicyads.com",
            "trafficjunky.com", "exosrv.com",
            "moatads.com", "adsafeprotected.com",
            "doubleverify.com", "ensighten.com",
            "tynt.com", "addthis.com",
            "sharethis.com", "disqus.com",
            "gemius.pl", "histats.com",
            "statcounter.com", "clicky.com",
            "getclicky.com", "woopra.com",
            "kissmetrics.com", "heap.io",
            "fullstory.com", "luckyorange.com",
            "trafficstars.com", "plugrush.com",
            "tsyndicate.com", "adcash.com",
            "adnium.com", "ero-advertising.com",
            "adxpansion.com", "onclickads.net",
            "onclickalgo.com", "onclckmn.com",
            "adk2x.com", "adtrafico.com",
            "bebi.com", "a-ads.com",
            "trafficfactory.biz", "mouseflow.com",
            "smartlook.com", "clarity.ms"
        )
    }

    private lateinit var root: LinearLayout
    private lateinit var toolbar: LinearLayout
    private lateinit var appBarContainer: LinearLayout
    private lateinit var titlePill: LinearLayout
    private lateinit var moreButton: View
    private lateinit var faviconView: ImageView
    private lateinit var titleView: TextView
    private lateinit var progress: ProgressBar
    private lateinit var webView: WebView
    private lateinit var findBar: LinearLayout
    private lateinit var findField: EditText
    private lateinit var tabsButton: android.widget.FrameLayout

    private var currentUrl = "https://www.google.com"
    private var currentTitle = "Google"
    private var tabId = ""
    private var tabCount = 1
    private var incognito = false
    private var previewOnly = false
    private var desktopMode = false
    private var toolbarHidden = false
    private var pageToolbarColor: Int? = null
    private var originalUserAgent: String? = null
    private var textSizePercent = 100
    private var pageZoomPercent = 100
    private var appliedPageZoomPercent = 100
    private var pendingRestoredScrollX: Int? = null
    private var pendingRestoredScrollY: Int? = null
    private var appBarAnimator: ValueAnimator? = null
    private var lastScrollDirection = 0
    private var accumulatedScrollDelta = 0
    private var reverseScrollDelta = 0
    private var toolbarScrollFreezeUntilMs = 0L
    private var menuLabels = JSONObject()
    private var isFinishingWithResult = false

    private var customView: View? = null
    private var customViewCallback: WebChromeClient.CustomViewCallback? = null

    private val prefs by lazy {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    private val tabStatePrefs by lazy {
        getSharedPreferences(TAB_STATE_PREFS, Context.MODE_PRIVATE)
    }

    private val dark: Boolean
        get() {
            if (incognito) return true

            return when (prefs.getString(PREF_THEME_MODE, "system")) {
                "dark" -> true
                "light" -> false
                else -> {
                    (resources.configuration.uiMode and
                        android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                        android.content.res.Configuration.UI_MODE_NIGHT_YES
                }
            }
        }

    private val pureBlack: Boolean
        get() = incognito || prefs.getBoolean(PREF_PURE_BLACK, false)

    private val pageBg: Int
        get() = when {
            !dark -> Color.WHITE
            pureBlack -> Color.BLACK
            else -> Color.rgb(25, 26, 28)
        }

    private val toolbarBg: Int
        get() = pageToolbarColor ?: when {
            !dark -> Color.WHITE
            pureBlack -> Color.rgb(16, 16, 16)
            else -> Color.rgb(31, 33, 36)
        }

    private val primaryText: Int
        get() = if (dark) {
            Color.rgb(232, 234, 237)
        } else {
            Color.rgb(32, 33, 36)
        }

    private val secondaryText: Int
        get() = if (dark) {
            Color.rgb(174, 178, 184)
        } else {
            Color.rgb(95, 99, 104)
        }

    private val accent: Int
        get() = if (dark) {
            Color.rgb(138, 180, 248)
        } else {
            Color.rgb(26, 115, 232)
        }

    private val adBlockEnabled: Boolean
        get() = prefs.getBoolean(PREF_AD_BLOCK, true)

    override fun onCreate(savedInstanceState: Bundle?) {
        // A WebView derives prefers-color-scheme from android:isLightTheme.
        // Set this Activity's local mode before creating the WebView.
        val requestedTheme = if (intent.getBooleanExtra(EXTRA_INCOGNITO, false)) {
            "dark"
        } else {
            getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(PREF_THEME_MODE, "system") ?: "system"
        }
        delegate.localNightMode = when (requestedTheme) {
            "dark" -> AppCompatDelegate.MODE_NIGHT_YES
            "light" -> AppCompatDelegate.MODE_NIGHT_NO
            else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
        }

        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.setSoftInputMode(
            android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        )

        currentUrl = savedInstanceState?.getString(STATE_URL)
            ?: intent.getStringExtra(EXTRA_URL)?.takeIf { it.isNotBlank() }
            ?: "https://www.google.com"

        currentTitle = savedInstanceState?.getString(STATE_TITLE).orEmpty()
        pendingRestoredScrollX = savedInstanceState?.getInt(STATE_SCROLL_X)
        pendingRestoredScrollY = savedInstanceState?.getInt(STATE_SCROLL_Y)
        tabId = intent.getStringExtra(EXTRA_TAB_ID).orEmpty()
        tabCount = intent.getIntExtra(EXTRA_TAB_COUNT, 1).coerceAtLeast(1)
        incognito = intent.getBooleanExtra(EXTRA_INCOGNITO, false)
        previewOnly = intent.getBooleanExtra(EXTRA_PREVIEW_ONLY, false)
        menuLabels = runCatching {
            JSONObject(intent.getStringExtra(EXTRA_MENU_LABELS_JSON) ?: "{}")
        }.getOrDefault(JSONObject())

        createInterface()
        configureWebView()

        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    if (customView != null) {
                        hideCustomView()
                    } else if (findBar.visibility == View.VISIBLE) {
                        closeFindBar()
                    } else if (webView.canGoBack()) {
                        webView.goBack()
                    } else {
                        finishToFlutter(
                            if (previewOnly) "previewClosed" else "home"
                        )
                    }
                }
            }
        )

        val restored = if (savedInstanceState != null) {
            val state = savedInstanceState.getBundle(STATE_WEBVIEW)
            state != null && webView.restoreState(state) != null
        } else {
            restoreTabState()
        }

        if (restored) {
            currentUrl = webView.url?.takeIf { it.isNotBlank() } ?: currentUrl
            currentTitle = webView.title?.takeIf { it.isNotBlank() } ?: currentTitle
            refreshTitle()
        } else {
            webView.loadUrl(currentUrl)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(STATE_URL, currentUrl)
        outState.putString(STATE_TITLE, currentTitle)
        outState.putInt(STATE_SCROLL_X, webView.scrollX)
        outState.putInt(STATE_SCROLL_Y, webView.scrollY)
        outState.putBundle(
            STATE_WEBVIEW,
            Bundle().also { webView.saveState(it) }
        )
    }

    private fun createInterface() {
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(pageBg)
            layoutParams = ViewGroup.LayoutParams(-1, -1)
        }

        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            view.setPadding(0, bars.top, 0, maxOf(bars.bottom, ime.bottom))
            insets
        }

        toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(6), dp(5), dp(6), dp(5))
            setBackgroundColor(toolbarBg)
        }

        val home = actionButton("home", "Início") {
            finishToFlutter("home")
        }

        toolbar.addView(home, LinearLayout.LayoutParams(dp(42), dp(46)))

        titlePill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), 0, dp(12), 0)
            background = rounded(toolbarPillColor(), 24)
            isClickable = true
            isFocusable = true
            setOnClickListener { finishToFlutter("search") }
        }

        faviconView = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageDrawable(
                MaterialSymbolsRounded.bitmapDrawable(
                    this@OrbitBrowserActivity,
                    "search",
                    secondaryText,
                    dp(18),
                )
            )
        }

        titlePill.addView(
            faviconView,
            LinearLayout.LayoutParams(dp(18), dp(18))
        )

        titleView = TextView(this).apply {
            text = currentTitle.ifBlank { hostOf(currentUrl) }
            setTextColor(toolbarText())
            textSize = 14f
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(dp(9), 0, 0, 0)
            typeface = android.graphics.Typeface.create(
                "sans-serif-medium",
                android.graphics.Typeface.NORMAL
            )
        }

        titlePill.addView(
            titleView,
            LinearLayout.LayoutParams(0, -2, 1f)
        )

        toolbar.addView(
            titlePill,
            LinearLayout.LayoutParams(0, dp(42), 1f).apply {
                marginStart = dp(3)
                marginEnd = dp(3)
            }
        )

        tabsButton = tabCountButton(tabCount) {
            finishToFlutter("tabs")
        }

        toolbar.addView(
            tabsButton,
            LinearLayout.LayoutParams(dp(42), dp(46))
        )

        // Mantém os três pontos verticais do Orbit; o menu usa PopupWindow
        // arredondado, mas o botão original da barra não é substituído.
        moreButton = actionButton("more_vert", menuText("options", "More options")) {
            showBrowserPopupMenu(moreButton)
        }
        toolbar.addView(moreButton, LinearLayout.LayoutParams(dp(42), dp(46)))

        progress = ProgressBar(
            this,
            null,
            android.R.attr.progressBarStyleHorizontal
        ).apply {
            max = 100
            progress = 0
            progressTintList =
                android.content.res.ColorStateList.valueOf(accent)
            progressBackgroundTintList =
                android.content.res.ColorStateList.valueOf(toolbarBg)
            visibility = View.GONE
        }

        // A barra e a linha de progresso pertencem ao mesmo contentor. Ao
        // recolher o app bar, a altura real do contentor passa a zero; não
        // fica uma faixa vazia entre a barra e a página.
        appBarContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(toolbarBg)
            clipChildren = true
            clipToPadding = true
            addView(toolbar, LinearLayout.LayoutParams(-1, dp(56)))
            addView(progress, LinearLayout.LayoutParams(-1, dp(2)))
        }
        root.addView(appBarContainer, LinearLayout.LayoutParams(-1, dp(58)))

        findBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(4), dp(6), dp(4))
            setBackgroundColor(toolbarBg)
            visibility = View.GONE
        }

        findField = EditText(this).apply {
            setSingleLine(true)
            textSize = 14f
            setTextColor(primaryText)
            setHintTextColor(secondaryText)
            hint = "Localizar na página"
            background = null
            imeOptions = EditorInfo.IME_ACTION_SEARCH
            inputType = InputType.TYPE_CLASS_TEXT

            setOnEditorActionListener { _, _, _ ->
                webView.findNext(true)
                true
            }

            addTextChangedListener(object : android.text.TextWatcher {
                override fun beforeTextChanged(
                    s: CharSequence?,
                    start: Int,
                    count: Int,
                    after: Int
                ) = Unit

                override fun onTextChanged(
                    s: CharSequence?,
                    start: Int,
                    before: Int,
                    count: Int
                ) {
                    val query = s?.toString().orEmpty()
                    if (query.isBlank()) {
                        webView.clearMatches()
                    } else {
                        webView.findAllAsync(query)
                    }
                }

                override fun afterTextChanged(s: android.text.Editable?) = Unit
            })
        }

        findBar.addView(
            findField,
            LinearLayout.LayoutParams(0, dp(42), 1f)
        )

        findBar.addView(
            actionButton("arrow_upward", "Resultado anterior") {
                webView.findNext(false)
            },
            LinearLayout.LayoutParams(dp(38), dp(42))
        )

        findBar.addView(
            actionButton("arrow_downward", "Resultado seguinte") {
                webView.findNext(true)
            },
            LinearLayout.LayoutParams(dp(38), dp(42))
        )

        findBar.addView(
            actionButton("close", menuText("closeSearch", "Close search")) {
                closeFindBar()
            },
            LinearLayout.LayoutParams(dp(38), dp(42))
        )

        root.addView(findBar, LinearLayout.LayoutParams(-1, dp(50)))

        webView = WebView(this).apply {
            setBackgroundColor(pageBg)
            overScrollMode = View.OVER_SCROLL_NEVER
        }

        root.addView(webView, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(root)
        applySystemBars()

        if (Build.VERSION.SDK_INT >= 23) {
            webView.setOnScrollChangeListener {
                    _, _, scrollY, _, oldScrollY ->
                val delta = scrollY - oldScrollY
                if (delta == 0) return@setOnScrollChangeListener

                // A alteração da altura da AppBar pode produzir callbacks de
                // compensação do WebView. Estes não são gestos do utilizador e
                // ficam fora da acumulação direcional até o layout estabilizar.
                if (SystemClock.uptimeMillis() < toolbarScrollFreezeUntilMs) {
                    lastScrollDirection = 0
                    accumulatedScrollDelta = 0
                    reverseScrollDelta = 0
                    return@setOnScrollChangeListener
                }
                if (abs(delta) < dp(2)) return@setOnScrollChangeListener

                // No topo, a barra fica sempre visível e a memória de direção
                // é reiniciada para não transportar oscilações entre páginas.
                if (scrollY <= dp(4)) {
                    lastScrollDirection = 0
                    accumulatedScrollDelta = 0
                    reverseScrollDelta = 0
                    hideToolbar(false)
                    return@setOnScrollChangeListener
                }

                val direction = if (delta > 0) 1 else -1
                val distance = abs(delta)

                if (lastScrollDirection == 0) {
                    lastScrollDirection = direction
                    accumulatedScrollDelta = distance
                    reverseScrollDelta = 0
                } else if (direction == lastScrollDirection) {
                    // Pequenas inversões em gestos lentos são descontadas,
                    // em vez de trocar imediatamente o estado da barra.
                    if (reverseScrollDelta > 0) {
                        accumulatedScrollDelta =
                            (accumulatedScrollDelta - reverseScrollDelta).coerceAtLeast(0)
                        reverseScrollDelta = 0
                    }
                    accumulatedScrollDelta += distance
                } else {
                    // Uma inversão só é aceite após uma distância consistente.
                    // O filtro evita alternância causada por sub-píxeis e por
                    // páginas que atualizam o scroll de forma incremental.
                    reverseScrollDelta += distance
                    val reversalThreshold = dp(22)
                    if (reverseScrollDelta < reversalThreshold) {
                        return@setOnScrollChangeListener
                    }

                    lastScrollDirection = direction
                    accumulatedScrollDelta =
                        (reverseScrollDelta - reversalThreshold).coerceAtLeast(0)
                    reverseScrollDelta = 0
                }

                val triggerDistance = if (direction > 0) dp(48) else dp(30)
                if (direction > 0 && scrollY > dp(112) &&
                    accumulatedScrollDelta >= triggerDistance
                ) {
                    hideToolbar(true)
                    accumulatedScrollDelta = 0
                } else if (direction < 0 &&
                    accumulatedScrollDelta >= triggerDistance
                ) {
                    hideToolbar(false)
                    accumulatedScrollDelta = 0
                }
            }
        }
    }

    /**
     * Usa o escurecimento moderno do Android System WebView.
     *
     * O algoritmo respeita o tema escuro implementado pelo próprio site e
     * só tenta escurecer algoritmicamente páginas sem tema escuro próprio,
     * quando o site não desativou explicitamente esta possibilidade.
     */
    private fun applyWebsiteDarkMode(settings: WebSettings) {
        val shouldDarken = dark &&
            (incognito || prefs.getBoolean(PREF_FORCE_DARK, false))

        try {
            if (WebViewFeature.isFeatureSupported(
                    WebViewFeature.ALGORITHMIC_DARKENING
                )
            ) {
                WebSettingsCompat.setAlgorithmicDarkeningAllowed(
                    settings,
                    shouldDarken
                )
                return
            }

            // Compatibilidade para WebViews antigos. Em apps com target SDK 33+
            // a API FORCE_DARK é ignorada, por isso não é usada nesse cenário.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
                WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)
            ) {
                @Suppress("DEPRECATION")
                WebSettingsCompat.setForceDark(
                    settings,
                    if (shouldDarken) {
                        WebSettingsCompat.FORCE_DARK_ON
                    } else {
                        WebSettingsCompat.FORCE_DARK_OFF
                    }
                )

                if (WebViewFeature.isFeatureSupported(
                        WebViewFeature.FORCE_DARK_STRATEGY
                    )
                ) {
                    @Suppress("DEPRECATION")
                    WebSettingsCompat.setForceDarkStrategy(
                        settings,
                        WebSettingsCompat.DARK_STRATEGY_PREFER_WEB_THEME_OVER_USER_AGENT_DARKENING
                    )
                }
            }
        } catch (_: UnsupportedOperationException) {
            // O WebView instalado pode não disponibilizar o recurso.
        } catch (_: RuntimeException) {
            // Uma implementação OEM incompatível não deve interromper a navegação.
        }
    }

    private fun configureWebView() {
        val settings = webView.settings

        settings.javaScriptEnabled = true
        settings.domStorageEnabled = !incognito
        settings.databaseEnabled = !incognito
        settings.loadsImagesAutomatically = true
        settings.loadWithOverviewMode = false
        settings.useWideViewPort = true
        settings.setSupportZoom(true)
        settings.builtInZoomControls = true
        settings.displayZoomControls = false
        settings.textZoom = textSizePercent

        settings.cacheMode = if (incognito) {
            WebSettings.LOAD_NO_CACHE
        } else {
            WebSettings.LOAD_DEFAULT
        }

        applyWebsiteDarkMode(settings)

        settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        settings.mediaPlaybackRequiresUserGesture = true
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.setSupportMultipleWindows(false)
        settings.allowFileAccess = false
        settings.allowContentAccess = true

        if (Build.VERSION.SDK_INT >= 26) {
            settings.safeBrowsingEnabled = true
        }

        originalUserAgent = settings.userAgentString

        CookieManager.getInstance().setAcceptCookie(!incognito)
        CookieManager.getInstance().setAcceptThirdPartyCookies(
            webView,
            !incognito
        )

        webView.webViewClient = object : WebViewClient() {

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean {
                val uri = request.url
                val scheme = uri.scheme?.lowercase(Locale.ROOT).orEmpty()

                if (scheme == "http" || scheme == "https") return false

                return openExternalUri(uri)
            }

            @Suppress("DEPRECATION")
            override fun shouldOverrideUrlLoading(
                view: WebView,
                url: String
            ): Boolean {
                val uri = Uri.parse(url)

                if (uri.scheme == "http" || uri.scheme == "https") {
                    return false
                }

                return openExternalUri(uri)
            }

            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest
            ): WebResourceResponse? {
                if (!incognito && adBlockEnabled && isBlocked(request.url)) {
                    recordBlockedRequest()
                    return WebResourceResponse(
                        "text/plain",
                        "utf-8",
                        ByteArrayInputStream(ByteArray(0))
                    )
                }

                return super.shouldInterceptRequest(view, request)
            }

            override fun onPageStarted(
                view: WebView,
                url: String,
                favicon: Bitmap?
            ) {
                currentUrl = url
                pageToolbarColor = null
                lastScrollDirection = 0
                accumulatedScrollDelta = 0
                reverseScrollDelta = 0
                appliedPageZoomPercent = 100
                hideToolbar(false)
                progress.progress = 0
                progress.visibility = View.VISIBLE
                refreshTitle()
                updateToolbarColors()
            }

            override fun onPageFinished(view: WebView, url: String) {
                currentUrl = url
                currentTitle = view.title?.takeIf { it.isNotBlank() } ?: hostOf(url)

                progress.progress = 100
                progress.postDelayed({
                    if (!isFinishing && progress.progress == 100) {
                        progress.visibility = View.GONE
                    }
                }, 260)

                refreshTitle()
                updateToolbarColors()
                view.post {
                    val restoredX = pendingRestoredScrollX
                    val restoredY = pendingRestoredScrollY
                    if (restoredX != null || restoredY != null) {
                        view.scrollTo(restoredX ?: 0, restoredY ?: 0)
                        pendingRestoredScrollX = null
                        pendingRestoredScrollY = null
                    }
                    applyPageZoomToCurrentPage()
                    view.postDelayed({
                        if (!isFinishing && !incognito && view.url == currentUrl) {
                            persistTabState()
                        }
                    }, 350L)
                }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                if (request.isForMainFrame) {
                    Toast.makeText(
                        this@OrbitBrowserActivity,
                        error.description?.toString()
                            ?: menuText("loadingError", "Could not load this page."),
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
        }

        webView.webChromeClient = object : WebChromeClient() {

            override fun onProgressChanged(view: WebView, newProgress: Int) {
                progress.progress = newProgress
                progress.visibility = if (newProgress >= 100) {
                    View.GONE
                } else {
                    View.VISIBLE
                }
            }

            override fun onReceivedTitle(view: WebView, title: String?) {
                if (!title.isNullOrBlank()) currentTitle = title
                refreshTitle()
            }

            override fun onReceivedIcon(view: WebView, icon: Bitmap?) {
                if (icon != null) {
                    faviconView.setImageDrawable(BitmapDrawable(resources, icon))
                }
            }

            override fun onShowCustomView(
                view: View,
                callback: CustomViewCallback
            ) {
                if (customView != null) {
                    callback.onCustomViewHidden()
                    return
                }

                customView = view
                customViewCallback = callback

                root.removeView(webView)
                root.addView(view, LinearLayout.LayoutParams(-1, 0, 1f))

                appBarContainer.visibility = View.GONE
                progress.visibility = View.GONE

                window.decorView.systemUiVisibility =
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            }

            override fun onHideCustomView() {
                hideCustomView()
            }
        }

        webView.setDownloadListener(
            DownloadListener { url, userAgent, disposition, mimeType, _ ->
                if (incognito) {
                    Toast.makeText(
                        this,
                        "Transferências desativadas no modo privado.",
                        Toast.LENGTH_SHORT
                    ).show()
                } else {
                    startDownload(url, userAgent, disposition, mimeType)
                }
            }
        )

        webView.setOnLongClickListener {
            val hit = webView.hitTestResult
            val target = hit.extra?.takeIf { it.isNotBlank() }

            if (target.isNullOrBlank()) {
                return@setOnLongClickListener false
            }

            showElementSheet(target, hit.type)
            true
        }
    }

    private fun actionButton(
        symbol: String,
        description: String,
        onClick: () -> Unit
    ): android.widget.FrameLayout {
        return android.widget.FrameLayout(this).apply {
            contentDescription = description
            isClickable = true
            isFocusable = true
            background = selectableBackground()
            addView(
                MaterialSymbolsRounded.textView(
                    this@OrbitBrowserActivity,
                    symbol,
                    toolbarText(),
                    21f,
                ),
                android.widget.FrameLayout.LayoutParams(dp(28), dp(28), Gravity.CENTER),
            )
            setOnClickListener { onClick() }
        }
    }

    private fun tabCountButton(count: Int, onClick: () -> Unit): android.widget.FrameLayout {
        return android.widget.FrameLayout(this).apply {
            contentDescription = "Separadores: $count"
            isClickable = true
            isFocusable = true
            background = selectableBackground()
            val icon = ImageView(this@OrbitBrowserActivity).apply {
                setImageDrawable(
                    MaterialSymbolsRounded.tabsCounterDrawable(
                        this@OrbitBrowserActivity,
                        count,
                        toolbarText(),
                        dp(25),
                    )
                )
            }
            addView(icon, android.widget.FrameLayout.LayoutParams(dp(25), dp(25), Gravity.CENTER))
            setOnClickListener { onClick() }
        }
    }

    private fun tintTabCountButton(color: Int) {
        if (!::tabsButton.isInitialized) return
        (tabsButton.getChildAt(0) as? ImageView)?.setImageDrawable(
            MaterialSymbolsRounded.tabsCounterDrawable(this, tabCount, color, dp(25))
        )
    }

    private fun tintMenuOptionsButton(color: Int) {
        if (!::moreButton.isInitialized) return
        val icon = (moreButton as? ViewGroup)?.getChildAt(0) as? TextView ?: return
        icon.setTextColor(color)
    }

    private fun showAddressDialog() {
        val input = EditText(this).apply {
            setSingleLine(true)
            textSize = 15f
            setTextColor(primaryText)
            setHintTextColor(secondaryText)
            hint = menuText("searchHint", "Search or enter a URL")
            setText(currentUrl)
            setSelection(text.length)
            inputType = InputType.TYPE_CLASS_TEXT or
                InputType.TYPE_TEXT_VARIATION_URI
            imeOptions = EditorInfo.IME_ACTION_GO
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(8), dp(22), 0)
            addView(input, LinearLayout.LayoutParams(-1, dp(52)))
        }

        val dialog = MaterialAlertDialogBuilder(this)
            .setTitle(menuText("searchHint", "Search or open address"))
            .setView(container)
            .setNegativeButton(menuText("cancel", "Cancel"), null)
            .setPositiveButton(menuText("newTabLabel", "Open"), null)
            .create()

        dialog.setOnShowListener {
            dialog.getButton(android.app.AlertDialog.BUTTON_POSITIVE)
                .setOnClickListener {
                    val value = input.text?.toString().orEmpty()
                    dialog.dismiss()
                    loadAddress(value)
                }

            input.requestFocus()
            input.post {
                (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager)
                    .showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
            }

            input.setOnEditorActionListener { _, actionId, event ->
                val enter = event?.keyCode == KeyEvent.KEYCODE_ENTER &&
                    event.action == KeyEvent.ACTION_UP

                if (actionId == EditorInfo.IME_ACTION_GO || enter) {
                    dialog.dismiss()
                    loadAddress(input.text?.toString().orEmpty())
                    true
                } else {
                    false
                }
            }
        }

        dialog.show()
    }

    private fun loadAddress(raw: String) {
        val value = raw.trim()
        if (value.isEmpty()) return

        val target = when {
            value.startsWith("https://", true) ||
                value.startsWith("http://", true) -> value

            value.contains(" ") || !value.contains(".") ->
                "https://www.google.com/search?q=" + Uri.encode(value)

            else -> "https://$value"
        }

        val uri = Uri.parse(target)

        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) {
            Toast.makeText(this, menuText("validAddress", "Enter a valid HTTP or HTTPS address."), Toast.LENGTH_SHORT).show()
            return
        }

        webView.loadUrl(uri.toString())
    }

    private fun menuText(key: String, fallback: String): String {
        return menuLabels.optString(key).takeIf { it.isNotBlank() } ?: fallback
    }

    private fun showBrowserPopupMenu(anchor: View) {
        if (previewOnly || isFinishing || !anchor.isAttachedToWindow) return

        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        val popupWidth = minOf(dp(420), screenWidth - dp(24)).coerceAtLeast(dp(260))
        // Não ocupar o ecrã todo: o menu é um painel compacto com a lista
        // interna a rolar, sem empurrar o conteúdo até ao fundo do telemóvel.
        val maxPopupHeight = (screenHeight * .62f).toInt().coerceAtLeast(dp(300))
        val surface = when {
            !dark -> Color.WHITE
            pureBlack -> Color.rgb(16, 16, 16)
            else -> Color.rgb(43, 45, 48)
        }
        val quickSurface = when {
            !dark -> Color.rgb(241, 243, 244)
            pureBlack -> Color.rgb(25, 25, 25)
            else -> Color.rgb(31, 33, 36)
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = rounded(surface, 27)
            clipToOutline = true
        }

        val quickRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(5), dp(7), dp(5), dp(9))
        }

        fun quickAction(glyph: String, description: String, enabled: Boolean = true, action: () -> Unit) {
            val frame = android.widget.FrameLayout(this).apply {
                isClickable = enabled
                isFocusable = enabled
                alpha = if (enabled) 1f else .38f
                background = rounded(quickSurface, 999)
                addView(
                    ImageView(this@OrbitBrowserActivity).apply {
                        setImageDrawable(
                            MaterialSymbolsRounded.bitmapDrawable(
                                this@OrbitBrowserActivity,
                                glyph,
                                primaryText,
                                dp(21),
                            )
                        )
                        scaleType = ImageView.ScaleType.FIT_CENTER
                        contentDescription = description
                    },
                    android.widget.FrameLayout.LayoutParams(dp(22), dp(22), Gravity.CENTER),
                )
                setOnClickListener {
                    if (enabled) {
                        popupWindowRef?.dismiss()
                        action()
                    }
                }
            }
            quickRow.addView(
                frame,
                LinearLayout.LayoutParams(0, dp(48), 1f).apply {
                    marginStart = dp(3)
                    marginEnd = dp(3)
                },
            )
        }

        // The five top actions mirror the compact Chrome-style shortcut row.
        quickAction("arrow_forward", menuText("forward", "Forward"), webView.canGoForward()) {
            webView.goForward()
        }
        quickAction("star", menuText("bookmark", "Bookmark")) {
            finishToFlutter("bookmark")
        }
        quickAction("download", menuText("downloads", "Downloads")) {
            finishToFlutter("downloads")
        }
        quickAction("info", menuText("siteInfo", "Site information")) {
            showSiteInfo()
        }
        quickAction("refresh", menuText("reload", "Reload page")) {
            webView.reload()
        }
        content.addView(quickRow, LinearLayout.LayoutParams(-1, dp(64)))

        val dividerColor = when {
            !dark -> Color.rgb(232, 234, 237)
            pureBlack -> Color.rgb(41, 41, 41)
            else -> Color.rgb(52, 54, 58)
        }
        val divider = View(this).apply { setBackgroundColor(dividerColor) }
        content.addView(divider, LinearLayout.LayoutParams(-1, dp(1)).apply {
            leftMargin = dp(8)
            rightMargin = dp(8)
            bottomMargin = dp(5)
        })

        val menuScroll = ScrollView(this).apply {
            isFillViewport = false
            overScrollMode = View.OVER_SCROLL_NEVER
            clipToPadding = false
            setPadding(0, 0, 0, dp(2))
        }
        val menuItems = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        menuScroll.addView(menuItems, ScrollView.LayoutParams(-1, -2))

        fun menuRow(label: String, glyph: String, action: () -> Unit) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(13), 0, dp(13), 0)
                minimumHeight = dp(51)
                background = selectableBackground()
                isClickable = true
                isFocusable = true
                addView(
                    ImageView(this@OrbitBrowserActivity).apply {
                        setImageDrawable(
                            MaterialSymbolsRounded.bitmapDrawable(
                                this@OrbitBrowserActivity,
                                glyph,
                                secondaryText,
                                dp(21),
                            )
                        )
                        scaleType = ImageView.ScaleType.FIT_CENTER
                    },
                    LinearLayout.LayoutParams(dp(24), dp(24)),
                )
                addView(View(this@OrbitBrowserActivity), LinearLayout.LayoutParams(dp(14), 1))
                addView(
                    TextView(this@OrbitBrowserActivity).apply {
                        text = label
                        setTextColor(primaryText)
                        textSize = 14f
                        maxLines = 2
                        ellipsize = android.text.TextUtils.TruncateAt.END
                        gravity = Gravity.CENTER_VERTICAL
                    },
                    LinearLayout.LayoutParams(0, -2, 1f),
                )
                setOnClickListener {
                    popupWindowRef?.dismiss()
                    action()
                }
            }
            menuItems.addView(row, LinearLayout.LayoutParams(-1, dp(51)))
        }

        fun menuDivider() {
            menuItems.addView(View(this).apply { setBackgroundColor(dividerColor) },
                LinearLayout.LayoutParams(-1, dp(1)).apply {
                    marginStart = dp(10)
                    marginEnd = dp(10)
                    topMargin = dp(5)
                    bottomMargin = dp(5)
                })
        }

        menuRow(menuText("newTab", "New tab"), "add_box") {
            finishToFlutter("newTab")
        }
        menuRow(menuText("tabs", "Manage tabs"), "tab") {
            finishToFlutter("tabs")
        }
        if (!incognito) {
            menuRow(menuText("bookmarks", "Bookmarks"), "bookmarks") {
                finishToFlutter("bookmarks")
            }
            menuRow(menuText("history", "History"), "history") {
                finishToFlutter("history")
            }
            menuDivider()
            menuRow(menuText("downloads", "Downloads"), "download") {
                finishToFlutter("downloads")
            }
        }
        menuRow(menuText("find", "Find in page"), "search") { openFindBar() }
        menuRow(
            menuText(if (desktopMode) "desktopOff" else "desktop", if (desktopMode) "Turn off desktop site" else "Desktop site"),
            "desktop_windows",
        ) { toggleDesktopMode() }
        menuRow(menuText("translate", "Translate"), "translate") { translatePage() }
        menuDivider()
        menuRow(menuText("fontSize", "Font size"), "text_fields") { showScaleCard(pageScale = false) }
        menuRow(menuText("pageZoom", "Page zoom"), "zoom_in") { showScaleCard(pageScale = true) }
        menuRow(menuText("print", "Print page"), "print") { printPage() }
        menuRow(menuText("share", "Share page"), "share") { shareAddress() }
        menuRow(menuText("settings", "Browser settings"), "settings") { finishToFlutter("settings") }
        val menuHeight = minOf(dp(560), maxPopupHeight - dp(90)).coerceAtLeast(dp(150))
        content.addView(menuScroll, LinearLayout.LayoutParams(-1, menuHeight))
        val popupHeight = (menuHeight + dp(86)).coerceAtMost(maxPopupHeight)

        val popup = PopupWindow(
            content,
            popupWidth,
            popupHeight,
            true,
        ).apply {
            setBackgroundDrawable(rounded(surface, 27))
            setElevation(dp(18).toFloat())
            isOutsideTouchable = true
            isClippingEnabled = true
            inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                enterTransition = Fade().apply { duration = 150 }
                exitTransition = Fade().apply { duration = 110 }
            }
        }
        popupWindowRef = popup
        popup.setOnDismissListener {
            if (popupWindowRef === popup) popupWindowRef = null
        }
        popup.showAsDropDown(anchor, dp(2), dp(5), Gravity.END)
    }

    private var popupWindowRef: PopupWindow? = null

    private fun shareText(value: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, value)
        }

        startActivity(Intent.createChooser(send, menuText("share", "Share link")))
    }

    private fun startDownload(
        url: String,
        userAgent: String?,
        contentDisposition: String?,
        mimeType: String?
    ) {
        try {
            val uri = Uri.parse(url)
            if (uri.scheme != "http" && uri.scheme != "https") {
                Toast.makeText(this, "Este tipo de transferência não pode ser enviado para a lista da aplicação.", Toast.LENGTH_LONG).show()
                return
            }
            val filename = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val resolvedMime = mimeType ?: URLConnection.guessContentTypeFromName(filename)
            val headers = hashMapOf<String, String>()
            headers["User-Agent"] = userAgent ?: webView.settings.userAgentString
            headers["Referer"] = currentUrl
            CookieManager.getInstance().getCookie(url)?.takeIf { it.isNotBlank() }?.let {
                headers["Cookie"] = it
            }
            MainActivity.notifyNativeDownloadRequested(
                url = url,
                filename = filename,
                mimeType = resolvedMime,
                headers = headers,
            )
            Toast.makeText(this, menuText("downloadReceived", "Download added to Downloads"), Toast.LENGTH_SHORT).show()
        } catch (_: Exception) {
            Toast.makeText(this, menuText("downloadFailed", "Download failed"), Toast.LENGTH_SHORT).show()
        }
    }

    private fun openExternalUri(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase(Locale.ROOT) ?: return true

        if (scheme == "http" || scheme == "https") return false

        return try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
            true
        } catch (_: Exception) {
            Toast.makeText(
                this,
                "Não existe uma aplicação compatível para abrir esta ligação.",
                Toast.LENGTH_SHORT
            ).show()
            true
        }
    }

    private fun isBlocked(uri: Uri): Boolean {
        val host = uri.host?.lowercase(Locale.ROOT)?.trimEnd('.') ?: return false

        if (blockedDomains.any { host == it || host.endsWith(".$it") }) {
            return true
        }

        val labels = host.split('.').flatMap { it.split('-') }

        val blockedLabels = setOf(
            "ad", "ads", "adserver", "adservice",
            "advertising", "banner", "popunder",
            "tracking", "tracker", "pixel",
            "beacon", "affiliate", "prebid"
        )

        if (labels.any { it in blockedLabels }) return true

        return Regex(
            "(?:^|/)(?:ads?|adserver|adservice|advertising|banners?|popunder|trackers?|tracking|pixels?|beacons?)(?:[/._-]|$)",
            RegexOption.IGNORE_CASE
        ).containsMatchIn(uri.encodedPath.orEmpty())
    }

    private fun recordBlockedRequest() {
        if (incognito) return

        try {
            val raw = prefs.getString(PREF_ADBLOCK_STATS, "{}") ?: "{}"
            val json = org.json.JSONObject(raw)

            val day = java.text.SimpleDateFormat(
                "yyyy-MM-dd",
                Locale.US
            ).format(java.util.Date())

            json.put(day, json.optInt(day, 0) + 1)

            prefs.edit()
                .putString(PREF_ADBLOCK_STATS, json.toString())
                .apply()
        } catch (_: Exception) {
        }
    }

    private fun refreshTitle() {
        if (!::titleView.isInitialized) return

        val address = runCatching {
            val uri = Uri.parse(currentUrl)
            uri.host?.removePrefix("www.")?.ifBlank { currentUrl } ?: currentUrl
        }.getOrDefault(currentUrl)

        titleView.text = address.ifBlank {
            currentTitle.ifBlank { "BrowseIt" }
        }
    }

    private fun updateToolbarColors() {
        val adaptive =
            prefs.getBoolean(PREF_ADAPTIVE_TOOLBAR, false) && !incognito

        if (!adaptive) {
            pageToolbarColor = null
            applySystemBars()
            return
        }

        webView.evaluateJavascript(
            """
            (() => {
                const meta = document.querySelector('meta[name="theme-color"]');
                if (meta && meta.content) return meta.content;

                const body = document.body
                    ? getComputedStyle(document.body).backgroundColor
                    : '';

                if (body && body !== 'transparent' &&
                    body !== 'rgba(0, 0, 0, 0)') {
                    return body;
                }

                return '';
            })();
            """.trimIndent()
        ) { value ->
            val parsed = parseCssColor(value?.trim('"'))

            if (parsed != null) {
                pageToolbarColor = parsed
                applySystemBars()
                toolbar.setBackgroundColor(toolbarBg)
                appBarContainer.setBackgroundColor(toolbarBg)
                titlePill.background = rounded(toolbarPillColor(), 24)

                titleView.setTextColor(toolbarText())
                tintTabCountButton(toolbarText())
                tintMenuOptionsButton(toolbarText())
            }
        }
    }

    private fun parseCssColor(value: String?): Int? {
        if (value.isNullOrBlank() || value == "null") return null

        try {
            return Color.parseColor(value)
        } catch (_: Exception) {
        }

        val match = Regex(
            "rgba?\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})"
        ).find(value) ?: return null

        val red = match.groupValues[1].toIntOrNull()?.coerceIn(0, 255) ?: return null
        val green = match.groupValues[2].toIntOrNull()?.coerceIn(0, 255) ?: return null
        val blue = match.groupValues[3].toIntOrNull()?.coerceIn(0, 255) ?: return null

        return Color.rgb(red, green, blue)
    }

    private fun toolbarText(): Int {
        val color = toolbarBg

        val luminance = (
            0.2126 * Color.red(color) +
                0.7152 * Color.green(color) +
                0.0722 * Color.blue(color)
            ) / 255.0

        return if (luminance > .55) {
            Color.rgb(32, 33, 36)
        } else {
            Color.rgb(245, 246, 247)
        }
    }

    private fun toolbarPillColor(): Int {
        return if (dark) {
            Color.rgb(46, 48, 52)
        } else {
            Color.rgb(241, 243, 244)
        }
    }

    private fun applySystemBars() {
        val status = toolbarBg

        window.statusBarColor = status
        window.navigationBarColor = pageBg

        val controller = WindowInsetsControllerCompat(window, root)
        controller.isAppearanceLightStatusBars = isLight(status)
        controller.isAppearanceLightNavigationBars = !dark

        if (Build.VERSION.SDK_INT >= 29) {
            window.isNavigationBarContrastEnforced = false
        }
    }

    private fun isLight(color: Int): Boolean {
        val luminance = (
            0.2126 * Color.red(color) +
                0.7152 * Color.green(color) +
                0.0722 * Color.blue(color)
            ) / 255.0

        return luminance > .55
    }

    private fun hideToolbar(hide: Boolean) {
        if (previewOnly || !::appBarContainer.isInitialized) return
        // Não cancelar/reiniciar a animação se a direção pedida já está ativa.
        if (toolbarHidden == hide) return

        toolbarHidden = hide
        toolbarScrollFreezeUntilMs = SystemClock.uptimeMillis() + 330L
        lastScrollDirection = 0
        accumulatedScrollDelta = 0
        reverseScrollDelta = 0
        appBarAnimator?.removeAllListeners()
        appBarAnimator?.cancel()
        appBarContainer.animate().cancel()

        val targetHeight = if (hide) 0 else dp(58)
        val currentHeight = appBarContainer.layoutParams.height
            .takeIf { it >= 0 } ?: appBarContainer.height

        if (hide && currentHeight <= 0) {
            appBarContainer.visibility = View.GONE
            return
        }

        if (!hide) {
            appBarContainer.visibility = View.VISIBLE
            if (currentHeight <= 0) {
                appBarContainer.layoutParams = appBarContainer.layoutParams.apply {
                    height = 0
                }
            }
        }

        val startHeight = appBarContainer.layoutParams.height
            .takeIf { it >= 0 } ?: appBarContainer.height
        appBarAnimator = ValueAnimator.ofInt(startHeight, targetHeight).apply {
            duration = 220L
            interpolator = DecelerateInterpolator()
            addUpdateListener { animator ->
                val params = appBarContainer.layoutParams
                params.height = animator.animatedValue as Int
                appBarContainer.layoutParams = params
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    toolbarScrollFreezeUntilMs = SystemClock.uptimeMillis() + 110L
                    lastScrollDirection = 0
                    accumulatedScrollDelta = 0
                    reverseScrollDelta = 0
                    if (toolbarHidden) {
                        appBarContainer.visibility = View.GONE
                    } else {
                        appBarContainer.visibility = View.VISIBLE
                        appBarContainer.layoutParams = appBarContainer.layoutParams.apply {
                            height = dp(58)
                        }
                    }
                }
            })
            start()
        }
    }

    private fun hideCustomView() {
        val view = customView ?: return

        (view.parent as? ViewGroup)?.removeView(view)

        customView = null
        customViewCallback?.onCustomViewHidden()
        customViewCallback = null

        toolbar.visibility = View.VISIBLE
        toolbarHidden = false
        appBarAnimator?.removeAllListeners()
        appBarAnimator?.cancel()
        appBarContainer.visibility = View.VISIBLE
        appBarContainer.layoutParams = appBarContainer.layoutParams.apply {
            height = dp(58)
        }

        root.addView(
            webView,
            LinearLayout.LayoutParams(-1, 0, 1f)
        )

        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
        applySystemBars()
    }

    private fun finishToFlutter(action: String, newUrl: String? = null) {
        if (isFinishingWithResult) return

        isFinishingWithResult = true
        persistTabState()

        val output = Intent().apply {
            putExtra(RESULT_URL, currentUrl)
            putExtra(RESULT_TITLE, currentTitle)
            putExtra(RESULT_TAB_ID, tabId)
            putExtra(RESULT_ACTION, action)

            if (newUrl != null) {
                putExtra(RESULT_NEW_URL, newUrl)
            }

            if (!incognito && !previewOnly) {
                takeThumbnail()?.let {
                    putExtra(RESULT_THUMBNAIL, it)
                }
            }

            // A animação de Container Transform precisa da captura da Activity
            // completa (barra, progresso e página), não apenas da WebView usada
            // como miniatura do cartão. A imagem é transitória e não é guardada.
            if (action == "tabs" && !previewOnly) {
                takeBrowserTransitionScreenshot()?.let {
                    putExtra(RESULT_TRANSITION_SCREENSHOT, it)
                }
            }
        }

        setResult(Activity.RESULT_OK, output)
        finish()
        // Ao abrir a grelha, o Flutter executa o mesmo Container Transform
        // usado pela navegação principal. Uma animação de saída da Activity
        // aqui criava um segundo movimento e quebrava a continuidade visual.
        if (action == "tabs") {
            overridePendingTransition(0, 0)
        } else {
            overridePendingTransition(0, R.anim.browser_slide_down)
        }
    }

    private fun tabStateKey(): String? {
        if (tabId.isBlank() || incognito || previewOnly) return null

        val safeId = tabId
            .replace(Regex("[^A-Za-z0-9_-]"), "_")
            .take(100)

        return "tab_$safeId"
    }

    private fun restoreTabState(): Boolean {
        val key = tabStateKey() ?: return false
        val encoded = tabStatePrefs.getString(key, null) ?: return false

        if (encoded.isBlank() || encoded.length > MAX_TAB_STATE_CHARS) {
            return false
        }

        val bytes = try {
            Base64.decode(encoded, Base64.NO_WRAP)
        } catch (_: Exception) {
            return false
        }

        val parcel = Parcel.obtain()

        return try {
            parcel.unmarshall(bytes, 0, bytes.size)
            parcel.setDataPosition(0)

            val state = parcel.readBundle(javaClass.classLoader) ?: return false
            state.classLoader = javaClass.classLoader

            if (webView.restoreState(state) == null) return false
            pendingRestoredScrollX = state.getInt(STATE_SCROLL_X, 0)
            pendingRestoredScrollY = state.getInt(STATE_SCROLL_Y, 0)

            currentUrl = state.getString(STATE_URL) ?: webView.url ?: currentUrl
            currentTitle = state.getString(STATE_TITLE) ?: webView.title ?: currentTitle

            true
        } catch (_: Exception) {
            false
        } finally {
            parcel.recycle()
        }
    }

    private fun persistTabState() {
        val key = tabStateKey() ?: return

        if (!::webView.isInitialized || webView.url.isNullOrBlank()) {
            return
        }

        val state = Bundle().apply {
            putString(STATE_URL, webView.url ?: currentUrl)
            putString(STATE_TITLE, webView.title ?: currentTitle)
            putInt(STATE_SCROLL_X, webView.scrollX)
            putInt(STATE_SCROLL_Y, webView.scrollY)
        }

        try {
            webView.saveState(state)

            val parcel = Parcel.obtain()

            try {
                parcel.writeBundle(state)

                val bytes = parcel.marshall()
                val encoded = Base64.encodeToString(bytes, Base64.NO_WRAP)

                if (encoded.length <= MAX_TAB_STATE_CHARS) {
                    tabStatePrefs.edit()
                        .putString(key, encoded)
                        .apply()
                }
            } finally {
                parcel.recycle()
            }
        } catch (_: Exception) {
            // A navegação continua mesmo se o WebView não conseguir
            // serializar a sessão.
        }
    }

    override fun onPause() {
        persistTabState()
        super.onPause()
    }

    override fun onDestroy() {
        if (incognito) {
            CookieManager.getInstance().setAcceptCookie(true)
        }

        if (::webView.isInitialized) {
            (webView.parent as? ViewGroup)?.removeView(webView)
            webView.stopLoading()
            webView.webChromeClient = null
            // webViewClient não é nulável neste WebView; um client vazio
            // evita callbacks na view já destacada sem violar o tipo.
            webView.webViewClient = object : WebViewClient() {}
            webView.destroy()
        }

        super.onDestroy()
    }

    private fun takeBrowserTransitionScreenshot(): ByteArray? {
        return try {
            val target = root
            val width = target.width.coerceAtLeast(1)
            val height = target.height.coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            target.draw(Canvas(bitmap))

            ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 56, stream)
                bitmap.recycle()
                stream.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun takeThumbnail(): ByteArray? {
        return try {
            val bitmap = Bitmap.createBitmap(
                webView.width.coerceAtLeast(1),
                webView.height.coerceAtLeast(1),
                Bitmap.Config.ARGB_8888
            )

            webView.draw(Canvas(bitmap))

            ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 58, stream)
                bitmap.recycle()
                stream.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun hostOf(url: String): String {
        return Uri.parse(url).host ?: url
    }

    private fun rounded(color: Int, radiusDp: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radiusDp).toFloat()
            setColor(color)
        }
    }

    private fun selectableBackground(): android.graphics.drawable.Drawable? {
        return android.util.TypedValue().let { value ->
            theme.resolveAttribute(
                android.R.attr.selectableItemBackground,
                value,
                true
            )

            if (value.resourceId != 0) {
                getDrawable(value.resourceId)
            } else {
                null
            }
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}

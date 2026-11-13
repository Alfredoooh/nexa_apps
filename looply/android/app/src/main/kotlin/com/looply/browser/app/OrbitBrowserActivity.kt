package com.looply.browser.app

import android.app.Activity
import android.animation.ValueAnimator
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Parcel
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.print.PrintAttributes
import android.print.PrintManager
import android.text.InputType
import android.view.Gravity
import android.view.PixelCopy
import android.widget.PopupWindow
import android.widget.HorizontalScrollView
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
import com.google.android.material.snackbar.Snackbar
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
        private const val PREF_NAVIGATION_ACCELERATOR = "flutter.looply_navigation_accelerator_enabled"
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
    private var progressAnimator: ValueAnimator? = null
    private var progressTarget: Int = 0
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

    private val navigationAcceleratorEnabled: Boolean
        get() = !incognito && prefs.getBoolean(PREF_NAVIGATION_ACCELERATOR, true)

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
    private fun setProgressSmooth(target: Int, immediate: Boolean = false) {
        if (!::progress.isInitialized) return
        progressTarget = target.coerceIn(0, 100)

        if (immediate) {
            progressAnimator?.cancel()
            progressAnimator = null
            progress.progress = progressTarget
            return
        }

        // As atualizações do WebView chegam em rajadas. Não reinicia a animação
        // por cada percentagem: a animação ativa segue o alvo mais recente e,
        // se necessário, inicia uma segunda fase contínua até o alcançar.
        if (progressAnimator?.isRunning == true) return
        val startValue = progress.progress
        if (startValue == progressTarget) return
        val initialDistance = kotlin.math.abs(progressTarget - startValue)
        val animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = (220L + initialDistance * 2L).coerceIn(240L, 420L)
            interpolator = DecelerateInterpolator(1.15f)
        }
        animator.addUpdateListener { update ->
            if (::progress.isInitialized && !isFinishing) {
                val targetNow = progressTarget
                val fraction = update.animatedFraction
                progress.progress = (startValue + (targetNow - startValue) * fraction)
                    .toInt().coerceIn(0, 100)
            }
        }
        animator.addListener(object : android.animation.AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: android.animation.Animator) {
                if (progressAnimator === animator) progressAnimator = null
                if (!isFinishing && progress.progress != progressTarget) {
                    setProgressSmooth(progressTarget)
                }
            }
        })
        progressAnimator = animator
        animator.start()
    }

    override fun onResume() {
        super.onResume()
        if (::webView.isInitialized) {
            applyWebsiteDarkMode(webView.settings)
            webView.settings.cacheMode = when {
                incognito -> WebSettings.LOAD_NO_CACHE
                navigationAcceleratorEnabled -> WebSettings.LOAD_CACHE_ELSE_NETWORK
                else -> WebSettings.LOAD_DEFAULT
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                webView.settings.offscreenPreRaster = navigationAcceleratorEnabled
            }
            updateToolbarColors()
        }
    }

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

        settings.cacheMode = when {
            incognito -> WebSettings.LOAD_NO_CACHE
            navigationAcceleratorEnabled -> WebSettings.LOAD_CACHE_ELSE_NETWORK
            else -> WebSettings.LOAD_DEFAULT
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Pré-renderização ajuda a reduzir o atraso visual ao voltar a uma
            // página; desligada em incógnito para reduzir retenção de memória.
            settings.offscreenPreRaster = navigationAcceleratorEnabled
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
                setProgressSmooth(0, immediate = true)
                progress.visibility = View.VISIBLE
                refreshTitle()
                updateToolbarColors()
            }

            override fun onPageFinished(view: WebView, url: String) {
                currentUrl = url
                currentTitle = view.title?.takeIf { it.isNotBlank() } ?: hostOf(url)

                setProgressSmooth(100)
                progress.postDelayed({
                    if (!isFinishing && progress.progress == 100) {
                        progress.visibility = View.GONE
                    }
                }, 460)

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
                    showBrowserSnackbar(
                        error.description?.toString()
                            ?: menuText("loadingError", "Could not load this page.")
                    )
                }
            }
        }

        webView.webChromeClient = object : WebChromeClient() {

            override fun onProgressChanged(view: WebView, newProgress: Int) {
                setProgressSmooth(newProgress)
                progress.visibility = View.VISIBLE
                if (newProgress >= 100) {
                    progress.postDelayed({
                        if (!isFinishing && progress.progress >= 100) {
                            progress.visibility = View.GONE
                        }
                    }, 460L)
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
                    showBrowserSnackbar("Transferências desativadas no modo privado.")
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
                    24f,
                ),
                android.widget.FrameLayout.LayoutParams(dp(30), dp(30), Gravity.CENTER),
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
                        dp(27),
                    )
                )
            }
            addView(icon, android.widget.FrameLayout.LayoutParams(dp(27), dp(27), Gravity.CENTER))
            setOnClickListener { onClick() }
        }
    }

    private fun tintTabCountButton(color: Int) {
        if (!::tabsButton.isInitialized) return
        (tabsButton.getChildAt(0) as? ImageView)?.setImageDrawable(
            MaterialSymbolsRounded.tabsCounterDrawable(this, tabCount, color, dp(27))
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
            showBrowserSnackbar(menuText("validAddress", "Enter a valid HTTP or HTTPS address."))
            return
        }

        webView.loadUrl(uri.toString())
    }

    private fun showBrowserSnackbar(message: String, long: Boolean = false) {
        if (!::root.isInitialized || isFinishing || message.isBlank()) return
        val backgroundColor = when {
            !dark -> Color.rgb(241, 243, 244)
            pureBlack -> Color.rgb(41, 41, 41)
            else -> Color.rgb(58, 60, 64)
        }
        val foregroundColor = if (dark) Color.WHITE else Color.rgb(32, 33, 36)
        val snackbar = Snackbar.make(
            root,
            message,
            if (long) Snackbar.LENGTH_LONG else Snackbar.LENGTH_SHORT,
        )
        snackbar.setTextColor(foregroundColor)
        snackbar.setBackgroundTint(backgroundColor)
        snackbar.setAnimationMode(Snackbar.ANIMATION_MODE_SLIDE)
        snackbar.view.apply {
            background = rounded(backgroundColor, 11)
            elevation = dp(6).toFloat()
            clipToOutline = true
        }
        snackbar.show()
    }

    private fun menuText(key: String, fallback: String): String {
        return menuLabels.optString(key).takeIf { it.isNotBlank() } ?: fallback
    }

    private fun showBrowserPopupMenu(anchor: View) {
        if (previewOnly || isFinishing || !anchor.isAttachedToWindow) return
        popupWindowRef?.dismiss()

        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        val popupWidth = minOf(dp(360), screenWidth - dp(24)).coerceAtLeast(dp(260))
        val maxPopupHeight = (screenHeight * .56f).toInt().coerceAtLeast(dp(280))
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
        val dividerColor = when {
            !dark -> Color.rgb(232, 234, 237)
            pureBlack -> Color.rgb(41, 41, 41)
            else -> Color.rgb(52, 54, 58)
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = rounded(surface, 26)
            clipToOutline = true
            layoutTransition = android.animation.LayoutTransition().apply {
                setDuration(170L)
                enableTransitionType(android.animation.LayoutTransition.CHANGING)
            }
        }

        // Atalhos superiores num trilho horizontal. Em ecrãs estreitos o
        // utilizador desliza esta faixa, sem aumentar a altura do popup.
        val quickScroller = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            clipToPadding = false
            setPadding(dp(2), dp(3), dp(2), dp(7))
        }
        val quickRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        fun quickAction(
            glyph: String,
            description: String,
            enabled: Boolean = true,
            action: () -> Unit,
        ) {
            val icon = ImageView(this@OrbitBrowserActivity).apply {
                setImageDrawable(
                    MaterialSymbolsRounded.bitmapDrawable(
                        this@OrbitBrowserActivity,
                        glyph,
                        primaryText,
                        dp(24),
                    )
                )
                scaleType = ImageView.ScaleType.FIT_CENTER
                contentDescription = description
            }
            val frame = android.widget.FrameLayout(this).apply {
                isClickable = enabled
                isFocusable = enabled
                alpha = if (enabled) 1f else .38f
                background = rounded(quickSurface, 999)
                addView(icon, android.widget.FrameLayout.LayoutParams(dp(28), dp(28), Gravity.CENTER))
                setOnClickListener {
                    if (enabled) {
                        popupWindowRef?.dismiss()
                        action()
                    }
                }
            }
            quickRow.addView(
                frame,
                LinearLayout.LayoutParams(dp(54), dp(48)).apply {
                    marginStart = dp(3)
                    marginEnd = dp(3)
                },
            )
        }

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

        quickScroller.addView(
            quickRow,
            HorizontalScrollView.LayoutParams(-2, -1),
        )
        content.addView(quickScroller, LinearLayout.LayoutParams(-1, dp(58)))

        content.addView(View(this).apply { setBackgroundColor(dividerColor) },
            LinearLayout.LayoutParams(-1, dp(1)).apply {
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
        menuScroll.addView(menuItems, android.widget.FrameLayout.LayoutParams(-1, -2))

        fun menuRow(label: String, glyph: String, action: () -> Unit) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(13), 0, dp(13), 0)
                minimumHeight = dp(50)
                alpha = 0f
                translationY = dp(7).toFloat()
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
                                dp(24),
                            )
                        )
                        scaleType = ImageView.ScaleType.FIT_CENTER
                    },
                    LinearLayout.LayoutParams(dp(26), dp(26)),
                )
                addView(View(this@OrbitBrowserActivity), LinearLayout.LayoutParams(dp(13), 1))
                addView(
                    TextView(this@OrbitBrowserActivity).apply {
                        text = label
                        setTextColor(primaryText)
                        textSize = 14f
                        maxLines = 2
                        ellipsize = android.text.TextUtils.TruncateAt.END
                        gravity = Gravity.CENTER_VERTICAL
                        includeFontPadding = false
                    },
                    LinearLayout.LayoutParams(0, -2, 1f),
                )
                setOnClickListener {
                    popupWindowRef?.dismiss()
                    action()
                }
            }
            val delay = menuItems.childCount * 14L
            menuItems.addView(row, LinearLayout.LayoutParams(-1, dp(50)))
            row.postDelayed({
                if (row.isAttachedToWindow) {
                    row.animate()
                        .alpha(1f)
                        .translationY(0f)
                        .setDuration(175L)
                        .setInterpolator(DecelerateInterpolator(1.4f))
                        .start()
                }
            }, delay)
        }

        fun menuDivider() {
            menuItems.addView(View(this).apply { setBackgroundColor(dividerColor) },
                LinearLayout.LayoutParams(-1, dp(1)).apply {
                    marginStart = dp(10)
                    marginEnd = dp(10)
                    topMargin = dp(4)
                    bottomMargin = dp(4)
                })
        }

        menuRow(menuText("newTab", "New tab"), "add_box") { finishToFlutter("newTab") }
        menuRow(menuText("tabs", "Manage tabs"), "tab") { finishToFlutter("tabs") }
        if (!incognito) {
            menuRow(menuText("bookmarks", "Bookmarks"), "bookmarks") { finishToFlutter("bookmarks") }
            menuRow(menuText("history", "History"), "history") { finishToFlutter("history") }
            menuDivider()
            menuRow(menuText("downloads", "Downloads"), "download") { finishToFlutter("downloads") }
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

        val menuHeight = minOf(dp(430), maxPopupHeight - dp(66)).coerceAtLeast(dp(130))
        content.addView(menuScroll, LinearLayout.LayoutParams(-1, menuHeight))
        val popupHeight = (menuHeight + dp(76)).coerceAtMost(maxPopupHeight)

        val popup = PopupWindow(content, popupWidth, popupHeight, true).apply {
            setBackgroundDrawable(rounded(surface, 26))
            setElevation(dp(20).toFloat())
            isOutsideTouchable = true
            isClippingEnabled = true
            inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                enterTransition = Fade().apply { duration = 165 }
                exitTransition = Fade().apply { duration = 115 }
            }
        }
        popupWindowRef = popup
        popup.setOnDismissListener {
            if (popupWindowRef === popup) popupWindowRef = null
        }

        val anchorLocation = IntArray(2)
        anchor.getLocationOnScreen(anchorLocation)
        val availableAbove = anchorLocation[1] - statusBarInsetPx()
        val showAbove = availableAbove >= popupHeight + dp(16)
        val popupX = (anchorLocation[0] + anchor.width - popupWidth)
            .coerceIn(dp(12), (screenWidth - popupWidth - dp(12)).coerceAtLeast(dp(12)))
        val popupY = if (showAbove) {
            (anchorLocation[1] - popupHeight - dp(8))
                .coerceAtLeast(statusBarInsetPx() + dp(8))
        } else {
            (anchorLocation[1] + anchor.height + dp(8))
                .coerceAtMost((screenHeight - popupHeight - navigationBarInsetPx() - dp(8)).coerceAtLeast(dp(8)))
        }
        popup.showAtLocation(root, Gravity.TOP or Gravity.LEFT, popupX, popupY)
        quickRow.post {
            for (index in 0 until quickRow.childCount) {
                val child = quickRow.getChildAt(index)
                child.alpha = 0f
                child.scaleX = .92f
                child.scaleY = .92f
                child.animate()
                    .alpha(1f)
                    .scaleX(1f)
                    .scaleY(1f)
                    .setStartDelay(index * 18L)
                    .setDuration(170L)
                    .setInterpolator(DecelerateInterpolator(1.35f))
                    .start()
            }
        }
    }

    private var popupWindowRef: PopupWindow? = null

    private fun addSheetItem(
        parent: LinearLayout,
        icon: String,
        label: String,
        action: () -> Unit
    ) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), 0, dp(12), 0)
            background = selectableBackground()
            isClickable = true
            isFocusable = true
            minimumHeight = dp(56)
            setOnClickListener { action() }
        }

        val iconCell = android.widget.FrameLayout(this).apply {
            addView(
                MaterialSymbolsRounded.textView(
                    this@OrbitBrowserActivity,
                    icon,
                    secondaryText,
                    24f,
                ),
                android.widget.FrameLayout.LayoutParams(dp(30), dp(30), Gravity.CENTER)
            )
        }
        row.addView(iconCell, LinearLayout.LayoutParams(dp(44), dp(56)))

        row.addView(
            TextView(this).apply {
                text = label
                textSize = 14f
                setTextColor(primaryText)
                gravity = Gravity.CENTER_VERTICAL
                includeFontPadding = false
                maxLines = 2
            },
            LinearLayout.LayoutParams(0, dp(56), 1f).apply {
                marginStart = dp(4)
            }
        )

        parent.addView(row, LinearLayout.LayoutParams(-1, dp(56)))
    }

    private fun showElementSheet(target: String, hitType: Int) {
        val isImage = hitType == WebView.HitTestResult.IMAGE_TYPE ||
            hitType == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
        val isLink = hitType == WebView.HitTestResult.ANCHOR_TYPE ||
            hitType == WebView.HitTestResult.SRC_ANCHOR_TYPE
        val dialog = BottomSheetDialog(this)

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(20))
            background = rounded(pageBg, 22)
        }

        content.addView(
            TextView(this).apply {
                text = when {
                    isImage -> menuText("image", "Image")
                    isLink -> menuText("link", "Link")
                    else -> menuText("media", "Media")
                }
                textSize = 16f
                setTextColor(primaryText)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                maxLines = 1
            },
            LinearLayout.LayoutParams(-1, dp(36))
        )
        content.addView(
            TextView(this).apply {
                text = target
                textSize = 12f
                setTextColor(secondaryText)
                maxLines = 2
                ellipsize = android.text.TextUtils.TruncateAt.MIDDLE
            },
            LinearLayout.LayoutParams(-1, dp(44))
        )

        addSheetItem(content, "open_in_new", menuText("openNewTab", "Open in new tab")) {
            dialog.dismiss()
            finishToFlutter("newTab", target)
        }
        addSheetItem(content, "content_copy", menuText("copyLink", "Copy link")) {
            dialog.dismiss()
            copyText(target)
        }
        addSheetItem(content, "share", menuText("share", "Share")) {
            dialog.dismiss()
            shareText(target)
        }
        if (isLink && !incognito) {
            addSheetItem(content, "star", menuText("addBookmark", "Add bookmark")) {
                dialog.dismiss()
                finishToFlutter("bookmarkUrl", target)
            }
        }
        if (isImage && !incognito) {
            addSheetItem(content, "download", menuText("downloadImage", "Download image")) {
                dialog.dismiss()
                startDownload(target, null, null, null)
            }
        }

        dialog.setContentView(content)
        dialog.show()
    }

    private fun openFindBar() {
        findBar.visibility = View.VISIBLE
        findField.requestFocus()
        findField.post {
            (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager)
                .showSoftInput(findField, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    private fun closeFindBar() {
        webView.clearMatches()
        findField.setText("")
        findBar.visibility = View.GONE
        (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager)
            .hideSoftInputFromWindow(findField.windowToken, 0)
    }

    private fun toggleDesktopMode() {
        desktopMode = !desktopMode
        webView.settings.userAgentString = if (desktopMode) {
            DESKTOP_UA
        } else {
            originalUserAgent ?: WebSettings.getDefaultUserAgent(this)
        }
        webView.settings.useWideViewPort = true
        webView.settings.loadWithOverviewMode = desktopMode
        webView.reload()
        showBrowserSnackbar(
            if (desktopMode) menuText("desktopEnabled", "Desktop site enabled")
            else menuText("desktopDisabled", "Desktop site disabled")
        )
    }

    private fun translatePage() {
        val targetLanguage = menuLabels.optString("targetLanguage", "en")
            .takeIf { it.matches(Regex("^[a-zA-Z-]{2,8}$")) } ?: "en"
        val translateUrl =
            "https://translate.google.com/translate?sl=auto&tl=$targetLanguage&u=" +
                Uri.encode(currentUrl)
        webView.loadUrl(translateUrl)
    }

    private fun showScaleCard(pageScale: Boolean) {
        val title = if (pageScale) {
            menuText("pageZoom", "Page zoom")
        } else {
            menuText("fontSize", "Font size")
        }
        val initialValue = if (pageScale) pageZoomPercent else textSizePercent
        val dialog = BottomSheetDialog(this)
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(18), dp(22), dp(18))
            background = rounded(pageBg, 32)
        }
        val handle = View(this).apply {
            background = rounded(
                if (dark) 0xFF5B5F64.toInt() else 0xFFD0D4D8.toInt(),
                99
            )
        }
        card.addView(
            handle,
            LinearLayout.LayoutParams(dp(36), dp(4)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(18)
            }
        )

        val heading = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        heading.addView(
            MaterialSymbolsRounded.textView(
                this,
                if (pageScale) "zoom_in" else "text_fields",
                primaryText,
                24f,
                title
            ),
            LinearLayout.LayoutParams(dp(30), dp(30)).apply {
                marginEnd = dp(12)
            }
        )
        heading.addView(
            TextView(this).apply {
                text = title
                textSize = 18f
                setTextColor(primaryText)
                typeface = android.graphics.Typeface.create(
                    "sans-serif-medium",
                    android.graphics.Typeface.NORMAL
                )
                includeFontPadding = false
            },
            LinearLayout.LayoutParams(0, dp(38), 1f)
        )
        val valueLabel = TextView(this).apply {
            text = "$initialValue%"
            textSize = 15f
            setTextColor(primaryText)
            gravity = Gravity.CENTER
            includeFontPadding = false
            background = rounded(toolbarPillColor(), 99)
            setPadding(dp(14), dp(8), dp(14), dp(8))
        }
        heading.addView(valueLabel, LinearLayout.LayoutParams(-2, dp(34)))
        card.addView(heading)

        val sliderContext = android.view.ContextThemeWrapper(
            this,
            R.style.ThemeOverlay_BrowseIt_ExpressiveSlider
        )
        val slider = Slider(
            sliderContext,
            null,
            com.google.android.material.R.attr.sliderStyle
        ).apply {
            valueFrom = 50f
            valueTo = 200f
            stepSize = 5f
            value = initialValue.coerceIn(50, 200).toFloat()
            contentDescription = title
            val accentColorList = android.content.res.ColorStateList.valueOf(accent)
            setThumbTintList(accentColorList)
            setHaloTintList(
                android.content.res.ColorStateList.valueOf(
                    (accent and 0x00FFFFFF) or 0x26000000
                )
            )
            setTrackActiveTintList(accentColorList)
            setTrackInactiveTintList(
                android.content.res.ColorStateList.valueOf(
                    if (dark) 0xFF53565B.toInt() else 0xFFDADCE0.toInt()
                )
            )
        }
        card.addView(
            slider,
            LinearLayout.LayoutParams(-1, dp(58)).apply {
                topMargin = dp(12)
            }
        )

        val rangeLabels = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        rangeLabels.addView(
            TextView(this).apply {
                text = "50%"
                textSize = 12f
                setTextColor(secondaryText)
                includeFontPadding = false
            },
            LinearLayout.LayoutParams(0, dp(22), 1f)
        )
        rangeLabels.addView(
            TextView(this).apply {
                text = "200%"
                textSize = 12f
                setTextColor(secondaryText)
                gravity = Gravity.END
                includeFontPadding = false
            },
            LinearLayout.LayoutParams(0, dp(22), 1f)
        )
        card.addView(rangeLabels)
        slider.addOnChangeListener { _, value, fromUser ->
            val selected = ((value.roundToInt() / 5) * 5).coerceIn(50, 200)
            valueLabel.text = "$selected%"
            if (fromUser) {
                if (pageScale) {
                    pageZoomPercent = selected
                    applyPageZoomToCurrentPage()
                } else {
                    textSizePercent = selected
                    webView.settings.textZoom = selected
                }
            }
        }

        dialog.setContentView(card)
        dialog.setOnShowListener {
            val sheet = dialog.findViewById<android.widget.FrameLayout>(
                com.google.android.material.R.id.design_bottom_sheet
            ) ?: return@setOnShowListener
            sheet.setBackgroundColor(Color.TRANSPARENT)
            val params = sheet.layoutParams as? ViewGroup.MarginLayoutParams
            params?.let {
                it.width = ViewGroup.LayoutParams.MATCH_PARENT
                it.height = ViewGroup.LayoutParams.WRAP_CONTENT
                it.marginStart = dp(12)
                it.marginEnd = dp(12)
                it.bottomMargin = dp(12) + navigationBarInsetPx()
                sheet.layoutParams = it
            }
            val behavior = BottomSheetBehavior.from(sheet)
            behavior.skipCollapsed = true
            behavior.state = BottomSheetBehavior.STATE_EXPANDED
        }
        dialog.show()
    }

    private fun applyPageZoomToCurrentPage() {
        if (!::webView.isInitialized || webView.url.isNullOrBlank()) return
        val target = pageZoomPercent.coerceIn(50, 200)
        val previouslyApplied = appliedPageZoomPercent.coerceIn(50, 200)
        if (target == previouslyApplied) return
        val factor = target.toFloat() / previouslyApplied.toFloat()
        appliedPageZoomPercent = target
        webView.zoomBy(factor.coerceIn(0.01f, 100f))
    }

    private fun navigationBarInsetPx(): Int {
        val insets = ViewCompat.getRootWindowInsets(root)
        return insets?.getInsets(WindowInsetsCompat.Type.navigationBars())?.bottom ?: 0
    }

    private fun printPage() {
        try {
            val manager = getSystemService(Context.PRINT_SERVICE) as PrintManager
            val adapter = webView.createPrintDocumentAdapter(
                "BrowseIt - ${hostOf(currentUrl)}"
            )
            manager.print("BrowseIt", adapter, PrintAttributes.Builder().build())
        } catch (_: Exception) {
            showBrowserSnackbar(menuText("printError", "Could not print this page."))
        }
    }

    private fun showSiteInfo() {
        val host = hostOf(currentUrl)
        MaterialAlertDialogBuilder(this)
            .setTitle(menuText("siteInfo", "Site information"))
            .setMessage("${currentTitle.ifBlank { host }}\n\n$currentUrl")
            .setPositiveButton(menuText("close", "Close"), null)
            .show()
    }

    private fun copyAddress() {
        copyText(currentUrl)
    }

    private fun copyText(value: String) {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager
        clipboard.setPrimaryClip(
            android.content.ClipData.newPlainText("BrowseIt", value)
        )
        showBrowserSnackbar(menuText("copied", "Copied"))
    }

    private fun shareAddress() {
        shareText(currentUrl)
    }

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
                showBrowserSnackbar("Este tipo de transferência não pode ser enviado para a lista da aplicação.", long = true)
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
            showBrowserSnackbar(menuText("downloadReceived", "Download added to Downloads"))
        } catch (_: Exception) {
            showBrowserSnackbar(menuText("downloadFailed", "Download failed"))
        }
    }

    private fun openExternalUri(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase(Locale.ROOT) ?: return true

        if (scheme == "http" || scheme == "https") return false

        return try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
            true
        } catch (_: Exception) {
            showBrowserSnackbar("Não existe uma aplicação compatível para abrir esta ligação.")
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
            if (::toolbar.isInitialized) toolbar.setBackgroundColor(toolbarBg)
            if (::appBarContainer.isInitialized) appBarContainer.setBackgroundColor(toolbarBg)
            if (::titlePill.isInitialized) titlePill.background = rounded(toolbarPillColor(), 24)
            if (::titleView.isInitialized) titleView.setTextColor(toolbarText())
            tintTabCountButton(toolbarText())
            tintMenuOptionsButton(toolbarText())
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
        val base = toolbarBg
        val neutral = if (isLight(base)) Color.WHITE else Color.BLACK
        val fraction = if (isLight(base)) .10f else .16f
        return blendColor(base, neutral, fraction)
    }

    private fun blendColor(from: Int, to: Int, amount: Float): Int {
        val t = amount.coerceIn(0f, 1f)
        val inverse = 1f - t
        return Color.rgb(
            (Color.red(from) * inverse + Color.red(to) * t).roundToInt().coerceIn(0, 255),
            (Color.green(from) * inverse + Color.green(to) * t).roundToInt().coerceIn(0, 255),
            (Color.blue(from) * inverse + Color.blue(to) * t).roundToInt().coerceIn(0, 255),
        )
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

        if (incognito || previewOnly || !::webView.isInitialized) {
            completeFinishToFlutter(action, newUrl, null, null)
            return
        }

        captureCurrentScreen { pageThumbnail, fullScreenshot ->
            if (isFinishing) return@captureCurrentScreen
            completeFinishToFlutter(
                action,
                newUrl,
                pageThumbnail,
                if (action == "tabs") fullScreenshot else null,
            )
        }
    }

    private fun completeFinishToFlutter(
        action: String,
        newUrl: String?,
        pageThumbnail: ByteArray?,
        fullScreenshot: ByteArray?,
    ) {
        val output = Intent().apply {
            putExtra(RESULT_URL, currentUrl)
            putExtra(RESULT_TITLE, currentTitle)
            putExtra(RESULT_TAB_ID, tabId)
            putExtra(RESULT_ACTION, action)
            if (newUrl != null) putExtra(RESULT_NEW_URL, newUrl)
            pageThumbnail?.let { putExtra(RESULT_THUMBNAIL, it) }
            fullScreenshot?.let { putExtra(RESULT_TRANSITION_SCREENSHOT, it) }
        }

        setResult(Activity.RESULT_OK, output)
        finish()
        if (action == "tabs") {
            overridePendingTransition(0, 0)
        } else {
            overridePendingTransition(0, R.anim.browser_slide_down)
        }
    }

    /** Captura a janela já composta (incluindo WebView) e faz fallback para
     * View.draw caso PixelCopy não esteja disponível ou o fabricante falhe. */
    private fun captureCurrentScreen(onCaptured: (ByteArray?, ByteArray?) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            onCaptured(takeThumbnail(), takeBrowserTransitionScreenshot())
            return
        }

        val decor = window.decorView
        val width = decor.width.coerceAtLeast(1)
        val height = decor.height.coerceAtLeast(1)
        val bitmap = try {
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        } catch (_: Exception) {
            onCaptured(takeThumbnail(), takeBrowserTransitionScreenshot())
            return
        }
        val handler = Handler(Looper.getMainLooper())
        var completed = false

        fun fallback() {
            if (completed) return
            completed = true
            runCatching { bitmap.recycle() }
            onCaptured(takeThumbnail(), takeBrowserTransitionScreenshot())
        }

        val timeout = Runnable { fallback() }
        handler.postDelayed(timeout, 450L)
        try {
            PixelCopy.request(window, bitmap, { result ->
                if (completed) {
                    runCatching { bitmap.recycle() }
                    return@request
                }
                completed = true
                handler.removeCallbacks(timeout)

                if (result != PixelCopy.SUCCESS) {
                    runCatching { bitmap.recycle() }
                    onCaptured(takeThumbnail(), takeBrowserTransitionScreenshot())
                    return@request
                }

                val full = encodeScreenshot(bitmap, 60)
                val location = IntArray(2)
                webView.getLocationInWindow(location)
                val left = location[0].coerceIn(0, bitmap.width - 1)
                val top = location[1].coerceIn(0, bitmap.height - 1)
                val right = (left + webView.width).coerceIn(left + 1, bitmap.width)
                val bottom = (top + webView.height).coerceIn(top + 1, bitmap.height)
                val page = try {
                    Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
                } catch (_: Exception) {
                    null
                }
                val pageBytes = page?.let { encodeScreenshot(it, 58) }
                page?.recycle()
                bitmap.recycle()
                onCaptured(pageBytes ?: takeThumbnail(), full ?: takeBrowserTransitionScreenshot())
            }, handler)
        } catch (_: Exception) {
            handler.removeCallbacks(timeout)
            fallback()
        }
    }

    private fun encodeScreenshot(bitmap: Bitmap, quality: Int): ByteArray? {
        return try {
            ByteArrayOutputStream().use { stream ->
                if (bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)) {
                    stream.toByteArray()
                } else null
            }
        } catch (_: Exception) {
            null
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
        progressAnimator?.cancel()
        progressAnimator = null
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

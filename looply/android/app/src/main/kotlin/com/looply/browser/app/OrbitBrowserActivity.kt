package com.looply.browser.app

import android.app.Activity
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
import android.util.Base64
import android.print.PrintAttributes
import android.print.PrintManager
import android.text.InputType
import android.view.Gravity
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
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.URLConnection
import java.util.Locale

class OrbitBrowserActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_URL = "com.looply.browser.app.orbit.URL"
        const val EXTRA_TAB_ID = "com.looply.browser.app.orbit.TAB_ID"
        const val EXTRA_INCOGNITO = "com.looply.browser.app.orbit.INCOGNITO"
        const val EXTRA_TAB_COUNT = "com.looply.browser.app.orbit.TAB_COUNT"
        const val EXTRA_PREVIEW_ONLY = "com.looply.browser.app.orbit.PREVIEW_ONLY"

        const val RESULT_URL = "com.looply.browser.app.orbit.RESULT_URL"
        const val RESULT_TITLE = "com.looply.browser.app.orbit.RESULT_TITLE"
        const val RESULT_TAB_ID = "com.looply.browser.app.orbit.RESULT_TAB_ID"
        const val RESULT_ACTION = "com.looply.browser.app.orbit.RESULT_ACTION"
        const val RESULT_THUMBNAIL = "com.looply.browser.app.orbit.RESULT_THUMBNAIL"
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

        private const val TAB_STATE_PREFS = "looply_orbit_native_tab_state_v1"
        private const val MAX_TAB_STATE_CHARS = 1_400_000

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
    private lateinit var titlePill: LinearLayout
    private lateinit var faviconView: ImageView
    private lateinit var titleView: TextView
    private lateinit var progress: ProgressBar
    private lateinit var webView: WebView
    private lateinit var findBar: LinearLayout
    private lateinit var findField: EditText
    private lateinit var tabsButton: TextView

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
    private var pageZoom = 100
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
        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.setSoftInputMode(
            android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        )

        currentUrl = savedInstanceState?.getString(STATE_URL)
            ?: intent.getStringExtra(EXTRA_URL)?.takeIf { it.isNotBlank() }
            ?: "https://www.google.com"

        currentTitle = savedInstanceState?.getString(STATE_TITLE).orEmpty()
        tabId = intent.getStringExtra(EXTRA_TAB_ID).orEmpty()
        tabCount = intent.getIntExtra(EXTRA_TAB_COUNT, 1).coerceAtLeast(1)
        incognito = intent.getBooleanExtra(EXTRA_INCOGNITO, false)
        previewOnly = intent.getBooleanExtra(EXTRA_PREVIEW_ONLY, false)

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

        val home = actionButton("⌂", "Início") {
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
            setOnClickListener { showAddressDialog() }
        }

        faviconView = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageResource(android.R.drawable.ic_menu_search)
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

        tabsButton = actionButton(tabCount.toString(), "Separadores") {
            finishToFlutter("tabs")
        }

        toolbar.addView(
            tabsButton,
            LinearLayout.LayoutParams(dp(42), dp(46))
        )

        toolbar.addView(
            actionButton("⋮", "Mais opções") { showBrowserSheet() },
            LinearLayout.LayoutParams(dp(42), dp(46))
        )

        root.addView(toolbar, LinearLayout.LayoutParams(-1, dp(56)))

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

        root.addView(progress, LinearLayout.LayoutParams(-1, dp(2)))

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
            actionButton("↑", "Resultado anterior") {
                webView.findNext(false)
            },
            LinearLayout.LayoutParams(dp(38), dp(42))
        )

        findBar.addView(
            actionButton("↓", "Resultado seguinte") {
                webView.findNext(true)
            },
            LinearLayout.LayoutParams(dp(38), dp(42))
        )

        findBar.addView(
            actionButton("×", "Fechar pesquisa") {
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

                if (scrollY > dp(90) && delta > dp(7)) {
                    hideToolbar(true)
                } else if (delta < -dp(5)) {
                    hideToolbar(false)
                }
            }
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
        settings.textZoom = pageZoom

        settings.cacheMode = if (incognito) {
            WebSettings.LOAD_NO_CACHE
        } else {
            WebSettings.LOAD_DEFAULT
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            run {
                settings.forceDark =
                    if (!incognito && prefs.getBoolean(PREF_FORCE_DARK, false)) {
                        WebSettings.FORCE_DARK_ON
                    } else {
                        WebSettings.FORCE_DARK_OFF
                    }
            }
        }

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
                            ?: "Não foi possível abrir a página.",
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

                toolbar.visibility = View.GONE
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
    ): TextView {
        return TextView(this).apply {
            text = symbol
            contentDescription = description
            gravity = Gravity.CENTER
            textSize = if (symbol.length > 1) 17f else 23f
            setTextColor(toolbarText())
            isClickable = true
            isFocusable = true
            background = selectableBackground()
            setOnClickListener { onClick() }
        }
    }

    private fun showAddressDialog() {
        val input = EditText(this).apply {
            setSingleLine(true)
            textSize = 15f
            setTextColor(primaryText)
            setHintTextColor(secondaryText)
            hint = "Pesquisar ou introduzir endereço"
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
            .setTitle("Pesquisar ou abrir endereço")
            .setView(container)
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Abrir", null)
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
            Toast.makeText(this, "Endereço inválido.", Toast.LENGTH_SHORT).show()
            return
        }

        webView.loadUrl(uri.toString())
    }

    private fun showBrowserSheet() {
        val dialog = BottomSheetDialog(this)
        val scroll = android.widget.ScrollView(this)

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(10), dp(18), dp(18))
            background = rounded(pageBg, 22)
        }

        val handle = View(this).apply {
            background = rounded(
                if (dark) 0xFF5B5F64.toInt() else 0xFFD0D4D8.toInt(),
                99
            )
        }

        content.addView(
            handle,
            LinearLayout.LayoutParams(dp(36), dp(4)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(16)
            }
        )

        content.addView(
            TextView(this).apply {
                text = "Browser"
                textSize = 17f
                setTextColor(primaryText)
                typeface = android.graphics.Typeface.create(
                    "sans-serif-medium",
                    android.graphics.Typeface.NORMAL
                )
            },
            LinearLayout.LayoutParams(-1, dp(38))
        )

        val quick = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        addQuickAction(quick, "‹", "Voltar", webView.canGoBack()) {
            webView.goBack()
        }

        addQuickAction(quick, "›", "Avançar", webView.canGoForward()) {
            webView.goForward()
        }

        addQuickAction(quick, "+", "Novo separador", true) {
            finishToFlutter("newTab")
        }

        addQuickAction(quick, "▣", "Separadores", true) {
            finishToFlutter("tabs")
        }

        content.addView(quick, LinearLayout.LayoutParams(-1, dp(78)))
        content.addView(sheetDivider())

        addSheetItem(content, "☆", "Adicionar aos favoritos") {
            dialog.dismiss()
            finishToFlutter("bookmark")
        }

        if (!incognito) {
            addSheetItem(content, "★", "Ver favoritos") {
                dialog.dismiss()
                finishToFlutter("bookmarks")
            }

            addSheetItem(content, "◷", "Histórico") {
                dialog.dismiss()
                finishToFlutter("history")
            }

            addSheetItem(content, "⇩", "Transferências") {
                dialog.dismiss()
                showDownloadsSheet()
            }
        }

        addSheetItem(content, "↻", "Recarregar página") {
            dialog.dismiss()
            webView.reload()
        }

        addSheetItem(content, "⌕", "Localizar na página") {
            dialog.dismiss()
            openFindBar()
        }

        addSheetItem(
            content,
            "▤",
            if (desktopMode) {
                "Desativar site para computador"
            } else {
                "Site para computador"
            }
        ) {
            dialog.dismiss()
            toggleDesktopMode()
        }

        addSheetItem(content, "文", "Traduzir página") {
            dialog.dismiss()
            translatePage()
        }

        addSheetItem(content, "−", "Reduzir texto") {
            dialog.dismiss()
            setZoom(-10)
        }

        addSheetItem(content, "+", "Aumentar texto") {
            dialog.dismiss()
            setZoom(10)
        }

        addSheetItem(content, "▣", "Imprimir") {
            dialog.dismiss()
            printPage()
        }

        addSheetItem(content, "⧉", "Copiar endereço") {
            dialog.dismiss()
            copyAddress()
        }

        addSheetItem(content, "↗", "Partilhar página") {
            dialog.dismiss()
            shareAddress()
        }

        addSheetItem(content, "ⓘ", "Informações do site") {
            dialog.dismiss()
            showSiteInfo()
        }

        addSheetItem(content, "⚙", "Definições") {
            dialog.dismiss()
            finishToFlutter("settings")
        }

        addSheetItem(content, "⌂", "Início") {
            dialog.dismiss()
            finishToFlutter("home")
        }

        scroll.addView(content)
        dialog.setContentView(scroll)
        dialog.show()
    }

    private fun addQuickAction(
        parent: LinearLayout,
        icon: String,
        label: String,
        enabled: Boolean,
        action: () -> Unit
    ) {
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            alpha = if (enabled) 1f else .38f
            isClickable = enabled
            isFocusable = enabled
            setOnClickListener {
                if (enabled) action()
            }
        }

        val iconView = TextView(this).apply {
            text = icon
            gravity = Gravity.CENTER
            textSize = 22f
            setTextColor(accent)
            background = rounded(toolbarPillColor(), 18)
        }

        column.addView(iconView, LinearLayout.LayoutParams(dp(48), dp(44)))

        column.addView(
            TextView(this).apply {
                text = label
                textSize = 10.5f
                setTextColor(secondaryText)
                gravity = Gravity.CENTER
                maxLines = 1
            },
            LinearLayout.LayoutParams(-1, dp(24))
        )

        parent.addView(column, LinearLayout.LayoutParams(0, -1, 1f))
    }

    private fun addSheetItem(
        parent: LinearLayout,
        icon: String,
        label: String,
        action: () -> Unit
    ) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), 0, dp(10), 0)
            background = selectableBackground()
            isClickable = true
            isFocusable = true
            setOnClickListener { action() }
        }

        row.addView(
            TextView(this).apply {
                text = icon
                textSize = 21f
                setTextColor(secondaryText)
                gravity = Gravity.CENTER
            },
            LinearLayout.LayoutParams(dp(42), dp(48))
        )

        row.addView(
            TextView(this).apply {
                text = label
                textSize = 14f
                setTextColor(primaryText)
            },
            LinearLayout.LayoutParams(0, dp(48), 1f)
        )

        parent.addView(row, LinearLayout.LayoutParams(-1, dp(48)))
    }

    private fun sheetDivider(): View {
        return View(this).apply {
            setBackgroundColor(
                if (dark) 0x33FFFFFF else 0x1F000000
            )

            layoutParams = LinearLayout.LayoutParams(-1, dp(1)).apply {
                topMargin = dp(6)
                bottomMargin = dp(6)
            }
        }
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
                    isImage -> "Imagem"
                    isLink -> "Ligação"
                    else -> "Multimédia"
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

        addSheetItem(content, "↗", "Abrir num novo separador") {
            dialog.dismiss()
            finishToFlutter("newTab", target)
        }

        addSheetItem(content, "⧉", "Copiar ligação") {
            dialog.dismiss()
            copyText(target)
        }

        addSheetItem(content, "↗", "Partilhar") {
            dialog.dismiss()
            shareText(target)
        }

        if (isLink && !incognito) {
            addSheetItem(content, "☆", "Adicionar aos favoritos") {
                dialog.dismiss()
                finishToFlutter("bookmarkUrl", target)
            }
        }

        if (isImage && !incognito) {
            addSheetItem(content, "⇩", "Transferir imagem") {
                dialog.dismiss()
                startDownload(target, null, null, null)
            }
        }

        dialog.setContentView(content)
        dialog.show()
    }

    private fun showDownloadsSheet() {
        val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val dialog = BottomSheetDialog(this)
        val scroll = android.widget.ScrollView(this)

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(12), dp(18), dp(18))
            background = rounded(pageBg, 22)
        }

        val handle = View(this).apply {
            background = rounded(
                if (dark) 0xFF5B5F64.toInt() else 0xFFD0D4D8.toInt(),
                99
            )
        }

        content.addView(
            handle,
            LinearLayout.LayoutParams(dp(36), dp(4)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(14)
            }
        )

        content.addView(
            TextView(this).apply {
                text = "Transferências"
                textSize = 18f
                setTextColor(primaryText)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            },
            LinearLayout.LayoutParams(-1, dp(42))
        )

        val query = DownloadManager.Query().setFilterByStatus(
            DownloadManager.STATUS_PENDING or
                DownloadManager.STATUS_RUNNING or
                DownloadManager.STATUS_PAUSED or
                DownloadManager.STATUS_SUCCESSFUL or
                DownloadManager.STATUS_FAILED
        )

        var count = 0

        manager.query(query)?.use { cursor ->
            val idColumn = cursor.getColumnIndex(DownloadManager.COLUMN_ID)
            val titleColumn = cursor.getColumnIndex(DownloadManager.COLUMN_TITLE)
            val statusColumn = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
            val downloadedColumn =
                cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            val totalColumn =
                cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            val reasonColumn =
                cursor.getColumnIndex(DownloadManager.COLUMN_REASON)

            while (cursor.moveToNext()) {
                if (idColumn < 0 || titleColumn < 0 || statusColumn < 0) {
                    continue
                }

                count++

                val id = cursor.getLong(idColumn)
                val filename =
                    cursor.getString(titleColumn)?.ifBlank { "Ficheiro" } ?: "Ficheiro"

                val status = cursor.getInt(statusColumn)
                val downloaded =
                    if (downloadedColumn >= 0) cursor.getLong(downloadedColumn) else 0L
                val total =
                    if (totalColumn >= 0) cursor.getLong(totalColumn) else -1L
                val reason =
                    if (reasonColumn >= 0) cursor.getInt(reasonColumn) else 0

                val statusLabel = when (status) {
                    DownloadManager.STATUS_SUCCESSFUL -> "Concluído"
                    DownloadManager.STATUS_FAILED ->
                        "Falhou${if (reason != 0) " · $reason" else ""}"

                    DownloadManager.STATUS_PAUSED -> "Pausado"

                    DownloadManager.STATUS_RUNNING -> {
                        if (total > 0) {
                            "A transferir · ${((downloaded * 100) / total).coerceIn(0, 100)}%"
                        } else {
                            "A transferir"
                        }
                    }

                    else -> "Na fila"
                }

                val row = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dp(12), dp(9), dp(12), dp(9))
                    background = selectableBackground()
                    isClickable = true
                    isFocusable = true

                    setOnClickListener {
                        if (status == DownloadManager.STATUS_SUCCESSFUL) {
                            openDownloadedFile(manager, id)
                        } else {
                            Toast.makeText(
                                this@OrbitBrowserActivity,
                                statusLabel,
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    }

                    setOnLongClickListener {
                        MaterialAlertDialogBuilder(this@OrbitBrowserActivity)
                            .setTitle("Remover transferência?")
                            .setMessage(filename)
                            .setNegativeButton("Cancelar", null)
                            .setPositiveButton("Remover") { _, _ ->
                                manager.remove(id)
                                showDownloadsSheetAfterDismiss(dialog)
                            }
                            .show()

                        true
                    }
                }

                row.addView(
                    TextView(this).apply {
                        text = filename
                        textSize = 14f
                        maxLines = 1
                        ellipsize = android.text.TextUtils.TruncateAt.MIDDLE
                        setTextColor(primaryText)
                    },
                    LinearLayout.LayoutParams(-1, -2)
                )

                row.addView(
                    TextView(this).apply {
                        text = statusLabel
                        textSize = 12f
                        setTextColor(secondaryText)
                        setPadding(0, dp(3), 0, 0)
                    },
                    LinearLayout.LayoutParams(-1, -2)
                )

                if (status == DownloadManager.STATUS_RUNNING && total > 0) {
                    val bar = ProgressBar(
                        this,
                        null,
                        android.R.attr.progressBarStyleHorizontal
                    ).apply {
                        max = 100
                        progress =
                            ((downloaded * 100) / total).toInt().coerceIn(0, 100)
                        progressTintList =
                            android.content.res.ColorStateList.valueOf(accent)
                    }

                    row.addView(
                        bar,
                        LinearLayout.LayoutParams(-1, dp(3)).apply {
                            topMargin = dp(8)
                        }
                    )
                }

                content.addView(row, LinearLayout.LayoutParams(-1, dp(66)))
                content.addView(sheetDivider())
            }
        }

        if (count == 0) {
            content.addView(
                TextView(this).apply {
                    text = "Ainda não existem transferências."
                    textSize = 14f
                    setTextColor(secondaryText)
                    gravity = Gravity.CENTER
                    setPadding(0, dp(26), 0, dp(30))
                },
                LinearLayout.LayoutParams(-1, -2)
            )
        }

        scroll.addView(content)
        dialog.setContentView(scroll)
        dialog.show()
    }

    private fun showDownloadsSheetAfterDismiss(dialog: BottomSheetDialog) {
        dialog.dismiss()

        android.os.Handler(mainLooper).postDelayed({
            if (!isFinishing) {
                showDownloadsSheet()
            }
        }, 180)
    }

    private fun openDownloadedFile(manager: DownloadManager, id: Long) {
        try {
            val uri = manager.getUriForDownloadedFile(id)

            if (uri == null) {
                Toast.makeText(
                    this,
                    "O ficheiro ainda não está disponível.",
                    Toast.LENGTH_SHORT
                ).show()
                return
            }

            val mime = manager.getMimeTypeForDownloadedFile(id) ?: "*/*"

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            startActivity(Intent.createChooser(intent, "Abrir ficheiro"))
        } catch (_: Exception) {
            Toast.makeText(
                this,
                "Não existe uma aplicação compatível para abrir este ficheiro.",
                Toast.LENGTH_SHORT
            ).show()
        }
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

        Toast.makeText(
            this,
            if (desktopMode) {
                "Site para computador ativado"
            } else {
                "Site para computador desativado"
            },
            Toast.LENGTH_SHORT
        ).show()
    }

    private fun translatePage() {
        val translateUrl =
            "https://translate.google.com/translate?sl=auto&tl=pt&u=" +
                Uri.encode(currentUrl)

        webView.loadUrl(translateUrl)
    }

    private fun setZoom(delta: Int) {
        pageZoom = (pageZoom + delta).coerceIn(50, 200)
        webView.settings.textZoom = pageZoom
    }

    private fun printPage() {
        try {
            val manager = getSystemService(Context.PRINT_SERVICE) as PrintManager
            val adapter = webView.createPrintDocumentAdapter(
                "BrowseIt - ${hostOf(currentUrl)}"
            )

            manager.print(
                "BrowseIt",
                adapter,
                PrintAttributes.Builder().build()
            )
        } catch (_: Exception) {
            Toast.makeText(
                this,
                "Não foi possível imprimir esta página.",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private fun showSiteInfo() {
        val host = hostOf(currentUrl)

        MaterialAlertDialogBuilder(this)
            .setTitle("Informações do site")
            .setMessage("${currentTitle.ifBlank { host }}\n\n$currentUrl")
            .setPositiveButton("Fechar", null)
            .show()
    }

    private fun copyAddress() {
        copyText(currentUrl)
    }

    private fun copyText(value: String) {
        val clipboard =
            getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager

        clipboard.setPrimaryClip(
            android.content.ClipData.newPlainText("BrowseIt", value)
        )

        Toast.makeText(this, "Copiado", Toast.LENGTH_SHORT).show()
    }

    private fun shareAddress() {
        shareText(currentUrl)
    }

    private fun shareText(value: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, value)
        }

        startActivity(Intent.createChooser(send, "Partilhar ligação"))
    }

    private fun startDownload(
        url: String,
        userAgent: String?,
        contentDisposition: String?,
        mimeType: String?
    ) {
        try {
            val filename = android.webkit.URLUtil.guessFileName(
                url,
                contentDisposition,
                mimeType
            )

            val request = DownloadManager.Request(Uri.parse(url)).apply {
                setTitle(filename)
                setDescription("A transferir através do BrowseIt")
                setMimeType(
                    mimeType ?: URLConnection.guessContentTypeFromName(filename)
                )
                setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                )
                setDestinationInExternalFilesDir(
                    this@OrbitBrowserActivity,
                    Environment.DIRECTORY_DOWNLOADS,
                    filename
                )
                addRequestHeader(
                    "User-Agent",
                    userAgent ?: webView.settings.userAgentString
                )

                val cookie = CookieManager.getInstance().getCookie(url)
                if (!cookie.isNullOrBlank()) {
                    addRequestHeader("Cookie", cookie)
                }
            }

            (getSystemService(DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)

            Toast.makeText(
                this,
                "Transferência iniciada",
                Toast.LENGTH_SHORT
            ).show()
        } catch (_: Exception) {
            Toast.makeText(
                this,
                "Não foi possível iniciar a transferência.",
                Toast.LENGTH_SHORT
            ).show()
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
                titlePill.background = rounded(toolbarPillColor(), 24)

                titleView.setTextColor(toolbarText())
                tabsButton.setTextColor(toolbarText())
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
        if (toolbarHidden == hide || previewOnly) return

        toolbarHidden = hide

        toolbar.animate()
            .translationY(if (hide) -toolbar.height.toFloat() else 0f)
            .setDuration(170)
            .start()
    }

    private fun hideCustomView() {
        val view = customView ?: return

        (view.parent as? ViewGroup)?.removeView(view)

        customView = null
        customViewCallback?.onCustomViewHidden()
        customViewCallback = null

        toolbar.visibility = View.VISIBLE

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
        }

        setResult(Activity.RESULT_OK, output)
        finish()
        overridePendingTransition(0, R.anim.browser_slide_down)
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

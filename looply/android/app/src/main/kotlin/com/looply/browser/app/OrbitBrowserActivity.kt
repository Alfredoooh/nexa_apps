package com.looply.browser.app

import android.app.Activity
import android.app.Dialog
import android.animation.ValueAnimator
import android.app.DownloadManager
import android.content.Context
import android.content.ClipData
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.webkit.MimeTypeMap
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
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.SslErrorHandler
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
import androidx.core.content.FileProvider
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
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import java.io.ByteArrayInputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.io.ByteArrayOutputStream
import java.net.URLConnection
import java.util.Locale
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.roundToInt

private data class BrowserElementHit(
    val kind: String,
    val linkUrl: String = "",
    val mediaUrl: String = "",
    val pageUrl: String = "",
    val title: String = "",
    val description: String = "",
    val thumbnailUrl: String = "",
)

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

        private const val INTERNAL_ERROR_BASE = "https://browseit.internal/error/"
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

        private val AD_COSMETIC_FILTER_SCRIPT = """
            (function(){
              if (window.__browseItCosmeticFilterInstalled) return;
              window.__browseItCosmeticFilterInstalled = true;
              const selectors = [
                'ins.adsbygoogle', '[data-ad-slot]', '[data-ad-client]',
                '.ad-container', '.ad-banner', '.advertisement', '.advertising',
                '.sponsored-ad', '.sponsored-content', '.taboola', '.outbrain',
                'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
                'iframe[src*="adservice"]', '[id^="google_ads_"]'
              ];
              const hideAds = root => {
                try { root.querySelectorAll(selectors.join(',')).forEach(el => {
                  if (el && el.dataset && el.dataset.browseItKeep === 'true') return;
                  if (el) { el.style.setProperty('display', 'none', 'important'); el.setAttribute('aria-hidden', 'true'); }
                }); } catch (_) {}
              };
              const prepareMedia = root => {
                try { root.querySelectorAll('video,audio').forEach(media => {
                  media.setAttribute('playsinline', '');
                  media.setAttribute('webkit-playsinline', '');
                  if (!media.hasAttribute('preload')) media.setAttribute('preload', 'metadata');
                }); } catch (_) {}
              };
              hideAds(document);
              prepareMedia(document);
              const observer = new MutationObserver(records => records.forEach(record =>
                record.addedNodes && record.addedNodes.forEach(node => {
                  if (node && node.nodeType === 1) {
                    hideAds(node.parentElement || document);
                    prepareMedia(node.parentElement || document);
                    prepareMedia(node);
                  }
                })
              ));
              observer.observe(document.documentElement, {childList:true, subtree:true});
              document.querySelectorAll('video').forEach(v => {
                try { v.playsInline = true; v.preload = v.preload || 'metadata'; } catch (_) {}
              });
            })();
        """.trimIndent()

        private val MEDIA_COMPATIBILITY_SCRIPT = """
            (function(){
              if (window.__browseItMediaCompatibilityInstalled) return;
              window.__browseItMediaCompatibilityInstalled = true;
              const style = document.createElement('style');
              style.textContent = `
                video,audio { background: transparent !important; max-width: 100%; }
                video { object-fit: contain; }
                video::-webkit-media-controls-enclosure { background: transparent !important; }
                video::-webkit-media-controls-panel { background: rgba(20,20,20,.72); }
                video::-webkit-media-controls-start-playback-button,
                video::-webkit-media-controls-overlay-play-button {
                  display: none !important; -webkit-appearance: none;
                }
              `;
              (document.head || document.documentElement).appendChild(style);
              const prepare = root => {
                try { root.querySelectorAll('video,audio').forEach(media => {
                  media.setAttribute('playsinline', '');
                  media.setAttribute('webkit-playsinline', '');
                  if (!media.hasAttribute('preload')) media.setAttribute('preload', 'metadata');
                  if (media.tagName === 'VIDEO' && !media.hasAttribute('poster')) {
                    media.style.setProperty('background-color', 'transparent', 'important');
                  }
                }); } catch (_) {}
              };
              prepare(document);
              const observer = new MutationObserver(records => records.forEach(record =>
                record.addedNodes && record.addedNodes.forEach(node => {
                  if (node && node.nodeType === 1) prepare(node.parentElement || document);
                  if (node && node.nodeType === 1) prepare(node);
                })
              ));
              if (document.documentElement) observer.observe(document.documentElement, {childList:true, subtree:true});
            })();
        """.trimIndent()

        private const val DESKTOP_VIEWPORT_SCRIPT = """
            (() => {
              try {
                let viewport = document.querySelector('meta[name="viewport"]');
                if (!viewport) {
                  viewport = document.createElement('meta');
                  viewport.name = 'viewport';
                  document.head.appendChild(viewport);
                }
                viewport.content = 'width=1280, initial-scale=0.8, minimum-scale=0.25, maximum-scale=5, user-scalable=yes';
                document.documentElement.style.minWidth = '980px';
                document.body && (document.body.style.minWidth = '980px');
              } catch (_) {}
            })();
        """

        private val blockedHostLabels = setOf(
            "ad", "ads", "adserver", "adservice", "advertising", "banner",
            "popunder", "tracking", "tracker", "pixel", "beacon", "affiliate", "prebid",
        )
        private val adPathPattern = Regex(
            "(?:^|/)(?:ads?|adserver|adservice|advertising|banners?|popunder|trackers?|tracking|pixels?|beacons?|prebid)(?:[/._-]|$)",
            RegexOption.IGNORE_CASE,
        )
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
    private lateinit var swipeRefreshLayout: SwipeRefreshLayout
    private lateinit var moreButton: View
    private lateinit var faviconView: ImageView
    private lateinit var titleView: TextView
    private lateinit var progress: ProgressBar
    private lateinit var webView: WebView
    private lateinit var homeButtonIcon: TextView
    private lateinit var findBar: LinearLayout
    private lateinit var findField: EditText
    private lateinit var tabsButton: android.widget.FrameLayout

    @Volatile private var currentUrl = "https://www.google.com"
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
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var imagesEnabled = true
    @Volatile private var showingInternalErrorPage = false
    @Volatile private var failedNavigationUrl: String? = null
    private val adBlockRules by lazy { NativeAdBlockRules.get(applicationContext).also { it.start() } }

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

        homeButtonIcon = MaterialSymbolsRounded.textView(
            this,
            "home",
            toolbarText(),
            26f,
            "Início",
        )
        val home = android.widget.FrameLayout(this).apply {
            contentDescription = "Início"
            isClickable = true
            isFocusable = true
            background = selectableBackground()
            addView(homeButtonIcon, android.widget.FrameLayout.LayoutParams(dp(34), dp(34), Gravity.CENTER))
            setOnClickListener { finishToFlutter("home") }
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
                    dp(24),
                )
            )
        }

        titlePill.addView(
            faviconView,
            LinearLayout.LayoutParams(dp(24), dp(24))
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
            // Mais passos internos evitam o movimento aos saltos quando o
            // WebView actualiza o progresso em rajadas curtas.
            max = 1000
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

        swipeRefreshLayout = SwipeRefreshLayout(this).apply {
            setColorSchemeColors(accent)
            setProgressBackgroundColorSchemeColor(toolbarPillColor())
            setOnChildScrollUpCallback { _, _ -> webView.scrollY > 0 }
            isEnabled = !previewOnly
            setOnRefreshListener {
                if (::webView.isInitialized) reloadCurrentPage()
                else isRefreshing = false
            }
            addView(webView, ViewGroup.LayoutParams(-1, -1))
        }
        root.addView(swipeRefreshLayout, LinearLayout.LayoutParams(-1, 0, 1f))
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
        progressTarget = target.coerceIn(0, 100) * 10

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
            duration = (360L + initialDistance / 2L).coerceIn(380L, 680L)
            interpolator = LinearInterpolator()
        }
        animator.addUpdateListener { update ->
            if (::progress.isInitialized && !isFinishing) {
                val targetNow = progressTarget
                val fraction = update.animatedFraction
                progress.progress = (startValue + (targetNow - startValue) * fraction)
                    .toInt().coerceIn(0, 1000)
            }
        }
        animator.addListener(object : android.animation.AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: android.animation.Animator) {
                if (progressAnimator === animator) progressAnimator = null
                if (!isFinishing && progress.progress != progressTarget) {
                    setProgressSmooth((progressTarget / 10).coerceIn(0, 100))
                } else if (!isFinishing && progressTarget >= 1000 && progress.progress >= 1000) {
                    hideProgressIfComplete()
                }
            }
        })
        progressAnimator = animator
        animator.start()
    }

    private fun hideProgressIfComplete() {
        if (!::progress.isInitialized || isFinishing ||
            progressTarget < 1000 || progress.progress < 1000 ||
            progress.visibility != View.VISIBLE
        ) return

        progress.animate().cancel()
        progress.animate()
            .alpha(0f)
            .setDuration(160L)
            .withEndAction {
                if (!isFinishing && progressTarget >= 1000 && progress.progress >= 1000) {
                    progress.visibility = View.GONE
                }
                progress.alpha = 1f
            }
            .start()
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
            if (adBlockEnabled) {
                webView.post {
                    if (!isFinishing && ::webView.isInitialized && webView.url == currentUrl) {
                        webView.evaluateJavascript(AD_COSMETIC_FILTER_SCRIPT, null)
                    }
                }
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
        adBlockRules.start()
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

                if (scheme == "browseit" && uri.host == "retry") {
                    retryFailedNavigation()
                    return true
                }
                if (scheme == "browseit" && uri.host == "home") {
                    finishToFlutter("home")
                    return true
                }
                if (scheme == "http" || scheme == "https") return false

                return openExternalUri(uri)
            }

            @Suppress("DEPRECATION")
            override fun shouldOverrideUrlLoading(
                view: WebView,
                url: String
            ): Boolean {
                val uri = Uri.parse(url)
                if (uri.scheme == "browseit" && uri.host == "retry") {
                    retryFailedNavigation()
                    return true
                }
                if (uri.scheme == "browseit" && uri.host == "home") {
                    finishToFlutter("home")
                    return true
                }
                if (uri.scheme == "http" || uri.scheme == "https") {
                    return false
                }

                return openExternalUri(uri)
            }

            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest
            ): WebResourceResponse? {
                if (adBlockEnabled && isBlocked(request.url, request)) {
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
                if (url.startsWith(INTERNAL_ERROR_BASE)) {
                    showingInternalErrorPage = true
                    if (::swipeRefreshLayout.isInitialized) swipeRefreshLayout.isRefreshing = false
                    hideToolbar(false)
                    setProgressSmooth(100, immediate = true)
                    progress.visibility = View.GONE
                    refreshTitle()
                    updateToolbarColors()
                    return
                }

                showingInternalErrorPage = false
                failedNavigationUrl = null
                currentUrl = url
                currentTitle = ""
                pageToolbarColor = null
                lastScrollDirection = 0
                accumulatedScrollDelta = 0
                reverseScrollDelta = 0
                appliedPageZoomPercent = 100
                hideToolbar(false)
                setProgressSmooth(0, immediate = true)
                progress.visibility = View.VISIBLE
                progress.alpha = 1f
                refreshTitle()
                updateToolbarColors()
            }

            override fun onPageFinished(view: WebView, url: String) {
                if (url.startsWith(INTERNAL_ERROR_BASE) || showingInternalErrorPage) {
                    if (::swipeRefreshLayout.isInitialized) swipeRefreshLayout.isRefreshing = false
                    setProgressSmooth(100, immediate = true)
                    progress.visibility = View.GONE
                    refreshTitle()
                    updateToolbarColors()
                    return
                }

                currentUrl = url
                currentTitle = view.title?.takeIf { it.isNotBlank() } ?: hostOf(url)

                if (::swipeRefreshLayout.isInitialized) swipeRefreshLayout.isRefreshing = false
                setProgressSmooth(100)
                progress.postDelayed({ hideProgressIfComplete() }, 520L)

                refreshTitle()
                updateToolbarColors()
                view.evaluateJavascript(MEDIA_COMPATIBILITY_SCRIPT, null)
                if (desktopMode) view.evaluateJavascript(DESKTOP_VIEWPORT_SCRIPT, null)
                if (adBlockEnabled) {
                    view.evaluateJavascript(AD_COSMETIC_FILTER_SCRIPT, null)
                }
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
                if (request.isForMainFrame && !showingInternalErrorPage &&
                    !request.url.toString().startsWith(INTERNAL_ERROR_BASE)) {
                    val description = error.description?.toString()
                        ?: menuText("loadingError", "Could not load this page.")
                    showInternalErrorPage(request.url.toString(), description, error.errorCode)
                }
            }

            override fun onReceivedHttpError(
                view: WebView,
                request: WebResourceRequest,
                errorResponse: WebResourceResponse
            ) {
                if (request.isForMainFrame && errorResponse.statusCode >= 400 &&
                    !showingInternalErrorPage && !request.url.toString().startsWith(INTERNAL_ERROR_BASE)) {
                    showInternalErrorPage(
                        request.url.toString(),
                        "HTTP ${errorResponse.statusCode}",
                        errorResponse.statusCode,
                    )
                }
            }

            override fun onReceivedSslError(
                view: WebView,
                handler: SslErrorHandler,
                error: android.net.http.SslError
            ) {
                handler.cancel()
                if (!showingInternalErrorPage) {
                    showInternalErrorPage(
                        error.url ?: currentUrl,
                        localizedBrowserText(
                            "Não foi possível estabelecer uma ligação segura.",
                            "A secure connection could not be established."
                        ),
                        error.primaryError,
                    )
                }
            }

        }

        webView.webChromeClient = object : WebChromeClient() {

            override fun onProgressChanged(view: WebView, newProgress: Int) {
                setProgressSmooth(newProgress)
                progress.visibility = View.VISIBLE
                if (newProgress >= 100) {
                    progress.postDelayed({ hideProgressIfComplete() }, 460L)
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

                swipeRefreshLayout.removeView(webView)
                root.removeView(swipeRefreshLayout)
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

        webView.setOnTouchListener { _, event ->
            if (event.actionMasked == android.view.MotionEvent.ACTION_DOWN ||
                event.actionMasked == android.view.MotionEvent.ACTION_MOVE
            ) {
                lastTouchX = event.x
                lastTouchY = event.y
            }
            false
        }

        webView.setOnLongClickListener {
            inspectElementAtTouch(webView.hitTestResult)
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

    /** O mesmo fundo, raio e cor de acento dos diálogos Flutter do BrowseIt. */
    private fun looplyMaterialDialogBuilder(): MaterialAlertDialogBuilder {
        val overlay = if (dark) R.style.LooplyBrowserDialog_Dark else R.style.LooplyBrowserDialog_Light
        val dialogSurface = when {
            !dark -> Color.WHITE
            pureBlack -> Color.rgb(25, 25, 25)
            else -> Color.rgb(43, 45, 48)
        }
        return MaterialAlertDialogBuilder(this, overlay)
            .setBackground(rounded(dialogSurface, 24))
    }

    private fun applyLooplyDialogDim(dialog: android.app.Dialog) {
        dialog.window?.let { dialogWindow ->
            dialogWindow.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            val attributes = dialogWindow.attributes
            attributes.dimAmount = .34f
            dialogWindow.attributes = attributes
        }
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

        val dialog = looplyMaterialDialogBuilder()
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
        applyLooplyDialogDim(dialog)
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
        val popupWidth = minOf(dp(284), screenWidth - dp(24)).coerceAtLeast(dp(260))
        val maxPopupHeight = (screenHeight * .76f).toInt().coerceAtLeast(dp(300))
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
                        dp(27),
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
                addView(icon, android.widget.FrameLayout.LayoutParams(dp(27), dp(27), Gravity.CENTER))
                setOnClickListener {
                    if (enabled) {
                        popupWindowRef?.dismiss()
                        action()
                    }
                }
            }
            quickRow.addView(
                frame,
                LinearLayout.LayoutParams(dp(48), dp(48)).apply {
                    // Mantém o trilho realmente deslocável: os cinco atalhos
                    // excedem ligeiramente a largura visível do popup estreito.
                    marginStart = dp(5)
                    marginEnd = dp(5)
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
            reloadCurrentPage()
        }

        quickScroller.addView(
            quickRow,
            android.widget.FrameLayout.LayoutParams(-2, -1),
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
                                dp(27),
                            )
                        )
                        scaleType = ImageView.ScaleType.FIT_CENTER
                    },
                    LinearLayout.LayoutParams(dp(27), dp(27)),
                )
                addView(View(this@OrbitBrowserActivity), LinearLayout.LayoutParams(dp(12), 1))
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
            menuItems.addView(row, LinearLayout.LayoutParams(-1, dp(50)))
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
        menuRow(localizedBrowserText("Abrir no navegador externo", "Open in external browser"), "open_in_new") {
            openCurrentPageExternally()
        }
        menuRow(localizedBrowserText("Copiar ligação limpa", "Copy clean link"), "link") {
            copyCleanCurrentUrl()
        }
        menuRow(localizedBrowserText("Copiar título e endereço", "Copy title and address"), "content_copy") {
            copyText("$currentTitle\n$currentUrl")
        }
        menuDivider()
        menuRow(localizedBrowserText("Modo de leitura", "Reader mode"), "description") {
            showReaderMode()
        }
        menuRow(localizedBrowserText("Recarregar sem cache", "Hard reload"), "refresh") {
            webView.clearCache(false)
            reloadCurrentPage()
        }
        menuRow(localizedBrowserText("Guardar página offline", "Save page offline"), "archive") {
            savePageOffline()
        }
        menuRow(
            if (webView.settings.loadsImagesAutomatically)
                localizedBrowserText("Desativar imagens", "Disable images")
            else localizedBrowserText("Ativar imagens", "Enable images"),
            "image",
        ) { togglePageImages() }
        menuRow(
            if (webView.settings.javaScriptEnabled)
                localizedBrowserText("Desativar JavaScript", "Disable JavaScript")
            else localizedBrowserText("Ativar JavaScript", "Enable JavaScript"),
            "code",
        ) { togglePageJavaScript() }
        menuRow(localizedBrowserText("Ver código-fonte", "View page source"), "code_blocks") {
            showPageSource()
        }
        menuRow(menuText("settings", "Browser settings"), "settings") { finishToFlutter("settings") }

        val menuHeight = minOf(dp(570), maxPopupHeight - dp(66)).coerceAtLeast(dp(180))
        content.addView(menuScroll, LinearLayout.LayoutParams(-1, menuHeight))
        val popupHeight = (menuHeight + dp(76)).coerceAtMost(maxPopupHeight)

        val popup = PopupWindow(content, popupWidth, popupHeight, true).apply {
            setBackgroundDrawable(rounded(surface, 26))
            setElevation(dp(20).toFloat())
            // A animação de janela do Android é a mesma utilizada por menus
            // popup nativos: escala + fade a partir da âncora, com saída curta.
            setAnimationStyle(R.style.LooplyNativePopupWindowAnimation)
            isOutsideTouchable = true
            isClippingEnabled = true
            inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        }
        popupWindowRef = popup
        popup.setOnDismissListener {
            if (popupWindowRef === popup) popupWindowRef = null
        }

        // Coloca o menu sobre o próprio botão de overflow, alinhando a borda
        // direita ao ícone. Assim o popup cobre o botão em vez de nascer abaixo.
        val anchorLocation = IntArray(2)
        anchor.getLocationOnScreen(anchorLocation)
        val visibleFrame = Rect()
        anchor.getWindowVisibleDisplayFrame(visibleFrame)
        val popupX = (anchorLocation[0] + anchor.width - popupWidth)
            .coerceAtLeast(dp(8))
        val preferredY = anchorLocation[1]
        val popupY = if (preferredY + popupHeight > visibleFrame.bottom) {
            (anchorLocation[1] + anchor.height - popupHeight).coerceAtLeast(visibleFrame.top)
        } else {
            preferredY.coerceAtLeast(visibleFrame.top)
        }
        popup.showAtLocation(root, Gravity.TOP or Gravity.LEFT, popupX, popupY)
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
                android.widget.FrameLayout.LayoutParams(dp(24), dp(24), Gravity.CENTER)
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

    private fun inspectElementAtTouch(fallback: WebView.HitTestResult) {
        val density = resources.displayMetrics.density.coerceAtLeast(1f)
        val x = (lastTouchX / density).roundToInt().coerceAtLeast(0)
        val y = (lastTouchY / density).roundToInt().coerceAtLeast(0)
        val script = """
            (function(){
              try {
                let e = document.elementFromPoint($x, $y);
                if (!e) return null;
                const closest = (n, q) => n && n.closest ? n.closest(q) : null;
                const a = closest(e, 'a[href]');
                const img = closest(e, 'img');
                const video = closest(e, 'video') || (e.tagName === 'SOURCE' && closest(e, 'video'));
                const audio = closest(e, 'audio') || (e.tagName === 'SOURCE' && closest(e, 'audio'));
                const source = e.tagName === 'SOURCE' ? e : null;
                const mediaUrl = video ? (video.currentSrc || video.src || (video.querySelector('source') || {}).src || '')
                  : audio ? (audio.currentSrc || audio.src || (audio.querySelector('source') || {}).src || '')
                  : img ? (img.currentSrc || img.src || img.getAttribute('src') || '')
                  : source ? (source.src || '') : '';
                const kind = video ? 'video' : audio ? 'audio' : img ? 'image' : a ? 'link' : 'other';
                const thumbnail = video ? (video.poster || '') : img ? (img.currentSrc || img.src || '') : '';
                return JSON.stringify({
                  kind: kind,
                  link: a ? (a.href || '') : '',
                  media: mediaUrl,
                  thumbnail: thumbnail,
                  page: location.href,
                  title: document.title || '',
                  description: img ? (img.alt || '') : (e.getAttribute('aria-label') || e.textContent || '')
                });
              } catch (_) { return null; }
            })();
        """.trimIndent()
        webView.evaluateJavascript(script) { raw ->
            val encoded = runCatching {
                val parsed = org.json.JSONTokener(raw ?: "null").nextValue()
                parsed as? String
            }.getOrNull()
            val payload = encoded?.let { runCatching { JSONObject(it) }.getOrNull() }
            if (payload == null) {
                val legacy = fallback.extra?.takeIf { it.isNotBlank() }
                if (legacy != null) {
                    val kind = when (fallback.type) {
                        WebView.HitTestResult.IMAGE_TYPE,
                        WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE -> "image"
                        WebView.HitTestResult.ANCHOR_TYPE,
                        WebView.HitTestResult.SRC_ANCHOR_TYPE -> "link"
                        else -> "other"
                    }
                    showElementSheet(BrowserElementHit(kind, linkUrl = if (kind == "link") legacy else "", mediaUrl = if (kind == "image") legacy else "", pageUrl = currentUrl))
                }
                return@evaluateJavascript
            }
            val hit = BrowserElementHit(
                kind = payload.optString("kind", "other"),
                linkUrl = payload.optString("link"),
                mediaUrl = payload.optString("media"),
                pageUrl = payload.optString("page", currentUrl),
                title = payload.optString("title"),
                description = payload.optString("description"),
                thumbnailUrl = payload.optString("thumbnail"),
            )
            if (hit.kind != "other" || hit.linkUrl.isNotBlank() || hit.mediaUrl.isNotBlank()) {
                showElementSheet(hit)
            } else {
                val legacy = fallback.extra?.takeIf { it.isNotBlank() }
                if (!legacy.isNullOrBlank()) showElementSheet(
                    BrowserElementHit("other", pageUrl = currentUrl, description = legacy)
                )
            }
        }
    }

    private fun showElementSheet(hit: BrowserElementHit) {
        val isImage = hit.kind == "image"
        val isVideo = hit.kind == "video"
        val isAudio = hit.kind == "audio"
        val isLink = hit.kind == "link" || hit.linkUrl.isNotBlank()
        val primaryTarget = when {
            isImage || isVideo || isAudio -> hit.mediaUrl
            hit.linkUrl.isNotBlank() -> hit.linkUrl
            else -> hit.pageUrl
        }.ifBlank { hit.pageUrl }
        if (!isSafeWebUrl(primaryTarget)) return

        val dialog = Dialog(this)
        val surface = if (!dark) Color.WHITE else if (pureBlack) Color.rgb(28, 28, 30) else Color.rgb(53, 55, 64)
        val divider = if (!dark) Color.rgb(225, 227, 230) else Color.rgb(77, 79, 88)
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(surface, 25)
            clipToOutline = true
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
        }
        val thumb = ImageView(this).apply {
            scaleType = if (isImage || isVideo) ImageView.ScaleType.CENTER_CROP else ImageView.ScaleType.CENTER_INSIDE
            background = rounded(if (dark) Color.rgb(44, 46, 54) else Color.rgb(239, 241, 244), if (isImage || isVideo) 3 else 999)
            clipToOutline = true
        }
        val thumbnailUrl = when {
            hit.thumbnailUrl.isNotBlank() -> hit.thumbnailUrl
            isImage -> hit.mediaUrl
            isLink -> runCatching {
                val host = Uri.parse(primaryTarget).host.orEmpty()
                if (host.isBlank()) "" else "https://www.google.com/s2/favicons?domain=${Uri.encode(host)}&sz=128"
            }.getOrDefault("")
            else -> ""
        }
        if (isImage || isVideo) {
            header.addView(thumb, LinearLayout.LayoutParams(dp(100), dp(68)))
        } else {
            val hostInitial = Uri.parse(primaryTarget).host.orEmpty().removePrefix("www.").firstOrNull()?.uppercaseChar()?.toString() ?: "•"
            val fallback = TextView(this).apply {
                text = hostInitial
                textSize = 21f
                gravity = Gravity.CENTER
                setTextColor(if (dark) Color.WHITE else Color.rgb(45, 48, 54))
                background = rounded(if (dark) Color.rgb(68, 71, 80) else Color.rgb(225, 228, 232), 999)
            }
            val thumbFrame = android.widget.FrameLayout(this).apply {
                addView(fallback, android.widget.FrameLayout.LayoutParams(dp(54), dp(54), Gravity.CENTER))
                addView(thumb, android.widget.FrameLayout.LayoutParams(dp(54), dp(54), Gravity.CENTER))
                thumb.alpha = 0f
            }
            header.addView(thumbFrame, LinearLayout.LayoutParams(dp(58), dp(58)))
        }

        val headerText = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), 0, 0, 0)
        }
        val host = Uri.parse(primaryTarget).host.orEmpty().removePrefix("www.")
        val heading = when {
            hit.description.isNotBlank() -> hit.description.replace(Regex("\\s+"), " ").trim()
            hit.title.isNotBlank() && !isImage && !isVideo -> hit.title
            isImage -> localizedBrowserText("Imagem selecionada", "Selected image")
            isVideo -> localizedBrowserText("Vídeo selecionado", "Selected video")
            isAudio -> localizedBrowserText("Áudio selecionado", "Selected audio")
            else -> host.ifBlank { localizedBrowserText("Ligação", "Link") }
        }
        headerText.addView(TextView(this).apply {
            text = heading
            textSize = 15.5f
            setTextColor(primaryText)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            maxLines = 2
            ellipsize = android.text.TextUtils.TruncateAt.END
        }, LinearLayout.LayoutParams(-1, -2))
        headerText.addView(TextView(this).apply {
            text = primaryTarget
            textSize = 12.5f
            setTextColor(secondaryText)
            maxLines = 2
            ellipsize = android.text.TextUtils.TruncateAt.MIDDLE
            setPadding(0, dp(5), 0, 0)
        }, LinearLayout.LayoutParams(-1, -2))
        header.addView(headerText, LinearLayout.LayoutParams(0, -2, 1f))
        card.addView(header, LinearLayout.LayoutParams(-1, -2))
        card.addView(View(this).apply { setBackgroundColor(divider) }, LinearLayout.LayoutParams(-1, dp(1)))

        val actionScroll = ScrollView(this).apply {
            isFillViewport = false
            overScrollMode = View.OVER_SCROLL_NEVER
            isVerticalScrollBarEnabled = false
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(8), 0, dp(8))
        }
        fun action(label: String, callback: () -> Unit) {
            val row = TextView(this).apply {
                text = label
                textSize = 16f
                setTextColor(primaryText)
                gravity = Gravity.CENTER_VERTICAL
                includeFontPadding = false
                maxLines = 2
                setPadding(dp(22), dp(8), dp(18), dp(8))
                minHeight = dp(56)
                background = selectableBackground()
                isClickable = true
                isFocusable = true
                setOnClickListener {
                    dialog.dismiss()
                    callback()
                }
            }
            actions.addView(row, LinearLayout.LayoutParams(-1, -2))
        }

        if (isImage) {
            action(localizedBrowserText("Abrir imagem num novo separador", "Open image in new tab")) {
                finishToFlutter("newTab", hit.mediaUrl)
            }
            action(localizedBrowserText("Pré-visualizar imagem", "Preview image")) {
                showMediaPreviewDialog(hit.mediaUrl, "image")
            }
            action(localizedBrowserText("Copiar imagem", "Copy image")) { copyText(hit.mediaUrl) }
            action(localizedBrowserText("Transferir imagem", "Download image")) {
                startDownload(hit.mediaUrl, null, null, "image/*")
            }
            action(localizedBrowserText("Pesquisar a imagem no Google", "Search image with Google")) {
                finishToFlutter("newTab", "https://lens.google.com/uploadbyurl?url=${Uri.encode(hit.mediaUrl)}")
            }
            action(localizedBrowserText("Partilhar imagem", "Share image")) { shareRemoteImage(hit.mediaUrl) }
        } else if (isVideo || isAudio) {
            val mediaLabel = if (isVideo) "vídeo" else "áudio"
            val mediaLabelEn = if (isVideo) "video" else "audio"
            action(localizedBrowserText("Abrir $mediaLabel num novo separador", "Open $mediaLabelEn in new tab")) {
                finishToFlutter("newTab", hit.mediaUrl)
            }
            action(localizedBrowserText("Pré-visualizar $mediaLabel", "Preview $mediaLabelEn")) {
                showMediaPreviewDialog(hit.mediaUrl, hit.kind)
            }
            action(localizedBrowserText("Copiar ligação do $mediaLabel", "Copy $mediaLabelEn link")) { copyText(hit.mediaUrl) }
            if (isDirectMediaUrl(hit.mediaUrl)) {
                action(localizedBrowserText("Transferir $mediaLabel", "Download $mediaLabelEn")) {
                    startDownload(hit.mediaUrl, null, null, if (isVideo) "video/*" else "audio/*")
                }
            }
            action(localizedBrowserText("Partilhar ligação do $mediaLabel", "Share $mediaLabelEn link")) { shareText(hit.mediaUrl) }
        } else {
            val link = hit.linkUrl.ifBlank { primaryTarget }
            action(localizedBrowserText("Abrir num novo separador", "Open in new tab")) {
                finishToFlutter("newTab", link)
            }
            action(localizedBrowserText("Abrir no separador de navegação anónima", "Open in incognito tab")) {
                finishToFlutter("newIncognitoTab", link)
            }
            action(localizedBrowserText("Pré-visualizar página", "Preview page")) { showLinkPreviewDialog(link) }
            action(localizedBrowserText("Copiar endereço do link", "Copy link address")) { copyText(link) }
            action(localizedBrowserText("Copiar texto do link", "Copy link text")) {
                copyText(hit.description.ifBlank { hit.title.ifBlank { link } })
            }
            action(localizedBrowserText("Transferir link", "Download link")) {
                startDownload(link, null, null, null)
            }
            action(localizedBrowserText("Adicionar à Lista de leitura", "Add to reading list")) {
                if (!incognito) finishToFlutter("bookmarkUrl", link)
            }
            action(localizedBrowserText("Partilhar link", "Share link")) { shareText(link) }
        }

        actionScroll.addView(actions, android.widget.FrameLayout.LayoutParams(-1, -2))
        card.addView(actionScroll, LinearLayout.LayoutParams(-1, -2))
        dialog.setContentView(card, ViewGroup.LayoutParams(-1, -2))
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        dialog.show()
        val dialogWidth = minOf(dp(560), (resources.displayMetrics.widthPixels * .80f).toInt())
        val maxDialogHeight = (resources.displayMetrics.heightPixels * .82f).toInt()
        card.measure(
            View.MeasureSpec.makeMeasureSpec(dialogWidth, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(maxDialogHeight, View.MeasureSpec.AT_MOST),
        )
        val dialogHeight = card.measuredHeight.coerceAtLeast(dp(180)).coerceAtMost(maxDialogHeight)
        dialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setLayout(dialogWidth, dialogHeight)
            addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            setDimAmount(.46f)
        }
        loadContextThumbnail(thumbnailUrl, thumb, dialog, primaryTarget)
    }

    private fun loadContextThumbnail(url: String, target: ImageView, dialog: Dialog, referer: String) {
        if (!isSafeWebUrl(url)) return
        Thread {
            var connection: HttpURLConnection? = null
            try {
                connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 6_000
                connection.readTimeout = 8_000
                connection.instanceFollowRedirects = true
                connection.setRequestProperty("User-Agent", runCatching { webView.settings.userAgentString }.getOrDefault("BrowseIt"))
                connection.setRequestProperty("Referer", referer)
                connection.getInputStream().use { input ->
                    val bitmap = BitmapFactory.decodeStream(input)
                    if (bitmap != null) runOnUiThread {
                        if (!isFinishing && dialog.isShowing) {
                            target.setImageBitmap(bitmap)
                            target.alpha = 1f
                        }
                    }
                }
            } catch (_: Exception) {
            } finally {
                connection?.disconnect()
            }
        }.start()
    }

    private fun reloadCurrentPage() {
        if (showingInternalErrorPage) retryFailedNavigation() else webView.reload()
    }

    private fun retryFailedNavigation() {
        val retryUrl = failedNavigationUrl?.takeIf(::isSafeWebUrl) ?: return
        showingInternalErrorPage = false
        failedNavigationUrl = null
        currentUrl = retryUrl
        webView.loadUrl(retryUrl)
    }

    private fun showInternalErrorPage(url: String, detail: String, errorCode: Int) {
    if (!isSafeWebUrl(url)) return
    failedNavigationUrl = url
    currentUrl = url
    showingInternalErrorPage = true
    currentTitle = localizedBrowserText("Sem ligação", "Connection problem")
    pageToolbarColor = null
    if (::swipeRefreshLayout.isInitialized) swipeRefreshLayout.isRefreshing = false
    setProgressSmooth(100, immediate = true)
    progress.visibility = View.GONE

    val background = cssColor(pageBg)
    val surface = cssColor(toolbarBg)
    val foreground = cssColor(primaryText)
    val muted = cssColor(secondaryText)
    val button = cssColor(accent)
    val safeDetail = android.text.TextUtils.htmlEncode(detail.take(180))
    val safeUrl = android.text.TextUtils.htmlEncode(url.take(160))
    val heading = android.text.TextUtils.htmlEncode(
        localizedBrowserText("Não foi possível abrir esta página", "This page could not be opened")
    )
    val explanation = android.text.TextUtils.htmlEncode(
        localizedBrowserText(
            "Verifica a ligação à Internet e tenta novamente.",
            "Check your internet connection and try again."
        )
    )
    val retryLabel = android.text.TextUtils.htmlEncode(localizedBrowserText("Tentar novamente", "Try again"))
    val homeLabel = android.text.TextUtils.htmlEncode(localizedBrowserText("Voltar ao início", "Go to home"))
    val html = """
        <!doctype html><html lang="${if (menuLabels.optString("appLocale", "pt").startsWith("pt")) "pt" else "en"}">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <meta name="color-scheme" content="${if (dark) "dark" else "light"}">
        <style>
          *{box-sizing:border-box}html,body{margin:0;min-height:100%;background:$background;color:$foreground;font-family:Roboto,"Arial",sans-serif}
          body{display:flex;align-items:center;justify-content:center;padding:28px 22px}
          main{width:100%;max-width:420px;text-align:center;background:$surface;border-radius:24px;padding:30px 22px;box-shadow:0 8px 28px rgba(0,0,0,.08)}
          .icon-wrap{width:96px;height:96px;margin:0 auto 22px;display:block}
          .icon-wrap circle.bg{opacity:0;animation:fade-in .4s ease forwards}
          .wifi-stroke{stroke-dasharray:60;stroke-dashoffset:60;opacity:0;animation:draw .5s ease forwards,fade-in .01s linear forwards}
          .wifi-stroke:nth-of-type(1){animation-delay:.15s,.15s}
          .wifi-stroke:nth-of-type(2){animation-delay:.45s,.45s}
          .wifi-dot{opacity:0;transform:scale(0);transform-origin:center;animation:dot-pop .35s cubic-bezier(.34,1.56,.64,1) forwards;animation-delay:.75s}
          .wifi-cross{stroke-dasharray:76;stroke-dashoffset:76;opacity:0;animation:draw-cross .4s ease forwards,fade-in .01s linear forwards;animation-delay:1s,1s}
          @keyframes fade-in{to{opacity:1}}
          @keyframes draw{to{stroke-dashoffset:0;opacity:.4}}
          @keyframes draw-cross{to{stroke-dashoffset:0;opacity:1}}
          @keyframes dot-pop{to{opacity:.4;transform:scale(1)}}
          h1,p,a{opacity:0;transform:translateY(8px);animation:content-in .45s ease forwards}
          h1{animation-delay:1.2s}p.explanation{animation-delay:1.3s}p.detail{animation-delay:1.4s}a.primary{animation-delay:1.5s}a.secondary{animation-delay:1.6s}
          @keyframes content-in{to{opacity:1;transform:translateY(0)}}
          h1{font-size:21px;line-height:1.3;margin:0 0 10px;font-weight:700;color:$foreground}
          p{font-size:15px;line-height:1.55;margin:0 0 18px;color:$muted}
          .detail{font-size:12px;word-break:break-word;opacity:.8;margin:0 0 22px}
          a{display:block;text-decoration:none;border-radius:999px;padding:14px 18px;font-size:15px;font-weight:600;margin-top:10px}
          .primary{background:$button;color:#fff}.secondary{background:transparent;color:$foreground;border:1px solid $muted}
        </style></head><body><main>
          <svg class="icon-wrap" viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle class="bg" cx="48" cy="48" r="48" fill="$button" fill-opacity="0.1"/>
            <path class="wifi-stroke" d="M30 44c10-9 26-9 36 0" stroke="$button" stroke-width="4" stroke-linecap="round"/>
            <path class="wifi-stroke" d="M37 54c6-5 16-5 22 0" stroke="$button" stroke-width="4" stroke-linecap="round"/>
            <circle class="wifi-dot" cx="48" cy="64" r="3.5" fill="$button"/>
            <path class="wifi-cross" d="M30 30l36 36" stroke="$button" stroke-width="4.5" stroke-linecap="round"/>
          </svg>
          <h1>$heading</h1><p class="explanation">$explanation</p>
          <p class="detail">$safeUrl<br>$safeDetail · $errorCode</p>
          <a class="primary" href="browseit://retry">$retryLabel</a>
          <a class="secondary" href="browseit://home">$homeLabel</a>
        </main></body></html>
    """.trimIndent()
    refreshTitle()
    webView.stopLoading()
    webView.loadDataWithBaseURL(INTERNAL_ERROR_BASE, html, "text/html", "UTF-8", null)
}

    private fun cssColor(color: Int): String = String.format(Locale.ROOT, "#%06X", 0xFFFFFF and color)

    private fun localizedBrowserText(portuguese: String, english: String): String {
        val language = menuLabels.optString("appLocale", "pt").lowercase(Locale.ROOT)
        return if (language.startsWith("pt")) portuguese else english
    }

    private fun isSafeWebUrl(value: String): Boolean {
        val uri = runCatching { Uri.parse(value) }.getOrNull() ?: return false
        return uri.scheme in listOf("http", "https") && !uri.host.isNullOrBlank()
    }

    private fun isDirectMediaUrl(value: String): Boolean {
        if (!isSafeWebUrl(value)) return false
        val path = Uri.parse(value).path.orEmpty().lowercase(Locale.ROOT)
        return listOf(".mp4", ".webm", ".mov", ".m4v", ".mp3", ".m4a", ".ogg", ".wav", ".aac")
            .any(path::endsWith)
    }

    private fun showLinkPreviewDialog(target: String) {
        if (!isSafeWebUrl(target)) return
        showWebContentDialog(target, "page")
    }

    private fun showMediaPreviewDialog(target: String, kind: String) {
        if (!isSafeWebUrl(target)) return
        showWebContentDialog(target, kind)
    }

    private fun showWebContentDialog(target: String, kind: String) {
        val dialog = Dialog(this)
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(pageBg, 14)
            clipToOutline = true
        }
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(8), dp(8), dp(8))
            setBackgroundColor(toolbarBg)
        }
        val label = TextView(this).apply {
            text = when (kind) {
                "image" -> localizedBrowserText("Pré-visualização da imagem", "Image preview")
                "video" -> localizedBrowserText("Pré-visualização do vídeo", "Video preview")
                "audio" -> localizedBrowserText("Pré-visualização do áudio", "Audio preview")
                else -> localizedBrowserText("Pré-visualização da página", "Page preview")
            }
            setTextColor(primaryText)
            textSize = 15f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            maxLines = 1
        }
        top.addView(label, LinearLayout.LayoutParams(0, dp(44), 1f))
        fun topAction(icon: String, description: String, action: () -> Unit) {
            val button = android.widget.FrameLayout(this).apply {
                contentDescription = description
                background = selectableBackground()
                isClickable = true
                isFocusable = true
                addView(
                    MaterialSymbolsRounded.textView(this@OrbitBrowserActivity, icon, secondaryText, 22f),
                    android.widget.FrameLayout.LayoutParams(dp(32), dp(32), Gravity.CENTER)
                )
                setOnClickListener { action() }
            }
            top.addView(button, LinearLayout.LayoutParams(dp(42), dp(44)))
        }
        var previewWebView: WebView? = null
        topAction("arrow_forward", localizedBrowserText("Abrir nesta aba", "Open in this tab")) {
            dialog.dismiss()
            loadAddress(target)
        }
        topAction("open_in_new", localizedBrowserText("Abrir em nova aba", "Open in new tab")) {
            dialog.dismiss()
            finishToFlutter("newTab", target)
        }
        topAction("content_copy", localizedBrowserText("Copiar endereço", "Copy address")) {
            copyText(target)
        }
        topAction("share", localizedBrowserText("Partilhar", "Share")) { shareText(target) }
        topAction("close", localizedBrowserText("Fechar", "Close")) { dialog.dismiss() }

        val preview = WebView(this).apply {
            setBackgroundColor(pageBg)
            isVerticalScrollBarEnabled = true
            settings.javaScriptEnabled = kind == "page"
            settings.domStorageEnabled = kind == "page"
            settings.loadsImagesAutomatically = true
            settings.mediaPlaybackRequiresUserGesture = true
            settings.javaScriptCanOpenWindowsAutomatically = false
            settings.setSupportMultipleWindows(false)
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            settings.cacheMode = if (incognito) WebSettings.LOAD_NO_CACHE else WebSettings.LOAD_CACHE_ELSE_NETWORK
            if (Build.VERSION.SDK_INT >= 26) settings.safeBrowsingEnabled = true
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    return request.url.scheme !in listOf("http", "https")
                }
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                    if (adBlockEnabled && isBlocked(request.url, request)) {
                        return WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))
                    }
                    return super.shouldInterceptRequest(view, request)
                }
            }
        }
        previewWebView = preview
        container.addView(top, LinearLayout.LayoutParams(-1, dp(56)))
        container.addView(preview, LinearLayout.LayoutParams(-1, dp(480)))
        dialog.setContentView(container)
        dialog.setOnDismissListener {
            previewWebView?.let { view ->
                runCatching {
                    view.stopLoading()
                    view.webChromeClient = null
                    view.webViewClient = object : WebViewClient() {}
                    (view.parent as? ViewGroup)?.removeView(view)
                    view.destroy()
                }
            }
            previewWebView = null
        }
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        dialog.show()
        dialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setLayout(
                (resources.displayMetrics.widthPixels * .92f).toInt(),
                WindowManager.LayoutParams.WRAP_CONTENT,
            )
            addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            setDimAmount(.42f)
        }

        val previewBackground = cssColor(pageBg)
        val previewForeground = cssColor(primaryText)
        when (kind) {
            "image" -> preview.loadDataWithBaseURL(
                currentUrl,
                "<html><meta name='viewport' content='width=device-width,initial-scale=1'><body style='margin:0;background:$previewBackground;display:flex;align-items:center;justify-content:center;min-height:100vh'><img src='${android.text.TextUtils.htmlEncode(target)}' style='max-width:100%;max-height:100vh;object-fit:contain'></body></html>",
                "text/html", "UTF-8", null
            )
            "video" -> preview.loadDataWithBaseURL(
                currentUrl,
                "<html><meta name='viewport' content='width=device-width,initial-scale=1'><body style='margin:0;background:$previewBackground;display:flex;align-items:center;justify-content:center;min-height:100vh'><video src='${android.text.TextUtils.htmlEncode(target)}' controls playsinline style='max-width:100%;max-height:100vh'></video></body></html>",
                "text/html", "UTF-8", null
            )
            "audio" -> preview.loadDataWithBaseURL(
                currentUrl,
                "<html><meta name='viewport' content='width=device-width,initial-scale=1'><body style='margin:0;background:$previewBackground;color:$previewForeground;display:flex;align-items:center;justify-content:center;min-height:100vh'><audio src='${android.text.TextUtils.htmlEncode(target)}' controls></audio></body></html>",
                "text/html", "UTF-8", null
            )
            else -> preview.loadUrl(target)
        }
    }

    private fun shareRemoteImage(imageUrl: String) {
        if (!isSafeWebUrl(imageUrl)) return
        showBrowserSnackbar(localizedBrowserText("A preparar imagem para partilhar…", "Preparing image to share…"))
        val userAgent = runCatching { webView.settings.userAgentString }.getOrDefault("BrowseIt Android")
        val referringPageUrl = currentUrl
        Thread {
            var tempFile: File? = null
            var mimeType = "image/*"
            var connection: HttpURLConnection? = null
            try {
                val activeConnection = URL(imageUrl).openConnection() as HttpURLConnection
                connection = activeConnection
                activeConnection.connectTimeout = 8_000
                activeConnection.readTimeout = 12_000
                activeConnection.instanceFollowRedirects = true
                activeConnection.setRequestProperty("User-Agent", userAgent)
                activeConnection.setRequestProperty("Referer", referringPageUrl)
                CookieManager.getInstance().getCookie(imageUrl)?.takeIf { it.isNotBlank() }?.let {
                    activeConnection.setRequestProperty("Cookie", it)
                }
                activeConnection.connect()
                if (activeConnection.responseCode !in 200..299) {
                    throw IllegalStateException("Image response ${activeConnection.responseCode}")
                }
                mimeType = activeConnection.contentType?.substringBefore(';')
                    ?.takeIf { it.startsWith("image/") }
                    ?: throw IllegalStateException("Not an image")
                val directory = File(cacheDir, "shared_media").apply { mkdirs() }
                val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
                    ?.take(8) ?: "img"
                val outputFile = File(directory, "browseit_${System.currentTimeMillis()}.$extension")
                tempFile = outputFile
                activeConnection.inputStream.use { input ->
                    outputFile.outputStream().use { output ->
                        val buffer = ByteArray(16 * 1024)
                        var total = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            if (total > 20L * 1024L * 1024L) {
                                throw IllegalStateException("Image exceeds share limit")
                            }
                            output.write(buffer, 0, count)
                        }
                    }
                }
            } catch (_: Exception) {
                tempFile?.delete()
                runOnUiThread {
                    showBrowserSnackbar(localizedBrowserText(
                        "Não foi possível preparar a imagem.",
                        "Could not prepare the image."
                    ))
                }
                return@Thread
            } finally {
                connection?.disconnect()
            }

            val completedFile = tempFile ?: return@Thread
            runOnUiThread {
                try {
                    val contentUri = FileProvider.getUriForFile(this, "$packageName.fileprovider", completedFile)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, contentUri)
                        clipData = ClipData.newUri(contentResolver, "BrowseIt image", contentUri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(send, localizedBrowserText("Partilhar imagem", "Share image")))
                } catch (_: Exception) {
                    showBrowserSnackbar(localizedBrowserText("Não foi possível partilhar a imagem.", "Could not share the image."))
                }
            }
        }.start()
    }

    private fun shareRemoteMedia(mediaUrl: String, fallbackMime: String) {
        if (!isSafeWebUrl(mediaUrl)) return
        showBrowserSnackbar(localizedBrowserText("A preparar conteúdo para partilhar…", "Preparing media to share…"))
        val userAgent = runCatching { webView.settings.userAgentString }.getOrDefault("BrowseIt Android")
        val referringPageUrl = currentUrl
        Thread {
            var tempFile: File? = null
            var mimeType = fallbackMime
            var connection: HttpURLConnection? = null
            try {
                val activeConnection = URL(mediaUrl).openConnection() as HttpURLConnection
                connection = activeConnection
                activeConnection.connectTimeout = 8_000
                activeConnection.readTimeout = 15_000
                activeConnection.instanceFollowRedirects = true
                activeConnection.setRequestProperty("User-Agent", userAgent)
                activeConnection.setRequestProperty("Referer", referringPageUrl)
                CookieManager.getInstance().getCookie(mediaUrl)?.takeIf { it.isNotBlank() }?.let {
                    activeConnection.setRequestProperty("Cookie", it)
                }
                activeConnection.connect()
                if (activeConnection.responseCode !in 200..299) {
                    throw IllegalStateException("Media response ${activeConnection.responseCode}")
                }
                val responseMime = activeConnection.contentType?.substringBefore(';')?.trim().orEmpty()
                if (responseMime.startsWith("video/") || responseMime.startsWith("audio/")) {
                    mimeType = responseMime
                }
                val directory = File(cacheDir, "shared_media").apply { mkdirs() }
                val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
                    ?.take(8) ?: if (fallbackMime.startsWith("video")) "mp4" else "audio"
                val outputFile = File(directory, "browseit_media_${System.currentTimeMillis()}.$extension")
                tempFile = outputFile
                activeConnection.inputStream.use { input ->
                    outputFile.outputStream().use { output ->
                        val buffer = ByteArray(16 * 1024)
                        var total = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            // Share actions are intentionally bounded. Larger
                            // streams can still be shared safely as a URL.
                            if (total > 50L * 1024L * 1024L) {
                                throw IllegalStateException("Media exceeds share limit")
                            }
                            output.write(buffer, 0, count)
                        }
                    }
                }
            } catch (_: Exception) {
                tempFile?.delete()
                runOnUiThread {
                    showBrowserSnackbar(localizedBrowserText(
                        "Não foi possível preparar o ficheiro. Partilha a ligação do conteúdo.",
                        "Could not prepare the file. Share the media link instead."
                    ))
                }
                return@Thread
            } finally {
                connection?.disconnect()
            }

            val completedFile = tempFile ?: return@Thread
            runOnUiThread {
                try {
                    val contentUri = FileProvider.getUriForFile(this, "$packageName.fileprovider", completedFile)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, contentUri)
                        clipData = ClipData.newUri(contentResolver, "BrowseIt media", contentUri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(
                        send,
                        localizedBrowserText("Partilhar conteúdo", "Share media")
                    ))
                } catch (_: Exception) {
                    completedFile.delete()
                    showBrowserSnackbar(localizedBrowserText("Não foi possível partilhar o conteúdo.", "Could not share the media."))
                }
            }
        }.start()
    }

    private fun savePageOffline() {
        val directory = File(filesDir, "offline_pages").apply { mkdirs() }
        val safeName = (hostOf(currentUrl).replace(Regex("[^A-Za-z0-9._-]"), "_") + "_" + System.currentTimeMillis())
        val path = File(directory, "$safeName.mht").absolutePath
        webView.saveWebArchive(path, true) { saved ->
            runOnUiThread {
                showBrowserSnackbar(
                    if (saved.isNullOrBlank()) localizedBrowserText("Não foi possível guardar a página.", "Could not save page.")
                    else localizedBrowserText("Página guardada para leitura offline.", "Page saved for offline reading.")
                )
            }
        }
    }

    private fun togglePageImages() {
        imagesEnabled = !webView.settings.loadsImagesAutomatically
        webView.settings.loadsImagesAutomatically = imagesEnabled
        webView.reload()
    }

    private fun togglePageJavaScript() {
        webView.settings.javaScriptEnabled = !webView.settings.javaScriptEnabled
        webView.reload()
        showBrowserSnackbar(
            if (webView.settings.javaScriptEnabled) localizedBrowserText("JavaScript ativado", "JavaScript enabled")
            else localizedBrowserText("JavaScript desativado", "JavaScript disabled")
        )
    }

    private fun showPageSource() {
        webView.evaluateJavascript("(function(){return document.documentElement ? document.documentElement.outerHTML : '';})();") { raw ->
            val source = runCatching {
                org.json.JSONTokener(raw ?: "\"\"").nextValue() as? String
            }.getOrNull().orEmpty()
            val display = source.take(80_000).ifBlank { "(empty document)" }
            val body = TextView(this).apply {
                text = display
                textSize = 11f
                typeface = android.graphics.Typeface.MONOSPACE
                setTextColor(primaryText)
                setPadding(dp(16), dp(16), dp(16), dp(16))
                setTextIsSelectable(true)
            }
            val scroll = ScrollView(this).apply { addView(body) }
            MaterialAlertDialogBuilder(this)
                .setTitle(localizedBrowserText("Código-fonte da página", "Page source"))
                .setView(scroll)
                .setPositiveButton(menuText("close", "Close"), null)
                .show()
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

    private fun buildDesktopUserAgent(): String {
        val mobileAgent = originalUserAgent ?: WebSettings.getDefaultUserAgent(this)
        return mobileAgent
            .replace(Regex("\\(Linux; Android [^)]+\\)"), "(Windows NT 10.0; Win64; x64)")
            .replace(" Mobile", "")
    }

    private fun toggleDesktopMode() {
        desktopMode = !desktopMode
        webView.settings.userAgentString = if (desktopMode) {
            buildDesktopUserAgent()
        } else {
            originalUserAgent ?: WebSettings.getDefaultUserAgent(this)
        }
        webView.settings.useWideViewPort = true
        webView.settings.loadWithOverviewMode = desktopMode
        webView.settings.setSupportZoom(true)
        webView.settings.builtInZoomControls = true
        webView.settings.displayZoomControls = false
        if (desktopMode) {
            webView.clearCache(false)
            webView.evaluateJavascript(DESKTOP_VIEWPORT_SCRIPT, null)
        }
        webView.reload()
        showBrowserSnackbar(
            if (desktopMode) menuText("desktopEnabled", "Desktop site enabled")
            else menuText("desktopDisabled", "Desktop site disabled")
        )
    }

    private fun translatePage() {
        val targetLanguage = menuLabels.optString("targetLanguage", "en")
            .lowercase(Locale.ROOT)
            .takeIf { it.matches(Regex("^[a-z]{2,3}(?:-[a-z]{2})?$")) } ?: "en"
        showBrowserSnackbar(localizedBrowserText("A traduzir o texto da página…", "Translating page text…"))
        val collectScript = """
            (() => {
              const rejected = 'script,style,noscript,svg,canvas,iframe,textarea,input,select,option,code,pre,[contenteditable="true"]';
              const walker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT);
              const nodes = [];
              let node;
              while ((node = walker.nextNode()) && nodes.length < 2500) {
                const parent = node.parentElement;
                if (!parent || parent.closest(rejected)) continue;
                const style = getComputedStyle(parent);
                if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) continue;
                const value = node.nodeValue || '';
                const text = value.trim();
                if (text.length < 2 || !/[\p{L}]/u.test(text)) continue;
                const leading = (value.match(/^\s*/) || [''])[0];
                const trailing = (value.match(/\s*$/) || [''])[0];
                nodes.push({i: nodes.length, text: text, leading: leading, trailing: trailing});
              }
              window.__looplyTranslationNodes = [];
              const secondWalker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT);
              let index = 0, current;
              while ((current = secondWalker.nextNode()) && index < nodes.length) {
                const parent = current.parentElement;
                if (!parent || parent.closest(rejected)) continue;
                const value = current.nodeValue || '', text = value.trim();
                if (text.length < 2 || !/[\p{L}]/u.test(text)) continue;
                const style = getComputedStyle(parent);
                if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) continue;
                window.__looplyTranslationNodes[index++] = current;
              }
              return JSON.stringify(nodes);
            })();
        """.trimIndent()
        webView.evaluateJavascript(collectScript) { raw ->
            val encoded = runCatching { org.json.JSONTokener(raw ?: "null").nextValue() as? String }.getOrNull()
            val nodes = runCatching { org.json.JSONArray(encoded ?: "[]") }.getOrNull()
            if (nodes == null || nodes.length() == 0) {
                showBrowserSnackbar(localizedBrowserText("Não há texto para traduzir nesta página.", "No page text was found to translate."))
                return@evaluateJavascript
            }

            data class TranslationNode(
                val index: Int,
                val text: String,
                val leading: String,
                val trailing: String,
            )

            val pending = ArrayList<TranslationNode>(nodes.length())
            for (index in 0 until nodes.length()) {
                val item = nodes.optJSONObject(index) ?: continue
                val original = item.optString("text")
                if (original.isBlank()) continue
                pending.add(
                    TranslationNode(
                        index = index,
                        text = original,
                        leading = item.optString("leading"),
                        trailing = item.optString("trailing"),
                    )
                )
            }

            Thread {
                var translatedCount = 0
                var failedCount = 0
                var cursor = 0
                while (cursor < pending.size) {
                    val batch = ArrayList<TranslationNode>(8)
                    var characterCount = 0
                    while (cursor < pending.size && batch.size < 8) {
                        val candidate = pending[cursor]
                        val addedLength = candidate.text.length + 36
                        if (batch.isNotEmpty() && characterCount + addedLength > 3_200) break
                        batch.add(candidate)
                        characterCount += addedLength
                        cursor++
                    }

                    val translations = translateBatchWithFreeEndpoint(
                        batch.map { it.text },
                        targetLanguage,
                    ) ?: batch.map { translateTextWithFreeEndpoint(it.text, targetLanguage) }

                    val assignments = org.json.JSONArray()
                    for (batchIndex in batch.indices) {
                        val translated = translations.getOrNull(batchIndex)
                        if (translated.isNullOrBlank()) {
                            failedCount++
                            continue
                        }
                        val entry = batch[batchIndex]
                        assignments.put(
                            org.json.JSONObject()
                                .put("i", entry.index)
                                .put("v", entry.leading + translated + entry.trailing)
                        )
                        translatedCount++
                    }

                    if (assignments.length() > 0) {
                        val script = """
                            (function(items){
                              if (!window.__looplyTranslationNodes) return;
                              for (var i = 0; i < items.length; i++) {
                                var item = items[i];
                                var node = window.__looplyTranslationNodes[item.i];
                                if (node && node.isConnected) node.nodeValue = item.v;
                              }
                            })(${assignments.toString()});
                        """.trimIndent()
                        runOnUiThread {
                            if (!isFinishing && !isDestroyed) webView.evaluateJavascript(script, null)
                        }
                    }
                    Thread.sleep(100)
                }

                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        val message = when {
                            translatedCount == 0 -> localizedBrowserText(
                                "Não foi possível traduzir a página. Tente novamente.",
                                "The page could not be translated. Try again.",
                            )
                            failedCount > 0 -> localizedBrowserText(
                                "Tradução parcial: $translatedCount blocos traduzidos; $failedCount não foram traduzidos.",
                                "Partial translation: $translatedCount blocks translated; $failedCount failed.",
                            )
                            else -> localizedBrowserText(
                                "Tradução concluída ($translatedCount blocos).",
                                "Translation completed ($translatedCount text blocks).",
                            )
                        }
                        showBrowserSnackbar(message)
                    }
                }
            }.start()
        }
    }

    private fun translateBatchWithFreeEndpoint(texts: List<String>, targetLanguage: String): List<String>? {
        if (texts.isEmpty()) return emptyList()
        if (texts.size == 1) {
            val single = translateTextWithFreeEndpoint(texts.first(), targetLanguage) ?: return null
            return listOf(single)
        }

        val markers = (0 until texts.lastIndex).map { index -> "\uE000L${index}\uE001" }
        val query = buildString {
            texts.forEachIndexed { index, text ->
                append(text.take(4_500))
                if (index < markers.size) {
                    append(' ')
                    append(markers[index])
                    append(' ')
                }
            }
        }
        val translated = requestFreeTranslation(query, targetLanguage) ?: return null
        val pieces = translated.split(*markers.toTypedArray())
        if (pieces.size != texts.size) return null
        return pieces.map { it.trim() }
    }

    private fun translateTextWithFreeEndpoint(text: String, targetLanguage: String): String? =
        requestFreeTranslation(text.take(4_500), targetLanguage)

    /** Uses Google's public web translation endpoint; it is free to access but undocumented. */
    private fun requestFreeTranslation(text: String, targetLanguage: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            val url = URL(
                "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" +
                    Uri.encode(targetLanguage) + "&dt=t&q=" + Uri.encode(text)
            )
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 7_000
            connection.readTimeout = 9_000
            connection.requestMethod = "GET"
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/142.0.0.0 Mobile Safari/537.36")
            connection.instanceFollowRedirects = true
            if (connection.responseCode !in 200..299) return null
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val root = org.json.JSONArray(body)
            val segments = root.optJSONArray(0) ?: return null
            buildString {
                for (i in 0 until segments.length()) {
                    append(segments.optJSONArray(i)?.optString(0).orEmpty())
                }
            }.takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
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
            LinearLayout.LayoutParams(dp(24), dp(24)).apply {
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

    private fun statusBarInsetPx(): Int {
        val insets = ViewCompat.getRootWindowInsets(root)
        return insets?.getInsets(WindowInsetsCompat.Type.statusBars())?.top ?: dp(24)
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
        val dialog = looplyMaterialDialogBuilder()
            .setTitle(menuText("siteInfo", "Site information"))
            .setMessage("${currentTitle.ifBlank { host }}\n\n$currentUrl")
            .setPositiveButton(menuText("close", "Close"), null)
            .create()
        dialog.show()
        applyLooplyDialogDim(dialog)
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

    private fun openCurrentPageExternally() {
        if (!isSafeWebUrl(currentUrl)) return
        try {
            startActivity(Intent.createChooser(
                Intent(Intent.ACTION_VIEW, Uri.parse(currentUrl)),
                localizedBrowserText("Abrir com", "Open with"),
            ))
        } catch (_: Exception) {
            showBrowserSnackbar(localizedBrowserText("Não existe uma aplicação compatível.", "No compatible app is available."))
        }
    }

    private fun copyCleanCurrentUrl() {
        val uri = runCatching { Uri.parse(currentUrl) }.getOrNull() ?: return
        val trackingKeys = setOf("fbclid", "gclid", "dclid", "_ga", "_gl", "mc_cid", "mc_eid", "ref", "ref_src", "source")
        val builder = uri.buildUpon().clearQuery()
        uri.queryParameterNames.forEach { key ->
            val normalized = key.lowercase(Locale.ROOT)
            if (normalized.startsWith("utm_") || normalized in trackingKeys) return@forEach
            uri.getQueryParameters(key).forEach { value -> builder.appendQueryParameter(key, value) }
        }
        copyText(builder.build().toString())
    }

    private fun showReaderMode() {
        val extractor = """
            (() => {
              const candidates = Array.from(document.querySelectorAll('article,main,[role="main"]'));
              const root = candidates.sort((a,b) => (b.innerText || '').length - (a.innerText || '').length)[0] || document.body;
              if (!root) return JSON.stringify({title:document.title || '',text:''});
              const clone = root.cloneNode(true);
              clone.querySelectorAll('script,style,nav,header,footer,form,button,iframe,video,audio,[hidden],[aria-hidden="true"]').forEach(n => n.remove());
              const text = (clone.innerText || clone.textContent || '').replace(/\n{3,}/g,'\n\n').trim();
              return JSON.stringify({title:document.title || '',text:text.slice(0,60000)});
            })();
        """.trimIndent()
        webView.evaluateJavascript(extractor) { raw ->
            val payload = runCatching {
                val encoded = org.json.JSONTokener(raw ?: "null").nextValue() as? String
                encoded?.let(::JSONObject)
            }.getOrNull()
            val article = payload?.optString("text").orEmpty()
            if (article.isBlank()) {
                showBrowserSnackbar(localizedBrowserText("Não foi possível extrair o texto principal.", "Could not extract the main text."))
                return@evaluateJavascript
            }
            val title = payload?.optString("title")?.takeIf { it.isNotBlank() } ?: hostOf(currentUrl)
            val content = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(20), dp(18), dp(20), dp(20))
                background = rounded(pageBg, 24)
            }
            content.addView(TextView(this).apply {
                text = title
                textSize = 20f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                setTextColor(primaryText)
            }, LinearLayout.LayoutParams(-1, -2))
            content.addView(TextView(this).apply {
                text = hostOf(currentUrl)
                textSize = 12f
                setTextColor(secondaryText)
                setPadding(0, dp(4), 0, dp(14))
            }, LinearLayout.LayoutParams(-1, -2))
            val body = TextView(this).apply {
                text = article
                textSize = 16f
                setTextColor(primaryText)
                setLineSpacing(dp(4).toFloat(), 1f)
                setTextIsSelectable(true)
            }
            content.addView(ScrollView(this).apply {
                overScrollMode = View.OVER_SCROLL_NEVER
                addView(body, ViewGroup.LayoutParams(-1, -2))
            }, LinearLayout.LayoutParams(-1, dp(500)))
            val dialog = BottomSheetDialog(this)
            dialog.setContentView(content)
            dialog.show()
            dialog.behavior.state = BottomSheetBehavior.STATE_EXPANDED
        }
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

    private fun isBlocked(uri: Uri, request: WebResourceRequest? = null): Boolean {
        val host = uri.host?.lowercase(Locale.ROOT)?.trimEnd('.') ?: return false

        if (blockedDomains.any { host == it || host.endsWith(".$it") }) return true
        if (adBlockRules.shouldBlock(uri, currentUrl, request)) return true

        val labels = host.split('.').flatMap { it.split('-') }
        if (labels.any { it in blockedHostLabels }) return true

        return adPathPattern.containsMatchIn(uri.encodedPath.orEmpty())
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

        val fallback = runCatching {
            val uri = Uri.parse(currentUrl)
            uri.host?.removePrefix("www.")?.ifBlank { currentUrl } ?: currentUrl
        }.getOrDefault(currentUrl)

        titleView.text = currentTitle.trim().ifBlank { fallback.ifBlank { "BrowseIt" } }
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
            tintHomeButton(toolbarText())
            applySystemBars()
            return
        }

        tintHomeButton(toolbarText())
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
                tintHomeButton(toolbarText())
            }
        }
    }

    private fun tintHomeButton(color: Int) {
        if (::homeButtonIcon.isInitialized) homeButtonIcon.setTextColor(color)
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
        // Sobre barras claras, escurece ligeiramente o pill (branco -> cinza
        // muito claro). Sobre barras escuras, clareia-o para criar separação.
        val neutral = if (isLight(base)) Color.BLACK else Color.WHITE
        val fraction = if (isLight(base)) .055f else .12f
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

        if (webView.parent == null) {
            swipeRefreshLayout.addView(webView, ViewGroup.LayoutParams(-1, -1))
        }
        if (swipeRefreshLayout.parent == null) {
            root.addView(swipeRefreshLayout, LinearLayout.LayoutParams(-1, 0, 1f))
        }

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
                if (action == "tabs" || action == "home") fullScreenshot else null,
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
        when (action) {
            "tabs" -> overridePendingTransition(0, 0)
            else -> overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
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

                val full = encodeScreenshot(bitmap, 72)
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
                val pageBytes = page?.let { encodeScreenshot(it, 68) }
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
                bitmap.compress(Bitmap.CompressFormat.JPEG, 72, stream)
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
                bitmap.compress(Bitmap.CompressFormat.JPEG, 68, stream)
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

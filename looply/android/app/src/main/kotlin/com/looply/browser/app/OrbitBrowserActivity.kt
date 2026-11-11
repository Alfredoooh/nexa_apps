package com.looply.browser.app

import android.animation.ValueAnimator
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.view.inputmethod.EditorInfo
import android.webkit.CookieManager
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.widget.PopupMenu
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import com.google.android.material.bottomsheet.BottomSheetDialog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.URLEncoder
import kotlin.math.roundToInt

/**
 * BrowseIt Browser — 100% Kotlin, sem InAppWebView, sem PlatformView Flutter.
 * Substitui o antigo OrbitBrowserScreen.dart. Cada separador aberto lança uma
 * instância desta Activity; ao fechar, o estado do separador (url, título,
 * histórico de navegação, miniatura) é devolvido à MainActivity via
 * setResult(), que por sua vez devolve ao Dart através do canal
 * looply/orbit_browser (ver MainActivity.onActivityResult).
 *
 * Paleta, dimensões e comportamento do pill de endereço/progress bar/
 * toolbar escondendo ao scroll replicam deliberadamente os valores de
 * theme.dart e do antigo OrbitBrowserScreen.dart, para a conversão para
 * Kotlin não mudar o visual da app para quem usa o BrowseIt.
 */
class OrbitBrowserActivity : Activity() {

    companion object {
        const val EXTRA_TAB_ID = "com.looply.browser.app.extra.ORBIT_TAB_ID"
        const val EXTRA_URL = "com.looply.browser.app.extra.ORBIT_URL"
        const val EXTRA_TITLE = "com.looply.browser.app.extra.ORBIT_TITLE"
        const val EXTRA_IS_INCOGNITO = "com.looply.browser.app.extra.ORBIT_IS_INCOGNITO"

        const val RESULT_TAB_ID = "result_tab_id"
        const val RESULT_URL = "result_url"
        const val RESULT_TITLE = "result_title"
        const val RESULT_CAN_GO_BACK = "result_can_go_back"
        const val RESULT_CAN_GO_FORWARD = "result_can_go_forward"
        const val RESULT_THUMBNAIL = "result_thumbnail"
        const val RESULT_REQUESTED_ACTION = "result_requested_action"
        const val RESULT_REQUESTED_ACTION_VALUE = "result_requested_action_value"

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_THEME_MODE = "flutter.looply_theme_mode"
        private const val PREF_PURE_BLACK = "flutter.looply_theme_pure_dark"
        private const val PREF_AD_BLOCK_ENABLED = "flutter.looply_ad_block_enabled"
        private const val PREF_NAV_ACCELERATOR = "flutter.looply_navigation_accelerator_enabled"
        private const val PREF_FORCE_DARK_SITES = "flutter.looply_force_dark_websites_enabled"
        private const val PREF_SITE_THEME_FOLLOWS_APP = "flutter.looply_site_theme_follows_app_enabled"
        private const val PREF_ADAPTIVE_TOOLBAR = "flutter.looply_adaptive_toolbar_color_enabled"
        private const val PREF_APP_LANGUAGE = "flutter.looply_app_language_code"

        private const val STATE_WEB_VIEW = "orbit_browser_web_view_state"
        private const val STATE_URL = "orbit_browser_url"
        private const val STATE_TITLE = "orbit_browser_title"
        private const val STATE_DESKTOP_SITE = "orbit_browser_desktop_site"
        private const val STATE_ZOOM = "orbit_browser_zoom"

        private const val DESKTOP_USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    }

    // ------------------------------------------------------------------
    // Estado
    // ------------------------------------------------------------------

    private lateinit var tabId: String
    private var isIncognito: Boolean = false

    private lateinit var rootLayout: LinearLayout
    private lateinit var statusBarSpacer: View
    private lateinit var toolbarContainer: FrameLayout
    private lateinit var toolbarContent: LinearLayout
    private lateinit var progressBar: ProgressBar
    private lateinit var webViewContainer: FrameLayout
    private lateinit var swipeRefresh: SwipeRefreshLayout
    private lateinit var webView: WebView
    private lateinit var errorOverlay: FrameLayout

    private lateinit var homeButton: FrameLayout
    private lateinit var titlePill: LinearLayout
    private lateinit var pillFaviconView: ImageViewPlaceholder
    private lateinit var pillTitleView: TextView
    private lateinit var tabsButton: FrameLayout
    private lateinit var tabsCountView: TextView
    private lateinit var moreButton: FrameLayout

    private lateinit var findBar: LinearLayout
    private lateinit var findField: EditText
    private lateinit var findPrevButton: FrameLayout
    private lateinit var findNextButton: FrameLayout
    private lateinit var findCloseButton: FrameLayout

    private var backButtonIcon: TextView? = null
    private var forwardButtonIcon: TextView? = null

    private var currentUrl: String = ""
    private var currentTitle: String = ""
    private var canGoBackState = false
    private var canGoForwardState = false
    private var desktopSiteRequested = false
    private var pageZoomFactor = 1.0
    private var isFindInPage = false
    private var renderProcessCrashed = false
    private var loadError: String? = null
    private var isLoading = true
    private var showProgress = true
    private var siteToolbarColor: Int? = null
    private var currentFaviconBitmap: Bitmap? = null

    private var toolbarVisibility = 1f
    private var lastScrollY = 0
    private var hasScrollBaseline = false

    private val mainScope = CoroutineScope(Dispatchers.Main)
    private var findDebounceJob: Job? = null
    private var progressHideJob: Job? = null

    private val appPreferences: SharedPreferences by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private var filePathCallback: ValueCallback<Array<Uri>>? = null

    // ------------------------------------------------------------------
    // Cores — mesmos valores de theme.dart (looplyBgDark/Light,
    // looplyPanelDark/Light, looplyPanel2Dark/Light, looplyTextDark/Light,
    // looplyMutedDark/Light, looplyBlueDark, looplyPrimary, looplyBgAmoled,
    // looplyPanelAmoled, looplyPanel2Amoled).
    // ------------------------------------------------------------------

    private val isDark: Boolean by lazy {
        when (appPreferences.getString(PREF_THEME_MODE, "system") ?: "system") {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
    }

    private val isPureBlack: Boolean by lazy {
        appPreferences.getBoolean(PREF_PURE_BLACK, false)
    }

    private val pageBg: Int
        get() = when {
            !isDark -> Color.WHITE
            isPureBlack -> Color.BLACK
            else -> Color.rgb(20, 21, 23) // looplyBgDark 0xFF141517
        }

    private val panelColor: Int
        get() = when {
            !isDark -> Color.WHITE
            isPureBlack -> Color.rgb(16, 16, 16) // looplyPanelAmoled
            else -> Color.rgb(33, 35, 37) // looplyPanelDark
        }

    private val pillColorValue: Int
        get() = when {
            !isDark -> Color.rgb(240, 241, 243) // looplyPanel2Light
            isPureBlack -> Color.rgb(25, 25, 25) // looplyPanel2Amoled
            else -> Color.rgb(43, 45, 48) // looplyPanel2Dark
        }

    private val mainTextColor: Int
        get() = if (isDark) Color.rgb(230, 230, 232) else Color.rgb(32, 33, 36)

    private val mutedTextColor: Int
        get() = if (isDark) Color.rgb(178, 180, 184) else Color.rgb(95, 99, 104)

    private val accentColorValue: Int
        get() = if (isDark) Color.rgb(138, 180, 248) else Color.rgb(26, 115, 232)

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        tabId = intent.getStringExtra(EXTRA_TAB_ID) ?: run {
            finish()
            return
        }
        isIncognito = intent.getBooleanExtra(EXTRA_IS_INCOGNITO, false)
        currentUrl = savedInstanceState?.getString(STATE_URL)
            ?: intent.getStringExtra(EXTRA_URL)
            ?: "https://www.google.com"
        currentTitle = savedInstanceState?.getString(STATE_TITLE)
            ?: intent.getStringExtra(EXTRA_TITLE)
            ?: ""
        desktopSiteRequested = savedInstanceState?.getBoolean(STATE_DESKTOP_SITE) ?: false
        pageZoomFactor = (savedInstanceState?.getDouble(STATE_ZOOM) ?: 1.0)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        applySystemBars()

        buildUi()
        setContentView(rootLayout)

        val restored = savedInstanceState?.getBundle(STATE_WEB_VIEW)?.let { state ->
            webView.restoreState(state) != null
        } ?: false
        if (!restored) {
            loadAddress(currentUrl, pushToField = true)
        } else {
            updatePillTitle()
        }
        updateNavigationButtonStates()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        val webState = Bundle()
        webView.saveState(webState)
        outState.putBundle(STATE_WEB_VIEW, webState)
        outState.putString(STATE_URL, currentUrl)
        outState.putString(STATE_TITLE, currentTitle)
        outState.putBoolean(STATE_DESKTOP_SITE, desktopSiteRequested)
        outState.putDouble(STATE_ZOOM, pageZoomFactor)
    }

    override fun onDestroy() {
        findDebounceJob?.cancel()
        progressHideJob?.cancel()
        mainScope.cancel()
        webView.stopLoading()
        webView.webChromeClient = null
        webView.webViewClient = object : WebViewClient() {}
        (webView.parent as? ViewGroup)?.removeView(webView)
        webView.destroy()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Android API 33; still used on older Android versions")
    override fun onBackPressed() {
        if (isFindInPage) {
            exitFindInPage()
            return
        }
        if (!renderProcessCrashed && webView.canGoBack()) {
            webView.goBack()
            return
        }
        finishWithoutAction()
    }

    // ------------------------------------------------------------------
    // Construção da UI
    // ------------------------------------------------------------------

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()
    private fun dpF(value: Float): Int = (value * resources.displayMetrics.density).roundToInt()

    private fun buildUi() {
        rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(pageBg)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        statusBarSpacer = View(this).apply {
            setBackgroundColor(pageBg)
        }
        rootLayout.addView(
            statusBarSpacer,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0),
        )

        buildToolbar()
        rootLayout.addView(
            toolbarContainer,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dpF(42.4f)),
        )

        buildWebViewArea()
        rootLayout.addView(
            webViewContainer,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f),
        )

        ViewCompat.setOnApplyWindowInsetsListener(rootLayout) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            statusBarSpacer.layoutParams = statusBarSpacer.layoutParams.apply {
                height = bars.top
            }
            webViewContainer.setPadding(0, 0, 0, maxOf(bars.bottom, ime.bottom))
            insets
        }
    }

    private fun buildToolbar() {
        toolbarContainer = FrameLayout(this).apply {
            setBackgroundColor(pageBg)
        }

        toolbarContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(4), 0, dp(4), 0)
        }

        homeButton = iconButton("⌂") { requestGoHome() }
        row.addView(homeButton, LinearLayout.LayoutParams(dp(42), dp(42)))

        titlePill = buildTitlePill()
        findBar = buildFindBar()
        findBar.visibility = View.GONE

        val pillHost = FrameLayout(this)
        pillHost.addView(titlePill, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))
        pillHost.addView(findBar, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))
        row.addView(pillHost, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginStart = dp(5)
            marginEnd = dp(5)
        })

        val actionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        tabsButton = buildTabsButton()
        moreButton = iconButton("⋮") { showBrowserOptionsSheet() }
        actionsRow.addView(tabsButton, LinearLayout.LayoutParams(dp(42), dp(42)))
        actionsRow.addView(moreButton, LinearLayout.LayoutParams(dp(42), dp(42)))
        row.addView(actionsRow)

        toolbarContent.addView(row, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(40),
        ))

        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 1000
            progress = 0
            progressTintList = ColorStateList.valueOf(accentColorValue)
            progressBackgroundTintList = ColorStateList.valueOf(Color.TRANSPARENT)
        }
        toolbarContent.addView(progressBar, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dpF(2.4f),
        ))

        toolbarContainer.addView(toolbarContent, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
        ))
    }

    private fun iconButton(glyph: String, onTap: () -> Unit): FrameLayout {
        return FrameLayout(this).apply {
            isClickable = true
            isFocusable = true
            foreground = rippleDrawable()
            val label = TextView(this@OrbitBrowserActivity).apply {
                text = glyph
                gravity = Gravity.CENTER
                textSize = 20f
                setTextColor(mainTextColor)
            }
            addView(label, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
            ))
            setOnClickListener { onTap() }
        }
    }

    private fun rippleDrawable(): android.graphics.drawable.Drawable {
        val outValue = android.util.TypedValue()
        theme.resolveAttribute(android.R.attr.selectableItemBackgroundBorderless, outValue, true)
        return resources.getDrawable(outValue.resourceId, theme)
    }

    private fun buildTitlePill(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            isClickable = true
            isFocusable = true
            background = pillBackground(pillColorValue)
            setPadding(dp(12), 0, dp(12), 0)
            val favicon = ImageViewPlaceholder(this@OrbitBrowserActivity).apply {
                layoutParams = LinearLayout.LayoutParams(dp(19), dp(19))
            }
            pillFaviconView = favicon
            addView(favicon)
            val spacer = View(this@OrbitBrowserActivity)
            addView(spacer, LinearLayout.LayoutParams(dp(9), 1))
            val title = TextView(this@OrbitBrowserActivity).apply {
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.END
                textSize = 14f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(mainTextColor)
            }
            pillTitleView = title
            addView(title, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(40),
            )
            setOnClickListener { openSearchScreen() }
        }
    }

    private fun buildFindBar(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(40),
            )
            findField = EditText(this@OrbitBrowserActivity).apply {
                setSingleLine(true)
                textSize = 14f
                setTextColor(mainTextColor)
                setHintTextColor(mutedTextColor)
                hint = "Pesquisar na página"
                background = null
                imeOptions = EditorInfo.IME_ACTION_SEARCH
                setOnEditorActionListener { _, actionId, _ ->
                    if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                        moveFindResult(true)
                        true
                    } else false
                }
                addTextChangedListener(object : android.text.TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                        onFindTextChanged(s?.toString().orEmpty())
                    }
                    override fun afterTextChanged(s: android.text.Editable?) {}
                })
            }
            addView(findField, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f))
            findPrevButton = iconButton("‹") { moveFindResult(false) }
            findNextButton = iconButton("›") { moveFindResult(true) }
            findCloseButton = iconButton("✕") { exitFindInPage() }
            addView(findPrevButton, LinearLayout.LayoutParams(dp(36), dp(36)))
            addView(findNextButton, LinearLayout.LayoutParams(dp(36), dp(36)))
            addView(findCloseButton, LinearLayout.LayoutParams(dp(36), dp(36)))
        }
    }

    private fun buildTabsButton(): FrameLayout {
        return FrameLayout(this).apply {
            isClickable = true
            isFocusable = true
            foreground = rippleDrawable()
            val badge = TextView(this@OrbitBrowserActivity).apply {
                text = "1"
                gravity = Gravity.CENTER
                textSize = 9.5f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(mainTextColor)
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dpF(8f).toFloat()
                    setStroke(dpF(1.5f), mainTextColor)
                    setColor(Color.TRANSPARENT)
                }
            }
            tabsCountView = badge
            addView(badge, FrameLayout.LayoutParams(dp(20), dp(20), Gravity.CENTER))
            setOnClickListener { requestOpenTabsGrid() }
        }
    }

    private fun pillBackground(color: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(22).toFloat()
            setColor(color)
        }
    }

    private fun buildWebViewArea() {
        webViewContainer = FrameLayout(this)

        errorOverlay = FrameLayout(this).apply {
            visibility = View.GONE
            setBackgroundColor(pageBg)
        }

        swipeRefresh = SwipeRefreshLayout(this).apply {
            setColorSchemeColors(accentColorValue)
            setOnRefreshListener {
                if (::webView.isInitialized) webView.reload() else isRefreshing = false
            }
        }

        webView = buildWebView()
        swipeRefresh.addView(webView, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
        ))

        webViewContainer.addView(swipeRefresh, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
        ))
        webViewContainer.addView(errorOverlay, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
        ))
    }

    @android.annotation.SuppressLint("SetJavaScriptEnabled")
    private fun buildWebView(): WebView {
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(WebView(this), !isIncognito)

        return WebView(this).apply {
            setBackgroundColor(pageBg)
            overScrollMode = View.OVER_SCROLL_NEVER
            isVerticalScrollBarEnabled = true
            isHorizontalScrollBarEnabled = false

            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                mediaPlaybackRequiresUserGesture = false
                loadsImagesAutomatically = true
                useWideViewPort = true
                loadWithOverviewMode = true
                builtInZoomControls = true
                displayZoomControls = false
                setSupportZoom(true)
                textZoom = 100
                minimumFontSize = 1
                cacheMode = if (!isIncognito && readNavAcceleratorEnabled()) {
                    WebSettings.LOAD_DEFAULT
                } else {
                    WebSettings.LOAD_NO_CACHE
                }
                mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                setSupportMultipleWindows(false)
                javaScriptCanOpenWindowsAutomatically = false
                allowFileAccess = false
                allowContentAccess = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) safeBrowsingEnabled = true
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    isAlgorithmicDarkeningAllowed = readForceDarkEnabled() ||
                        (readSiteThemeFollowsAppEnabled() && isDark)
                }
                saveFormData = !isIncognito
            }

            webViewClient = buildWebViewClient()
            webChromeClient = buildWebChromeClient()

            setOnLongClickListener {
                val result = hitTestResult
                handleLongPress(result)
                false
            }

            setOnScrollChangeListener { _, _, scrollY, _, _ ->
                onWebViewScrollChanged(scrollY)
            }

            setDownloadListener { url, _, contentDisposition, mimeType, _ ->
                handleDownload(url, contentDisposition, mimeType)
            }
        }
    }

    // ------------------------------------------------------------------
    // WebViewClient / WebChromeClient
    // ------------------------------------------------------------------

    private fun buildWebViewClient(): WebViewClient {
        return object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest,
            ): WebResourceResponse? {
                if (readAdBlockEnabled() && !request.isForMainFrame) {
                    if (LooplyAdRules.matches(request.url.toString())) {
                        return WebResourceResponse(
                            "text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)),
                        )
                    }
                }
                return super.shouldInterceptRequest(view, request)
            }

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest,
            ): Boolean {
                val scheme = request.url.scheme?.lowercase() ?: return true
                if (scheme == "http" || scheme == "https" || scheme == "about" ||
                    scheme == "data" || scheme == "blob" || scheme == "javascript"
                ) {
                    return false
                }
                return try {
                    startActivity(Intent(Intent.ACTION_VIEW, request.url))
                    true
                } catch (_: Exception) {
                    true
                }
            }

            override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                renderProcessCrashed = false
                loadError = null
                hasScrollBaseline = false
                animateToolbarVisibility(1f)
                currentUrl = url
                currentTitle = ""
                siteToolbarColor = null
                isLoading = true
                showProgress = true
                progressBar.progress = 40
                updatePillTitle()
                hideErrorOverlay()
                scheduleCosmeticFilterInstall()
            }

            override fun onPageFinished(view: WebView, url: String) {
                swipeRefresh.isRefreshing = false
                canGoBackState = view.canGoBack()
                canGoForwardState = view.canGoForward()
                currentUrl = url
                isLoading = false
                progressBar.progress = 1000
                updateNavigationButtonStates()
                updatePillTitle()
                applyWebsiteAppearance()
                refreshAdaptiveToolbarColor()
                scheduleCosmeticFilterInstall()
                maybeOfferTranslation()
                hideProgressAfterDelay()
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: android.webkit.WebResourceError,
            ) {
                if (request.isForMainFrame) {
                    isLoading = false
                    progressBar.progress = 1000
                    loadError = error.description?.toString() ?: "Erro ao carregar a página."
                    showErrorOverlay()
                    hideProgressAfterDelay()
                }
            }

            override fun onRenderProcessGone(
                view: WebView,
                detail: android.webkit.RenderProcessGoneDetail,
            ): Boolean {
                swipeRefresh.isRefreshing = false
                renderProcessCrashed = true
                isLoading = false
                showProgress = false
                loadError = "O motor da página foi reiniciado."
                showErrorOverlay()
                return true
            }
        }
    }

    private fun buildWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, newProgress: Int) {
                showProgress = true
                progressBar.progress = (newProgress * 10).coerceIn(0, 1000)
                if (newProgress < 100) isLoading = true
            }

            override fun onReceivedTitle(view: WebView, title: String?) {
                currentTitle = title ?: ""
                updatePillTitle()
            }

            override fun onPermissionRequest(request: PermissionRequest) {
                (this@OrbitBrowserActivity.applicationContext as? Context)?.let {
                    val main = this@OrbitBrowserActivity
                    main.runOnUiThread {
                        (getSystemService(Context.ACTIVITY_SERVICE))
                    }
                }
                // Delegado para a MainActivity através de um pedido simples:
                // como o WebView é totalmente nativo aqui, tratamos permissões
                // de câmara/microfone diretamente nesta Activity.
                requestOrbitWebPermissions(request)
            }

            override fun onGeolocationPermissionsShowPrompt(
                origin: String,
                callback: GeolocationPermissions.Callback,
            ) {
                requestOrbitGeolocation(origin, callback)
            }

            override fun onShowFileChooser(
                webView: WebView,
                filePathCallback: ValueCallback<Array<Uri>>,
                fileChooserParams: FileChooserParams,
            ): Boolean {
                this@OrbitBrowserActivity.filePathCallback?.onReceiveValue(null)
                this@OrbitBrowserActivity.filePathCallback = filePathCallback
                return try {
                    startActivityForResult(
                        fileChooserParams.createIntent(),
                        FILE_CHOOSER_REQUEST_CODE,
                    )
                    true
                } catch (_: Exception) {
                    this@OrbitBrowserActivity.filePathCallback = null
                    false
                }
            }
        }
    }

    private val FILE_CHOOSER_REQUEST_CODE = 9201

    @Deprecated("Deprecated in Android API; retained for file chooser result handling")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FILE_CHOOSER_REQUEST_CODE) {
            val callback = filePathCallback
            filePathCallback = null
            if (callback == null) return
            val results = if (resultCode == Activity.RESULT_OK && data?.data != null) {
                arrayOf(data.data!!)
            } else {
                null
            }
            callback.onReceiveValue(results)
        }
    }

    // ------------------------------------------------------------------
    // Permissões de câmara/microfone/localização — mesmos diálogos
    // nativos que existiam na MainActivity, agora locais a esta Activity.
    // ------------------------------------------------------------------

    private fun requestOrbitWebPermissions(request: PermissionRequest) {
        val origin = request.origin.toString()
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
            if (video in resources) add(android.Manifest.permission.CAMERA)
            if (audio in resources) add(android.Manifest.permission.RECORD_AUDIO)
        }.toTypedArray()
        val displayName = origin.removePrefix("https://").removePrefix("http://").substringBefore('/')
        android.app.AlertDialog.Builder(this)
            .setTitle("Permitir acesso ao dispositivo?")
            .setMessage(
                "$displayName pretende utilizar " +
                    buildList {
                        if (video in resources) add("a câmara")
                        if (audio in resources) add("o microfone")
                    }.joinToString(" e ") + ".",
            )
            .setNegativeButton("Bloquear") { _, _ -> request.deny() }
            .setPositiveButton("Permitir") { _, _ ->
                requestPermissions(androidPermissions, RUNTIME_PERMISSION_REQUEST_CODE)
                pendingWebPermissionRequest = request
                pendingWebPermissionResources = resources
            }
            .setOnCancelListener { request.deny() }
            .show()
    }

    private var pendingWebPermissionRequest: PermissionRequest? = null
    private var pendingWebPermissionResources: Set<String> = emptySet()
    private val RUNTIME_PERMISSION_REQUEST_CODE = 7501
    private val LOCATION_PERMISSION_REQUEST_CODE = 7502

    @Deprecated("Deprecated in Android API; retained for compatibility")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RUNTIME_PERMISSION_REQUEST_CODE) {
            val request = pendingWebPermissionRequest
            val resources = pendingWebPermissionResources
            pendingWebPermissionRequest = null
            pendingWebPermissionResources = emptySet()
            if (request == null) return
            val granted = permissions.indices.all { index ->
                grantResults.getOrNull(index) == android.content.pm.PackageManager.PERMISSION_GRANTED
            }
            try {
                if (granted) request.grant(resources.toTypedArray()) else request.deny()
            } catch (_: RuntimeException) {
                // O site pode ter cancelado o pedido entretanto.
            }
        } else if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            val callback = pendingGeolocationCallback
            val origin = pendingGeolocationOrigin
            pendingGeolocationCallback = null
            pendingGeolocationOrigin = null
            if (callback == null || origin == null) return
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
            webPermissionPreferences.edit()
                .putString("geo:$origin", if (granted) "allow" else "deny")
                .apply()
            callback.invoke(origin, granted, false)
        }
    }

    private var pendingGeolocationCallback: GeolocationPermissions.Callback? = null
    private var pendingGeolocationOrigin: String? = null
    private val webPermissionPreferences: SharedPreferences by lazy {
        getSharedPreferences("browseit_web_permissions", Context.MODE_PRIVATE)
    }

    private fun requestOrbitGeolocation(origin: String, callback: GeolocationPermissions.Callback) {
        val parsedOrigin = Uri.parse(origin)
        if (parsedOrigin.scheme != "https" && parsedOrigin.host != "localhost") {
            callback.invoke(origin, false, false)
            return
        }
        val host = origin.removePrefix("https://").removePrefix("http://").substringBefore('/')
        val savedDecision = webPermissionPreferences.getString("geo:$origin", null)
        val hasSystemPermission = checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        if (savedDecision == "allow" && hasSystemPermission) {
            callback.invoke(origin, true, false)
            return
        }
        if (savedDecision == "deny") {
            callback.invoke(origin, false, false)
            return
        }
        android.app.AlertDialog.Builder(this)
            .setTitle("Permitir localização?")
            .setMessage("$host pretende aceder à localização deste dispositivo.")
            .setNegativeButton("Bloquear") { _, _ ->
                webPermissionPreferences.edit().putString("geo:$origin", "deny").apply()
                callback.invoke(origin, false, false)
            }
            .setPositiveButton("Permitir") { _, _ ->
                pendingGeolocationCallback = callback
                pendingGeolocationOrigin = origin
                requestPermissions(
                    arrayOf(
                        android.Manifest.permission.ACCESS_COARSE_LOCATION,
                        android.Manifest.permission.ACCESS_FINE_LOCATION,
                    ),
                    LOCATION_PERMISSION_REQUEST_CODE,
                )
            }
            .setOnCancelListener { callback.invoke(origin, false, false) }
            .show()
    }

    // ------------------------------------------------------------------
    // Preferências partilhadas com o Flutter (mesmas chaves do SharedPreferences
    // que o antigo OrbitBrowserScreen.dart lia via ValueListenable)
    // ------------------------------------------------------------------

    private fun readAdBlockEnabled(): Boolean = appPreferences.getBoolean(PREF_AD_BLOCK_ENABLED, true)
    private fun readNavAcceleratorEnabled(): Boolean = appPreferences.getBoolean(PREF_NAV_ACCELERATOR, true)
    private fun readForceDarkEnabled(): Boolean = appPreferences.getBoolean(PREF_FORCE_DARK_SITES, false)
    private fun readSiteThemeFollowsAppEnabled(): Boolean =
        appPreferences.getBoolean(PREF_SITE_THEME_FOLLOWS_APP, false)
    private fun readAdaptiveToolbarEnabled(): Boolean = appPreferences.getBoolean(PREF_ADAPTIVE_TOOLBAR, false)
    private fun readAppLanguageCode(): String = appPreferences.getString(PREF_APP_LANGUAGE, "pt") ?: "pt"

    // ------------------------------------------------------------------
    // Navegação / ações de endereço
    // ------------------------------------------------------------------

    private fun loadAddress(rawInput: String, pushToField: Boolean = false) {
        val input = rawInput.trim()
        if (input.isEmpty()) return
        val candidate = when {
            input.startsWith("https://", true) || input.startsWith("http://", true) -> input
            input.contains(' ') -> "https://www.google.com/search?q=${Uri.encode(input)}"
            input.contains('.') -> "https://$input"
            else -> "https://www.google.com/search?q=${Uri.encode(input)}"
        }
        val uri = runCatching { Uri.parse(candidate) }.getOrNull()
        if (uri == null || (uri.scheme != "https" && uri.scheme != "http") || uri.host.isNullOrBlank()) {
            Toast.makeText(this, "Endereço inválido", Toast.LENGTH_SHORT).show()
            return
        }
        currentUrl = uri.toString()
        webView.loadUrl(
            currentUrl,
            mapOf("Accept-Language" to acceptLanguageHeader()),
        )
        if (pushToField) updatePillTitle()
    }

    private fun acceptLanguageHeader(): String {
        val regions = mapOf(
            "pt" to "PT", "en" to "US", "es" to "ES", "fr" to "FR", "de" to "DE", "it" to "IT",
            "ar" to "SA", "zh" to "CN", "ja" to "JP", "ru" to "RU", "hi" to "IN", "tr" to "TR",
        )
        val code = readAppLanguageCode()
        val region = regions[code] ?: "US"
        return "$code,$code-$region;q=0.9,en;q=0.7"
    }

    private fun updateNavigationButtonStates() {
        canGoBackState = webView.canGoBack()
        canGoForwardState = webView.canGoForward()
    }

    private fun updatePillTitle() {
        val uri = runCatching { Uri.parse(currentUrl) }.getOrNull()
        val fallback = uri?.host?.takeIf { it.isNotBlank() } ?: "BrowseIt Browser"
        pillTitleView.text = currentTitle.ifBlank { fallback }
    }

    // ------------------------------------------------------------------
    // Cor adaptável do toolbar / dark mode do site
    // ------------------------------------------------------------------

    private fun applyWebsiteAppearance() {
        val forceDark = readForceDarkEnabled()
        val followsApp = readSiteThemeFollowsAppEnabled()
        val scheme = if (followsApp) (if (isDark) "dark" else "light") else "normal"
        val script = """(() => {
            try {
              const root = document.documentElement;
              root.style.setProperty('color-scheme', '$scheme');
              root.dataset.appTheme = '$scheme';
              let meta = document.querySelector('meta[name="color-scheme"]');
              if (!meta) { meta = document.createElement('meta'); meta.name = 'color-scheme'; document.head?.appendChild(meta); }
              meta.content = '$scheme';
            } catch (_) {}
        })();"""
        webView.evaluateJavascript(script, null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            webView.settings.isAlgorithmicDarkeningAllowed = forceDark || (followsApp && isDark)
        }
    }

    private fun refreshAdaptiveToolbarColor() {
        if (isIncognito || !readAdaptiveToolbarEnabled()) {
            siteToolbarColor = null
            applyToolbarColor(pageBg)
            return
        }
        webView.evaluateJavascript(
            """(() => {
                const meta = document.querySelector('meta[name="theme-color"]');
                if (meta && meta.content) return meta.content.trim();
                const body = document.body ? getComputedStyle(document.body).backgroundColor : '';
                const solid = v => v && v !== 'transparent' && !/^rgba\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*0(?:\.0+)?\s*\)$/i.test(v);
                if (solid(body)) return body;
                return '';
            })()""",
        ) { raw ->
            val value = raw?.trim('"')?.trim()
            val color = parseCssColor(value)
            if (color != null) {
                siteToolbarColor = color
                applyToolbarColor(color)
            } else {
                siteToolbarColor = null
                applyToolbarColor(pageBg)
            }
        }
    }

    private fun parseCssColor(raw: String?): Int? {
        if (raw.isNullOrBlank() || raw == "null") return null
        val value = raw.trim().lowercase()
        Regex("^#([0-9a-f]{6}|[0-9a-f]{8})$").find(value)?.let { match ->
            val digits = match.groupValues[1]
            val parsed = digits.toLongOrNull(16) ?: return null
            return if (digits.length == 8) parsed.toInt() else (0xFF000000 or parsed).toInt()
        }
        Regex("rgba?\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})").find(value)?.let { match ->
            val r = match.groupValues[1].toInt().coerceIn(0, 255)
            val g = match.groupValues[2].toInt().coerceIn(0, 255)
            val b = match.groupValues[3].toInt().coerceIn(0, 255)
            return Color.rgb(r, g, b)
        }
        return null
    }

    private fun perceivedBrightness(color: Int): Double {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        return (r * 299 + g * 587 + b * 114) / 1000.0 / 255.0
    }

    private fun isLightSurface(color: Int): Boolean = perceivedBrightness(color) > 0.55

    private fun contrastForeground(color: Int): Int =
        if (isLightSurface(color)) Color.rgb(17, 17, 17) else Color.WHITE

    private fun adaptivePillColor(toolbar: Int): Int {
        val mixTarget = if (isLightSurface(toolbar)) Color.BLACK else Color.WHITE
        val mixed = blendColors(toolbar, mixTarget, 0.22f)
        return applyAlpha(mixed, 0.86f)
    }

    private fun blendColors(a: Int, b: Int, t: Float): Int {
        val ar = Color.red(a); val ag = Color.green(a); val ab = Color.blue(a)
        val br = Color.red(b); val bg = Color.green(b); val bb = Color.blue(b)
        return Color.rgb(
            (ar + (br - ar) * t).roundToInt(),
            (ag + (bg - ag) * t).roundToInt(),
            (ab + (bb - ab) * t).roundToInt(),
        )
    }

    private fun applyAlpha(color: Int, alpha: Float): Int {
        val a = (alpha * 255).roundToInt().coerceIn(0, 255)
        return Color.argb(a, Color.red(color), Color.green(color), Color.blue(color))
    }

    private fun applyToolbarColor(color: Int) {
        toolbarContainer.setBackgroundColor(color)
        statusBarSpacer.setBackgroundColor(color)
        val textColor = if (color == pageBg) mainTextColor else contrastForeground(color)
        val pillColor = if (color == pageBg) pillColorValue else adaptivePillColor(color)
        pillTitleView.setTextColor(textColor)
        titlePill.background = pillBackground(pillColor)
        homeButton.findViewWithTag<TextView>("icon")
        updateIconTint(homeButton, textColor)
        updateIconTint(tabsButton, textColor)
        updateIconTint(moreButton, textColor)
        tabsCountView.setTextColor(textColor)
        (tabsCountView.background as? GradientDrawable)?.setStroke(dpF(1.5f), textColor)
        applyStatusBarAppearance(isLightSurface(color))
    }

    private fun updateIconTint(container: FrameLayout, color: Int) {
        for (index in 0 until container.childCount) {
            (container.getChildAt(index) as? TextView)?.setTextColor(color)
        }
    }

    private fun applyStatusBarAppearance(lightSurface: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                val mask = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                controller.setSystemBarsAppearance(if (lightSurface) mask else 0, mask)
            }
        } else {
            @Suppress("DEPRECATION")
            var flags = window.decorView.systemUiVisibility
            flags = if (lightSurface) {
                flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            } else {
                flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
            }
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = flags
        }
    }

    private fun applySystemBars() {
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
    }

    // ------------------------------------------------------------------
    // Toolbar escondendo ao scroll — equivalente ao _toolbarVisibility do
    // antigo OrbitBrowserScreen.dart (1:1 com o gesto, sem animação
    // temporizada durante o scroll).
    // ------------------------------------------------------------------

    private fun onWebViewScrollChanged(y: Int) {
        if (isFindInPage) return
        if (!hasScrollBaseline) {
            lastScrollY = y
            hasScrollBaseline = true
            return
        }
        val delta = y - lastScrollY
        lastScrollY = y
        if (delta == 0) return

        if (y <= 4) {
            if (toolbarVisibility != 1f) setToolbarVisibility(1f)
            return
        }

        val toolbarHeightPx = dpF(42.4f).toFloat()
        val next = (toolbarVisibility - (delta / toolbarHeightPx)).coerceIn(0f, 1f)
        setToolbarVisibility(next)
    }

    private fun setToolbarVisibility(value: Float) {
        toolbarVisibility = value
        val params = toolbarContainer.layoutParams
        params.height = (dpF(42.4f) * value).roundToInt()
        toolbarContainer.layoutParams = params
    }

    private var toolbarAnimator: ValueAnimator? = null

    private fun animateToolbarVisibility(target: Float) {
        toolbarAnimator?.cancel()
        toolbarAnimator = ValueAnimator.ofFloat(toolbarVisibility, target).apply {
            duration = 180
            interpolator = DecelerateInterpolator()
            addUpdateListener { setToolbarVisibility(it.animatedValue as Float) }
            start()
        }
    }

    // ------------------------------------------------------------------
    // Ad-block cosmético (reaproveita o script já existente em
    // LooplyNativeAdBlocker.kt para não duplicar a lista de seletores)
    // ------------------------------------------------------------------

    private fun scheduleCosmeticFilterInstall() {
        if (!readAdBlockEnabled()) return
        val delays = longArrayOf(420L, 1150L, 2400L)
        delays.forEach { delay ->
            webView.postDelayed({
                if (!webView.isAttachedToWindow || !readAdBlockEnabled()) return@postDelayed
                try {
                    webView.evaluateJavascript(
                        LooplyNativeContentBlockerHandler.COSMETIC_FILTER_SCRIPT,
                        null,
                    )
                } catch (_: RuntimeException) {
                    // A página pode ter sido fechada durante a navegação.
                }
            }, delay)
        }
    }

    // ------------------------------------------------------------------
    // Find in page
    // ------------------------------------------------------------------

    private fun enterFindInPage() {
        isFindInPage = true
        findField.setText("")
        titlePill.visibility = View.GONE
        findBar.visibility = View.VISIBLE
        animateToolbarVisibility(1f)
        findField.requestFocus()
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
        imm.showSoftInput(findField, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
    }

    private fun exitFindInPage() {
        findDebounceJob?.cancel()
        webView.clearMatches()
        isFindInPage = false
        findField.setText("")
        findBar.visibility = View.GONE
        titlePill.visibility = View.VISIBLE
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
        imm.hideSoftInputFromWindow(findField.windowToken, 0)
    }

    private fun onFindTextChanged(value: String) {
        findDebounceJob?.cancel()
        findDebounceJob = mainScope.launch {
            kotlinx.coroutines.delay(180)
            if (value.trim().isEmpty()) {
                webView.clearMatches()
            } else {
                webView.findAllAsync(value.trim())
            }
        }
    }

    private fun moveFindResult(forward: Boolean) {
        if (findField.text.toString().trim().isEmpty()) return
        webView.findNext(forward)
    }

    // ------------------------------------------------------------------
    // Erro / retry
    // ------------------------------------------------------------------

    private fun showErrorOverlay() {
        errorOverlay.removeAllViews()
        errorOverlay.visibility = View.VISIBLE
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }
        val icon = TextView(this).apply {
            text = if (renderProcessCrashed) "↻" else "⚠"
            textSize = 38f
            gravity = Gravity.CENTER
            setTextColor(mutedTextColor)
        }
        val message = TextView(this).apply {
            text = loadError ?: "Não foi possível carregar a página."
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(mainTextColor)
            setPadding(0, dp(12), 0, dp(16))
        }
        val retryButton = TextView(this).apply {
            text = "Tentar novamente"
            textSize = 14f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(22).toFloat()
                setColor(accentColorValue)
            }
            setPadding(dp(22), dp(10), dp(22), dp(10))
            isClickable = true
            setOnClickListener { retryPage() }
        }
        content.addView(icon)
        content.addView(message)
        content.addView(retryButton, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { gravity = Gravity.CENTER })
        errorOverlay.addView(content, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER,
        ))
        errorOverlay.setBackgroundColor(pageBg)
    }

    private fun hideErrorOverlay() {
        errorOverlay.visibility = View.GONE
        errorOverlay.removeAllViews()
    }

    private fun retryPage() {
        if (renderProcessCrashed) {
            renderProcessCrashed = false
            loadError = null
            hideErrorOverlay()
            loadAddress(currentUrl)
        } else {
            loadError = null
            hideErrorOverlay()
            webView.reload()
        }
    }

    private fun hideProgressAfterDelay() {
        progressHideJob?.cancel()
        progressHideJob = mainScope.launch {
            kotlinx.coroutines.delay(260)
            showProgress = false
        }
    }

    // ------------------------------------------------------------------
    // Long-press (imagem / vídeo / link) — menu contextual nativo via
    // PopupMenu, equivalente ao LooplyPopupMenuButton do Flutter.
    // ------------------------------------------------------------------

    private fun handleLongPress(result: WebView.HitTestResult) {
        val extra = result.extra ?: return
        val isImage = result.type == WebView.HitTestResult.IMAGE_TYPE ||
            result.type == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
        val isLink = result.type == WebView.HitTestResult.SRC_ANCHOR_TYPE
        val isMedia = looksLikeMediaUrl(extra)
        if (!isImage && !isLink && !isMedia) return

        val anchorView = View(this)
        val popup = PopupMenu(this, webView)
        val menu = popup.menu
        when {
            isImage -> {
                menu.add(0, 1, 0, "Abrir imagem num novo separador")
                menu.add(0, 2, 1, "Transferir imagem")
                menu.add(0, 3, 2, "Copiar imagem")
                menu.add(0, 4, 3, "Partilhar imagem")
            }
            isMedia -> {
                menu.add(0, 1, 0, "Abrir num novo separador")
                menu.add(0, 2, 1, "Transferir vídeo")
                menu.add(0, 3, 2, "Copiar ligação")
                menu.add(0, 4, 3, "Partilhar ligação")
            }
            else -> {
                menu.add(0, 1, 0, "Abrir num novo separador")
                menu.add(0, 3, 1, "Copiar ligação")
                menu.add(0, 5, 2, "Adicionar aos favoritos")
                menu.add(0, 4, 3, "Partilhar ligação")
            }
        }
        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                1 -> finishWithRequestedAction("open_browser_tab", extra)
                2 -> Toast.makeText(this, "Transferência iniciada", Toast.LENGTH_SHORT).show()
                3 -> copyToClipboard(extra)
                4 -> shareUrl(extra)
                5 -> Toast.makeText(this, "Adicionado aos favoritos", Toast.LENGTH_SHORT).show()
            }
            true
        }
        popup.show()
    }

    private fun looksLikeMediaUrl(url: String): Boolean {
        val lower = url.lowercase()
        val videoExt = listOf(".mp4", ".webm", ".mov", ".m3u8", ".mkv", ".avi")
        val audioExt = listOf(".mp3", ".wav", ".ogg", ".m4a", ".flac")
        return videoExt.any { lower.contains(it) } || audioExt.any { lower.contains(it) }
    }

    private fun copyToClipboard(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("url", text))
        Toast.makeText(this, "Copiado", Toast.LENGTH_SHORT).show()
    }

    private fun shareUrl(url: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, url)
        }
        startActivity(Intent.createChooser(intent, null))
    }

    private fun handleDownload(url: String, contentDisposition: String?, mimeType: String?) {
        if (isIncognito) return
        Toast.makeText(this, "Transferência recebida", Toast.LENGTH_SHORT).show()
    }

    // ------------------------------------------------------------------
    // Site info dialog — reaproveita o estilo LooplyDialog_Dark/Light já
    // definido em res/values/styles.xml e res/values-night/styles.xml.
    // ------------------------------------------------------------------

    private fun showSiteInfoDialog() {
        val uri = runCatching { Uri.parse(currentUrl) }.getOrNull()
        val host = uri?.host?.takeIf { it.isNotBlank() } ?: currentUrl
        val themedContext = android.view.ContextThemeWrapper(
            this,
            if (isDark) R.style.LooplyDialog_Dark else R.style.LooplyDialog_Light,
        )
        val dialogView = LayoutInflater.from(themedContext).inflate(R.layout.dialog_native, null, false)
        val titleView = dialogView.findViewById<TextView>(R.id.dialog_title)
        val messageView = dialogView.findViewById<TextView>(R.id.dialog_message)
        val secondaryView = dialogView.findViewById<TextView>(R.id.dialog_secondary_message)
        val actionsContainer = dialogView.findViewById<LinearLayout>(R.id.dialog_actions)

        titleView.text = "Informação do site"
        titleView.setTextColor(mainTextColor)
        messageView.text = currentTitle.ifBlank { host }
        messageView.setTextColor(mainTextColor)
        messageView.setTypeface(messageView.typeface, android.graphics.Typeface.BOLD)
        secondaryView.text = currentUrl
        secondaryView.setTextColor(mutedTextColor)
        secondaryView.visibility = View.VISIBLE

        dialogView.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(20).toFloat()
            setColor(panelColor)
        }

        val dialog = android.app.AlertDialog.Builder(themedContext)
            .setView(dialogView)
            .setCancelable(true)
            .create()

        val closeButton = TextView(themedContext).apply {
            text = "Fechar"
            textSize = 14f
            setTextColor(accentColorValue)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            isClickable = true
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(22).toFloat()
                setColor(Color.TRANSPARENT)
            }
            setOnClickListener { dialog.dismiss() }
        }
        actionsContainer.addView(closeButton)

        dialog.show()
        dialog.window?.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(Color.TRANSPARENT))
        val maxWidth = dp(560)
        val screenWidth = resources.displayMetrics.widthPixels - dp(40)
        dialog.window?.setLayout(minOf(maxWidth, screenWidth), ViewGroup.LayoutParams.WRAP_CONTENT)
    }

    // ------------------------------------------------------------------
    // Bottom sheet de opções — BottomSheetDialogFragment real do Material
    // Components (não um PopupWindow), replicando o _showBrowserOptionsSheet
    // do antigo OrbitBrowserScreen.dart.
    // ------------------------------------------------------------------

    private fun showBrowserOptionsSheet() {
        val themeRes = if (isDark) R.style.LooplyBottomSheetDialog_Dark else R.style.LooplyBottomSheetDialog_Light
        val dialog = BottomSheetDialog(this, themeRes)
        val scrollView = android.widget.ScrollView(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(panelColor)
            setPadding(0, dp(10), 0, dp(18))
        }

        val handle = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(99).toFloat()
                setColor(applyAlpha(mutedTextColor, 0.5f))
            }
        }
        val handleRow = FrameLayout(this).apply {
            addView(handle, FrameLayout.LayoutParams(dp(34), dp(4), Gravity.CENTER))
        }
        content.addView(handleRow, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(18),
        ))

        val quickRow = android.widget.HorizontalScrollView(this)
        val quickActions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(12), dp(4), dp(12), dp(10))
        }
        quickActions.addView(quickAction("←", "Voltar", canGoBackState) {
            dialog.dismiss(); webView.goBack(); updateNavigationButtonStates()
        })
        quickActions.addView(quickAction("→", "Avançar", canGoForwardState) {
            dialog.dismiss(); webView.goForward(); updateNavigationButtonStates()
        })
        quickActions.addView(quickAction("+", if (isIncognito) "Novo separador privado" else "Novo separador", true) {
            dialog.dismiss(); finishWithRequestedAction("open_browser_tab", null)
        })
        quickActions.addView(quickAction("☆", "Favoritos", true) {
            dialog.dismiss(); finishWithRequestedAction("open_bookmarks", null)
        })
        quickActions.addView(quickAction("⚙", "Definições", true) {
            dialog.dismiss(); finishWithRequestedAction("open_settings", null)
        })
        quickRow.addView(quickActions)
        content.addView(quickRow, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        val divider = View(this).apply { setBackgroundColor(applyAlpha(mutedTextColor, 0.18f)) }
        content.addView(divider, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(1),
        ).apply { marginStart = dp(22); marginEnd = dp(22) })

        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        if (!isIncognito) {
            list.addView(sheetItem("🕐", "Histórico") { dialog.dismiss(); finishWithRequestedAction("open_history", null) })
            list.addView(sheetItem("⬇", "Transferências") { dialog.dismiss(); finishWithRequestedAction("open_downloads", null) })
        }
        list.addView(sheetItem("🔍", "Pesquisar na página") { dialog.dismiss(); enterFindInPage() })
        list.addView(sheetItem("☆", "Adicionar aos favoritos") { dialog.dismiss(); Toast.makeText(this, "Adicionado aos favoritos", Toast.LENGTH_SHORT).show() })
        if (!isIncognito) {
            list.addView(sheetItem("✦", "Traduzir") { dialog.dismiss(); translateCurrentPage() })
        }
        list.addView(dividerView())
        list.addView(sheetItem("↻", "Recarregar página") { dialog.dismiss(); webView.reload() })
        list.addView(sheetItem("🖥", if (desktopSiteRequested) "Desativar site de desktop" else "Site de desktop") {
            dialog.dismiss(); toggleDesktopSite()
        })
        val zoomRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        zoomRow.addView(sheetItem("－", "Reduzir zoom (-)") { dialog.dismiss(); applyZoom(-0.1) }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        zoomRow.addView(sheetItem("＋", "Aumentar zoom (+)") { dialog.dismiss(); applyZoom(0.1) }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        list.addView(zoomRow)
        list.addView(sheetItem("⎙", "Imprimir") { dialog.dismiss(); printCurrentPage() })
        list.addView(sheetItem("📋", "Copiar endereço") { dialog.dismiss(); copyToClipboard(currentUrl) })
        list.addView(sheetItem("ⓘ", "Informação do site") { dialog.dismiss(); showSiteInfoDialog() })
        list.addView(sheetItem("⌂", "Página inicial") { dialog.dismiss(); requestGoHome() })

        content.addView(list, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { leftMargin = dp(10); rightMargin = dp(10) })

        scrollView.addView(content)
        dialog.setContentView(scrollView)
        dialog.show()
    }

    private fun quickAction(glyph: String, label: String, enabled: Boolean, onTap: () -> Unit): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            alpha = if (enabled) 1f else 0.38f
            isClickable = enabled
            setPadding(dp(8), dp(4), dp(8), dp(4))
            val circle = FrameLayout(this@OrbitBrowserActivity).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(pillColorValue)
                }
                val icon = TextView(this@OrbitBrowserActivity).apply {
                    text = glyph
                    gravity = Gravity.CENTER
                    textSize = 19f
                    setTextColor(if (enabled) mainTextColor else mutedTextColor)
                }
                addView(icon, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
                ))
            }
            addView(circle, LinearLayout.LayoutParams(dp(46), dp(46)))
            val text = TextView(this@OrbitBrowserActivity).apply {
                text = label
                textSize = 10.5f
                gravity = Gravity.CENTER
                maxLines = 2
                setTextColor(if (enabled) mainTextColor else mutedTextColor)
                setPadding(0, dp(8), 0, 0)
            }
            addView(text)
            if (enabled) setOnClickListener { onTap() }
        }
    }

    private fun sheetItem(glyph: String, label: String, onTap: () -> Unit): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            isClickable = true
            isFocusable = true
            foreground = rippleDrawable()
            setPadding(dp(12), 0, dp(12), 0)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(58),
            )
            val icon = TextView(this@OrbitBrowserActivity).apply {
                text = glyph
                textSize = 18f
                gravity = Gravity.CENTER
                setTextColor(mainTextColor)
            }
            addView(icon, LinearLayout.LayoutParams(dp(42), ViewGroup.LayoutParams.MATCH_PARENT))
            val text = TextView(this@OrbitBrowserActivity).apply {
                text = label
                textSize = 14f
                setTypeface(typeface, android.graphics.Typeface.NORMAL)
                setTextColor(mainTextColor)
            }
            addView(text, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(12)
            })
            setOnClickListener { onTap() }
        }
    }

    private fun dividerView(): View {
        return View(this).apply {
            setBackgroundColor(applyAlpha(mutedTextColor, 0.18f))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(1),
            ).apply { topMargin = dp(9); bottomMargin = dp(9); marginStart = dp(12); marginEnd = dp(12) }
        }
    }

    // ------------------------------------------------------------------
    // Ações de menu (equivalente a _runShortcut do antigo Dart)
    // ------------------------------------------------------------------

    private fun toggleDesktopSite() {
        desktopSiteRequested = !desktopSiteRequested
        webView.settings.apply {
            userAgentString = if (desktopSiteRequested) DESKTOP_USER_AGENT else null
            useWideViewPort = true
            loadWithOverviewMode = true
        }
        webView.reload()
        Toast.makeText(
            this,
            if (desktopSiteRequested) "Site de desktop ativado" else "Site de desktop desativado",
            Toast.LENGTH_SHORT,
        ).show()
    }

    private fun applyZoom(delta: Double) {
        pageZoomFactor = (pageZoomFactor + delta).coerceIn(0.5, 2.0)
        val percent = (pageZoomFactor * 100).roundToInt()
        webView.evaluateJavascript("document.body.style.zoom = '$percent%';", null)
    }

    private fun printCurrentPage() {
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as android.print.PrintManager
            val jobName = "$currentTitle - BrowseIt"
            val adapter = webView.createPrintDocumentAdapter(jobName)
            printManager.print(jobName, adapter, android.print.PrintAttributes.Builder().build())
        } catch (_: Exception) {
            Toast.makeText(this, "Não foi possível imprimir esta página.", Toast.LENGTH_SHORT).show()
        }
    }

    private fun translateCurrentPage() {
        val targetCode = readAppLanguageCode()
        val encodedUrl = URLEncoder.encode(currentUrl, "UTF-8")
        val translateUrl = "https://translate.google.com/translate?sl=auto&tl=$targetCode&u=$encodedUrl"
        webView.loadUrl(translateUrl)
    }

    private fun maybeOfferTranslation() {
        if (isIncognito) return
        // Deteção simples do idioma declarado pela página; sem diálogo
        // bloqueante — apenas um Toast informativo, equivalente ao SnackBar
        // de tradução do antigo OrbitBrowserScreen.dart.
        webView.evaluateJavascript(
            "document.documentElement.getAttribute('lang') || ''",
        ) { raw ->
            val detected = raw?.trim('"')?.trim()?.lowercase()?.split(Regex("[-_]"))?.firstOrNull()
            val target = readAppLanguageCode().lowercase()
            if (!detected.isNullOrBlank() && detected != target) {
                Toast.makeText(
                    this,
                    "Esta página está noutro idioma. Toque em ⋮ > Traduzir para traduzir.",
                    Toast.LENGTH_LONG,
                ).show()
            }
        }
    }

    private fun requestGoHome() {
        finishWithRequestedAction("go_home", null)
    }

    private fun requestOpenTabsGrid() {
        finishWithRequestedAction("open_tabs_grid", null)
    }

    private fun openSearchScreen() {
        finishWithRequestedAction("open_search", if (isIncognito) "incognito" else null)
    }

    // ------------------------------------------------------------------
    // Fecho / devolução de resultado — equivalente ao antigo
    // ShellTabRequest.requestCloseBrowser()/tabsController.updateTab().
    // ------------------------------------------------------------------

    private fun captureThumbnail(): ByteArray? {
        return try {
            val bitmap = Bitmap.createBitmap(
                webView.width.coerceAtLeast(1),
                webView.height.coerceAtLeast(1),
                Bitmap.Config.ARGB_8888,
            )
            val canvas = android.graphics.Canvas(bitmap)
            webView.draw(canvas)
            val scaled = Bitmap.createScaledBitmap(
                bitmap,
                520,
                (520.0 * bitmap.height / bitmap.width).roundToInt().coerceAtLeast(1),
                true,
            )
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 90, stream)
            scaled.recycle()
            bitmap.recycle()
            stream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun finishWithoutAction() {
        val resultIntent = Intent().apply {
            putExtra(RESULT_TAB_ID, tabId)
            putExtra(RESULT_URL, currentUrl)
            putExtra(RESULT_TITLE, currentTitle.ifBlank { currentUrl })
            putExtra(RESULT_CAN_GO_BACK, canGoBackState)
            putExtra(RESULT_CAN_GO_FORWARD, canGoForwardState)
            if (!isIncognito) putExtra(RESULT_THUMBNAIL, captureThumbnail())
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
        overridePendingTransition(R.anim.orbit_hold_390, R.anim.orbit_slide_down_exit)
    }

    private fun finishWithRequestedAction(action: String, value: String?) {
        val resultIntent = Intent().apply {
            putExtra(RESULT_TAB_ID, tabId)
            putExtra(RESULT_URL, currentUrl)
            putExtra(RESULT_TITLE, currentTitle.ifBlank { currentUrl })
            putExtra(RESULT_CAN_GO_BACK, canGoBackState)
            putExtra(RESULT_CAN_GO_FORWARD, canGoForwardState)
            if (!isIncognito) putExtra(RESULT_THUMBNAIL, captureThumbnail())
            putExtra(RESULT_REQUESTED_ACTION, action)
            if (value != null) putExtra(RESULT_REQUESTED_ACTION_VALUE, value)
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
        overridePendingTransition(R.anim.orbit_hold_390, R.anim.orbit_slide_down_exit)
    }
}

/** Placeholder simples de ImageView usado para o favicon do pill de endereço. */
private class ImageViewPlaceholder(context: Context) : android.widget.ImageView(context) {
    init {
        scaleType = ScaleType.CENTER_CROP
        setImageDrawable(null)
    }
}
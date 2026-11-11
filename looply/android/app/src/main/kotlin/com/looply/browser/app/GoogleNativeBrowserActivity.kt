package com.looply.browser.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Minimal, independent Android WebView used only by the Google quick-site tile.
 * It is intentionally separate from the Flutter/InAppWebView browser so the
 * rendering and page behavior can be compared directly on the same device.
 */
class GoogleNativeBrowserActivity : Activity() {
    companion object {
        const val EXTRA_URL = "com.looply.browser.app.extra.NATIVE_BROWSER_URL"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_THEME_MODE = "flutter.looply_theme_mode"
        private const val PREF_PURE_BLACK = "flutter.looply_theme_pure_dark"
        private const val STATE_WEB_VIEW = "native_browser_web_view_state"
        private const val STATE_ADDRESS = "native_browser_address"
    }

    private lateinit var webView: WebView
    private lateinit var addressField: EditText
    private lateinit var progressBar: ProgressBar
    private lateinit var backButton: TextView
    private lateinit var forwardButton: TextView
    private lateinit var reloadButton: TextView
    private var pageStarted = false

    private val isDark: Boolean by lazy {
        val mode = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(PREF_THEME_MODE, "system") ?: "system"
        when (mode) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
    }

    private val isPureBlack: Boolean by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getBoolean(PREF_PURE_BLACK, false)
    }

    private val pageBackground: Int
        get() = when {
            !isDark -> Color.WHITE
            isPureBlack -> Color.BLACK
            else -> Color.rgb(20, 21, 23)
        }

    private val toolbarSurface: Int
        get() = when {
            !isDark -> Color.rgb(240, 241, 243)
            isPureBlack -> Color.rgb(25, 25, 25)
            else -> Color.rgb(43, 45, 48)
        }

    private val primaryText: Int
        get() = if (isDark) Color.rgb(230, 230, 232) else Color.rgb(32, 33, 36)

    private val secondaryText: Int
        get() = if (isDark) Color.rgb(178, 180, 184) else Color.rgb(95, 99, 104)

    private val accent: Int
        get() = if (isDark) Color.rgb(138, 180, 248) else Color.rgb(26, 115, 232)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        applySystemBars()
        window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(pageBackground)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            view.setPadding(0, bars.top, 0, maxOf(bars.bottom, ime.bottom))
            insets
        }

        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(9), dp(10), dp(9))
            setBackgroundColor(pageBackground)
        }

        backButton = createToolbarButton("‹", "Voltar") {
            if (webView.canGoBack()) webView.goBack() else finish()
        }
        forwardButton = createToolbarButton("›", "Avançar") {
            if (webView.canGoForward()) webView.goForward()
        }

        addressField = EditText(this).apply {
            setSingleLine(true)
            textSize = 14f
            setTextColor(primaryText)
            setHintTextColor(secondaryText)
            hint = "Pesquisar ou introduzir endereço"
            setPadding(dp(14), 0, dp(12), 0)
            imeOptions = EditorInfo.IME_ACTION_GO
            inputType = android.text.InputType.TYPE_CLASS_TEXT or
                android.text.InputType.TYPE_TEXT_VARIATION_URI
            background = roundedBackground(toolbarSurface, 22)
            isSelectAllOnFocus = true
            setOnEditorActionListener { _, actionId, event ->
                val enterPressed = event?.keyCode == KeyEvent.KEYCODE_ENTER &&
                    event.action == KeyEvent.ACTION_UP
                if (actionId == EditorInfo.IME_ACTION_GO || enterPressed) {
                    loadAddress(addressField.text?.toString().orEmpty())
                    true
                } else {
                    false
                }
            }
        }

        reloadButton = createToolbarButton("↻", "Recarregar") {
            if (::webView.isInitialized) webView.reload()
        }

        toolbar.addView(backButton, toolbarButtonParams())
        toolbar.addView(forwardButton, toolbarButtonParams())
        toolbar.addView(
            addressField,
            LinearLayout.LayoutParams(0, dp(42), 1f).apply {
                marginStart = dp(5)
                marginEnd = dp(5)
            },
        )
        toolbar.addView(reloadButton, toolbarButtonParams())
        root.addView(toolbar, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            progressTintList = android.content.res.ColorStateList.valueOf(accent)
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(toolbarSurface)
            visibility = View.GONE
        }
        root.addView(progressBar, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(2),
        ))

        CookieManager.getInstance().setAcceptCookie(true)
        webView = WebView(this).apply {
            setBackgroundColor(if (isDark) Color.rgb(20, 21, 23) else Color.WHITE)
            overScrollMode = View.OVER_SCROLL_NEVER
            isVerticalScrollBarEnabled = true
            isHorizontalScrollBarEnabled = false
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                loadsImagesAutomatically = true
                useWideViewPort = true
                loadWithOverviewMode = true
                builtInZoomControls = false
                displayZoomControls = false
                mediaPlaybackRequiresUserGesture = true
                javaScriptCanOpenWindowsAutomatically = false
                setSupportMultipleWindows(false)
                allowFileAccess = false
                allowContentAccess = false
                mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) safeBrowsingEnabled = true
            }
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val uri = request.url
                    return handleNonWebScheme(uri)
                }

                @Suppress("DEPRECATION")
                override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                    return handleNonWebScheme(Uri.parse(url))
                }

                override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                    pageStarted = true
                    addressField.setText(url)
                    progressBar.progress = 4
                    progressBar.visibility = View.VISIBLE
                    updateNavigationButtons()
                }

                override fun onPageFinished(view: WebView, url: String) {
                    addressField.setText(url)
                    pageStarted = false
                    updateNavigationButtons()
                }
            }
            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView, newProgress: Int) {
                    progressBar.progress = newProgress
                    progressBar.visibility = if (newProgress >= 100) View.GONE else View.VISIBLE
                    updateNavigationButtons()
                }
            }
        }

        root.addView(webView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))
        setContentView(root)

        val restored = savedInstanceState?.getBundle(STATE_WEB_VIEW)?.let { state ->
            webView.restoreState(state) != null
        } ?: false
        if (restored) {
            addressField.setText(savedInstanceState?.getString(STATE_ADDRESS) ?: webView.url.orEmpty())
        } else {
            val initialUrl = savedInstanceState?.getString(STATE_ADDRESS)
                ?: intent.getStringExtra(EXTRA_URL)
                ?: "https://www.google.com"
            loadAddress(initialUrl)
        }
        updateNavigationButtons()
    }

    private fun createToolbarButton(label: String, description: String, action: () -> Unit): TextView {
        return TextView(this).apply {
            text = label
            contentDescription = description
            gravity = Gravity.CENTER
            textSize = 27f
            setTextColor(primaryText)
            isClickable = true
            isFocusable = true
            setOnClickListener { action() }
            background = roundedBackground(toolbarSurface, 22)
        }
    }

    private fun toolbarButtonParams() = LinearLayout.LayoutParams(dp(38), dp(42)).apply {
        marginEnd = dp(3)
    }

    private fun roundedBackground(color: Int, radiusDp: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radiusDp).toFloat()
            setColor(color)
        }
    }

    private fun loadAddress(rawInput: String) {
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
        addressField.clearFocus()
        webView.loadUrl(uri.toString())
    }

    private fun handleNonWebScheme(uri: Uri): Boolean {
        if (uri.scheme.equals("http", true) || uri.scheme.equals("https", true)) return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
            true
        } catch (_: Exception) {
            true
        }
    }

    private fun updateNavigationButtons() {
        if (!::webView.isInitialized) return
        backButton.alpha = if (webView.canGoBack()) 1f else 0.45f
        forwardButton.alpha = if (webView.canGoForward()) 1f else 0.45f
        reloadButton.text = if (pageStarted) "×" else "↻"
    }

    private fun applySystemBars() {
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                val lightBars = !isDark
                val mask = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                val value = if (lightBars) mask else 0
                controller.setSystemBarsAppearance(value, mask)
            }
        } else {
            @Suppress("DEPRECATION")
            var flags = window.decorView.systemUiVisibility
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = if (isDark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                flags = if (isDark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                }
            }
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = flags
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (::webView.isInitialized) {
            val webState = Bundle()
            webView.saveState(webState)
            outState.putBundle(STATE_WEB_VIEW, webState)
            outState.putString(STATE_ADDRESS, addressField.text?.toString().orEmpty())
        }
    }

    @Deprecated("Deprecated in Android API 33; still used on older Android versions")
    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.webChromeClient = null
            webView.webViewClient = WebViewClient()
            (webView.parent as? ViewGroup)?.removeView(webView)
            webView.destroy()
        }
        super.onDestroy()
    }
}

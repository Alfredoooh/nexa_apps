package com.looply.browser.app

import android.app.Activity
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/** Native game renderer. It accepts a hosted page, a remote HTML source, or
 * HTML supplied by the games catalogue; the WebView is never replaced by a
 * Flutter/HTML preview screen. */
class GamesWebViewActivity : Activity() {
    companion object {
        const val EXTRA_LAUNCH_TYPE = "looply.game.LAUNCH_TYPE"
        const val EXTRA_URL = "looply.game.URL"
        const val EXTRA_HTML_FILE = "looply.game.HTML_FILE"
        const val EXTRA_BASE_URL = "looply.game.BASE_URL"
        const val EXTRA_TITLE = "looply.game.TITLE"
        const val EXTRA_ORIENTATION = "looply.game.ORIENTATION"
        private const val MAX_GAME_BYTES = 24L * 1024L * 1024L
        private const val ACCENT_BLUE = 0xFF1A73E8.toInt()
    }

    private lateinit var webView: WebView
    private lateinit var progress: ProgressBar
    private lateinit var loadingLabel: TextView
    private lateinit var statusBarScrim: View
    private var orientationDetected = false
    private var pageFailed = false
    private var launchType = ""
    private var gameUrl = ""
    private var gameHtml = ""
    private var baseUrl = ""
    private var gameTitle = ""
    private var requestedGameOrientation = "auto"
    private var sourceHost = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchType = intent.getStringExtra(EXTRA_LAUNCH_TYPE).orEmpty()
        gameUrl = intent.getStringExtra(EXTRA_URL).orEmpty()
        baseUrl = intent.getStringExtra(EXTRA_BASE_URL).orEmpty()
        if (launchType == "html" && !readHtmlFromCache()) {
            finish()
            return
        }
        gameTitle = intent.getStringExtra(EXTRA_TITLE).orEmpty().take(100)
        requestedGameOrientation = intent.getStringExtra(EXTRA_ORIENTATION).orEmpty().ifBlank { "auto" }

        if (!isValidLaunch()) {
            finish()
            return
        }

        sourceHost = when (launchType) {
            "html" -> android.net.Uri.parse(baseUrl.ifBlank { "https://games.local/" }).host.orEmpty()
            else -> android.net.Uri.parse(gameUrl).host.orEmpty()
        }
        requestedOrientation = when (requestedGameOrientation) {
            "portrait" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT
            "landscape" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            else -> ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        applyBlackSystemBars()
        buildGameContent()
        loadGame()
    }

    private fun readHtmlFromCache(): Boolean {
        val suppliedPath = intent.getStringExtra(EXTRA_HTML_FILE).orEmpty()
        if (suppliedPath.isBlank()) return false
        return try {
            val cacheRoot = cacheDir.canonicalPath + File.separator
            val htmlFile = File(suppliedPath).canonicalFile
            if (!htmlFile.path.startsWith(cacheRoot) || !htmlFile.isFile ||
                htmlFile.length() <= 0L || htmlFile.length() > MAX_GAME_BYTES) {
                false
            } else {
                gameHtml = htmlFile.readText(Charsets.UTF_8)
                htmlFile.delete()
                gameHtml.isNotBlank()
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isValidLaunch(): Boolean {
        if (launchType !in setOf("url", "source_url", "html")) return false
        if (launchType == "html") {
            if (gameHtml.isBlank() || gameHtml.toByteArray(Charsets.UTF_8).size > MAX_GAME_BYTES) return false
            if (baseUrl.isNotBlank()) {
                val uri = runCatching { android.net.Uri.parse(baseUrl) }.getOrNull() ?: return false
                if (uri.scheme != "https" || uri.host.isNullOrBlank()) return false
            }
            return true
        }
        val uri = runCatching { android.net.Uri.parse(gameUrl) }.getOrNull() ?: return false
        return uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null
    }

    /** Keep a solid black status bar and white icons in every app theme. */
    private fun applyBlackSystemBars() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        val insetsController = WindowCompat.getInsetsController(window, window.decorView)
        insetsController.isAppearanceLightStatusBars = false
        insetsController.isAppearanceLightNavigationBars = false
    }

    private fun buildGameContent() {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }

        webView = WebView(this).apply {
            setBackgroundColor(Color.BLACK)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.databaseEnabled = true
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            settings.setSupportZoom(false)
            settings.builtInZoomControls = false
            settings.displayZoomControls = false
            settings.javaScriptCanOpenWindowsAutomatically = false
            settings.setSupportMultipleWindows(false)
            settings.mediaPlaybackRequiresUserGesture = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.allowFileAccessFromFileURLs = false
            settings.allowUniversalAccessFromFileURLs = false
            settings.mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW
            settings.cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) settings.safeBrowsingEnabled = true

            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView?, newProgress: Int) {
                    this@GamesWebViewActivity.progress.progress = newProgress
                    this@GamesWebViewActivity.progress.visibility =
                        if (newProgress >= 100) View.GONE else View.VISIBLE
                    if (newProgress >= 100 && !pageFailed) loadingLabel.visibility = View.GONE
                }
            }
            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView?,
                    request: WebResourceRequest,
                ): WebResourceResponse? {
                    if (launchType != "source_url" || request.method != "GET") return null
                    val requested = request.url.buildUpon().fragment(null).build().toString()
                    val source = android.net.Uri.parse(gameUrl).buildUpon().fragment(null).build().toString()
                    if (requested == source) return fetchHtmlAsDocument(gameUrl)
                    return null
                }

                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest): Boolean {
                    if (!request.isForMainFrame) return false
                    val uri = request.url
                    // Permite a navegação interna do jogo no mesmo host e bloqueia
                    // esquemas perigosos ou saltos inesperados para outros sites.
                    return uri.scheme != "https" || uri.host.isNullOrBlank() || uri.host != sourceHost
                }

                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    val uri = runCatching { android.net.Uri.parse(url.orEmpty()) }.getOrNull() ?: return true
                    return uri.scheme != "https" || uri.host.isNullOrBlank() || uri.host != sourceHost
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    if (requestedGameOrientation == "auto") scheduleOrientationDetection()
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: android.webkit.WebResourceError?,
                ) {
                    super.onReceivedError(view, request, error)
                    if (request?.isForMainFrame == true) showLoadError()
                }

                override fun onReceivedHttpError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    errorResponse: WebResourceResponse?,
                ) {
                    super.onReceivedHttpError(view, request, errorResponse)
                    if (request?.isForMainFrame == true && (errorResponse?.statusCode ?: 200) >= 400) showLoadError()
                }
            }
        }

        root.addView(
            webView,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT),
        )

        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            progressTintList = android.content.res.ColorStateList.valueOf(ACCENT_BLUE)
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(Color.TRANSPARENT)
        }
        root.addView(
            progress,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, dp(2), Gravity.TOP),
        )

        loadingLabel = TextView(this).apply {
            text = if (gameTitle.isBlank()) "A carregar jogo…" else "A carregar $gameTitle…"
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(12), dp(20), dp(12))
            setBackgroundColor(0xAA141517.toInt())
        }
        root.addView(
            loadingLabel,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER),
        )

        statusBarScrim = View(this).apply { setBackgroundColor(Color.BLACK) }
        root.addView(statusBarScrim, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, 0, Gravity.TOP))

        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val topInset = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top
            statusBarScrim.layoutParams = (statusBarScrim.layoutParams as FrameLayout.LayoutParams).apply {
                height = topInset
            }
            progress.layoutParams = (progress.layoutParams as FrameLayout.LayoutParams).apply {
                topMargin = topInset
            }
            insets
        }
        setContentView(root)
        ViewCompat.requestApplyInsets(root)
    }

    private fun loadGame() {
        pageFailed = false
        orientationDetected = false
        progress.progress = 0
        progress.visibility = View.VISIBLE
        loadingLabel.visibility = View.VISIBLE
        when (launchType) {
            "html" -> {
                val origin = baseUrl.ifBlank { "https://games.local/" }
                webView.loadDataWithBaseURL(origin, gameHtml, "text/html", "UTF-8", null)
            }
            "source_url", "url" -> webView.loadUrl(gameUrl)
        }
    }

    /** Fetches a raw HTML source and changes its MIME type before WebView parses it. */
    private fun fetchHtmlAsDocument(url: String): WebResourceResponse {
        return try {
            val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 20_000
                readTimeout = 45_000
                instanceFollowRedirects = true
                requestMethod = "GET"
                setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36")
                setRequestProperty("Accept", "text/html,application/xhtml+xml,*/*;q=0.8")
            }
            val status = connection.responseCode
            val length = connection.getHeaderField("Content-Length")?.toLongOrNull() ?: -1L
            if (status !in 200..299 || (length > 0 && length > MAX_GAME_BYTES)) {
                connection.disconnect()
                return htmlErrorResponse("Não foi possível carregar este jogo. Verifica a ligação à Internet e tenta novamente.")
            }
            val bytes = connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                var total = 0L
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    if (total > MAX_GAME_BYTES) throw IllegalStateException("O ficheiro excede o limite permitido.")
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            connection.disconnect()
            WebResourceResponse(
                "text/html",
                "UTF-8",
                status,
                "OK",
                mapOf("Cache-Control" to "no-store"),
                ByteArrayInputStream(bytes),
            )
        } catch (_: Exception) {
            htmlErrorResponse("Não foi possível carregar este jogo. Verifica a ligação à Internet e tenta novamente.")
        }
    }

    private fun htmlErrorResponse(message: String): WebResourceResponse {
        val safe = message.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        val html = """<!doctype html><html lang="pt"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#141517;color:#f3f3f3;font:16px sans-serif;text-align:center}main{padding:28px;max-width:340px}button{margin-top:14px;padding:12px 18px;border:0;border-radius:24px;background:#1A73E8;color:white;font-weight:600}</style><main><p>$safe</p><button onclick="location.reload()">Tentar novamente</button></main></html>"""
        return WebResourceResponse("text/html", "UTF-8", ByteArrayInputStream(html.toByteArray(Charsets.UTF_8)))
    }

    private fun showLoadError() {
        if (pageFailed) return
        pageFailed = true
        loadingLabel.text = "Não foi possível abrir o jogo. Verifica a ligação à Internet."
        loadingLabel.visibility = View.VISIBLE
        progress.visibility = View.GONE
    }

    private fun scheduleOrientationDetection() {
        if (orientationDetected || isFinishing) return
        webView.postDelayed({ detectGameOrientation() }, 900)
        webView.postDelayed({ detectGameOrientation() }, 2_300)
        webView.postDelayed({ detectGameOrientation() }, 4_800)
    }

    private fun detectGameOrientation() {
        if (orientationDetected || isFinishing) return
        val script = """(function(){
            const nodes=[...document.querySelectorAll('canvas,video,iframe')];
            let best=null, area=0;
            for(const el of nodes){
              const r=el.getBoundingClientRect();
              const iw=Number(el.getAttribute('width'))||Number(el.width)||0;
              const ih=Number(el.getAttribute('height'))||Number(el.height)||0;
              const w=iw>100?iw:r.width, h=ih>100?ih:r.height;
              const a=w*h;
              if(w>120&&h>120&&a>area){best={w:w,h:h};area=a;}
            }
            if(!best){
              const m=document.querySelector('meta[name="game-orientation"]');
              if(m&&m.content){return m.content.toLowerCase()==='landscape'?'1.6':(m.content.toLowerCase()==='portrait'?'0.6':'1.0');}
              return '1.0';
            }
            return (best.w/best.h).toFixed(3);
        })();"""
        webView.evaluateJavascript(script) { raw ->
            val ratio = raw?.trim()?.trim('"')?.toFloatOrNull() ?: return@evaluateJavascript
            if (ratio >= 1.18f) {
                orientationDetected = true
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            } else if (ratio <= 0.84f) {
                orientationDetected = true
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT
            }
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else {
            finish()
            overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
        }
    }

    override fun onPause() {
        if (::webView.isInitialized) webView.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (::webView.isInitialized) webView.onResume()
        applyBlackSystemBars()
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.loadUrl("about:blank")
            webView.clearHistory()
            webView.removeAllViews()
            webView.destroy()
        }
        super.onDestroy()
    }
}

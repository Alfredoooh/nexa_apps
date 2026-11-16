package com.looply.browser.app

import android.app.Activity
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
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
import java.io.ByteArrayInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/**
 * Reproduz o ficheiro HTML do jogo numa WebView real (não numa pré-visualização
 * de código). O HTML é servido pelo repositório original e a resposta é
 * apresentada como text/html porque o raw.githubusercontent.com usa text/plain
 * para ficheiros HTML. O código do jogo não é incluído nem redistribuído no APK.
 */
class GamesWebViewActivity : Activity() {
    companion object {
        const val EXTRA_FILE_NAME = "looply.game.FILE_NAME"
        const val EXTRA_TITLE = "looply.game.TITLE"
        private const val RAW_PREFIX =
            "https://raw.githubusercontent.com/CoolDude2349/Offline-HTML-Games-Pack/master/offline/"
        private const val MAX_GAME_BYTES = 24L * 1024L * 1024L
    }

    private lateinit var webView: WebView
    private lateinit var progress: ProgressBar
    private lateinit var loadingLabel: TextView
    private var orientationDetected = false
    private var pageFailed = false
    private var gameFileName = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        gameFileName = intent.getStringExtra(EXTRA_FILE_NAME).orEmpty()
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        if (!isAllowedFileName(gameFileName)) {
            finish()
            return
        }

        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        applySystemBarColors()
        buildGameContent(title)
        loadGame()
    }

    private fun isAllowedFileName(value: String): Boolean {
        return value in setOf(
            "2048.html",
            "wordle-unlimited.html",
            "doodle-jump.html",
            "stack.html",
            "candy-crush.html",
            "idle-breakout.html",
            "google-baseball.html",
            "chess.html",
            "table-tennis-world-tour.html",
            "pac-man.html",
        )
    }

    private fun applySystemBarColors() {
        val dark = (resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val surface = if (dark) Color.rgb(20, 21, 23) else Color.WHITE
        window.statusBarColor = surface
        window.navigationBarColor = surface
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            var flags = window.decorView.systemUiVisibility
            flags = if (dark) {
                flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv() and
                    View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
            } else {
                flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or
                    View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            }
            window.decorView.systemUiVisibility = flags
        }
    }

    private fun buildGameContent(title: String) {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            fitsSystemWindows = false
        }

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
            settings.mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW
            settings.cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView?, newProgress: Int) {
                    progress.progress = newProgress
                    progress.visibility = if (newProgress >= 100) View.GONE else View.VISIBLE
                    if (newProgress >= 100) loadingLabel.visibility = View.GONE
                }
            }
            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView?,
                    request: WebResourceRequest,
                ): WebResourceResponse? {
                    val uri = request.url
                    if (uri.scheme != "https" || uri.host != "raw.githubusercontent.com") return null
                    val expectedPath = "/CoolDude2349/Offline-HTML-Games-Pack/master/offline/$gameFileName"
                    if (uri.path != expectedPath) return null
                    return fetchHtmlAsDocument(uri.toString())
                }

                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest): Boolean {
                    val uri = request.url
                    // Mantém a navegação dentro da página do jogo e bloqueia a
                    // abertura inadvertida de domínios externos a partir do HTML.
                    return uri.scheme !in setOf("https", "http") ||
                        (uri.host != "raw.githubusercontent.com" && uri.host != "github.com")
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    scheduleOrientationDetection()
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: android.webkit.WebResourceError?,
                ) {
                    super.onReceivedError(view, request, error)
                    if (request?.isForMainFrame == true) showLoadError()
                }
            }
        }

        root.addView(
            webView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            progressTintList = android.content.res.ColorStateList.valueOf(Color.rgb(80, 130, 230))
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(Color.TRANSPARENT)
        }
        root.addView(
            progress,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dp(3),
            ).apply { gravity = android.view.Gravity.TOP },
        )

        loadingLabel = TextView(this).apply {
            text = if (title.isBlank()) "A carregar jogo…" else "A carregar $title…"
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = android.view.Gravity.CENTER
            setPadding(dp(20), dp(12), dp(20), dp(12))
            setBackgroundColor(0xAA141517.toInt())
        }
        root.addView(
            loadingLabel,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                android.view.Gravity.CENTER,
            ),
        )

        setContentView(root)
    }

    private fun loadGame() {
        pageFailed = false
        orientationDetected = false
        progress.progress = 0
        progress.visibility = View.VISIBLE
        loadingLabel.visibility = View.VISIBLE
        val url = RAW_PREFIX + gameFileName
        webView.loadUrl(url)
    }

    /** Fetches the selected single-file game and overrides only its MIME type. */
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
                val output = java.io.ByteArrayOutputStream()
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
                ByteArrayInputStream(bytes),
            )
        } catch (_: Exception) {
            htmlErrorResponse("Não foi possível carregar este jogo. Verifica a ligação à Internet e tenta novamente.")
        }
    }

    private fun htmlErrorResponse(message: String): WebResourceResponse {
        val safe = message.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        val html = """<!doctype html><html lang="pt"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#141517;color:#f3f3f3;font:16px sans-serif;text-align:center}main{padding:28px;max-width:340px}button{margin-top:14px;padding:12px 18px;border:0;border-radius:24px;background:#8ab4f8;color:#101114;font-weight:600}</style><main><p>$safe</p><button onclick="location.reload()">Tentar novamente</button></main></html>"""
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
        if (orientationDetected) return
        // Alguns jogos só criam o canvas após inicializarem os scripts.
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
            // Relações quase quadradas permanecem em rotação automática.
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else {
            finish()
            overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
        }
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

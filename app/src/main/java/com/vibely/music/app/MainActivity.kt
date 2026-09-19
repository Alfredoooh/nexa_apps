package com.vibely.music.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowInsetsController
import android.webkit.ConsoleMessage
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var reloadBtn: Button
    private lateinit var testIdInput: EditText
    private lateinit var testPlayBtn: Button

    private var testPlayer: MediaPlayer? = null

    private val appUrl = "https://vibelywebapp.onrender.com"

    // Marca se a página principal falhou ao carregar
    private var loadFailed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webView)
        reloadBtn = findViewById(R.id.reloadBtn)
        testIdInput = findViewById(R.id.testIdInput)
        testPlayBtn = findViewById(R.id.testPlayBtn)

        ViewCompat.setOnApplyWindowInsetsListener(webView) { _, insets -> insets }

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowContentAccess = true
            builtInZoomControls = false
            displayZoomControls = false
            setSupportZoom(false)
            cacheMode = WebSettings.LOAD_DEFAULT
            // Permite tocar áudio sem exigir toque do usuário a cada faixa
            mediaPlaybackRequiresUserGesture = false
            // O site é HTTPS e o áudio vem de http://localhost:8080.
            // Sem isto o WebView bloqueia a mídia e o áudio nunca toca.
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        }

        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false
        webView.setBackgroundColor(Color.TRANSPARENT)

        webView.addJavascriptInterface(AndroidBridge(this), "Android")

        // Manda os console.log/erros do site para o Logcat (filtro: VibelyWeb)
        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                Log.d("VibelyWeb", "${message.message()} (${message.sourceId()}:${message.lineNumber()})")
                return true
            }
        }

        webView.webViewClient = object : WebViewClient() {

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean {
                return false
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                loadFailed = false
                reloadBtn.visibility = View.GONE
            }

            // Falhou ao carregar a página principal:
            // esconde o WebView (some a tela de erro nativa) e mostra o botão "Recarregar"
            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                if (request.isForMainFrame) {
                    loadFailed = true
                    view.stopLoading()
                    view.visibility = View.INVISIBLE
                    reloadBtn.visibility = View.VISIBLE
                }
            }

            // Carregou sem erro: mostra o WebView e esconde o botão
            override fun onPageFinished(view: WebView, url: String?) {
                super.onPageFinished(view, url)
                if (!loadFailed) {
                    view.visibility = View.VISIBLE
                    reloadBtn.visibility = View.GONE
                }
            }
        }

        reloadBtn.setOnClickListener {
            reloadBtn.visibility = View.GONE
            webView.visibility = View.VISIBLE
            loadFailed = false
            // Após um erro, reload() pode recarregar a página de erro; loadUrl é o certo
            webView.loadUrl(appUrl)
        }

        // ─── PAINEL DE TESTE: toca um ID via MediaPlayer nativo, sem passar pelo WebView ───
        // Serve para isolar se o problema é mixed content no WebView ou algo no servidor.
        testPlayBtn.setOnClickListener {
            val id = testIdInput.text.toString().trim()
            if (id.isEmpty()) {
                Toast.makeText(this, "Escreve um ID do YouTube primeiro", Toast.LENGTH_SHORT).show()
            } else {
                testPlayNative(id)
            }
        }

        requestNotificationPermission()
        startPlaybackService()

        if (savedInstanceState != null) {
            webView.restoreState(savedInstanceState)
        } else {
            webView.loadUrl(appUrl)
        }
    }

    // Toca via MediaPlayer nativo do Android, direto do LocalServer, sem WebView.
    private fun testPlayNative(videoId: String) {
        Toast.makeText(this, "A testar $videoId…", Toast.LENGTH_SHORT).show()
        testPlayer?.release()
        testPlayer = MediaPlayer()
        try {
            testPlayer?.setDataSource("http://localhost:8080/audio?id=$videoId")
            testPlayer?.setOnPreparedListener {
                Toast.makeText(this, "✅ TOCOU! ($videoId) — não é mixed content", Toast.LENGTH_LONG).show()
                it.start()
            }
            testPlayer?.setOnErrorListener { _, what, extra ->
                Toast.makeText(this, "❌ Falhou nativo: what=$what extra=$extra", Toast.LENGTH_LONG).show()
                true
            }
            testPlayer?.prepareAsync()
        } catch (e: Exception) {
            Toast.makeText(this, "❌ Exceção: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }

    // Android 13+ exige permissão para mostrar a notificação do serviço
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1001
                )
            }
        }
    }

    private fun startPlaybackService() {
        val intent = Intent(this, PlaybackService::class.java)
        ContextCompat.startForegroundService(this, intent)
    }

    fun setStatusBarIcons(dark: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val controller = window.insetsController
                if (dark) {
                    controller?.setSystemBarsAppearance(
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS,
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                    )
                } else {
                    controller?.setSystemBarsAppearance(
                        0,
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                    )
                }
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = if (dark) {
                    window.decorView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                } else {
                    window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                }
            }
        }
    }

    // Mantém o WebView (e o áudio) rodando com o app em segundo plano
    override fun onPause() {
        super.onPause()
        webView.onResume()
        webView.resumeTimers()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    override fun onDestroy() {
        super.onDestroy()
        testPlayer?.release()
        testPlayer = null
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
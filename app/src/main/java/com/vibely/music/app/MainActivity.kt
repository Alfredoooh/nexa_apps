package com.vibely.music.app

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
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
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var reloadBtn: Button
    private val appUrl = "https://vibelywebapp.onrender.com"
    private var loadFailed = false
    private var receiverRegistered = false

    // Recebe os comandos da notificação, dos fones e do ecrã bloqueado
    // (enviados pelo PlaybackService) e entrega-os ao JavaScript do player.
    private val mediaCommandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val cmd = intent?.getStringExtra("cmd") ?: return
            dispatchMediaCommand(cmd)
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webView)
        reloadBtn = findViewById(R.id.reloadBtn)

        ViewCompat.setOnApplyWindowInsetsListener(webView) { _, insets -> insets }

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowContentAccess = true
            builtInZoomControls = false
            displayZoomControls = false
            setSupportZoom(false)
            cacheMode = WebSettings.LOAD_DEFAULT
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        }

        webView.overScrollMode = View.OVER_SCROLL_NEVER
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false
        webView.setBackgroundColor(Color.TRANSPARENT)

        webView.addJavascriptInterface(AndroidBridge(this), "Android")

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                Log.d("VibelyWeb", "${message.message()} (${message.sourceId()}:${message.lineNumber()})")
                return true
            }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean = false

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                loadFailed = false
                reloadBtn.visibility = View.GONE
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) {
                    loadFailed = true
                    view.stopLoading()
                    view.visibility = View.INVISIBLE
                    reloadBtn.visibility = View.VISIBLE
                }
            }

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
            webView.loadUrl(appUrl)
        }

        // Botão voltar: primeiro o JS tenta fechar o que estiver aberto (diálogo, sheet,
        // menu, player, página, tab). Só se o JS disser que não há nada para fechar é que
        // a app vai para segundo plano. Usa a API moderna (OnBackPressedCallback), porque
        // onBackPressed() está obsoleto e não funciona com o gesto de voltar do Android 13+.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                webView.evaluateJavascript(
                    "(function(){try{return window.onNativeBack ? window.onNativeBack() : false;}catch(e){return false;}})()"
                ) { result ->
                    val consumed = result == "true"
                    if (!consumed) {
                        // Nada para fechar: vai para o ecrã inicial em vez de matar o
                        // processo, para a música continuar a tocar em segundo plano.
                        moveTaskToBack(true)
                    }
                }
            }
        })

        registerMediaReceiver()
        requestNotificationPermission()
        requestLocalMusicPermission()
        requestBluetoothPermission()
        startPlaybackService()

        if (savedInstanceState != null) webView.restoreState(savedInstanceState)
        else webView.loadUrl(appUrl)
    }

    // ─── Comandos da notificação → JavaScript ───
    // Chama a função global window.nativeMediaCommand(cmd), definida no index.html.
    // Se a página ainda estiver a carregar e a função não existir, não faz nada.
    private fun dispatchMediaCommand(cmd: String) {
        val safe = cmd.replace("\\", "\\\\").replace("'", "\\'")
        val js = "(function(){try{if(window.nativeMediaCommand){window.nativeMediaCommand('$safe');}}catch(e){}})()"
        runOnUiThread { webView.evaluateJavascript(js, null) }
    }

    private fun registerMediaReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter("com.vibely.music.app.MEDIA_COMMAND")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(mediaCommandReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(mediaCommandReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
        }
    }

    // Permissão para ler músicas guardadas localmente no aparelho
    fun requestLocalMusicPermission() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(permission), 1002)
        }
    }

    private fun requestBluetoothPermission() {
        val perms = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            perms.add(Manifest.permission.BLUETOOTH_CONNECT)
            perms.add(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val missing = perms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1003)
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
                if (dark) controller?.setSystemBarsAppearance(WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
                else controller?.setSystemBarsAppearance(0, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
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

    // O WebView tem de continuar vivo com o ecrã bloqueado ou com a app em segundo plano,
    // senão o JavaScript congela e o evento "ended" nunca dispara (a fila para de avançar).
    // Por isso NÃO chamamos webView.onPause() aqui, e reforçamos com resumeTimers().
    override fun onPause() {
        super.onPause()
        webView.resumeTimers()
    }

    override fun onResume() {
        super.onResume()
        webView.onResume()
        webView.resumeTimers()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    override fun onDestroy() {
        if (receiverRegistered) {
            try { unregisterReceiver(mediaCommandReceiver) } catch (_: Exception) {}
            receiverRegistered = false
        }
        super.onDestroy()
    }
}
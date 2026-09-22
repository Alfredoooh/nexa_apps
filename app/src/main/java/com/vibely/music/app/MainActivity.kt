package com.vibely.music.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
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
    // A app deixou de depender de um site externo: o index.html completo (web) passa a
    // ser o único index do app, empacotado em assets/app/index.html, servido por file://.
    // Funciona sempre, online ou offline — as chamadas de rede (BASE = localhost:8080)
    // continuam a funcionar normalmente por dentro do WebView em file://.
    private val appIndexUrl = "file:///android_asset/app/index.html"
    private var loadFailed = false
    private var receiverRegistered = false

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

        MainActivityInstance.instance = this

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
            allowFileAccess = true
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
            webView.loadUrl(appIndexUrl)
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                webView.evaluateJavascript(
                    "(function(){try{return window.onNativeBack ? window.onNativeBack() : false;}catch(e){return false;}})()"
                ) { result ->
                    val consumed = result == "true"
                    if (!consumed) moveTaskToBack(true)
                }
            }
        })

        registerMediaReceiver()
        requestNotificationPermission()
        requestLocalMusicPermission()
        requestBluetoothPermission()
        startPlaybackService()

        if (savedInstanceState != null) webView.restoreState(savedInstanceState)
        else webView.loadUrl(appIndexUrl)
    }

    // URL atual — usado pela CameraActivity para carregar a mesma origem.
    fun currentUrl(): String = appIndexUrl

    fun evaluateInWebView(js: String) {
        webView.evaluateJavascript(js, null)
    }

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

    fun requestLocalMusicPermission() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE
        if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(permission), 1002)
        }
    }

    fun requestImagesPermission() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE
        if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(permission), 1004)
        }
    }

    private fun requestBluetoothPermission() {
        val perms = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            perms.add(Manifest.permission.BLUETOOTH_CONNECT); perms.add(Manifest.permission.BLUETOOTH_SCAN)
        } else perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
        val missing = perms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1003)
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
                window.decorView.systemUiVisibility = if (dark) window.decorView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                else window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
            }
        }
    }

    // ─── Picker nativo de imagens (botão "Dispositivo" no modal de capa) ───
    fun openSystemImagePicker() {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        try { startActivityForResult(Intent.createChooser(intent, "Escolher imagem"), 3001) } catch (e: Exception) { }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 3001 && resultCode == Activity.RESULT_OK) {
            val uri = data?.data ?: return
            try { contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (e: Exception) { }
            val safe = uri.toString().replace("\\", "\\\\").replace("'", "\\'")
            val js = "(function(){try{if(window.onNativeImagePicked){window.onNativeImagePicked('$safe');}}catch(e){}})()"
            webView.evaluateJavascript(js, null)
        }
    }

    override fun onPause() { super.onPause(); webView.resumeTimers() }
    override fun onResume() { super.onResume(); webView.onResume(); webView.resumeTimers() }
    override fun onSaveInstanceState(outState: Bundle) { super.onSaveInstanceState(outState); webView.saveState(outState) }

    override fun onDestroy() {
        if (receiverRegistered) { try { unregisterReceiver(mediaCommandReceiver) } catch (_: Exception) {}; receiverRegistered = false }
        if (MainActivityInstance.instance === this) MainActivityInstance.instance = null
        super.onDestroy()
    }
}
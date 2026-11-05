package com.looply.browser.app

import android.content.Context
import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.WebChromeClient
import android.webkit.PermissionRequest
import android.webkit.GeolocationPermissions
import android.webkit.ValueCallback
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.Collections
import java.util.WeakHashMap

/** PlatformViewFactory que fornece o WebView Android nativo apenas ao Orbit. */
internal class OrbitNativeWebViewFactory(
    private val messenger: BinaryMessenger,
    private val onBlockedRequest: (Boolean) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val options = args as? Map<String, Any?> ?: emptyMap()
        return OrbitNativeWebViewPlatformView(
            context = context,
            viewId = viewId,
            messenger = messenger,
            options = options,
            onBlockedRequest = onBlockedRequest,
        )
    }
}

/** Um WebView real do Android, controlado pelo Orbit através de MethodChannel. */
internal class OrbitNativeWebViewPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    options: Map<String, Any?>,
    private val onBlockedRequest: (Boolean) -> Unit,
) : PlatformView {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val incognito = options["isIncognito"] as? Boolean ?: false
    private val channel = MethodChannel(messenger, "looply/orbit_webview_$viewId")
    private var disposed = false
    private var cacheEnabled = options["cacheEnabled"] as? Boolean ?: true
    private var adBlockEnabled = LooplyNativeAdBlockState.enabled
    private var touchStartY = 0f
    private var pullTriggered = false
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop

    private val webView = WebView(context).apply {
        setBackgroundColor(Color.TRANSPARENT)
        // Em Hybrid Composition (ver orbit_browser_screen.dart) a View Android
        // é desenhada diretamente na hierarquia de janela, sem passar por uma
        // textura/Virtual Display intermediária. Forçar aqui um hardware layer
        // extra duplicava a composição e era a causa do aspecto desfocado;
        // o WebView já tem a sua própria aceleração de hardware internamente.
        setLayerType(View.LAYER_TYPE_NONE, null)
        settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            @Suppress("DEPRECATION")
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            setGeolocationEnabled(true)
            cacheMode = if (incognito || !cacheEnabled) WebSettings.LOAD_NO_CACHE else WebSettings.LOAD_DEFAULT
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            builtInZoomControls = false
            displayZoomControls = false
            loadsImagesAutomatically = true
            allowFileAccess = false
            allowContentAccess = false
            // useWideViewPort + loadWithOverviewMode fazem a página calcular o
            // layout para a largura real do ecrã, em vez de escalar um layout
            // desktop para caber — é essa escala que produzia a sensação de
            // texto e imagens pouco nítidos em muitos sites.
            useWideViewPort = true
            loadWithOverviewMode = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) safeBrowsingEnabled = true
        }
    }

    init {
        CookieManager.getInstance().setAcceptCookie(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?,
            ): WebResourceResponse? {
                if (request == null || !LooplyNativeAdBlockState.enabled || request.isForMainFrame) {
                    return null
                }
                val url = request.url?.toString().orEmpty()
                if (!LooplyAdRules.matches(url)) return null
                onBlockedRequest(incognito)
                return WebResourceResponse(
                    "text/plain",
                    "UTF-8",
                    204,
                    "No Content",
                    mapOf("Access-Control-Allow-Origin" to "*"),
                    ByteArrayInputStream(ByteArray(0)),
                )
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val uri = request?.url ?: return false
                return !isAllowedWebNavigation(uri)
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                sendEvent("onLoadStart", mapOf("url" to url))
                sendEvent("onProgressChanged", mapOf("progress" to 0))
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                applyCosmeticFilter()
                sendVisitedHistory()
                sendEvent("onLoadStop", mapOf("url" to (url ?: webView.url)))
            }

            override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
                super.doUpdateVisitedHistory(view, url, isReload)
                sendVisitedHistory()
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: android.webkit.WebResourceError?,
            ) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame == true) {
                    val description = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        error?.description?.toString().orEmpty()
                    } else {
                        "Não foi possível carregar esta página."
                    }
                    sendEvent("onReceivedError", mapOf("isForMainFrame" to true, "description" to description))
                }
            }

            override fun onRenderProcessGone(view: WebView?, detail: android.webkit.RenderProcessGoneDetail?): Boolean {
                sendEvent("onRenderProcessGone", emptyMap<String, Any?>())
                return true
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                sendEvent("onProgressChanged", mapOf("progress" to newProgress))
            }

            override fun onReceivedTitle(view: WebView?, title: String?) {
                sendEvent("onTitleChanged", mapOf("title" to title))
            }

            override fun onPermissionRequest(request: PermissionRequest) {
                val activity = context as? MainActivity
                if (activity == null) {
                    request.deny()
                    return
                }
                activity.runOnUiThread {
                    if (!disposed) activity.requestOrbitWebPermissions(request, request.origin.toString())
                    else request.deny()
                }
            }

            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: GeolocationPermissions.Callback?,
            ) {
                val activity = context as? MainActivity
                if (activity == null || callback == null || origin.isNullOrBlank()) {
                    callback?.invoke(origin.orEmpty(), false, false)
                    return
                }
                activity.runOnUiThread {
                    if (!disposed) activity.requestOrbitGeolocation(origin, callback)
                    else callback.invoke(origin, false, false)
                }
            }

            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?,
            ): Boolean {
                val activity = context as? Activity ?: return false
                if (filePathCallback == null || fileChooserParams == null) return false
                return OrbitFileChooserRegistry.open(activity, fileChooserParams, filePathCallback)
            }
        }

        webView.setDownloadListener(DownloadListener { url, _, contentDisposition, mimeType, _ ->
            sendEvent(
                "onDownloadStartRequest",
                mapOf(
                    "url" to url,
                    "contentDisposition" to contentDisposition,
                    "mimeType" to mimeType,
                    "suggestedFilename" to android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType),
                ),
            )
        })

        // Mantém o gesto de puxar para atualizar sem delegar a WebView ao Flutter.
        webView.setOnTouchListener { view, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartY = event.y
                    pullTriggered = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val distance = event.y - touchStartY
                    if (!pullTriggered && view.scrollY <= 0 && distance > touchSlop * 3) {
                        pullTriggered = true
                        webView.reload()
                        return@setOnTouchListener true
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    touchStartY = 0f
                    pullTriggered = false
                }
            }
            false
        }

        OrbitNativeWebViewRegistry.register(this)
        channel.setMethodCallHandler(::handleMethodCall)
    }

    override fun getView(): View = webView

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("webview_disposed", "A WebView já foi destruída.", null)
            return
        }
        when (call.method) {
            "configure" -> {
                cacheEnabled = call.argument<Boolean>("cacheEnabled") ?: cacheEnabled
                adBlockEnabled = call.argument<Boolean>("adBlockEnabled") ?: adBlockEnabled
                LooplyNativeAdBlockState.enabled = adBlockEnabled
                applyWebSettings()
                val url = call.argument<String>("url")
                if (!url.isNullOrBlank()) webView.loadUrl(url)
                result.success(true)
            }
            "loadUrl" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) result.error("invalid_url", "O endereço está vazio.", null)
                else {
                    webView.loadUrl(url)
                    result.success(true)
                }
            }
            "reload" -> { webView.reload(); result.success(true) }
            "stopLoading" -> { webView.stopLoading(); result.success(true) }
            "goBack" -> { if (webView.canGoBack()) webView.goBack(); result.success(true) }
            "goForward" -> { if (webView.canGoForward()) webView.goForward(); result.success(true) }
            "canGoBack" -> result.success(webView.canGoBack())
            "canGoForward" -> result.success(webView.canGoForward())
            "getUrl" -> result.success(webView.url)
            "getTitle" -> result.success(webView.title)
            "takeScreenshot" -> result.success(captureScreenshot())
            "evaluateJavascript" -> {
                val source = call.argument<String>("source").orEmpty()
                webView.evaluateJavascript(source) { value -> result.success(value) }
            }
            "findAll" -> { webView.findAllAsync(call.argument<String>("query").orEmpty()); result.success(true) }
            "findNext" -> { webView.findNext(call.argument<Boolean>("forward") ?: true); result.success(true) }
            "clearMatches" -> { webView.clearMatches(); result.success(true) }
            "setSettings" -> {
                cacheEnabled = call.argument<Boolean>("cacheEnabled") ?: cacheEnabled
                adBlockEnabled = call.argument<Boolean>("adBlockEnabled") ?: adBlockEnabled
                LooplyNativeAdBlockState.enabled = adBlockEnabled
                applyWebSettings()
                applyCosmeticFilter()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun applyWebSettings() {
        webView.settings.cacheMode = if (incognito || !cacheEnabled) {
            WebSettings.LOAD_NO_CACHE
        } else {
            WebSettings.LOAD_DEFAULT
        }
        if (incognito) webView.clearHistory()
    }

    internal fun updateCosmeticFilter(enabled: Boolean) {
        adBlockEnabled = enabled
        mainHandler.post {
            if (disposed || !webView.isAttachedToWindow) return@post
            applyCosmeticFilter()
        }
    }

    private fun applyCosmeticFilter() {
        if (disposed || webView.url.isNullOrBlank()) return
        if (!LooplyNativeAdBlockState.enabled) {
            webView.evaluateJavascript(
                "window.__looplyAdBlockSetEnabled && window.__looplyAdBlockSetEnabled(false);",
                null,
            )
            return
        }
        webView.evaluateJavascript(LooplyNativeContentBlockerHandler.COSMETIC_FILTER_SCRIPT, null)
        webView.evaluateJavascript(
            "window.__looplyAdBlockSetEnabled && window.__looplyAdBlockSetEnabled(${LooplyNativeAdBlockState.enabled});",
            null,
        )
    }

    private fun sendVisitedHistory() {
        sendEvent(
            "onUpdateVisitedHistory",
            mapOf(
                "url" to webView.url,
                "title" to webView.title,
                "canGoBack" to webView.canGoBack(),
                "canGoForward" to webView.canGoForward(),
            ),
        )
    }

    private fun sendEvent(method: String, arguments: Map<String, Any?>) {
        if (disposed) return
        mainHandler.post {
            if (!disposed) channel.invokeMethod("event", mapOf("name" to method, "arguments" to arguments))
        }
    }

    private fun captureScreenshot(): ByteArray? {
        val width = webView.width
        val height = webView.height
        if (width <= 0 || height <= 0) return null
        return try {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            webView.draw(Canvas(bitmap))
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
            bitmap.recycle()
            stream.toByteArray()
        } catch (_: RuntimeException) {
            null
        }
    }

    private fun isAllowedWebNavigation(uri: Uri): Boolean {
        return when (uri.scheme?.lowercase()) {
            "http", "https", "about", "data", "blob", "javascript" -> true
            else -> false
        }
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        OrbitNativeWebViewRegistry.unregister(this)
        mainHandler.removeCallbacksAndMessages(null)
        try {
            webView.stopLoading()
            webView.loadUrl("about:blank")
            webView.clearHistory()
            webView.removeAllViews()
            webView.destroy()
        } catch (_: RuntimeException) {
            // A libertação do renderer não deve afetar a shell Flutter.
        }
    }
}

/** Mantém apenas referências fracas às WebViews Orbit para atualizar o filtro em runtime. */
internal object OrbitNativeWebViewRegistry {
    private val views = Collections.newSetFromMap(WeakHashMap<OrbitNativeWebViewPlatformView, Boolean>())

    @Synchronized
    fun register(view: OrbitNativeWebViewPlatformView) {
        views.add(view)
    }

    @Synchronized
    fun unregister(view: OrbitNativeWebViewPlatformView) {
        views.remove(view)
    }

    @Synchronized
    fun updateAll(enabled: Boolean) {
        views.toList().forEach { it.updateCosmeticFilter(enabled) }
    }
}


/** Usa o seletor de ficheiros do Android, sem pedir permissões de armazenamento amplas. */
internal object OrbitFileChooserRegistry {
    const val REQUEST_CODE = 7403
    private var pendingCallback: ValueCallback<Array<Uri>>? = null

    @Synchronized
    fun open(
        activity: Activity,
        params: WebChromeClient.FileChooserParams,
        callback: ValueCallback<Array<Uri>>,
    ): Boolean {
        pendingCallback?.onReceiveValue(null)
        pendingCallback = callback
        return try {
            val intent = params.createIntent()
            activity.startActivityForResult(intent, REQUEST_CODE)
            true
        } catch (_: Exception) {
            pendingCallback = null
            callback.onReceiveValue(null)
            false
        }
    }

    @Synchronized
    fun onActivityResult(resultCode: Int, data: Intent?) {
        val callback = pendingCallback ?: return
        pendingCallback = null
        val result = try {
            WebChromeClient.FileChooserParams.parseResult(resultCode, data)
        } catch (_: Exception) {
            null
        }
        callback.onReceiveValue(result)
    }
}
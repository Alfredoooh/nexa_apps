package com.looply.app

import android.content.Context
import android.app.DownloadManager
import android.os.Environment
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
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.URLUtil
import org.json.JSONObject
import org.json.JSONTokener
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
    private var touchStartX = 0f
    private var desktopMode = false
    private val mobileUserAgent = WebSettings.getDefaultUserAgent(context)
    private var pullTriggered = false
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop

    private val webView = WebView(context).apply {
        setBackgroundColor(Color.TRANSPARENT)
        setLayerType(View.LAYER_TYPE_HARDWARE, null)
        settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            @Suppress("DEPRECATION")
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            cacheMode = if (incognito || !cacheEnabled) WebSettings.LOAD_NO_CACHE else WebSettings.LOAD_DEFAULT
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            builtInZoomControls = false
            displayZoomControls = false
            loadsImagesAutomatically = true
            allowFileAccess = false
            allowContentAccess = false
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
                    touchStartX = event.x
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

        webView.setOnLongClickListener {
            val hit = webView.hitTestResult
            val hitType = hit.type
            val fallback = hit.extra.orEmpty()
            val isImageHit = hitType == WebView.HitTestResult.IMAGE_TYPE ||
                hitType == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
            val isLinkHit = hitType == WebView.HitTestResult.SRC_ANCHOR_TYPE ||
                hitType == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
            if (!isImageHit && !isLinkHit) {
                return@setOnLongClickListener false
            }

            val x = (touchStartX / webView.scale).coerceAtLeast(0f)
            val y = (touchStartY / webView.scale).coerceAtLeast(0f)
            val script = """(function(){
                const el=document.elementFromPoint($x,$y);
                const img=el&&(el.closest('img')||(el.tagName==='IMG'?el:null));
                const a=el&&el.closest('a');
                return JSON.stringify({
                    imageUrl:img?(img.currentSrc||img.src||''):'',
                    linkUrl:a?(a.href||''):'',
                    linkText:a?((a.innerText||a.getAttribute('aria-label')||'').trim().slice(0,180)):'',
                    imageWidth:img?(img.naturalWidth||img.width||0):0,
                    imageHeight:img?(img.naturalHeight||img.height||0):0
                });
            })()""".trimIndent()
            webView.evaluateJavascript(script) { raw ->
                try {
                    val jsonText = JSONTokener(raw ?: "").nextValue() as? String
                    val data = if (jsonText.isNullOrBlank()) JSONObject() else JSONObject(jsonText)
                    val imageUrl = data.optString("imageUrl").ifBlank {
                        if (isImageHit) fallback else ""
                    }
                    val linkUrl = data.optString("linkUrl").ifBlank {
                        if (isLinkHit && !isImageHit) fallback else ""
                    }
                    val type = if (imageUrl.isNotBlank()) "image" else if (linkUrl.isNotBlank()) "link" else ""
                    if (type.isNotBlank()) {
                        sendEvent("onLongPress", mapOf(
                            "type" to type,
                            "imageUrl" to imageUrl,
                            "linkUrl" to linkUrl,
                            "linkText" to data.optString("linkText"),
                            "imageWidth" to data.optInt("imageWidth"),
                            "imageHeight" to data.optInt("imageHeight"),
                        ))
                    }
                } catch (_: Exception) {
                    val type = if (isImageHit) "image" else "link"
                    sendEvent("onLongPress", mapOf(
                        "type" to type,
                        "imageUrl" to if (isImageHit) fallback else "",
                        "linkUrl" to if (isLinkHit && !isImageHit) fallback else "",
                    ))
                }
            }
            true
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
            "setZoom" -> {
                val scale = (call.argument<Double>("scale") ?: 1.0).coerceIn(0.5, 2.0)
                webView.settings.textZoom = (scale * 100.0).toInt()
                val encoded = scale.toString()
                webView.evaluateJavascript("document.documentElement.style.zoom='$encoded';", null)
                result.success(true)
            }
            "setDesktopMode" -> {
                desktopMode = call.argument<Boolean>("enabled") ?: false
                applyWebSettings()
                val current = webView.url
                if (!current.isNullOrBlank()) webView.loadUrl(current)
                result.success(true)
            }
            "getSiteInfo" -> {
                val pageUrl = webView.url.orEmpty()
                val cookies = CookieManager.getInstance().getCookie(pageUrl).orEmpty()
                val cookieNames = cookies.split(';')
                    .map { it.trim().substringBefore('=').trim() }
                    .filter { it.isNotBlank() }
                    .distinct()
                val script = """(function(){let memory=0,storage=0;try{if(performance&&performance.memory)memory=performance.memory.usedJSHeapSize||0}catch(e){};try{for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);storage+=((k||'').length+(localStorage.getItem(k)||'').length)*2}for(let i=0;i<sessionStorage.length;i++){const k=sessionStorage.key(i);storage+=((k||'').length+(sessionStorage.getItem(k)||'').length)*2}}catch(e){};return JSON.stringify({memoryBytes:memory,storageBytes:storage});})()"""
                webView.evaluateJavascript(script) { raw ->
                    val memoryInfo = try {
                        val jsonText = JSONTokener(raw ?: "").nextValue() as? String
                        if (jsonText.isNullOrBlank()) JSONObject() else JSONObject(jsonText)
                    } catch (_: Exception) { JSONObject() }
                    result.success(mapOf(
                        "cookieCount" to cookieNames.size,
                        "cookieNames" to cookieNames,
                        "memoryBytes" to memoryInfo.optLong("memoryBytes", 0L),
                        "storageBytes" to memoryInfo.optLong("storageBytes", 0L),
                    ))
                }
            }
            "clearSiteData" -> {
                val pageUrl = webView.url.orEmpty()
                val cookies = CookieManager.getInstance().getCookie(pageUrl).orEmpty()
                cookies.split(';').map { it.trim().substringBefore('=').trim() }
                    .filter { it.isNotBlank() }.distinct().forEach { name ->
                        CookieManager.getInstance().setCookie(pageUrl, "$name=; Max-Age=0; Path=/; SameSite=Lax")
                    }
                CookieManager.getInstance().flush()
                val script = """(function(){try{localStorage.clear()}catch(e){};try{sessionStorage.clear()}catch(e){};try{caches.keys().then(keys=>keys.forEach(k=>caches.delete(k)))}catch(e){};try{indexedDB.databases().then(dbs=>dbs.forEach(db=>db.name&&indexedDB.deleteDatabase(db.name)))}catch(e){};return true;})()"""
                webView.evaluateJavascript(script, null)
                result.success(true)
            }
            "downloadUrl" -> {
                val target = call.argument<String>("url")
                if (target.isNullOrBlank()) {
                    result.error("invalid_url", "O endereço de transferência está vazio.", null)
                } else {
                    try {
                        val request = DownloadManager.Request(Uri.parse(target))
                            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, URLUtil.guessFileName(target, null, null))
                        val cookie = CookieManager.getInstance().getCookie(target)
                        if (!cookie.isNullOrBlank()) request.addRequestHeader("Cookie", cookie)
                        request.addRequestHeader("User-Agent", webView.settings.userAgentString)
                        (context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("download_failed", error.message, null)
                    }
                }
            }
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
        webView.settings.userAgentString = if (desktopMode) {
            mobileUserAgent
                .replace(Regex("Linux; Android [^)]+"), "X11; Linux x86_64")
                .replace(" Mobile Safari/", " Safari/")
                .replace("; wv", "")
        } else {
            mobileUserAgent
        }
        webView.settings.useWideViewPort = desktopMode
        webView.settings.loadWithOverviewMode = desktopMode
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

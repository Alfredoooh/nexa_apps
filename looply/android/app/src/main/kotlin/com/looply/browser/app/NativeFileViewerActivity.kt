package com.looply.browser.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.util.Base64
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale
import java.util.zip.ZipFile

/**
 * Visualizador local de ficheiros do BrowseIt.
 * Não é uma instância do Orbit: não tem separadores, endereço ou appbar.
 * O conteúdo é apresentado por páginas HTML dedicadas em android_asset.
 */
class NativeFileViewerActivity : AppCompatActivity() {
    companion object {
        const val EXTRA_PATH = "file_path"
        const val EXTRA_NAME = "file_name"
        const val EXTRA_MIME = "file_mime"

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_THEME_MODE = "flutter.looply_theme_mode"
        private const val PREF_PURE_BLACK = "flutter.looply_theme_pure_dark"
    }

    private lateinit var webView: WebView
    private lateinit var sourceFile: File
    private var isDark = false
    private var isPureBlack = false

    private val surfaceColor: Int
        get() = when {
            !isDark -> Color.WHITE
            isPureBlack -> Color.BLACK
            else -> Color.rgb(20, 21, 23)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        readAppearance()
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        applySystemBars()

        val rawPath = intent.getStringExtra(EXTRA_PATH).orEmpty()
        sourceFile = runCatching { File(rawPath).canonicalFile }.getOrNull()
            ?: run { finish(); return }
        val appDataRoot = runCatching { File(applicationInfo.dataDir).canonicalPath }.getOrNull().orEmpty()
        if (!sourceFile.isFile || appDataRoot.isBlank() ||
            !sourceFile.path.startsWith(appDataRoot + File.separator)) {
            finish()
            return
        }

        val root = FrameLayout(this).apply {
            setBackgroundColor(surfaceColor)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(0, bars.top, 0, bars.bottom)
            insets
        }

        webView = WebView(this).apply {
            setBackgroundColor(surfaceColor)
            overScrollMode = WebView.OVER_SCROLL_NEVER
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = false
            settings.allowFileAccessFromFileURLs = true
            settings.allowUniversalAccessFromFileURLs = false
            settings.mediaPlaybackRequiresUserGesture = true
            settings.builtInZoomControls = false
            settings.displayZoomControls = false
            settings.loadsImagesAutomatically = true
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?,
                ): Boolean {
                    val scheme = request?.url?.scheme?.lowercase(Locale.ROOT)
                    // Mantém o visualizador isolado: apenas recursos locais e data URLs.
                    return scheme !in setOf("file", "data", "about", "blob")
                }
            }
            addJavascriptInterface(ViewerBridge(this@NativeFileViewerActivity), "AndroidViewer")
        }

        root.addView(
            webView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        setContentView(root)
        loadViewerPage()
    }

    private fun readAppearance() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val mode = prefs.getString(PREF_THEME_MODE, "system") ?: "system"
        isDark = when (mode) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                android.content.res.Configuration.UI_MODE_NIGHT_YES
        }
        isPureBlack = isDark && prefs.getBoolean(PREF_PURE_BLACK, false)
    }

    private fun applySystemBars() {
        // Edge-to-edge: o fundo da raiz pinta a área do sistema e mantém
        // a cor do statusbar alinhada ao tema sem criar uma appbar nativa.
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        window.setBackgroundDrawableResource(android.R.color.transparent)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.isAppearanceLightStatusBars = !isDark
        controller.isAppearanceLightNavigationBars = !isDark
        if (Build.VERSION.SDK_INT >= 29) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    private fun loadViewerPage() {
        val name = intent.getStringExtra(EXTRA_NAME)?.takeIf { it.isNotBlank() }
            ?: sourceFile.name
        val mime = intent.getStringExtra(EXTRA_MIME).orEmpty().lowercase(Locale.ROOT)
        val extension = sourceFile.extension.lowercase(Locale.ROOT)
        val kind = when {
            mime.startsWith("image/") || extension in setOf("png", "jpg", "jpeg", "gif", "webp", "bmp", "svg") -> "image"
            mime.startsWith("video/") || extension in setOf("mp4", "m4v", "mov", "webm", "mkv", "avi") -> "video"
            mime.startsWith("audio/") || extension in setOf("mp3", "m4a", "aac", "wav", "ogg", "flac") -> "audio"
            mime == "application/pdf" || extension == "pdf" -> "pdf"
            mime.startsWith("text/") || extension in setOf("txt", "rtf", "json", "xml", "html", "htm", "css", "js", "kt", "dart", "java", "yaml", "yml", "md", "csv", "log", "docx", "odt") -> "text"
            else -> "file"
        }
        val page = when (kind) {
            "image" -> "image-viewer.html"
            "video" -> "video-viewer.html"
            "audio" -> "audio-viewer.html"
            else -> "document-viewer.html"
        }
        val params = Uri.Builder()
            .appendQueryParameter("src", Uri.fromFile(sourceFile).toString())
            .appendQueryParameter("name", name)
            .appendQueryParameter("kind", kind)
            .appendQueryParameter("theme", if (isDark) "dark" else "light")
            .appendQueryParameter("pure", if (isPureBlack) "1" else "0")
            .build()
            .encodedQuery
        webView.loadUrl("file:///android_asset/screens/$page?$params")
    }

    private fun readTextDocument(): String {
        return runCatching {
            if (sourceFile.length() > 8L * 1024L * 1024L) {
                "O documento é demasiado grande para ser apresentado neste visualizador."
            } else {
                val ext = sourceFile.extension.lowercase(Locale.ROOT)
                val text = when (ext) {
                    "docx" -> extractOfficeXml("word/document.xml")
                    "odt" -> extractOfficeXml("content.xml")
                    else -> sourceFile.readText(Charsets.UTF_8)
                }
                Base64.encodeToString(text.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
            }
        }.getOrElse {
            Base64.encodeToString("Não foi possível ler este documento.".toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
        }
    }

    private fun extractOfficeXml(entryName: String): String {
        val xml = ZipFile(sourceFile).use { archive ->
            val entry = archive.getEntry(entryName)
                ?: throw IllegalArgumentException("O documento não contém conteúdo legível.")
            archive.getInputStream(entry).bufferedReader(Charsets.UTF_8).use { it.readText() }
        }
        return xml
            .replace(Regex("</(?:w:p|text:p|table:table-row)\\s*>"), "\n")
            .replace(Regex("<w:tab\\s*/>"), "\t")
            .replace(Regex("<[^>]+>"), "")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&apos;", "'")
    }

    private fun pdfPageCount(): Int {
        return runCatching {
            ParcelFileDescriptor.open(sourceFile, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                PdfRenderer(descriptor).use { it.pageCount }
            }
        }.getOrDefault(0)
    }

    private fun renderPdfPage(pageIndex: Int): String {
        return runCatching {
            ParcelFileDescriptor.open(sourceFile, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                PdfRenderer(descriptor).use { renderer ->
                    if (pageIndex !in 0 until renderer.pageCount) return@use ""
                    renderer.openPage(pageIndex).use { page ->
                        val targetWidth = 1200
                        val ratio = targetWidth.toFloat() / page.width.coerceAtLeast(1)
                        val targetHeight = (page.height * ratio).toInt().coerceIn(1, 4000)
                        val bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val output = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)
                        bitmap.recycle()
                        Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
                    }
                }
            }
        }.getOrDefault("")
    }

    inner class ViewerBridge(private val activity: NativeFileViewerActivity) {
        @JavascriptInterface
        fun close() {
            activity.runOnUiThread { activity.closeViewer() }
        }

        @JavascriptInterface
        fun getTextDocument(): String = activity.readTextDocument()

        @JavascriptInterface
        fun getPdfPageCount(): Int = activity.pdfPageCount()

        @JavascriptInterface
        fun getPdfPageData(index: Int): String = activity.renderPdfPage(index)
    }

    private fun closeViewer() {
        if (isFinishing) return
        finish()
        overridePendingTransition(0, R.anim.browser_slide_down)
    }

    @Deprecated("Deprecated by Android; retained for back-button compatibility")
    override fun onBackPressed() {
        closeViewer()
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.removeJavascriptInterface("AndroidViewer")
            webView.destroy()
        }
        super.onDestroy()
    }
}

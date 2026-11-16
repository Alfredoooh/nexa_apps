package com.looply.browser.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.MediaController
import android.widget.SeekBar
import android.widget.ScrollView
import android.widget.TextView
import android.widget.VideoView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import java.io.File
import java.io.FileInputStream
import com.caverock.androidsvg.SVG
import java.util.Locale
import java.util.zip.ZipFile

/**
 * Visualizador local de ficheiros inteiramente nativo.
 * Imagens, vídeos, áudio, PDF e documentos de texto usam Views Android;
 * não existe WebView nem dependência de páginas HTML internas.
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

    private lateinit var sourceFile: File
    private lateinit var rootContainer: LinearLayout
    private lateinit var contentHost: FrameLayout
    private lateinit var fileName: String
    private lateinit var mimeType: String

    private var isDark = false
    private var isPureBlack = false
    private var videoView: VideoView? = null
    private var mediaController: MediaController? = null
    private var mediaPlayer: MediaPlayer? = null
    private var audioSeekBar: SeekBar? = null
    private var audioTimeLabel: TextView? = null
    private var audioPlayLabel: TextView? = null
    private val handler = Handler(Looper.getMainLooper())
    private var audioPrepared = false
    private var pdfDescriptor: ParcelFileDescriptor? = null
    private var pdfRenderer: PdfRenderer? = null
    private var pdfPageIndex = 0
    private var pdfPageImage: ImageView? = null
    private var pdfPageLabel: TextView? = null
    private var pdfPageBitmap: Bitmap? = null

    private val surfaceColor: Int
        get() = when {
            !isDark -> Color.WHITE
            isPureBlack -> Color.BLACK
            else -> Color.rgb(20, 21, 23)
        }

    private val secondarySurface: Int
        get() = when {
            !isDark -> Color.rgb(242, 243, 245)
            isPureBlack -> Color.rgb(25, 25, 25)
            else -> Color.rgb(40, 42, 45)
        }

    private val textColor: Int
        get() = if (isDark) Color.rgb(238, 239, 241) else Color.rgb(32, 33, 36)

    private val mutedColor: Int
        get() = if (isDark) Color.rgb(174, 178, 184) else Color.rgb(95, 99, 104)

    private val accentColor: Int
        get() = if (isDark) Color.rgb(138, 180, 248) else Color.rgb(26, 115, 232)

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
        val downloadsDirectory = sourceFile.parentFile?.canonicalFile
        val internalRoot = File(applicationInfo.dataDir).canonicalFile
        if (downloadsDirectory == null ||
            !downloadsDirectory.path.startsWith(internalRoot.path + File.separator) ||
            downloadsDirectory.name != "downloads") {
            finish()
            return
        }

        fileName = intent.getStringExtra(EXTRA_NAME)?.takeIf { it.isNotBlank() } ?: sourceFile.name
        mimeType = intent.getStringExtra(EXTRA_MIME).orEmpty().lowercase(Locale.ROOT)

        createNativeLayout()
        showFileContent()
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = closeViewer()
        })
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
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        window.setBackgroundDrawableResource(android.R.color.transparent)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.isAppearanceLightStatusBars = !isDark
        controller.isAppearanceLightNavigationBars = !isDark
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_DEFAULT
        controller.show(WindowInsetsCompat.Type.systemBars())
        if (Build.VERSION.SDK_INT >= 29) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    private fun createNativeLayout() {
        rootContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(surfaceColor)
            layoutParams = ViewGroup.LayoutParams(-1, -1)
        }
        ViewCompat.setOnApplyWindowInsetsListener(rootContainer) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(0, bars.top, 0, bars.bottom)
            insets
        }

        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), dp(4), dp(10), dp(4))
            setBackgroundColor(surfaceColor)
        }
        toolbar.addView(iconButton("arrow_back", "Voltar", ::closeViewer), LinearLayout.LayoutParams(dp(48), dp(48)))
        toolbar.addView(TextView(this).apply {
            text = fileName
            setTextColor(textColor)
            textSize = 16f
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.MIDDLE
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, dp(8), 0)
        }, LinearLayout.LayoutParams(0, -1, 1f))
        val extensionLabel = sourceFile.extension.uppercase(Locale.ROOT).ifBlank { "FILE" }
        toolbar.addView(TextView(this).apply {
            text = extensionLabel
            setTextColor(accentColor)
            textSize = 10.5f
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            background = roundedDrawable(secondarySurface, dp(9).toFloat())
            setPadding(dp(9), dp(6), dp(9), dp(6))
        }, LinearLayout.LayoutParams(-2, dp(30)).apply { marginStart = dp(6) })
        rootContainer.addView(toolbar, LinearLayout.LayoutParams(-1, dp(60)))

        contentHost = FrameLayout(this).apply {
            setBackgroundColor(surfaceColor)
            layoutParams = LinearLayout.LayoutParams(-1, 0, 1f)
        }
        rootContainer.addView(contentHost, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(rootContainer)
    }

    private fun iconButton(symbol: String, description: String, action: () -> Unit): View {
        return FrameLayout(this).apply {
            isClickable = true
            isFocusable = true
            contentDescription = description
            background = selectableBackground()
            addView(
                MaterialSymbolsRounded.textView(this@NativeFileViewerActivity, symbol, textColor, 24f),
                FrameLayout.LayoutParams(dp(24), dp(24), Gravity.CENTER),
            )
            setOnClickListener { action() }
        }
    }

    private fun showFileContent() {
        val extension = sourceFile.extension.lowercase(Locale.ROOT)
        val kind = when {
            mimeType.startsWith("image/") || extension in setOf("png", "jpg", "jpeg", "gif", "webp", "bmp", "svg") -> "image"
            mimeType.startsWith("video/") || extension in setOf("mp4", "m4v", "mov", "webm", "mkv", "avi", "3gp") -> "video"
            mimeType.startsWith("audio/") || extension in setOf("mp3", "m4a", "aac", "ogg", "wav", "flac", "opus") -> "audio"
            mimeType == "application/pdf" || extension == "pdf" -> "pdf"
            isReadableDocument(extension, mimeType) -> "text"
            else -> "unsupported"
        }

        when (kind) {
            "image" -> showImage()
            "video" -> showVideo()
            "audio" -> showAudio()
            "pdf" -> showPdf()
            "text" -> showTextDocument()
            else -> showUnsupportedFile()
        }
    }

    private fun isReadableDocument(extension: String, mime: String): Boolean {
        if (mime.startsWith("text/")) return true
        return extension in setOf(
            "txt", "rtf", "json", "xml", "html", "htm", "css", "js", "kt", "dart", "java",
            "yaml", "yml", "md", "csv", "log", "docx", "odt", "pptx", "xlsx"
        )
    }

    private fun showImage() {
        contentHost.setPadding(dp(14), dp(14), dp(14), dp(14))
        val imageFrame = FrameLayout(this).apply {
            background = roundedDrawable(secondarySurface, dp(24).toFloat())
            clipToOutline = true
        }
        val image = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
            contentDescription = fileName
        }
        imageFrame.addView(image, FrameLayout.LayoutParams(-1, -1, Gravity.CENTER).apply {
            setMargins(dp(6), dp(6), dp(6), dp(6))
        })
        contentHost.addView(imageFrame, FrameLayout.LayoutParams(-1, -1, Gravity.CENTER))
        image.post {
            if (isFinishing || isDestroyed) return@post
            val bitmap = if (sourceFile.extension.equals("svg", ignoreCase = true)) {
                runCatching {
                    val picture = FileInputStream(sourceFile).use { input ->
                        SVG.getFromInputStream(input).renderToPicture()
                    }
                    val width = picture.width.coerceIn(1, 2400)
                    val height = picture.height.coerceIn(1, 3000)
                    Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { output ->
                        Canvas(output).drawPicture(picture)
                    }
                }.getOrNull()
            } else {
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(sourceFile.absolutePath, options)
                val requestedWidth = image.width.coerceAtLeast(1)
                val requestedHeight = image.height.coerceAtLeast(1)
                var sample = 1
                while (options.outWidth / (sample * 2) >= requestedWidth &&
                    options.outHeight / (sample * 2) >= requestedHeight) {
                    sample *= 2
                }
                BitmapFactory.decodeFile(sourceFile.absolutePath, BitmapFactory.Options().apply {
                    inSampleSize = sample
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                })
            }
            if (bitmap != null) image.setImageBitmap(bitmap) else showMessage("Não foi possível descodificar esta imagem.")
        }
    }

    private fun showVideo() {
        val player = VideoView(this).apply {
            setBackgroundColor(Color.BLACK)
            setVideoURI(Uri.fromFile(sourceFile))
        }
        videoView = player
        contentHost.setBackgroundColor(Color.BLACK)
        contentHost.addView(player, FrameLayout.LayoutParams(-1, -1, Gravity.CENTER))
        mediaController = MediaController(this).also { controller ->
            controller.setAnchorView(player)
            player.setMediaController(controller)
        }
        player.setOnPreparedListener { media ->
            media.isLooping = false
            mediaController?.show(3500)
        }
        player.setOnTouchListener { _, event ->
            if (event.action == android.view.MotionEvent.ACTION_UP) {
                if (player.isPlaying) player.pause() else player.start()
                mediaController?.show(3500)
            }
            true
        }
        player.setOnErrorListener { _, _, _ ->
            showMessage("Não foi possível reproduzir este vídeo neste dispositivo.")
            true
        }
    }

    private fun showAudio() {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(22), dp(28), dp(22), dp(28))
        }
        val artwork = FrameLayout(this).apply {
            background = roundedDrawable(secondarySurface, dp(34).toFloat())
            addView(
                MaterialSymbolsRounded.textView(this@NativeFileViewerActivity, "audio_file", accentColor, 42f),
                FrameLayout.LayoutParams(dp(88), dp(88), Gravity.CENTER),
            )
        }
        container.addView(artwork, LinearLayout.LayoutParams(dp(148), dp(148)).apply { bottomMargin = dp(26) })
        container.addView(TextView(this).apply {
            text = fileName
            setTextColor(textColor)
            textSize = 18f
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            maxLines = 2
            ellipsize = android.text.TextUtils.TruncateAt.END
        }, LinearLayout.LayoutParams(-1, -2))
        container.addView(TextView(this).apply {
            text = "Áudio local"
            setTextColor(mutedColor)
            textSize = 13f
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(6) })

        val seek = SeekBar(this).apply {
            progressTintList = android.content.res.ColorStateList.valueOf(accentColor)
            thumbTintList = android.content.res.ColorStateList.valueOf(accentColor)
            max = 1000
        }
        audioSeekBar = seek
        container.addView(seek, LinearLayout.LayoutParams(-1, dp(48)).apply {
            topMargin = dp(24)
            bottomMargin = dp(2)
        })
        val time = TextView(this).apply {
            text = "00:00 / 00:00"
            setTextColor(mutedColor)
            textSize = 12f
            gravity = Gravity.CENTER
        }
        audioTimeLabel = time
        container.addView(time, LinearLayout.LayoutParams(-1, -2))

        val playButton = FrameLayout(this).apply {
            background = roundedDrawable(accentColor, dp(99).toFloat())
            isClickable = true
            isFocusable = true
            addView(
                MaterialSymbolsRounded.textView(this@NativeFileViewerActivity, "play_arrow", Color.WHITE, 32f),
                FrameLayout.LayoutParams(dp(38), dp(38), Gravity.CENTER),
            )
        }
        audioPlayLabel = playButton.getChildAt(0) as? TextView
        playButton.setOnClickListener { toggleAudioPlayback() }
        container.addView(playButton, LinearLayout.LayoutParams(dp(76), dp(76)).apply { topMargin = dp(24) })
        contentHost.addView(container, FrameLayout.LayoutParams(-1, -1, Gravity.CENTER))

        seek.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar?, progress: Int, fromUser: Boolean) {
                val player = mediaPlayer
                if (fromUser && audioPrepared && player != null) {
                    player.seekTo((progress / 1000f * player.duration).toInt())
                    updateAudioTime()
                }
            }
            override fun onStartTrackingTouch(bar: SeekBar?) = Unit
            override fun onStopTrackingTouch(bar: SeekBar?) = Unit
        })

        mediaPlayer = MediaPlayer().apply {
            setOnPreparedListener { player ->
                audioPrepared = true
                seek.max = 1000
                seek.isEnabled = true
                updateAudioTime()
            }
            setOnCompletionListener {
                audioPlayLabel?.text = "play_arrow"
                audioSeekBar?.progress = 0
                updateAudioTime()
            }
            setOnErrorListener { _, _, _ ->
                showMessage("Não foi possível reproduzir este áudio neste dispositivo.")
                true
            }
            runCatching {
                setDataSource(sourceFile.absolutePath)
                seek.isEnabled = false
                prepareAsync()
            }.onFailure {
                showMessage("Não foi possível abrir este ficheiro de áudio.")
            }
        }
        handler.post(audioProgressRunnable)
    }

    private val audioProgressRunnable = object : Runnable {
        override fun run() {
            if (audioPrepared && mediaPlayer != null && !isFinishing) updateAudioTime()
            handler.postDelayed(this, 450L)
        }
    }

    private fun toggleAudioPlayback() {
        val player = mediaPlayer ?: return
        if (!audioPrepared) return
        if (player.isPlaying) {
            player.pause()
            audioPlayLabel?.text = "play_arrow"
        } else {
            player.start()
            audioPlayLabel?.text = "pause"
        }
        updateAudioTime()
    }

    private fun updateAudioTime() {
        val player = mediaPlayer ?: return
        if (!audioPrepared) return
        val duration = player.duration.coerceAtLeast(0)
        val position = player.currentPosition.coerceIn(0, duration)
        audioSeekBar?.progress = if (duration == 0) 0 else (position * 1000L / duration).toInt()
        audioTimeLabel?.text = "${formatTime(position)} / ${formatTime(duration)}"
        audioPlayLabel?.text = if (player.isPlaying) "pause" else "play_arrow"
    }

    private fun formatTime(milliseconds: Int): String {
        val totalSeconds = (milliseconds / 1000).coerceAtLeast(0)
        return String.format(Locale.getDefault(), "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private fun showPdf() {
        val descriptor = runCatching {
            ParcelFileDescriptor.open(sourceFile, ParcelFileDescriptor.MODE_READ_ONLY)
        }.getOrNull()
        if (descriptor == null) {
            showMessage("Não foi possível abrir este documento PDF.")
            return
        }
        pdfDescriptor = descriptor
        pdfRenderer = runCatching { PdfRenderer(descriptor) }.getOrNull()
        val renderer = pdfRenderer
        if (renderer == null || renderer.pageCount <= 0) {
            showMessage("Este documento PDF não contém páginas legíveis.")
            return
        }

        val pageFrame = FrameLayout(this).apply { setBackgroundColor(secondarySurface) }
        pdfPageImage = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
            setBackgroundColor(Color.WHITE)
        }
        pageFrame.addView(pdfPageImage, FrameLayout.LayoutParams(-1, -1).apply {
            setMargins(dp(10), dp(10), dp(10), dp(10))
        })
        contentHost.addView(pageFrame, FrameLayout.LayoutParams(-1, -1))
        val pageControls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(6), dp(16), dp(6))
            setBackgroundColor(surfaceColor)
        }
        val previous = iconButton("chevron_left", "Página anterior") {
            showPdfPage((pdfPageIndex - 1).coerceAtLeast(0))
        }
        val next = iconButton("chevron_right", "Página seguinte") {
            showPdfPage((pdfPageIndex + 1).coerceAtMost(renderer.pageCount - 1))
        }
        pageControls.addView(previous, LinearLayout.LayoutParams(dp(48), dp(48)))
        pdfPageLabel = TextView(this).apply {
            setTextColor(mutedColor)
            textSize = 13f
            gravity = Gravity.CENTER
        }
        pageControls.addView(pdfPageLabel, LinearLayout.LayoutParams(0, -1, 1f))
        pageControls.addView(next, LinearLayout.LayoutParams(dp(48), dp(48)))
        // O rodapé é nativo e fica abaixo da área de visualização.
        rootContainer.addView(pageControls, LinearLayout.LayoutParams(-1, dp(64)))
        pageFrame.post { showPdfPage(0) }
    }

    private fun showPdfPage(index: Int) {
        val renderer = pdfRenderer ?: return
        if (index !in 0 until renderer.pageCount) return
        val image = pdfPageImage ?: return
        pdfPageIndex = index
        val bitmap = runCatching {
            renderer.openPage(index).use { page ->
                val targetWidth = contentHost.width.coerceAtLeast(1).coerceAtMost(1800)
                val scale = targetWidth.toFloat() / page.width.coerceAtLeast(1)
                val targetHeight = (page.height * scale).toInt().coerceIn(1, 3000)
                Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888).also { output ->
                    output.eraseColor(Color.WHITE)
                    page.render(output, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                }
            }
        }.getOrNull()
        if (bitmap == null) {
            showMessage("Não foi possível renderizar esta página PDF.")
            return
        }
        val oldBitmap = pdfPageBitmap
        pdfPageBitmap = bitmap
        image.setImageBitmap(bitmap)
        if (oldBitmap != null && !oldBitmap.isRecycled) oldBitmap.recycle()
        pdfPageLabel?.text = "${index + 1} / ${renderer.pageCount}"
    }

    private fun showTextDocument() {
        val content = readTextDocument()
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(secondarySurface)
            clipToPadding = false
            setPadding(dp(12), dp(12), dp(12), dp(16))
        }
        val text = TextView(this).apply {
            text = content
            setTextColor(textColor)
            textSize = 15f
            setLineSpacing(dp(3).toFloat(), 1f)
            setTextIsSelectable(true)
            setPadding(dp(22), dp(24), dp(22), dp(34))
            typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL)
            background = roundedDrawable(surfaceColor, dp(18).toFloat())
        }
        scroll.addView(text, ViewGroup.LayoutParams(-1, -2))
        contentHost.addView(scroll, FrameLayout.LayoutParams(-1, -1))
    }

    private fun readTextDocument(): String {
        return runCatching {
            val extension = sourceFile.extension.lowercase(Locale.ROOT)
            if (sourceFile.length() > 8L * 1024L * 1024L) {
                return@runCatching "O ficheiro é demasiado grande para a pré-visualização de texto.\n\n${sourceFile.name}"
            }
            when (extension) {
                "docx" -> extractOfficeXml("word/document.xml")
                "odt" -> extractOfficeXml("content.xml")
                "pptx" -> extractPresentationXml()
                "xlsx" -> extractSpreadsheetXml()
                "rtf" -> sourceFile.readText(Charsets.UTF_8)
                    .replace(Regex("\\\\'[0-9a-fA-F]{2}"), " ")
                    .replace(Regex("\\\\[a-zA-Z]+-?\\d* ?"), "")
                    .replace(Regex("[{}]"), "")
                else -> sourceFile.readText(Charsets.UTF_8)
            }
        }.getOrElse {
            "Não foi possível ler o conteúdo deste documento.\n\n${sourceFile.name}"
        }
    }

    private fun extractOfficeXml(entryName: String): String {
        val xml = ZipFile(sourceFile).use { archive ->
            val entry = archive.getEntry(entryName)
                ?: throw IllegalArgumentException("O documento não contém conteúdo legível.")
            archive.getInputStream(entry).bufferedReader(Charsets.UTF_8).use { it.readText() }
        }
        return cleanOfficeXml(xml)
    }

    private fun extractPresentationXml(): String {
        val entries = ZipFile(sourceFile).use { archive ->
            archive.entries().asSequence()
                .filter { !it.isDirectory && it.name.startsWith("ppt/slides/slide") && it.name.endsWith(".xml") }
                .sortedBy { it.name }
                .map { entry -> archive.getInputStream(entry).bufferedReader(Charsets.UTF_8).use { it.readText() } }
                .toList()
        }
        return entries.mapIndexed { index, xml -> "Página ${index + 1}\n${cleanOfficeXml(xml)}" }.joinToString("\n\n")
    }

    private fun extractSpreadsheetXml(): String {
        val entries = ZipFile(sourceFile).use { archive ->
            archive.entries().asSequence()
                .filter { !it.isDirectory && it.name.startsWith("xl/worksheets/sheet") && it.name.endsWith(".xml") }
                .sortedBy { it.name }
                .map { entry -> archive.getInputStream(entry).bufferedReader(Charsets.UTF_8).use { it.readText() } }
                .toList()
        }
        return entries.mapIndexed { index, xml -> "Folha ${index + 1}\n${cleanOfficeXml(xml)}" }.joinToString("\n\n")
    }

    private fun cleanOfficeXml(xml: String): String {
        return xml
            .replace(Regex("</(?:w:p|a:p|text:p|table:table-row|row)\\s*>"), "\n")
            .replace(Regex("<w:tab\\s*/>"), "\t")
            .replace(Regex("<[^>]+>"), "")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&apos;", "'")
            .replace(Regex("[\\t ]+\\n"), "\n")
            .trim()
    }

    private fun showUnsupportedFile() {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(30), dp(28), dp(30), dp(28))
            background = roundedDrawable(secondarySurface, dp(28).toFloat())
        }
        container.addView(
            MaterialSymbolsRounded.textView(this, "description", mutedColor, 54f),
            LinearLayout.LayoutParams(dp(68), dp(68)).apply { bottomMargin = dp(18) },
        )
        container.addView(TextView(this).apply {
            text = "Pré-visualização não disponível"
            setTextColor(textColor)
            textSize = 18f
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(-1, -2))
        container.addView(TextView(this).apply {
            text = "$fileName\n${mimeType.ifBlank { "Ficheiro ${sourceFile.extension.uppercase(Locale.ROOT)}" }}\n${formatFileSize(sourceFile.length())}"
            setTextColor(mutedColor)
            textSize = 13f
            gravity = Gravity.CENTER
            setLineSpacing(dp(4).toFloat(), 1f)
        }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(10) })
        contentHost.addView(container, FrameLayout.LayoutParams(-1, -1))
    }

    private fun showMessage(message: String) {
        if (isFinishing) return
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
    }

    private fun formatFileSize(bytes: Long): String {
        return when {
            bytes >= 1024L * 1024L -> String.format(Locale.getDefault(), "%.1f MB", bytes / (1024f * 1024f))
            bytes >= 1024L -> String.format(Locale.getDefault(), "%.0f KB", bytes / 1024f)
            else -> "$bytes B"
        }
    }

    private fun roundedDrawable(color: Int, radius: Float) = android.graphics.drawable.GradientDrawable().apply {
        shape = android.graphics.drawable.GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = radius
    }

    private fun selectableBackground(): android.graphics.drawable.Drawable {
        val value = android.util.TypedValue()
        theme.resolveAttribute(android.R.attr.selectableItemBackground, value, true)
        return if (value.resourceId != 0) getDrawable(value.resourceId)!!
        else android.graphics.drawable.ColorDrawable(Color.TRANSPARENT)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun closeViewer() {
        if (isFinishing) return
        finish()
        overridePendingTransition(0, R.anim.browser_slide_down)
    }

    override fun onPause() {
        videoView?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        handler.removeCallbacks(audioProgressRunnable)
        runCatching { mediaPlayer?.stop() }
        runCatching { mediaPlayer?.release() }
        mediaPlayer = null
        videoView?.stopPlayback()
        videoView = null
        mediaController = null
        runCatching { pdfPageBitmap?.recycle() }
        pdfPageBitmap = null
        runCatching { pdfRenderer?.close() }
        pdfRenderer = null
        runCatching { pdfDescriptor?.close() }
        pdfDescriptor = null
        super.onDestroy()
    }
}

package com.looply.browser.app

import android.Manifest
import android.app.DownloadManager
import android.app.role.RoleManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SwitchCompat
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.looply.browser.app.browser.LooplyAdBlocker
import com.looply.browser.app.data.LooplyCloudSync
import com.looply.browser.app.data.LooplyStore
import com.looply.browser.app.data.LooplyTab
import com.looply.browser.app.ui.LooplyIconView
import com.looply.browser.app.ui.LooplyPalette
import com.looply.browser.app.ui.assetImage
import com.looply.browser.app.ui.cardText
import com.looply.browser.app.ui.dp
import com.looply.browser.app.ui.iconButton
import com.looply.browser.app.ui.label
import com.looply.browser.app.ui.linear
import com.looply.browser.app.ui.ripple
import com.looply.browser.app.ui.rounded
import com.looply.browser.app.ui.subLabel
import com.looply.browser.app.ui.textView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.net.URLEncoder
import java.security.SecureRandom
import java.util.Locale
import java.util.UUID

class MainActivity : AppCompatActivity() {
    private lateinit var store: LooplyStore
    private lateinit var cloudSync: LooplyCloudSync
    private lateinit var host: FrameLayout
    private var palette = LooplyPalette(false, false, Color.WHITE, Color.WHITE, 0xFFF0F1F3.toInt(), 0xFFF8F9FA.toInt(), 0xFF202124.toInt(), 0xFF5F6368.toInt(), 0xFFE8EAED.toInt(), 0xFF1A73E8.toInt())
    private var themeMode = "system"
    private var pureBlack = false
    private var currentScreen = "home"
    private val backStack = ArrayDeque<String>()
    private var activeTab: LooplyTab? = null
    private val tabs = mutableListOf<LooplyTab>()
    private var currentWebView: WebView? = null
    private var currentProgress: ProgressBar? = null
    private var currentAddress: TextView? = null
    private var currentBrowserTitle = ""
    private var currentBrowserToolbar: View? = null
    private var currentAddressPill: View? = null
    private var drawerOverlay: View? = null
    private var drawerPanel: View? = null
    private var pendingWebPermission: PermissionRequest? = null
    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null
    private var lastSearchEngine = "Google"
    private var lastSearchText = ""
    private var browserToolbarColor: Int? = null
    private val handler = Handler(Looper.getMainLooper())
    private val splashRemoval = Runnable { hideSplash() }
    private var splashView: ShimmerSplashView? = null
    private var homeBottom: View? = null
    private var pageRoot: LinearLayout? = null
    private var isIncognito = false

    private val filePicker = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val callback = fileChooserCallback ?: return@registerForActivityResult
        val uris = if (result.resultCode == RESULT_OK) {
            val data = result.data
            when {
                data?.clipData != null -> Array(data.clipData!!.itemCount) { index -> data.clipData!!.getItemAt(index).uri }
                data?.data != null -> arrayOf(data.data!!)
                else -> emptyArray()
            }
        } else emptyArray()
        callback.onReceiveValue(uris)
        fileChooserCallback = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, true)
        store = LooplyStore(this)
        cloudSync = LooplyCloudSync(this, store)
        themeMode = store.getString("flutter.looply_theme_mode", "system").ifBlank { "system" }
        pureBlack = store.getBoolean("flutter.looply_theme_pure_dark", false)
        palette = LooplyPalette.resolve(this, themeMode, pureBlack)
        applySystemTheme()
        tabs.clear()
        tabs.addAll(store.loadTabs())
        val savedActiveTabId = store.getString("flutter.looply_active_tab_v1")
        activeTab = tabs.firstOrNull { it.id == savedActiveTabId } ?: tabs.lastOrNull()
        lastSearchEngine = store.getString("flutter.looply_search_engine", "Google")
        LooplyAdBlocker.enabled = store.getBoolean("flutter.looply_ad_block_enabled", true)
        setContentView(R.layout.activity_main)
        host = findViewById(R.id.looplyRoot)
        host.setBackgroundColor(palette.background)
        renderCurrent()
        showSplash()
        consumeIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeIncomingIntent(intent)
    }

    private fun consumeIncomingIntent(source: Intent?) {
        val url = source?.dataString ?: return
        if (url.startsWith("http://") || url.startsWith("https://")) openBrowser(url, false)
    }

    private fun showSplash() {
        val view = ShimmerSplashView(this, palette.dark, palette.pureBlack)
        splashView = view
        host.addView(view, FrameLayout.LayoutParams(-1, -1))
        handler.removeCallbacks(splashRemoval)
        handler.postDelayed(splashRemoval, 3000L)
    }

    private fun hideSplash() {
        val overlay = splashView ?: return
        overlay.animate().alpha(0f).setDuration(260L).withEndAction {
            (overlay.parent as? ViewGroup)?.removeView(overlay)
            overlay.dispose()
            if (splashView === overlay) splashView = null
        }.start()
    }

    private fun renderCurrent() {
        showScreen(currentScreen, addToStack = false)
    }

    private fun applySystemTheme() {
        palette = LooplyPalette.resolve(this, themeMode, pureBlack)
        LooplyPalette.applyToWindow(window, palette)
        if (currentScreen == "browser") applyBrowserChromeColor(browserToolbarColor ?: palette.background)
    }

    private fun applyBrowserChromeColor(color: Int) {
        window.statusBarColor = color
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars =
            ColorUtils.calculateLuminance(color) > 0.48
        currentBrowserToolbar?.setBackgroundColor(color)
        currentAddressPill?.background = rounded(palette.pill, 22f, this)
        window.navigationBarColor = palette.background
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        if (themeMode == "system") {
            applySystemTheme()
            renderCurrent()
        }
    }

    override fun onResume() {
        super.onResume()
        applySystemTheme()
    }

    override fun onPause() {
        persistTabs()
        currentWebView?.let { web ->
            val url = web.url.orEmpty()
            if (!isIncognito && url.startsWith("http")) saveLastPage(url, web.title.orEmpty())
            try { CookieManager.getInstance().flush() } catch (_: Exception) { }
        }
        super.onPause()
    }

    override fun onDestroy() {
        handler.removeCallbacks(splashRemoval)
        currentWebView?.apply {
            stopLoading()
            webChromeClient = null
            webViewClient = null
            removeAllViews()
            destroy()
        }
        currentWebView = null
        splashView?.dispose()
        splashView = null
        pendingWebPermission?.let { permission -> try { permission.deny() } catch (_: Exception) { } }
        pendingWebPermission = null
        pendingGeoCallback = null
        pendingGeoOrigin = ""
        fileChooserCallback?.onReceiveValue(null)
        fileChooserCallback = null
        drawerOverlay = null
        drawerPanel = null
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        when {
            drawerOverlay != null -> closeDrawer()
            currentScreen == "browser" && currentWebView?.canGoBack() == true -> currentWebView?.goBack()
            currentScreen == "browser" -> { currentWebView?.stopLoading(); showScreen("home", addToStack = false) }
            backStack.isNotEmpty() -> showScreen(backStack.removeLast(), addToStack = false)
            else -> super.onBackPressed()
        }
    }

    private fun navigate(route: String) {
        if (route == currentScreen) return
        backStack.addLast(currentScreen)
        showScreen(route, addToStack = false)
    }

    private fun showScreen(route: String, addToStack: Boolean = false) {
        if (addToStack && route != currentScreen) backStack.addLast(currentScreen)
        closeDrawerImmediately()
        if (currentWebView != null && (route != "browser" || currentScreen == "browser")) disposeCurrentWebView()
        currentScreen = route
        host.removeAllViews()
        pageRoot = null
        homeBottom = null
        when (route) {
            "home" -> host.addView(buildHome(), FrameLayout.LayoutParams(-1, -1))
            "activity" -> host.addView(buildActivity(), FrameLayout.LayoutParams(-1, -1))
            "browser" -> host.addView(buildBrowser(), FrameLayout.LayoutParams(-1, -1))
            "tabs" -> host.addView(buildTabs(), FrameLayout.LayoutParams(-1, -1))
            "profile" -> host.addView(buildProfile(), FrameLayout.LayoutParams(-1, -1))
            "auth" -> host.addView(buildAuth(), FrameLayout.LayoutParams(-1, -1))
            "search" -> host.addView(buildSearch(), FrameLayout.LayoutParams(-1, -1))
            "settings" -> host.addView(buildSettings(), FrameLayout.LayoutParams(-1, -1))
            "history" -> host.addView(buildHistory(), FrameLayout.LayoutParams(-1, -1))
            "bookmarks" -> host.addView(buildBookmarks(), FrameLayout.LayoutParams(-1, -1))
            "downloads" -> host.addView(buildDownloads(), FrameLayout.LayoutParams(-1, -1))
            "all_sites" -> host.addView(buildAllSites(), FrameLayout.LayoutParams(-1, -1))
            "language" -> host.addView(buildLanguage(), FrameLayout.LayoutParams(-1, -1))
            "ad_calendar" -> host.addView(buildAdCalendar(), FrameLayout.LayoutParams(-1, -1))
            "site_usage" -> host.addView(buildSiteUsage(), FrameLayout.LayoutParams(-1, -1))
            "app_info" -> host.addView(buildAppInfo(), FrameLayout.LayoutParams(-1, -1))
            "security" -> host.addView(buildSecurity(), FrameLayout.LayoutParams(-1, -1))
            else -> host.addView(buildHome(), FrameLayout.LayoutParams(-1, -1))
        }
        applySystemTheme()
    }

    private fun shellContainer(content: View, selected: Int): View {
        val root = linear(this, true).apply { setBackgroundColor(palette.background) }
        root.addView(content, LinearLayout.LayoutParams(-1, 0, 1f))
        if (selected >= 0) root.addView(buildBottomNavigation(selected), LinearLayout.LayoutParams(-1, dp(64)))
        return root
    }

    private fun buildBottomNavigation(selected: Int): View {
        val bar = FrameLayout(this).apply { setBackgroundColor(palette.background) }
        val row = linear(this).apply { gravity = Gravity.CENTER_VERTICAL }
        val selectedIndicator = View(this).apply {
            background = rounded(if (palette.dark) palette.pill else 0x261A73E8, 50f, this@MainActivity)
        }
        val screenWidthDp = (resources.displayMetrics.widthPixels / resources.displayMetrics.density).toInt()
        val itemWidthDp = screenWidthDp / 3
        val indicator = FrameLayout.LayoutParams(dp(itemWidthDp - 14), dp(48)).apply {
            leftMargin = dp(7 + selected * itemWidthDp)
            topMargin = dp(3)
        }
        if (selected in 0..1) bar.addView(selectedIndicator, indicator)
        val home = bottomItem("house", "Início", selected == 0) { showScreen("home", false) }
        val activity = bottomItem("clock-counter-clockwise", "Atividade", selected == 1) { showScreen("activity", false) }
        val tabsItem = FrameLayout(this).apply {
            isClickable = true; isFocusable = true; setOnClickListener { showScreen("tabs") }
            val count = TextView(this@MainActivity).apply {
                text = if (tabs.size > 99) "99+" else tabs.size.toString()
                textSize = 11f; setTextColor(palette.muted); typeface = Typeface.DEFAULT_BOLD; gravity = Gravity.CENTER
                background = rounded(Color.TRANSPARENT, 6f, this@MainActivity, palette.muted, 1.6f)
            }
            addView(count, FrameLayout.LayoutParams(dp(24), dp(24), Gravity.CENTER))
        }
        row.addView(home, LinearLayout.LayoutParams(0, -1, 1f))
        row.addView(activity, LinearLayout.LayoutParams(0, -1, 1f))
        row.addView(tabsItem, LinearLayout.LayoutParams(0, -1, 1f))
        bar.addView(row, FrameLayout.LayoutParams(-1, dp(56), Gravity.TOP))
        return bar
    }

    private fun bottomItem(icon: String, title: String, selected: Boolean, action: () -> Unit): View =
        FrameLayout(this).apply {
            isClickable = true; isFocusable = true; contentDescription = title; setOnClickListener { action() }
            addView(LooplyIconView(this@MainActivity, icon).apply { tint = if (selected) palette.text else palette.muted },
                FrameLayout.LayoutParams(dp(24), dp(24), Gravity.CENTER))
        }

    // ---------------------------------------------------------------------
    // Home — geometry copied from HomeScreen/QuickSiteGridCard in Dart.
    // ---------------------------------------------------------------------
    private data class Site(val name: String, val file: String, val url: String, val category: String = "Destaques")

    private val quickSites = listOf(
        Site("Google", "google.webp", "https://www.google.com"), Site("YouTube", "youtube.webp", "https://www.youtube.com"),
        Site("Instagram", "instagram.webp", "https://www.instagram.com"), Site("Brave", "brave.webp", "https://search.brave.com"),
        Site("X", "x.webp", "https://x.com"), Site("Ao vivo", "besoccer_pro.webp", "https://www.flashscore.com"),
        Site("Wikipedia", "wikipedia.webp", "https://www.wikipedia.org"), Site("Bing", "bing.webp", "https://www.bing.com"),
        Site("DuckDuckGo", "duckduckgo.webp", "https://duckduckgo.com"),
    )

    private val allSites = listOf(
        Site("Google","google.webp","https://www.google.com"), Site("Bing","bing.webp","https://www.bing.com"), Site("Brave","brave.webp","https://search.brave.com"),
        Site("DuckDuckGo","duckduckgo.webp","https://duckduckgo.com"), Site("Yahoo","yahoo.webp","https://www.yahoo.com"), Site("Wikipedia","wikipedia.webp","https://www.wikipedia.org"),
        Site("Reddit","reddit.webp","https://www.reddit.com"), Site("Medium","medium.webp","https://medium.com"), Site("YouTube","youtube.webp","https://www.youtube.com"),
        Site("Adobe","adobe.webp","https://www.adobe.com","Produtividade"), Site("Airtable","airtable.webp","https://www.airtable.com","Produtividade"),
        Site("Apple","apple.webp","https://www.apple.com","Produtividade"), Site("Canva","canva.webp","https://www.canva.com","Produtividade"), Site("Dropbox","dropbox.webp","https://www.dropbox.com","Produtividade"),
        Site("Figma","figma.webp","https://www.figma.com","Produtividade"), Site("Jotform","jotform.webp","https://www.jotform.com","Produtividade"), Site("Loom","loom.webp","https://www.loom.com","Produtividade"),
        Site("Lucidspark","lucidspark.webp","https://lucidspark.com","Produtividade"), Site("Microsoft","microsoft.webp","https://www.microsoft.com","Produtividade"), Site("Miro","miro.webp","https://miro.com","Produtividade"),
        Site("Notion","notion.webp","https://www.notion.so","Produtividade"), Site("Zoom","zoom.webp","https://zoom.us","Produtividade"), Site("Oracle","oracle.webp","https://www.oracle.com","Produtividade"),
        Site("Recurly","recurly.webp","https://www.recurly.com","Finanças"), Site("Instagram","instagram.webp","https://www.instagram.com","Social"), Site("TikTok","tiktok.webp","https://www.tiktok.com","Social"),
        Site("Gmail","gmail.webp","https://mail.google.com","Social"), Site("Revolt","revolt.webp","https://revolt.chat","Social"), Site("Netflix","netflix.webp","https://www.netflix.com","Entretenimento"),
        Site("Spotify","spotify.webp","https://open.spotify.com","Entretenimento"), Site("Roblox","roblox.webp","https://www.roblox.com","Entretenimento"), Site("Poki","poki.webp","https://poki.com","Entretenimento"),
        Site("BBC","bbc.webp","https://www.bbc.com","Notícias"), Site("BeSoccer Pro","besoccer_pro.webp","https://www.besoccer.com","Notícias"),
        Site("Atlassian","atlassian.webp","https://www.atlassian.com","Desenvolvimento"), Site("Cloudflare","cloudflare.webp","https://www.cloudflare.com","Desenvolvimento"), Site("Framer","framer.webp","https://framer.com","Desenvolvimento"),
        Site("GitHub","github.webp","https://github.com","Desenvolvimento"), Site("GitLab","gitlab.webp","https://gitlab.com","Desenvolvimento"), Site("Replit","replit.webp","https://replit.com","Desenvolvimento"),
        Site("Semrush","semrush.webp","https://semrush.com","Desenvolvimento"), Site("Zapier","zapier.webp","https://zapier.com","Desenvolvimento"), Site("Deepgram","deepgram.webp","https://deepgram.com","Desenvolvimento"),
        Site("ChatGPT","openai_chatgpt.webp","https://chatgpt.com","IA"), Site("DeepMind","deepmind.webp","https://deepmind.google","IA"), Site("Mistral","mistral.webp","https://mistral.ai","IA"),
        Site("xAI","xai.webp","https://x.ai","IA"), Site("Stability AI","stabilityai.webp","https://stability.ai","IA"), Site("DreamStudio","stability_ai.webp","https://dreamstudio.ai","IA"), Site("Sider","sider.webp","https://sider.ai","IA"),
        Site("Amazon","amazon.webp","https://www.amazon.com","Compras"), Site("Alibaba","alibaba.webp","https://www.alibaba.com","Compras"), Site("Flipkart","flipkart.webp","https://www.flipkart.com","Compras"),
        Site("Airbnb","airbnb.webp","https://www.airbnb.com","Viagens"), Site("Aside","aside.webp","https://aside.com","Produtividade"),
    )

    private fun buildHome(): View {
        val frame = FrameLayout(this).apply { setBackgroundColor(palette.background) }
        val scrollColumn = linear(this, true)
        val scroll = ScrollView(this).apply { isFillViewport = false; clipToPadding = false }
        val list = linear(this, true).apply { setPadding(dp(12), dp(86), dp(12), dp(28)) }
        list.addView(View(this), LinearLayout.LayoutParams(1, dp(18)))
        list.addView(buildQuickSitesCard(), LinearLayout.LayoutParams(-1, -2))
        val user = store.getString("flutter.looply_auth_email")
        if (user.isBlank()) {
            val signIn = linear(this).apply {
                orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER
                background = ripple(this@MainActivity, palette.pill, 28f)
                setPadding(dp(16), dp(15), dp(16), dp(15))
                isClickable = true; isFocusable = true; setOnClickListener { navigate("auth") }
                addView(LooplyIconView(this@MainActivity, "sign-in").apply { tint = palette.text }, LinearLayout.LayoutParams(dp(18), dp(18)))
                addView(textView(this@MainActivity, "Iniciar sessão", 14f, palette.text, Typeface.BOLD).apply { setPadding(dp(8), 0, 0, 0) })
            }
            val p = LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(10) }
            list.addView(signIn, p)
        }
        val footer = textView(this, "Navegação simples, rápida e privada.", 12f, palette.muted).apply { gravity = Gravity.CENTER; setPadding(0, dp(14), 0, 0) }
        list.addView(footer)
        scroll.addView(list)
        frame.addView(scroll, FrameLayout.LayoutParams(-1, -1))
        frame.addView(buildHomeAppBar(), FrameLayout.LayoutParams(-1, dp(64), Gravity.TOP))
        return shellContainer(frame, 0)
    }

    private fun buildHomeAppBar(): View {
        val bar = FrameLayout(this)
        val gradient = android.graphics.drawable.GradientDrawable(
            android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(palette.background, palette.background, Color.TRANSPARENT),
        ).apply {
            setColors(intArrayOf(palette.background, palette.background, Color.TRANSPARENT), floatArrayOf(0f, 0.55f, 1f))
        }
        bar.background = gradient
        val row = linear(this).apply { gravity = Gravity.CENTER_VERTICAL; setPadding(dp(10), 0, dp(10), 0) }
        row.addView(iconButton(this, "list", 44, palette.muted, palette.pill, "Abrir menu") { openDrawer() }, LinearLayout.LayoutParams(dp(44), dp(44)))
        val logo = LooplyLogoView(this).apply { tint = palette.text }
        row.addView(logo, LinearLayout.LayoutParams(0, dp(34), 1f).apply { leftMargin = dp(8); rightMargin = dp(8) })
        row.addView(iconButton(this, "magnifying-glass", 44, palette.muted, palette.pill, "Pesquisar") { navigate("search") }, LinearLayout.LayoutParams(dp(44), dp(44)))
        bar.addView(row, FrameLayout.LayoutParams(-1, dp(64)))
        return bar
    }

    private fun buildQuickSitesCard(): View {
        val card = linear(this, true).apply {
            background = rounded(palette.pill, 24f, this@MainActivity)
            setPadding(dp(8), dp(12), dp(8), dp(12))
        }
        card.addView(buildSiteRow(quickSites.take(5)), LinearLayout.LayoutParams(-1, -2))
        card.addView(View(this), LinearLayout.LayoutParams(1, dp(12)))
        val second = linear(this).apply { gravity = Gravity.CENTER }
        quickSites.drop(5).forEach { second.addView(buildSiteTile(it), LinearLayout.LayoutParams(0, -2, 1f)) }
        second.addView(buildMoreTile(), LinearLayout.LayoutParams(0, -2, 1f))
        card.addView(second)
        return card
    }

    private fun buildSiteRow(sites: List<Site>): View = linear(this).apply {
        gravity = Gravity.CENTER
        sites.forEach { addView(buildSiteTile(it), LinearLayout.LayoutParams(0, -2, 1f)) }
    }

    private fun buildSiteTile(site: Site): View = linear(this, true).apply {
        gravity = Gravity.CENTER
        isClickable = true; isFocusable = true; background = ripple(this@MainActivity, Color.TRANSPARENT, 16f)
        setOnClickListener { openBrowser(site.url, false) }
        val circle = FrameLayout(this@MainActivity).apply {
            background = rounded(if (palette.dark) palette.pill else Color.WHITE, 20f, this@MainActivity)
            clipToOutline = true
            val image = assetImage(this@MainActivity, "images/quick_sites/${site.file}")
            addView(image, FrameLayout.LayoutParams(-1, -1))
            image.scaleType = ImageView.ScaleType.CENTER_CROP
        }
        addView(circle, LinearLayout.LayoutParams(dp(40), dp(40)))
        addView(textView(this@MainActivity, site.name, 10f, palette.text).apply { gravity = Gravity.CENTER; maxLines = 1; ellipsize = android.text.TextUtils.TruncateAt.END },
            LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(5) })
        setPadding(dp(1), dp(1), dp(1), dp(1))
    }

    private fun buildMoreTile(): View = linear(this, true).apply {
        gravity = Gravity.CENTER
        isClickable = true; isFocusable = true; background = ripple(this@MainActivity, Color.TRANSPARENT, 16f)
        setOnClickListener { navigate("all_sites") }
        val dash = android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.OVAL
            setColor(Color.TRANSPARENT); setStroke(dp(1.5f), palette.accent, dp(4f), dp(3f))
        }
        addView(FrameLayout(this@MainActivity).apply {
            background = dash
            addView(LooplyIconView(this@MainActivity, "plus").apply { tint = palette.accent }, FrameLayout.LayoutParams(dp(22), dp(22), Gravity.CENTER))
        }, LinearLayout.LayoutParams(dp(40), dp(40)))
        addView(textView(this@MainActivity, "Mais", 10f, palette.text).apply { gravity = Gravity.CENTER }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(5) })
    }

    // ---------------------------------------------------------------------
    // Browser — native WebView, 40dp rounded address pill and 3dp progress.
    // ---------------------------------------------------------------------
    private fun buildBrowser(): View {
        val tab = activeTab ?: run {
            val created = LooplyTab(UUID.randomUUID().toString(), "https://www.google.com", "Google", false)
            tabs.add(created); activeTab = created; created
        }
        isIncognito = tab.incognito
        val root = linear(this, true).apply { setBackgroundColor(palette.background) }
        val toolbar = linear(this).apply { gravity = Gravity.CENTER_VERTICAL; setPadding(dp(4), 0, dp(4), 0); setBackgroundColor(browserToolbarColor ?: palette.background) }
        currentBrowserToolbar = toolbar
        toolbar.addView(iconButton(this, "house", 48, palette.text, Color.TRANSPARENT, "Início") {
            disposeCurrentWebView(); showScreen("home", false)
        }, LinearLayout.LayoutParams(dp(48), dp(56)))
        val addressPill = FrameLayout(this).apply {
            background = rounded(palette.pill, 22f, this@MainActivity)
            isClickable = true; isFocusable = true; setOnClickListener { navigate("search") }
        }
        currentAddressPill = addressPill
        addressPill.addView(LooplyIconView(this, if (tab.url.startsWith("https")) "lock-simple" else "magnifying-glass").apply { tint = palette.muted },
            FrameLayout.LayoutParams(dp(18), dp(18), Gravity.CENTER_VERTICAL or Gravity.START).apply { leftMargin = dp(12) })
        currentAddress = textView(this, tab.title.ifBlank { Uri.parse(tab.url).host ?: tab.url }, 14f, palette.text, Typeface.MEDIUM).apply {
            maxLines = 1; ellipsize = android.text.TextUtils.TruncateAt.END
        }
        addressPill.addView(currentAddress, FrameLayout.LayoutParams(-1, -1).apply { leftMargin = dp(38); rightMargin = dp(8) })
        toolbar.addView(addressPill, LinearLayout.LayoutParams(0, dp(40), 1f))
        val tabsButton = FrameLayout(this).apply {
            isClickable = true; isFocusable = true; setOnClickListener { navigate("tabs") }
            addView(TextView(this@MainActivity).apply {
                text = tabs.size.toString(); textSize = 11f; typeface = Typeface.DEFAULT_BOLD; gravity = Gravity.CENTER; setTextColor(palette.text)
                background = rounded(Color.TRANSPARENT, 6f, this@MainActivity, palette.text, 1.6f)
            }, FrameLayout.LayoutParams(dp(24), dp(24), Gravity.CENTER))
        }
        toolbar.addView(tabsButton, LinearLayout.LayoutParams(dp(42), dp(56)))
        toolbar.addView(iconButton(this, "dots-three-vertical", 42, palette.text, Color.TRANSPARENT, "Mais opções") { showBrowserOptions() }, LinearLayout.LayoutParams(dp(42), dp(56)))
        root.addView(toolbar, LinearLayout.LayoutParams(-1, dp(56)))
        val progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100; progress = 0; progressTintList = android.content.res.ColorStateList.valueOf(palette.accent)
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(palette.muted and 0x22FFFFFF)
        }
        currentProgress = progress
        root.addView(progress, LinearLayout.LayoutParams(-1, dp(3)))

        val web = WebView(this)
        currentWebView = web
        configureWebView(web, tab)
        root.addView(web, LinearLayout.LayoutParams(-1, 0, 1f))
        web.loadUrl(tab.url)
        return root
    }

    private fun configureWebView(web: WebView, tab: LooplyTab) {
        web.setBackgroundColor(palette.background)
        web.overScrollMode = View.OVER_SCROLL_NEVER
        web.isVerticalScrollBarEnabled = false
        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            loadsImagesAutomatically = true
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            useWideViewPort = true
            loadWithOverviewMode = false
            builtInZoomControls = false
            displayZoomControls = false
            cacheMode = if (store.getBoolean("flutter.looply_navigation_accelerator_enabled", true)) WebSettings.LOAD_DEFAULT else WebSettings.LOAD_NO_CACHE
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            mediaPlaybackRequiresUserGesture = true
            allowFileAccess = false
            allowContentAccess = true
            if (tab.incognito) {
                cacheMode = WebSettings.LOAD_NO_CACHE
                databaseEnabled = false
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                @Suppress("DEPRECATION")
                forceDark = if (store.getBoolean("flutter.looply_force_dark_websites", false) ||
                    (store.getBoolean("flutter.looply_site_theme_follows_app", true) && palette.dark)) WebSettings.FORCE_DARK_ON else WebSettings.FORCE_DARK_OFF
            }
        }
        CookieManager.getInstance().setAcceptCookie(!tab.incognito)
        CookieManager.getInstance().setAcceptThirdPartyCookies(web, !tab.incognito)
        if (tab.incognito) {
            web.clearCache(true)
            web.clearHistory()
        }
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val uri = request.url
                val scheme = uri.scheme.orEmpty()
                if (scheme == "http" || scheme == "https") return false
                return try { startActivity(Intent(Intent.ACTION_VIEW, uri)); true } catch (_: Exception) { true }
            }

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                if (LooplyAdBlocker.shouldBlock(request)) return WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))
                return super.shouldInterceptRequest(view, request)
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                currentProgress?.visibility = View.VISIBLE
                currentProgress?.progress = 0
                currentAddress?.text = Uri.parse(url.orEmpty()).host ?: url.orEmpty()
                browserToolbarColor = null
                applyBrowserChromeColor(palette.background)
                tab.url = url ?: tab.url
                tab.title = Uri.parse(tab.url).host ?: tab.title
            }

            override fun onPageFinished(view: WebView, url: String?) {
                super.onPageFinished(view, url)
                currentProgress?.visibility = View.GONE
                tab.url = url ?: tab.url
                tab.title = view.title?.takeIf { it.isNotBlank() } ?: (Uri.parse(tab.url).host ?: tab.url)
                currentAddress?.text = tab.title
                if (!tab.incognito) store.addHistory(tab.title, tab.url)
                if (LooplyAdBlocker.enabled) view.evaluateJavascript(LooplyAdBlocker.COSMETIC_SCRIPT, null)
                applyWebsiteAppearance(view)
                if (store.getBoolean("flutter.looply_adaptive_toolbar_color", false) && !tab.incognito) refreshAdaptiveToolbarColor(view)
                store.saveTabs(tabs, tab.id)
            }

            override fun onRenderProcessGone(view: WebView, detail: android.webkit.RenderProcessGoneDetail): Boolean {
                if (currentWebView === view) {
                    currentWebView = null
                    try { (view.parent as? ViewGroup)?.removeView(view); view.destroy() } catch (_: Exception) { }
                    Toast.makeText(this@MainActivity, "A página foi reiniciada após uma falha do WebView.", Toast.LENGTH_LONG).show()
                    if (currentScreen == "browser") showScreen("browser", false)
                }
                return true
            }
        }
        web.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, newProgress: Int) {
                currentProgress?.progress = newProgress
                if (newProgress >= 100) currentProgress?.visibility = View.GONE else currentProgress?.visibility = View.VISIBLE
            }

            override fun onReceivedTitle(view: WebView, title: String?) {
                super.onReceivedTitle(view, title)
                if (!title.isNullOrBlank()) {
                    tab.title = title
                    currentAddress?.text = title
                }
            }

            override fun onPermissionRequest(request: PermissionRequest) {
                runOnUiThread {
                    val requested = request.resources.mapNotNull { resource ->
                        when (resource) {
                            PermissionRequest.RESOURCE_AUDIO_CAPTURE -> Manifest.permission.RECORD_AUDIO
                            PermissionRequest.RESOURCE_VIDEO_CAPTURE -> Manifest.permission.CAMERA
                            else -> null
                        }
                    }.distinct()
                    if (requested.isEmpty()) { request.deny(); return@runOnUiThread }
                    val missing = requested.filter { ContextCompat.checkSelfPermission(this@MainActivity, it) != PackageManager.PERMISSION_GRANTED }
                    if (missing.isEmpty()) request.grant(request.resources.toTypedArray()) else {
                        pendingWebPermission = request
                        ActivityCompat.requestPermissions(this@MainActivity, missing.toTypedArray(), 8162)
                    }
                }
            }

            override fun onGeolocationPermissionsShowPrompt(origin: String?, callback: GeolocationPermissions.Callback?) {
                val allowed = ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                if (allowed) callback?.invoke(origin, true, false)
                else MaterialAlertDialogBuilder(this@MainActivity)
                    .setTitle("Permitir localização?")
                    .setMessage("O site ${Uri.parse(origin.orEmpty()).host ?: ""} pretende aceder à localização deste dispositivo.")
                    .setNegativeButton("Não") { _, _ -> callback?.invoke(origin, false, false) }
                    .setPositiveButton("Continuar") { _, _ ->
                        pendingGeoCallback = callback
                        pendingGeoOrigin = origin.orEmpty()
                        ActivityCompat.requestPermissions(this@MainActivity, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), 8163)
                    }.show()
            }

            override fun onShowFileChooser(webView: WebView?, filePathCallback: ValueCallback<Array<Uri>>?, fileChooserParams: FileChooserParams?): Boolean {
                fileChooserCallback?.onReceiveValue(null)
                fileChooserCallback = filePathCallback
                val intent = fileChooserParams?.createIntent() ?: Intent(Intent.ACTION_GET_CONTENT).apply { type = "*/*"; addCategory(Intent.CATEGORY_OPENABLE) }
                return try { filePicker.launch(intent); true } catch (_: ActivityNotFoundException) { fileChooserCallback = null; false }
            }
        }
        web.setDownloadListener(DownloadListener { url, userAgent, contentDisposition, mimeType, _ ->
            try {
                val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
                val request = DownloadManager.Request(Uri.parse(url)).apply {
                    setMimeType(mimeType)
                    addRequestHeader("User-Agent", userAgent)
                    setTitle(fileName)
                    setDescription("Download do Looply")
                    setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                    setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
                }
                (getSystemService(DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
                if (!tab.incognito) store.addDownload(url, fileName, mimeType)
                toast("Download iniciado")
            } catch (error: Exception) { toast("Não foi possível iniciar o download: ${error.message}") }
        })
    }

    private var pendingGeoCallback: GeolocationPermissions.Callback? = null
    private var pendingGeoOrigin: String = ""

    private fun disposeCurrentWebView() {
        val web = currentWebView ?: return
        currentWebView = null
        currentAddress = null
        currentProgress = null
        currentBrowserToolbar = null
        currentAddressPill = null
        try {
            web.stopLoading()
            web.onPause()
            (web.parent as? ViewGroup)?.removeView(web)
            web.webChromeClient = null
            web.webViewClient = null
            web.destroy()
        } catch (_: Exception) { }
    }

    private fun openBrowser(raw: String, incognito: Boolean, title: String? = null) {
        if (currentWebView != null) disposeCurrentWebView()
        val url = normalizeUrl(raw)
        val tab = LooplyTab(UUID.randomUUID().toString(), url, title ?: (Uri.parse(url).host ?: url), incognito)
        tabs.add(tab)
        activeTab = tab
        isIncognito = incognito
        persistTabs()
        backStack.clear()
        showScreen("browser", false)
    }

    private fun normalizeUrl(raw: String): String {
        val value = raw.trim()
        if (value.isEmpty()) return "https://www.google.com"
        if (value.startsWith("http://") || value.startsWith("https://")) return value
        if (value.contains(' ') || !value.contains('.') || value.startsWith("?")) return searchUrl(value)
        return "https://$value"
    }

    private fun searchUrl(query: String): String {
        val engine = lastSearchEngine
        val encoded = URLEncoder.encode(query, "UTF-8")
        return when (engine) {
            "Bing" -> "https://www.bing.com/search?q=$encoded"
            "DuckDuckGo" -> "https://duckduckgo.com/?q=$encoded"
            "Yahoo" -> "https://search.yahoo.com/search?p=$encoded"
            "Brave" -> "https://search.brave.com/search?q=$encoded"
            "Ecosia" -> "https://www.ecosia.org/search?q=$encoded"
            else -> "https://www.google.com/search?q=$encoded"
        }
    }

    private fun saveLastPage(url: String, title: String) {
        val json = JSONObject().put("url", url).put("title", title.ifBlank { url }).put("savedAt", java.time.Instant.now().toString())
        store.putString("flutter.looply_last_page_session", json.toString())
    }

    private fun persistTabs() { if (::store.isInitialized) store.saveTabs(tabs, activeTab?.id) }

    private fun showBrowserOptions() {
        val sheet = BottomSheetDialog(this)
        val content = linear(this, true).apply {
            background = rounded(palette.panel, 24f, this@MainActivity)
            setPadding(dp(12), dp(12), dp(12), dp(18))
        }
        val title = textView(this, "Opções do navegador", 16f, palette.text, Typeface.BOLD).apply { setPadding(dp(12), dp(8), dp(12), dp(12)) }
        content.addView(title)
        val options = listOf(
            Triple("bookmark-simple", "Adicionar aos favoritos") { activeTab?.let { if (!it.incognito) { store.addBookmark(it.title, it.url); toast("Adicionado aos favoritos") } else toast("Favoritos não são guardados em navegação anónima") } },
            Triple("copy", "Copiar endereço") { copyAddress() },
            Triple("magnifying-glass", "Pesquisar nesta página") { searchInPage() },
            Triple("share", "Partilhar página") { shareCurrentPage() },
            Triple("clock-counter-clockwise", "Histórico") { sheet.dismiss(); navigate("history") },
            Triple("bookmarks-simple", "Favoritos") { sheet.dismiss(); navigate("bookmarks") },
            Triple("download-simple", "Downloads") { sheet.dismiss(); navigate("downloads") },
            Triple("gear", "Definições") { sheet.dismiss(); navigate("settings") },
            Triple("arrow-clockwise", "Recarregar") { currentWebView?.reload() },
        )
        options.forEach { (icon, text, action) ->
            val item = linear(this).apply {
                gravity = Gravity.CENTER_VERTICAL; isClickable = true; isFocusable = true
                background = ripple(this@MainActivity, Color.TRANSPARENT, 12f)
                setPadding(dp(12), 0, dp(12), 0); minimumHeight = dp(54)
                addView(LooplyIconView(this@MainActivity, icon).apply { tint = palette.text }, LinearLayout.LayoutParams(dp(22), dp(22)))
                addView(textView(this@MainActivity, text, 14f, palette.text).apply { setPadding(dp(16), 0, 0, 0) })
                setOnClickListener { action(); if (sheet.isShowing && text !in setOf("Histórico", "Favoritos", "Downloads", "Definições")) sheet.dismiss() }
            }
            content.addView(item)
        }
        sheet.setContentView(content)
        sheet.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        sheet.show()
    }

    private fun copyAddress() {
        val url = currentWebView?.url ?: activeTab?.url ?: return
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager
        clipboard.setPrimaryClip(android.content.ClipData.newPlainText("URL", url))
        toast("Endereço copiado")
    }

    private fun searchInPage() {
        val input = EditText(this).apply { hint = "Pesquisar na página"; setTextColor(palette.text); setHintTextColor(palette.muted) }
        MaterialAlertDialogBuilder(this).setTitle("Pesquisar na página").setView(input)
            .setNegativeButton("Cancelar", null).setPositiveButton("Pesquisar") { _, _ ->
                val q = input.text.toString().trim(); if (q.isNotEmpty()) currentWebView?.findAllAsync(q)
            }.show()
    }

    private fun shareCurrentPage() {
        val url = currentWebView?.url ?: activeTab?.url ?: return
        val title = currentWebView?.title ?: url
        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, "$title\n$url") }, "Partilhar página"))
    }

    // ---------------------------------------------------------------------
    // Search and tab grid.
    // ---------------------------------------------------------------------
    private fun buildSearch(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Pesquisar") { if (backStack.isNotEmpty()) onBackPressed() else showScreen("home", false) })
        val body = linear(this, true).apply { setPadding(dp(20), dp(20), dp(20), dp(24)) }
        val engineBar = linear(this).apply {
            gravity = Gravity.CENTER_VERTICAL; background = rounded(palette.pill, 18f, this@MainActivity); setPadding(dp(14), 0, dp(14), 0); minimumHeight = dp(50)
            addView(LooplyIconView(this@MainActivity, "magnifying-glass").apply { tint = palette.muted }, LinearLayout.LayoutParams(dp(20), dp(20)))
            addView(textView(this@MainActivity, lastSearchEngine, 14f, palette.text, Typeface.MEDIUM).apply { setPadding(dp(10), 0, 0, 0) }, LinearLayout.LayoutParams(0, -1, 1f))
            addView(LooplyIconView(this@MainActivity, "caret-down").apply { tint = palette.muted }, LinearLayout.LayoutParams(dp(18), dp(18)))
            setOnClickListener { chooseSearchEngine() }
        }
        body.addView(engineBar)
        val input = EditText(this).apply {
            hint = "Pesquisar na Web ou inserir endereço"; setTextColor(palette.text); setHintTextColor(palette.muted); textSize = 15f
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_AUTO_CORRECT
            singleLine = true; imeOptions = android.view.inputmethod.EditorInfo.IME_ACTION_GO
            background = rounded(palette.pill, 18f, this@MainActivity); setPadding(dp(16), 0, dp(16), 0)
            setOnEditorActionListener { _, _, _ -> val q = text.toString(); if (q.isNotBlank()) openSearchQuery(q); true }
        }
        val inputParams = LinearLayout.LayoutParams(-1, dp(54)).apply { topMargin = dp(14) }
        body.addView(input, inputParams)
        val go = textButton("Pesquisar", true) { openSearchQuery(input.text.toString()) }
        body.addView(go, LinearLayout.LayoutParams(-1, dp(50)).apply { topMargin = dp(14) })
        val historyTitle = textView(this, "Pesquisas recentes", 15f, palette.text, Typeface.BOLD).apply { setPadding(0, dp(26), 0, dp(10)) }
        body.addView(historyTitle)
        val recent = store.readArray("looply_search_history_v1")
        for (i in 0 until minOf(recent.length(), 10)) {
            val query = recent.optString(i)
            val item = listRow("clock-counter-clockwise", query, null) { input.setText(query); input.setSelection(input.text.length); openSearchQuery(query) }
            body.addView(item)
        }
        val scroll = ScrollView(this).apply { isFillViewport = true; addView(body) }
        page.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun chooseSearchEngine() {
        val engines = arrayOf("Google", "Bing", "DuckDuckGo", "Yahoo", "Brave", "Ecosia")
        MaterialAlertDialogBuilder(this).setTitle("Motor de pesquisa").setSingleChoiceItems(engines, engines.indexOf(lastSearchEngine).coerceAtLeast(0)) { dialog, which ->
            lastSearchEngine = engines[which]; store.putString("flutter.looply_search_engine", lastSearchEngine); dialog.dismiss()
            if (currentScreen == "search") showScreen("search", false)
        }.setNegativeButton("Cancelar", null).show()
    }

    private fun openSearchQuery(query: String) {
        val value = query.trim()
        if (value.isBlank()) return
        val history = store.readArray("looply_search_history_v1")
        for (i in history.length() - 1 downTo 0) if (history.optString(i).equals(value, true)) history.remove(i)
        history.put(0, value)
        while (history.length() > 30) history.remove(history.length() - 1)
        store.writeArray("looply_search_history_v1", history)
        openBrowser(if (value.startsWith("http://") || value.startsWith("https://") || (value.contains('.') && !value.contains(' '))) normalizeUrl(value) else searchUrl(value), false)
    }

    private fun buildTabs(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Abas (${tabs.size})") { onBackPressed() })
        val controls = linear(this).apply { setPadding(dp(16), dp(12), dp(16), dp(12)) }
        controls.addView(textButton("Nova aba", true) { openBrowser("https://www.google.com", false) }, LinearLayout.LayoutParams(0, dp(46), 1f))
        controls.addView(textButton("Anónima", false) { openBrowser("https://www.google.com", true) }, LinearLayout.LayoutParams(0, dp(46), 1f).apply { leftMargin = dp(8) })
        page.addView(controls)
        val scrollBody = linear(this, true).apply { setPadding(dp(14), dp(4), dp(14), dp(24)) }
        if (tabs.isEmpty()) scrollBody.addView(emptyState("Não existem abas abertas", "Abre um site para começares a navegar."))
        tabs.toList().forEach { tab ->
            val item = linear(this).apply {
                orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
                background = rounded(palette.pill, 18f, this@MainActivity); setPadding(dp(14), dp(12), dp(10), dp(12))
                val info = cardText(this@MainActivity, tab.title.ifBlank { Uri.parse(tab.url).host ?: tab.url }, tab.url, palette)
                addView(info, LinearLayout.LayoutParams(0, -2, 1f))
                addView(iconButton(this@MainActivity, "x", 36, palette.muted, Color.TRANSPARENT, "Fechar aba") { closeTab(tab.id) }, LinearLayout.LayoutParams(dp(36), dp(36)))
                setOnClickListener { activeTab = tab; showScreen("browser", false) }
            }
            scrollBody.addView(item, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(10) })
        }
        if (tabs.size > 1) scrollBody.addView(textButton("Fechar todas as abas", false) {
            tabs.clear(); activeTab = null; persistTabs(); showScreen("home", false)
        }, LinearLayout.LayoutParams(-1, dp(48)))
        page.addView(ScrollView(this).apply { addView(scrollBody) }, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun closeTab(id: String) {
        val index = tabs.indexOfFirst { it.id == id }
        if (index < 0) return
        tabs.removeAt(index)
        if (activeTab?.id == id) activeTab = tabs.lastOrNull()
        persistTabs()
        if (activeTab == null) showScreen("home", false) else showScreen("tabs", false)
    }

    // ---------------------------------------------------------------------
    // Profile/authentication.
    // ---------------------------------------------------------------------
    private fun buildAuth(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Iniciar sessão") { onBackPressed() })
        val scroll = ScrollView(this).apply { isFillViewport = true; clipToPadding = false }
        val body = linear(this, true).apply { gravity = Gravity.CENTER_HORIZONTAL; setPadding(dp(22), dp(18), dp(22), dp(32)) }
        val logo = assetImage(this, "images/looply_icon.png").apply { scaleType = ImageView.ScaleType.CENTER_CROP; background = rounded(palette.pill, 50f, this@MainActivity); clipToOutline = true }
        body.addView(logo, LinearLayout.LayoutParams(dp(82), dp(82)))
        body.addView(textView(this, "Bem-vindo ao Looply", 23f, palette.text, Typeface.BOLD).apply { gravity = Gravity.CENTER; setPadding(0, dp(20), 0, dp(8)) })
        body.addView(textView(this, "Inicia sessão para sincronizar o teu perfil e os teus dados.", 13f, palette.muted).apply { gravity = Gravity.CENTER; setLineSpacing(dp(3).toFloat(), 1f) })
        val email = EditText(this).apply {
            hint = "Email"; textSize = 14f; setTextColor(palette.text); setHintTextColor(palette.muted); inputType = InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS or InputType.TYPE_CLASS_TEXT
            background = rounded(palette.pill, 18f, this@MainActivity, palette.line, 1f); setPadding(dp(16), dp(16), dp(16), dp(16))
        }
        body.addView(email, LinearLayout.LayoutParams(-1, dp(56)).apply { topMargin = dp(30) })
        val password = EditText(this).apply {
            hint = "Palavra-passe"; textSize = 14f; setTextColor(palette.text); setHintTextColor(palette.muted); inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            background = rounded(palette.pill, 18f, this@MainActivity, palette.line, 1f); setPadding(dp(16), dp(16), dp(16), dp(16))
        }
        body.addView(password, LinearLayout.LayoutParams(-1, dp(56)).apply { topMargin = dp(13) })
        body.addView(textButton("Entrar", true) {
            if (email.text.isNullOrBlank() || password.text.isNullOrEmpty()) toast("Preenche o email e a palavra-passe.")
            else toast("O login por email ainda precisa de um endpoint de autenticação próprio.")
        }, LinearLayout.LayoutParams(-1, dp(52)).apply { topMargin = dp(18) })
        body.addView(textView(this, "ou", 12f, palette.muted).apply { gravity = Gravity.CENTER; setPadding(0, dp(20), 0, dp(18)) })
        val google = linear(this).apply {
            gravity = Gravity.CENTER; background = rounded(palette.panel, 999f, this@MainActivity, palette.line, 1f)
            isClickable = true; isFocusable = true; setPadding(dp(18), 0, dp(18), 0); minimumHeight = dp(52)
            val logoGoogle = assetImage(this@MainActivity, "images/quick_sites/google.webp")
            addView(logoGoogle, LinearLayout.LayoutParams(dp(20), dp(20)))
            addView(textView(this@MainActivity, "Continuar com Google", 14f, palette.text, Typeface.MEDIUM).apply { setPadding(dp(10), 0, 0, 0) })
            setOnClickListener { signInGoogle() }
        }
        body.addView(google, LinearLayout.LayoutParams(-1, dp(52)))
        body.addView(textView(this, "A tua autenticação é processada pelo Credential Manager do Android.", 11f, palette.muted).apply { gravity = Gravity.CENTER; setPadding(0, dp(18), 0, 0) })
        scroll.addView(body)
        page.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun signInGoogle() {
        val webClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID
        if (webClientId.isBlank()) { toast("Configura BROWSEIT_GOOGLE_WEB_CLIENT_ID para ativar o login Google."); return }
        lifecycleScope.launch {
            try {
                val workerNonce = cloudSync.createChallenge()
                val nonce = workerNonce ?: randomNonce()
                val option = GetGoogleIdOption.Builder().setFilterByAuthorizedAccounts(false)
                    .setServerClientId(webClientId).setNonce(nonce).build()
                val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
                val response = CredentialManager.create(this@MainActivity).getCredential(this@MainActivity, request)
                val credential = response.credential
                if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                    throw IllegalStateException("A credencial devolvida não é do Google.")
                }
                val google = GoogleIdTokenCredential.createFrom(credential.data)
                val token = google.idToken
                if (token.isBlank()) throw IllegalStateException("A credencial Google recebida está incompleta.")
                if (cloudSync.configured) cloudSync.authenticate(token, nonce)
                val claims = decodeJwtClaims(token)
                val email = google.id.ifBlank { claims.optString("email") }
                if (email.isBlank()) throw IllegalStateException("A credencial Google não contém um email válido.")
                store.putString("flutter.looply_auth_email", email)
                store.putString("flutter.looply_auth_name", google.displayName ?: claims.optString("name"))
                store.putString("flutter.looply_auth_photo", google.profilePictureUri?.toString() ?: claims.optString("picture"))
                store.putString("flutter.looply_auth_provider", if (cloudSync.configured) "google" else "google-local")
                if (cloudSync.configured) withContext(Dispatchers.IO) { runCatching { cloudSync.uploadBackup() } }
                toast("Sessão iniciada")
                showScreen("profile", false)
            } catch (error: GetCredentialException) {
                toast(error.message ?: "Não foi possível concluir o login Google.")
            } catch (error: Exception) {
                toast(error.message ?: "Falha ao iniciar sessão com Google.")
            }
        }
    }

    private fun randomNonce(): String {
        val bytes = ByteArray(32); SecureRandom().nextBytes(bytes)
        return android.util.Base64.encodeToString(bytes, android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
    }

    private fun decodeJwtClaims(token: String): JSONObject = try {
        val parts = token.split('.')
        if (parts.size < 2) JSONObject() else JSONObject(String(android.util.Base64.decode(parts[1], android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP), Charsets.UTF_8))
    } catch (_: Exception) { JSONObject() }

    private fun buildProfile(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Perfil") { onBackPressed() })
        val scroll = ScrollView(this)
        val body = linear(this, true).apply { setPadding(dp(20), dp(22), dp(20), dp(28)) }
        val email = store.getString("flutter.looply_auth_email")
        if (email.isBlank()) {
            body.gravity = Gravity.CENTER
            body.addView(emptyState("A tua conta", "Inicia sessão para aceder ao teu perfil."))
            body.addView(textButton("Iniciar sessão", true) { navigate("auth") }, LinearLayout.LayoutParams(-1, dp(50)).apply { topMargin = dp(20) })
        } else {
            val name = store.getString("flutter.looply_auth_name", "Utilizador Looply").ifBlank { "Utilizador Looply" }
            val avatar = assetImage(this, "images/avatar.png").apply { background = rounded(palette.pill, 50f, this@MainActivity); clipToOutline = true }
            body.addView(avatar, LinearLayout.LayoutParams(dp(92), dp(92)).apply { gravity = Gravity.CENTER })
            body.addView(textView(this, name, 22f, palette.text, Typeface.BOLD).apply { gravity = Gravity.CENTER; setPadding(0, dp(18), 0, dp(4)) })
            body.addView(textView(this, email, 13f, palette.muted).apply { gravity = Gravity.CENTER })
            body.addView(settingCard("shield-check", "Sessão", "Ligada por ${store.getString("flutter.looply_auth_provider", "google").replace("google-local", "Google")}"), LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(24) })
            body.addView(textButton("Terminar sessão", false) { confirmSignOut() }, LinearLayout.LayoutParams(-1, dp(50)).apply { topMargin = dp(18) })
        }
        scroll.addView(body)
        page.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun confirmSignOut() {
        MaterialAlertDialogBuilder(this).setTitle("Terminar sessão")
            .setMessage("Tens a certeza de que pretendes terminar a sessão?")
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Terminar sessão") { _, _ ->
                lifecycleScope.launch {
                    runCatching { cloudSync.signOut() }
                    listOf("flutter.looply_auth_email", "flutter.looply_auth_name", "flutter.looply_auth_photo", "flutter.looply_auth_provider").forEach { store.prefs.edit().remove(it).apply() }
                    showScreen("profile", false)
                }
            }.show()
    }

    // ---------------------------------------------------------------------
    // Activity/history/bookmarks/downloads and settings.
    // ---------------------------------------------------------------------
    private fun buildActivity(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Atividade") { openDrawer() })
        val body = linear(this, true).apply { setPadding(dp(18), dp(12), dp(18), dp(22)) }
        val entries = store.readArray("looply_browsing_history_v1")
        val today = java.time.LocalDate.now().toString()
        var todayCount = 0
        val hosts = linkedSetOf<String>()
        for (i in 0 until entries.length()) {
            val item = entries.optJSONObject(i) ?: continue
            if (item.optString("timestamp").startsWith(today)) todayCount++
            Uri.parse(item.optString("url")).host?.let(hosts::add)
        }
        val stats = linear(this).apply {
            background = rounded(palette.pill, 22f, this@MainActivity); setPadding(dp(16), dp(16), dp(16), dp(16))
            addView(metric("$todayCount", "Visitas hoje"), LinearLayout.LayoutParams(0, -2, 1f))
            addView(metric("${hosts.size}", "Sites visitados"), LinearLayout.LayoutParams(0, -2, 1f))
        }
        body.addView(stats)
        body.addView(textView(this, "Atividade recente", 16f, palette.text, Typeface.BOLD).apply { setPadding(0, dp(24), 0, dp(12)) })
        if (entries.length() == 0) body.addView(emptyState("Ainda sem atividade", "Os sites que visitares aparecerão aqui."))
        for (i in entries.length() - 1 downTo maxOf(0, entries.length() - 25)) {
            val obj = entries.optJSONObject(i) ?: continue
            body.addView(listRow("globe", obj.optString("title", obj.optString("url")), Uri.parse(obj.optString("url")).host) {
                openBrowser(obj.optString("url"), false)
            })
        }
        page.addView(ScrollView(this).apply { addView(body) }, LinearLayout.LayoutParams(-1, 0, 1f))
        return shellContainer(page, 1)
    }

    private fun metric(value: String, caption: String): View = linear(this, true).apply {
        addView(textView(this@MainActivity, value, 24f, palette.text, Typeface.BOLD))
        addView(textView(this@MainActivity, caption, 11f, palette.muted).apply { setPadding(0, dp(5), 0, 0) })
    }

    private fun buildHistory(): View = buildStoredListScreen("Histórico", "looply_browsing_history_v1", "clock-counter-clockwise", true)
    private fun buildBookmarks(): View = buildStoredListScreen("Favoritos", "looply_bookmarks_v1", "bookmarks-simple", false)
    private fun buildDownloads(): View = buildStoredListScreen("Downloads", "looply_download_requests_v1", "download-simple", false)

    private fun buildStoredListScreen(title: String, key: String, icon: String, isHistory: Boolean): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader(title) { onBackPressed() })
        val entries = store.readArray(key)
        val body = linear(this, true).apply { setPadding(dp(16), dp(10), dp(16), dp(26)) }
        if (entries.length() == 0) body.addView(emptyState("Sem itens", if (isHistory) "Os sites que visitares aparecerão aqui." else "Ainda não existem itens guardados."))
        for (i in entries.length() - 1 downTo 0) {
            val item = entries.optJSONObject(i) ?: continue
            val url = item.optString("url")
            val titleText = item.optString("title", item.optString("filename", url))
            val subtitle = if (isHistory) Uri.parse(url).host else url
            val row = listRow(icon, titleText, subtitle) { if (url.isNotBlank()) openBrowser(url, false) }
            row.setOnLongClickListener {
                MaterialAlertDialogBuilder(this).setItems(arrayOf("Abrir", "Remover")) { _, which ->
                    if (which == 0 && url.isNotBlank()) openBrowser(url, false)
                    if (which == 1) { store.removeArrayItem(key, i); showScreen(currentScreen, false) }
                }.show(); true
            }
            body.addView(row)
        }
        if (entries.length() > 0 && (isHistory || key == "looply_bookmarks_v1")) {
            body.addView(textButton("Limpar tudo", false) {
                MaterialAlertDialogBuilder(this).setTitle("Limpar ${title.lowercase(Locale.ROOT)}?").setNegativeButton("Cancelar", null)
                    .setPositiveButton("Limpar") { _, _ -> store.clearArray(key); showScreen(currentScreen, false) }.show()
            }, LinearLayout.LayoutParams(-1, dp(48)).apply { topMargin = dp(12) })
        }
        page.addView(ScrollView(this).apply { addView(body) }, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun buildSettings(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Definições") { onBackPressed() })
        val body = linear(this, true).apply { setPadding(dp(16), dp(12), dp(16), dp(28)) }
        body.addView(sectionTitle("Aparência"))
        body.addView(settingCard("palette", "Tema", when (themeMode) { "light" -> "Claro"; "dark" -> if (pureBlack) "AMOLED" else "Escuro"; else -> "Sistema" }))
        body.getChildAt(body.childCount - 1).setOnClickListener { chooseTheme() }
        body.addView(sectionTitle("Navegador"))
        body.addView(switchRow("shield-check", "Bloqueador de anúncios", "Bloqueia pedidos de publicidade conhecidos", store.getBoolean("flutter.looply_ad_block_enabled", true), "flutter.looply_ad_block_enabled") { enabled -> LooplyAdBlocker.enabled = enabled })
        body.addView(switchRow("gauge", "Aceleração de navegação", "Ativa otimizações de carregamento", store.getBoolean("flutter.looply_navigation_accelerator_enabled", true), "flutter.looply_navigation_accelerator_enabled") { updateWebTheme() })
        body.addView(switchRow("moon", "Forçar tema escuro nos sites", "Aplica escurecimento algorítmico quando suportado", store.getBoolean("flutter.looply_force_dark_websites", false), "flutter.looply_force_dark_websites") { updateWebTheme() })
        body.addView(switchRow("palette", "Seguir o tema da aplicação", "Usa a aparência Looply nos sites compatíveis", store.getBoolean("flutter.looply_site_theme_follows_app", true), "flutter.looply_site_theme_follows_app") { updateWebTheme() })
        body.addView(switchRow("image", "Cor adaptativa da barra", "Acompanha a cor dominante do site", store.getBoolean("flutter.looply_adaptive_toolbar_color", false), "flutter.looply_adaptive_toolbar_color") { enabled ->
            if (enabled) currentWebView?.let { refreshAdaptiveToolbarColor(it) } else applyBrowserChromeColor(palette.background)
        })
        body.addView(switchRow("sparkles", "Pesquisa com IA", "Ativa a opção de pesquisa inteligente", store.getBoolean("flutter.looply_ai_search_mode", false), "flutter.looply_ai_search_mode") { })
        body.addView(sectionTitle("Dados e conta"))
        body.addView(settingCard("clock-counter-clockwise", "Histórico", "Gerir sites visitados").apply { setOnClickListener { navigate("history") } })
        body.addView(settingCard("bookmarks-simple", "Favoritos", "Gerir páginas guardadas").apply { setOnClickListener { navigate("bookmarks") } })
        body.addView(settingCard("download-simple", "Downloads", "Ficheiros transferidos").apply { setOnClickListener { navigate("downloads") } })
        body.addView(settingCard("globe", "Idioma", "Português e outros idiomas").apply { setOnClickListener { navigate("language") } })
        body.addView(settingCard("user", "Perfil", "Conta e sessão").apply { setOnClickListener { navigate("profile") } })
        body.addView(settingCard("info", "Sobre o Looply", "Versão, licença e informação").apply { setOnClickListener { navigate("app_info") } })
        page.addView(ScrollView(this).apply { addView(body) }, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun sectionTitle(title: String): View = textView(this, title, 13f, palette.muted, Typeface.BOLD).apply { setPadding(dp(8), dp(22), 0, dp(10)) }

    private fun settingCard(icon: String, title: String, subtitle: String): View = linear(this).apply {
        background = ripple(this@MainActivity, palette.pill, 18f); gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(14), dp(13), dp(14), dp(13)); isClickable = true; isFocusable = true
        addView(LooplyIconView(this@MainActivity, icon).apply { tint = palette.accent }, LinearLayout.LayoutParams(dp(21), dp(21)))
        addView(cardText(this@MainActivity, title, subtitle, palette), LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(12) })
        addView(LooplyIconView(this@MainActivity, "caret-right").apply { tint = palette.muted }, LinearLayout.LayoutParams(dp(18), dp(18)))
        minimumHeight = dp(68)
    }

    private fun switchRow(icon: String, title: String, subtitle: String, checked: Boolean, key: String, onChanged: (Boolean) -> Unit): View = linear(this).apply {
        background = rounded(palette.pill, 16f, this@MainActivity); gravity = Gravity.CENTER_VERTICAL; setPadding(dp(14), dp(10), dp(10), dp(10))
        addView(LooplyIconView(this@MainActivity, icon).apply { tint = palette.accent }, LinearLayout.LayoutParams(dp(21), dp(21)))
        addView(cardText(this@MainActivity, title, subtitle, palette), LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(12) })
        val toggle = SwitchCompat(this@MainActivity).apply {
            isChecked = checked
            thumbTintList = android.content.res.ColorStateList.valueOf(if (checked) Color.WHITE else palette.muted)
            trackTintList = android.content.res.ColorStateList.valueOf(if (checked) palette.accent else palette.line)
            setOnCheckedChangeListener { _, value -> store.putBoolean(key, value); onChanged(value) }
        }
        addView(toggle)
        minimumHeight = dp(74)
    }

    private fun chooseTheme() {
        val items = arrayOf("Sistema", "Claro", "Escuro", "AMOLED")
        MaterialAlertDialogBuilder(this).setTitle("Tema").setSingleChoiceItems(items, when { themeMode == "light" -> 1; themeMode == "dark" && pureBlack -> 3; themeMode == "dark" -> 2; else -> 0 }) { dialog, which ->
            themeMode = when (which) { 1 -> "light"; 2, 3 -> "dark"; else -> "system" }
            pureBlack = which == 3
            store.putString("flutter.looply_theme_mode", themeMode)
            store.putBoolean("flutter.looply_theme_pure_dark", pureBlack)
            applySystemTheme()
            dialog.dismiss()
            // The active WebView is retained; only the native shell and system bars are recolored.
            if (currentScreen == "browser") {
                currentWebView?.setBackgroundColor(palette.background)
                currentProgress?.progressTintList = android.content.res.ColorStateList.valueOf(palette.accent)
                currentAddress?.setTextColor(palette.text)
                applyBrowserChromeColor(browserToolbarColor ?: palette.background)
            } else showScreen("settings", false)
        }.setNegativeButton("Cancelar", null).show()
    }

    private fun applyWebsiteAppearance(web: WebView) {
        val followsApp = store.getBoolean("flutter.looply_site_theme_follows_app", true)
        val scheme = if (followsApp) if (palette.dark) "dark" else "light" else "normal"
        val script = "(function(){try{document.documentElement.style.setProperty('color-scheme','$scheme');document.documentElement.dataset.appTheme='$scheme';}catch(e){}})();"
        try { web.evaluateJavascript(script, null) } catch (_: Exception) { }
    }

    private fun refreshAdaptiveToolbarColor(web: WebView) {
        val script = "(function(){try{var m=document.querySelector('meta[name=theme-color]');return m?m.content:(getComputedStyle(document.body||document.documentElement).backgroundColor||'');}catch(e){return '';}})();"
        try {
            web.evaluateJavascript(script) { encoded ->
                if (isFinishing || isDestroyed || currentWebView !== web || currentScreen != "browser") return@evaluateJavascript
                val value = try { org.json.JSONTokener(encoded ?: "").nextValue() as? String } catch (_: Exception) { null }
                val color = parseCssColor(value) ?: return@evaluateJavascript
                browserToolbarColor = color
                applyBrowserChromeColor(color)
            }
        } catch (_: Exception) { }
    }

    private fun parseCssColor(raw: String?): Int? {
        val value = raw?.trim()?.lowercase(Locale.ROOT) ?: return null
        return try {
            when {
                value.matches(Regex("^#[0-9a-f]{6}$")) || value.matches(Regex("^#[0-9a-f]{8}$")) -> Color.parseColor(value)
                value.startsWith("rgb(") || value.startsWith("rgba(") -> {
                    val values = Regex("\\d+").findAll(value).mapNotNull { it.value.toIntOrNull() }.toList()
                    if (values.size < 3) null else Color.rgb(values[0].coerceIn(0, 255), values[1].coerceIn(0, 255), values[2].coerceIn(0, 255))
                }
                else -> null
            }
        } catch (_: Exception) { null }
    }

    private fun updateWebTheme() {
        currentWebView?.let { web ->
            web.settings.cacheMode = if (store.getBoolean("flutter.looply_navigation_accelerator_enabled", true)) WebSettings.LOAD_DEFAULT else WebSettings.LOAD_NO_CACHE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                @Suppress("DEPRECATION")
                web.settings.forceDark = if (store.getBoolean("flutter.looply_force_dark_websites", false) || (store.getBoolean("flutter.looply_site_theme_follows_app", true) && palette.dark)) WebSettings.FORCE_DARK_ON else WebSettings.FORCE_DARK_OFF
            }
            web.reload()
        }
    }

    private fun buildSecurity(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Segurança") { onBackPressed() })
        val body = linear(this, true).apply { setPadding(dp(18), dp(14), dp(18), dp(24)) }
        body.addView(settingCard("shield-check", "Bloqueador de anúncios", "Filtragem local de domínios conhecidos"))
        body.addView(settingCard("lock-simple", "Navegação HTTPS", "O navegador bloqueia conteúdo misto inseguro por predefinição"))
        body.addView(settingCard("eye", "Privacidade", "As abas anónimas não são adicionadas ao histórico"))
        page.addView(body, LinearLayout.LayoutParams(-1, -1))
        return page
    }

    private fun buildAllSites(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Todos os sites") { onBackPressed() })
        val body = linear(this, true).apply { setPadding(dp(16), dp(10), dp(16), dp(24)) }
        val grouped = allSites.groupBy { it.category }
        grouped.forEach { (category, sites) ->
            body.addView(textView(this, category, 15f, palette.text, Typeface.BOLD).apply { setPadding(dp(4), dp(16), 0, dp(8)) })
            val grid = android.widget.GridLayout(this).apply { columnCount = 3; useDefaultMargins = false }
            sites.forEach { site ->
                val tile = buildSiteTile(site)
                tile.setPadding(dp(6), dp(8), dp(6), dp(8))
                grid.addView(tile, android.widget.GridLayout.LayoutParams().apply { width = resources.displayMetrics.widthPixels / 3 - dp(20); height = dp(82) })
            }
            body.addView(grid)
        }
        page.addView(ScrollView(this).apply { addView(body) }, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun buildLanguage(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Idioma") { onBackPressed() })
        val body = linear(this, true).apply { setPadding(dp(16), dp(12), dp(16), dp(20)) }
        val languages = listOf("Português" to "pt", "English" to "en", "Español" to "es", "Français" to "fr", "Deutsch" to "de", "العربية" to "ar", "हिन्दी" to "hi", "日本語" to "ja", "中文" to "zh", "Русский" to "ru", "Italiano" to "it", "Türkçe" to "tr")
        val current = store.getString("flutter.looply_language", "pt")
        languages.forEach { (name, code) ->
            val item = listRow("globe", name, if (code == current) "Selecionado" else null) {
                store.putString("flutter.looply_language", code); toast("Idioma guardado. Algumas áreas podem manter o idioma anterior até serem abertas novamente."); showScreen("language", false)
            }
            body.addView(item)
        }
        page.addView(ScrollView(this).apply { addView(body) }, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun buildAdCalendar(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Calendário do bloqueador") { onBackPressed() })
        val body = linear(this, true).apply { setPadding(dp(18), dp(18), dp(18), dp(24)) }
        val stats = store.readArray("looply_adblock_daily_history_v2")
        body.addView(settingCard("shield-check", "Bloqueios registados", "${stats.length()} registos diários guardados"))
        body.addView(textView(this, "O bloqueador filtra localmente os pedidos reconhecidos. A atividade diária detalhada é mantida nas preferências da aplicação.", 13f, palette.muted).apply { setPadding(dp(8), dp(16), dp(8), 0) })
        page.addView(body, LinearLayout.LayoutParams(-1, -1))
        return page
    }

    private fun buildSiteUsage(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Utilização por site") { onBackPressed() })
        val body = linear(this, true).apply { setPadding(dp(16), dp(12), dp(16), dp(24)) }
        val entries = store.readArray("looply_browsing_history_v1")
        val counts = linkedMapOf<String, Int>()
        for (i in 0 until entries.length()) {
            val host = Uri.parse(entries.optJSONObject(i)?.optString("url").orEmpty()).host ?: continue
            counts[host] = (counts[host] ?: 0) + 1
        }
        counts.toList().sortedByDescending { it.second }.forEach { (host, count) -> body.addView(listRow("globe", host, "$count visitas") { }) }
        if (counts.isEmpty()) body.addView(emptyState("Sem dados de utilização", "A estatística será preenchida à medida que navegares."))
        page.addView(ScrollView(this).apply { addView(body) }, LinearLayout.LayoutParams(-1, 0, 1f))
        return page
    }

    private fun buildAppInfo(): View {
        val page = linear(this, true).apply { setBackgroundColor(palette.background) }
        page.addView(buildFeatureHeader("Sobre o Looply") { onBackPressed() })
        val body = linear(this, true).apply { gravity = Gravity.CENTER_HORIZONTAL; setPadding(dp(22), dp(30), dp(22), dp(30)) }
        body.addView(assetImage(this, "images/looply_icon.png").apply { background = rounded(palette.pill, 28f, this@MainActivity); clipToOutline = true }, LinearLayout.LayoutParams(dp(96), dp(96)))
        body.addView(textView(this, "Looply", 24f, palette.text, Typeface.BOLD).apply { gravity = Gravity.CENTER; setPadding(0, dp(18), 0, dp(4)) })
        body.addView(textView(this, "Versão ${packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"}", 13f, palette.muted).apply { gravity = Gravity.CENTER })
        body.addView(textView(this, "Navegação simples, rápida e privada.", 13f, palette.muted).apply { gravity = Gravity.CENTER; setPadding(0, dp(18), 0, dp(12)) })
        body.addView(textView(this, "Interface Android nativa em Kotlin. As preferências são mantidas localmente e a sincronização Cloudflare é opcional.", 12f, palette.muted).apply { gravity = Gravity.CENTER; setLineSpacing(dp(3).toFloat(), 1f) })
        page.addView(body, LinearLayout.LayoutParams(-1, -1))
        return page
    }

    // ---------------------------------------------------------------------
    // Navigation drawer, common native widgets and helpers.
    // ---------------------------------------------------------------------
    private fun openDrawer() {
        if (drawerOverlay != null) return
        val overlay = FrameLayout(this).apply { setBackgroundColor(0x00000000) }
        val scrim = View(this).apply { setBackgroundColor(Color.BLACK); alpha = 0f; setOnClickListener { closeDrawer() } }
        overlay.addView(scrim, FrameLayout.LayoutParams(-1, -1))
        val panel = linear(this, true).apply {
            background = rounded(palette.panel, 0f, this@MainActivity)
            setPadding(dp(16), dp(14), dp(16), dp(18))
            elevation = dp(12).toFloat()
        }
        val top = linear(this).apply { gravity = Gravity.CENTER_VERTICAL; setPadding(dp(4), dp(10), dp(4), dp(18)) }
        top.addView(assetImage(this, "images/looply_icon.png").apply { clipToOutline = true; background = rounded(palette.pill, 12f, this@MainActivity) }, LinearLayout.LayoutParams(dp(42), dp(42)))
        top.addView(textView(this, "Looply", 20f, palette.text, Typeface.BOLD).apply { setPadding(dp(12), 0, 0, 0) })
        panel.addView(top)
        val items = listOf(
            Triple("house", "Início", "home"), Triple("clock-counter-clockwise", "Atividade", "activity"),
            Triple("browser", "Navegador", "browser"), Triple("squares-four", "Abas", "tabs"),
            Triple("bookmarks-simple", "Favoritos", "bookmarks"), Triple("clock-counter-clockwise", "Histórico", "history"),
            Triple("download-simple", "Downloads", "downloads"), Triple("globe", "Todos os sites", "all_sites"),
            Triple("gauge", "Utilização por site", "site_usage"), Triple("shield-check", "Calendário do bloqueador", "ad_calendar"),
            Triple("user", "Perfil", "profile"), Triple("gear", "Definições", "settings"),
        )
        val list = linear(this, true)
        items.forEach { (icon, title, route) -> list.addView(drawerItem(icon, title) { closeDrawer(); if (route == "browser") openBrowser("https://www.google.com", false) else navigate(route) }) }
        panel.addView(ScrollView(this).apply { addView(list) }, LinearLayout.LayoutParams(-1, 0, 1f))
        panel.addView(drawerItem("info", "Sobre o Looply") { closeDrawer(); navigate("app_info") })
        overlay.addView(panel, FrameLayout.LayoutParams(dp(304), -1, Gravity.START))
        host.addView(overlay, FrameLayout.LayoutParams(-1, -1))
        drawerOverlay = overlay; drawerPanel = panel
        val animator = android.animation.ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 240; interpolator = android.view.animation.DecelerateInterpolator()
            addUpdateListener { a -> val p = a.animatedValue as Float; shellView()?.translationX = dp(304) * p; scrim.alpha = .07f * p; panel.translationX = -dp(304) * (1f - p) }
            start()
        }
    }

    private fun shellView(): View? = host.getChildAt(0)

    private fun closeDrawer() {
        val overlay = drawerOverlay ?: return
        val shell = shellView()
        val panel = drawerPanel
        val scrim = overlay.getChildAt(0)
        android.animation.ValueAnimator.ofFloat(1f, 0f).apply {
            duration = 200; interpolator = DecelerateInterpolator()
            addUpdateListener { a -> val p = a.animatedValue as Float; shell?.translationX = dp(304) * p; scrim?.alpha = .07f * p; panel?.translationX = -dp(304) * (1f - p) }
            doOnEnd { closeDrawerImmediately() }
            start()
        }
    }

    private fun android.animation.ValueAnimator.doOnEnd(action: () -> Unit) { addListener(object : android.animation.AnimatorListenerAdapter() { override fun onAnimationEnd(animation: android.animation.Animator) = action() }) }

    private fun closeDrawerImmediately() {
        drawerOverlay?.let { (it.parent as? ViewGroup)?.removeView(it) }
        shellView()?.translationX = 0f
        drawerOverlay = null; drawerPanel = null
    }

    private fun drawerItem(icon: String, title: String, action: () -> Unit): View = linear(this).apply {
        gravity = Gravity.CENTER_VERTICAL; isClickable = true; isFocusable = true
        background = ripple(this@MainActivity, Color.TRANSPARENT, 12f)
        setPadding(dp(12), 0, dp(12), 0); minimumHeight = dp(52)
        addView(LooplyIconView(this@MainActivity, icon).apply { tint = palette.muted }, LinearLayout.LayoutParams(dp(21), dp(21)))
        addView(textView(this@MainActivity, title, 14f, palette.text).apply { setPadding(dp(15), 0, 0, 0) })
        setOnClickListener { action() }
    }

    private fun buildFeatureHeader(title: String, onBack: () -> Unit): View = linear(this).apply {
        gravity = Gravity.CENTER_VERTICAL; setPadding(dp(4), 0, dp(12), 0); minimumHeight = dp(62)
        addView(iconButton(this@MainActivity, "arrow-left", 48, palette.text, Color.TRANSPARENT, "Voltar", onBack), LinearLayout.LayoutParams(dp(48), dp(48)))
        addView(textView(this@MainActivity, title, 17f, palette.text, Typeface.BOLD).apply { setPadding(dp(4), 0, 0, 0) }, LinearLayout.LayoutParams(0, -1, 1f))
    }

    private fun listRow(icon: String, title: String, subtitle: String?, action: () -> Unit): View = linear(this).apply {
        gravity = Gravity.CENTER_VERTICAL; isClickable = true; isFocusable = true; background = ripple(this@MainActivity, Color.TRANSPARENT, 12f)
        setPadding(dp(12), dp(11), dp(10), dp(11)); minimumHeight = dp(58)
        addView(LooplyIconView(this@MainActivity, icon).apply { tint = palette.muted }, LinearLayout.LayoutParams(dp(22), dp(22)))
        addView(cardText(this@MainActivity, title, subtitle, palette), LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(14) })
        addView(LooplyIconView(this@MainActivity, "caret-right").apply { tint = palette.muted }, LinearLayout.LayoutParams(dp(17), dp(17)))
        setOnClickListener { action() }
    }

    private fun textButton(text: String, primary: Boolean, action: () -> Unit): View = TextView(this).apply {
        this.text = text; textSize = 14f; typeface = Typeface.create("sans-serif", Typeface.BOLD)
        setTextColor(if (primary) Color.WHITE else palette.text); gravity = Gravity.CENTER
        background = ripple(this@MainActivity, if (primary) palette.accent else palette.pill, 999f)
        isClickable = true; isFocusable = true; setOnClickListener { action() }
    }

    private fun emptyState(title: String, message: String): View = linear(this, true).apply {
        gravity = Gravity.CENTER; setPadding(dp(20), dp(50), dp(20), dp(50))
        addView(LooplyIconView(this@MainActivity, "browser").apply { tint = palette.muted }, LinearLayout.LayoutParams(dp(42), dp(42)))
        addView(textView(this@MainActivity, title, 16f, palette.text, Typeface.BOLD).apply { gravity = Gravity.CENTER; setPadding(0, dp(14), 0, dp(6)) })
        addView(textView(this@MainActivity, message, 13f, palette.muted).apply { gravity = Gravity.CENTER })
    }

    private fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_SHORT).show()

    // System browser role is exposed through native Android RoleManager.
    private fun requestDefaultBrowser() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val manager = getSystemService(RoleManager::class.java)
            if (manager?.isRoleAvailable(RoleManager.ROLE_BROWSER) == true && !manager.isRoleHeld(RoleManager.ROLE_BROWSER)) {
                try { startActivityForResult(manager.createRequestRoleIntent(RoleManager.ROLE_BROWSER), 8120) } catch (_: Exception) { toast("Não foi possível abrir a seleção do navegador predefinido.") }
            } else toast("O Looply já é o navegador predefinido.")
        } else toast("A seleção do navegador predefinido depende das definições do Android.")
    }

    @Suppress("DEPRECATION")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 8162) {
            val request = pendingWebPermission; pendingWebPermission = null
            if (request != null) {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) request.grant(request.resources) else request.deny()
            }
        } else if (requestCode == 8163) {
            val allowed = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingGeoCallback?.invoke(pendingGeoOrigin, allowed, false)
            pendingGeoCallback = null
            pendingGeoOrigin = ""
        }
    }
}

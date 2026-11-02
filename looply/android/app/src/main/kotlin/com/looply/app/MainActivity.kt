package com.looply.app

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.PopupMenu
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.view.ContextThemeWrapper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "looply/native_ui"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_THEME_MODE = "flutter.looply_theme_mode"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // O Android guarda o modo de aparência escolhido pela aplicação.
        // Aplicá-lo antes de criar a janela permite que os recursos values-night
        // do splash acompanhem a preferência da Looply, não apenas o tema global.
        val savedMode = readSavedThemeMode()
        val savedPureBlack = readSavedPureBlack()
        applyApplicationNightMode(savedMode)
        super.onCreate(savedInstanceState)
        applyWindowTheme(savedMode, savedPureBlack)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAppThemeMode" -> {
                        val mode = call.argument<String>("mode") ?: "system"
                        val pureBlack = call.argument<Boolean>("pureBlack") ?: false
                        applyApplicationNightMode(mode)
                        applyWindowTheme(mode, pureBlack)
                        result.success(true)
                    }
                    "showNativePopup" -> showNativePopup(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun readSavedThemeMode(): String {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(PREF_THEME_MODE, "system") ?: "system"
    }

    private fun readSavedPureBlack(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("flutter.looply_theme_pure_dark", false)
    }

    private fun applyApplicationNightMode(mode: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val nightMode = when (mode) {
            "light" -> UiModeManager.MODE_NIGHT_NO
            "dark" -> UiModeManager.MODE_NIGHT_YES
            // MODE_NIGHT_AUTO é a opção automática oferecida por UiModeManager;
            // o SDK Android não expõe FOLLOW_SYSTEM neste método.
            else -> UiModeManager.MODE_NIGHT_AUTO
        }
        try {
            getSystemService(UiModeManager::class.java)?.setApplicationNightMode(nightMode)
        } catch (_: RuntimeException) {
            // A configuração Flutter continua funcional mesmo em dispositivos
            // Android modificados que não implementem o modo por aplicação.
        }
    }


    private fun applyWindowTheme(mode: String, pureBlack: Boolean) {
        val dark = when (mode) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        val background = when {
            !dark -> Color.WHITE
            pureBlack -> Color.BLACK
            else -> Color.rgb(23, 24, 26)
        }
        window.setBackgroundDrawable(ColorDrawable(background))
        window.statusBarColor = background
        window.navigationBarColor = background
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            @Suppress("DEPRECATION")
            var flags = window.decorView.systemUiVisibility
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = if (dark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                flags = if (dark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                }
            }
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = flags
        }
    }

    private fun showNativePopup(call: MethodCall, result: MethodChannel.Result) {
        val items = call.argument<List<Map<String, Any?>>>("items")
        val anchor = call.argument<Map<String, Any>>("anchor")
        if (items.isNullOrEmpty() || anchor == null) {
            result.error("invalid_popup", "Os itens ou a âncora do menu são inválidos.", null)
            return
        }

        val content = findViewById<FrameLayout>(android.R.id.content)
        val flutterView = findFlutterView(content) ?: content
        val flutterLocation = IntArray(2)
        val contentLocation = IntArray(2)
        flutterView.getLocationOnScreen(flutterLocation)
        content.getLocationOnScreen(contentLocation)

        val density = resources.displayMetrics.density
        val right = (anchor["right"] as? Number)?.toDouble() ?: 0.0
        val bottom = (anchor["bottom"] as? Number)?.toDouble() ?: 0.0
        val leftMargin = (flutterLocation[0] - contentLocation[0] + right * density).roundToInt()
        val topMargin = (flutterLocation[1] - contentLocation[1] + bottom * density).roundToInt()

        val anchorView = View(this).apply {
            alpha = 0f
            isClickable = false
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val layoutParams = FrameLayout.LayoutParams(1, 1).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            this.leftMargin = leftMargin
            this.topMargin = topMargin
        }
        content.addView(anchorView, layoutParams)

        val isDark = isAppDarkTheme()
        val popupContext = ContextThemeWrapper(
            this,
            if (isDark) android.R.style.Theme_Material else android.R.style.Theme_Material_Light
        )
        val popup = PopupMenu(popupContext, anchorView, Gravity.END)
        val iconTint = if (isDark) Color.rgb(178, 180, 184) else Color.rgb(95, 99, 104)
        items.forEachIndexed { index, item ->
            val label = item["label"]?.toString().orEmpty()
            val menuItem = popup.menu.add(0, index, index, label)
            val iconBytes = item["icon"] as? ByteArray
            if (iconBytes != null) {
                val bitmap = BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
                if (bitmap != null) {
                    val drawable = BitmapDrawable(resources, bitmap)
                    val iconSize = (24 * density).roundToInt()
                    drawable.setBounds(0, 0, iconSize, iconSize)
                    drawable.setTint(iconTint)
                    menuItem.icon = drawable
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            popup.setForceShowIcon(true)
        } else {
            // Compatibilidade com versões anteriores ao método público API 29.
            try {
                popup.javaClass.getMethod("setForceShowIcon", Boolean::class.javaPrimitiveType)
                    .invoke(popup, true)
            } catch (_: Exception) {
                // O menu nativo continua funcional; apenas os ícones podem ser ocultados.
            }
        }

        var completed = false
        popup.setOnMenuItemClickListener { menuItem ->
            if (!completed) {
                completed = true
                result.success(items.getOrNull(menuItem.itemId)?.get("value"))
            }
            true
        }
        popup.setOnDismissListener {
            if (!completed) {
                completed = true
                result.success(null)
            }
            content.removeView(anchorView)
        }

        try {
            popup.show()
        } catch (error: RuntimeException) {
            content.removeView(anchorView)
            if (!completed) {
                completed = true
                result.error("popup_failed", error.message, null)
            }
        }
    }

    private fun isAppDarkTheme(): Boolean {
        val mode = readSavedThemeMode()
        return when (mode) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findFlutterView(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }
}

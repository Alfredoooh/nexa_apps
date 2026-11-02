package com.looply.app

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.animation.AlphaAnimation
import android.view.animation.AnimationSet
import android.view.animation.DecelerateInterpolator
import android.view.animation.ScaleAnimation
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.BitmapFactory
import android.graphics.drawable.GradientDrawable
import android.graphics.Typeface
import android.text.TextUtils
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
        fun dp(value: Number): Int = (value.toDouble() * density).roundToInt()
        val anchorLeft = flutterLocation[0] + dp(anchor["left"] as? Number ?: 0)
        val anchorTop = flutterLocation[1] + dp(anchor["top"] as? Number ?: 0)
        val anchorRight = flutterLocation[0] + dp(anchor["right"] as? Number ?: 0)
        val anchorBottom = flutterLocation[1] + dp(anchor["bottom"] as? Number ?: 0)
        val anchorCenterY = (anchorTop + anchorBottom) / 2

        val screenWidth = resources.displayMetrics.widthPixels
        val availableContentHeight = (content.height - dp(16)).coerceAtLeast(dp(180))
        val requestedWidth = call.argument<Number>("width")?.toDouble() ?: 252.0
        val popupWidth = dp(requestedWidth).coerceAtMost(screenWidth - dp(16)).coerceAtLeast(dp(190))
        val rowHeight = dp(48)
        val dividerHeight = dp(0.7).coerceAtLeast(1)
        val desiredHeight = rowHeight * items.size + dividerHeight * (items.size - 1)
        val popupHeight = desiredHeight.coerceAtMost(availableContentHeight)

        val dark = isAppDarkTheme()
        val pureBlack = isAppPureBlackTheme()
        val backgroundColor = when {
            dark && pureBlack -> Color.rgb(25, 25, 25)
            dark -> Color.rgb(43, 45, 48)
            else -> Color.rgb(255, 255, 255)
        }
        val textColor = if (dark) Color.rgb(230, 230, 232) else Color.rgb(32, 33, 36)
        val iconTint = if (dark) Color.rgb(178, 180, 184) else Color.rgb(95, 99, 104)
        val separatorColor = if (dark) Color.argb(115, 130, 134, 139) else Color.argb(115, 218, 220, 224)
        val outlineColor = if (dark) Color.rgb(64, 66, 70) else Color.rgb(232, 234, 237)

        fun newPopupBackground() = GradientDrawable().apply {
            setColor(backgroundColor)
            cornerRadius = dp(14).toFloat()
            setStroke(dp(1), outlineColor)
        }
        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        val scroll = ScrollView(this).apply {
            isFillViewport = false
            clipToOutline = true
            background = newPopupBackground()
            overScrollMode = View.OVER_SCROLL_NEVER
            addView(
                list,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }

        lateinit var popup: PopupWindow
        var completed = false
        items.forEachIndexed { index, item ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16), 0, dp(16), 0)
                isClickable = true
                isFocusable = true
                minimumHeight = rowHeight
            }

            val iconBytes = item["icon"] as? ByteArray
            if (iconBytes != null) {
                val bitmap = BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
                if (bitmap != null) {
                    val image = ImageView(this).apply {
                        // Ícone intencionalmente mais contido: 18 dp, próximo
                        // do tamanho visual dos símbolos usados no Flutter.
                        layoutParams = LinearLayout.LayoutParams(dp(18), dp(18)).apply {
                            marginEnd = dp(14)
                        }
                        scaleType = ImageView.ScaleType.FIT_CENTER
                        setImageBitmap(bitmap)
                        setColorFilter(iconTint)
                    }
                    row.addView(image)
                } else {
                    row.addView(View(this), LinearLayout.LayoutParams(dp(18), dp(18)).apply {
                        marginEnd = dp(14)
                    })
                }
            } else {
                row.addView(View(this), LinearLayout.LayoutParams(dp(18), dp(18)).apply {
                    marginEnd = dp(14)
                })
            }

            val label = TextView(this).apply {
                text = item["label"]?.toString().orEmpty()
                setTextColor(textColor)
                textSize = 14f
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                gravity = Gravity.CENTER_VERTICAL
                includeFontPadding = false
            }
            row.addView(
                label,
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f),
            )
            row.setOnClickListener {
                if (!completed) {
                    completed = true
                    result.success(item["value"])
                }
                popup.dismiss()
            }
            list.addView(
                row,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    rowHeight,
                ),
            )

            if (index < items.lastIndex) {
                val divider = View(this).apply {
                    setBackgroundColor(separatorColor)
                }
                list.addView(
                    divider,
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        dividerHeight,
                    ).apply {
                        leftMargin = dp(14)
                        rightMargin = dp(14)
                    },
                )
            }
        }

        popup = PopupWindow(scroll, popupWidth, popupHeight, true).apply {
            setBackgroundDrawable(newPopupBackground())
            isOutsideTouchable = true
            isFocusable = true
            isClippingEnabled = true
            elevation = dp(12).toFloat()
            setOnDismissListener {
                if (!completed) {
                    completed = true
                    result.success(null)
                }
            }
        }

        // O menu abre ao lado do controlo, centrado verticalmente na sua
        // âncora; não usa o comportamento padrão que o coloca sempre abaixo.
        val gap = dp(8)
        val spaceRight = screenWidth - anchorRight
        val spaceLeft = anchorLeft
        val opensRight = spaceRight >= popupWidth + gap || spaceRight >= spaceLeft
        val rawPopupX = if (opensRight) {
            anchorRight + gap
        } else {
            anchorLeft - popupWidth - gap
        }
        val popupXOnScreen = rawPopupX.coerceIn(
            dp(8),
            (screenWidth - popupWidth - dp(8)).coerceAtLeast(dp(8)),
        )

        val minY = contentLocation[1] + dp(8)
        val maxY = (contentLocation[1] + content.height - popupHeight - dp(8)).coerceAtLeast(minY)
        val popupYOnScreen = (anchorCenterY - popupHeight / 2).coerceIn(minY, maxY)
        val popupX = popupXOnScreen - contentLocation[0]
        val popupY = popupYOnScreen - contentLocation[1]

        try {
            popup.showAtLocation(content, Gravity.TOP or Gravity.LEFT, popupX, popupY)
            val pivotX = if (opensRight) 0.0f else 1.0f
            val animation = AnimationSet(true).apply {
                interpolator = DecelerateInterpolator(1.8f)
                duration = 190
                addAnimation(
                    ScaleAnimation(
                        .92f, 1f, .94f, 1f,
                        ScaleAnimation.RELATIVE_TO_SELF, pivotX,
                        ScaleAnimation.RELATIVE_TO_SELF, .5f,
                    ),
                )
                addAnimation(AlphaAnimation(0f, 1f))
            }
            scroll.startAnimation(animation)
        } catch (error: RuntimeException) {
            if (!completed) {
                completed = true
                result.error("popup_failed", error.message, null)
            }
            popup.dismiss()
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

    private fun isAppPureBlackTheme(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("flutter.looply_theme_pure_dark", false)
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

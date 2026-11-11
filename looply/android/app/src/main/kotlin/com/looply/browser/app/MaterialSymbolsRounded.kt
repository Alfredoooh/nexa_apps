package com.looply.browser.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.widget.TextView
import android.view.Gravity
import io.flutter.FlutterInjector

/**
 * Utiliza a própria fonte oficial Material Symbols Rounded já empacotada pelo
 * Flutter através de material_symbols_icons. Assim o browser Kotlin e a UI
 * Flutter desenham os mesmos glifos, sem SVGs ou ícones Android clássicos.
 */
internal object MaterialSymbolsRounded {
    private const val FONT_ASSET =
        "packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf"

    private val codePoints = mapOf(
        "home" to 0xE9B2,
        "tab" to 0xE8D8,
        "more_vert" to 0xE5D4,
        "arrow_upward" to 0xE5D8,
        "arrow_downward" to 0xE5DB,
        "close" to 0xE5CD,
        "arrow_back" to 0xE5C4,
        "arrow_forward" to 0xE5C8,
        "add" to 0xE145,
        "bookmark" to 0xE8E7,
        "bookmarks" to 0xE98B,
        "history" to 0xE8B3,
        "download" to 0xF090,
        "refresh" to 0xE5D5,
        "search" to 0xEF7A,
        "desktop_windows" to 0xE30C,
        "translate" to 0xE8E2,
        "text_decrease" to 0xEADD,
        "text_increase" to 0xEAE2,
        "print" to 0xE8AD,
        "content_copy" to 0xE14D,
        "share" to 0xE80D,
        "info" to 0xE88E,
        "settings" to 0xE8B8,
        "open_in_new" to 0xE89E,
        "image" to 0xE3F4,
        "star" to 0xF09A,
        "domino_mask" to 0xF5E4,
    )

    private val fontCache = mutableMapOf<Int, Typeface>()

    private fun font(context: Context): Typeface {
        val key = System.identityHashCode(context.applicationContext)
        return synchronized(fontCache) {
            fontCache[key] ?: run {
                val loader = FlutterInjector.instance().flutterLoader()
                val assetKey = loader.getLookupKeyForAsset(FONT_ASSET)
                Typeface.createFromAsset(context.assets, assetKey).also {
                    fontCache[key] = it
                }
            }
        }
    }

    fun glyph(name: String): String {
        val codePoint = codePoints[name]
            ?: throw IllegalArgumentException("Símbolo Material não registado: $name")
        return String(Character.toChars(codePoint))
    }

    fun textView(
        context: Context,
        name: String,
        color: Int,
        sizeSp: Float,
        description: String? = null,
    ): TextView {
        return TextView(context).apply {
            text = glyph(name)
            typeface = font(context)
            textSize = sizeSp
            setTextColor(color)
            gravity = Gravity.CENTER
            includeFontPadding = false
            contentDescription = description
            isSingleLine = true
            importantForAccessibility = if (description == null) {
                android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
            } else {
                android.view.View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
        }
    }

    fun bitmapDrawable(
        context: Context,
        name: String,
        color: Int,
        sizePx: Int,
    ): Drawable {
        val dimension = sizePx.coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(dimension, dimension, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            typeface = font(context)
            textAlign = Paint.Align.CENTER
            textSize = dimension * .88f
            this.color = color
        }
        val baseline = dimension / 2f - (paint.ascent() + paint.descent()) / 2f
        canvas.drawText(glyph(name), dimension / 2f, baseline, paint)
        return BitmapDrawable(context.resources, bitmap)
    }
}

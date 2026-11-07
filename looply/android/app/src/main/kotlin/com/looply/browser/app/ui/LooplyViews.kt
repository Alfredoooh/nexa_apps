package com.looply.browser.app.ui

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.roundToInt

internal fun Context.dp(value: Number): Int = (resources.displayMetrics.density * value.toFloat()).roundToInt()

internal fun rounded(color: Int, radiusDp: Float, context: Context, stroke: Int = Color.TRANSPARENT, strokeDp: Float = 0f): GradientDrawable =
    GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = context.dp(radiusDp).toFloat()
        if (strokeDp > 0f) setStroke(context.dp(strokeDp), stroke)
    }

internal fun ripple(context: Context, color: Int, radiusDp: Float, pressed: Int = 0x1F5F6368): RippleDrawable =
    RippleDrawable(ColorStateList.valueOf(pressed), rounded(color, radiusDp, context), null)

/**
 * weight accepts Typeface.NORMAL / Typeface.BOLD / Typeface.ITALIC / Typeface.BOLD_ITALIC as before.
 * A medium-weight look (previously the invalid Typeface.MEDIUM) is now requested via useMediumFamily = true,
 * which switches the font family to "sans-serif-medium" instead of relying on a non-existent Typeface constant.
 */
internal fun textView(context: Context, text: CharSequence, size: Float, color: Int, weight: Int = Typeface.NORMAL, useMediumFamily: Boolean = false): TextView =
    TextView(context).apply {
        this.text = text
        textSize = size
        setTextColor(color)
        typeface = if (useMediumFamily) Typeface.create("sans-serif-medium", Typeface.NORMAL) else Typeface.create("sans-serif", weight)
        includeFontPadding = false
        gravity = Gravity.CENTER_VERTICAL
    }

internal fun linear(context: Context, vertical: Boolean = false): LinearLayout = LinearLayout(context).apply {
    orientation = if (vertical) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
}

internal fun spacer(context: Context, heightDp: Int): View = View(context).apply {
    layoutParams = LinearLayout.LayoutParams(1, context.dp(heightDp))
}

internal fun label(context: Context, value: String, palette: LooplyPalette, size: Float = 14f, weight: Int = Typeface.NORMAL, useMediumFamily: Boolean = false): TextView =
    textView(context, value, size, palette.text, weight, useMediumFamily)

internal fun subLabel(context: Context, value: String, palette: LooplyPalette, size: Float = 12f): TextView =
    textView(context, value, size, palette.muted)

internal fun panel(context: Context, palette: LooplyPalette, radiusDp: Float = 22f): LinearLayout = linear(context, true).apply {
    background = rounded(palette.pill, radiusDp, context)
    clipToOutline = true
}

internal fun cardText(context: Context, title: String, subtitle: String?, palette: LooplyPalette): LinearLayout = linear(context, true).apply {
    addView(label(context, title, palette, 14f, Typeface.NORMAL, useMediumFamily = true))
    if (!subtitle.isNullOrBlank()) {
        addView(subLabel(context, subtitle, palette, 12f).apply { setPadding(0, context.dp(4), 0, 0) })
    }
}

internal fun makeScroll(context: Context, child: View): ScrollView = ScrollView(context).apply {
    isFillViewport = true
    clipToPadding = false
    addView(child, ScrollView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
}

internal fun iconImage(context: Context, icon: String, sizeDp: Int, tint: Int): LooplyIconView = LooplyIconView(context, icon).apply {
    this.tint = tint
    layoutParams = ViewGroup.LayoutParams(context.dp(sizeDp), context.dp(sizeDp))
}

internal fun iconButton(context: Context, icon: String, sizeDp: Int, tint: Int, bg: Int, description: String, onClick: () -> Unit): FrameLayout =
    FrameLayout(context).apply {
        isClickable = true
        isFocusable = true
        contentDescription = description
        background = ripple(context, bg, sizeDp / 2f)
        setOnClickListener { onClick() }
        addView(LooplyIconView(context, icon).apply { this.tint = tint }, FrameLayout.LayoutParams(context.dp(22), context.dp(22), Gravity.CENTER))
        minimumWidth = context.dp(sizeDp)
        minimumHeight = context.dp(sizeDp)
    }

internal fun assetImage(context: Context, asset: String): ImageView = ImageView(context).apply {
    scaleType = ImageView.ScaleType.FIT_CENTER
    try { assets.open(asset).use { stream -> setImageDrawable(android.graphics.drawable.Drawable.createFromStream(stream, null)) } } catch (_: Exception) { }
}
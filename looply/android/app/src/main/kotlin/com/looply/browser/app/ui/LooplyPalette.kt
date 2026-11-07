package com.looply.browser.app.ui

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.view.Window
import androidx.core.view.WindowInsetsControllerCompat

/** Color tokens copied from lib/theme.dart without changing their RGB/alpha values. */
data class LooplyPalette(
    val dark: Boolean,
    val pureBlack: Boolean,
    val background: Int,
    val panel: Int,
    val pill: Int,
    val soft: Int,
    val text: Int,
    val muted: Int,
    val line: Int,
    val accent: Int,
) {
    companion object {
        fun resolve(context: Context, mode: String, pureBlack: Boolean): LooplyPalette {
            val systemDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            val dark = when (mode) { "light" -> false; "dark" -> true; else -> systemDark }
            return if (!dark) LooplyPalette(
                false, false, Color.WHITE, Color.WHITE, 0xFFF0F1F3.toInt(), 0xFFF8F9FA.toInt(),
                0xFF202124.toInt(), 0xFF5F6368.toInt(), 0xFFE8EAED.toInt(), 0xFF1A73E8.toInt(),
            ) else if (pureBlack) LooplyPalette(
                true, true, Color.BLACK, 0xFF101010.toInt(), 0xFF191919.toInt(), 0xFF050505.toInt(),
                0xFFE6E6E8.toInt(), 0xFFB2B4B8.toInt(), 0xFF292929.toInt(), 0xFF8AB4F8.toInt(),
            ) else LooplyPalette(
                true, false, 0xFF141517.toInt(), 0xFF212325.toInt(), 0xFF2B2D30.toInt(), 0xFF1D1F21.toInt(),
                0xFFE6E6E8.toInt(), 0xFFB2B4B8.toInt(), 0xFF34363A.toInt(), 0xFF8AB4F8.toInt(),
            )
        }

        fun applyToWindow(window: Window, palette: LooplyPalette) {
            window.statusBarColor = palette.background
            window.navigationBarColor = palette.background
            window.decorView.setBackgroundColor(palette.background)
            WindowInsetsControllerCompat(window, window.decorView).apply {
                isAppearanceLightStatusBars = !palette.dark
                isAppearanceLightNavigationBars = !palette.dark
            }
        }
    }
}

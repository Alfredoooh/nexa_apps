package com.looply.browser.app.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Picture
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.view.View
import com.caverock.androidsvg.SVG

/** Renders the original Looply wordmark SVG as a native Android View. */
class LooplyLogoView(context: Context) : View(context) {
    var tint: Int = Color.BLACK
        set(value) { field = value; invalidate() }
    private val picture: Picture? = try {
        SVG.getFromAsset(context.assets, "images/logo_text.svg").renderToPicture(240, 48)
    } catch (_: Exception) { null }
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        colorFilter = PorterDuffColorFilter(tint, PorterDuff.Mode.SRC_IN)
    }
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        paint.colorFilter = PorterDuffColorFilter(tint, PorterDuff.Mode.SRC_IN)
        picture?.let { pic ->
            val save = canvas.save()
            canvas.scale(width / 240f, height / 48f)
            val layer = canvas.saveLayer(0f, 0f, 240f, 48f, paint)
            canvas.drawPicture(pic)
            canvas.restoreToCount(layer)
            canvas.restoreToCount(save)
        }
    }
}
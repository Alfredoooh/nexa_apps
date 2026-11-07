package com.looply.browser.app.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Picture
import android.graphics.Color
import android.view.View
import com.caverock.androidsvg.SVG
import com.looply.browser.app.icons.phosphor.LooplySvgIconRegistry

/** AndroidSVG renderer. Every Phosphor SVG source is embedded in its Kotlin file. */
class LooplyIconView(context: Context, private val name: String) : View(context) {
    var tint: Int = Color.BLACK
        set(value) { field = value; picture = render(); invalidate() }
    private var picture: Picture? = null

    init { picture = render(); contentDescription = name.replace('-', ' ') }

    private fun render(): Picture? {
        val key = if (name.contains('/')) name else "regular/$name"
        val raw = LooplySvgIconRegistry.source(key) ?: LooplySvgIconRegistry.source("regular/$name")
            ?: LooplySvgIconRegistry.source("fill/$name") ?: return null
        val hex = "#%06X".format(0xFFFFFF and tint)
        val tinted = raw
            .replace("#000000", hex, ignoreCase = true)
            .replace("#000", hex, ignoreCase = true)
            .replace("rgb(0,0,0)", hex, ignoreCase = true)
            .replace("rgb(0, 0, 0)", hex, ignoreCase = true)
            .replace("currentColor", hex, ignoreCase = true)
        return try {
            SVG.getFromString(tinted).renderToPicture(24, 24)
        } catch (_: Exception) { null }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val image = picture ?: return
        if (width <= 0 || height <= 0) return
        val side = minOf(width, height).toFloat()
        val save = canvas.save()
        canvas.translate((width - side) / 2f, (height - side) / 2f)
        canvas.scale(side / 24f, side / 24f)
        canvas.drawPicture(image)
        canvas.restoreToCount(save)
    }
}

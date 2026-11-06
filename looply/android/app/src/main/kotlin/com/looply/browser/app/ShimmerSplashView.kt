package com.looply.browser.app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Shader
import android.view.View
import android.view.animation.LinearInterpolator
import androidx.appcompat.content.res.AppCompatResources
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Pequena camada de splash mostrada por cima do primeiro frame do Flutter.
 * O gradiente é recortado pela transparência do próprio logótipo, portanto
 * o shimmer percorre apenas os traços e nunca o fundo/contêiner.
 */
internal class ShimmerSplashView(
    context: Context,
    private val darkTheme: Boolean,
    private val pureBlack: Boolean,
) : View(context) {

    private val splashBackground = when {
        !darkTheme -> Color.WHITE
        pureBlack -> Color.BLACK
        else -> Color.rgb(23, 24, 26)
    }

    private val baseColor = if (darkTheme) {
        Color.rgb(190, 192, 195)
    } else {
        Color.rgb(105, 107, 111)
    }

    private val highlightColor = if (darkTheme) {
        Color.WHITE
    } else {
        Color.rgb(220, 221, 223)
    }

    private val logoBounds = RectF()
    private val shimmerPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
        xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
    }

    private var logoMask: Bitmap? = null
    private var shimmerAnimator: ValueAnimator? = null
    private var shimmerPosition = 0f

    private val preferredLogoSize = (184f * resources.displayMetrics.density).roundToInt()

    init {
        setBackgroundColor(splashBackground)
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        isFocusable = false
        isClickable = true
        setWillNotDraw(false)
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        super.onSizeChanged(width, height, oldWidth, oldHeight)
        if (width <= 0 || height <= 0) return

        val size = min(preferredLogoSize.toFloat(), min(width, height) * 0.62f)
        val left = (width - size) / 2f
        val top = (height - size) / 2f
        logoBounds.set(left, top, left + size, top + size)

        createLogoMask(size.roundToInt())
        startShimmer()
    }

    private fun createLogoMask(size: Int) {
        logoMask?.takeIf { !it.isRecycled }?.recycle()
        if (size <= 0) {
            logoMask = null
            return
        }

        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val bitmapCanvas = Canvas(bitmap)
        val logoDrawable = AppCompatResources.getDrawable(context, R.drawable.launch_logo)
        if (logoDrawable != null) {
            logoDrawable.setBounds(0, 0, size, size)
            logoDrawable.draw(bitmapCanvas)
        }
        logoMask = bitmap
    }

    private fun startShimmer() {
        shimmerAnimator?.cancel()
        val width = logoBounds.width()
        if (width <= 0f) return

        shimmerAnimator = ValueAnimator.ofFloat(
            logoBounds.left - width,
            logoBounds.right,
        ).apply {
            duration = 1750L
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener { animation ->
                shimmerPosition = animation.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val mask = logoMask ?: return
        if (mask.isRecycled || logoBounds.isEmpty) return

        // O gradiente é o conteúdo (destination); a imagem do logótipo é a
        // máscara alfa (source). DST_IN mantém o brilho exclusivamente nos
        // píxeis opacos do símbolo e deixa todo o restante transparente.
        val layer = canvas.saveLayer(logoBounds, null)
        shimmerPaint.shader = LinearGradient(
            shimmerPosition,
            logoBounds.top,
            shimmerPosition + logoBounds.width(),
            logoBounds.bottom,
            intArrayOf(
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
            ),
            floatArrayOf(0f, 0.40f, 0.50f, 0.60f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(logoBounds, shimmerPaint)
        shimmerPaint.shader = null
        canvas.drawBitmap(mask, null, logoBounds, maskPaint)
        canvas.restoreToCount(layer)
    }

    /** Liberta o bitmap/animador quando a camada deixa de ser necessária. */
    fun dispose() {
        shimmerAnimator?.cancel()
        shimmerAnimator = null
        logoMask?.takeIf { !it.isRecycled }?.recycle()
        logoMask = null
    }

    override fun onDetachedFromWindow() {
        shimmerAnimator?.cancel()
        shimmerAnimator = null
        super.onDetachedFromWindow()
    }
}

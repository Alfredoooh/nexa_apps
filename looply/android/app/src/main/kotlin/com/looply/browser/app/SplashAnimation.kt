package com.looply.browser.app

import android.graphics.ImageDecoder
import android.graphics.drawable.AnimatedImageDrawable
import android.graphics.drawable.AnimationDrawable
import android.os.Build
import android.widget.ImageView

/**
 * Plays the provided splash asset once. Animated WebP is used on Android 9+;
 * older releases use a native AnimationDrawable built from sampled PNG frames.
 */
internal fun ImageView.playSplashCircle(onFinished: () -> Unit) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
        val legacy = runCatching {
            resources.getDrawable(R.drawable.splash_circle_legacy, context.theme) as? AnimationDrawable
        }.getOrNull()
        if (legacy == null) {
            setImageResource(R.drawable.splash_circle_static)
            postDelayed(onFinished, 650L)
            return
        }
        legacy.isOneShot = true
        val duration = (0 until legacy.numberOfFrames)
            .sumOf { legacy.getDuration(it).toLong() }
            .coerceAtLeast(650L)
        setImageDrawable(legacy)
        post { legacy.start() }
        postDelayed(onFinished, duration + 80L)
        return
    }

    try {
        val source = ImageDecoder.createSource(resources, R.drawable.splash_circle)
        val drawable = ImageDecoder.decodeDrawable(source) as? AnimatedImageDrawable
        if (drawable == null) {
            setImageResource(R.drawable.splash_circle_static)
            postDelayed(onFinished, 650L)
            return
        }
        drawable.repeatCount = 0
        drawable.registerAnimationCallback(object : AnimatedImageDrawable.AnimationCallback() {
            override fun onAnimationEnd(drawable: android.graphics.drawable.Drawable) {
                post(onFinished)
            }
        })
        setImageDrawable(drawable)
        drawable.start()
    } catch (_: Exception) {
        setImageResource(R.drawable.splash_circle_static)
        postDelayed(onFinished, 650L)
    }
}

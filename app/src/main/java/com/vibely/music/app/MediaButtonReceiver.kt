package com.vibely.music.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.media.session.MediaButtonReceiver

class MediaButtonReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        MediaButtonReceiver.handleIntent(PlaybackService.mediaSession, intent)
    }
}
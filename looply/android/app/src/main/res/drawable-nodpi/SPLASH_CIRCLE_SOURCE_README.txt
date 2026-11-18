SPLASH CIRCLE — ANDROID DRAWABLE

Source supplied by the user:
  res/drawable-nodpi/splash_circle.webp

Characteristics:
- Lossless animated WebP with real alpha channel.
- 512 × 512 px, 30 fps, 60 frames, approximately 2 seconds.
- Transparent background; one-shot playback.
- Uses AnimatedImageDrawable on Android 9 (API 28) and newer.

Legacy Android fallback:
- Android versions below API 28 use splash_circle_legacy.xml.
- That AnimationDrawable references 30 sampled PNG frames (15 fps) extracted
  from the exact supplied WebP, with a total duration of approximately 2 seconds.
- splash_circle_static.png remains a final safe fallback if drawable decoding
  fails on a device with a modified Android implementation.

Splash background:
- MainActivity reads the saved BrowseIt app theme preference.
- Light app theme uses white; dark app theme uses #17181A.
- The splash does not use the app's AMOLED/pure-black variant.

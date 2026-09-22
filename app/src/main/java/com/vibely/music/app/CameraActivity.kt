package com.vibely.music.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale

// Câmera nativa (só fotos). O preview é 100% nativo (CameraX). A aparência do ecrã
// (botões, moldura, respeito pela safe area/appbar) é um WebView transparente por cima,
// carregando a mesma app em modo câmera. Usa navegação nativa: botão/gesto de voltar do
// sistema fecha a Activity normalmente (OnBackPressedCallback), tal como qualquer outro
// ecrã nativo do Android — sem depender do histórico do WebView.
class CameraActivity : AppCompatActivity() {

    private lateinit var previewView: PreviewView
    private lateinit var overlayWeb: android.webkit.WebView
    private lateinit var root: FrameLayout

    private var imageCapture: ImageCapture? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var torchOn = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Edge-to-edge igual ao MainActivity, para a UI desenhada pelo WebView por cima
        // respeitar a mesma safe area/altura de appbar usada no resto da app.
        WindowCompat.setDecorFitsSystemWindows(window, false)

        root = FrameLayout(this)
        setContentView(root)

        previewView = PreviewView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        root.addView(previewView)

        overlayWeb = android.webkit.WebView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            addJavascriptInterface(CameraBridge(), "AndroidCamera")
        }
        root.addView(overlayWeb)

        val appUrl = intent.getStringExtra("appUrl") ?: "file:///android_asset/app/index.html"
        val separator = if (appUrl.contains("?")) "&" else "?"
        overlayWeb.loadUrl("$appUrl${separator}camera=1")

        // Navegação nativa: o botão/gesto de voltar do sistema fecha esta Activity
        // diretamente (como qualquer ecrã nativo), sem passar pelo JS.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() { finish() }
        })

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 2001)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2001) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera()
            } else {
                Log.w("VibelyCamera", "Permissão de câmera negada")
                finish()
            }
        }
    }

    private fun startCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            try {
                cameraProvider = providerFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .build()

                val selector = CameraSelector.DEFAULT_BACK_CAMERA
                cameraProvider?.unbindAll()
                camera = cameraProvider?.bindToLifecycle(this, selector, preview, imageCapture)
            } catch (e: Exception) {
                Log.e("VibelyCamera", "Falha ao iniciar câmera: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun hasFlashUnit(): Boolean = camera?.cameraInfo?.hasFlashUnit() == true

    private fun setTorch(on: Boolean): Boolean {
        val cam = camera ?: return false
        if (!hasFlashUnit()) return false
        return try {
            cam.cameraControl.enableTorch(on)
            torchOn = on
            true
        } catch (e: Exception) { false }
    }

    private fun takePhoto() {
        val capture = imageCapture ?: return
        val dir = File(cacheDir, "camera").apply { mkdirs() }
        val name = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(java.util.Date()) + ".jpg"
        val file = File(dir, name)
        val output = ImageCapture.OutputFileOptions.Builder(file).build()

        capture.takePicture(output, ContextCompat.getMainExecutor(this), object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(results: ImageCapture.OutputFileResults) {
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this@CameraActivity, "$packageName.fileprovider", file
                )
                runOnUiThread {
                    notifyMainWebView(uri.toString())
                    finish()
                }
            }

            override fun onError(exception: ImageCaptureException) {
                Log.e("VibelyCamera", "Erro ao capturar: ${exception.message}")
                runOnUiThread { finish() }
            }
        })
    }

    private fun notifyMainWebView(fileUriString: String) {
        val safe = fileUriString.replace("\\", "\\\\").replace("'", "\\'")
        val js = "(function(){try{if(window.onNativePhotoCaptured){window.onNativePhotoCaptured('$safe');}}catch(e){}})()"
        MainActivityInstance.instance?.let { activity ->
            activity.runOnUiThread { activity.evaluateInWebView(js) }
        }
    }

    override fun onDestroy() {
        try { if (torchOn) setTorch(false) } catch (_: Exception) {}
        cameraProvider?.unbindAll()
        super.onDestroy()
    }

    inner class CameraBridge {
        @android.webkit.JavascriptInterface
        fun isInsideApp(): Boolean = true

        @android.webkit.JavascriptInterface
        fun capture() { runOnUiThread { takePhoto() } }

        @android.webkit.JavascriptInterface
        fun hasFlash(): Boolean = hasFlashUnit()

        @android.webkit.JavascriptInterface
        fun toggleFlash(on: Boolean): Boolean = setTorch(on)

        @android.webkit.JavascriptInterface
        fun isFlashOn(): Boolean = torchOn

        @android.webkit.JavascriptInterface
        fun closeCamera() { runOnUiThread { finish() } }
    }
}
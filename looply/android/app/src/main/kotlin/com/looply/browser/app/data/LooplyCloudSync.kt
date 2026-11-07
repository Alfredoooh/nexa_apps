package com.looply.browser.app.data

import android.content.Context
import android.util.Base64
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Secure-session and Cloudflare Worker transport ported from cloud_sync.dart. */
class LooplyCloudSync(private val context: Context, private val store: LooplyStore) {
    private val baseUrl = BuildConfig.BROWSEIT_WORKER_URL.trim().trimEnd('/')
    val configured: Boolean get() = baseUrl.startsWith("https://") && !baseUrl.contains("YOUR_SUBDOMAIN")

    suspend fun createChallenge(): String? = withContext(Dispatchers.IO) {
        if (!configured) return@withContext null
        val response = request("POST", "/api/v1/auth/challenge", null, mapOf("Accept" to "application/json"))
        if (response.first !in 200..299) throw IllegalStateException(response.second.optString("error", "Não foi possível iniciar a autenticação segura."))
        response.second.optString("nonce").takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("O servidor não devolveu um desafio de autenticação válido.")
    }

    suspend fun authenticate(idToken: String, nonce: String) = withContext(Dispatchers.IO) {
        if (!configured) return@withContext
        val body = JSONObject().put("idToken", idToken).put("nonce", nonce)
        val response = request("POST", "/api/v1/auth/google", body, mapOf("Content-Type" to "application/json", "Accept" to "application/json"))
        if (response.first !in 200..299) throw IllegalStateException(response.second.optString("error", "O servidor não aceitou a conta Google."))
        val token = response.second.optString("sessionToken")
        if (token.length < 32) throw IllegalStateException("O servidor não devolveu uma sessão válida.")
        saveSecureToken(token)
    }

    suspend fun uploadBackup() = withContext(Dispatchers.IO) {
        if (!configured) return@withContext
        val token = readSecureToken() ?: return@withContext
        val all = store.prefs.all
        val preferences = JSONObject()
        all.forEach { (key, value) ->
            if (!key.startsWith("flutter.looply_") || key.startsWith("flutter.looply_auth_")) return@forEach
            when (value) {
                is String -> preferences.put(key.removePrefix("flutter."), value)
                is Boolean, is Int, is Long, is Float, is Double -> preferences.put(key.removePrefix("flutter."), value)
                is Set<*> -> preferences.put(key.removePrefix("flutter."), org.json.JSONArray(value.filterIsInstance<String>()))
            }
        }
        val backup = JSONObject().put("format", "looply-backup").put("schemaVersion", 1)
            .put("exportedAt", java.time.Instant.now().toString())
            .put("sync", JSONObject().put("mode", "local").put("userId", JSONObject.NULL).put("revision", 1).put("lastSyncedAt", JSONObject.NULL))
            .put("preferences", preferences).put("tabSnapshots", JSONObject()).put("favicons", JSONObject())
        val response = request("PUT", "/api/v1/me/data/app-backup", JSONObject().put("data", backup), mapOf(
            "Authorization" to "Bearer $token", "Content-Type" to "application/json", "Accept" to "application/json"
        ))
        if (response.first == 401) { deleteSecureToken(); return@withContext }
        if (response.first !in 200..299) throw IllegalStateException(response.second.optString("error", "Não foi possível sincronizar o backup."))
    }

    suspend fun signOut() = withContext(Dispatchers.IO) {
        val token = readSecureToken()
        if (configured && !token.isNullOrBlank()) {
            try { request("POST", "/api/v1/auth/logout", null, mapOf("Authorization" to "Bearer $token")) } catch (_: Exception) { }
        }
        deleteSecureToken()
    }

    private fun request(method: String, path: String, body: JSONObject?, headers: Map<String, String>): Pair<Int, JSONObject> {
        val connection = URL(baseUrl + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 15000
            connection.readTimeout = 25000
            connection.doInput = true
            headers.forEach { (key, value) -> connection.setRequestProperty(key, value) }
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", headers["Content-Type"] ?: "application/json")
                connection.outputStream.use { output ->
                    output.write(body.toString().toByteArray(Charsets.UTF_8))
                    output.flush()
                }
            }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val responseJson = try { JSONObject(responseText) } catch (_: Exception) { JSONObject() }
            return code to responseJson
        } finally {
            connection.disconnect()
        }
    }

    private fun loadKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "looply_cloud_session_aes"
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance("AES", "AndroidKeyStore")
        val spec = android.security.keystore.KeyGenParameterSpec.Builder(alias,
            android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or android.security.keystore.KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256).build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun saveSecureToken(token: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, loadKey())
        val encrypted = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
        val combined = cipher.iv + encrypted
        context.getSharedPreferences("LooplySecureSession", Context.MODE_PRIVATE).edit()
            .putString("browseit_cloud_session_v1", Base64.encodeToString(combined, Base64.NO_WRAP)).apply()
    }

    private fun readSecureToken(): String? {
        return try {
            val encoded = context.getSharedPreferences("LooplySecureSession", Context.MODE_PRIVATE)
                .getString("browseit_cloud_session_v1", null) ?: return null
            val combined = Base64.decode(encoded, Base64.NO_WRAP)
            if (combined.size <= 12) return null
            val iv = combined.copyOfRange(0, 12)
            val payload = combined.copyOfRange(12, combined.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, loadKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(payload), Charsets.UTF_8)
        } catch (_: Exception) { null }
    }

    private fun deleteSecureToken() {
        context.getSharedPreferences("LooplySecureSession", Context.MODE_PRIVATE).edit().remove("browseit_cloud_session_v1").apply()
    }
}

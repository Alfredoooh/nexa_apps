package com.looply.browser.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/** Keeps a salted credential verifier protected by a non-exportable Android Keystore key. */
internal object BrowserSecurityStore {
    private const val PREFS = "browseit_browser_security_v1"
    private const val KEY_MODE = "credential_mode"
    private const val KEY_SALT = "credential_salt"
    private const val KEY_HASH = "credential_hash"
    private const val KEY_FAIL_COUNT = "failed_attempt_count"
    private const val KEY_LOCK_UNTIL = "locked_until_ms"
    private const val KEY_ALIAS = "browseit_browser_security_hmac_v1"
    private const val ITERATIONS = 210_000
    private const val KEY_BITS = 256
    private const val MAX_ATTEMPTS = 5
    private const val LOCK_DURATION_MS = 30_000L

    fun hasCredential(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return !prefs.getString(KEY_SALT, null).isNullOrBlank() &&
            !prefs.getString(KEY_HASH, null).isNullOrBlank() &&
            prefs.getString(KEY_MODE, null) in setOf("pin", "password")
    }

    fun credentialMode(context: Context): String {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_MODE, "pin") ?: "pin"
    }

    fun setCredential(context: Context, mode: String, secret: String): Boolean {
        if (mode !in setOf("pin", "password")) return false
        val valid = if (mode == "pin") secret.matches(Regex("^[0-9]{4,12}$"))
                    else secret.length in 8..64
        if (!valid) return false
        return runCatching {
            val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
            val protectedVerifier = protect(derive(secret, salt))
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_MODE, mode)
                .putString(KEY_SALT, Base64.encodeToString(salt, Base64.NO_WRAP))
                .putString(KEY_HASH, Base64.encodeToString(protectedVerifier, Base64.NO_WRAP))
                .putInt(KEY_FAIL_COUNT, 0)
                .putLong(KEY_LOCK_UNTIL, 0L)
                .commit()
        }.getOrDefault(false)
    }

    fun verify(context: Context, candidate: String): Boolean {
        return runCatching {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            if (prefs.getLong(KEY_LOCK_UNTIL, 0L) > now) return false

            val saltEncoded = prefs.getString(KEY_SALT, null) ?: return false
            val hashEncoded = prefs.getString(KEY_HASH, null) ?: return false
            val salt = Base64.decode(saltEncoded, Base64.NO_WRAP)
            val expected = Base64.decode(hashEncoded, Base64.NO_WRAP)
            val actual = protect(derive(candidate, salt))
            val matches = MessageDigest.isEqual(expected, actual)
            if (matches) {
                prefs.edit().putInt(KEY_FAIL_COUNT, 0).putLong(KEY_LOCK_UNTIL, 0L).apply()
                true
            } else {
                val failures = prefs.getInt(KEY_FAIL_COUNT, 0) + 1
                prefs.edit()
                    .putInt(KEY_FAIL_COUNT, if (failures >= MAX_ATTEMPTS) 0 else failures)
                    .putLong(KEY_LOCK_UNTIL, if (failures >= MAX_ATTEMPTS) now + LOCK_DURATION_MS else 0L)
                    .apply()
                false
            }
        }.getOrDefault(false)
    }

    private fun protect(value: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(loadOrCreateKeystoreKey())
        return mac.doFinal(value)
    }

    private fun loadOrCreateKeystoreKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_HMAC_SHA256,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
            )
                .setDigests(KeyProperties.DIGEST_SHA256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun derive(secret: String, salt: ByteArray): ByteArray {
        val spec = PBEKeySpec(secret.toCharArray(), salt, ITERATIONS, KEY_BITS)
        return try {
            SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                .generateSecret(spec).encoded
        } finally {
            spec.clearPassword()
        }
    }
}

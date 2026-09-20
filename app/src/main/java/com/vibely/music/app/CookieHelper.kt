package com.vibely.music.app

import android.webkit.CookieManager

object CookieHelper {

    // Domínios de onde lemos a sessão. Só o que é do YouTube/Google, mais nada.
    private val urls = listOf(
        "https://www.youtube.com",
        "https://youtube.com",
        "https://accounts.google.com",
        "https://www.google.com"
    )

    // Cookies que realmente identificam a sessão logada
    private val sessionNames = setOf(
        "SID", "HSID", "SSID", "APISID", "SAPISID",
        "__Secure-1PSID", "__Secure-3PSID",
        "__Secure-1PAPISID", "__Secure-3PAPISID",
        "__Secure-1PSIDTS", "__Secure-3PSIDTS",
        "LOGIN_INFO", "PREF", "VISITOR_INFO1_LIVE", "YSC"
    )

    fun isLoggedIn(): Boolean {
        val cm = CookieManager.getInstance()
        return urls.any { url ->
            val raw = cm.getCookie(url) ?: return@any false
            raw.split(";").any {
                val name = it.substringBefore("=").trim()
                name == "SAPISID" || name == "__Secure-3PAPISID" || name == "LOGIN_INFO"
            }
        }
    }

    // Devolve os cookies no formato Netscape (cookies.txt). Vazio se não estiver logado.
    fun exportNetscape(): String {
        if (!isLoggedIn()) return ""
        val cm = CookieManager.getInstance()
        val seen = HashSet<String>()
        val sb = StringBuilder()
        sb.append("# Netscape HTTP Cookie File\n")

        for (url in urls) {
            val raw = cm.getCookie(url) ?: continue
            val host = url.removePrefix("https://")
            for (pair in raw.split(";")) {
                val name = pair.substringBefore("=").trim()
                val value = pair.substringAfter("=", "").trim()
                if (name.isEmpty() || name !in sessionNames) continue
                val id = "$host|$name"
                if (!seen.add(id)) continue

                val domain = if (host.startsWith("www.")) host.removePrefix("www") else ".$host"
                val secure = "TRUE"
                // Expiração longe no futuro: o servidor só precisa do valor
                val expires = "2147483647"
                sb.append("$domain\tTRUE\t/\t$secure\t$expires\t$name\t$value\n")
            }
        }
        return sb.toString()
    }

    fun clear() {
        val cm = CookieManager.getInstance()
        for (url in urls) {
            val raw = cm.getCookie(url) ?: continue
            for (pair in raw.split(";")) {
                val name = pair.substringBefore("=").trim()
                if (name.isNotEmpty()) {
                    cm.setCookie(url, "$name=; Max-Age=0; Path=/")
                }
            }
        }
        cm.flush()
    }
}
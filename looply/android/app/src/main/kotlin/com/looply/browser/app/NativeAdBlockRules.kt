package com.looply.browser.app

import android.content.Context
import android.net.Uri
import android.util.Base64
import android.webkit.WebResourceRequest
import java.io.BufferedInputStream
import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.StringReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.GZIPInputStream

/**
 * Native WebView network filter backed by EasyList, EasyPrivacy and a hosts list.
 * Supports domain-anchored ABP rules, domain/third-party conditions, resource
 * type conditions and exception rules. Unsupported cosmetic/regex syntax is
 * deliberately ignored rather than interpreted as a broad blocking rule.
 */
internal class NativeAdBlockRules private constructor(context: Context) {
    private data class ScopedRule(
        val host: String,
        val exception: Boolean,
        val thirdPartyOnly: Boolean?,
        val includeDomains: Set<String>,
        val excludeDomains: Set<String>,
        val pathToken: String?,
        val includeTypes: Set<String>,
        val excludeTypes: Set<String>,
    )

    private data class Snapshot(
        val blockedHosts: Set<String> = emptySet(),
        val thirdPartyHosts: Set<String> = emptySet(),
        val allowedHosts: Set<String> = emptySet(),
        val pathTokens: Set<String> = emptySet(),
        val scopedRules: List<ScopedRule> = emptyList(),
    ) {
        // Index once when a list is compiled/loaded. shouldBlock() then checks
        // only the exact host and its parent domains instead of scanning tens
        // of thousands of unrelated ABP rules on every WebView request.
        val scopedRulesByHost: Map<String, List<ScopedRule>> = scopedRules.groupBy { it.host }
    }

    private val appContext = context.applicationContext
    private val cacheFile = File(appContext.filesDir, "native_adblock_rules_v2.txt")
    private val prefs = appContext.getSharedPreferences("browseit_native_adblock", Context.MODE_PRIVATE)
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "BrowseIt-AdBlock-Rules").apply { isDaemon = true }
    }
    private val started = AtomicBoolean(false)

    @Volatile
    private var snapshot = Snapshot()

    fun start() {
        if (!started.compareAndSet(false, true)) return
        executor.execute {
            loadCachedRules()
            val lastUpdate = prefs.getLong(KEY_LAST_UPDATE, 0L)
            if (System.currentTimeMillis() - lastUpdate >= UPDATE_INTERVAL_MS) refreshLists()
        }
    }

    fun shouldBlock(uri: Uri, pageUrl: String, request: WebResourceRequest? = null): Boolean {
        val host = uri.host?.lowercase(Locale.ROOT)?.trimEnd('.') ?: return false
        if (host.isBlank()) return false
        val rules = snapshot
        if (matchesHost(host, rules.allowedHosts)) return false

        val pageHost = request?.requestHeaders?.entries
            ?.firstOrNull { it.key.equals("Referer", ignoreCase = true) }
            ?.value
            ?.let { runCatching { Uri.parse(it).host }.getOrNull() }
            ?.lowercase(Locale.ROOT)
            ?: runCatching { Uri.parse(pageUrl).host?.lowercase(Locale.ROOT) }.getOrNull()
        val thirdParty = pageHost.isNullOrBlank() ||
            (host != pageHost && !host.endsWith(".$pageHost") && !pageHost.endsWith(".$host"))
        val resourceType = detectResourceType(uri, request)

        val scopedCandidates = ArrayList<ScopedRule>()
        var candidateHost = host
        while (candidateHost.isNotEmpty()) {
            rules.scopedRulesByHost[candidateHost]?.let(scopedCandidates::addAll)
            val dot = candidateHost.indexOf('.')
            if (dot < 0) break
            candidateHost = candidateHost.substring(dot + 1)
        }

        fun applies(rule: ScopedRule): Boolean {
            if (!matchesHost(host, rule.host)) return false
            if (rule.thirdPartyOnly != null && rule.thirdPartyOnly != thirdParty) return false
            if (rule.pathToken != null && !uri.encodedPath.orEmpty().contains(rule.pathToken, true)) return false
            if (rule.includeDomains.isNotEmpty() &&
                (pageHost == null || rule.includeDomains.none { matchesHost(pageHost, it) })) return false
            if (rule.excludeDomains.any { pageHost != null && matchesHost(pageHost, it) }) return false
            if (rule.includeTypes.isNotEmpty() && resourceType !in rule.includeTypes) return false
            if (resourceType in rule.excludeTypes) return false
            return true
        }

        // ABP exception rules always take precedence over blocking rules.
        if (scopedCandidates.any { it.exception && applies(it) }) return false
        if (matchesHost(host, rules.blockedHosts)) return true
        if (thirdParty && matchesHost(host, rules.thirdPartyHosts)) return true
        if (scopedCandidates.any { !it.exception && applies(it) }) return true

        val path = uri.encodedPath.orEmpty().lowercase(Locale.ROOT)
        return path.isNotBlank() && rules.pathTokens.any { token -> path.contains(token) }
    }

    private fun detectResourceType(uri: Uri, request: WebResourceRequest?): String {
        if (request?.isForMainFrame == true) return "document"
        val headers = request?.requestHeaders.orEmpty()
        val destination = headers.entries.firstOrNull {
            it.key.equals("Sec-Fetch-Dest", ignoreCase = true)
        }?.value?.lowercase(Locale.ROOT).orEmpty()
        when (destination) {
            "script" -> return "script"
            "style" -> return "stylesheet"
            "image" -> return "image"
            "font" -> return "font"
            "audio", "video", "track" -> return "media"
            "document", "iframe" -> return "subdocument"
            "empty" -> return "xmlhttprequest"
        }
        val accept = headers.entries.firstOrNull {
            it.key.equals("Accept", ignoreCase = true)
        }?.value?.lowercase(Locale.ROOT).orEmpty()
        if ("image/" in accept) return "image"
        if ("text/css" in accept) return "stylesheet"
        if ("font/" in accept) return "font"
        if ("video/" in accept || "audio/" in accept) return "media"
        val path = uri.path.orEmpty().lowercase(Locale.ROOT)
        return when {
            path.endsWith(".js") || path.endsWith(".mjs") -> "script"
            path.endsWith(".css") -> "stylesheet"
            path.endsWith(".png") || path.endsWith(".jpg") || path.endsWith(".jpeg") ||
                path.endsWith(".webp") || path.endsWith(".gif") || path.endsWith(".svg") -> "image"
            path.endsWith(".woff") || path.endsWith(".woff2") || path.endsWith(".ttf") ||
                path.endsWith(".otf") -> "font"
            path.endsWith(".mp4") || path.endsWith(".webm") || path.endsWith(".mp3") ||
                path.endsWith(".m4a") || path.endsWith(".ogg") -> "media"
            else -> "other"
        }
    }

    private fun loadCachedRules() {
        if (!cacheFile.isFile || cacheFile.length() !in 1..MAX_CACHE_BYTES) return
        runCatching {
            val blocked = LinkedHashSet<String>()
            val thirdParty = LinkedHashSet<String>()
            val allowed = LinkedHashSet<String>()
            val paths = LinkedHashSet<String>()
            val scoped = LinkedHashSet<ScopedRule>()
            cacheFile.bufferedReader(Charsets.UTF_8).useLines { lines ->
                lines.forEach { line ->
                    if (line.length < 3) return@forEach
                    val value = line.substring(2)
                    when (line[0]) {
                        'B' -> blocked.add(value)
                        'T' -> thirdParty.add(value)
                        'A' -> allowed.add(value)
                        'P' -> paths.add(value)
                        'R' -> decodeRule(value)?.let(scoped::add)
                    }
                }
            }
            if (blocked.isNotEmpty() || thirdParty.isNotEmpty() || allowed.isNotEmpty() ||
                paths.isNotEmpty() || scoped.isNotEmpty()) {
                snapshot = Snapshot(blocked, thirdParty, allowed, paths, scoped.toList())
            }
        }
    }

    private fun refreshLists() {
        val blocked = LinkedHashSet<String>()
        val thirdParty = LinkedHashSet<String>()
        val allowed = LinkedHashSet<String>()
        val paths = LinkedHashSet<String>()
        val scoped = LinkedHashSet<ScopedRule>()
        var fetchedAtLeastOne = false

        LIST_URLS.forEach { source ->
            val text = downloadList(source) ?: return@forEach
            fetchedAtLeastOne = true
            parseList(text, blocked, thirdParty, allowed, paths, scoped)
        }
        if (!fetchedAtLeastOne) return

        val next = Snapshot(blocked, thirdParty, allowed, paths, scoped.toList())
        snapshot = next
        runCatching {
            cacheFile.parentFile?.mkdirs()
            cacheFile.bufferedWriter(Charsets.UTF_8).use { writer ->
                next.blockedHosts.forEach { writer.append("B ").append(it).append('\n') }
                next.thirdPartyHosts.forEach { writer.append("T ").append(it).append('\n') }
                next.allowedHosts.forEach { writer.append("A ").append(it).append('\n') }
                next.pathTokens.forEach { writer.append("P ").append(it).append('\n') }
                next.scopedRules.forEach { encodeRule(it)?.let { encoded ->
                    writer.append("R ").append(encoded).append('\n')
                } }
            }
        }
        prefs.edit().putLong(KEY_LAST_UPDATE, System.currentTimeMillis()).apply()
    }

    private fun downloadList(address: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(address).openConnection() as HttpURLConnection
            connection.connectTimeout = 7_000
            connection.readTimeout = 10_000
            connection.instanceFollowRedirects = true
            connection.setRequestProperty("User-Agent", "BrowseIt/1.0 (Android WebView filter updater)")
            connection.setRequestProperty("Accept", "text/plain,*/*;q=0.8")
            connection.setRequestProperty("Accept-Encoding", "gzip")
            if (connection.responseCode !in 200..299) return null
            val raw: InputStream = BufferedInputStream(connection.inputStream)
            val decoded = if (connection.contentEncoding.equals("gzip", ignoreCase = true)) GZIPInputStream(raw) else raw
            decoded.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var total = 0
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    if (total > MAX_LIST_BYTES) return null
                    output.write(buffer, 0, count)
                }
                output.toString(Charsets.UTF_8.name())
            }
        } catch (_: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun parseList(
        text: String,
        blocked: MutableSet<String>,
        thirdParty: MutableSet<String>,
        allowed: MutableSet<String>,
        paths: MutableSet<String>,
        scoped: MutableSet<ScopedRule>,
    ) {
        BufferedReader(StringReader(text)).useLines { lines ->
            lines.forEach lineLoop@{ rawLine ->
                val line = rawLine.trim()
                if (line.isEmpty() || line.startsWith("!") || line.startsWith("[") ||
                    line.contains("##") || line.contains("#@#") || line.contains("#$#") ||
                    line.contains("#?#")) return@lineLoop

                // Hosts-format lists (e.g. 0.0.0.0 ads.example) are widely used
                // and cheap to evaluate, so consume them directly.
                val hostsParts = line.split(Regex("\\s+"))
                if (hostsParts.size >= 2 &&
                    (hostsParts.first() == "0.0.0.0" || hostsParts.first() == "127.0.0.1" ||
                        hostsParts.first() == "::" || hostsParts.first() == "::1")) {
                    hostsParts.drop(1).forEach { candidate ->
                        val host = candidate.lowercase(Locale.ROOT).trim('.')
                        if (isValidHostRule(host) && blocked.size < MAX_HOST_RULES) blocked.add(host)
                    }
                    return@lineLoop
                }

                val exception = line.startsWith("@@")
                val withoutException = if (exception) line.substring(2) else line
                val pattern = withoutException.substringBefore('$').trim()
                val optionText = withoutException.substringAfter('$', "")
                val options = optionText.split(',').map { it.trim().lowercase(Locale.ROOT) }
                val remainder = pattern.removePrefix("||")
                if (!pattern.startsWith("||")) {
                    if (!exception) addConservativePath(pattern, paths)
                    return@lineLoop
                }

                val host = remainder.takeWhile { it.isLetterOrDigit() || it == '.' || it == '-' }
                    .lowercase(Locale.ROOT).trim('.')
                if (!isValidHostRule(host)) return@lineLoop
                val tail = remainder.substring(host.length)
                val pathToken = if (tail.startsWith('/')) {
                    tail.substring(1).substringBefore('*').substringBefore('^')
                        .substringBefore('|').trim('/').takeIf { it.length >= 3 }
                } else null

                val domainOption = options.firstOrNull { it.startsWith("domain=") }
                val includeDomains = LinkedHashSet<String>()
                val excludeDomains = LinkedHashSet<String>()
                if (domainOption != null) {
                    domainOption.substringAfter('=').split('|').forEach domainLoop@{ rawDomain ->
                        val domain = rawDomain.trim().lowercase(Locale.ROOT)
                        if (domain.isBlank() || domain.contains('*')) return@domainLoop
                        if (domain.startsWith('~')) {
                            domain.removePrefix("~").takeIf(::isValidHostRule)?.let(excludeDomains::add)
                        } else if (isValidHostRule(domain)) {
                            includeDomains.add(domain)
                        }
                    }
                }

                val thirdPartyCondition = when {
                    "third-party" in options -> true
                    "~third-party" in options -> false
                    else -> null
                }
                val types = setOf("document", "subdocument", "script", "stylesheet", "image", "object",
                    "xmlhttprequest", "media", "font", "websocket", "ping", "other")
                val includeTypes = options.filter { it in types }.toSet()
                val excludeTypes = options.filter { it.startsWith('~') && it.removePrefix("~") in types }
                    .map { it.removePrefix("~") }.toSet()
                val hasConditions = domainOption != null || thirdPartyCondition != null ||
                    includeTypes.isNotEmpty() || excludeTypes.isNotEmpty()

                if (pathToken != null || hasConditions) {
                    if (scoped.size < MAX_SCOPED_RULES) {
                        scoped.add(ScopedRule(
                            host = host,
                            exception = exception,
                            thirdPartyOnly = thirdPartyCondition,
                            includeDomains = includeDomains,
                            excludeDomains = excludeDomains,
                            pathToken = pathToken,
                            includeTypes = includeTypes,
                            excludeTypes = excludeTypes,
                        ))
                    }
                } else if (exception) {
                    allowed.add(host)
                } else if ("third-party" in options) {
                    thirdParty.add(host)
                } else if (blocked.size < MAX_HOST_RULES) {
                    blocked.add(host)
                }
            }
        }
    }

    private fun addConservativePath(pattern: String, paths: MutableSet<String>) {
        val clean = pattern.removePrefix("|").removeSuffix("|")
            .replace('*', ' ').replace('^', ' ').trim().lowercase(Locale.ROOT)
        if (clean.length !in 5..72 || clean.any { !(it.isLetterOrDigit() || it in "/._-?=&") }) return
        val adSignals = listOf("/ad/", "/ads/", "/advert", "/banner", "/popunder", "/prebid",
            "/doubleclick", "/tracking", "/tracker", "/pixel", "/analytics")
        if (adSignals.any(clean::contains) && paths.size < MAX_PATH_RULES) paths.add(clean)
    }

    private fun encodeRule(rule: ScopedRule): String? = runCatching {
        val value = listOf(
            rule.host,
            if (rule.exception) "1" else "0",
            rule.thirdPartyOnly?.let { if (it) "1" else "0" } ?: "-",
            rule.includeDomains.sorted().joinToString(","),
            rule.excludeDomains.sorted().joinToString(","),
            rule.pathToken.orEmpty(),
            rule.includeTypes.sorted().joinToString(","),
            rule.excludeTypes.sorted().joinToString(","),
        ).joinToString("|")
        Base64.encodeToString(value.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
    }.getOrNull()

    private fun decodeRule(encoded: String): ScopedRule? = runCatching {
        val fields = String(Base64.decode(encoded, Base64.NO_WRAP), Charsets.UTF_8).split('|')
        if (fields.size != 8 || !isValidHostRule(fields[0])) return null
        val include = fields[3].split(',').filter { isValidHostRule(it) }.toSet()
        val exclude = fields[4].split(',').filter { isValidHostRule(it) }.toSet()
        ScopedRule(
            host = fields[0],
            exception = fields[1] == "1",
            thirdPartyOnly = when (fields[2]) { "1" -> true; "0" -> false; else -> null },
            includeDomains = include,
            excludeDomains = exclude,
            pathToken = fields[5].takeIf { it.isNotBlank() },
            includeTypes = fields[6].split(',').filter { it in RESOURCE_TYPES }.toSet(),
            excludeTypes = fields[7].split(',').filter { it in RESOURCE_TYPES }.toSet(),
        )
    }.getOrNull()

    private fun matchesHost(host: String, rules: Set<String>): Boolean {
        var candidate = host
        while (candidate.isNotEmpty()) {
            if (candidate in rules) return true
            val dot = candidate.indexOf('.')
            if (dot < 0) break
            candidate = candidate.substring(dot + 1)
        }
        return false
    }

    private fun matchesHost(host: String, ruleHost: String): Boolean =
        host == ruleHost || host.endsWith(".$ruleHost")

    private fun isValidHostRule(host: String): Boolean {
        if (host.length !in 4..253 || '.' !in host || host.startsWith('.') || host.endsWith('.')) return false
        if (host.any { !(it.isLetterOrDigit() || it == '.' || it == '-') }) return false
        if (host.split('.').any { it.isEmpty() || it.startsWith('-') || it.endsWith('-') }) return false
        return true
    }

    companion object {
        @Volatile private var instance: NativeAdBlockRules? = null
        fun get(context: Context): NativeAdBlockRules = instance ?: synchronized(this) {
            instance ?: NativeAdBlockRules(context.applicationContext).also { instance = it }
        }

        private const val KEY_LAST_UPDATE = "last_filter_update_ms"
        private const val UPDATE_INTERVAL_MS = 4L * 24L * 60L * 60L * 1000L
        private const val MAX_LIST_BYTES = 8 * 1024 * 1024
        private const val MAX_CACHE_BYTES = 16L * 1024L * 1024L
        private const val MAX_HOST_RULES = 80_000
        private const val MAX_SCOPED_RULES = 60_000
        private const val MAX_PATH_RULES = 3_000
        private val RESOURCE_TYPES = setOf("document", "subdocument", "script", "stylesheet", "image", "object",
            "xmlhttprequest", "media", "font", "websocket", "ping", "other")
        private val LIST_URLS = listOf(
            "https://easylist.to/easylist/easylist.txt",
            "https://easylist.to/easylist/easyprivacy.txt",
            "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext",
        )
    }
}

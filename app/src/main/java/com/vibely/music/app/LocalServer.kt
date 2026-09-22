package com.vibely.music.app

import android.content.Context
import android.util.Log
import fi.iki.elonen.NanoHTTPD
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class LocalServer(private val context: Context) : NanoHTTPD(8080) {

    private val tag = "VibelyServer"
    private val extractor = MusicExtractor(context)
    private val lyricsProvider = LyricsProvider()
    private val podcasts = PodcastProvider()
    private val prefs = PreferencesStore(context)

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    init {
        Thread {
            extractor.initYtDlp()
            extractor.updateYtDlp()
        }.start()
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val params = session.parameters
        Log.d(tag, "${session.method} $uri")

        if (session.method == Method.OPTIONS) {
            return withCors(newFixedLengthResponse(Response.Status.OK, "text/plain", ""))
        }

        return try {
            when (uri) {
                "/search" -> {
                    val query = params["q"]?.firstOrNull() ?: return badRequest("Missing q")
                    val limit = params["limit"]?.firstOrNull()?.toIntOrNull() ?: 100
                    jsonResponse(extractor.search(query, limit))
                }
                "/stream" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    jsonResponse("""{"streamUrl":"http://localhost:8080/audio?id=$id"}""")
                }
                "/audio" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    proxyAudio(id, session.headers["range"])
                }
                "/related" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    jsonResponse(extractor.getRelated(id))
                }
                "/shorts" -> {
                    val query = params["q"]?.firstOrNull() ?: "trending"
                    jsonResponse(extractor.searchShorts(query))
                }
                "/local" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    serveLocalAudio(id, session.headers["range"])
                }
                "/downloaded" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    serveDownloaded(id, session.headers["range"])
                }
                "/cover" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    serveLocalCover(id)
                }
                "/customcover" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    serveCustomCover(id)
                }
                "/deviceimage" -> {
                    val id = params["id"]?.firstOrNull() ?: return badRequest("Missing id")
                    val thumb = params["thumb"]?.firstOrNull() == "1"
                    serveDeviceImage(id, thumb)
                }
                "/lyrics" -> {
                    val title = params["title"]?.firstOrNull() ?: return badRequest("Missing title")
                    val artist = params["artist"]?.firstOrNull() ?: ""
                    jsonResponse(lyricsProvider.fetch(title, artist))
                }
                "/podcasts/search" -> {
                    val query = params["q"]?.firstOrNull() ?: return badRequest("Missing q")
                    jsonResponse(podcasts.search(query))
                }
                "/podcasts/featured" -> jsonResponse(podcasts.featured())
                "/podcasts/episodes" -> {
                    val feedUrl = params["feedUrl"]?.firstOrNull() ?: return badRequest("Missing feedUrl")
                    jsonResponse(podcasts.episodes(feedUrl))
                }
                "/debug" -> {
                    val id = params["id"]?.firstOrNull()
                    if (id != null) { extractor.invalidate(id); extractor.getStreamSource(id) }
                    withCors(newFixedLengthResponse(Response.Status.OK, "text/plain; charset=utf-8", extractor.debugReport()))
                }
                else -> withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found"))
            }
        } catch (e: Exception) {
            Log.e(tag, "Erro em $uri", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "application/json", """{"error":"${(e.message ?: "erro").replace("\"", "'")}"}"""))
        }
    }

    private fun localUri(id: String): android.net.Uri? {
        val numeric = id.removePrefix("local_").toLongOrNull() ?: return null
        return android.content.ContentUris.withAppendedId(
            android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, numeric
        )
    }

    private fun serveLocalAudio(id: String, rangeHeader: String?): Response {
        val uri = localUri(id) ?: return withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "text/plain", "id inválido"))
        return try {
            val resolver = context.contentResolver
            val mime = resolver.getType(uri)?.takeIf { it.startsWith("audio/") } ?: "audio/mpeg"
            val total = resolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: -1L
            if (total <= 0) return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Ficheiro não encontrado"))

            var start = 0L
            var end = total - 1
            var partial = false
            if (rangeHeader != null && rangeHeader.startsWith("bytes=")) {
                val parts = rangeHeader.removePrefix("bytes=").split("-")
                start = parts.getOrNull(0)?.toLongOrNull() ?: 0L
                end = parts.getOrNull(1)?.takeIf { it.isNotEmpty() }?.toLongOrNull() ?: (total - 1)
                end = minOf(end, total - 1)
                if (start > end || start < 0) {
                    val r = newFixedLengthResponse(Response.Status.RANGE_NOT_SATISFIABLE, "text/plain", "")
                    r.addHeader("Content-Range", "bytes */$total")
                    return withCors(r)
                }
                partial = true
            }

            val length = end - start + 1
            val input = resolver.openInputStream(uri) ?: return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Sem acesso"))
            var skipped = 0L
            while (skipped < start) {
                val n = input.skip(start - skipped)
                if (n <= 0) break
                skipped += n
            }
            val limited = object : java.io.FilterInputStream(input) {
                private var remaining = length
                override fun read(): Int {
                    if (remaining <= 0) return -1
                    val b = super.read(); if (b >= 0) remaining--; return b
                }
                override fun read(b: ByteArray, off: Int, len: Int): Int {
                    if (remaining <= 0) return -1
                    val n = super.read(b, off, minOf(len.toLong(), remaining).toInt())
                    if (n > 0) remaining -= n
                    return n
                }
            }

            val resp = newFixedLengthResponse(
                if (partial) Response.Status.PARTIAL_CONTENT else Response.Status.OK, mime, limited, length
            )
            resp.addHeader("Accept-Ranges", "bytes")
            if (partial) resp.addHeader("Content-Range", "bytes $start-$end/$total")
            withCors(resp)
        } catch (e: SecurityException) {
            withCors(newFixedLengthResponse(Response.Status.FORBIDDEN, "text/plain", "Sem permissão de áudio"))
        } catch (e: Exception) {
            Log.e(tag, "Erro a servir local $id", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Erro ao ler ficheiro"))
        }
    }

    // Capa embutida no ficheiro (ID3/MediaStore). Só usada quando não há capa customizada.
    private fun serveLocalCover(id: String): Response {
        val uri = localUri(id) ?: return withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "text/plain", "id inválido"))
        return try {
            val mmr = android.media.MediaMetadataRetriever()
            mmr.setDataSource(context, uri)
            val art = mmr.embeddedPicture
            mmr.release()
            if (art == null || art.isEmpty()) {
                withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Sem capa"))
            } else {
                val r = newFixedLengthResponse(Response.Status.OK, "image/jpeg", java.io.ByteArrayInputStream(art), art.size.toLong())
                r.addHeader("Cache-Control", "public, max-age=86400")
                withCors(r)
            }
        } catch (e: Exception) {
            withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Sem capa"))
        }
    }

    // Capa customizada: lê o content:// URI que o usuário escolheu (galeria/picker) e guardou em PreferencesStore.
    private fun serveCustomCover(id: String): Response {
        val covers = prefs.getCustomCovers()
        val uriString = covers.optString(id, "")
        if (uriString.isEmpty()) return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Sem capa customizada"))
        return try {
            val uri = android.net.Uri.parse(uriString)
            val resolver = context.contentResolver
            val mime = resolver.getType(uri) ?: "image/jpeg"
            val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
                ?: return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Imagem indisponível"))
            val r = newFixedLengthResponse(Response.Status.OK, mime, java.io.ByteArrayInputStream(bytes), bytes.size.toLong())
            r.addHeader("Cache-Control", "no-cache")
            withCors(r)
        } catch (e: SecurityException) {
            withCors(newFixedLengthResponse(Response.Status.FORBIDDEN, "text/plain", "Sem permissão"))
        } catch (e: Exception) {
            Log.e(tag, "Erro a servir capa customizada $id", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Erro"))
        }
    }

    // Imagens da galeria do dispositivo, para o grid do modal "Escolher capa". thumb=1 devolve
    // uma miniatura reduzida (mais rápido para a grelha); sem thumb devolve a imagem completa.
    private fun serveDeviceImage(id: String, thumb: Boolean): Response {
        val numeric = id.toLongOrNull() ?: return withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "text/plain", "id inválido"))
        val uri = android.content.ContentUris.withAppendedId(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, numeric)
        return try {
            val resolver = context.contentResolver
            val bytes: ByteArray
            val mime: String
            if (thumb && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                val bmp = resolver.loadThumbnail(uri, android.util.Size(300, 300), null)
                val stream = java.io.ByteArrayOutputStream()
                bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, stream)
                bytes = stream.toByteArray(); mime = "image/jpeg"
            } else {
                bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Imagem indisponível"))
                mime = resolver.getType(uri) ?: "image/jpeg"
            }
            val r = newFixedLengthResponse(Response.Status.OK, mime, java.io.ByteArrayInputStream(bytes), bytes.size.toLong())
            r.addHeader("Cache-Control", "public, max-age=3600")
            withCors(r)
        } catch (e: SecurityException) {
            withCors(newFixedLengthResponse(Response.Status.FORBIDDEN, "text/plain", "Sem permissão de imagens"))
        } catch (e: Exception) {
            Log.e(tag, "Erro a servir imagem $id", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Erro"))
        }
    }

    private fun serveDownloaded(id: String, rangeHeader: String?): Response {
        val safeId = id.filter { it.isLetterOrDigit() || it == '_' || it == '-' }
        val file = java.io.File(java.io.File(context.filesDir, "downloads"), "$safeId.audio")
        if (!file.exists() || file.length() <= 0) {
            return withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Download não encontrado"))
        }
        return try {
            val total = file.length()
            var start = 0L
            var end = total - 1
            var partial = false
            if (rangeHeader != null && rangeHeader.startsWith("bytes=")) {
                val parts = rangeHeader.removePrefix("bytes=").split("-")
                start = parts.getOrNull(0)?.toLongOrNull() ?: 0L
                end = parts.getOrNull(1)?.takeIf { it.isNotEmpty() }?.toLongOrNull() ?: (total - 1)
                end = minOf(end, total - 1)
                if (start > end || start < 0) {
                    val r = newFixedLengthResponse(Response.Status.RANGE_NOT_SATISFIABLE, "text/plain", "")
                    r.addHeader("Content-Range", "bytes */$total")
                    return withCors(r)
                }
                partial = true
            }
            val length = end - start + 1
            val raf = java.io.RandomAccessFile(file, "r")
            raf.seek(start)
            val stream = object : java.io.InputStream() {
                private var remaining = length
                override fun read(): Int {
                    if (remaining <= 0) return -1
                    val b = raf.read(); if (b >= 0) remaining--; return b
                }
                override fun read(b: ByteArray, off: Int, len: Int): Int {
                    if (remaining <= 0) return -1
                    val n = raf.read(b, off, minOf(len.toLong(), remaining).toInt())
                    if (n > 0) remaining -= n
                    return n
                }
                override fun close() { try { raf.close() } catch (_: Exception) {} }
            }
            val resp = newFixedLengthResponse(
                if (partial) Response.Status.PARTIAL_CONTENT else Response.Status.OK, "audio/mp4", stream, length
            )
            resp.addHeader("Accept-Ranges", "bytes")
            if (partial) resp.addHeader("Content-Range", "bytes $start-$end/$total")
            withCors(resp)
        } catch (e: Exception) {
            Log.e(tag, "Erro a servir download $id", e)
            withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Erro ao ler download"))
        }
    }

    private fun proxyAudio(videoId: String, rangeHeader: String?): Response {
        var opened = openUpstream(videoId, rangeHeader)
        if (opened == null || !isGood(opened.second)) {
            opened?.second?.close()
            extractor.invalidate(videoId)
            opened = openUpstream(videoId, rangeHeader)
        }
        if (opened == null || !isGood(opened.second)) {
            val code = opened?.second?.code ?: 0
            opened?.second?.close()
            return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Extração falhou ($code)"))
        }

        val (source, upstream) = opened
        val body = upstream.body ?: run {
            upstream.close()
            return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Sem corpo"))
        }

        val mime = upstream.header("Content-Type")?.takeIf { it.startsWith("audio/") || it.startsWith("video/") } ?: source.mime
        val length = body.contentLength()
        val status = if (upstream.code == 206) Response.Status.PARTIAL_CONTENT else Response.Status.OK

        if (length < 0) {
            body.close(); upstream.close()
            val total = fetchTotalLength(source)
            if (total == null || total <= 0) {
                return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Stream sem tamanho conhecido"))
            }
            val reopened = openUpstream(videoId, rangeHeader) ?: return withCors(
                newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Falha ao reabrir stream")
            )
            val (source2, upstream2) = reopened
            val body2 = upstream2.body ?: run {
                upstream2.close()
                return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Sem corpo"))
            }
            val mime2 = upstream2.header("Content-Type")?.takeIf { it.startsWith("audio/") || it.startsWith("video/") } ?: source2.mime
            val status2 = if (upstream2.code == 206) Response.Status.PARTIAL_CONTENT else Response.Status.OK
            val effectiveLength = body2.contentLength().takeIf { it >= 0 } ?: total
            val resp2 = newFixedLengthResponse(status2, mime2, body2.byteStream(), effectiveLength)
            resp2.addHeader("Accept-Ranges", "bytes")
            upstream2.header("Content-Range")?.let { resp2.addHeader("Content-Range", it) }
            if (status2 == Response.Status.OK) resp2.addHeader("Content-Range", "bytes 0-${total - 1}/$total")
            return withCors(resp2)
        }

        val resp = newFixedLengthResponse(status, mime, body.byteStream(), length)
        resp.addHeader("Accept-Ranges", "bytes")
        upstream.header("Content-Range")?.let { resp.addHeader("Content-Range", it) }
        return withCors(resp)
    }

    private fun fetchTotalLength(source: MusicExtractor.StreamSource): Long? {
        return try {
            val rb = Request.Builder().url(source.url).header("Range", "bytes=0-1")
            source.headers.forEach { (k, v) -> rb.header(k, v) }
            http.newCall(rb.build()).execute().use { r ->
                r.header("Content-Range")?.substringAfterLast("/")?.toLongOrNull()
                    ?: r.header("Content-Length")?.toLongOrNull()
            }
        } catch (e: Exception) { null }
    }

    private fun isGood(r: okhttp3.Response) = r.isSuccessful || r.code == 206

    private fun openUpstream(videoId: String, rangeHeader: String?): Pair<MusicExtractor.StreamSource, okhttp3.Response>? {
        val source = try { extractor.getStreamSource(videoId) } catch (e: Exception) { null } ?: return null
        val rb = Request.Builder().url(source.url)
        source.headers.forEach { (k, v) -> rb.header(k, v) }
        rb.header("Range", rangeHeader ?: "bytes=0-")
        return try { Pair(source, http.newCall(rb.build()).execute()) } catch (e: Exception) { null }
    }

    private fun jsonResponse(json: String): Response = withCors(newFixedLengthResponse(Response.Status.OK, "application/json", json))
    private fun badRequest(msg: String): Response = withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", """{"error":"$msg"}"""))

    private fun withCors(r: Response): Response {
        r.addHeader("Access-Control-Allow-Origin", "*")
        r.addHeader("Access-Control-Allow-Headers", "Range, Content-Type")
        r.addHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
        r.addHeader("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")
        return r
    }
}
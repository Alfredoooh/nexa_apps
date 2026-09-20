package com.vibely.music.app

import android.content.Context
import android.util.Log
import fi.iki.elonen.NanoHTTPD
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

class LocalServer(context: Context) : NanoHTTPD(8080) {

    private val tag = "VibelyServer"

    private val extractor = MusicExtractor(context)

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    init {
        // Prepara o yt-dlp em segundo plano para a primeira música não esperar a extração dos binários
        Thread {
            extractor.initYtDlp()
            extractor.updateYtDlp()
        }.start()
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val params = session.parameters
        Log.d(tag, "${session.method} $uri ${session.headers["range"] ?: ""}")

        if (session.method == Method.OPTIONS) {
            return withCors(newFixedLengthResponse(Response.Status.OK, "text/plain", ""))
        }

        return try {
            when (uri) {
                "/search" -> {
                    val query = params["q"]?.firstOrNull() ?: return badRequest("Missing q")
                    jsonResponse(extractor.search(query))
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
                "/debug" -> {
                    val id = params["id"]?.firstOrNull()
                    if (id != null) {
                        extractor.invalidate(id)
                        extractor.getStreamSource(id)
                    }
                    withCors(newFixedLengthResponse(Response.Status.OK, "text/plain; charset=utf-8", extractor.debugReport()))
                }
                else -> withCors(newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found"))
            }
        } catch (e: Exception) {
            Log.e(tag, "Erro em $uri", e)
            withCors(
                newFixedLengthResponse(
                    Response.Status.INTERNAL_ERROR,
                    "application/json",
                    """{"error":"${(e.message ?: "erro").replace("\"", "'")}"}"""
                )
            )
        }
    }

    private fun proxyAudio(videoId: String, rangeHeader: String?): Response {
        var opened = openUpstream(videoId, rangeHeader)

        if (opened == null || !isGood(opened.second)) {
            Log.w(tag, "Upstream falhou (${opened?.second?.code}), refazendo a extração")
            opened?.second?.close()
            extractor.invalidate(videoId)
            opened = openUpstream(videoId, rangeHeader)
        }

        if (opened == null || !isGood(opened.second)) {
            val code = opened?.second?.code ?: 0
            Log.e(tag, "Upstream falhou de vez: $code")
            opened?.second?.close()
            return withCors(
                newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Extração falhou ($code)")
            )
        }

        val (source, upstream) = opened
        val body = upstream.body ?: run {
            upstream.close()
            return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Sem corpo"))
        }

        val mime = upstream.header("Content-Type")?.takeIf { it.startsWith("audio/") || it.startsWith("video/") }
            ?: source.mime
        val length = body.contentLength()
        val status = if (upstream.code == 206) Response.Status.PARTIAL_CONTENT else Response.Status.OK
        Log.d(tag, "Upstream OK via ${source.origin}: ${upstream.code} $mime length=$length")

        // O MediaPlayer/<audio> travam sem erro quando a resposta não tem Content-Length (chunked).
        // Se o upstream não devolveu tamanho, descobrimos o tamanho total antes de responder.
        if (length < 0) {
            Log.w(tag, "Upstream sem Content-Length, a descobrir tamanho total…")
            body.close()
            upstream.close()
            val total = fetchTotalLength(source)
            if (total == null || total <= 0) {
                Log.e(tag, "Não foi possível determinar o tamanho do ficheiro")
                return withCors(
                    newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Stream sem tamanho conhecido")
                )
            }
            val reopened = openUpstream(videoId, rangeHeader) ?: return withCors(
                newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Falha ao reabrir stream")
            )
            val (source2, upstream2) = reopened
            val body2 = upstream2.body ?: run {
                upstream2.close()
                return withCors(newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Sem corpo"))
            }
            val mime2 = upstream2.header("Content-Type")?.takeIf { it.startsWith("audio/") || it.startsWith("video/") }
                ?: source2.mime
            val status2 = if (upstream2.code == 206) Response.Status.PARTIAL_CONTENT else Response.Status.OK
            val effectiveLength = body2.contentLength().takeIf { it >= 0 } ?: total
            val resp2 = newFixedLengthResponse(status2, mime2, body2.byteStream(), effectiveLength)
            resp2.addHeader("Accept-Ranges", "bytes")
            upstream2.header("Content-Range")?.let { resp2.addHeader("Content-Range", it) }
            if (status2 == Response.Status.OK) {
                resp2.addHeader("Content-Range", "bytes 0-${total - 1}/$total")
            }
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
                val contentRange = r.header("Content-Range")
                val total = contentRange?.substringAfterLast("/")?.toLongOrNull()
                total ?: r.header("Content-Length")?.toLongOrNull()
            }
        } catch (e: Exception) {
            Log.e(tag, "fetchTotalLength falhou: ${e.message}")
            null
        }
    }

    private fun isGood(r: okhttp3.Response) = r.isSuccessful || r.code == 206

    private fun openUpstream(
        videoId: String,
        rangeHeader: String?
    ): Pair<MusicExtractor.StreamSource, okhttp3.Response>? {
        val source = try {
            extractor.getStreamSource(videoId)
        } catch (e: Exception) {
            Log.e(tag, "Falha ao extrair de $videoId", e)
            null
        } ?: return null

        val rb = Request.Builder().url(source.url)
        source.headers.forEach { (k, v) -> rb.header(k, v) }
        rb.header("Range", rangeHeader ?: "bytes=0-")

        return try {
            Pair(source, http.newCall(rb.build()).execute())
        } catch (e: Exception) {
            Log.e(tag, "Erro de rede no upstream", e)
            null
        }
    }

    private fun jsonResponse(json: String): Response =
        withCors(newFixedLengthResponse(Response.Status.OK, "application/json", json))

    private fun badRequest(msg: String): Response =
        withCors(newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", """{"error":"$msg"}"""))

    private fun withCors(r: Response): Response {
        r.addHeader("Access-Control-Allow-Origin", "*")
        r.addHeader("Access-Control-Allow-Headers", "Range, Content-Type")
        r.addHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
        r.addHeader("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")
        return r
    }
}
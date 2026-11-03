package com.looply.app

import android.net.Uri
import android.os.SystemClock
import android.webkit.WebResourceResponse
import com.pichillilorenzo.flutter_inappwebview_android.content_blocker.ContentBlockerHandler
import com.pichillilorenzo.flutter_inappwebview_android.types.WebResourceRequestExt
import com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview.InAppWebView
import java.io.ByteArrayInputStream
import java.util.WeakHashMap

/**
 * Estado partilhado com a preferência Flutter. A leitura é feita em memória
 * durante shouldInterceptRequest: não há chamadas Dart nem I/O por pedido.
 */
internal object LooplyNativeAdBlockState {
    @Volatile
    var enabled: Boolean = true
}

/**
 * Implementação nativa para Android do bloqueador Looply.
 * A decisão por URL é feita localmente no worker do WebView, sem round-trips
 * HEAD e sem uma chamada MethodChannel para cada recurso.
 */
internal class LooplyNativeContentBlockerHandler(
    private val onBlocked: (isIncognito: Boolean) -> Unit,
) : ContentBlockerHandler() {

    private val cosmeticLock = Any()
    private val lastCosmeticSchedule = WeakHashMap<InAppWebView, Long>()

    override fun checkUrl(
        webView: InAppWebView,
        request: WebResourceRequestExt,
    ): WebResourceResponse? {
        if (!LooplyNativeAdBlockState.enabled) return null

        // Os documentos principais não são bloqueados por listas de anúncios.
        // Neles é instalado um filtro cosmético para publicidade first-party,
        // banners e elementos injectados depois do carregamento.
        if (request.isForMainFrame) {
            scheduleCosmeticFilter(webView)
            return null
        }

        if (!LooplyAdRules.matches(request.url)) return null

        onBlocked(webView.customSettings.incognito)
        return WebResourceResponse(
            "text/plain",
            "utf-8",
            ByteArrayInputStream(ByteArray(0)),
        )
    }

    /** Atualiza a página aberta imediatamente quando o utilizador muda a opção. */
    fun updateCosmeticFilter(webView: InAppWebView, enabled: Boolean) {
        webView.post {
            try {
                if (enabled) {
                    webView.evaluateJavascript(
                        "window.__looplyAdBlockSetEnabled && window.__looplyAdBlockSetEnabled(true);",
                        null,
                    )
                    webView.evaluateJavascript(COSMETIC_FILTER_SCRIPT, null)
                } else {
                    webView.evaluateJavascript(
                        "window.__looplyAdBlockSetEnabled && window.__looplyAdBlockSetEnabled(false);",
                        null,
                    )
                }
            } catch (_: RuntimeException) {
                // A página pode ter sido fechada durante a alteração.
            }
        }
    }

    /** Agenda a limpeza no UI thread; o observer trata anúncios adicionados depois. */
    private fun scheduleCosmeticFilter(webView: InAppWebView) {
        val now = SystemClock.uptimeMillis()
        synchronized(cosmeticLock) {
            val last = lastCosmeticSchedule[webView] ?: 0L
            if (now - last < 1_800L) return
            lastCosmeticSchedule[webView] = now
        }

        // Uma primeira tentativa rápida e mais duas após scripts/slots de ads
        // normalmente aparecerem. A instalação é limitada por WebView.
        val attempts = longArrayOf(420L, 1_150L, 2_400L)
        attempts.forEach { delay ->
            webView.postDelayed({
                if (!webView.isAttachedToWindow || !LooplyNativeAdBlockState.enabled) return@postDelayed
                try {
                    webView.evaluateJavascript(COSMETIC_FILTER_SCRIPT, null)
                } catch (_: RuntimeException) {
                    // O documento pode ter sido fechado durante a navegação.
                }
            }, delay)
        }
    }

    private companion object {
        /**
         * Filtro cosmético conservador: esconde slots e iframes de publicidade,
         * preserva o conteúdo principal e observa novas inserções no DOM.
         */
        const val COSMETIC_FILTER_SCRIPT = """
            (function () {
              try {
                if (window.__looplyAdBlockInstalled) {
                  if (window.__looplyAdBlockEnabled) window.__looplyAdBlockApply?.(document);
                  return;
                }
                window.__looplyAdBlockInstalled = true;
                window.__looplyAdBlockEnabled = true;

                var selectors = [
                  'ins.adsbygoogle', '.adsbygoogle',
                  'iframe[src*="doubleclick.net"]', 'iframe[src*="googlesyndication.com"]',
                  'iframe[src*="googleadservices.com"]', 'iframe[src*="adservice.google"]',
                  'iframe[src*="exoclick.com"]', 'iframe[src*="juicyads.com"]',
                  'iframe[src*="trafficjunky.com"]', 'iframe[src*="popads.net"]',
                  'iframe[id^="google_ads_iframe"]', 'div[id^="google_ads_iframe"]',
                  '[data-ad-slot]', '[data-ad-unit]', '[data-ad]', '[data-google-query-id]',
                  'amp-ad', 'amp-embed[type="adsense"]',
                  '.ad-container', '.ad-wrapper', '.ad-banner', '.banner-ad',
                  '[class*="ad-container"]', '[id*="ad-container"]',
                  '[class*="ad-wrapper"]', '[id*="ad-wrapper"]',
                  '[class*="advertisement"]', '[id*="advertisement"]',
                  '[class*="sponsored"]', '[id*="sponsored"]',
                  '.advertisement', '.advertising', '.sponsored-ad',
                  '.sponsored-content', '.native-ad', '.popup-ad', '.popunder',
                  '#ad-container', '#ad-banner', '#google_ads_iframe'
                ];

                var style = document.getElementById('__looply_adblock_style');
                if (!style) {
                  style = document.createElement('style');
                  style.id = '__looply_adblock_style';
                  style.textContent = selectors.join(',') + ',[data-looply-adblocked="1"]' +
                    '{display:none!important;visibility:hidden!important;pointer-events:none!important;' +
                    'width:0!important;height:0!important;min-width:0!important;min-height:0!important;}';
                  (document.head || document.documentElement).appendChild(style);
                }

                function hideNode(node) {
                  if (!node || node.nodeType !== 1) return;
                  try {
                    if (node.matches && node.matches(selectors.join(','))) {
                      node.setAttribute('data-looply-adblocked', '1');
                    }
                    if (node.querySelectorAll) {
                      var found = node.querySelectorAll(selectors.join(','));
                      for (var i = 0; i < found.length; i++) hideNode(found[i]);
                    }
                  } catch (_) {}
                }

                window.__looplyAdBlockApply = function (root) {
                  if (!window.__looplyAdBlockEnabled) return;
                  hideNode(root || document.documentElement);
                };

                window.__looplyAdBlockSetEnabled = function (enabled) {
                  window.__looplyAdBlockEnabled = !!enabled;
                  if (style) style.disabled = !window.__looplyAdBlockEnabled;
                  if (window.__looplyAdBlockEnabled) window.__looplyAdBlockApply(document);
                };

                if (window.MutationObserver && document.documentElement) {
                  var observer = new MutationObserver(function (mutations) {
                    if (!window.__looplyAdBlockEnabled) return;
                    for (var i = 0; i < mutations.length; i++) {
                      var added = mutations[i].addedNodes;
                      for (var j = 0; j < added.length; j++) hideNode(added[j]);
                    }
                  });
                  observer.observe(document.documentElement, { childList: true, subtree: true });
                  window.__looplyAdBlockObserver = observer;
                }
                window.__looplyAdBlockApply(document);

                // Bloqueia popunders e aberturas sem gesto real. Links abertos
                // diretamente pelo utilizador continuam a poder funcionar.
                if (!window.__looplyOpenWrapped) {
                  window.__looplyOpenWrapped = true;
                  var originalOpen = window.open;
                  window.open = function (url, name, features) {
                    var value = String(url || '');
                    var adDestination = /(?:doubleclick|googlesyndication|googleadservices|exoclick|juicyads|trafficjunky|popads|propellerads|onclickads|trafficstars|plugrush|adcash|adnium|adxpansion|onclckmn)\./i.test(value);
                    var userGesture = !!(navigator.userActivation && navigator.userActivation.isActive);
                    if (window.__looplyAdBlockEnabled && (adDestination || !userGesture)) return null;
                    return originalOpen.call(window, url, name, features);
                  };
                }

                if (!window.__looplyAdClickGuard) {
                  window.__looplyAdClickGuard = true;
                  document.addEventListener('click', function (event) {
                    if (!window.__looplyAdBlockEnabled) return;
                    var link = event.target && event.target.closest ? event.target.closest('a[href]') : null;
                    if (!link) return;
                    var href = String(link.href || '');
                    if (/(?:doubleclick|googlesyndication|googleadservices|exoclick|juicyads|trafficjunky|popads|propellerads|onclickads|trafficstars|plugrush|adcash|adnium|adxpansion|onclckmn)\./i.test(href)) {
                      event.preventDefault();
                      event.stopImmediatePropagation();
                    }
                  }, true);
                }
              } catch (_) {}
            })();
        """
    }
}

/** Regras compactas compiladas uma única vez, sem consulta de rede. */
private object LooplyAdRules {
    private val knownAdAndTrackerDomains = setOf(
        "doubleclick.net", "googlesyndication.com", "googleadservices.com",
        "google-analytics.com", "googletagmanager.com", "googletagservices.com",
        "adservice.google.com", "adsystem.com", "amazon-adsystem.com",
        "connect.facebook.net", "ads.facebook.com",
        "taboola.com", "outbrain.com", "criteo.com", "criteo.net", "adroll.com",
        "adnxs.com", "rubiconproject.com", "pubmatic.com", "openx.net",
        "casalemedia.com", "smartadserver.com", "advertising.com", "adform.net",
        "adtech.com", "media.net", "yieldmo.com", "bidswitch.net", "contextweb.com",
        "exoclick.com", "popads.net", "propellerads.com", "revcontent.com", "mgid.com",
        "zedo.com", "adblade.com", "adcolony.com", "applovin.com", "chartboost.com",
        "unityads.unity3d.com", "vungle.com", "inmobi.com", "mopub.com",
        "scorecardresearch.com", "quantserve.com", "hotjar.com", "mixpanel.com",
        "segment.io", "segment.com", "amplitude.com", "crazyegg.com", "optimizely.com",
        "newrelic.com", "nr-data.net", "bugsnag.com", "sentry.io", "intercom.io",
        "drift.com", "onesignal.com", "pushwoosh.com", "branch.io", "adjust.com",
        "appsflyer.com", "kochava.com", "tapjoy.com", "ironsrc.com", "smaato.net",
        "sharethrough.com", "teads.tv", "triplelift.com", "spotxchange.com", "adsrvr.org",
        "turn.com", "mathtag.com", "bluekai.com", "krxd.net", "demdex.net",
        "everesttech.net", "serving-sys.com", "atdmt.com", "adbrite.com", "adtechus.com",
        "burstnet.com", "chitika.com", "clicksor.com", "infolinks.com", "kontera.com",
        "lijit.com", "media6degrees.com", "pointroll.com", "quantcast.com", "rlcdn.com",
        "simpli.fi", "tribalfusion.com", "tremorhub.com", "undertone.com", "yieldlab.net",
        "zergnet.com", "popcash.net", "adsterra.com", "propellerclick.com", "clickadu.com",
        "galaksion.com", "adspyglass.com", "hilltopads.net", "juicyads.com",
        "trafficjunky.com", "exosrv.com", "moatads.com", "adsafeprotected.com",
        "doubleverify.com", "ensighten.com", "tynt.com", "addthis.com", "sharethis.com",
        "gemius.pl", "histats.com", "statcounter.com", "clicky.com",
        "getclicky.com", "woopra.com", "kissmetrics.com", "heap.io", "fullstory.com",
        "luckyorange.com", "mouseflow.com", "smartlook.com", "clarity.ms",
        // Redes de publicidade comuns em páginas adultas, popunders e tráfego desconhecido.
        "trafficstars.com", "plugrush.com", "tsyndicate.com", "adcash.com",
        "adnium.com", "ero-advertising.com", "adxpansion.com", "onclickads.net",
        "onclickalgo.com", "onclckmn.com", "adk2x.com", "adtrafico.com", "bebi.com",
        "a-ads.com", "trafficfactory.biz",
    )

    private val hostSignal = Regex(
        "(^|[.-])(?:ads?|adserver|adservice|advert(?:ising)?|banners?|popunder|popads|clickunder|trackers?|tracking|pixels?|beacons?|affiliate|sponsored?|impressions?|prebid|adunit)(?:[0-9]*)([.-]|$)",
        RegexOption.IGNORE_CASE,
    )
    private val pathSignal = Regex(
        "(?:^|/)(?:ads?|adserver|adservice|advert(?:ising)?|banners?|popunder|clickunder|trackers?|tracking|pixels?|beacons?|impressions?|vast)(?:[/._-]|$)",
        RegexOption.IGNORE_CASE,
    )
    private val querySignal = Regex(
        "(?:^|&)(?:ad|adid|ad_id|adunit|ad_unit|adslot|ad_slot|tracking|tracker|pixel|beacon|click_id)=?",
        RegexOption.IGNORE_CASE,
    )

    fun matches(rawUrl: String): Boolean {
        val uri = try {
            Uri.parse(rawUrl)
        } catch (_: RuntimeException) {
            return false
        }
        val scheme = uri.scheme?.lowercase() ?: return false
        if (scheme != "http" && scheme != "https") return false

        val host = uri.host?.lowercase()?.trimEnd('.') ?: return false
        if (host.isBlank()) return false
        // Percorre apenas os sufixos do host e usa HashSet O(1), sem procurar
        // cada domínio da lista em todas as requisições.
        var suffixStart = 0
        while (suffixStart < host.length) {
            if (knownAdAndTrackerDomains.contains(host.substring(suffixStart))) return true
            val separator = host.indexOf('.', suffixStart)
            if (separator < 0) break
            suffixStart = separator + 1
        }
        if (hostSignal.containsMatchIn(host)) return true

        val path = uri.encodedPath?.lowercase().orEmpty()
        if (pathSignal.containsMatchIn(path)) return true

        return querySignal.containsMatchIn(uri.encodedQuery?.lowercase().orEmpty())
    }
}

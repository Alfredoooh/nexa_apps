package com.looply.browser.app.browser

import android.webkit.WebResourceRequest
import java.util.Locale

/** Local URL filter, equivalent to the original native interceptor's domain rules. */
object LooplyAdBlocker {
    @Volatile var enabled: Boolean = true
    private val domains = setOf(
        "doubleclick.net","googlesyndication.com","googleadservices.com","google-analytics.com","googletagmanager.com","googletagservices.com","adservice.google.com","adsystem.com","amazon-adsystem.com","facebook.net","connect.facebook.net","fbcdn.net","ads.facebook.com","taboola.com","outbrain.com","criteo.com","criteo.net","adroll.com","adnxs.com","rubiconproject.com","pubmatic.com","openx.net","casalemedia.com","smartadserver.com","advertising.com","adform.net","adtech.com","media.net","yieldmo.com","bidswitch.net","contextweb.com","exoclick.com","popads.net","propellerads.com","revcontent.com","mgid.com","zedo.com","adblade.com","adcolony.com","applovin.com","chartboost.com","unityads.unity3d.com","vungle.com","inmobi.com","mopub.com","scorecardresearch.com","quantserve.com","hotjar.com","mixpanel.com","segment.io","segment.com","amplitude.com","crazyegg.com","optimizely.com","newrelic.com","nr-data.net","bugsnag.com","sentry.io","intercom.io","drift.com","onesignal.com","pushwoosh.com","branch.io","adjust.com","appsflyer.com","kochava.com","tapjoy.com","ironsrc.com","smaato.net","sharethrough.com","teads.tv","triplelift.com","spotxchange.com","adsrvr.org","turn.com","mathtag.com","bluekai.com","krxd.net","demdex.net","everesttech.net","serving-sys.com","atdmt.com","adbrite.com","adtechus.com","burstnet.com","chitika.com","clicksor.com","infolinks.com","kontera.com","lijit.com","media6degrees.com","pointroll.com","quantcast.com","rlcdn.com","simpli.fi","tribalfusion.com","tremorhub.com","undertone.com","yieldlab.net","zergnet.com","popcash.net","adsterra.com","propellerclick.com","clickadu.com","galaksion.com","adspyglass.com","hilltopads.net","juicyads.com","trafficjunky.com","exosrv.com","moatads.com","adsafeprotected.com","doubleverify.com","ensighten.com","tynt.com","addthis.com","sharethis.com","disqus.com","gemius.pl","histats.com","statcounter.com","clicky.com","getclicky.com","woopra.com","kissmetrics.com","heap.io","fullstory.com","luckyorange.com","trafficstars.com","plugrush.com","tsyndicate.com","adcash.com","adnium.com","ero-advertising.com","adxpansion.com","onclickads.net","onclickalgo.com","onclckmn.com","adk2x.com","adtrafico.com","bebi.com","a-ads.com","trafficfactory.biz","mouseflow.com","smartlook.com","clarity.ms"
    )
    fun shouldBlock(request: WebResourceRequest): Boolean {
        if (!enabled || request.isForMainFrame) return false
        val host = request.url.host?.lowercase(Locale.ROOT) ?: return false
        return domains.any { host == it || host.endsWith(".$it") }
    }

    const val COSMETIC_SCRIPT = """
    (function(){try{if(window.__looplyBlocker)return;window.__looplyBlocker=true;
    var s=['ins.adsbygoogle','.adsbygoogle','iframe[src*=doubleclick]','iframe[src*=googlesyndication]','iframe[src*=googleadservices]','iframe[id^=google_ads_iframe]','[data-ad-slot]','[data-ad-unit]','[data-ad]','[data-google-query-id]','amp-ad','.ad-container','.ad-wrapper','.ad-banner','.advertisement','.sponsored-ad','.native-ad','.popup-ad','.popunder','[class*=advertisement]','[id*=advertisement]','[class*=sponsored]','[id*=sponsored]'];
    var css=document.createElement('style');css.textContent=s.join(',')+'{display:none!important;visibility:hidden!important;pointer-events:none!important;width:0!important;height:0!important}';(document.head||document.documentElement).appendChild(css);
    function hide(n){if(!n||n.nodeType!==1)return;try{if(n.matches&&n.matches(s.join(',')))n.style.setProperty('display','none','important');if(n.querySelectorAll)n.querySelectorAll(s.join(',')).forEach(function(x){x.style.setProperty('display','none','important')})}catch(e){}}
    hide(document.documentElement);new MutationObserver(function(ms){ms.forEach(function(m){m.addedNodes.forEach(hide)})}).observe(document.documentElement,{childList:true,subtree:true});
    var old=window.open;window.open=function(u){if(/doubleclick|googlesyndication|googleadservices|exoclick|juicyads|trafficjunky|popads|propellerads/i.test(String(u||'')))return null;return old.apply(this,arguments)};
    }catch(e){}})();
    """
}

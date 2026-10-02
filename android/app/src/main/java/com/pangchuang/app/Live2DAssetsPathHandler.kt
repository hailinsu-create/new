package com.pangchuang.app

import android.content.Context
import android.util.Log
import android.webkit.WebResourceResponse
import androidx.webkit.WebViewAssetLoader
import java.io.IOException
import java.util.Locale

/**
 * Serves files from assets/ with MIME types that WebView/fetch accept for Live2D.
 * Default AssetsPathHandler can mishandle .moc3 / unknown extensions.
 */
class Live2DAssetsPathHandler(
    private val context: Context
) : WebViewAssetLoader.PathHandler {
    override fun handle(path: String): WebResourceResponse {
        val cleaned = path.trimStart('/')
        return try {
            val mime = mimeFor(cleaned)
            val stream = context.assets.open(cleaned)
            Log.d(TAG, "serve $cleaned ($mime)")
            WebResourceResponse(mime, "UTF-8", stream)
        } catch (e: IOException) {
            Log.e(TAG, "missing asset: $cleaned", e)
            WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", emptyMap(), "".byteInputStream())
        }
    }

    private fun mimeFor(path: String): String {
        val lower = path.lowercase(Locale.US)
        return when {
            lower.endsWith(".html") || lower.endsWith(".htm") -> "text/html"
            lower.endsWith(".js") -> "application/javascript"
            lower.endsWith(".mjs") -> "application/javascript"
            lower.endsWith(".css") -> "text/css"
            lower.endsWith(".json") -> "application/json"
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> "image/jpeg"
            lower.endsWith(".webp") -> "image/webp"
            lower.endsWith(".wasm") -> "application/wasm"
            lower.endsWith(".moc3") -> "application/octet-stream"
            lower.endsWith(".mtn") -> "application/octet-stream"
            lower.endsWith(".svg") -> "image/svg+xml"
            else -> "application/octet-stream"
        }
    }

    companion object {
        private const val TAG = "PangchuangLive2DAsset"
    }
}

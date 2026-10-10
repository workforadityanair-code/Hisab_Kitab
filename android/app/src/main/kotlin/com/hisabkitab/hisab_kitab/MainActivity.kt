package com.hisabkitab.hisab_kitab

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var openedFile: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        readOpenedFile(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (readOpenedFile(intent)) {
            channel?.invokeMethod("fileOpened", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, "hisabkitab/share").also { c ->
            c.setMethodCallHandler { call, result ->
                when (call.method) {
                    "whatsappImage" -> {
                        val path = call.argument<String>("path")
                        val text = call.argument<String>("text") ?: ""
                        val phone = call.argument<String>("phone") ?: ""
                        result.success(
                            if (path == null) false else shareToWhatsApp(path, text, phone)
                        )
                    }
                    "takeOpenedFile" -> {
                        val content = openedFile
                        openedFile = null
                        result.success(content)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun readOpenedFile(intent: Intent?): Boolean {
        if (intent == null) return false
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return false
        return try {
            val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
            if (text.isNullOrEmpty()) {
                false
            } else {
                openedFile = text
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun shareToWhatsApp(path: String, text: String, phone: String): Boolean {
        val uri = try {
            FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))
        } catch (e: Exception) {
            return false
        }
        for (target in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, text)
                putExtra("jid", "$phone@s.whatsapp.net")
                setPackage(target)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                startActivity(intent)
                return true
            } catch (e: Exception) {
                continue
            }
        }
        return false
    }
}

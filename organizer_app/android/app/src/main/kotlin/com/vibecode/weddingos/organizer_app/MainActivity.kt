package com.vibecode.weddingos.organizer_app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pickerChannel = "weddingos/file_picker"
    private val pickXlsxRequestCode = 9041
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pickerChannel).setMethodCallHandler { call, result ->
            if (call.method != "pickXlsx") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingResult != null) {
                result.error("PICKER_BUSY", "A file picker request is already active.", null)
                return@setMethodCallHandler
            }

            pendingResult = result
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
            }
            startActivityForResult(intent, pickXlsxRequestCode)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickXlsxRequestCode) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            val bytes = contentResolver.openInputStream(data.data!!)?.use { it.readBytes() }
            result.success(bytes)
        } catch (error: Exception) {
            result.error("READ_FAILED", "Unable to read selected XLSX file.", null)
        }
    }
}

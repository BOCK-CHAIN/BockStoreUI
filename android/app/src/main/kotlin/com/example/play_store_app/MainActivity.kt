package com.example.play_store_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "bock.store/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "uninstallApp" -> {
                    val packageName = call.argument<String>("packageName")

                    if (!packageName.isNullOrEmpty()) {
                        val intent = Intent(Intent.ACTION_UNINSTALL_PACKAGE).apply {
                            data = Uri.parse("package:$packageName")
                            putExtra(Intent.EXTRA_RETURN_RESULT, true)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error(
                            "INVALID_PACKAGE",
                            "Package name is null or empty",
                            null
                        )
                    }
                }

                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")

                    if (!packageName.isNullOrEmpty()) {
                        try {
                            packageManager.getPackageInfo(packageName, 0)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
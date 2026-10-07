package com.nutilizmobile

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.nutilizmobile/app_update",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getBuildNumber" -> {
					try {
						result.success(getBuildNumber())
					} catch (error: Exception) {
						result.error("build_number_unavailable", error.message, null)
					}
				}
				"openPlayStore" -> {
					try {
						val storeUri = Uri.parse("market://details?id=$packageName")
						startActivity(Intent(Intent.ACTION_VIEW, storeUri))
						result.success(true)
					} catch (_: Exception) {
						try {
							val webUri = Uri.parse(
								"https://play.google.com/store/apps/details?id=$packageName",
							)
							startActivity(Intent(Intent.ACTION_VIEW, webUri))
							result.success(true)
						} catch (error: Exception) {
							result.error("play_store_unavailable", error.message, null)
						}
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	@Suppress("DEPRECATION")
	private fun getBuildNumber(): Long {
		val packageInfo = packageManager.getPackageInfo(packageName, 0)
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
			packageInfo.longVersionCode
		} else {
			packageInfo.versionCode.toLong()
		}
	}

	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		val appIsDebuggable =
			(applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
		if (!appIsDebuggable && isReleaseEnvironmentUnsafe()) {
			finishAndRemoveTask()
			return
		}
		super.onCreate(savedInstanceState)
	}

	private fun isReleaseEnvironmentUnsafe(): Boolean {
		val applicationInfo = applicationInfo
		val debuggerAttached = Debug.isDebuggerConnected() || Debug.waitingForDebugger()
		val appMarkedDebuggable =
			(applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
		val emulatorSignals =
			Build.FINGERPRINT.startsWith("generic") ||
				Build.FINGERPRINT.startsWith("unknown") ||
				Build.MODEL.contains("google_sdk", ignoreCase = true) ||
				Build.MODEL.contains("emulator", ignoreCase = true) ||
				Build.MANUFACTURER.contains("genymotion", ignoreCase = true) ||
				(Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))

		return debuggerAttached || appMarkedDebuggable || emulatorSignals
	}
}

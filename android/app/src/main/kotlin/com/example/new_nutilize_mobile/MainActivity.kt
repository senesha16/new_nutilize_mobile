package com.nutilizmobile

import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		if (!BuildConfig.DEBUG && isReleaseEnvironmentUnsafe()) {
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

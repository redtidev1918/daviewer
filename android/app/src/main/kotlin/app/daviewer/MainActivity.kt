package app.daviewer

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "daviewer/system_proxy",
        ).setMethodCallHandler { call, result ->
            if (call.method != "getSystemProxy") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                result.success(null)
                return@setMethodCallHandler
            }
            val proxy = try {
                val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE)
                    as ConnectivityManager
                connectivity.defaultProxy
            } catch (_: SecurityException) {
                null
            }
            val host = proxy?.host?.trim().orEmpty()
            val port = proxy?.port ?: -1
            if (host.isEmpty() || port !in 1..65535) {
                result.success(null)
            } else {
                result.success(mapOf("host" to host, "port" to port))
            }
        }
    }
}

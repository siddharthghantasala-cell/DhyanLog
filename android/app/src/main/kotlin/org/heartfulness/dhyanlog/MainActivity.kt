package org.heartfulness.dhyanlog

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationMutePlugin.register(
            this,
            flutterEngine.dartExecutor.binaryMessenger
        )
    }
}

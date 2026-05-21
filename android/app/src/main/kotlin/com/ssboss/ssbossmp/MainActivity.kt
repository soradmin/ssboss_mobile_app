package com.ssboss.ssbossmp

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * [FlutterFragmentActivity] — [androidx.activity.ComponentActivity], поэтому доступен
 * [enableEdgeToEdge] (Android 15+). Это согласуется с рекомендациями Play Console вместо
 * устаревших вызовов Window.setStatusBarColor / setNavigationBarColor.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}


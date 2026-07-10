package net.defined.mobile_nebula

import io.flutter.embedding.engine.loader.FlutterLoader
import android.app.Application

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        FlutterLoader().startInitialization(applicationContext)
    }
}

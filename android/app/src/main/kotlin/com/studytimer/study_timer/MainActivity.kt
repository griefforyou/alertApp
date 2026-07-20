package com.studytimer.study_timer

import android.content.Context
import android.media.RingtoneManager
import android.provider.MediaStore
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNotificationSounds" -> {
                    result.success(getNotificationSounds(this))
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "com.studytimer/sound_picker"
    }

    private fun getNotificationSounds(context: Context): List<Map<String, String>> {
        val sounds = mutableListOf<Map<String, String>>()
        try {
            val manager = RingtoneManager(context)
            manager.setType(RingtoneManager.TYPE_NOTIFICATION)
            val cursor = manager.cursor
            if (cursor != null) {
                val titleIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                while (cursor.moveToNext()) {
                    val title = cursor.getString(titleIndex) ?: "Unknown"
                    val position = cursor.position
                    val uri = manager.getRingtoneUri(position)?.toString()
                    if (uri != null) {
                        sounds.add(mapOf("title" to title, "uri" to uri))
                    }
                }
                cursor.close()
            }
        } catch (_: Exception) {}
        return sounds
    }
}

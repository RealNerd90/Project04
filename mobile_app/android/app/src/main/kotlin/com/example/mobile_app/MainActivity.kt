package com.example.mobile_app

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mobile_app/audio"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val rawName = call.argument<String>("rawName")
                    val url = call.argument<String>("url")

                    try {
                        try {
                            if (mediaPlayer != null) {
                                if (mediaPlayer!!.isPlaying) {
                                    mediaPlayer!!.stop()
                                }
                                mediaPlayer!!.release()
                                mediaPlayer = null
                            }
                        } catch (_: Exception) {}

                        // 1. Try local raw resource first (instant, guaranteed audio playback)
                        if (!rawName.isNullOrEmpty()) {
                            val cleanName = rawName.lowercase().replace(" ", "_").replace(".wav", "").replace(".mp3", "")
                            val resId = resources.getIdentifier(cleanName, "raw", packageName)
                            if (resId != 0) {
                                mediaPlayer = MediaPlayer.create(this@MainActivity, resId).apply {
                                    setVolume(1.0f, 1.0f)
                                    setOnCompletionListener {
                                        it.release()
                                        mediaPlayer = null
                                    }
                                    start()
                                }
                                result.success(true)
                                return@setMethodCallHandler
                            }
                        }

                        // 2. Stream from network URL or file
                        if (!url.isNullOrEmpty()) {
                            mediaPlayer = MediaPlayer().apply {
                                setAudioAttributes(
                                    AudioAttributes.Builder()
                                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                        .setUsage(AudioAttributes.USAGE_MEDIA)
                                        .build()
                                )
                                setDataSource(this@MainActivity, android.net.Uri.parse(url))
                                setVolume(1.0f, 1.0f)
                                setOnPreparedListener { mp ->
                                    mp.start()
                                }
                                setOnCompletionListener {
                                    it.release()
                                    mediaPlayer = null
                                }
                                setOnErrorListener { mp, _, _ ->
                                    mp.release()
                                    mediaPlayer = null
                                    false
                                }
                                prepareAsync()
                            }
                            result.success(true)
                        } else {
                            result.error("PLAY_ERROR", "Neither rawName nor URL provided", null)
                        }
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }
                "stop" -> {
                    try {
                        if (mediaPlayer?.isPlaying == true) {
                            mediaPlayer?.stop()
                        }
                        mediaPlayer?.release()
                        mediaPlayer = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}
        super.onDestroy()
    }
}

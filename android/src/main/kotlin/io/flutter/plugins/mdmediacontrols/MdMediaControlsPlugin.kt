package io.flutter.plugins.mdmediacontrols

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.util.Log
import java.io.IOException
import android.os.Handler
import java.lang.Exception
import java.lang.IllegalStateException


class MdMediaControlsPlugin(Channel: MethodChannel, Registrar: Registrar) : MethodCallHandler {
    private val mediaPlayer = MediaPlayer()
    private var uncontrolledMediaPLayer = MediaPlayer()
    private val registrar: Registrar = Registrar
    private val channel: MethodChannel = Channel
    private val am: AudioManager
    private var isOnPlay = false
    private var isSekInProgress = false
    private val handler = Handler()
    private val context: Context

    init {
        this.channel.setMethodCallHandler(this)
        this.context = this.registrar.context().applicationContext
        this.am = this.context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }


    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "md_media_controls")
            channel.setMethodCallHandler(MdMediaControlsPlugin(channel, registrar))
        }

    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "play" -> {
                val args = call.arguments as HashMap<*, *>
                val url = args.get("url") as String
                val rate = args.get("rate") as Double
                val isLocal = args.get("isLocal") as Boolean
                val startPosition = args.get("startPosition") as Double
                val autoPlay = args.get("autoPlay") as Boolean

                try {
                    this.mediaPlayer.stop()
                } catch (error: IllegalStateException) {}

                this.mediaPlayer.reset()

                try {
                    if (isLocal && (url.indexOf("assets") == 0 || url.indexOf("/assets") == 0)) {
                        val assetManager = this.registrar.context().assets
                        val key = this.registrar.lookupKeyForAsset(url)
                        val fd = assetManager.openFd(key)
                        if (fd.declaredLength < 0) {
                            this.mediaPlayer.setDataSource(fd.fileDescriptor)
                        } else {
                            this.mediaPlayer.setDataSource(fd.fileDescriptor, fd.startOffset, fd.declaredLength)
                        }
                    } else {
                        this.mediaPlayer.setDataSource(url)
                    }
                } catch (error: IOException) {
                    Log.w("Play", "Invalid data source", error)
                    this.channel.invokeMethod("error", "play error")
                    return result.error("Playing error", "Invalid data source", null)
                }

                try {
                    this.mediaPlayer.prepare()
                    if (autoPlay) {
                        this.mediaPlayer.start()
                    }
                    if (startPosition != 0.0) {
                        isSekInProgress = true
                        val positionInMsec = startPosition * 1000
                        this.mediaPlayer.seekTo(positionInMsec.toInt())
                    }
                    if (autoPlay) {
                        this.channel.invokeMethod("audio.play", null)
                    } else {
                        this.channel.invokeMethod("audio.pause", null)
                    }
                    val duration = this.mediaPlayer.duration
                    this.channel.invokeMethod("audio.duration", duration / 1000)
                } catch (error: Exception) {
                    Log.w("player", "prepare error", error)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (autoPlay) {
                        this.mediaPlayer.playbackParams = this.mediaPlayer.playbackParams.setSpeed(rate.toFloat())
                    }
                    this.channel.invokeMethod("audio.rate", rate.toFloat())
                }

                this.mediaPlayer.setOnCompletionListener {
                    this.channel.invokeMethod("audio.completed", null)
                    this.isOnPlay = false
                    handler.removeCallbacks(this.sendData)
                }

                this.mediaPlayer.setOnErrorListener { _, _, _ ->
                    channel.invokeMethod("error", "start play error")
                    true
                }

                this.mediaPlayer.setOnSeekCompleteListener {
                    val time = mediaPlayer.currentPosition
                    channel.invokeMethod("audio.position", time)
                    isSekInProgress = false
                }
                this.isOnPlay = autoPlay
                this.handler.post(this.sendData)
                return result.success(true)
            }
            "pause" -> {
                if (this.mediaPlayer?.isPlaying && this.isOnPlay) {
                    this.isOnPlay = false
                    this.mediaPlayer.pause()
                    this.channel.invokeMethod("audio.pause", null)
                    this.handler.removeCallbacks(this.sendData)
                }
                return result.success(true)
            }
            "playPrev" -> {
                if (!this.isOnPlay) {
                    this.isOnPlay = true
                    this.mediaPlayer.start()
                    this.channel.invokeMethod("audio.play", null)
                    this.handler.post(this.sendData)
                }
                return result.success(true)
            }
            "seek" -> {
                val args = call.arguments as HashMap<*, *>
                val position = args.get("position") as Double
                val play = args.get("play") as Boolean
                val positionInMsec = position * 1000
                isSekInProgress = true
                this.mediaPlayer.seekTo(positionInMsec.toInt())
                if (!this.isOnPlay) {
                    this.isOnPlay = false
                    this.handler.removeCallbacks(this.sendData)
                    this.handler.post(this.sendData)
                }
                if (play) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        this.mediaPlayer.playbackParams = this.mediaPlayer.playbackParams.setSpeed(1.0f)
                    }
                    this.isOnPlay = true
                    this.mediaPlayer.start()
                    this.channel.invokeMethod("audio.play", null)
                } else {
                    this.isOnPlay = false
                    this.mediaPlayer.pause()
                    this.channel.invokeMethod("audio.pause", null)
                }
                this.channel.invokeMethod("audio.rate", 1.0)
                return result.success(true)
            }
            "stop" -> {
                this.handler.removeCallbacks(this.sendData)
                this.channel.invokeMethod("audio.stop", null)
                this.isOnPlay = false
                return result.success(true)
            }
            "rate" -> {
                val args = call.arguments as HashMap<*, *>
                val rate = args.get("rate") as Double
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    this.mediaPlayer.playbackParams = this.mediaPlayer.playbackParams.setSpeed(rate.toFloat())
                    this.channel.invokeMethod("audio.rate", rate.toFloat())
                }
                return result.success(true)
            }
            "infoControls" -> {
                // TODO implement it
                return result.success(true)
            }
            "info" -> {
                return result.success(true)
            }
            "clearInfo" -> {
                // TODO implement it
                return result.success(true)
            }
            "playUncontrolled" -> {
                val args = call.arguments as HashMap<*, *>
                val url = args.get("url") as String
                val rate = args.get("rate") as Double
                val isLocal = args.get("isLocal") as Boolean

                try {
                    this.uncontrolledMediaPLayer.stop()
                } catch (error: IllegalStateException) {}
                
                this.uncontrolledMediaPLayer.reset()

                try {
                    if (isLocal && (url.indexOf("assets") == 0 || url.indexOf("/assets") == 0)) {
                        val assetManager = this.registrar.context().assets
                        val key = this.registrar.lookupKeyForAsset(url)
                        val fd = assetManager.openFd(key)
                        if (fd.declaredLength < 0) {
                            this.uncontrolledMediaPLayer.setDataSource(fd.fileDescriptor)
                        } else {
                            this.uncontrolledMediaPLayer.setDataSource(fd.fileDescriptor, fd.startOffset, fd.declaredLength)
                        }
                    } else {
                        this.uncontrolledMediaPLayer.setDataSource(url)
                    }
                } catch (error: IOException) {
                    return result.error("Playing error", "Invalid data source", null)
                }

                try {
                    this.uncontrolledMediaPLayer.prepare()
                    this.uncontrolledMediaPLayer.start()
                } catch (error: Exception) {
                    Log.w("player", "prepare error", error)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    this.uncontrolledMediaPLayer.playbackParams = this.uncontrolledMediaPLayer.playbackParams.setSpeed(rate.toFloat())
                }
                return result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private val sendData = object : Runnable {
        override fun run() {
            try {
                if (!mediaPlayer.isPlaying) {
                    handler.removeCallbacks(this)
                    return
                }
                if (!isSekInProgress) {
                    val time = mediaPlayer.currentPosition
                    channel.invokeMethod("audio.position", time)
                }
                handler.postDelayed(this, 100)
            } catch (error: Exception) {
                Log.w("player", "Handler error", error)
            }

        }
    }
}

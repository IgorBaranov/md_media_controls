package io.flutter.plugins.mdmediacontrols

import android.app.Service
import android.content.Context
import android.content.Intent
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
import android.os.IBinder
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.FlutterNativeView
import java.lang.Exception
import java.util.*

class MdMediaService : MethodCallHandler, Service() {
    private lateinit var mBackgroundChannel: MethodChannel
    private lateinit var context: Context
    private var mediaPlayer = MediaPlayer()
    private var uncontrolledMediaPLayer = MediaPlayer()
    private lateinit var am: AudioManager
    private var isOnPlay = false
    private val handler = Handler()

    companion object {
        @JvmStatic
        private lateinit var registrar: PluginRegistry.PluginRegistrantCallback


        @JvmStatic
        fun setPluginRegistrant(callback: PluginRegistry.PluginRegistrantCallback) {
            registrar = callback
        }
    }

    private fun startMediaService(mContext: Context) {
        context = mContext
    }


    override fun onCreate() {
        print("created")
        // Start up the thread running the service.  Note that we create a
        // separate thread because the service normally runs in the process's
        // main thread, which we don't want to block.  We also make it
        // background priority so CPU-intensive work will not disrupt our UI.
    }

    override fun onBind(intent: Intent): IBinder? {
        // We don't provide binding, so return null
        return null
    }

    override fun onDestroy() {

    }

    override fun onMethodCall(call: MethodCall, result: Result) {
//        when (call.method) {
//            "play" -> {
//                val args = call.arguments as HashMap<*, *>
//                val url = args.get("url") as String
//                val rate = args.get("rate") as Double
//                val isLocal = args.get("isLocal") as Boolean
//
//                this.mediaPlayer?.release()
//                this.mediaPlayer = MediaPlayer()
//
//                try {
//                    if (isLocal && (url.indexOf("assets") == 0 || url.indexOf("/assets") == 0)) {
//                        val assetManager = this.registrar.context().assets
//                        val key = this.registrar.lookupKeyForAsset(url)
//                        val fd = assetManager.openFd(key)
//                        if (fd.declaredLength < 0) {
//                            this.mediaPlayer.setDataSource(fd.fileDescriptor)
//                        } else {
//                            this.mediaPlayer.setDataSource(fd.fileDescriptor, fd.startOffset, fd.declaredLength)
//                        }
//                    } else {
//                        this.mediaPlayer.setDataSource(url)
//                    }
//                } catch (error: IOException) {
//                    Log.w("Play", "Invalid data source", error)
//                    this.channel.invokeMethod("error", "play error")
//                    return result.error("Playing error", "Invalid data source", null)
//                }
//
//                try {
//                    this.mediaPlayer.prepare();
//                    this.mediaPlayer.start();
//                    this.channel.invokeMethod("audio.play", null)
//                    val duration = this.mediaPlayer.duration
//                    this.channel.invokeMethod("audio.duration", duration / 1000)
//                } catch (error: Exception) {
//                    Log.w("player", "prepare error", error)
//                }
//
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//                    this.mediaPlayer.playbackParams = this.mediaPlayer.playbackParams.setSpeed(rate.toFloat())
//                    this.channel.invokeMethod("audio.rate", rate.toFloat())
//                }
//
//                this.mediaPlayer.setOnCompletionListener {
//                    this.channel.invokeMethod("audio.completed", null)
//                    this.isOnPlay = false
//                    handler.removeCallbacks(this.sendData)
//                }
//
//                this.mediaPlayer.setOnErrorListener { _, _, _ ->
//                    channel.invokeMethod("error", "start play error")
//                    true
//                }
//                this.isOnPlay = true
//                this.handler.post(this.sendData)
//                return result.success(true)
//            }
//            "pause" -> {
//                if (this.mediaPlayer?.isPlaying && this.isOnPlay) {
//                    this.isOnPlay = false
//                    this.mediaPlayer.pause()
//                    this.channel.invokeMethod("audio.pause", null)
//                    this.handler.removeCallbacks(this.sendData)
//                }
//                return result.success(true)
//            }
//            "playPrev" -> {
//                if (!this.isOnPlay) {
//                    this.isOnPlay = true
//                    this.mediaPlayer.start()
//                    this.channel.invokeMethod("audio.play", null)
//                    this.handler.post(this.sendData)
//                }
//                return result.success(true)
//            }
//            "seek" -> {
//                val args = call.arguments as HashMap<*, *>
//                val position = args.get("position") as Double
//                val positionInMsec = position * 1000
//                this.mediaPlayer.seekTo(positionInMsec.toInt())
//                if (!this.isOnPlay) {
//                    this.isOnPlay = false
//                    this.handler.removeCallbacks(this.sendData)
//                    this.handler.post(this.sendData);
//                }
//                return result.success(true)
//            }
//            "stop" -> {
//                this.handler.removeCallbacks(this.sendData)
//                this.mediaPlayer.release()
//                this.channel.invokeMethod("audio.stop", null)
//                this.isOnPlay = false
//                return result.success(true)
//            }
//            "rate" -> {
//                val args = call.arguments as HashMap<*, *>
//                val rate = args.get("rate") as Double
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//                    this.mediaPlayer.playbackParams = this.mediaPlayer.playbackParams.setSpeed(rate.toFloat())
//                    this.channel.invokeMethod("audio.rate", rate.toFloat())
//                }
//                return result.success(true)
//            }
//            "infoControls" -> {
//                // TODO implement it
//                return result.success(true)
//            }
//            "info" -> {
//                return result.success(true)
//            }
//            "clearInfo" -> {
//                // TODO implement it
//                return result.success(true)
//            }
//            "playUncontrolled" -> {
//                val args = call.arguments as HashMap<*, *>
//                val url = args.get("url") as String
//                val rate = args.get("rate") as Double
//                val isLocal = args.get("isLocal") as Boolean
//
//                this.uncontrolledMediaPLayer?.release()
//                this.uncontrolledMediaPLayer = MediaPlayer()
//
//                try {
//                    if (isLocal && (url.indexOf("assets") == 0 || url.indexOf("/assets") == 0)) {
//                        val assetManager = this.registrar.context().assets
//                        val key = this.registrar.lookupKeyForAsset(url)
//                        val fd = assetManager.openFd(key)
//                        if (fd.declaredLength < 0) {
//                            this.uncontrolledMediaPLayer.setDataSource(fd.fileDescriptor)
//                        } else {
//                            this.uncontrolledMediaPLayer.setDataSource(fd.fileDescriptor, fd.startOffset, fd.declaredLength)
//                        }
//                    } else {
//                        this.uncontrolledMediaPLayer.setDataSource(url)
//                    }
//                } catch (error: IOException) {
//                    return result.error("Playing error", "Invalid data source", null)
//                }
//
//                try {
//                    this.uncontrolledMediaPLayer.prepare();
//                    this.uncontrolledMediaPLayer.start();
//                } catch (error: Exception) {
//                    Log.w("player", "prepare error", error)
//                }
//
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//                    this.uncontrolledMediaPLayer.playbackParams = this.uncontrolledMediaPLayer.playbackParams.setSpeed(rate.toFloat())
//                }
//                return result.success(true)
//            }
//            else -> {
//                result.notImplemented()
//            }
//        }
    }

    private val sendData = object : Runnable {
        override fun run() {
            try {
//                if (!mediaPlayer.isPlaying) {
//                    handler.removeCallbacks(this)
//                }
//                val time = mediaPlayer.currentPosition
//                channel.invokeMethod("audio.position", time)
//                handler.postDelayed(this, 100)
            } catch (error: Exception) {
                Log.w("player", "Handler error", error)
            }

        }
    }
}
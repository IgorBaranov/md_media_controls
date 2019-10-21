package io.flutter.plugins.mdmediacontrols

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
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


class MdMediaControlsPlugin(Channel: MethodChannel, Registrar: Registrar) : MethodCallHandler, AudioManager.OnAudioFocusChangeListener {
    private val mediaPlayer = MediaPlayer()
    private var uncontrolledMediaPLayer = MediaPlayer()
    private val registrar: Registrar = Registrar
    private val channel: MethodChannel = Channel
    private val am: AudioManager
    private var isOnPlay = false
    private var isSeekInProgress = false
    private val handler = Handler()
    private val context: Context
    private var wasAudioInterrupted = false

    init {
        this.channel.setMethodCallHandler(this)
        this.context = this.registrar.context().applicationContext
        this.am = this.context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            this.mediaPlayer.setAudioAttributes(
                    AudioAttributes
                            .Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build())
        }

        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        context.registerReceiver(HeadsetReceiver(), filter)
    }

    companion object {
        private const val ARG_URL = "url"
        private const val ARG_RATE = "rate"
        private const val ARG_IS_LOCAL = "isLocal"
        private const val ARG_POSITION = "position"
        private const val ARG_START_POSITION = "startPosition"
        private const val ARG_AUTO_PLAY = "autoPlay"
        private const val ARG_PLAY = "play"

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "md_media_controls")
            channel.setMethodCallHandler(MdMediaControlsPlugin(channel, registrar))
        }
    }

    override fun onAudioFocusChange(focusChange: Int) {
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                if (isOnPlay) {
                    pause()
                    wasAudioInterrupted = true
                }
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                if (!isOnPlay && wasAudioInterrupted) {
                    playPrev()
                    wasAudioInterrupted = false
                }
            }
        }
    }

    private fun hasAudioFocus(): Boolean {
        return this.am.requestAudioFocus(this, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "play" -> {
                val args = call.arguments as HashMap<*, *>
                val url = args[ARG_URL] as String
                val rate = args[ARG_RATE] as Double
                val isLocal = args[ARG_IS_LOCAL] as Boolean
                val startPosition = args[ARG_START_POSITION] as Double
                val autoPlay = args[ARG_AUTO_PLAY] as Boolean

                try {
                    this.mediaPlayer.stop()
                } catch (error: IllegalStateException) {}

                this.mediaPlayer.reset()

                try {
                    setDataSource(url, isLocal)
                } catch (error: IOException) {
                    Log.w("Play", "Invalid data source", error)
                    this.channel.invokeMethod("error", "play error")
                    return result.error("Playing error", "Invalid data source", null)
                }

                play(autoPlay, startPosition, rate)
                return result.success(true)
            }
            "pause" -> {
                pause()
                return result.success(true)
            }
            "playPrev" -> {
                playPrev()
                return result.success(true)
            }
            "seek" -> {
                val args = call.arguments as HashMap<*, *>
                val position = args[ARG_POSITION] as Double
                val play = args[ARG_PLAY] as Boolean
                seek(position, play)
                return result.success(true)
            }
            "stop" -> {
                stop()
                return result.success(true)
            }
            "rate" -> {
                val args = call.arguments as HashMap<*, *>
                val rate = args[ARG_RATE] as Double
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
                val url = args[ARG_URL] as String
                val rate = args[ARG_RATE] as Double
                val isLocal = args[ARG_IS_LOCAL] as Boolean

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

    @Throws(IOException::class)
    private fun setDataSource(url: String, isLocal: Boolean) {
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
    }

    private fun play(autoPlay: Boolean, startPosition: Double, rate: Double) {
        wasAudioInterrupted = false

        try {
            var hasAudioFocus = false
            this.mediaPlayer.prepare()
            if (autoPlay) {
                hasAudioFocus = hasAudioFocus()
                if (hasAudioFocus) {
                    this.mediaPlayer.start()
                }
            }
            if (startPosition != 0.0) {
                this.isSeekInProgress = true
                val positionInMsec = startPosition * 1000
                this.mediaPlayer.seekTo(positionInMsec.toInt())
            }
            if (autoPlay && hasAudioFocus) {
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

        this.mediaPlayer.setOnSeekCompleteListener {
            val time = mediaPlayer.currentPosition
            channel.invokeMethod("audio.position", time)
            this.isSeekInProgress = false
        }
        this.isOnPlay = autoPlay
        this.handler.post(this.sendData)
    }

    private fun pause() {
        if (this.mediaPlayer.isPlaying && this.isOnPlay) {
            this.isOnPlay = false
            this.mediaPlayer.pause()
            this.channel.invokeMethod("audio.pause", null)
            this.handler.removeCallbacks(this.sendData)
        }
    }

    private fun playPrev() {
        if (!this.isOnPlay && hasAudioFocus()) {
            this.isOnPlay = true
            this.mediaPlayer.start()
            this.channel.invokeMethod("audio.play", null)
            this.handler.post(this.sendData)
        }
    }

    private fun seek(position: Double, play: Boolean) {
        val positionInMsec = position * 1000
        this.isSeekInProgress = true
        this.mediaPlayer.seekTo(positionInMsec.toInt())
        print(this.mediaPlayer.isPlaying)
        print(this.isSeekInProgress)

        if (play) {
            if (!this.isOnPlay && hasAudioFocus()) {
                this.isOnPlay = true
                this.mediaPlayer.start()
                this.handler.removeCallbacks(this.sendData)
                this.handler.post(this.sendData)
            }
            this.channel.invokeMethod("audio.play", null)
        } else {
            if (this.isOnPlay) {
                this.isOnPlay = false
                this.mediaPlayer.pause()
            }
            this.channel.invokeMethod("audio.pause", null)
        }
    }

    private fun stop() {
        this.handler.removeCallbacks(this.sendData)
        try {
            this.mediaPlayer.stop()
        } catch (error: IllegalStateException) {}
        this.channel.invokeMethod("audio.stop", null)
        this.isOnPlay = false
    }

    private val sendData = object : Runnable {
        override fun run() {
            try {
                if (!mediaPlayer.isPlaying) {
                    handler.removeCallbacks(this)
                    return
                }
                if (!this@MdMediaControlsPlugin.isSeekInProgress) {
                    val time = mediaPlayer.currentPosition
                    channel.invokeMethod("audio.position", time)
                }
                handler.postDelayed(this, 100)
            } catch (error: Exception) {
                Log.w("player", "Handler error", error)
            }

        }
    }

    inner class HeadsetReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let {
                if (it.action ==  AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                    pause()
                }
            }
        }
    }
}

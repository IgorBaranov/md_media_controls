package com.example.mdmediacontrols

import android.app.PendingIntent
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
import java.lang.Exception
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat


class MdMediaControlsPlugin(Channel: MethodChannel, Registrar: Registrar) : MethodCallHandler {
    private var mediaPlayer = MediaPlayer()
    private val registrar: Registrar = Registrar
    private val channel: MethodChannel = Channel
    private val am: AudioManager
    private var isOnPlay = false
    private val handler = Handler()
    private val context: Context
    private val metadataBuilder = MediaMetadataCompat.Builder()
    private val stateBuilder: PlaybackStateCompat.Builder = PlaybackStateCompat.Builder().setActions(
        PlaybackStateCompat.ACTION_PLAY
        or PlaybackStateCompat.ACTION_STOP
        or PlaybackStateCompat.ACTION_PAUSE
        or PlaybackStateCompat.ACTION_PLAY_PAUSE
        or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)
    private var metadata: MediaMetadataCompat? = null

    private val mediaSession: MediaSessionCompat

    init {
        this.channel.setMethodCallHandler(this)
        this.context = this.registrar.context().applicationContext
        this.am = this.context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        this.mediaSession = MediaSessionCompat(this.context, "mdMediaService")

        mediaSession.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS)


        val activityIntent = Intent(this.context, MdMediaControlsPlugin.javaClass)

        mediaSession.setSessionActivity(
                PendingIntent.getActivity(this.context, 0, activityIntent, 0))

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

                this.mediaPlayer?.release()
                this.mediaPlayer = MediaPlayer()

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

                this.mediaPlayer.prepareAsync()

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    this.mediaPlayer.playbackParams = this.mediaPlayer.playbackParams.setSpeed(rate.toFloat())
                    this.channel.invokeMethod("audio.rate", rate.toFloat())
                }

                this.mediaPlayer.setOnPreparedListener {
                    it.start()
                    this.channel.invokeMethod("audio.play", null)
                    val duration = this.mediaPlayer.duration
                    this.channel.invokeMethod("audio.duration", duration / 1000)
                }

                this.mediaPlayer.setOnCompletionListener {
                    this.channel.invokeMethod("audio.completed", null)
                }

                this.mediaPlayer.setOnErrorListener { _, _, _ ->
                    channel.invokeMethod("error", "start play error")
                    true
                }
                this.isOnPlay = true
                handler.post(this.sendData)
                return result.success(true)
            }
            "pause" -> {
                if (this.mediaPlayer.isPlaying) {
                    this.mediaPlayer.pause()
                    this.channel.invokeMethod("audio.pause", null)
                }
                return result.success(true)
            }
            "playPrev" -> {
                this.mediaPlayer.start()
                this.channel.invokeMethod("audio.play", null)
                return result.success(true)
            }
            "seek" -> {
                val args = call.arguments as HashMap<*, *>
                val position = args.get("position") as Double
                this.mediaPlayer.seekTo(position.toInt() * 1000)
                return result.success(true)
            }
            "stop" -> {
                this.handler.removeCallbacks(this.sendData)
                this.mediaPlayer.release()
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
                val args = call.arguments as HashMap<*, *>
                val title = args.get("title") as String
                val artist = args.get("artist") as String
                val imageData = args.get("imageData") as String

                this.metadata = metadataBuilder
                        .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                        .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
                        .build()

                mediaSession.setMetadata(this.metadata)
                mediaSession.isActive = true

                mediaSession.setPlaybackState(
                        stateBuilder.setState(
                                PlaybackStateCompat.STATE_PLAYING,
                                PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN,
                                1.0F
                        ).build()
                )

                return result.success(true)
            }
            "clearInfo" -> {
                // TODO implement it
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
                }
                val time = mediaPlayer.currentPosition
                channel.invokeMethod("audio.position", time / 1000)
                handler.postDelayed(this, 200)
            } catch (error: Exception) {
                Log.w("player", "Handler error", error)
            }

        }
    }
}

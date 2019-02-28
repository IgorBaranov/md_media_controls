package com.example.mdmediacontrols

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

import android.media.AudioManager;
import android.media.MediaPlayer;

class MdMediaControlsPlugin(channel: MethodChannel, registrar: Registrar) : MethodCallHandler {
//    private var audioManager = AudioManager();
    private var mediaPlayer = MediaPlayer();

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "md_media_controls")
            channel.setMethodCallHandler(MdMediaControlsPlugin(channel, registrar));
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "play" -> {
                var args = call.arguments as HashMap<String, Any>;
                var isLocal = args.get("isLocal") as Boolean;
                var url = args.get("url") as String;
                var rate = args.get("rate") as Double;

            }
            "pause" -> {

            }
            "playPrev" -> {

            }
            "seek" -> {

            }
            "stop" -> {

            }
            "rate" -> {

            }
            "infoControls" -> {

            }
            "info" -> {

            }
            "clearInfo" -> {

            }
            else -> {
                result.notImplemented();
            }
        }
    }
}

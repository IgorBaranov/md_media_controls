import UIKit
import Flutter
import MediaPlayer
import AVFoundation

let player = AVPlayer();
var playerItemObserver: AnyObject?;
var playerItem: AVPlayerItem?;
var preventPositionChange = false;
let mediaInfo = MPNowPlayingInfoCenter.default();
var mediaControlsChannel: FlutterMethodChannel?;


public class SwiftMdMediaControlsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    mediaControlsChannel = FlutterMethodChannel(name: "md_media_controls", binaryMessenger: registrar.messenger())
    let instance = SwiftMdMediaControlsPlugin()
    
    let commandCenter = MPRemoteCommandCenter.shared()
    
    commandCenter.playCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
        if player.rate == 0.0 {
            mediaControlsChannel?.invokeMethod("audio.play", arguments: nil);
            player.play()
            return .success
        }
        return .commandFailed
    })
    
    
    commandCenter.pauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
        if player.rate == 1.0 {
            mediaControlsChannel?.invokeMethod("audio.pause", arguments: nil);
            player.pause()
            return .success
        }
        return .commandFailed
    }
    
    if #available(iOS 9.1, *) {
        commandCenter.changePlaybackPositionCommand.addTarget { (remoteEvent) -> MPRemoteCommandHandlerStatus in
            if let event = remoteEvent as? MPChangePlaybackPositionCommandEvent {
                preventPositionChange = true;
                player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: CMTimeScale(1000)), completionHandler: {_ in
                    preventPositionChange = false;
                });
                return .success;
            }
            return .commandFailed;
        }
    }
    
    commandCenter.nextTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
        mediaControlsChannel?.invokeMethod("audio.controls.next", arguments: nil);
        return .success;
    }
    
    commandCenter.previousTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
        mediaControlsChannel?.invokeMethod("audio.controls.prev", arguments: nil);
        return .success;
    }
    
    player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.01, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) {
        time in
        if !preventPositionChange, let tt = playerItem {
            mediaInfo.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime]  = tt.currentTime().seconds;
        }
    }
    
    player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) {
        time in
        if let tt = playerItem {
            mediaControlsChannel?.invokeMethod("audio.position", arguments: Int(tt.currentTime().seconds));
        }
    }
    
    registrar.addMethodCallDelegate(instance, channel: mediaControlsChannel!)
  }
  
  public func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "play":
        mediaControlsChannel?.invokeMethod("audio.prepare", arguments: nil)
        
        let args = (call.arguments as! NSDictionary);
        let urlString = args.object(forKey: "url") as! String;
        
        playerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!);
        
        if let tt = playerItemObserver {
            tt.invalidate();
        }
        
        playerItemObserver = playerItem?.observe(\.status, options: [.new, .old], changeHandler: { (playerItem, change) in
            if (playerItem.status == .readyToPlay && !playerItem.duration.seconds.isNaN) {
                mediaControlsChannel?.invokeMethod("audio.duration", arguments: Int(playerItem.duration.seconds));
            }
        });
        
        if #available(iOS 10.0, *) {
            mediaInfo.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds;
            mediaInfo.nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds;
            mediaInfo.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = player.rate;
        }
        
        player.replaceCurrentItem(with: playerItem);
        
        if #available(iOS 10.0, *) {
            player.playImmediately(atRate: 1)
        } else {
            player.play();
        };
        
        mediaControlsChannel?.invokeMethod("audio.duration", arguments: playerItem?.duration.seconds)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: []);
            try AVAudioSession.sharedInstance().setActive(true);
            UIApplication.shared.beginReceivingRemoteControlEvents();
            mediaControlsChannel?.invokeMethod("audio.play", arguments: nil);
        } catch let error {
            mediaControlsChannel?.invokeMethod("error", arguments: error.localizedDescription);
            return result(false);
        }
        return result(true);
    case "pause":
        player.pause();
        mediaControlsChannel?.invokeMethod("audio.pause", arguments: nil);
        return result(true);
    case "seek":
        let args = (call.arguments as! NSDictionary);
        let position = args.object(forKey: "position") as! Double;
        
        if let tt = playerItem {
            tt.seek(to: CMTimeMakeWithSeconds(position, 60000));
        }
        if (player.rate == 0.0) {
            player.play();
        }
        return result(true);
    case "stop":
        player.pause();
        player.replaceCurrentItem(with: nil);
        return result(true);
        
    case "info":
        let args = (call.arguments as! NSDictionary);
        
        if let title = args.value(forKey: "title") {
            mediaInfo.nowPlayingInfo?[MPMediaItemPropertyTitle] = title as! String;
        }
        
        if let artist = args.value(forKey: "artist") {
            mediaInfo.nowPlayingInfo?[MPMediaItemPropertyArtist] = artist as! String;
        }
        if #available(iOS 10.0, *) {
            if let imageUrl = args.value(forKey: "imageData") {
                if ((imageUrl as! String).count > 0) {
//                    
//                    if let image = UIImage(named: "lockscreen") {
//                        mediaInfo.nowPlayingInfo?[MPMediaItemPropertyArtwork] =
//                            MPMediaItemArtwork(boundsSize: image.size) { size in
//                                return image;
//                        }
//                    }
                }
            }
        }
        
        
        return result(true);
    default:
        result(FlutterMethodNotImplemented)
    }
  }
}

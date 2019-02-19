import UIKit
import Flutter
import MediaPlayer
import AVFoundation

let player = AVPlayer();
var playerItemObserver: Any?;
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
    } else {
        // Fallback on earlier versions
    }
    
    commandCenter.nextTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
        mediaControlsChannel?.invokeMethod("audio.controls.next", arguments: nil);
        return .success;
    }
    
    commandCenter.previousTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
        mediaControlsChannel?.invokeMethod("audio.controls.prev", arguments: nil);
        return .success;
    }
    
    let interval = CMTime(seconds: 0.5,
                          preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    
    player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) {
        time in
        if let tt = playerItem {
            mediaControlsChannel?.invokeMethod("audio.position", arguments: Int(tt.currentTime().seconds));
            if !preventPositionChange {
                mediaInfo.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime]  = tt.currentTime().seconds;
            }
        }
    }
    
    registrar.addMethodCallDelegate(instance, channel: mediaControlsChannel!)
  }
    
  @available(iOS 10.0, *)
  public class func setupNowPlaying(playerItem: AVPlayerItem, player: AVPlayer) -> [String : Any] {
        // Define Now Playing Info
     var nowPlayingInfo = [String : Any]()
     nowPlayingInfo[MPMediaItemPropertyTitle] = "My title";
     nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
     nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.asset.duration.seconds
     nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        
        // Set the metadata
    return nowPlayingInfo;
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
        mediaControlsChannel?.invokeMethod("audio.prepare", arguments: nil)
        
        let args = (call.arguments as! NSDictionary);
        let urlString = args.object(forKey: "url") as! String;
        
        playerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!);
        
        if let tt = playerItemObserver {
            (tt as AnyObject).invalidate();
        }
        
        playerItemObserver = playerItem?.observe(\.status, options: [.new, .old], changeHandler: { (playerItem, change) in
            if (playerItem.status == .readyToPlay && !playerItem.duration.seconds.isNaN) {
                mediaControlsChannel?.invokeMethod("audio.duration", arguments: Int(playerItem.duration.seconds));
            }
        });
        
        if let tt = playerItem {
            if #available(iOS 10.0, *) {
                mediaInfo.nowPlayingInfo = SwiftMdMediaControlsPlugin.setupNowPlaying(playerItem: tt, player: player)
            } else {
                // Fallback on earlier versions
            };
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
        return result(true);
    default:
        result(FlutterMethodNotImplemented)
    }
  }
}

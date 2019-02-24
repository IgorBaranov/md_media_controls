import UIKit
import Flutter
import MediaPlayer
import AVFoundation

let player = AVPlayer();
var playerItemObserver: AnyObject?;
var playerItem: AVPlayerItem?;
var preventPositionChange = false;
var mediaControlsChannel: FlutterMethodChannel?;
var playerObserver: AnyObject?;

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
            func addPlayerObserver() {
                UIApplication.shared.beginReceivingRemoteControlEvents();
                let mediaInfo = MPNowPlayingInfoCenter.default();
                playerObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) {
                    time in
                    if let tt = playerItem {
                        mediaControlsChannel?.invokeMethod("audio.position", arguments: Int(tt.currentTime().seconds));
                        mediaInfo.nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime]  = tt.currentTime().seconds;
                    }
                    } as AnyObject
            }
            
            func removePlayerObserver() {
                if let observer = playerItemObserver {
                    UIApplication.shared.beginIgnoringInteractionEvents();
                    print(observer);
                    player.removeTimeObserver(observer);
                    playerItemObserver = nil;
                }
            }
            
            commandCenter.changePlaybackPositionCommand.addTarget { (remoteEvent) -> MPRemoteCommandHandlerStatus in
                if let event = remoteEvent as? MPChangePlaybackPositionCommandEvent {
                    removePlayerObserver();
                    player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: CMTimeScale(1000)), completionHandler: {_ in
                        addPlayerObserver()
                    });
                    return .success;
                }
                return .commandFailed;
            }
            
            addPlayerObserver();
        }
        
        commandCenter.nextTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            mediaControlsChannel?.invokeMethod("audio.controls.next", arguments: nil);
            return .success;
        }
        
        commandCenter.previousTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            mediaControlsChannel?.invokeMethod("audio.controls.prev", arguments: nil);
            return .success;
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
            
            let mediaInfo = MPNowPlayingInfoCenter.default();
            if mediaInfo.nowPlayingInfo != nil {
                mediaInfo.nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds;
                mediaInfo.nowPlayingInfo![MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds;
                mediaInfo.nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = player.rate;
            } else {
                var newInfo = [String: Any]();
                newInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds;
                newInfo[MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds;
                newInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate;
                mediaInfo.nowPlayingInfo = newInfo;
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
            let mediaInfo = MPNowPlayingInfoCenter.default();
            if mediaInfo.nowPlayingInfo == nil {
                mediaInfo.nowPlayingInfo = [String: Any]();
            }
            
            if let title = args.value(forKey: "title") {
                mediaInfo.nowPlayingInfo?[MPMediaItemPropertyTitle] = title as! String;
            }
            
            if let artist = args.value(forKey: "artist") {
                mediaInfo.nowPlayingInfo?[MPMediaItemPropertyArtist] = artist as! String;
            }
            if #available(iOS 10.0, *) {
                if let imageData = args.value(forKey: "imageData") {
                    if ((imageData as! String).count > 0) {
                        if let isLocal = args.value(forKey: "isLocal") {
                            if (isLocal as! Int == 1) {
                                do {
                                    let data = try Data(contentsOf: URL(string: imageData as! String)!);
                                    if let image = UIImage(data: data) {
                                        mediaInfo.nowPlayingInfo?[MPMediaItemPropertyArtwork] =
                                            MPMediaItemArtwork(boundsSize: image.size) { size in
                                                return image;
                                        }
                                    }
                                } catch {
                                    // TODO add error handler
                                }
                            } else {
                                if let data = Data(base64Encoded: imageData as! String) {
                                    if let image = UIImage(data: data) {
                                        mediaInfo.nowPlayingInfo?[MPMediaItemPropertyArtwork] =
                                            MPMediaItemArtwork(boundsSize: image.size) { size in
                                                return image;
                                        }
                                    }
                                }
                            }

                        }
                    }
                }
            }
            
            
            return result(true);
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

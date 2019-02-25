import UIKit
import Flutter
import MediaPlayer
import AVFoundation
import CoreFoundation

let player = AVPlayer();
var playerItemObserver: AnyObject?;
var playerItem: AVPlayerItem?;
var preventPositionChange = false;
var mediaControlsChannel: FlutterMethodChannel?;
var mediaInfoData = [String: Any]();
var registrarTemp: FlutterPluginRegistrar?;

public class SwiftMdMediaControlsPlugin: NSObject, FlutterPlugin {
    var registrar: FlutterPluginRegistrar;
    
    init(pluginRegistrar: FlutterPluginRegistrar) {
        registrar = pluginRegistrar;
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        mediaControlsChannel = FlutterMethodChannel(name: "md_media_controls", binaryMessenger: registrar.messenger())
        let instance = SwiftMdMediaControlsPlugin(pluginRegistrar: registrar);
        
        let commandCenter = MPRemoteCommandCenter.shared();
        
        commandCenter.playCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            if player.rate == 0.0 {
                mediaControlsChannel?.invokeMethod("audio.play", arguments: nil);
                player.play();
                return .success
            }
            return .commandFailed
        })
        
        
        commandCenter.pauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            if player.rate > 0.0 {
                mediaControlsChannel?.invokeMethod("audio.pause", arguments: nil);
                player.pause()
                return .success
            }
            return .commandFailed
        }
        
        if #available(iOS 9.1, *) {
            UIApplication.shared.beginReceivingRemoteControlEvents();
            player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) {
                time in
                if let tt = playerItem {
                    let currentTime = tt.currentTime().seconds;
                    mediaControlsChannel?.invokeMethod("audio.position", arguments: Int(currentTime));
                    mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime]  = currentTime;
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                }
            }
            
            commandCenter.changePlaybackPositionCommand.addTarget { (remoteEvent) -> MPRemoteCommandHandlerStatus in
                if let event = remoteEvent as? MPChangePlaybackPositionCommandEvent {
                    player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: CMTimeScale(1000)), completionHandler: {_ in
                        if let tt = playerItem {
                            mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime]  = tt.currentTime().seconds;
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                        }
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
            
            player.replaceCurrentItem(with: playerItem);
            
            UIApplication.shared.beginReceivingRemoteControlEvents();
            mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds;
            mediaInfoData[MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds;
            mediaInfoData[MPNowPlayingInfoPropertyPlaybackRate] = player.rate;
            
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: 1)
            } else {
                player.play();
            };
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
            mediaControlsChannel?.invokeMethod("audio.rate", arguments: 1.0)
            mediaControlsChannel?.invokeMethod("audio.duration", arguments: playerItem?.duration.seconds)
            
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: []);
                try AVAudioSession.sharedInstance().setActive(true);
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
        case "playPrev":
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: player.rate);
            } else {
                player.play();
            }
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
            UIApplication.shared.endReceivingRemoteControlEvents();
            return result(true);
        case "rate":
            let args = (call.arguments as! NSDictionary);
            let rate = args.object(forKey: "rate") as! Double;
            player.rate = Float(rate);
            mediaControlsChannel?.invokeMethod("audio.rate", arguments: rate)
            return result(true);
        case "info":
            let args = (call.arguments as! NSDictionary);
            UIApplication.shared.beginReceivingRemoteControlEvents();
           
            if let title = args.value(forKey: "title") {
                mediaInfoData[MPMediaItemPropertyTitle] = title as! String;
            }
            
            if let artist = args.value(forKey: "artist") {
                mediaInfoData[MPMediaItemPropertyArtist] = artist as! String;
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
            if #available(iOS 10.0, *) {
                if let imageData = args.value(forKey: "imageData") {
                    if ((imageData as! String).count > 0) {
                        var data: Data;
                        if let isLocal = args.value(forKey: "isLocal") {
                            if (isLocal as! Int == 1) {
                                let key = self.registrar.lookupKey(forAsset: imageData as! String);
                                let path = Bundle.main.path(forAuxiliaryExecutable: key);
                                if let image = UIImage(contentsOfFile: path!) {
                                    mediaInfoData[MPMediaItemPropertyArtwork] =
                                        MPMediaItemArtwork(boundsSize: image.size) { size in
                                            return image;
                                    }
                                    MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                                }
                            } else {
                                do {
                                    data = try Data(contentsOf: URL(string: imageData as! String)!);
                                    if let image = UIImage(data: data) {
                                        mediaInfoData[MPMediaItemPropertyArtwork] =
                                            MPMediaItemArtwork(boundsSize: image.size) { size in
                                                return image;
                                        }
                                        MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                                    }
                                } catch {
                                    return result(true);
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

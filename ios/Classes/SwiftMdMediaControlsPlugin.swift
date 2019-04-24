import UIKit
import Flutter
import MediaPlayer
import AVFoundation
import CoreFoundation

let player = AVPlayer();
var playerItemObserver: AnyObject?;
var playerItem: AVPlayerItem?;
var mediaInfoData = [String: Any]();

public class SwiftMdMediaControlsPlugin: NSObject, FlutterPlugin {
    var registrar: FlutterPluginRegistrar;
    var currentRate: Double = 0.0;
    var channel: FlutterMethodChannel;
    
    init(pluginRegistrar: FlutterPluginRegistrar, pluginChannel: FlutterMethodChannel) {
        registrar = pluginRegistrar;
        channel = pluginChannel;
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let mediaControlsChannel = FlutterMethodChannel(name: "md_media_controls", binaryMessenger: registrar.messenger())
        let instance = SwiftMdMediaControlsPlugin(pluginRegistrar: registrar, pluginChannel: mediaControlsChannel);
        
        let commandCenter = MPRemoteCommandCenter.shared();
        
        commandCenter.playCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            if player.rate == 0.0 {
                player.play();
                mediaControlsChannel.invokeMethod("audio.play", arguments: nil);
                return .success
            }
            return .commandFailed
        })
        
        
        commandCenter.pauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            if player.rate > 0.0 {
                player.pause();
                mediaControlsChannel.invokeMethod("audio.pause", arguments: nil);
                return .success
            }
            return .commandFailed
        }
        
        if #available(iOS 9.1, *) {
            UIApplication.shared.beginReceivingRemoteControlEvents();
            player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.1, Int32(NSEC_PER_SEC)), queue: nil) {
                time in
                if let tt = playerItem {
                    let currentTime = tt.currentTime().seconds;
                    mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime]  = currentTime;
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                    mediaControlsChannel.invokeMethod("audio.position", arguments: Int(currentTime * 1000));
                }
            }
            
            commandCenter.changePlaybackPositionCommand.addTarget { (remoteEvent) -> MPRemoteCommandHandlerStatus in
                if let event = remoteEvent as? MPChangePlaybackPositionCommandEvent {
                    mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(event.positionTime);
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                    player.seek(to: CMTimeMake(Int64(event.positionTime), 1));
                    return .success;
                }
                return .commandFailed;
            }
        }
        
        commandCenter.nextTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            mediaControlsChannel.invokeMethod("audio.controls.next", arguments: nil);
            return .success;
        }
        
        commandCenter.previousTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            mediaControlsChannel.invokeMethod("audio.controls.prev", arguments: nil);
            return .success;
        }
        
        registrar.addMethodCallDelegate(instance, channel: mediaControlsChannel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "play":
            self.channel.invokeMethod("audio.prepare", arguments: nil)
            
            let args = (call.arguments as! NSDictionary);
            let urlString = args.object(forKey: "url") as! String;
            if let range = urlString.range(of: "assets") {
                let position = urlString.distance(from: urlString.startIndex, to: range.lowerBound);
                if (position == 1 || position == 0) {
                    let asset = self.registrar.lookupKey(forAsset: urlString);
                    let path = Bundle.main.path(forAuxiliaryExecutable: asset);
                    playerItem = AVPlayerItem(url: URL(fileURLWithPath: path!));
                } else {
                    playerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!);
                }
            } else {
                playerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!);
            }
            
            
            
            
            NotificationCenter.default.removeObserver(self)
            
            if let tt = playerItemObserver {
                tt.invalidate();
            }
            
            playerItemObserver = playerItem?.observe(\.status, options: [.new, .old], changeHandler: { (playerItem, change) in
                if (playerItem.status == .readyToPlay && !playerItem.duration.seconds.isNaN) {
                    self.channel.invokeMethod("audio.duration", arguments: Int(playerItem.duration.seconds));
                }
            });
            
            NotificationCenter.default.addObserver(self, selector:#selector(self.playerDidFinishPlaying(note:)),name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem);
            
            player.replaceCurrentItem(with: playerItem);
            let rate = args.object(forKey: "rate") as! Double;
            player.rate = Float(rate);
            self.currentRate = rate;
            UIApplication.shared.beginReceivingRemoteControlEvents();
            mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds;
            mediaInfoData[MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds;
            mediaInfoData[MPNowPlayingInfoPropertyPlaybackRate] = player.rate;
            
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: Float(rate))
            } else {
                player.play();
            };
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
            self.channel.invokeMethod("audio.rate", arguments: 1.0)
            self.channel.invokeMethod("audio.duration", arguments: playerItem?.duration.seconds)
            
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: []);
                try AVAudioSession.sharedInstance().setActive(true);
                self.channel.invokeMethod("audio.play", arguments: nil);
            } catch let error {
                print(error);
                self.channel.invokeMethod("error", arguments: error.localizedDescription);
                return result(false);
            }
            return result(true);
        case "pause":
            player.pause();
            self.channel.invokeMethod("audio.pause", arguments: nil);
            return result(true);
        case "playPrev":
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: Float(self.currentRate));
            } else {
                player.play();
            }
            self.channel.invokeMethod("audio.play", arguments: nil);
            return result(true);
        case "seek":
            let args = (call.arguments as! NSDictionary);
            let position = args.object(forKey: "position") as! Double;
            
            if let tt = playerItem {
                tt.seek(to: CMTimeMakeWithSeconds(position, 60000));
            }
            if (player.rate == 0.0) {
                if #available(iOS 10.0, *) {
                    player.playImmediately(atRate: Float(self.currentRate))
                } else {
                    player.play();
                };
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
            self.currentRate = Double(player.rate);
            self.channel.invokeMethod("audio.rate", arguments: rate)
            return result(true);
        case "infoControls":
            let args = (call.arguments as! NSDictionary);
            let commandCenter = MPRemoteCommandCenter.shared();
            commandCenter.playCommand.isEnabled = args.object(forKey: "play") as! Int == 1;
            commandCenter.pauseCommand.isEnabled = args.object(forKey: "pause") as! Int == 1;
            commandCenter.previousTrackCommand.isEnabled = args.object(forKey: "prev") as! Int == 1;
            commandCenter.nextTrackCommand.isEnabled = args.object(forKey: "next") as! Int == 1;
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
            result(true);
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
                                    // TODO add error handler
                                }
                            }
                        }
                    }
                }
            }
            break;
        case "clearInfo":
            mediaInfoData = [String: Any]();
            MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
            return result(true);
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    @objc func playerDidFinishPlaying(note: NSNotification){
        channel.invokeMethod("audio.completed", arguments: nil)
    }
}

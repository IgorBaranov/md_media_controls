import UIKit
import Flutter
import MediaPlayer
import AVFoundation
import CoreFoundation


let uncontrolledPlayer = AVPlayer();
var uncontrolledPlayerItem: AVPlayerItem?;
let player = AVPlayer();
var playerItemObserver: AnyObject?;
var playerTimeObserver: Any?;
var playerItem: AVPlayerItem?;
var mediaInfoData = [String: Any]();
var seekInProgress = false;

public class SwiftMdMediaControlsPlugin: NSObject, FlutterPlugin {
    var registrar: FlutterPluginRegistrar;
    var currentRate: Double = 0.0;
    var channel: FlutterMethodChannel;
    var lastProgressTime = 0
    var lastSeekTime : CMTime? = nil
    var lastTimeRangeDuration = 0


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
            playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.1, Int32(NSEC_PER_SEC)), queue: nil) {
                time in
                if (!seekInProgress) {
                    if let tt = playerItem {
                        if (tt.status == .readyToPlay) {
                            let currentTime = CMTimeGetSeconds(tt.currentTime());
                            mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime]  = currentTime;
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                            mediaControlsChannel.invokeMethod("audio.position", arguments: Int(currentTime * 1000));
                        }
                    }
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
            seekInProgress = false
            lastProgressTime = 0
            lastSeekTime = nil
            self.channel.invokeMethod("audio.prepare", arguments: nil)

            NotificationCenter.default.removeObserver(self)

            if let tt = playerItemObserver {
                tt.invalidate()
            }

            let args = (call.arguments as! NSDictionary)
            let urlString = args.object(forKey: "url") as! String
            let startPosition = args.object(forKey: "startPosition") as! Double
            let autoPlay = args.object(forKey: "autoPlay") as! Bool
            if let range = urlString.range(of: "assets") {
                let position = urlString.distance(from: urlString.startIndex, to: range.lowerBound)
                if (position == 1 || position == 0) {
                    let asset = self.registrar.lookupKey(forAsset: urlString)
                    let path = Bundle.main.path(forAuxiliaryExecutable: asset)
                    playerItem = AVPlayerItem(url: URL(fileURLWithPath: path!))
                } else {
                    playerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!)
                }
            } else {
                playerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!)
            }
            playerItem?.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithm.varispeed

            playerItemObserver = playerItem?.observe(\.status, options: [.new, .old], changeHandler: { [weak self] (playerItem, change) in
                if (playerItem.loadedTimeRanges.count == 0) {
                    return;
                }

                let timeRange = playerItem.loadedTimeRanges[0].timeRangeValue
                let duration = CMTimeGetSeconds(timeRange.duration)
                if (startPosition != 0.0) {
                    seekInProgress = true
                    self?.stopAppTimeObserver()

                    let seekTime = CMTimeMakeWithSeconds(startPosition, 1000)
                    playerItem.seek(to: seekTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self]
                        (_: Bool) -> Void in

                        if let selfObjec = self {
                            seekInProgress = false
                            selfObjec.lastSeekTime = seekTime
                            selfObjec.startAppTimeObserver(channel: selfObjec.channel)
                            let currentTime = CMTimeGetSeconds(playerItem.currentTime())
                            selfObjec.channel.invokeMethod("audio.position", arguments: Int(currentTime * 1000))
                        }
                    });
                } else {
                    if let selfObject = self {
                        selfObject.stopAppTimeObserver()
                        let seekTime = CMTimeMakeWithSeconds(startPosition, 1000)
                        selfObject.lastSeekTime = seekTime
                        selfObject.startAppTimeObserver(channel: selfObject.channel)
                        selfObject.channel.invokeMethod("audio.position", arguments: 0)
                    }
                }
                self?.lastTimeRangeDuration = Int(duration)
                self?.channel.invokeMethod("audio.duration", arguments: Int(duration))
            });

            NotificationCenter.default.addObserver(self, selector:#selector(self.playerDidFinishPlaying), name:NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
            NotificationCenter.default.addObserver(self, selector:#selector(self.handleInterruption(notification:)), name:NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
            NotificationCenter.default.addObserver(self, selector:#selector(self.audioRouteChanged), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)


            player.replaceCurrentItem(with: playerItem)
            let rate = args.object(forKey: "rate") as! Double
            if (autoPlay) {
                player.rate = Float(rate)
            }
            self.currentRate = rate
            UIApplication.shared.beginReceivingRemoteControlEvents()
            mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem?.currentTime().seconds
            mediaInfoData[MPMediaItemPropertyPlaybackDuration] = playerItem?.asset.duration.seconds
            mediaInfoData[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

            if (autoPlay) {
                if #available(iOS 10.0, *) {
                    player.playImmediately(atRate: Float(rate))
                } else {
                    player.play()
                };
            }

            MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData
            self.channel.invokeMethod("audio.rate", arguments: 1.0)

            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [])
                try AVAudioSession.sharedInstance().setActive(true)
                if (autoPlay) {
                    self.channel.invokeMethod("audio.play", arguments: nil)
                } else {
                    self.channel.invokeMethod("audio.pause", arguments: nil)
                }
            } catch let error {
                print(error)
                self.channel.invokeMethod("error", arguments: error.localizedDescription)
                return result(false)
            }
            return result(true)
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
            if (seekInProgress) {return result(false);}

            seekInProgress = true;
            self.stopAppTimeObserver();
            let args = (call.arguments as! NSDictionary);
            let position = args.object(forKey: "position") as! Double;
            let play = args.object(forKey: "play") as! Bool;

            if let tt = playerItem {
                let seekTime = CMTimeMakeWithSeconds(position, 1000)
                tt.seek(to: seekTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self]
                    (_: Bool) -> Void in

                    if let selfObject = self {
                        selfObject.lastSeekTime = seekTime
                        selfObject.startAppTimeObserver(channel: selfObject.channel);
                        seekInProgress = false;
                        let currentTime = CMTimeGetSeconds(tt.currentTime());
                        selfObject.channel.invokeMethod("audio.position", arguments: Int(currentTime * 1000));
                    }
                });
            }
            if (play) {
                player.rate = 1.0;
                self.currentRate = 1.0;
                self.channel.invokeMethod("audio.play", arguments: nil);
            } else {
                self.currentRate = 1.0;
                player.pause();
                self.channel.invokeMethod("audio.pause", arguments: nil);
            }
            self.channel.invokeMethod("audio.rate", arguments: Float(self.currentRate));
            return result(true);
        case "stop":
            lastProgressTime = 0
            player.pause()
            player.replaceCurrentItem(with: nil)
            UIApplication.shared.endReceivingRemoteControlEvents()
            return result(true)
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
            if #available(iOS 9.1, *) {
                commandCenter.changePlaybackPositionCommand.isEnabled = args.object(forKey: "position") as! Int == 1
            }
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
        case "playUncontrolled":
            let args = (call.arguments as! NSDictionary);
            let urlString = args.object(forKey: "url") as! String;
            if let range = urlString.range(of: "assets") {
                let position = urlString.distance(from: urlString.startIndex, to: range.lowerBound);
                if (position == 1 || position == 0) {
                    let asset = self.registrar.lookupKey(forAsset: urlString);
                    let path = Bundle.main.path(forAuxiliaryExecutable: asset);
                    uncontrolledPlayerItem = AVPlayerItem(url: URL(fileURLWithPath: path!));
                } else {
                    uncontrolledPlayerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!);
                }
            } else {
                uncontrolledPlayerItem = AVPlayerItem(url: args.object(forKey: "isLocal") as! Int == 1 ? URL(fileURLWithPath: urlString) : URL(string: urlString)!);
            }


            uncontrolledPlayer.replaceCurrentItem(with: uncontrolledPlayerItem);
            let rate = args.object(forKey: "rate") as! Double;
            uncontrolledPlayer.rate = Float(rate);

            if #available(iOS 10.0, *) {
                uncontrolledPlayer.playImmediately(atRate: Float(rate))
            } else {
                uncontrolledPlayer.play();
            };

            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error {
                print(error)
                self.channel.invokeMethod("error", arguments: error.localizedDescription)
                return result(false)
            }

            return result(true);
        case "stopUncontrolled":
            uncontrolledPlayer.rate = 0;
            return result(true);
        default:
            result(FlutterMethodNotImplemented)
        }
    }


    @objc func handleInterruption(notification: NSNotification) {
        guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSessionInterruptionType(rawValue: typeValue) else {
                return
        }

        if type == .began {
            player.pause();
            channel.invokeMethod("audio.pause", arguments: nil);
        } else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSessionInterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                if #available(iOS 10.0, *) {
                    player.playImmediately(atRate: Float(self.currentRate));
                } else {
                    player.play();
                }
                channel.invokeMethod("audio.play", arguments: nil);
            }
        }
    }

    @objc func audioRouteChanged(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                let wasHeadphonesConnected = isHeadphones(in: previousRoute)
                if (wasHeadphonesConnected) {
                    channel.invokeMethod("audio.pause", arguments: nil)
                }
            }
        }
    }

    func isHeadphones(in routeDescription: AVAudioSessionRouteDescription) -> Bool {
        return !routeDescription.outputs.filter({$0.portType == AVAudioSessionPortHeadphones}).isEmpty
    }

    @objc func playerDidFinishPlaying(note: NSNotification) {
        channel.invokeMethod("audio.completed", arguments: nil)
        channel.invokeMethod("audio.stop", arguments: nil)
    }

    @objc func startAppTimeObserver(channel: FlutterMethodChannel) {
        lastProgressTime = 0
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.05, Int32(NSEC_PER_SEC)), queue: nil) { [weak self]
            time in

            if let item = playerItem {
                if (!item.loadedTimeRanges.isEmpty) {
                    let timeRange = item.loadedTimeRanges[0].timeRangeValue
                    let duration = Int(CMTimeGetSeconds(timeRange.duration))
                    let lastDuration = self?.lastTimeRangeDuration ?? 0
                    if (duration != lastDuration) {
                        self?.lastTimeRangeDuration = duration
                        self?.channel.invokeMethod("audio.duration", arguments: duration)
                    }
                }
            }

            let lastSeek = self?.lastSeekTime ?? time
            if (!seekInProgress && CMTimeCompare(lastSeek, time) <= 0) {
                if let tt = playerItem {
                    if (tt.status == .readyToPlay) {
                        let currentTime = CMTimeGetSeconds(tt.currentTime());
                        mediaInfoData[MPNowPlayingInfoPropertyElapsedPlaybackTime]  = currentTime;
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = mediaInfoData;
                        let timeMs = Int(currentTime * 1000)
                        if (timeMs >= self?.lastProgressTime ?? 0) {
                            self?.lastProgressTime = timeMs
                            channel.invokeMethod("audio.position", arguments: timeMs);
                        }
                    }
                }
            }
        }
    }

    @objc func stopAppTimeObserver() {
        if let tt = playerTimeObserver {
            lastProgressTime = 0
            player.removeTimeObserver(tt);
            playerTimeObserver = nil;
        }
    }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

enum ControlsState {
  STOPPED,
  PLAYING,
  PAUSED,
  PREPARE,
  COMPLETED,
  ERROR
}

enum ControlsActions {
  PREV,
  NEXT
}

const MethodChannel _CHANNEL = const MethodChannel('md_media_controls');

const _protocols = [ 'http', 'https', 'ftp'];


class MdMediaControls {

  Duration _duration = Duration();

  final StreamController<
      ControlsState> _playerStateController = StreamController.broadcast();

  final StreamController<double> _playerRateController = StreamController.broadcast();

  final StreamController<Duration> _positionController = StreamController
      .broadcast();

  final StreamController<ControlsActions> _controlsController = StreamController
      .broadcast();

  ControlsState _state = ControlsState.STOPPED;

  ControlsState get state => _state;

  Duration get duration => _duration;

  Stream<ControlsState> get onPlayerStateChanged =>
      _playerStateController.stream;

  Stream<Duration> get positionChanged => _positionController.stream;

  Stream<ControlsActions> get onControlsFired => _controlsController.stream;

  Stream<double> get onRateChanged => _playerRateController.stream;

  MdMediaControls() {
    _CHANNEL.setMethodCallHandler(_channelMethodHandler);
  }

  Future<void> _channelMethodHandler(MethodCall call) async {
    switch (call.method) {
      case 'audio.prepare':
        _playerStateController.add(ControlsState.PREPARE);
        _state = ControlsState.PREPARE;
        break;
      case 'audio.duration':
        _duration = Duration(seconds: call.arguments);
        break;
      case 'audio.position':
        _positionController.add(Duration(milliseconds: call.arguments));
        break;
      case 'audio.play':
        _playerStateController.add(ControlsState.PLAYING);
        _state = ControlsState.PLAYING;
        break;
      case 'audio.stop':
        _playerStateController.add(ControlsState.STOPPED);
        _state = ControlsState.STOPPED;
        break;
      case 'audio.completed':
        _playerStateController.add(ControlsState.COMPLETED);
        _state = ControlsState.COMPLETED;
        break;
      case 'audio.pause':
        _playerStateController.add(ControlsState.PAUSED);
        _state = ControlsState.PAUSED;
        break;
      case 'audio.rate':
        _playerRateController.add(call.arguments);
        break;
      case 'audio.controls.next':
        _controlsController.add(ControlsActions.NEXT);
        break;
      case 'audio.controls.prev':
        _controlsController.add(ControlsActions.PREV);
        break;
      case 'error':
        _playerStateController.addError(call.arguments);
        _state = ControlsState.ERROR;
        break;
      default:
        throw new ArgumentError('Unknown method ${call.method}');
    }
  }

  Future<void> playNew({@required String url, double rate = 1.0, double startPosition = 0.0, bool autoPlay = true}) async =>
      await _CHANNEL.invokeMethod('play', {
        'url': url,
        'isLocal': !_protocols.contains(url.split('://').first),
        'rate': rate ?? 1.0,
        'startPosition': startPosition ?? 0.0,
        'autoPlay': autoPlay
      });

  Future<void> playUncontrolled({@required String url, rate = 1.0}) async =>
      await _CHANNEL.invokeMethod('playUncontrolled', {
        'url': url,
        'isLocal': !_protocols.contains(url.split('://').first),
        'rate': rate
      });

  Future<void> play() async =>
      await _CHANNEL.invokeMethod('playPrev');

  Future<void> pause() async => await _CHANNEL.invokeMethod('pause');

  Future<void> stop() async => await _CHANNEL.invokeMethod('stop');

  Future<void> seek(double seconds, {bool play = true}) async =>
      await _CHANNEL.invokeMethod('seek', {'position': seconds, 'play': play});

  Future<void> rate({double rate = 0.0}) async =>
      await _CHANNEL.invokeMethod('rate', {'rate': rate});

  Future<void> setInfo({
    @required String title,
    @required String artist,
    @required String imageUrl,
  }) async {
    var isLocal = true;
    if (imageUrl != null && _protocols.contains(imageUrl.split('://').first)) {
      isLocal = false;
    }
    return await _CHANNEL.invokeMethod('info', {
      'title': title,
      'artist': artist,
      'imageData': imageUrl,
      'isLocal': isLocal
    });
  }

  Future<void> infoControls({
    bool pause = true,
    bool play = true,
    bool prev = true,
    bool next = true,
    bool position = true
  }) async => await _CHANNEL.invokeMethod('infoControls', {
    'pause': pause,
    'play': play,
    'prev': prev,
    'next': next,
    'position': position
  });

  Future<void> clearInfo() async => await _CHANNEL.invokeMethod('clearInfo');

}

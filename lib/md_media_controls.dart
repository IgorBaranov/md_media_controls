import 'dart:async';
import 'dart:io';
import 'dart:convert' show utf8, base64;

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

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

  final StreamController<Duration> _positionController = StreamController
      .broadcast();

  final StreamController<ControlsActions> _controlsController = StreamController
      .broadcast();

  ControlsState _state = ControlsState.STOPPED;

  Duration get duration => _duration;

  Stream<ControlsState> get onPlayerStateChanged =>
      _playerStateController.stream;

  Stream<Duration> get positionChanged => _positionController.stream;

  Stream<ControlsActions> get onControlsFired => _controlsController.stream;


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
        _positionController.add(Duration(seconds: 0));
        break;
      case 'audio.position':
        _positionController.add(Duration(seconds: call.arguments));
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

  Future<void> play({@required String url}) async =>
      await _CHANNEL.invokeMethod('play', {
        'url': url,
        'isLocal': !_protocols.contains(url.split('://').first)
      });

  Future<void> pause() async => await _CHANNEL.invokeMethod('pause');

  Future<void> stop() async => await _CHANNEL.invokeMethod('stop');

  Future<void> seek(double seconds) async =>
      await _CHANNEL.invokeMethod('seek', {'position': seconds});

  Future<void> setInfo({
    @required String title,
    @required String artist,
    @required String imageUrl,
  }) async {
    var fileData = '';
    if (imageUrl != null) {
      if (_protocols.contains(imageUrl.split('://').first)) {
        final url = Uri.parse(imageUrl);
        final httpClient = HttpClient();
        try {
          final HttpClientRequest request = await httpClient.getUrl(url);
          final HttpClientResponse response = await request.close();
          await fileStreamToBase64(response);
        } catch (e) {
          httpClient.close(force: true);
        }
      } else {
        try {
          final ByteData bytes = await rootBundle.load(imageUrl);
          final path = await getTemporaryDirectory();
          final File file = new File('${path.path}/_temp.file');
          await file.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
          fileData = await fileStreamToBase64(file.openRead());
          file.delete();
        } catch (e) {}
      }
    }
    return await _CHANNEL.invokeMethod('info', {
      'title': title,
      'artist': artist,
      'imageData': fileData
    });
  }

  Future<String> fileStreamToBase64(Stream<dynamic> stream) async {
    var tempData = '';
    final completer = Completer();
    stream.transform(base64.encoder)
        .listen(
            (contents) => tempData += contents,
            onDone: () => completer.complete(),
            onError:() => completer.completeError('transform error')
    );
    await completer.future;
    return tempData;
  }

}

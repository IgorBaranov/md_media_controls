# md_media_controls
A new Flutter plugin was created while using the framework to develop [cross-platform apps at MobiDev](https://mobidev.biz/services/cross-platform-app-development)

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.io/developing-packages/),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter, view our 
[online documentation](https://flutter.io/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.
# MdMediaControls

A Flutter audio plugin (Swift/Kotlin) to play remote or local audio files and control it on LockScreen(iOS only, Android part will be ready soon)

## Features

- [x] Android & iOS
  - [x] play (remote file)
  - [x] stop
  - [x] pause
  - [x] onEnd
  - [x] position/duration
  - [x] seek
  - [x] mute
  - [x] rate / onChangeRate
- [x] iOS
  - [x] lockScreen controls
  - [x] lockScreen events
- [x] Android
   - TBD

## Usage

[Example](https://github.com/IgorBaranov/md_media_controls/blob/master/example/lib/main.dart)

To use this plugin :

- Add the dependency to your [pubspec.yaml](https://github.com/IgorBaranov/md_media_controls/blob/master/example/pubspec.yaml) file.

```yaml
  dependencies:
    flutter:
      sdk: flutter
    md_media_controls:
```

- Instantiate an MdMediaControls instance

```dart
//...
MdMediaControls mdMediaControls = new MdMediaControls();
//...
```

### Player Controls

```dart

const testUrl = "https://raw.githubusercontent.com/IgorBaranov/md_media_controls/master/example.mp3";

StreamBuilder<ControlsState>(
              initialData: ControlsState.STOPPED,
              stream: mdMediaControls.onPlayerStateChanged,
              builder: (BuildContext context, AsyncSnapshot<ControlsState> snapshot) {
                final ControlsState data = snapshot.data;

                return Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      onPressed: data == ControlsState.PLAYING ? null : () async {
                        await mdMediaControls.playNew(url: testUrl, rate: 2.0);
                        await mdMediaControls.setInfo(title: 'Some title', artist: 'some artist',
                            imageUrl: 'https://pngimage.net/wp-content/uploads/2018/05/example-icon-png-4.png'
                        );
                      },
                      iconSize: 64.0,
                      icon: Icon(Icons.play_arrow),
                      color: Colors.cyan),
                  IconButton(
                      onPressed: data == ControlsState.PLAYING ? () {
                        mdMediaControls.pause();
                      } : null,
                      iconSize: 64.0,
                      icon: Icon(Icons.pause),
                      color: Colors.cyan),
                  IconButton(
                      onPressed: data == ControlsState.PLAYING || data == ControlsState.PAUSED ? () {
                        mdMediaControls.stop();
                      } : null,
                      iconSize: 64.0,
                      icon: Icon(Icons.stop),
                      color: Colors.amberAccent),
                  IconButton(
                      onPressed: () async {
                        await mdMediaControls.setInfo(title: 'Some title 123', artist: 'some artist 123',
                            imageUrl: 'assets/test.png'
                        );
                      },
                      iconSize: 64.0,
                      icon: Icon(Icons.adb),
                      color: Colors.amberAccent),

                ]);
              },
            )
```

### Status current position, seek and rate

The dart part of the plugin listen for platform calls :

```dart
StreamBuilder<ControlsState>(
                    initialData: ControlsState.STOPPED,
                    stream: mdMediaControls.onPlayerStateChanged,
                    builder: (BuildContext context, AsyncSnapshot<ControlsState> snapshot) {
                      final ControlsState data = snapshot.data;

                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            onPressed: data == ControlsState.PLAYING ? null : () async {
                              await mdMediaControls.playNew(url: 'another url', rate: 1.0);
                              await mdMediaControls.setInfo(title: 'Some title', artist: 'some artist',
                                  imageUrl: 'https://pngimage.net/wp-content/uploads/2018/05/example-icon-png-4.png'
                              );
                            },
                            iconSize: 64.0,
                            icon: Icon(Icons.play_arrow),
                            color: Colors.cyan),
                        IconButton(
                            onPressed: data == ControlsState.PLAYING ? () {
                              mdMediaControls.pause();
                            } : null,
                            iconSize: 64.0,
                            icon: Icon(Icons.pause),
                            color: Colors.cyan),
                        IconButton(
                            onPressed: data == ControlsState.PLAYING || data == ControlsState.PAUSED ? () {
                              mdMediaControls.stop();
                            } : null,
                            iconSize: 64.0,
                            icon: Icon(Icons.stop),
                            color: Colors.amberAccent),

                      ]);
                    },
                  ),
                  StreamBuilder<Duration>(
                      initialData: Duration(),
                      stream: mdMediaControls.positionChanged,
                      builder: (BuildContext context, AsyncSnapshot<Duration> snapshot) {
                        final double max = sound.service.duration.inSeconds.toDouble();
                        final double value = snapshot.data.inSeconds.toDouble();

                        return Column(
                          children: <Widget>[
                            max > 0.0 ? Center(
                                child: Text('$value/$max')
                            ) : Container(),
                            value >= 0.0 && value <= max ? Slider(
                                onChanged: (double seconds) {
                                  mdMediaControls.seek(seconds);
                                },
                                min: 0.0,
                                value: value,
                                max: max
                            ) : Slider(
                                onChanged: null,
                                min: 0.0,
                                value: 0.0,
                                max: max
                            )
                          ],
                        );
                      }
                  ),
                  StreamBuilder<double>(
                    initialData: 1.0,
                    stream: mdMediaControls.onRateChanged,
                    builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
                      return Column(
                        children: <Widget>[
                          Text('${snapshot.data}'),
                          Container(
                              child: Center(
                                child: Slider(
                                    onChanged: (double rate) => mdMediaControls.rate(rate: rate),
                                    value: snapshot.data,
                                    min: 0.0,
                                    max: 5.0
                                ),
                              )
                          )
                        ],
                      );
                    }
                  )
```

Do not forget to cancel all the subscriptions when the widget is disposed.

## iOS

## :warning: iOS App Transport Security

By default iOS forbids loading from non-https url. To cancel this restriction edit your .plist and add :

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Getting Started

For help getting started with Flutter, view our online
[documentation](http://flutter.io/).

For help on editing plugin code, view the [documentation](https://flutter.io/platform-plugins/#edit-code).

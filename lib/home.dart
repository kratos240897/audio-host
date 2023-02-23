import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:socket_io_client/socket_io_client.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isSending = false;
  bool isReceiving = false;
  Stream<Uint8List>? stream;
  StreamSubscription<Uint8List>? listener;
  late io.Socket socket;
  AudioPlayer? audioPlayer = AudioPlayer();

  Future<void> initSocket() async {
    try {
      socket = io.io(
          'https://0903-27-5-115-227.in.ngrok.io',
          OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .build());
      socket.connect();
      socket.onConnect((data) {
        if (kDebugMode) {
          print('connected: ${socket.id}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  @override
  void initState() {
    initSocket().then((value) {
      if (kDebugMode) {
        print(socket.connected);
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Echo'),
      ),
      body: SafeArea(
          child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
                onPressed: isReceiving ? null : () async {
                  if (isSending) {
                    _pauseCapturing();
                    return;
                  }
                  await _startCaputring();
                },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    shape: const StadiumBorder()),
                icon: Icon(
                    isSending ? Icons.signal_cellular_alt_rounded : Icons.send),
                label: Text(isSending ? 'Sending' : 'Send')),
            ElevatedButton.icon(
                onPressed: isSending ? null : () async {
                  if (isReceiving) {
                    _pauseReceiving();
                    return;
                  }
                  await _receiveAudio();
                },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    shape: const StadiumBorder()),
                icon: Icon(
                    isReceiving ? Icons.equalizer : Icons.record_voice_over),
                label: Text(isReceiving ? 'Receiving' : 'Receive'))
          ],
        ),
      )),
    );
  }

  _startCaputring() async {
    if (stream != null && listener != null) {
      await _resumeCapturing();
      return;
    }
    setState(() {
      isSending = true;
      isReceiving = false;
    });
    MicStream.shouldRequestPermission(true);
    stream = await MicStream.microphone(sampleRate: 44100);
    listener = stream?.listen((samples) {
      socket.emit('audio-stream-send', samples);
    });
  }

  _receiveAudio() async {
    if (stream != null && listener != null && audioPlayer != null) {
      await _resumeReceiving();
      return;
    }
    setState(() {
      isSending = false;
      isReceiving = true;
    });
    socket.on('audio-stream-receive', (data) async {
      if (kDebugMode) {
        print('audio-stream-receive $data');
      }
      await audioPlayer?.play(BytesSource(data));
    });
  }

  _pauseReceiving() async {
    setState(() {
      isReceiving = false;
    });
    await audioPlayer?.pause();
  }

  _resumeReceiving() async {
    setState(() {
      isReceiving = true;
    });
    await audioPlayer?.resume();
  }

  _stopReceiving() async {
    await audioPlayer?.stop();
  }

  _pauseCapturing() async {
    setState(() {
      isSending = false;
    });
    listener?.pause();
  }

  _resumeCapturing() async {
    setState(() {
      isSending = true;
    });
    listener?.resume();
  }

  _stopCapturing() async {
    stream = null;
    listener?.cancel();
    listener = null;
  }

  @override
  void dispose() {
    _stopCapturing();
    _stopReceiving();
    socket.disconnect();
    super.dispose();
  }
}

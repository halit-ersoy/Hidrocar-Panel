import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:window_manager/window_manager.dart';

class BackCamera extends StatefulWidget {
  const BackCamera({super.key});

  @override
  _BackCameraState createState() => _BackCameraState();
}

class _BackCameraState extends State<BackCamera> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _stream;
  double screenWidth = 1920;
  double screenHeight = 1080;

  @override
  void initState() {
    super.initState();
    _initializeWindow();
    _initializeCamera();
  }

  Future<void> _initializeWindow() async {
    await windowManager.waitUntilReadyToShow();
    Size screenSize = await windowManager.getSize();
    setState(() {
      screenWidth = screenSize.width;
      screenHeight = screenSize.height;
    });
    await windowManager.setFullScreen(true);
  }

  Future<void> _initializeCamera() async {
    await _renderer.initialize();
    try {
      final Map<String, dynamic> constraints = {
        'video': {
          'facingMode': 'user',
          'width': {'ideal': screenWidth.toInt()},
          'height': {'ideal': screenHeight.toInt()},
        }
      };

      MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);
      setState(() {
        _stream = stream;
        _renderer.srcObject = stream;
      });
    } catch (e) {
      print("Kamera açılırken hata oluştu: $e");
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _stream?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              _renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            ),
          ),
        ],
      ),
    );
  }
}

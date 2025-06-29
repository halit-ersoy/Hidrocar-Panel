import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:path/path.dart' as p;

class BackCamera extends StatefulWidget {
  const BackCamera({super.key});

  @override
  State<BackCamera> createState() => _BackCameraState();
}

class _BackCameraState extends State<BackCamera> {
  Process? _pythonProcess;
  bool _serverReady = false;
  bool _streamActive = false;
  bool _errorState = false;
  String _errorMessage = '';
  Timer? _connectionChecker;
  Timer? _streamActivityTimer;

  @override
  void initState() {
    super.initState();
    _launchPythonServer();
    // Start stream activity checker
    _streamActivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // This will toggle the stream status indicator to show activity
      setState(() {
        _streamActive = !_streamActive;
      });
    });
  }

  Future<void> _launchPythonServer() async {
    setState(() {
      _serverReady = false;
      _errorState = false;
      _errorMessage = '';
    });

    try {
      final pythonExe =
          r'C:\Users\halit\AndroidStudioProjects\hidrocar_panel\.venv\Scripts\python.exe';
      final scriptPath = p.join(Directory.current.path, 'camera.py');

      if (!File(pythonExe).existsSync()) {
        setState(() {
          _errorState = true;
          _errorMessage = 'Python yürütülebilir dosyası bulunamadı: $pythonExe';
        });
        return;
      }

      if (!File(scriptPath).existsSync()) {
        setState(() {
          _errorState = true;
          _errorMessage = 'Python betiği bulunamadı: $scriptPath';
        });
        return;
      }

      _pythonProcess = await Process.start(
        pythonExe,
        [scriptPath],
        workingDirectory: Directory.current.path,
        environment: {'PYTHONIOENCODING': 'utf-8'},
      );

      _pythonProcess!.stdout.transform(const Utf8Decoder()).listen(
        (output) {
          print('[PY-OUT] $output');
          if (output.contains('Running on')) {
            setState(() => _serverReady = true);
          }
        },
      );

      _pythonProcess!.stderr.transform(const Utf8Decoder()).listen(
        (error) {
          print('[PY-ERR] $error');
          if (error.contains('Error') || error.contains('Exception')) {
            setState(() {
              _errorState = true;
              _errorMessage = error;
            });
          }
        },
      );

      // Wait for server to start
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _serverReady = true);
    } catch (e) {
      setState(() {
        _errorState = true;
        _errorMessage = 'Kamera başlatılırken hata oluştu: $e';
      });
    }
  }

  void _restartServer() {
    _pythonProcess?.kill();
    _launchPythonServer();
  }

  @override
  void dispose() {
    _pythonProcess?.kill();
    _connectionChecker?.cancel();
    _streamActivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streamUrl = 'http://127.0.0.1:5000/video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Stream
          if (_serverReady && !_errorState)
            Positioned.fill(
              child: Mjpeg(
                isLive: true,
                stream: streamUrl,
                error: (context, error, stack) {
                  return Center(
                    child: _buildErrorDisplay(
                        'Yayın bağlantı hatası', error.toString()),
                  );
                },
                loading: (context) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Kamera yayını başlatılıyor...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                fit: BoxFit.contain,
              ),
            ),

          // Error Display
          if (_errorState)
            _buildErrorDisplay('Kamera Hatası', _errorMessage, canRetry: true),

          // Server initializing display
          if (!_serverReady && !_errorState)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: 30),
                    Text(
                      'Kamera Başlatılıyor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Python sunucusu hazırlanıyor...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar with title and status
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'ARKA KAMERA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  // Status indicator
                  if (_serverReady && !_errorState)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _streamActive
                            ? Colors.green.withOpacity(0.3)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _streamActive
                              ? Colors.green
                              : Colors.green.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi,
                            color: _streamActive
                                ? Colors.green
                                : Colors.green.withOpacity(0.7),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Bağlı',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera info
                  if (_serverReady && !_errorState)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'HD Kamera (1280x720)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Function key navigation
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.3), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FunctionKey(label: 'F1', description: 'Ana Ekran'),
                        SizedBox(width: 16),
                        _FunctionKey(
                            label: 'F2',
                            description: 'Arka Kamera',
                            isActive: true),
                        SizedBox(width: 16),
                        _FunctionKey(
                          label: 'F3',
                          description: 'Ön Kamera',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String title, String message,
      {bool canRetry = false}) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 70,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (canRetry) ...[
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _restartServer,
              icon: const Icon(Icons.refresh),
              label: const Text('YENİDEN DENE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Function key component for the navigation bar
class _FunctionKey extends StatelessWidget {
  final String label;
  final String description;
  final bool isActive;

  const _FunctionKey({
    required this.label,
    required this.description,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          description,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

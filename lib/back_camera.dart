import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:path/path.dart' as p;
import 'function_key.dart';

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
    _streamActivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() => _streamActive = !_streamActive);
    });
  }

  // --- OS'e göre Python yürütücüsünü bulan yardımcı fonksiyon ---
  Future<String?> _resolvePythonExe() async {
    final env = Platform.environment;
    final cwd = Directory.current.path;

    // 1) Ortam değişkeni ile override
    final fromEnv = env['PYTHON_EXEC'];
    final candidates = <String>[
      if (fromEnv != null && fromEnv.trim().isNotEmpty) fromEnv.trim(),

      // 2) Proje içindeki virtualenv yolları
      // Windows
      if (Platform.isWindows) p.join(cwd, r'.venv\Scripts\python.exe'),
      if (Platform.isWindows) p.join(cwd, r'venv\Scripts\python.exe'),
      // Linux/RPi
      if (!Platform.isWindows) p.join(cwd, '.venv/bin/python'),
      if (!Platform.isWindows) p.join(cwd, 'venv/bin/python'),

      // 3) Sistem PATH
      'python',
      'python3',

      // 4) Olası tam yollar (Linux/RPi)
      if (!Platform.isWindows) '/usr/bin/python3',
      if (!Platform.isWindows) '/usr/local/bin/python3',
    ];

    Future<bool> _isUsable(String exe) async {
      try {
        final res = await Process.run(exe, ['-V'],
            stdoutEncoding: const Utf8Codec(),
            stderrEncoding: const Utf8Codec());
        final out = (res.stdout.toString() + res.stderr.toString()).trim();
        if (res.exitCode == 0 && out.toLowerCase().contains('python')) {
          // (İstersen Python >=3.8 kontrolü ekleyebilirsin)
          return true;
        }
      } catch (_) {}
      return false;
    }

    for (final exe in candidates) {
      if (exe.isEmpty) continue;
      if (await _isUsable(exe)) return exe;
    }
    return null;
  }

  Future<void> _launchPythonServer() async {
    setState(() {
      _serverReady = false;
      _errorState = false;
      _errorMessage = '';
    });

    try {
      final pythonExe = await _resolvePythonExe();
      final scriptPath = p.join(Directory.current.path, 'camera.py');

      if (pythonExe == null) {
        setState(() {
          _errorState = true;
          _errorMessage = 'Uygun bir Python yürütücüsü bulunamadı. '
              'PATH’e python/python3 ekleyin ya da PYTHON_EXEC ortam değişkeniyle yolu belirtin.';
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

      // Linux/RPi için bazı ortamlarda locale/utf-8 ve opencv ile uyumlu IO önemlidir.
      final env = Map<String, String>.from(Platform.environment)
        ..putIfAbsent('PYTHONIOENCODING', () => 'utf-8');

      _pythonProcess = await Process.start(
        pythonExe,
        [scriptPath],
        workingDirectory: Directory.current.path,
        environment: env,
        mode: ProcessStartMode.normal,
      );

      _pythonProcess!.stdout.transform(const Utf8Decoder()).listen((output) {
        // Flask "Running on http://..." yazdığında hazır say
        if (output.contains('Running on')) {
          setState(() => _serverReady = true);
        }
        // Debug log
        // print('[PY-OUT] $output');
      });

      _pythonProcess!.stderr.transform(const Utf8Decoder()).listen((error) {
        // print('[PY-ERR] $error');
        if (error.contains('Error') || error.contains('Exception')) {
          setState(() {
            _errorState = true;
            _errorMessage = error;
          });
        }
      });

      // Küçük bir bekleme: bazı cihazlarda Flask'ın ayağa kalkması 1-2 sn sürüyor
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
    // İstek her zaman 0 ile gitsin (Raspberry Pi’de arka/ön seçmek istersen ileride bu değeri değiştirebilirsin)
    const int cameraIndex = 0;
    final streamUrl = 'http://127.0.0.1:5000/video?camera=$cameraIndex';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_serverReady && !_errorState)
            Positioned.fill(
              child: Mjpeg(
                isLive: true,
                stream: streamUrl,
                error: (context, error, stack) {
                  return Center(
                    child:
                    _buildErrorDisplay('Bağlantı hatası', error.toString()),
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
                            'Kamera başlatılıyor...',
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

          if (_errorState)
            _buildErrorDisplay('Kamera Hatası', _errorMessage, canRetry: true),

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
                      'Bağlantı kuruluyor...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Üst bar vs... (kalan kısımlar aynı)
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
                        children: const [
                          Icon(Icons.wifi, color: Colors.green, size: 16),
                          SizedBox(width: 6),
                          Text(
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

          // Alt overlay ve butonlar (aynı)
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
                  if (_serverReady && !_errorState)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white70, size: 16),
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
                        FunctionKey(label: 'F1', description: 'Ana Ekran'),
                        SizedBox(width: 16),
                        FunctionKey(
                            label: 'F2',
                            description: 'Arka Kamera',
                            isActive: true),
                        SizedBox(width: 16),
                        FunctionKey(
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
          const Icon(Icons.error_outline, color: Colors.red, size: 70),
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

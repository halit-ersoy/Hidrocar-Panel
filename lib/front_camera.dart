import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:path/path.dart' as p;

class FrontCamera extends StatefulWidget {
  const FrontCamera({super.key});

  @override
  State<FrontCamera> createState() => _FrontCameraState();
}

class _FrontCameraState extends State<FrontCamera> {
  Process? _pythonProcess;
  StreamSubscription<String>? _outSub;
  StreamSubscription<String>? _errSub;

  bool _serverReady = false;
  bool _streamActive = false;
  bool _errorState = false;
  String _errorMessage = '';

  Timer? _streamActivityTimer;

  // ---- Sabitler ----
  static const String _camIndex = '0';   // ön kamera = 0
  static const String _port     = '5000';
  static const String _script   = 'camera.py';

  @override
  void initState() {
    super.initState();
    _launchPythonServer();

    // Yayın aktif göstergesi (sadece UI animasyon)
    _streamActivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _safeSetState(() => _streamActive = !_streamActive);
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  // ---- Python çözümleme (Windows + Linux) ----
  Future<String?> _resolvePythonCmd() async {
    // 0) Ortam değişkeni override
    final envPy = Platform.environment['HYDROCAR_PY'];
    if (envPy != null && envPy.isNotEmpty && File(envPy).existsSync()) return envPy;

    if (Platform.isWindows) {
      // 1) py launcher
      try {
        final r = await Process.run('py', ['-3', '--version'], runInShell: true);
        if (r.exitCode == 0 && (r.stdout.toString() + r.stderr.toString()).contains('Python')) {
          return 'py'; // 'py -3 script.py'
        }
      } catch (_) {}

      // 2) yaygın venv yolları
      final guesses = <String>[
        p.join(Directory.current.path, '.venv', 'Scripts', 'python.exe'),
        p.join(Directory.current.path, 'venv',  'Scripts', 'python.exe'),
      ];
      for (final g in guesses) {
        if (File(g).existsSync()) return g;
      }

      // 3) PATH
      for (final cmd in ['python', 'python.exe']) {
        try {
          final r = await Process.run(cmd, ['--version'], runInShell: true);
          if (r.exitCode == 0) return cmd;
        } catch (_) {}
      }
    } else {
      // Linux/macOS
      for (final cmd in ['python3', 'python']) {
        try {
          final r = await Process.run(cmd, ['--version']);
          if (r.exitCode == 0) return cmd;
        } catch (_) {}
      }
      for (final cmd in ['/usr/bin/python3', '/usr/local/bin/python3']) {
        if (File(cmd).existsSync()) return cmd;
      }
    }
    return null;
  }

  String? _resolveScriptPath() {
    // 1) Çalışma dizini
    final c1 = p.join(Directory.current.path, _script);
    if (File(c1).existsSync()) return c1;

    // 2) Çalıştırılabilirin klasörü (desktop build’lerde faydalı)
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final c2 = p.join(exeDir, _script);
      if (File(c2).existsSync()) return c2;
    } catch (_) {}

    // 3) Parent (bazı debug koşullarında)
    final c3 = p.join(Directory.current.parent.path, _script);
    if (File(c3).existsSync()) return c3;

    return null;
  }

  Future<void> _launchPythonServer() async {
    _safeSetState(() {
      _serverReady = false;
      _errorState = false;
      _errorMessage = '';
    });

    try {
      final pythonCmd = await _resolvePythonCmd();
      final scriptPath = _resolveScriptPath();

      if (pythonCmd == null) {
        _safeSetState(() {
          _errorState = true;
          _errorMessage =
          'Uygun Python bulunamadı.\n'
              'Windows: py -3 / python.exe, Linux: python3\n'
              'Gerekirse HYDROCAR_PY ile yolu belirt.';
        });
        return;
      }
      if (scriptPath == null) {
        _safeSetState(() {
          _errorState = true;
          _errorMessage = 'Python betiği bulunamadı: $_script\n'
              'camera.py dosyasını çalışma dizinine koy.';
        });
        return;
      }

      // Windows’ta py launcher ise '-3' kullan
      final args = (Platform.isWindows && p.basename(pythonCmd).toLowerCase() == 'py')
          ? ['-3', scriptPath, _camIndex, _port]
          : [scriptPath, _camIndex, _port];

      final proc = await Process.start(
        pythonCmd,
        args,
        workingDirectory: Directory.current.path,
        environment: {
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONUNBUFFERED': '1',
        },
        runInShell: Platform.isWindows, // py launcher için gerekli
      );

      if (!mounted) {
        proc.kill(ProcessSignal.sigkill);
        return;
      }

      _pythonProcess = proc;

      _outSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // ignore: avoid_print
        print('[PY-OUT] $line');
        if (!mounted) return;
        if (line.contains('Running on') || line.contains(' * Running on')) {
          _safeSetState(() => _serverReady = true);
        }
      });

      _errSub = proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // ignore: avoid_print
        print('[PY-ERR] $line');
        if (!mounted) return;
        final l = line.toLowerCase();
        if (l.contains('error') || l.contains('exception') || l.contains('traceback')) {
          _safeSetState(() {
            _errorState = true;
            _errorMessage = line;
          });
        }
      });

      // Basit hazır bekleme
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _safeSetState(() => _serverReady = true);
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() {
        _errorState = true;
        _errorMessage = 'Kamera başlatılırken hata oluştu: $e';
      });
    }
  }

  void _restartServer() {
    _pythonProcess?.kill(ProcessSignal.sigkill);
    _outSub?.cancel();
    _errSub?.cancel();
    _launchPythonServer();
  }

  @override
  void dispose() {
    _streamActivityTimer?.cancel();
    _streamActivityTimer = null;

    _outSub?.cancel();
    _errSub?.cancel();
    _outSub = null;
    _errSub = null;

    _pythonProcess?.kill(ProcessSignal.sigkill);
    _pythonProcess = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const streamUrl = 'http://127.0.0.1:5000/video';

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
                error: (context, error, stack) => Center(
                  child: _buildErrorDisplay('Yayın bağlantı hatası', error.toString()),
                ),
                loading: (context) => Container(
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
                ),
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
                    'ÖN KAMERA',
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _streamActive ? Colors.green.withOpacity(0.3) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _streamActive ? Colors.green : Colors.green.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi,
                            color: _streamActive ? Colors.green : Colors.green.withOpacity(0.7),
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
                  if (_serverReady && !_errorState)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, color: Colors.white70, size: 16),
                          SizedBox(width: 8),
                          Text('HD Kamera (1280x720)',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FunctionKey(label: 'F1', description: 'Ana Ekran'),
                        SizedBox(width: 16),
                        _FunctionKey(label: 'F2', description: 'Arka Kamera'),
                        SizedBox(width: 16),
                        _FunctionKey(label: 'F3', description: 'Ön Kamera', isActive: true),
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

  Widget _buildErrorDisplay(String title, String message, {bool canRetry = false}) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 70),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
          if (canRetry) ...[
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _restartServer,
              icon: const Icon(Icons.refresh),
              label: const Text('YENİDEN DENE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
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

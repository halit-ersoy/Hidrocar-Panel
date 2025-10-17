import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

// Bu dosyanın projenizde mevcut olduğunu ve bir FunctionKey widget'ı
// içerdiğini varsayıyorum. Eğer dosya adı farklıysa bu satırı güncelleyin.
import 'function_key.dart';

class BackCamera extends StatefulWidget {
  const BackCamera({super.key});

  @override
  State<BackCamera> createState() => _BackCameraState();
}

class _BackCameraState extends State<BackCamera> {
  Process? _pythonProcess;
  Stream<Uint8List>? _imageStream;
  StreamSubscription? _errorSubscription;

  bool _errorState = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _launchPythonProcess();
  }

  // Python betiğinden gelen ham byte akışını anlamlı JPEG karelerine dönüştürür.
  Stream<Uint8List> _processCameraStream(Stream<List<int>> rawStream) async* {
    List<int> buffer = [];
    int expectedLength = -1;

    await for (var chunk in rawStream) {
      buffer.addAll(chunk);

      while (true) {
        // 1. Adım: Bir sonraki görüntünün boyutunu içeren satırı ara
        if (expectedLength == -1) {
          // '\n' (newline) karakterinin ASCII kodu 10'dur. Bu bizim ayırıcımız.
          int newlineIndex = buffer.indexOf(10);
          if (newlineIndex != -1) {
            final lengthBytes = buffer.sublist(0, newlineIndex);
            final lengthString = utf8.decode(lengthBytes);
            expectedLength = int.tryParse(lengthString) ?? -1;

            if (expectedLength <= 0) {
              // Geçersiz veya boş bir uzunluk bilgisi geldi, buffer'ı temizle ve baştan başla
              buffer.clear();
              expectedLength = -1;
              continue;
            }
            // Boyut bilgisini ve newline karakterini buffer'dan kaldır
            buffer = buffer.sublist(newlineIndex + 1);
          } else {
            // Henüz tam bir boyut bilgisi gelmedi, sonraki veri parçasını bekle
            break;
          }
        }

        // 2. Adım: Beklenen boyutta görüntü verisi buffer'da var mı kontrol et
        if (expectedLength != -1 && buffer.length >= expectedLength) {
          final imageData = Uint8List.fromList(buffer.sublist(0, expectedLength));
          yield imageData; // Tam bir görüntü karesi bulduk, stream'e gönder!

          // İşlenen görüntü verisini buffer'dan kaldır
          buffer = buffer.sublist(expectedLength);
          // Bir sonraki karenin boyutunu beklemeye başla
          expectedLength = -1;
        } else {
          // Henüz tam bir görüntü verisi gelmedi, sonraki veri parçasını bekle
          break;
        }
      }
    }
  }

  Future<void> _launchPythonProcess() async {
    setState(() {
      _errorState = false;
      _errorMessage = '';
      _imageStream = null;
    });

    try {
      final pythonExe = await _resolvePythonExe();
      final scriptPath = await _resolveScriptPath();

      if (pythonExe == null) {
        throw Exception(
            'Python yürütücüsü bulunamadı. PATH’e python/python3 ekleyin '
                'ya da PYTHON_EXEC ortam değişkeniyle yolu belirtin.');
      }
      if (scriptPath == null) {
        throw Exception(
            'camera.py bulunamadı. CAMERA_PY ortam değişkeni ile tam yolu verebilir, '
                'ya da betiği uygulamanın yanında veya Hidrocar-Panel klasöründe tutabilirsiniz.');
      }

      const int cameraIndex = 0; // Kullanılacak kamera indeksi
      final scriptDir = File(scriptPath).parent.path;

      _pythonProcess = await Process.start(
        pythonExe,
        [scriptPath, cameraIndex.toString()], // Kamera indeksini argüman olarak gönder
        workingDirectory: scriptDir,
        mode: ProcessStartMode.normal,
      );

      // Python betiğinden gelen hataları dinle
      _errorSubscription =
          _pythonProcess!.stderr.transform(utf8.decoder).listen((error) {
            debugPrint("[PY-ERR] $error");
            // Sadece ilk anlamlı hata mesajını göster
            if (!_errorState && mounted) {
              setState(() {
                _errorState = true;
                _errorMessage = error;
              });
            }
          });

      // Çıkış kodunu kontrol et, işlem hemen hata ile sonlanırsa yakala
      _pythonProcess!.exitCode.then((code) {
        if (code != 0 && !_errorState && mounted) {
          setState(() {
            _errorState = true;
            _errorMessage =
            "Kamera işlemi beklenmedik bir şekilde sonlandı (Çıkış Kodu: $code). Hata loglarını kontrol edin.";
          });
        }
      });

      // Görüntü akışını işlemeye başla
      if (mounted) {
        setState(() {
          _imageStream = _processCameraStream(_pythonProcess!.stdout);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorState = true;
          _errorMessage = 'Kamera başlatılırken hata oluştu: ${e.toString()}';
        });
      }
    }
  }

  void _restartProcess() {
    _pythonProcess?.kill();
    _errorSubscription?.cancel();
    _launchPythonProcess();
  }

  @override
  void dispose() {
    _pythonProcess?.kill();
    _errorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ana Görüntü Alanı
          Center(
            child: _buildCameraView(),
          ),

          // Üst Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopOverlay(),
          ),

          // Alt Bar ve Butonlar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_errorState) {
      return _buildErrorDisplay('Kamera Hatası', _errorMessage, canRetry: true);
    }

    if (_imageStream == null) {
      return _buildLoadingDisplay(
          'Kamera Başlatılıyor', 'Bağlantı kuruluyor...');
    }

    return StreamBuilder<Uint8List>(
      stream: _imageStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Gelen byte verisini direkt olarak Image widget'ına veriyoruz
          return Image.memory(
            snapshot.data!,
            gaplessPlayback: true, // Kareler arası geçişte titremeyi önler
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Görüntü verisi bozuk gelirse burası tetiklenir
              return const Center(
                  child: Text("Görüntü verisi hatalı.",
                      style: TextStyle(color: Colors.yellow)));
            },
          );
        } else if (snapshot.hasError) {
          return _buildErrorDisplay('Akış Hatası', snapshot.error.toString());
        }

        // Henüz veri gelmediyse bekleme ekranı göster
        return _buildLoadingDisplay(
            'Kamera Başlatılıyor', 'Görüntü bekleniyor...');
      },
    );
  }

  // --- UI Yardımcı Widget'ları (Orijinal kodunuzdan alınmıştır) ---

  Widget _buildTopOverlay() {
    return Container(
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
          // İsteğe bağlı: Stream durumuna göre "Bağlı" göstergesi
          if (_imageStream != null && !_errorState)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green,
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
    );
  }

  Widget _buildBottomOverlay() {
    return Container(
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
          if (_imageStream != null && !_errorState)
            const Padding(
              padding: EdgeInsets.only(bottom: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FunctionKey(label: 'F1', description: 'Ana Ekran'),
                SizedBox(width: 16),
                FunctionKey(label: 'F2', description: 'Arka Kamera', isActive: true),
                SizedBox(width: 16),
                FunctionKey(label: 'F3', description: 'Ön Kamera'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDisplay(String title, String subtitle) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                    color: Colors.blueAccent, strokeWidth: 4)),
            const SizedBox(height: 30),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
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
              onPressed: _restartProcess,
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

  // --- Betik ve Yürütücü Bulma Fonksiyonları (Orijinal kodunuzdan alınmıştır) ---

  Future<String?> _resolvePythonExe() async {
    final env = Platform.environment;
    final cwd = Directory.current.path;

    final fromEnv = env['PYTHON_EXEC'];
    final candidates = <String>[
      if (fromEnv != null && fromEnv.trim().isNotEmpty) fromEnv.trim(),
      if (Platform.isWindows) p.join(cwd, r'.venv\Scripts\python.exe'),
      if (Platform.isWindows) p.join(cwd, r'venv\Scripts\python.exe'),
      if (!Platform.isWindows) p.join(cwd, '.venv/bin/python'),
      if (!Platform.isWindows) p.join(cwd, 'venv/bin/python'),
      'python3',
      'python',
      if (!Platform.isWindows) '/usr/bin/python3',
      if (!Platform.isWindows) '/usr/local/bin/python3',
    ];

    Future<bool> isUsable(String exe) async {
      try {
        final res = await Process.run(exe, ['-V']);
        return res.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    for (final exe in candidates.where((c) => c.isNotEmpty)) {
      if (await isUsable(exe)) return exe;
    }
    return null;
  }

  Future<String?> _resolveScriptPath() async {
    final env = Platform.environment;
    final cwd = Directory.current.path;

    String? exeDir;
    try {
      exeDir = File(Platform.resolvedExecutable).parent.path;
    } catch (_) {
      exeDir = null;
    }

    final fromEnv = env['CAMERA_PY'];
    if (fromEnv != null &&
        fromEnv.trim().isNotEmpty &&
        File(fromEnv.trim()).existsSync()) {
      return fromEnv.trim();
    }

    final directCandidates = <String>[
      if (exeDir != null) p.join(exeDir, 'camera.py'),
      if (exeDir != null) p.join(exeDir, 'Hidrocar-Panel', 'camera.py'),
      p.join(cwd, 'camera.py'),
      p.join(cwd, 'Hidrocar-Panel', 'camera.py'),
    ];

    for (final c in directCandidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }
}
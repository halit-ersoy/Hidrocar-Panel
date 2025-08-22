import 'dart:async';
import 'dart:io' show Platform, Process, ProcessResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'package:hidrocar_panel/splash_screen.dart';
import 'package:hidrocar_panel/cross_page.dart';
import 'package:hidrocar_panel/back_camera.dart';
import 'package:hidrocar_panel/front_camera.dart';

import 'car_data_service.dart';
import 'car_data.dart';
import 'serial_service.dart';

// -------------------- Global --------------------
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
enum CurrentPage { cross, backCamera, frontCamera }
CurrentPage currentPage = CurrentPage.cross;

// -------------------- Main --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Tam ekran: Tüm platformlarda Flutter’ın immersive modu
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 2) Sadece desteklenen masaüstlerinde window_manager kullan
  await _initDesktopWindowIfSupported();

  // 3) Global kısayollar (opsiyonel)
  ServicesBinding.instance.keyboard.addHandler(_handleGlobalKeyEvent);

  // 4) Seri portu başlat
  _startSerialByPlatform();

  // 5) UI canlı kalsın diye simülasyon
  _startSimulatedData();

  runApp(const MyApp());
}

/// window_manager sadece Windows ve Linux **x64**’te çalıştırılır.
/// Linux’ta mimariyi `uname -m` ile kontrol ediyoruz (arm/aarch64 ise atla).
Future<void> _initDesktopWindowIfSupported() async {
  try {
    final bool isWindows = Platform.isWindows;
    final bool isLinux = Platform.isLinux;

    bool isLinuxArm = false;
    if (isLinux) {
      // uname -m -> x86_64, aarch64, armv7l ...
      final ProcessResult r = await Process.run('uname', ['-m']);
      final arch = (r.stdout as String?)?.trim().toLowerCase() ?? '';
      isLinuxArm = arch.contains('arm') || arch.contains('aarch64');
      debugPrint('Linux arch: $arch  (arm? $isLinuxArm)');
    }

    if (isWindows || (isLinux && !isLinuxArm)) {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,  // macOS/Windows: başlık gizli
        backgroundColor: Colors.black,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        // Windows/Linux x64: çerçevesiz + tam ekran + yeniden boyutlandırma kapalı
        await windowManager.setAsFrameless();
        await windowManager.setResizable(false);
        await windowManager.setPreventClose(true);
        await windowManager.setFullScreen(true);
        await windowManager.show();
        await windowManager.focus();
      });

      // Kapatmayı tamamen engelle (istersen burada onay diyaloğu yaz)
      windowManager.addListener(_WndListener());
    } else {
      // ARM Linux (ör. Raspberry Pi): window_manager KULLANMA
      debugPrint('window_manager skipped on this platform/arch.');
    }
  } catch (e) {
    // Her ihtimale karşı: missing plugin vs. durumunda sorunsuz devam et
    debugPrint('window_manager init skipped due to error: $e');
  }
}

// -------------------- Window listener --------------------
class _WndListener with WindowListener {
  @override
  void onWindowClose() async {
    final prevent = await windowManager.isPreventClose();
    if (prevent) {
      // Tamamen engelle; istersen burada onay diyaloğu aç
      return;
    }
  }
}

// -------------------- Serial başlangıcı --------------------
void _startSerialByPlatform() {
  final env = Platform.environment;
  final envPort = env['SERIAL_PORT'];

  if (Platform.isLinux) {
    final ports = SerialPort.availablePorts;
    debugPrint('availablePorts: $ports');

    String? preferred;
    if (envPort != null && envPort.isNotEmpty && ports.contains(envPort)) {
      preferred = envPort;
    } else {
      // RPi & Linux’ta yaygın adlar
      preferred = ports.firstWhere(
            (p) => p.contains('/dev/serial0'),
        orElse: () => ports.firstWhere(
              (p) => p.contains('/dev/ttyAMA'),
          orElse: () => ports.firstWhere(
                (p) => p.contains('/dev/ttyS'),
            orElse: () => ports.firstWhere(
                  (p) => p.contains('/dev/ttyUSB'),
              orElse: () => '', // bulunamadı -> auto-scan
            ),
          ),
        ),
      );
      if (preferred.isEmpty) preferred = null;
    }

    SerialService().start(
      onLine: onSerialLine,
      preferredPortName: preferred ?? '',
      fallbackToAuto: true,
    );
  } else if (Platform.isWindows) {
    final ports = SerialPort.availablePorts;
    debugPrint('availablePorts: $ports');

    String? preferred = envPort?.isNotEmpty == true ? envPort : null;
    preferred ??= ports.contains('COM11') ? 'COM11' : null;

    SerialService().start(
      onLine: onSerialLine,
      preferredPortName: preferred ?? '',
      fallbackToAuto: true,
    );
  } else {
    // Diğer platformlarda otomatik tarama
    SerialService().start(
      onLine: onSerialLine,
      preferredPortName: envPort ?? '',
      fallbackToAuto: true,
    );
  }
}

// -------------------- Gelen seri satırlar --------------------
void onSerialLine(String line) {
  final msg = line.trim().toLowerCase();
  if (msg.isEmpty) return;

  debugPrint('UART/Serial: $msg');

  void go(Widget page, CurrentPage pageId) {
    if (currentPage == pageId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => page),
            (route) => false,
      );
      currentPage = pageId;
    });
  }

  if (msg == 'button-1') {
    go(const CrossPage(), CurrentPage.cross);
  } else if (msg == 'button-2') {
    go(const BackCamera(), CurrentPage.backCamera);
  } else if (msg == 'button-3') {
    go(const FrontCamera(), CurrentPage.frontCamera);
  }
}

// -------------------- Kısayol tuşları (opsiyonel) --------------------
bool _handleGlobalKeyEvent(KeyEvent event) {
  if (event is KeyDownEvent) {
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      onSerialLine('button-1');
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      onSerialLine('button-2');
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      onSerialLine('button-3');
      return true;
    }
  }
  return false;
}

// -------------------- App --------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

// -------------------- Telemetri simülasyonu --------------------
void _startSimulatedData() {
  double batteryPercentage = 50;
  double speed = 0;
  bool speedIncreasing = true;
  bool isCharging = true;
  int chargingStateCounter = 0;

  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    if (speedIncreasing) {
      speed += 0.5;
      if (speed >= 90) speedIncreasing = false;
    } else {
      speed -= 0.5;
      if (speed <= 0) speedIncreasing = true;
    }

    chargingStateCounter++;
    if (chargingStateCounter >= 300) {
      isCharging = !isCharging;
      chargingStateCounter = 0;
    }

    if (isCharging) {
      batteryPercentage = (batteryPercentage + 0.05).clamp(0, 100);
    } else {
      batteryPercentage = (batteryPercentage - 0.01).clamp(0, 100);
    }

    CarDataService().updateData(CarData(
      batteryPercentage: batteryPercentage,
      remainingEnergy: batteryPercentage * 20,
      chargePower: isCharging ? 500 : 0,
      batteryCurrent: isCharging ? 12 : 8,
      batteryVoltage: 78,
      batteryTemperature: isCharging ? 76 : 50,
      isolationResistance: 20,
      speed: speed,
    ));
  });
}

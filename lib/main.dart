import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// kiosk uygulandı bayrağı
bool _kioskApplied = false;

// -------------------- Main --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // İçerik tam ekran (sistem çubuklarını gizle)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // (Opsiyonel) Global kısayollar
  ServicesBinding.instance.keyboard.addHandler(_handleGlobalKeyEvent);

  // Serial başlat
  _startSerialByPlatform();

  // Simülasyon
  _startSimulatedData();

  runApp(const MyApp());

  // Linux (X11) için kiosk’u yalnızca 1 kez uygula
  if (Platform.isLinux) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyKioskOnceStable();
    });
  }
}

// -------------------- Linux Kiosk (X11) --------------------
Future<void> applyKioskOnceStable() async {
  if (_kioskApplied || !Platform.isLinux) return;
  _kioskApplied = true;

  Future<void> run(String cmd) async {
    try {
      await Process.run('bash', ['-lc', cmd]);
    } catch (_) {}
  }

  Future<String?> getActiveWinId() async {
    try {
      final res = await Process.run('bash', ['-lc', 'xdotool getactivewindow']);
      final id = (res.stdout as String?)?.trim();
      return (id != null && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }

  // Pencere map olana kadar kısa retry (maks 6 deneme, ~1.5 sn)
  int tries = 0;
  Timer.periodic(const Duration(milliseconds: 250), (t) async {
    tries++;
    final id = await getActiveWinId();
    if (id != null) {
      // Tam ekran
      await run('wmctrl -i -r $id -b add,fullscreen');
      // Dekorasyonları kapat (birçok WM destekler)
      await run('xprop -id $id -f _MOTIF_WM_HINTS 32c '
          '-set _MOTIF_WM_HINTS "2, 0, 0, 0, 0"');
      t.cancel();
    } else if (tries >= 6) {
      t.cancel();
    }
  });
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
      onSerialLine('button-1'); return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      onSerialLine('button-2'); return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      onSerialLine('button-3'); return true;
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

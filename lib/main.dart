import 'dart:async';
import 'dart:io' show Platform, Process, ProcessResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

// Windows x64 için (Linux ARM'de çağrılmayacak)
import 'package:window_manager/window_manager.dart' as wm;

import 'package:hidrocar_panel/splash_screen.dart';
import 'package:hidrocar_panel/cross_page.dart';
import 'package:hidrocar_panel/back_camera.dart';
import 'package:hidrocar_panel/front_camera.dart';

import 'car_data_service.dart';
import 'car_data.dart';
import 'serial_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
enum CurrentPage { cross, backCamera, frontCamera }
CurrentPage currentPage = CurrentPage.cross;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // İçerik tam ekran; sistem çubukları gizli
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Masaüstü pencereyi ayarla
  await _initWindowKiosk();

  // Kısayol (opsiyonel)
  ServicesBinding.instance.keyboard.addHandler(_handleGlobalKeyEvent);

  // Serial
  _startSerialByPlatform();

  // Simülasyon
  _startSimulatedData();

  runApp(const MyApp());
}

Future<void> _initWindowKiosk() async {
  if (Platform.isWindows) {
    // Windows (x64): window_manager ile frameless+fullscreen
    try {
      await wm.windowManager.ensureInitialized();
      const opts = wm.WindowOptions(
        titleBarStyle: wm.TitleBarStyle.hidden,
        backgroundColor: Colors.black,
      );
      await wm.windowManager.waitUntilReadyToShow(opts, () async {
        await wm.windowManager.setAsFrameless();
        await wm.windowManager.setResizable(false);
        await wm.windowManager.setPreventClose(true);
        await wm.windowManager.setFullScreen(true);
        await wm.windowManager.show();
        await wm.windowManager.focus();
      });
      wm.windowManager.addListener(_WndListener());
    } catch (_) {/* Windows dışında/yoksa sessiz geç */}
  } else if (Platform.isLinux) {
    // Linux (ARM dahil): X11 araçlarıyla tam ekran + dekorasyonsuz
    // Not: Wayland'da çalışmaz; X11/LXDE, XFCE, Openbox gibi WM'lerde çalışır.
    Future<void> run(String cmd) async {
      try { await Process.run('bash', ['-lc', cmd]); } catch (_) {}
    }

    // Pencere görünene kadar kısa bekleyip (500–800ms) uygula
    Future.delayed(const Duration(milliseconds: 700), () async {
      // Tam ekran ve "always on top"
      await run('wmctrl -r :ACTIVE: -b add,fullscreen');
      await run('wmctrl -r :ACTIVE: -b add,above');
      // Dekorasyonları kaldır (birçok WM destekler)
      await run('xprop -id \$(xdotool getactivewindow) '
          '-f _MOTIF_WM_HINTS 32c '
          '-set _MOTIF_WM_HINTS "2, 0, 0, 0, 0"');
    });
  }
}

// Windows’ta kapatmayı engelleme (opsiyonel)
class _WndListener with wm.WindowListener {
  @override
  void onWindowClose() async {
    final prevent = await wm.windowManager.isPreventClose();
    if (prevent) {
      // tam engelle
      return;
    }
  }
}

// ---- Serial başlangıcı ----
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

// ---- Gelen seri satırlar ----
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

// ---- Kısayollar (opsiyonel) ----
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

// ---- Telemetri simülasyonu ----
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

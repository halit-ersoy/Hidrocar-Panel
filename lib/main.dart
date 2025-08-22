import 'dart:async';
import 'dart:io' show Platform; // <-- platform tespiti
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hidrocar_panel/splash_screen.dart';
import 'package:hidrocar_panel/cross_page.dart';
import 'package:hidrocar_panel/back_camera.dart';
import 'package:hidrocar_panel/front_camera.dart';

import 'car_data_service.dart';
import 'car_data.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'serial_service.dart'; // UART/Serial dinleyici

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Track the currently displayed page
enum CurrentPage { cross, backCamera, frontCamera }
CurrentPage currentPage = CurrentPage.cross;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  // Global keyboard handler (optional)
  ServicesBinding.instance.keyboard.addHandler(_handleGlobalKeyEvent);

  // Platforma göre seri haberleşmeyi başlat
  _startSerialByPlatform();

  // Simulated telemetry (UI canlanması için)
  _startSimulatedData();

  runApp(const MyApp());
}

/// Platforma göre doğru seri portu seç ve dinlemeyi başlatır.
void _startSerialByPlatform() {
  final env = Platform.environment;
  final envPort = env['SERIAL_PORT'];

  if (Platform.isLinux) {
    // Mevcut portları al ve logla (teşhis için çok faydalı)
    final ports = SerialPort.availablePorts;
    debugPrint('availablePorts: $ports');

    // 1) ENV ile gelmişse ve listede varsa onu kullan
    String? preferred;
    if (envPort != null && envPort.isNotEmpty && ports.contains(envPort)) {
      preferred = envPort;
    } else {
      // 2) Yaygın Linux/RPi isimleri arasından seç
      preferred = ports.firstWhere(
            (p) => p.contains('/dev/serial0'),
        orElse: () => ports.firstWhere(
              (p) => p.contains('/dev/ttyAMA'),
          orElse: () => ports.firstWhere(
                (p) => p.contains('/dev/ttyS'),
            orElse: () => ports.firstWhere(
                  (p) => p.contains('/dev/ttyUSB'),
              orElse: () => '', // bulunamadı -> otomatiğe bırak
            ),
          ),
        ),
      );
      if (preferred.isEmpty) preferred = null;
    }

    SerialService().start(
      onLine: onSerialLine,
      preferredPortName: preferred ?? '', // yoksa boş ver
      fallbackToAuto: true,               // auto-scan devreye girer
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

/// UART/Serial'dan gelen her satır
void onSerialLine(String line) {
  final msg = line.trim().toLowerCase();
  if (msg.isEmpty) return;

  // Log
  debugPrint('UART/Serial: $msg');

  // Sayfa değiştir
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

// Kısayol tuşları (opsiyonel)
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

// Telemetri simülasyonu (UI canlı kalsın)
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
      batteryPercentage = batteryPercentage + 0.05;
      if (batteryPercentage > 100) batteryPercentage = 100;
    } else {
      batteryPercentage = batteryPercentage - 0.01;
      if (batteryPercentage < 0) batteryPercentage = 0;
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

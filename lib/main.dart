import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hidrocar_panel/splash_screen.dart';
import 'package:hidrocar_panel/cross_page.dart';
import 'package:hidrocar_panel/back_camera.dart';
import 'package:hidrocar_panel/front_camera.dart';

import 'car_data_service.dart';
import 'car_data.dart';
import 'serial_service.dart'; // UART dinleyici

// Global key for navigator to be used across the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Track the currently displayed page
enum CurrentPage { cross, backCamera, frontCamera }

// Global variable to keep track of the current page
CurrentPage currentPage = CurrentPage.cross;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  // Global keyboard handler (isteğe bağlı)
  ServicesBinding.instance.keyboard.addHandler(_handleGlobalKeyEvent);

  runApp(const MyApp());
  _startSimulatedData();

  // >>> SADECE COM11'e bağlan <<<
  SerialService().start(
    onLine: onSerialLine,
    preferredPortName: 'COM11', // <-- Burayı değiştirirsen farklı COM'a bağlanır
    fallbackToAuto: false,       // false = sadece COM11 dene
  );
}

/// UART/Serial'dan gelen her satır buraya gelir
void onSerialLine(String line) {
  final msg = line.trim().toLowerCase();

  // Gelen veriyi logla
  print('UART veri: $msg');

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

// Simulated data for testing when no real port is available
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

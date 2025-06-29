import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidrocar_panel/splash_screen.dart';
import 'package:hidrocar_panel/cross_page.dart';
import 'package:hidrocar_panel/back_camera.dart';
import 'package:hidrocar_panel/front_camera.dart';
import 'car_data_service.dart';
import 'car_data.dart';

// Global key for navigator to be used across the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  // Set up services to listen for key events globally
  ServicesBinding.instance.keyboard.addHandler(_handleGlobalKeyEvent);

  runApp(const MyApp());
  _startSimulatedData();
}

// Global key handler function that works across all screens
bool _handleGlobalKeyEvent(KeyEvent event) {
  if (event is KeyDownEvent) {
    print("Key pressed globally: ${event.logicalKey}");

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      print("F1 pressed - Navigating to CrossPage");
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CrossPage()),
            (route) => false,
      );
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      print("F2 pressed - Navigating to BackCamera");
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BackCamera()),
            (route) => false,
      );
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      print("F3 pressed - Navigating to FrontCamera");
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FrontCamera()),
            (route) => false,
      );
      return true;
    }
  }
  return false; // Let other key events continue to be processed
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Use the global navigator key
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
    // Simulate changing speed
    if (speedIncreasing) {
      speed += 0.5;
      if (speed >= 90) speedIncreasing = false;
    } else {
      speed -= 0.5;
      if (speed <= 0) speedIncreasing = true;
    }

    // Switch between charging and discharging every ~30 seconds
    chargingStateCounter++;
    if (chargingStateCounter >= 300) {
      isCharging = !isCharging;
      chargingStateCounter = 0;
    }

    // Update battery percentage based on charging state
    if (isCharging) {
      batteryPercentage = batteryPercentage + 0.05;
      if (batteryPercentage > 100) batteryPercentage = 100;
    } else {
      batteryPercentage = batteryPercentage - 0.01;
      if (batteryPercentage < 0) batteryPercentage = 0;
    }

    // Update car data
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
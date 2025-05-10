import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hidrocar_panel/cross_page.dart';
import 'package:hidrocar_panel/listen_port.dart';
import 'car_data_service.dart';
import 'back_camera.dart';
import 'car_data.dart';

void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: CrossPage(),
    ),
  ));
  _startSimulatedData();
}

// Simulated data for testing when no real port is available
void _startSimulatedData() {
  double batteryPercentage = 50;
  double speed = 0;
  bool speedIncreasing = true;
  bool isCharging = true;
  int chargingStateCounter = 0;

  // In _startSimulatedData method, occasionally simulate warning conditions
// For example:
  Timer.periodic(Duration(seconds: 1), (timer) {
    // Every 20 seconds, simulate a warning condition for testing
    if (timer.tick % 3 == 0) {
      // Low isolation resistance
      CarDataService().updateData(CarData(
        batteryPercentage: batteryPercentage,
        remainingEnergy: batteryPercentage * 20,
        chargePower: isCharging ? 500 : 0,
        batteryCurrent: isCharging ? 12 : 8,
        batteryVoltage: 78,
        batteryTemperature: 55,
        isolationResistance: 25, // Red warning (< 30)
        speed: speed,
      ));
    } else if (timer.tick % 3 == 1) {
      // High battery temperature
      CarDataService().updateData(CarData(
        batteryPercentage: batteryPercentage,
        remainingEnergy: batteryPercentage * 20,
        chargePower: isCharging ? 500 : 0,
        batteryCurrent: isCharging ? 12 : 8,
        batteryVoltage: 78,
        batteryTemperature: 82, // Red warning (> 75)
        isolationResistance: 60,
        speed: speed,
      ));
    } else if (timer.tick % 3 == 2) {
      // Critical condition
      CarDataService().updateData(CarData(
        batteryPercentage: batteryPercentage,
        remainingEnergy: batteryPercentage * 20,
        chargePower: isCharging ? 500 : 0,
        batteryCurrent: isCharging ? 12 : 8,
        batteryVoltage: 78,
        batteryTemperature: 55,
        isolationResistance: 8, // Critical warning (< 10)
        speed: speed,
      ));
    }
  });
}
// lib/models/car_data.dart
class CarData {
  final double batteryPercentage;
  final double remainingEnergy;
  final double chargePower;
  final double batteryCurrent;
  final double batteryVoltage;
  final double batteryTemperature;
  final double isolationResistance;
  final double speed;

  CarData({
    this.batteryPercentage = 0,
    this.remainingEnergy = 0,
    this.chargePower = 0,
    this.batteryCurrent = 0,
    this.batteryVoltage = 0,
    this.batteryTemperature = 0,
    this.isolationResistance = 0,
    this.speed = 0,
  });
}
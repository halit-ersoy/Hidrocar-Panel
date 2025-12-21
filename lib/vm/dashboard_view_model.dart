// lib/view_model/dashboard_view_model.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/car_data.dart';
import '../services/car_data_service.dart';

// Uyarı seviyelerini burada tanımlayabiliriz
enum WarningLevel { normal, yellow, red }

class DashboardViewModel extends ChangeNotifier {
  final CarDataService _service = CarDataService();
  late StreamSubscription<CarData> _dataSubscription;
  late StreamSubscription _timerSubscription;

  CarData _carData = CarData();
  String _currentTime = "";

  // View'ın erişeceği veriler (Getters)
  CarData get carData => _carData;
  String get currentTime => _currentTime;

  // Başlatıcı
  DashboardViewModel() {
    _listenToData();
    _startClock();
  }

  void _listenToData() {
    _dataSubscription = _service.dataStream.listen((data) {
      _carData = data;
      notifyListeners(); // View'a "Veri değişti, kendini güncelle" der.
    });
  }

  void _startClock() {
    _timerSubscription = Stream.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      return "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')}";
    }).listen((timeString) {
      _currentTime = timeString;
      notifyListeners();
    });
  }

  // --- İŞ MANTIĞI (BUSINESS LOGIC) BURAYA TAŞINDI ---

  // Kritik uyarı var mı?
  bool get hasCriticalWarning =>
      _carData.isolationResistance < 10 || _carData.batteryTemperature > 90;

  // Kritik uyarı mesajı nedir?
  String get criticalMessage {
    if (_carData.isolationResistance < 10) {
      return "İzolasyon Direnci Kritik Seviyede!\n${_carData.isolationResistance.toInt()}Ω";
    }
    if (_carData.batteryTemperature > 90) {
      return "Batarya Sıcaklığı Kritik Seviyede!\n${_carData.batteryTemperature.toInt()}°C";
    }
    return "";
  }

  // Şarj durumu metni
  String? get estimatedChargeTimeText {
    if (_carData.chargePower <= 0) return null;

    final remainingPercentage = 100 - _carData.batteryPercentage;
    final powerKw = _carData.chargePower / 1000;
    if (powerKw == 0) return null;

    // Basit bir hesaplama mantığı (Örnek)
    final totalHours = remainingPercentage / (powerKw * 2);
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).floor();

    return 'Dolum: $hours saat $minutes dk';
  }

  // Renk ve Uyarı Mantıkları
  WarningLevel get isolationLevel {
    if (_carData.isolationResistance < 30) return WarningLevel.red;
    if (_carData.isolationResistance < 50) return WarningLevel.yellow;
    return WarningLevel.normal;
  }

  WarningLevel get tempLevel {
    if (_carData.batteryTemperature > 75) return WarningLevel.red;
    if (_carData.batteryTemperature > 60) return WarningLevel.yellow;
    return WarningLevel.normal;
  }

  // UI Yardımcıları (Renkleri buradan yönetmek daha temizdir)
  Color get batteryIconColor =>
      _carData.chargePower > 0 ? Colors.greenAccent : Colors.orange;

  IconData get batteryIcon =>
      _carData.chargePower > 0 ? Icons.battery_charging_full : Icons.battery_full;

  @override
  void dispose() {
    _dataSubscription.cancel();
    _timerSubscription.cancel();
    super.dispose();
  }
}
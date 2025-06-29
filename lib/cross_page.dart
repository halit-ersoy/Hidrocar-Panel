import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hidrocar_panel/ui/painter/speedometer.dart';
import 'car_data_service.dart';
import 'car_data.dart';
import 'function_key.dart';

class CrossPage extends StatefulWidget {
  const CrossPage({super.key});

  @override
  State<CrossPage> createState() => _CrossPageState();
}

// Add enum for warning levels
enum WarningLevel { yellow, red, critical }

class _CrossPageState extends State<CrossPage> {
  CarData _carData = CarData();
  late final StreamSubscription<CarData> _dataSubscription;
  late final Stream<String> _timeStream;

  @override
  void initState() {
    super.initState();
    _dataSubscription = CarDataService().dataStream.listen((data) {
      setState(() {
        _carData = data;
      });
    });

    // Initialize time stream once
    _timeStream = Stream.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      return "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')}";
    });
  }

  @override
  void dispose() {
    _dataSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check for critical warnings
    bool hasCriticalWarning = false;
    String criticalMessage = "";

    // Check isolation resistance critical
    if (_carData.isolationResistance < 10) {
      hasCriticalWarning = true;
      criticalMessage =
          "İzolasyon Direnci Kritik Seviyede!\n${_carData.isolationResistance.toInt()}Ω";
    }

    // Check battery temperature critical
    if (_carData.batteryTemperature > 90) {
      hasCriticalWarning = true;
      criticalMessage =
          "Batarya Sıcaklığı Kritik Seviyede!\n${_carData.batteryTemperature.toInt()}°C";
    }

    // Determine warning levels
    WarningLevel? isolationWarningLevel;
    if (_carData.isolationResistance < 30) {
      isolationWarningLevel = WarningLevel.red;
    } else if (_carData.isolationResistance < 50) {
      isolationWarningLevel = WarningLevel.yellow;
    }

    WarningLevel? temperatureWarningLevel;
    if (_carData.batteryTemperature > 75) {
      temperatureWarningLevel = WarningLevel.red;
    } else if (_carData.batteryTemperature > 60) {
      temperatureWarningLevel = WarningLevel.yellow;
    }

    return Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.black, Colors.blue.shade900],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.02),
                      child: Column(
                        children: [
                          _buildTopSection(),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 35,
                                  child: _buildLeftPanel(context),
                                ),
                                Expanded(
                                  flex: 50,
                                  child: _buildCenterSpeedometer(screenHeight),
                                ),
                                Expanded(
                                  flex: 35,
                                  child: _buildRightPanel(
                                    context,
                                    isolationWarningLevel:
                                        isolationWarningLevel,
                                    temperatureWarningLevel:
                                        temperatureWarningLevel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Show critical warning overlay if needed
                if (hasCriticalWarning)
                  Positioned.fill(
                    child: _buildCriticalWarning(criticalMessage),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: Colors.blue.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FunctionKey(
                                label: 'F1',
                                description: 'Ana Ekran',
                                isActive: true),
                            SizedBox(width: 16),
                            FunctionKey(
                                label: 'F2', description: 'Arka Kamera'),
                            SizedBox(width: 16),
                            FunctionKey(label: 'F3', description: 'Ön Kamera'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ));
  }

  Widget _buildTopSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, color: Colors.blue.shade300, size: 32),
          const SizedBox(width: 12),
          StreamBuilder<String>(
            stream: _timeStream,
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? DateTime.now().toString().substring(11, 19),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSpeedometer(double screenHeight) {
    return Center(
      child: Container(
        width: screenHeight * 0.55,
        height: screenHeight * 0.55,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
          border: Border.all(
            color: Colors.blue.shade700.withOpacity(0.6),
            width: 3,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Speedometer(value: _carData.speed),
        ),
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    // Determine if battery is charging based on charge power
    final bool isCharging = _carData.chargePower > 0;

    // Calculate estimated time text
    String? estimatedTimeText;
    if (isCharging) {
      // Calculate time to full charge (remaining percentage to 100%)
      final remainingPercentage = 100 - _carData.batteryPercentage;
      // Assuming charging rate is proportional to charge power
      final timeToFullHours =
          (remainingPercentage / ((_carData.chargePower / 1000) * 2)).floor();
      final timeToFullMinutes =
          ((remainingPercentage / ((_carData.chargePower / 1000) * 2) -
                      timeToFullHours) *
                  60)
              .floor();
      estimatedTimeText = 'Dolum: $timeToFullHours saat $timeToFullMinutes dk';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.blue.shade500.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEnhancedInfoRow(
              icon:
                  isCharging ? Icons.battery_charging_full : Icons.battery_full,
              title: 'Batarya Yüzdesi',
              value: '%${_carData.batteryPercentage.toInt()}',
              additionalInfo: estimatedTimeText,
              iconColor: isCharging ? Colors.greenAccent : Colors.orange,
            ),
            Divider(color: Colors.blue.withOpacity(0.3), height: 1),
            _buildEnhancedInfoRow(
              icon: Icons.electric_bolt,
              title: 'Kalan Enerji',
              value: '${_carData.remainingEnergy.toInt()}Wh',
              iconColor: Colors.orangeAccent,
            ),
            Divider(color: Colors.blue.withOpacity(0.3), height: 1),
            _buildEnhancedInfoRow(
              icon: Icons.electrical_services,
              title: 'Şarj Gücü',
              value: '${_carData.chargePower.toInt()}W',
              iconColor: isCharging ? Colors.greenAccent : Colors.purpleAccent,
            ),
            Divider(color: Colors.blue.withOpacity(0.3), height: 1),
            _buildEnhancedInfoRow(
              icon: Icons.electrical_services,
              title: 'Batarya Akımı',
              value: '${_carData.batteryCurrent.toInt()}A',
              iconColor: Colors.yellowAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(
    BuildContext context, {
    WarningLevel? temperatureWarningLevel,
    WarningLevel? isolationWarningLevel,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.blue.shade500.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEnhancedInfoRow(
              icon: Icons.bolt,
              title: 'Batarya Gerilimi',
              value: '${_carData.batteryVoltage.toInt()}V',
              iconColor: Colors.redAccent,
            ),
            Divider(color: Colors.blue.withOpacity(0.3), height: 1),
            _buildEnhancedInfoRow(
              icon: Icons.thermostat,
              title: 'Batarya Sıcaklığı',
              value: '${_carData.batteryTemperature.toInt()}°C',
              iconColor: Colors.deepOrangeAccent,
              warningLevel: temperatureWarningLevel,
            ),
            Divider(color: Colors.blue.withOpacity(0.3), height: 1),
            _buildEnhancedInfoRow(
              icon: Icons.shield,
              title: 'İzolasyon Direnci',
              value: '${_carData.isolationResistance.toInt()}Ω',
              iconColor: Colors.tealAccent,
              warningLevel: isolationWarningLevel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedInfoRow({
    required IconData icon,
    required String title,
    required String value,
    String? additionalInfo,
    required Color iconColor,
    WarningLevel? warningLevel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.blue.shade100,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    if (additionalInfo != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        additionalInfo,
                        style: TextStyle(
                          color: Colors.blue.shade200,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (warningLevel != null) ...[
            Icon(
              Icons.warning_amber_rounded,
              color: warningLevel == WarningLevel.yellow
                  ? Colors.amber
                  : Colors.red,
              size: 48,
            ),
          ],
        ],
      ),
    );
  }

  // Critical warning overlay widget
  Widget _buildCriticalWarning(String message) {
    return Container(
      color: Colors.red.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              "KRİTİK UYARI",
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

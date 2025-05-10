import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hidrocar_panel/cross_page.dart';
import 'package:hidrocar_panel/listen_port.dart';
import 'car_data_service.dart';
import 'back_camera.dart';
import 'car_data.dart';

void main() {
  runApp(const MyApp());
  _startSimulatedData();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _showStatusChecks = false;
  bool _showBootComplete = false;
  final List<String> _systemChecks = [
    "Batarya sistemi başlatılıyor...",
    "İzolasyon kontrol ediliyor...",
    "Termal yönetim başlatılıyor...",
    "Sürüş sistemi hazırlanıyor...",
    "Gösterge paneli yükleniyor..."
  ];
  List<bool> _checkComplete = [false, false, false, false, false];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.5, curve: Curves.easeIn))
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.5, curve: Curves.easeOutBack))
    );

    _startAnimation();
  }

  void _startAnimation() async {
    await _controller.forward();

    setState(() {
      _showStatusChecks = true;
    });

    // Show system checks one by one
    for (int i = 0; i < _systemChecks.length; i++) {
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        _checkComplete[i] = true;
      });
    }

    // Show boot complete message
    await Future.delayed(Duration(milliseconds: 600));
    setState(() {
      _showBootComplete = true;
    });

    // Navigate to main screen
    await Future.delayed(Duration(milliseconds: 800));
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 1000),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: CrossPage(),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Colors.blue.shade900],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo animation
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.6 * _fadeAnimation.value),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.electric_car,
                              size: 80,
                              color: Colors.blue.shade300,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "HIDROCAR",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 50),

              // System checks
              if (_showStatusChecks)
                Container(
                  width: 300,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blue.shade700.withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _systemChecks.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              _checkComplete[i]
                                  ? Icon(Icons.check_circle, color: Colors.green, size: 18)
                                  : SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _systemChecks[i],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_showBootComplete)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Text(
                            "SİSTEM HAZIR",
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
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

  Timer.periodic(Duration(milliseconds: 100), (timer) {
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
      batteryPercentage = batteryPercentage + 0.05; // Charge faster than discharge
      if (batteryPercentage > 100) batteryPercentage = 100;
    } else {
      batteryPercentage = batteryPercentage - 0.01;
      if (batteryPercentage < 0) batteryPercentage = 0;
    }

    // Update car data
    CarDataService().updateData(CarData(
      batteryPercentage: batteryPercentage,
      remainingEnergy: batteryPercentage * 20, // 2000Wh at 100%
      chargePower: isCharging ? 500 : 0, // 500W when charging, 0 when not
      batteryCurrent: isCharging ? 12 : 8,
      batteryVoltage: 78,
      batteryTemperature: isCharging ? 91 : 50, // Temperature rises during charging
      isolationResistance: 1,
      speed: speed,
    ));
  });
}
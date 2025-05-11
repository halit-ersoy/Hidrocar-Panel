import 'dart:async';
import 'dart:math';
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
  late Animation<double> _rotateAnimation;
  late Animation<double> _pulseAnimation;

  bool _showStatusChecks = false;
  bool _showBootComplete = false;
  double _bootProgress = 0.0;

  final List<String> _systemChecks = [
    "Batarya sistemi başlatılıyor...",
    "İzolasyon kontrol ediliyor...",
    "Termal yönetim başlatılıyor...",
    "Sürüş sistemi hazırlanıyor...",
    "Gösterge paneli yükleniyor..."
  ];
  List<bool> _checkComplete = [false, false, false, false, false];
  List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.5, curve: Curves.easeIn))
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.5, curve: Curves.elasticOut))
    );

    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(0.1, 0.5, curve: Curves.elasticOut))
    );

    _pulseAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.5, 1.0, curve: Curves.easeInOut),
    ));

    // Generate particles
    _generateParticles();

    _startAnimation();
  }

  void _generateParticles() {
    final random = Random();
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle(
        x: random.nextDouble() * 400 - 200,
        y: random.nextDouble() * 400 - 200,
        size: random.nextDouble() * 4 + 1,
        speed: random.nextDouble() * 1.5 + 0.5,
        opacity: random.nextDouble() * 0.6 + 0.2,
      ));
    }
  }

  void _startAnimation() async {
    await _controller.forward();

    setState(() {
      _showStatusChecks = true;
    });

    // Show system checks one by one with progress updates
    for (int i = 0; i < _systemChecks.length; i++) {
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        _checkComplete[i] = true;
        _bootProgress = (i + 1) / _systemChecks.length;
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
        transitionDuration: Duration(milliseconds: 1200),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: Scaffold(
                backgroundColor: Colors.black,
                body: CrossPage(),
              ),
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
      body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Update particle positions
            for (var particle in _particles) {
              particle.y -= particle.speed;
              if (particle.y < -200) particle.y = 200;
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, Colors.blue.shade900],
                ),
              ),
              child: Stack(
                children: [
                  // Particles
                  ...(_particles.map((p) => Positioned(
                    left: MediaQuery.of(context).size.width / 2 + p.x,
                    top: MediaQuery.of(context).size.height / 2 + p.y,
                    child: Opacity(
                      opacity: p.opacity * _fadeAnimation.value,
                      child: Container(
                        width: p.size,
                        height: p.size,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ))),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo animation
                        Transform.rotate(
                          angle: _rotateAnimation.value * pi,
                          child: Transform.scale(
                            scale: _scaleAnimation.value * _pulseAnimation.value,
                            child: Opacity(
                              opacity: _fadeAnimation.value,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.6 * _fadeAnimation.value),
                                      blurRadius: 30 + (10 * _pulseAnimation.value),
                                      spreadRadius: 10 + (2 * _pulseAnimation.value),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/logo2.png',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 50),

                        // System checks
                        if (_showStatusChecks)
                          AnimatedOpacity(
                            opacity: _showStatusChecks ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 500),
                            child: Container(
                              width: 320,
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.blue.shade700.withOpacity(0.6),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade900.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Overall progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _bootProgress,
                                      minHeight: 10,
                                      backgroundColor: Colors.black45,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          _bootProgress == 1.0 ? Colors.green : Colors.blue.shade400),
                                    ),
                                  ),

                                  SizedBox(height: 20),

                                  for (int i = 0; i < _systemChecks.length; i++)
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      margin: EdgeInsets.symmetric(vertical: 6.0),
                                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                      decoration: BoxDecoration(
                                        color: _checkComplete[i] ? Colors.blue.withOpacity(0.15) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _checkComplete[i] ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _checkComplete[i]
                                              ? TweenAnimationBuilder(
                                            duration: Duration(milliseconds: 500),
                                            tween: Tween<double>(begin: 0.0, end: 1.0),
                                            builder: (context, value, child) {
                                              return Transform.scale(
                                                scale: value,
                                                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                                              );
                                            },
                                          )
                                              : SizedBox(
                                            width: 20,
                                            height: 20,
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
                                                color: _checkComplete[i]
                                                    ? Colors.white
                                                    : Colors.white.withOpacity(0.7),
                                                fontSize: 14,
                                                fontWeight: _checkComplete[i] ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (_showBootComplete)
                                    TweenAnimationBuilder(
                                      duration: Duration(milliseconds: 800),
                                      tween: Tween<double>(begin: 0.0, end: 1.0),
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 20.0),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(30),
                                                border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle_outline, color: Colors.green),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "SİSTEM HAZIR",
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}

// Particle class for background effect
class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Simulated data for testing when no real port is available
void _startSimulatedData() {
  // [Existing simulation code remains the same]
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
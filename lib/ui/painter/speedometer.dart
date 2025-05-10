import 'dart:math';
import 'package:flutter/material.dart';

class Speedometer extends StatefulWidget {
  final double value; // 0 ile 90 arasında

  const Speedometer({super.key, required this.value});

  @override
  State<Speedometer> createState() => _SpeedometerState();
}

class _SpeedometerState extends State<Speedometer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: _currentValue, end: widget.value)
        .animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ))
      ..addListener(() {
        setState(() {
          _currentValue = _animation.value;
        });
      });
    _animationController.forward();
  }

  @override
  void didUpdateWidget(Speedometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _currentValue, end: widget.value)
          .animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SpeedometerPainter(_currentValue),
      size: const Size(400, 400),
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double value; // 0..90 arası

  SpeedometerPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final center = Offset(centerX, centerY);
    final radius = size.width / 2;

    // 1) Ark (270 derecelik yay) - alt-sol (135°) -> alt-sağ (405°)
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final startAngle = degToRad(132);
    final sweepAngle = degToRad(276);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // 2) Skala tıkları ve rakamlar: 0..90
    for (int speedValue = 0; speedValue <= 90; speedValue += 10) {
      final angleDeg = 135.0 + 3 * speedValue;
      final angleRad = degToRad(angleDeg);

      // Tıklar (kısa çizgiler)
      final tickStart = Offset(
        centerX + (radius - 15) * cos(angleRad),
        centerY + (radius - 15) * sin(angleRad),
      );
      final tickEnd = Offset(
        centerX + radius * cos(angleRad),
        centerY + radius * sin(angleRad),
      );

      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3,
      );

      // Rakamlar
      final textSpan = TextSpan(
        text: speedValue.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      const labelOffset = 30.0;
      final labelX = centerX +
          (radius - labelOffset) * cos(angleRad) -
          textPainter.width / 2;
      final labelY = centerY +
          (radius - labelOffset) * sin(angleRad) -
          textPainter.height / 2;

      textPainter.paint(canvas, Offset(labelX, labelY));
    }

    // 3) İbre (kırmızı ok)
    final currentAngleDeg = 135 + 3 * value;
    final currentAngleRad = degToRad(currentAngleDeg);

    final needleStart = center;
    final needleLength = radius - 30;
    final needleEnd = Offset(
      centerX + needleLength * cos(currentAngleRad),
      centerY + needleLength * sin(currentAngleRad),
    );

    canvas.drawLine(
      needleStart,
      needleEnd,
      Paint()
        ..color = Colors.red
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // İbrenin merkezine ufak daire
    canvas.drawCircle(
      center,
      10,
      Paint()..color = Colors.red,
    );

    // 4) Alt kısımda "X km/h" metni
    final speedText = '${value.toStringAsFixed(0)} km/h';
    final speedTextPainter = TextPainter(
      text: TextSpan(
        text: speedText,
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    speedTextPainter.layout();

    final textOffset = Offset(
      centerX - (speedTextPainter.width / 2),
      centerY + 100,
    );
    speedTextPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  double degToRad(double deg) => deg * pi / 180;
}
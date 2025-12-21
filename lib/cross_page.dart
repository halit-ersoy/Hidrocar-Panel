// lib/cross_page.dart
import 'package:flutter/material.dart';
import 'package:hidrocar_panel/ui/painter/speedometer.dart';
import 'package:hidrocar_panel/vm/dashboard_view_model.dart';
import 'function_key.dart';
// ViewModel'i import et

class CrossPage extends StatefulWidget {
  const CrossPage({super.key});

  @override
  State<CrossPage> createState() => _CrossPageState();
}

class _CrossPageState extends State<CrossPage> {
  // ViewModel'i tanımla
  late final DashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardViewModel(); // ViewModel başlatılıyor
  }

  @override
  void dispose() {
    _viewModel.dispose(); // Bellek sızıntısını önle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder, ViewModel'de "notifyListeners()" denildiğinde burayı yeniden çizer.
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        // Artık verileri _viewModel üzerinden alıyoruz
        return Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
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
                        padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                        child: Column(
                          children: [
                            _buildTopSection(),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 35,
                                    child: _buildLeftPanel(),
                                  ),
                                  Expanded(
                                    flex: 50,
                                    child: _buildCenterSpeedometer(constraints.maxHeight),
                                  ),
                                  Expanded(
                                    flex: 35,
                                    child: _buildRightPanel(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Kritik Uyarı Katmanı (Logic artık ViewModel'de)
                  if (_viewModel.hasCriticalWarning)
                    Positioned.fill(
                      child: _buildCriticalWarning(_viewModel.criticalMessage),
                    ),

                  // Alt Fonksiyon Tuşları
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _buildBottomBar(),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, color: Colors.blue.shade300, size: 32),
          const SizedBox(width: 12),
          Text(
            _viewModel.currentTime, // ViewModel'den geliyor
            style: const TextStyle(
              color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 2,
            ),
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
            BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 30, spreadRadius: 10),
          ],
          border: Border.all(color: Colors.blue.shade700.withOpacity(0.6), width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          // Hız verisi ViewModel'den
          child: Speedometer(value: _viewModel.carData.speed),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return _buildPanelContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildEnhancedInfoRow(
            icon: _viewModel.batteryIcon,
            title: 'Batarya Yüzdesi',
            value: '%${_viewModel.carData.batteryPercentage.toInt()}',
            additionalInfo: _viewModel.estimatedChargeTimeText,
            iconColor: _viewModel.batteryIconColor,
          ),
          _buildDivider(),
          _buildEnhancedInfoRow(
            icon: Icons.electric_bolt,
            title: 'Kalan Enerji',
            value: '${_viewModel.carData.remainingEnergy.toInt()}Wh',
            iconColor: Colors.orangeAccent,
          ),
          _buildDivider(),
          _buildEnhancedInfoRow(
            icon: Icons.electrical_services,
            title: 'Şarj Gücü',
            value: '${_viewModel.carData.chargePower.toInt()}W',
            iconColor: Colors.purpleAccent, // İstersen bunu da VM'e taşıyabilirsin
          ),
          _buildDivider(),
          _buildEnhancedInfoRow(
            icon: Icons.electrical_services,
            title: 'Batarya Akımı',
            value: '${_viewModel.carData.batteryCurrent.toInt()}A',
            iconColor: Colors.yellowAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    return _buildPanelContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildEnhancedInfoRow(
            icon: Icons.bolt,
            title: 'Batarya Gerilimi',
            value: '${_viewModel.carData.batteryVoltage.toInt()}V',
            iconColor: Colors.redAccent,
          ),
          _buildDivider(),
          _buildEnhancedInfoRow(
            icon: Icons.thermostat,
            title: 'Batarya Sıcaklığı',
            value: '${_viewModel.carData.batteryTemperature.toInt()}°C',
            iconColor: Colors.deepOrangeAccent,
            warningLevel: _viewModel.tempLevel, // ViewModel'den geliyor
          ),
          _buildDivider(),
          _buildEnhancedInfoRow(
            icon: Icons.shield,
            title: 'İzolasyon Direnci',
            value: '${_viewModel.carData.isolationResistance.toInt()}Ω',
            iconColor: Colors.tealAccent,
            warningLevel: _viewModel.isolationLevel, // ViewModel'den geliyor
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Widget Metotları (Değişmedi, sadece sadeleşti) ---

  Widget _buildPanelContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.shade500.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.blue.shade900.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _buildDivider() => Divider(color: Colors.blue.withOpacity(0.3), height: 1);

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FunctionKey(label: 'F1', description: 'Ana Ekran', isActive: true),
              const SizedBox(width: 16),
              FunctionKey(label: 'F2', description: 'Arka Kamera'),
              const SizedBox(width: 16),
              FunctionKey(label: 'F3', description: 'Ön Kamera'),
            ],
          ),
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
    // Bu kısım UI gösterimi olduğu için burada kalabilir.
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
                Text(title, style: TextStyle(color: Colors.blue.shade100, fontSize: 16, fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    if (additionalInfo != null) ...[
                      const SizedBox(width: 8),
                      Text(additionalInfo, style: TextStyle(color: Colors.blue.shade200, fontSize: 14)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (warningLevel != null && warningLevel != WarningLevel.normal) ...[
            Icon(
              Icons.warning_amber_rounded,
              color: warningLevel == WarningLevel.yellow ? Colors.amber : Colors.red,
              size: 48,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriticalWarning(String message) {
    return Container(
      color: Colors.red.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 100),
            const SizedBox(height: 20),
            const Text("KRİTİK UYARI", style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
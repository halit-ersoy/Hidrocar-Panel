import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// COM (Windows) / tty (Linux/macOS) seri port dinleyicisi.
/// - preferredPortName verilirse önce onu dener (örn: "COM11").
/// - fallbackToAuto = true ise hedef açılamazsa otomatik port arar.
class SerialService {
  static final SerialService _inst = SerialService._();
  factory SerialService() => _inst;
  SerialService._();

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _sub;

  final _buf = BytesBuilder(copy: false);
  Timer? _retryTimer;

  bool get isOpen => _port?.isOpen == true;

  void start({
    required void Function(String line) onLine,
    String? preferredPortName, // örn: 'COM11'
    bool fallbackToAuto = true,
  }) {
    if (isOpen) return;

    _tryOpenPort(onLine, preferredPortName: preferredPortName, fallbackToAuto: fallbackToAuto);

    // Eğer bağlanamazsa periyodik dene
    _retryTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (!isOpen) {
        _tryOpenPort(onLine, preferredPortName: preferredPortName, fallbackToAuto: fallbackToAuto);
      }
    });
  }

  void stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _close();
  }

  void _close() {
    _sub?.cancel();
    _sub = null;
    _reader?.close();
    _reader = null;
    try {
      _port?.close();
    } catch (_) {}
    _port?.dispose();
    _port = null;
    _buf.clear();
  }

  void _tryOpenPort(
      void Function(String) onLine, {
        String? preferredPortName,
        required bool fallbackToAuto,
      }) {
    String? name;

    // 1) Önce tercih edilen portu dene (ör: COM11)
    if (preferredPortName != null && preferredPortName.isNotEmpty) {
      name = _resolvePreferred(preferredPortName);
      if (name == null) {
        debugPrint('SerialService: preferred "$preferredPortName" bulunamadı.');
        if (!fallbackToAuto) {
          return; // sadece bunu dene, otomatiğe düşme
        }
      }
    }

    // 2) Tercih edilen bulunamadı/yoksa otomatik seç
    name ??= _pickBestPortName();
    if (name == null) {
      debugPrint('SerialService: uygun port yok.');
      return;
    }

    final port = SerialPort(name);
    if (!port.openReadWrite()) {
      debugPrint('SerialService: $name acilamadi.');
      port.dispose();
      return;
    }

    final cfg = SerialPortConfig()
      ..baudRate = 9600
      ..bits = 8
      ..parity = 0
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);
    port.config = cfg;

    _port = port;
    _reader = SerialPortReader(port, timeout: 200);
    _sub = _reader!.stream.listen(
          (data) => _onBytes(data, onLine),
      onError: (e, st) {
        debugPrint('SerialService error: $e');
        _close();
      },
      onDone: () {
        _close();
      },
    );

    debugPrint('SerialService: connected to $name');
  }

  /// Tercih edilen port adını (örn. COM11) sistemdeki gerçek adlarla eşleştirir.
  String? _resolvePreferred(String preferred) {
    final want = preferred.toLowerCase().trim();
    for (final p in SerialPort.availablePorts) {
      if (p.toLowerCase().trim() == want) return p;
    }
    // Bazı durumlarda flutter_libserialport listede yokken de açılabiliyor;
    // yine de adı direkt döndürelim ve deneyelim.
    return preferred;
  }

  /// Otomatik port seçimi: açıklaması USB/Serial olan ilk port
  String? _pickBestPortName() {
    final ports = SerialPort.availablePorts;
    if (ports.isEmpty) return null;

    String? candidate;
    for (final name in ports) {
      final p = SerialPort(name);
      final desc = (p.description ?? '').toLowerCase();
      final vid = p.vendorId?.toRadixString(16) ?? '';

      final looksLikeUsbUart = [
        'usb',
        'serial',
        'ch340',
        'wch',
        'cp210',
        'silabs',
        'ftdi',
        'usb-serial',
        'arduino',
      ].any((k) => desc.contains(k));

      const knownVids = {'1a86', '10c4', '0403', '2341'}; // WCH, SiLabs, FTDI, Arduino
      final known = knownVids.contains(vid);

      if (looksLikeUsbUart || known) {
        candidate = name;
        break;
      }
    }

    candidate ??= ports.first;
    return candidate;
  }

  void _onBytes(Uint8List data, void Function(String) onLine) {
    _buf.add(data);
    _drainFramed(onLine);
    _drainLines(onLine);
  }

  // "<...>" şeklindeki mesajları ayıkla
  void _drainFramed(void Function(String) onLine) {
    final bytes = _buf.toBytes();
    if (bytes.isEmpty) return;

    final s = const AsciiDecoder(allowInvalid: true).convert(bytes);
    int start = s.indexOf('<');
    int end = s.indexOf('>', start + 1);
    if (start == -1 || end == -1) return;

    var tmp = s;
    final lines = <String>[];
    while (true) {
      start = tmp.indexOf('<');
      if (start == -1) break;
      end = tmp.indexOf('>', start + 1);
      if (end == -1) break;

      final inner = tmp.substring(start + 1, end).trim();
      if (inner.isNotEmpty) lines.add(inner);
      tmp = tmp.substring(end + 1);
    }

    _buf.clear();
    _buf.add(ascii.encode(tmp));

    for (final l in lines) {
      onLine(l);
    }
  }

  // Satır sonu ile biten mesajları ayıkla
  void _drainLines(void Function(String) onLine) {
    final bytes = _buf.toBytes();
    if (bytes.isEmpty) return;

    final s = const AsciiDecoder(allowInvalid: true).convert(bytes);
    if (!s.contains('\n')) return;

    final normalized = s.replaceAll('\r', '');
    final parts = normalized.split('\n');
    final tail = parts.removeLast();

    for (final p in parts) {
      final line = p.trim();
      if (line.isNotEmpty) onLine(line);
    }

    _buf.clear();
    _buf.add(ascii.encode(tail));
  }
}

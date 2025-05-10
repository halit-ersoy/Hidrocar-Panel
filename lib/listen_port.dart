import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class ListenPort {
  final String portName;
  late SerialPort port;
  late SerialPortReader reader;
  String buffer = "";
  final StreamController<String> _controller = StreamController.broadcast();

  ListenPort(this.portName) {
    port = SerialPort(portName);
    if (!port.openReadWrite()) {
      throw Exception("Failed to open port: $portName");
    }
    reader = SerialPortReader(port);
    _startListening();
  }

  void _startListening() {
    reader.stream.listen((data) {
      buffer += String.fromCharCodes(data);

      while (buffer.contains("<") && buffer.contains(">")) {
        final start = buffer.indexOf("<");
        final end = buffer.indexOf(">");

        if (start < end) {
          final output = buffer.substring(start + 1, end).trim();
          _controller.add(output);
          buffer = buffer.substring(end + 1);
        } else {
          buffer = buffer.substring(start);
        }
      }
    }, onError: (error) {
      print("Error: $error");
    });
  }

  Stream<String> get stream => _controller.stream;

  void close() {
    port.close();
    _controller.close();
  }
}

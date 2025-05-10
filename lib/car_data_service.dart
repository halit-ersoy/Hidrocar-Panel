// lib/services/car_data_service.dart
import 'dart:async';

import 'car_data.dart';

class CarDataService {
  static final CarDataService _instance = CarDataService._internal();
  factory CarDataService() => _instance;
  CarDataService._internal();

  final _dataController = StreamController<CarData>.broadcast();
  Stream<CarData> get dataStream => _dataController.stream;

  void updateData(CarData data) {
    _dataController.add(data);
  }

  void dispose() {
    _dataController.close();
  }
}
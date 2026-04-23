import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'sensor_decoder.dart';

class SensorThresholds {
  final double pressureMin;
  final double pressureMax;
  final double temperatureMax;
  final int batteryMin;

  SensorThresholds({
    required this.pressureMin,
    required this.pressureMax,
    required this.temperatureMax,
    required this.batteryMin,
  });

  Map<String, dynamic> toJson() {
    return {
      'pressureMin': pressureMin,
      'pressureMax': pressureMax,
      'temperatureMax': temperatureMax,
      'batteryMin': batteryMin,
    };
  }

  factory SensorThresholds.fromJson(Map<String, dynamic> json) {
    return SensorThresholds(
      pressureMin: (json['pressureMin'] ?? 30.0).toDouble(),
      pressureMax: (json['pressureMax'] ?? 35.0).toDouble(),
      temperatureMax: (json['temperatureMax'] ?? 80.0).toDouble(),
      batteryMin: json['batteryMin'] ?? 20,
    );
  }

  factory SensorThresholds.defaultValues() {
    return SensorThresholds(
      pressureMin: 30.0,
      pressureMax: 35.0,
      temperatureMax: 80.0,
      batteryMin: 20,
    );
  }
}

class BoundSensor {
  final String wheelLabel;
  final String sensorId;
  final String deviceId;
  final SensorThresholds thresholds;
  final DateTime boundAt;

  BoundSensor({
    required this.wheelLabel,
    required this.sensorId,
    required this.deviceId,
    required this.thresholds,
    required this.boundAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'wheelLabel': wheelLabel,
      'sensorId': sensorId,
      'deviceId': deviceId,
      'thresholds': thresholds.toJson(),
      'boundAt': boundAt.millisecondsSinceEpoch,
    };
  }

  factory BoundSensor.fromJson(Map<String, dynamic> json) {
    return BoundSensor(
      wheelLabel: json['wheelLabel'] ?? '',
      sensorId: json['sensorId'] ?? '',
      deviceId: json['deviceId'] ?? '',
      thresholds: SensorThresholds.fromJson(json['thresholds'] ?? {}),
      boundAt: DateTime.fromMillisecondsSinceEpoch(json['boundAt'] ?? 0),
    );
  }
}

class SensorIdStore {
  static const String _boundSensorsKey = 'bound_sensors';
  static const String _sensorDataKey = 'sensor_data_history';
  static const String _lastDataKey = 'last_sensor_data';

  /// Save bound sensor information
  static Future<void> bindSensor({
    required String wheelLabel,
    required String sensorId,
    required String deviceId,
    SensorThresholds? thresholds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sensors = await getBoundSensors();
    
    // Remove existing binding for this wheel
    sensors.removeWhere((sensor) => sensor.wheelLabel == wheelLabel);
    
    // Add new binding
    final newSensor = BoundSensor(
      wheelLabel: wheelLabel,
      sensorId: sensorId,
      deviceId: deviceId,
      thresholds: thresholds ?? SensorThresholds.defaultValues(),
      boundAt: DateTime.now(),
    );
    
    sensors.add(newSensor);
    
    // Save to SharedPreferences
    final sensorsJson = sensors.map((s) => s.toJson()).toList();
    await prefs.setString(_boundSensorsKey, jsonEncode(sensorsJson));
  }

  /// Get all bound sensors
  static Future<List<BoundSensor>> getBoundSensors() async {
    final prefs = await SharedPreferences.getInstance();
    final sensorsJson = prefs.getString(_boundSensorsKey);
    
    if (sensorsJson == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(sensorsJson);
      return decoded.map((json) => BoundSensor.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get sensor bound to specific wheel
  static Future<BoundSensor?> getBoundSensor(String wheelLabel) async {
    final sensors = await getBoundSensors();
    return sensors.firstWhereOrNull((sensor) => sensor.wheelLabel == wheelLabel);
  }

  /// Remove sensor binding
  static Future<void> unbindSensor(String wheelLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final sensors = await getBoundSensors();
    
    sensors.removeWhere((sensor) => sensor.wheelLabel == wheelLabel);
    
    final sensorsJson = sensors.map((s) => s.toJson()).toList();
    await prefs.setString(_boundSensorsKey, jsonEncode(sensorsJson));
  }

  /// Update sensor thresholds
  static Future<void> updateSensorThresholds(String wheelLabel, SensorThresholds thresholds) async {
    final sensors = await getBoundSensors();
    final sensorIndex = sensors.indexWhere((sensor) => sensor.wheelLabel == wheelLabel);
    
    if (sensorIndex != -1) {
      final updatedSensor = BoundSensor(
        wheelLabel: sensors[sensorIndex].wheelLabel,
        sensorId: sensors[sensorIndex].sensorId,
        deviceId: sensors[sensorIndex].deviceId,
        thresholds: thresholds,
        boundAt: sensors[sensorIndex].boundAt,
      );
      
      sensors[sensorIndex] = updatedSensor;
      
      final prefs = await SharedPreferences.getInstance();
      final sensorsJson = sensors.map((s) => s.toJson()).toList();
      await prefs.setString(_boundSensorsKey, jsonEncode(sensorsJson));
    }
  }

  /// Save latest sensor data
  static Future<void> saveLatestSensorData(String wheelLabel, SensorData data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_lastDataKey}_$wheelLabel';
    await prefs.setString(key, jsonEncode(data.toJson()));
  }

  /// Get latest sensor data
  static Future<SensorData?> getLatestSensorData(String wheelLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_lastDataKey}_$wheelLabel';
    final dataJson = prefs.getString(key);
    
    if (dataJson == null) return null;
    
    try {
      final decoded = jsonDecode(dataJson);
      return SensorData.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }

  /// Check if sensor ID is already bound
  static Future<bool> isSensorBound(String sensorId) async {
    final sensors = await getBoundSensors();
    return sensors.any((sensor) => sensor.sensorId == sensorId);
  }

  /// Get wheel label for sensor ID
  static Future<String?> getWheelForSensor(String sensorId) async {
    final sensors = await getBoundSensors();
    final sensor = sensors.firstWhereOrNull((s) => s.sensorId == sensorId);
    return sensor?.wheelLabel;
  }

  /// Clear all sensor data
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_boundSensorsKey);
    await prefs.remove(_sensorDataKey);
    
    // Remove all individual sensor data
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith(_lastDataKey)) {
        await prefs.remove(key);
      }
    }
  }
}

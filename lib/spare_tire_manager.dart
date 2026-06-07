// Complete implementation for SpareTireManager class
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sensor_id_store.dart';
import 'sensor_decoder.dart';
import 'sensor_status.dart';

// Define the TireSwapRecord class
class TireSwapRecord {
  final DateTime timestamp;
  final String wheelLabel;
  final String damagedTireSensorId;
  final String spareTireSensorId;

  TireSwapRecord({
    required this.timestamp,
    required this.wheelLabel,
    required this.damagedTireSensorId,
    required this.spareTireSensorId,
  });

  // Getter for formatted date
  String get formattedDate {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} '
           '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'wheelLabel': wheelLabel,
      'damagedTireSensorId': damagedTireSensorId,
      'spareTireSensorId': spareTireSensorId,
    };
  }

  factory TireSwapRecord.fromJson(Map<String, dynamic> json) {
    return TireSwapRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      wheelLabel: json['wheelLabel'] ?? '',
      damagedTireSensorId: json['damagedTireSensorId'] ?? '',
      spareTireSensorId: json['spareTireSensorId'] ?? '',
    );
  }
}

class SpareTireManager {
  static const String _spareTireKey = 'spare_tire_sensor';
  static const String _tireSwapHistoryKey = 'tire_swap_history';
  static const String _spareTireDataKey = 'spare_tire_data';
  
  // Get the current spare tire sensor
  static Future<BoundSensor?> getSpareTireSensor() async {
    final prefs = await SharedPreferences.getInstance();
    final sensorIdString = prefs.getString(_spareTireKey);
    
    if (sensorIdString != null) {
      try {
        Map<String, dynamic> sensorMap = json.decode(sensorIdString);
        return BoundSensor.fromJson(sensorMap);
      } catch (e) {
        print('Error parsing spare tire sensor: $e');
        return null;
      }
    }
    return null;
  }
  
  // Save spare tire sensor
  static Future<void> saveSpareTireSensor(BoundSensor sensor) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> sensorMap = {
      'sensorId': sensor.sensorId,
      'deviceId': sensor.deviceId,
      'wheelLabel': 'Spare Tire',
      'thresholds': sensor.thresholds.toJson(),
      'boundAt': sensor.boundAt.millisecondsSinceEpoch,
    };
    await prefs.setString(_spareTireKey, json.encode(sensorMap));
  }
  
  // Remove spare tire sensor
  static Future<void> removeSpareTireSensor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spareTireKey);
    await prefs.remove(_spareTireDataKey);
  }
  
  // Get spare tire sensor data
  static Future<SensorData?> getSpareTireData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = prefs.getString(_spareTireDataKey);
    
    if (dataJson != null) {
      try {
        final decoded = json.decode(dataJson);
        return SensorData.fromJson(decoded);
      } catch (e) {
        print('Error parsing spare tire data: $e');
        return null;
      }
    }
    return null;
  }
  
  // Save spare tire sensor data
  static Future<void> saveSpareTireData(SensorData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spareTireDataKey, json.encode(data.toJson()));
  }

  // Register a new spare tire sensor
  static Future<void> registerSpareTireSensor({
    required String sensorId,
    required String deviceId,
    SensorThresholds? thresholds,
  }) async {
    // Create bound sensor for spare tire
    final spareTire = BoundSensor(
      wheelLabel: 'Spare Tire',
      sensorId: sensorId,
      deviceId: deviceId,
      thresholds: thresholds ?? SensorThresholds.defaultValues(),
      boundAt: DateTime.now(),
    );
    
    // Save to SharedPreferences using the saveSpareTireSensor method
    await saveSpareTireSensor(spareTire);
    
    // Also bind this sensor in the regular sensor store for data tracking
    await SensorIdStore.bindSensor(
      wheelLabel: 'Spare Tire',
      sensorId: sensorId,
      deviceId: deviceId,
      thresholds: thresholds,
    );
    
    // Update global sensor status
    updateSensorStatus('Spare Tire', SensorStatus(
      connected: true,
      statusColor: Colors.blue,
      warningIcons: [Icons.tire_repair],
      message: 'Spare Tire',
    ));
  }
  
  // Get tire swap history
  static Future<List<TireSwapRecord>> getTireSwapHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_tireSwapHistoryKey);
    
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = json.decode(historyJson);
        return decoded
            .map((item) => TireSwapRecord.fromJson(item))
            .toList();
      } catch (e) {
        print('Error parsing tire swap history: $e');
      }
    }
    
    return [];
  }
  
  // Record a tire swap
  static Future<void> _recordTireSwap(
    String damagedWheelLabel,
    BoundSensor damagedTire,
    BoundSensor spareTire,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> history = [];
    
    // Get existing history
    final historyJson = prefs.getString(_tireSwapHistoryKey);
    if (historyJson != null) {
      final List<dynamic> decoded = json.decode(historyJson);
      history = decoded.cast<Map<String, dynamic>>();
    }
    
    // Add new swap record
    history.add({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'wheelLabel': damagedWheelLabel,
      'damagedTireSensorId': damagedTire.sensorId,
      'spareTireSensorId': spareTire.sensorId,
    });
    
    // Save updated history
    await prefs.setString(_tireSwapHistoryKey, json.encode(history));
  }

  // Swap spare tire with a damaged tire
  static Future<bool> swapWithSpareTire(String damagedWheelLabel) async {
    try {
      // Get spare tire sensor
      final spareTire = await getSpareTireSensor();
      if (spareTire == null) return false;
      
      // Get the damaged tire sensor
      final damagedTire = await SensorIdStore.getBoundSensor(damagedWheelLabel);
      if (damagedTire == null) return false;
      
      // Unbind damaged tire and mark as "In Service"
      await SensorIdStore.unbindSensor(damagedWheelLabel);
      await SensorIdStore.bindSensor(
        wheelLabel: 'In Service',
        sensorId: damagedTire.sensorId,
        deviceId: damagedTire.deviceId,
        thresholds: damagedTire.thresholds,
      );
      
      // Bind spare tire to the wheel position
      await SensorIdStore.unbindSensor('Spare Tire');
      await SensorIdStore.bindSensor(
        wheelLabel: damagedWheelLabel,
        sensorId: spareTire.sensorId,
        deviceId: spareTire.deviceId,
        thresholds: spareTire.thresholds,
      );
      
      // Remove spare tire reference
      await removeSpareTireSensor();
      
      // Record the swap
      await _recordTireSwap(damagedWheelLabel, damagedTire, spareTire);
      
      return true;
    } catch (e) {
      print('Error during tire swap: $e');
      return false;
    }
  }
}

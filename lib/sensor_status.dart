// removed unused import
import 'package:flutter/material.dart';
import 'sensor_status_controller.dart';

class SensorStatus {
  final bool connected;
  final Color statusColor;
  final List<IconData> warningIcons;
  final String message;
  final SensorStatusInfo? statusInfo;

  SensorStatus({
    required this.connected,
    required this.statusColor,
    required this.warningIcons,
    required this.message,
    this.statusInfo,
  });

  factory SensorStatus.notConnected() {
    return SensorStatus(
      connected: false,
      statusColor: const Color(0xFF8C909F), // Changed to mute grey
      warningIcons: [Icons.bluetooth_disabled],
      message: 'Not Connected',
    );
  }

  factory SensorStatus.normal() {
    return SensorStatus(
      connected: true,
      statusColor: const Color(0xFFADC6FF), // Blue accent instead of green
      warningIcons: [Icons.check_circle],
      message: 'Normal',
    );
  }

  factory SensorStatus.lowPressure() {
    return SensorStatus(
      connected: true,
      statusColor: const Color(0xFFFFB4AB),
      warningIcons: [Icons.warning],
      message: 'Low Pressure',
    );
  }

  factory SensorStatus.highPressure() {
    return SensorStatus(
      connected: true,
      statusColor: const Color(0xFFFFB4AB),
      warningIcons: [Icons.warning],
      message: 'High Pressure',
    );
  }

  factory SensorStatus.lowBattery() {
    return SensorStatus(
      connected: true,
      statusColor: const Color(0xFFFFD97D),
      warningIcons: [Icons.battery_alert],
      message: 'Low Battery',
    );
  }

  factory SensorStatus.highTemperature() {
    return SensorStatus(
      connected: true,
      statusColor: const Color(0xFFFFD97D),
      warningIcons: [Icons.thermostat],
      message: 'High Temperature',
    );
  }

  factory SensorStatus.fromStatusInfo(SensorStatusInfo statusInfo) {
    List<IconData> icons = SensorStatusController.buildWarningIcons(statusInfo);
    if (icons.isEmpty) {
      icons = [statusInfo.icon];
    }

    return SensorStatus(
      connected: statusInfo.status != SensorStatusType.notConnected,
      statusColor: statusInfo.color,
      warningIcons: icons,
      message: statusInfo.message,
      statusInfo: statusInfo,
    );
  }
}

// Global sensor statuses for the vehicle screens
Map<String, SensorStatus> sensorStatuses = {
  // CV (Commercial Vehicle) sensors
  'Sensor 1': SensorStatus.notConnected(),
  'Sensor 2': SensorStatus.notConnected(),
  'Sensor 3': SensorStatus.notConnected(),
  'Sensor 4': SensorStatus.notConnected(),
  'Sensor 5': SensorStatus.notConnected(),
  'Sensor 6': SensorStatus.notConnected(),
  // Add this line to the global sensor statuses map
  'Spare Tire': SensorStatus.notConnected(),

  
  // Bike sensors
  'Sensor Front': SensorStatus.notConnected(),
  'Sensor Back': SensorStatus.notConnected(),
};

// Function to update sensor status
void updateSensorStatus(String sensorLabel, SensorStatus status) {
  sensorStatuses[sensorLabel] = status;
}

// Function to get sensor status
SensorStatus getSensorStatus(String sensorLabel) {
  return sensorStatuses[sensorLabel] ?? SensorStatus.notConnected();
}

// Function to initialize all sensor statuses
void initializeSensorStatuses() {
  for (String key in sensorStatuses.keys) {
    sensorStatuses[key] = SensorStatus.notConnected();
  }
}

// Function to check if any sensor has warnings
bool hasAnySensorWarnings() {
  return sensorStatuses.values.any((status) => 
    status.statusInfo != null && 
    SensorStatusController.shouldAlert(status.statusInfo!)
  );
}

// Function to get count of sensors with warnings
int getSensorWarningCount() {
  return sensorStatuses.values.where((status) => 
    status.statusInfo != null && 
    SensorStatusController.shouldAlert(status.statusInfo!)
  ).length;
}

// Function to get count of connected sensors
int getConnectedSensorCount() {
  return sensorStatuses.values.where((status) => status.connected).length;
}

// Function to get total sensor count
int getTotalSensorCount() {
  return sensorStatuses.length;
}

// Function to get critical issues across all sensors
List<String> getAllCriticalIssues() {
  List<String> issues = [];
  for (var entry in sensorStatuses.entries) {
    if (entry.value.statusInfo != null && 
        SensorStatusController.shouldAlert(entry.value.statusInfo!)) {
      for (String warning in entry.value.statusInfo!.warnings) {
        issues.add('${entry.key}: $warning');
      }
    }
  }
  return issues;
}

// Function to get status summary with emoji indicators
Map<String, dynamic> getStatusSummaryWithEmojis() {
  Map<SensorStatusType, int> statusCounts = {};
  Map<SensorStatusType, List<String>> statusSensors = {};
  
  for (var entry in sensorStatuses.entries) {
    SensorStatusType statusType = entry.value.statusInfo?.status ?? SensorStatusType.notConnected;
    statusCounts[statusType] = (statusCounts[statusType] ?? 0) + 1;
    statusSensors[statusType] = (statusSensors[statusType] ?? [])..add(entry.key);
  }
  
  return {
    'summary': statusCounts,
    'sensors': statusSensors,
    'emojis': {
      SensorStatusType.normal: '✅',
      SensorStatusType.pressureLow: '🔴',
      SensorStatusType.pressureHigh: '🔴',
      SensorStatusType.temperatureHigh: '🌡️',
      SensorStatusType.batteryLow: '🟠',
      SensorStatusType.notConnected: '⚫',
      SensorStatusType.multipleWarnings: '🚨',
    }
  };
}

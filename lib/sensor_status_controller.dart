// removed unused import
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'package:collection/collection.dart';
import 'sensor_decoder.dart';
import 'sensor_id_store.dart';
import 'threshold_settings_screen.dart';

enum SensorStatusType {
  notConnected,
  normal,
  pressureHigh,
  pressureLow,
  temperatureHigh,
  batteryLow,
  multipleWarnings,
}

class SensorStatusInfo {
  final SensorStatusType status;
  final Color color;
  final IconData icon;
  final String message;
  final List<String> warnings;

  SensorStatusInfo({
    required this.status,
    required this.color,
    required this.icon,
    required this.message,
    required this.warnings,
  });
}

class SensorStatusController {
  static Future<SensorStatusInfo> getStatusInfo(SensorData? data, SensorThresholds? thresholds) async {
    if (data == null) {
      return SensorStatusInfo(
        status: SensorStatusType.notConnected,
        color: AppTheme.outline,
        icon: Icons.bluetooth_disabled,
        message: 'Not Connected',
        warnings: ['Sensor not detected or lost signal'],
      );
    }

    // Load global thresholds if local thresholds are not available
    ThresholdSettings globalThresholds = await ThresholdManager.getSettings();
    
    double pressureMin = thresholds?.pressureMin ?? globalThresholds.pressureMin;
    double pressureMax = thresholds?.pressureMax ?? globalThresholds.pressureMax;
    double temperatureMax = thresholds?.temperatureMax ?? globalThresholds.temperatureMax;
    double batteryMinVoltage = globalThresholds.batteryMinVoltage; // Always use global for voltage
    int batteryMinPercentage = thresholds?.batteryMin ?? globalThresholds.batteryMinPercentage;

    List<String> warnings = [];
    SensorStatusType status = SensorStatusType.normal;
    Color color = AppTheme.primary; // positiveColor
    IconData icon = Icons.check_circle;

    // Convert pressure from kPa to PSI for threshold comparison
    double pressurePsi = data.pressurePsi;

    // Check pressure thresholds
    if (pressurePsi < pressureMin) {
      warnings.add('Pressure below minimum: ${pressurePsi.toStringAsFixed(1)} PSI (Min: ${pressureMin.toStringAsFixed(1)} PSI)');
      status = SensorStatusType.pressureLow;
      color = AppTheme.error; // errorColor
      icon = Icons.warning;
    } else if (pressurePsi > pressureMax) {
      warnings.add('Pressure above maximum: ${pressurePsi.toStringAsFixed(1)} PSI (Max: ${pressureMax.toStringAsFixed(1)} PSI)');
      status = SensorStatusType.pressureHigh;
      color = AppTheme.error; // errorColor
      icon = Icons.warning;
    }

    // Check temperature threshold
    if (data.temperature > temperatureMax) {
      warnings.add('Temperature above safe level: ${data.temperature}Â°C (Max: ${temperatureMax.toStringAsFixed(1)}Â°C)');
      if (status == SensorStatusType.normal) {
        status = SensorStatusType.temperatureHigh;
        color = Color(0xFFFFD97D); // warningColor
        icon = Icons.thermostat;
      } else {
        status = SensorStatusType.multipleWarnings;
        color = AppTheme.error; // errorColor
        icon = Icons.error;
      }
    }

    // Check battery voltage (using fixed 2.2V threshold)
    if (data.batteryVoltage < batteryMinVoltage) {
      warnings.add('Battery voltage low: ${data.batteryVoltage.toStringAsFixed(2)}V (Min: ${batteryMinVoltage}V)');
      if (status == SensorStatusType.normal) {
        status = SensorStatusType.batteryLow;
        color = Color(0xFFFFD97D); // warningColor
        icon = Icons.battery_alert;
      } else {
        status = SensorStatusType.multipleWarnings;
        color = AppTheme.error; // errorColor
        icon = Icons.error;
      }
    }

    // Also check battery percentage
    int batteryPercentage = ((data.battery / 255.0) * 100).round();
    if (batteryPercentage < batteryMinPercentage) {
      warnings.add('Battery percentage low: ${batteryPercentage}% (Min: ${batteryMinPercentage}%)');
      if (status == SensorStatusType.normal) {
        status = SensorStatusType.batteryLow;
        color = Color(0xFFFFD97D); // warningColor
        icon = Icons.battery_alert;
      } else {
        status = SensorStatusType.multipleWarnings;
        color = AppTheme.error; // errorColor
        icon = Icons.error;
      }
    }

    String message;
    if (warnings.isEmpty) {
      message = 'All OK';
    } else if (warnings.length == 1) {
      switch (status) {
        case SensorStatusType.pressureLow:
          message = 'Low Pressure';
          break;
        case SensorStatusType.pressureHigh:
          message = 'High Pressure';
          break;
        case SensorStatusType.temperatureHigh:
          message = 'High Temperature';
          break;
        case SensorStatusType.batteryLow:
          message = 'Low Battery';
          break;
        default:
          message = warnings.first;
      }
    } else {
      message = '${warnings.length} issues detected';
    }

    return SensorStatusInfo(
      status: status,
      color: color,
      icon: icon,
      message: message,
      warnings: warnings,
    );
  }

  static Widget buildStatusIndicator(SensorStatusInfo statusInfo, {double size = 16}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: statusInfo.color,
        boxShadow: [
          BoxShadow(
            color: statusInfo.color.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        statusInfo.icon,
        color: AppTheme.surface,
        size: size * 0.6,
      ),
    );
  }

  static Widget buildStatusIcon(SensorStatusInfo statusInfo, {double size = 24}) {
    return Icon(
      statusInfo.icon,
      color: statusInfo.color,
      size: size,
    );
  }

  static List<IconData> buildWarningIcons(SensorStatusInfo statusInfo) {
    List<IconData> icons = [];

    switch (statusInfo.status) {
      case SensorStatusType.notConnected:
        icons.add(Icons.bluetooth_disabled);
        break;
      case SensorStatusType.normal:
        icons.add(Icons.check_circle);
        break;
      case SensorStatusType.pressureLow:
      case SensorStatusType.pressureHigh:
        icons.add(Icons.warning);
        break;
      case SensorStatusType.temperatureHigh:
        icons.add(Icons.thermostat);
        break;
      case SensorStatusType.batteryLow:
        icons.add(Icons.battery_alert);
        break;
      case SensorStatusType.multipleWarnings:
        icons.add(Icons.error);
        break;
    }

    return icons;
  }

  static bool shouldAlert(SensorStatusInfo statusInfo) {
    return statusInfo.status != SensorStatusType.normal && 
           statusInfo.status != SensorStatusType.notConnected;
  }

  static Future<String> getDetailedMessage(SensorData data, SensorThresholds? thresholds) async {
    final statusInfo = await getStatusInfo(data, thresholds);
    final globalThresholds = await ThresholdManager.getSettings();
    
    if (statusInfo.warnings.isEmpty) {
      return 'Sensor Status: Normal âœ…\n'
             'Pressure: ${data.pressurePsi.toStringAsFixed(1)} PSI (${globalThresholds.pressureMin}-${globalThresholds.pressureMax})\n'
             'Temperature: ${data.temperature}Â°C (Max: ${globalThresholds.temperatureMax})\n'
             'Battery: ${((data.battery / 255.0) * 100).round()}% (${data.batteryVoltage.toStringAsFixed(2)}V)\n'
             'Battery Thresholds: Min ${globalThresholds.batteryMinPercentage}% (${globalThresholds.batteryMinVoltage}V)';
    } else {
      String statusEmoji = '';
      switch (statusInfo.status) {
        case SensorStatusType.pressureLow:
        case SensorStatusType.pressureHigh:
          statusEmoji = 'ðŸ”´';
          break;
        case SensorStatusType.temperatureHigh:
          statusEmoji = 'ðŸŒ¡ï¸';
          break;
        case SensorStatusType.batteryLow:
          statusEmoji = 'ðŸŸ ';
          break;
        case SensorStatusType.notConnected:
          statusEmoji = 'âš«';
          break;
        case SensorStatusType.multipleWarnings:
          statusEmoji = 'ðŸš¨';
          break;
        default:
          statusEmoji = 'âš ï¸';
      }
      
      return 'Sensor Status: ${statusInfo.message} $statusEmoji\n'
             'Issues:\n${statusInfo.warnings.map((w) => 'â€¢ $w').join('\n')}\n\n'
             'Current Readings:\n'
             'Pressure: ${data.pressurePsi.toStringAsFixed(1)} PSI\n'
             'Temperature: ${data.temperature}Â°C\n'
             'Battery: ${((data.battery / 255.0) * 100).round()}% (${data.batteryVoltage.toStringAsFixed(2)}V)';
    }
  }

  static Future<Map<String, dynamic>> getStatusSummary(List<SensorData> allSensorData, List<BoundSensor> boundSensors) async {
    int totalSensors = boundSensors.length;
    int connectedSensors = 0;
    int sensorsWithWarnings = 0;
    List<String> criticalIssues = [];

    for (BoundSensor boundSensor in boundSensors) {
      final data = allSensorData.firstWhereOrNull((d) => d.sensorId == boundSensor.sensorId);
      if (data != null) {
        connectedSensors++;
        final statusInfo = await getStatusInfo(data, boundSensor.thresholds);
        if (shouldAlert(statusInfo)) {
          sensorsWithWarnings++;
          criticalIssues.addAll(statusInfo.warnings);
        }
      }
    }

    return {
      'totalSensors': totalSensors,
      'connectedSensors': connectedSensors,
      'sensorsWithWarnings': sensorsWithWarnings,
      'criticalIssues': criticalIssues,
      'allClear': sensorsWithWarnings == 0 && connectedSensors == totalSensors,
    };
  }

  // Helper method to get status color based on condition
  static Color getStatusColor(SensorStatusType status) {
    switch (status) {
      case SensorStatusType.normal:
        return Colors.green;
      case SensorStatusType.pressureLow:
      case SensorStatusType.pressureHigh:
      case SensorStatusType.multipleWarnings:
        return Colors.red;
      case SensorStatusType.temperatureHigh:
        return Colors.orange;
      case SensorStatusType.batteryLow:
        return Colors.amber;
      case SensorStatusType.notConnected:
        return Colors.black;
    }
  }

  // Helper method to get status icon based on condition
  static IconData getStatusIcon(SensorStatusType status) {
    switch (status) {
      case SensorStatusType.normal:
        return Icons.check_circle;
      case SensorStatusType.pressureLow:
      case SensorStatusType.pressureHigh:
        return Icons.warning;
      case SensorStatusType.temperatureHigh:
        return Icons.thermostat;
      case SensorStatusType.batteryLow:
        return Icons.battery_alert;
      case SensorStatusType.notConnected:
        return Icons.bluetooth_disabled;
      case SensorStatusType.multipleWarnings:
        return Icons.error;
    }
  }

  // Helper method to get human-readable status message
  static String getStatusMessage(SensorStatusType status) {
    switch (status) {
      case SensorStatusType.normal:
        return 'Normal';
      case SensorStatusType.pressureLow:
        return 'Low Pressure';
      case SensorStatusType.pressureHigh:
        return 'High Pressure';
      case SensorStatusType.temperatureHigh:
        return 'High Temperature';
      case SensorStatusType.batteryLow:
        return 'Low Battery';
      case SensorStatusType.notConnected:
        return 'Not Connected';
      case SensorStatusType.multipleWarnings:
        return 'Multiple Issues';
    }
  }
}



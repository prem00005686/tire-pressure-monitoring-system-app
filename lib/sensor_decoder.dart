class SensorData {
  final String sensorId;
  final int pressure;
  final int temperature;
  final int battery;
  final DateTime timestamp;

  SensorData({
    required this.sensorId,
    required this.pressure,
    required this.temperature,
    required this.battery,
    required this.timestamp,
  });

  Map toJson() {
    return {
      'sensorId': sensorId,
      'pressure': pressure,
      'temperature': temperature,
      'battery': battery,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory SensorData.fromJson(Map json) {
    return SensorData(
      sensorId: json['sensorId'] ?? '',
      pressure: json['pressure'] ?? 0,
      temperature: json['temperature'] ?? 0,
      battery: json['battery'] ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
    );
  }

  // Atmospheric pressure constants
  static const double ATMOSPHERIC_PRESSURE_PSI =
      14.6; // Updated to 14.6 as you requested
  static const double ATMOSPHERIC_PRESSURE_KPA =
      100.7; // Corresponding kPa value (14.6 * 6.895)

  // Gauge pressure (what users typically see on tire pressure gauges)
  double get pressurePsi {
    // Convert from kPa to absolute PSI
    double absolutePressurePsi = pressure * 0.145038;

    // Convert to gauge pressure by subtracting atmospheric pressure
    double gaugePressure = absolutePressurePsi - ATMOSPHERIC_PRESSURE_PSI;

    // Return 0 if below atmospheric pressure (invalid reading)
    return gaugePressure > 0 ? gaugePressure : 0.0;
  }

  double get pressureBar {
    // Convert from kPa to gauge pressure in kPa, then to bar
    double absolutePressureKpa = pressure.toDouble();
    double gaugePressureKpa = absolutePressureKpa - ATMOSPHERIC_PRESSURE_KPA;

    // Convert to bar (1 bar = 100 kPa)
    return gaugePressureKpa > 0 ? (gaugePressureKpa * 0.01) : 0.0;
  }

  // Raw absolute pressure values (for debugging/internal use)
  double get absolutePressurePsi => pressure * 0.145038;
  double get absolutePressureKpa => pressure.toDouble();
  double get absolutePressureBar => pressure * 0.01;

  // Temperature conversions
  double get temperatureK => temperature + 273.15;

  // Battery voltage calculation
  double get batteryVoltage => ((battery / 255.0) * 1.25 + 1.8);
}

class SensorDecoder {
  static const int HEADER_BYTE = 0xFB;
  static const int PRESSURE_PATTERN_1 = 0x2F;
  static const int PRESSURE_PATTERN_2 = 0x00;

  /// Decodes sensor ID from BLE advertisement payload
  static String decodeSensorId(List<int> bytes) {
    try {
      final headerIndex = bytes.indexOf(HEADER_BYTE);
      if (headerIndex == -1 || bytes.length < headerIndex + 8) {
        return "INVALID";
      }

      final idStart = headerIndex + 4;
      if (idStart + 3 >= bytes.length) {
        return "INVALID";
      }

      return '${bytes[idStart].toRadixString(16).padLeft(2, '0')}-'
              '${bytes[idStart + 1].toRadixString(16).padLeft(2, '0')}-'
              '${bytes[idStart + 2].toRadixString(16).padLeft(2, '0')}-'
              '${bytes[idStart + 3].toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
    } catch (e) {
      return "ERROR";
    }
  }

  /// Helper function to find first occurrence of 2F 00 XX pattern starting from index
  static int _findValueAfter(List<int> bytes, int startIndex) {
    for (int i = startIndex; i < bytes.length - 2; i++) {
      if (bytes[i] == PRESSURE_PATTERN_1 &&
          bytes[i + 1] == PRESSURE_PATTERN_2) {
        return bytes[i + 2];
      }
    }
    return -1;
  }

  /// Extracts pressure value from payload (in kPa)
  static int extractPressure(List<int> bytes) {
    try {
      final headerIndex = bytes.indexOf(HEADER_BYTE);
      if (headerIndex == -1) return -1;

      final sensorIdStart = headerIndex + 4;
      if (sensorIdStart + 4 >= bytes.length) return -1;

      return _findValueAfter(bytes, sensorIdStart + 4);
    } catch (e) {
      return -1;
    }
  }

  /// Extracts temperature value from payload (in Celsius)
  static int extractTemperature(List<int> bytes) {
    try {
      final headerIndex = bytes.indexOf(HEADER_BYTE);
      if (headerIndex == -1) return -1;

      final sensorIdStart = headerIndex + 4;
      if (sensorIdStart + 4 >= bytes.length) return -1;

      // Find pressure first, then find next value
      final pressureValue = _findValueAfter(bytes, sensorIdStart + 4);
      if (pressureValue == -1) return -1;

      // Find the index where pressure was found
      int pressureIndex = -1;
      for (int i = sensorIdStart + 4; i < bytes.length - 2; i++) {
        if (bytes[i] == PRESSURE_PATTERN_1 &&
            bytes[i + 1] == PRESSURE_PATTERN_2 &&
            bytes[i + 2] == pressureValue) {
          pressureIndex = i;
          break;
        }
      }

      if (pressureIndex == -1) return -1;

      return _findValueAfter(bytes, pressureIndex + 3);
    } catch (e) {
      return -1;
    }
  }

  /// Extracts battery level from payload (raw value 0-255)
  static int extractBattery(List<int> bytes) {
    try {
      final headerIndex = bytes.indexOf(HEADER_BYTE);
      if (headerIndex == -1) return -1;

      final sensorIdStart = headerIndex + 4;
      if (sensorIdStart + 4 >= bytes.length) return -1;

      // Find pressure first
      final pressureValue = _findValueAfter(bytes, sensorIdStart + 4);
      if (pressureValue == -1) return -1;

      // Find pressure index
      int pressureIndex = -1;
      for (int i = sensorIdStart + 4; i < bytes.length - 2; i++) {
        if (bytes[i] == PRESSURE_PATTERN_1 &&
            bytes[i + 1] == PRESSURE_PATTERN_2 &&
            bytes[i + 2] == pressureValue) {
          pressureIndex = i;
          break;
        }
      }

      if (pressureIndex == -1) return -1;

      // Find temperature next
      final tempValue = _findValueAfter(bytes, pressureIndex + 3);
      if (tempValue == -1) return -1;

      // Find temperature index
      int tempIndex = -1;
      for (int i = pressureIndex + 3; i < bytes.length - 2; i++) {
        if (bytes[i] == PRESSURE_PATTERN_1 &&
            bytes[i + 1] == PRESSURE_PATTERN_2 &&
            bytes[i + 2] == tempValue) {
          tempIndex = i;
          break;
        }
      }

      if (tempIndex == -1) return -1;

      return _findValueAfter(bytes, tempIndex + 3);
    } catch (e) {
      return -1;
    }
  }

  /// Extracts CRC from payload
  static String extractCRC(List<int> bytes) {
    try {
      int fdIndex = bytes.lastIndexOf(0xFD);
      if (fdIndex >= 3 && bytes[fdIndex - 3] == 0x2F) {
        return '0x${bytes[fdIndex - 2].toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${bytes[fdIndex - 1].toRadixString(16).padLeft(2, '0').toUpperCase()}';
      }
      return "Not found";
    } catch (e) {
      return "Error";
    }
  }

  /// Decodes complete sensor data from payload
  static SensorData? decodeCompleteData(List<int> bytes) {
    try {
      final sensorId = decodeSensorId(bytes);
      if (sensorId == "INVALID" || sensorId == "ERROR") {
        return null;
      }

      final pressure = extractPressure(bytes);
      final temperature = extractTemperature(bytes);
      final battery = extractBattery(bytes);

      if (pressure == -1 || temperature == -1 || battery == -1) {
        return null;
      }

      return SensorData(
        sensorId: sensorId,
        pressure: pressure, // Raw kPa value (absolute pressure)
        temperature: temperature, // Celsius
        battery: battery, // Raw value 0-255
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Decode error: $e');
      return null;
    }
  }

  /// Validates if payload contains valid sensor data
  static bool isValidPayload(List<int> bytes) {
    if (bytes.isEmpty || bytes.length < 20) return false;
    return bytes.contains(HEADER_BYTE);
  }

  /// Converts raw advertisement data to readable format
  static String payloadToHexString(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
  }

  /// Debug function to show detailed decoding process
  static Map<String, dynamic> debugDecode(List<int> bytes) {
    final result = <String, dynamic>{};

    try {
      result['Input Length'] = bytes.length;
      result['Hex String'] = payloadToHexString(bytes);

      final headerIndex = bytes.indexOf(HEADER_BYTE);
      result['Header Index'] = headerIndex;

      if (headerIndex != -1) {
        final sensorId = decodeSensorId(bytes);
        result['Sensor ID'] = sensorId;

        final pressure = extractPressure(bytes);
        final temperature = extractTemperature(bytes);
        final battery = extractBattery(bytes);
        final crc = extractCRC(bytes);

        result['Pressure (kPa)'] = pressure;

        if (pressure != -1) {
          // Show all pressure calculations for debugging
          double absolutePsi = pressure * 0.145038;
          double gaugePsi = absolutePsi - SensorData.ATMOSPHERIC_PRESSURE_PSI;
          double gaugeBar =
              (pressure - SensorData.ATMOSPHERIC_PRESSURE_KPA) * 0.01;

          result['Absolute Pressure (PSI)'] = absolutePsi.toStringAsFixed(2);
          result['Gauge Pressure (PSI)'] =
              gaugePsi > 0 ? gaugePsi.toStringAsFixed(2) : '0.00';
          result['Gauge Pressure (bar)'] =
              gaugeBar > 0 ? gaugeBar.toStringAsFixed(2) : '0.00';
          result['Atmospheric Compensation'] =
              'Subtracted ${SensorData.ATMOSPHERIC_PRESSURE_PSI} PSI';
        } else {
          result['Absolute Pressure (PSI)'] = 'N/A';
          result['Gauge Pressure (PSI)'] = 'N/A';
          result['Gauge Pressure (bar)'] = 'N/A';
        }

        result['Temperature (°C)'] = temperature;
        result['Temperature (K)'] = temperature != -1
            ? (temperature + 273.15).toStringAsFixed(2)
            : 'N/A';
        result['Battery Raw'] = battery;
        result['Battery Voltage'] = battery != -1
            ? (((battery / 255.0) * 1.25 + 1.8)).toStringAsFixed(3)
            : 'N/A';
        result['Battery Percentage'] =
            battery != -1 ? '${((battery / 255.0) * 100).round()}%' : 'N/A';
        result['CRC'] = crc;

        result['Valid'] = pressure != -1 && temperature != -1 && battery != -1;
      } else {
        result['Valid'] = false;
        result['Error'] = 'Header byte 0xFB not found';
      }
    } catch (e) {
      result['Valid'] = false;
      result['Error'] = e.toString();
    }

    return result;
  }
}

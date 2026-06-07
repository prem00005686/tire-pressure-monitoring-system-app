import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'sensor_decoder.dart';
import 'sensor_id_store.dart';
import 'sensor_status.dart';
import 'ble_permissions.dart';

class SensorScanScreen extends StatefulWidget {
  final String wheelLabel;

  SensorScanScreen({Key? key, required this.wheelLabel})
      : super(key: key);

  @override
  _SensorScanScreenState createState() => _SensorScanScreenState();
}

class _SensorScanScreenState extends State<SensorScanScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  List<DiscoveredDevice> _discoveredDevices = [];
  Map<String, SensorData> _deviceSensorData = {};
  Map<String, int> _deviceRssi = {};
  bool _isScanning = false;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  Future<void> _requestPermissionsAndScan() async {
    bool hasPermissions = await BlePermissions.requestPermissions(context);
    if (!mounted) return;

    if (hasPermissions) {
      _startScanning();
    }
  }

  Future<BleStatus> _getCurrentBleStatus() async {
    try {
      return await _ble.statusStream
          .firstWhere((status) => status != BleStatus.unknown)
          .timeout(Duration(seconds: 5), onTimeout: () => BleStatus.unknown);
    } catch (e) {
      print('Error checking BLE status: $e');
      return BleStatus.unknown;
    }
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;

    final bleStatus = await _getCurrentBleStatus();
    if (!mounted) return;
    if (bleStatus != BleStatus.ready) {
      _showBluetoothOffDialog(bleStatus);
      return;
    }

    await _scanSubscription?.cancel();
    _scanTimer?.cancel();

    if (mounted) {
      setState(() {
        _isScanning = true;
        _discoveredDevices.clear();
        _deviceSensorData.clear();
        _deviceRssi.clear();
      });
    }

    try {
      // Start scanning with options to detect ALL devices including non-connectable
      _scanSubscription = _ble.scanForDevices(
        withServices: [], // Empty list = scan for ALL devices
        scanMode: ScanMode.lowLatency, // Best for detecting all devices
        requireLocationServicesEnabled: true,
      ).listen(
        (device) {
          _handleDiscoveredDevice(device);
        },
        onError: (error) {
          print('Scan error: $error');
          if (!mounted) return;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Scan error: $error', style: TextStyle(color: AppTheme.error)),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
            );
          }
        },
      );

      // Auto-stop after 30 seconds
      _scanTimer = Timer(Duration(seconds: 30), () {
        _stopScanning();
      });
    } catch (e) {
      print('Error starting scan: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _handleDiscoveredDevice(DiscoveredDevice device) {
    // Process manufacturer data to extract sensor info
    // In flutter_reactive_ble, manufacturerData is List<int> directly
    if (device.manufacturerData.isNotEmpty) {
      List<int> data = device.manufacturerData;
      if (SensorDecoder.isValidPayload(data)) {
        SensorData? sensorData = SensorDecoder.decodeCompleteData(data);
        if (sensorData != null) {
          // Add mounted check before setState
          if (mounted) {
            setState(() {
              // Update or add device
              final existingIndex =
                  _discoveredDevices.indexWhere((d) => d.id == device.id);

              if (existingIndex >= 0) {
                _discoveredDevices[existingIndex] = device;
              } else {
                _discoveredDevices.add(device);
              }

              _deviceSensorData[device.id] = sensorData;
              _deviceRssi[device.id] = device.rssi;
            });
          }
        }
      }
    }
  }

  void _stopScanning() {
    _scanSubscription?.cancel();
    _scanTimer?.cancel();
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _showBluetoothOffDialog(BleStatus status) {
    if (!mounted) return;

    String message;
    switch (status) {
      case BleStatus.ready:
        message = 'Bluetooth is ready.';
        break;
      case BleStatus.unauthorized:
        message = 'Bluetooth permission is not granted. Please allow permissions in settings.';
        break;
      case BleStatus.locationServicesDisabled:
        message = 'Location services are disabled. Please enable location services to scan for BLE devices.';
        break;
      case BleStatus.poweredOff:
      case BleStatus.unknown:
      default:
        message = 'Bluetooth appears to be off or unavailable. Please turn on Bluetooth and try again.';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bluetooth Status'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _bindSensor(
      DiscoveredDevice device, SensorData sensorData) async {
    try {
      // Check if sensor is already bound
      bool isAlreadyBound =
          await SensorIdStore.isSensorBound(sensorData.sensorId);
      if (!mounted) return;
      if (isAlreadyBound) {
        String? boundWheel =
            await SensorIdStore.getWheelForSensor(sensorData.sensorId);
        if (!mounted) return;
        _showAlreadyBoundDialog(sensorData.sensorId, boundWheel);
        return;
      }

      // Show detailed confirmation dialog with sensor data
      bool? confirm = await _showBindConfirmationDialog(sensorData);
      if (!mounted) return;

      if (confirm == true) {
        await SensorIdStore.bindSensor(
          wheelLabel: widget.wheelLabel,
          sensorId: sensorData.sensorId,
          deviceId: device.id,
        );
        if (!mounted) return;

        // Save initial sensor data
        await SensorIdStore.saveLatestSensorData(widget.wheelLabel, sensorData);
        if (!mounted) return;

        // Update global sensor status to show it's now bound
        updateSensorStatus(
            widget.wheelLabel,
            SensorStatus(
              connected: true,
              statusColor: AppTheme.primary,
              warningIcons: [Icons.bluetooth_connected],
              message: 'Connected with live data',
            ));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Sensor ${sensorData.sensorId} bound to ${widget.wheelLabel}', 
                  style: TextStyle(color: AppTheme.onBackground)),
              backgroundColor: AppTheme.surfaceHigh,
            ),
          );

          Navigator.pop(context, device.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error binding sensor: $e', style: TextStyle(color: AppTheme.error)),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<bool?> _showBindConfirmationDialog(SensorData sensorData) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Bind Sensor', style: TextStyle(color: AppTheme.onBackground)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bind this sensor to ${widget.wheelLabel}?',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onBackground),
            ),
            SizedBox(height: 16),
            _buildDataRow('Sensor ID', sensorData.sensorId, Icons.sensors),
            _buildDataRow(
                'Pressure',
                '${sensorData.pressure} kPa (${sensorData.pressurePsi.toStringAsFixed(1)} PSI)',
                Icons.speed),
            _buildDataRow(
                'Temperature', '${sensorData.temperature}Â°C', Icons.thermostat),
            _buildDataRow(
                'Battery',
                '${sensorData.battery} (${sensorData.batteryVoltage.toStringAsFixed(2)}V)',
                Icons.battery_full),
            SizedBox(height: 8),
            Text(
              'Last updated: ${_formatTime(sensorData.timestamp)}',
              style: TextStyle(fontSize: 12, color: AppTheme.outline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Bind', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.onSurfaceVariant)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: AppTheme.onBackground))),
        ],
      ),
    );
  }

  void _showAlreadyBoundDialog(String sensorId, String? boundWheel) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Sensor Already Bound', style: TextStyle(color: AppTheme.onBackground)),
        content: Text(
          'Sensor $sensorId is already bound to ${boundWheel ?? "another wheel"}. '
          'Please unbind it first or choose a different sensor.',
          style: TextStyle(color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSensorDetails(SensorData sensorData, int rssi) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Sensor Details', style: TextStyle(color: AppTheme.onBackground)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDataRow('Sensor ID', sensorData.sensorId, Icons.sensors),
            Divider(color: AppTheme.outlineVariant),
            _buildDataRow(
                'Pressure (kPa)', sensorData.pressure.toString(), Icons.speed),
            _buildDataRow('Pressure (PSI)',
                sensorData.pressurePsi.toStringAsFixed(2), Icons.speed),
            _buildDataRow('Pressure (bar)',
                sensorData.pressureBar.toStringAsFixed(2), Icons.speed),
            Divider(color: AppTheme.outlineVariant),
            _buildDataRow('Temperature (Â°C)', sensorData.temperature.toString(),
                Icons.thermostat),
            _buildDataRow('Temperature (K)',
                sensorData.temperatureK.toStringAsFixed(2), Icons.thermostat),
            Divider(color: AppTheme.outlineVariant),
            _buildDataRow('Battery Raw', sensorData.battery.toString(),
                Icons.battery_full),
            _buildDataRow(
                'Battery Voltage',
                '${sensorData.batteryVoltage.toStringAsFixed(3)}V',
                Icons.battery_full),
            Divider(color: AppTheme.outlineVariant),
            _buildDataRow('RSSI', '$rssi dBm', Icons.signal_cellular_alt),
            Divider(color: AppTheme.outlineVariant),
            Text(
              'Last updated: ${_formatDateTime(sensorData.timestamp)}',
              style: TextStyle(fontSize: 12, color: AppTheme.outline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final validDevices = _discoveredDevices
        .where((device) => _deviceSensorData.containsKey(device.id))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings_input_antenna, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('TPMS PRO'),
          ],
        ),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.primary,
        elevation: 0.5,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 6),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Icon(Icons.person, size: 18, color: AppTheme.onSurfaceVariant),
          ),
          if (_isScanning)
            IconButton(
              onPressed: _stopScanning,
              icon: Icon(Icons.stop),
            )
          else
            IconButton(
              onPressed: _startScanning,
              icon: Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(16, 16, 16, 12),
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.background,
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final inset in [18.0, 36.0, 54.0])
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(inset),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primary, width: 1.6),
                        ),
                        child: Icon(
                          _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                          color: AppTheme.primary,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  _isScanning ? 'Scanning for Sensors...' : 'Ready to Scan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onBackground,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '${validDevices.length.toString().padLeft(2, '0')} DEVICES IN RANGE',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Discovered Devices',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isScanning ? AppTheme.primary : AppTheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  _isScanning ? 'Active' : 'Idle',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: _isScanning ? AppTheme.primary : AppTheme.outline,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),

          // Scan results
          Expanded(
            child: validDevices.isEmpty && !_isScanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching,
                            size: 64, color: AppTheme.outlineVariant),
                        SizedBox(height: 16),
                        Text(
                          'No sensors found',
                          style:
                              TextStyle(fontSize: 18, color: AppTheme.onSurfaceVariant),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Make sure your TPMS sensors are active and nearby',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.outline),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: validDevices.length,
                    itemBuilder: (context, index) {
                      DiscoveredDevice device = validDevices[index];
                      SensorData sensorData = _deviceSensorData[device.id]!;
                      int rssi = _deviceRssi[device.id] ?? device.rssi;

                      return Container(
                        key: ValueKey(device.id),
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(Icons.sensors, color: AppTheme.primary),
                            ),
                            title: Text(
                              device.name.isNotEmpty ? device.name : 'TPMS Sensor',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onBackground),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'ID: ${sensorData.sensorId}',
                                    style: TextStyle(color: AppTheme.onSurfaceVariant)),
                                Text('RSSI: $rssi dBm', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                                SizedBox(height: 4),
                                // Quick preview of sensor data
                                Row(
                                  children: [
                                    _buildQuickStat(
                                        Icons.speed,
                                        '${sensorData.pressurePsi.toStringAsFixed(1)} PSI',
                                        AppTheme.primary),
                                    SizedBox(width: 12),
                                    _buildQuickStat(
                                        Icons.thermostat,
                                        '${sensorData.temperature}Â°C',
                                        AppTheme.error),
                                    SizedBox(width: 12),
                                    _buildQuickStat(
                                        Icons.battery_full,
                                        '${sensorData.batteryVoltage.toStringAsFixed(1)}V',
                                        AppTheme.primary),
                                  ],
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Detailed sensor data
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailCard(
                                              'Pressure',
                                              '${sensorData.pressure} kPa\n${sensorData.pressurePsi.toStringAsFixed(2)} PSI\n${sensorData.pressureBar.toStringAsFixed(2)} bar',
                                              Icons.speed,
                                              AppTheme.primary),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: _buildDetailCard(
                                              'Temperature',
                                              '${sensorData.temperature}Â°C\n${sensorData.temperatureK.toStringAsFixed(1)} K',
                                              Icons.thermostat,
                                              AppTheme.error),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailCard(
                                              'Battery',
                                              'Raw: ${sensorData.battery}\n${sensorData.batteryVoltage.toStringAsFixed(3)}V',
                                              Icons.battery_full,
                                              AppTheme.primary),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: _buildDetailCard(
                                              'Signal',
                                              'RSSI: $rssi dBm\nUpdated: ${_formatTime(sensorData.timestamp)}',
                                              Icons.signal_cellular_alt,
                                              AppTheme.primary),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    // Action buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _showSensorDetails(
                                                sensorData, rssi),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.primary,
                                              side: BorderSide(color: AppTheme.outlineVariant),
                                            ),
                                            icon: Icon(Icons.info_outline),
                                            label: Text('Details'),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _bindSensor(device, sensorData),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              foregroundColor: AppTheme.onPrimary,
                                            ),
                                            icon: Icon(Icons.link),
                                            label: Text('Bind'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 16, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'Found ${validDevices.length} TPMS sensors with live data',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDetailCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}



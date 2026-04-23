import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'sensor_decoder.dart';
import 'sensor_id_store.dart';
import 'sensor_status.dart';
import 'ble_permissions.dart';

class SensorScanScreen extends StatefulWidget {
  final String wheelLabel;

  const SensorScanScreen({Key? key, required this.wheelLabel})
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

    if (hasPermissions) {
      _startScanning();
    }
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;

    // Check BLE status
    final bleStatus = await _ble.statusStream.first;
    if (bleStatus != BleStatus.ready) {
      _showBluetoothOffDialog();
      return;
    }

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Scan error: $error'),
                backgroundColor: Colors.red,
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

  void _showBluetoothOffDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bluetooth is Off'),
        content: Text('Please turn on Bluetooth to scan for TPMS sensors.'),
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
      if (isAlreadyBound) {
        String? boundWheel =
            await SensorIdStore.getWheelForSensor(sensorData.sensorId);
        _showAlreadyBoundDialog(sensorData.sensorId, boundWheel);
        return;
      }

      // Show detailed confirmation dialog with sensor data
      bool? confirm = await _showBindConfirmationDialog(sensorData);

      if (confirm == true) {
        await SensorIdStore.bindSensor(
          wheelLabel: widget.wheelLabel,
          sensorId: sensorData.sensorId,
          deviceId: device.id,
        );

        // Save initial sensor data
        await SensorIdStore.saveLatestSensorData(widget.wheelLabel, sensorData);

        // Update global sensor status to show it's now bound
        updateSensorStatus(
            widget.wheelLabel,
            SensorStatus(
              connected: true,
              statusColor: Colors.green,
              warningIcons: [
                Icon(Icons.bluetooth_connected, color: Colors.white, size: 12)
              ],
              message: 'Connected with live data',
            ));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Sensor ${sensorData.sensorId} bound to ${widget.wheelLabel}'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context, device.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error binding sensor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showBindConfirmationDialog(SensorData sensorData) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bind Sensor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bind this sensor to ${widget.wheelLabel}?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildDataRow('Sensor ID', sensorData.sensorId, Icons.sensors),
            _buildDataRow(
                'Pressure',
                '${sensorData.pressure} kPa (${sensorData.pressurePsi.toStringAsFixed(1)} PSI)',
                Icons.speed),
            _buildDataRow(
                'Temperature', '${sensorData.temperature}°C', Icons.thermostat),
            _buildDataRow(
                'Battery',
                '${sensorData.battery} (${sensorData.batteryVoltage.toStringAsFixed(2)}V)',
                Icons.battery_full),
            SizedBox(height: 8),
            Text(
              'Last updated: ${_formatTime(sensorData.timestamp)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Bind', style: TextStyle(color: Colors.blue[800])),
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
          Icon(icon, size: 16, color: Colors.blue[600]),
          SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showAlreadyBoundDialog(String sensorId, String? boundWheel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sensor Already Bound'),
        content: Text(
          'Sensor $sensorId is already bound to ${boundWheel ?? "another wheel"}. '
          'Please unbind it first or choose a different sensor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSensorDetails(SensorData sensorData, int rssi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sensor Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDataRow('Sensor ID', sensorData.sensorId, Icons.sensors),
            Divider(),
            _buildDataRow(
                'Pressure (kPa)', sensorData.pressure.toString(), Icons.speed),
            _buildDataRow('Pressure (PSI)',
                sensorData.pressurePsi.toStringAsFixed(2), Icons.speed),
            _buildDataRow('Pressure (bar)',
                sensorData.pressureBar.toStringAsFixed(2), Icons.speed),
            Divider(),
            _buildDataRow('Temperature (°C)', sensorData.temperature.toString(),
                Icons.thermostat),
            _buildDataRow('Temperature (K)',
                sensorData.temperatureK.toStringAsFixed(2), Icons.thermostat),
            Divider(),
            _buildDataRow('Battery Raw', sensorData.battery.toString(),
                Icons.battery_full),
            _buildDataRow(
                'Battery Voltage',
                '${sensorData.batteryVoltage.toStringAsFixed(3)}V',
                Icons.battery_full),
            Divider(),
            _buildDataRow('RSSI', '$rssi dBm', Icons.signal_cellular_alt),
            Divider(),
            Text(
              'Last updated: ${_formatDateTime(sensorData.timestamp)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
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
      appBar: AppBar(
        title: Text('Scan for ${widget.wheelLabel}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
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
          // Scanning indicator
          Container(
            padding: EdgeInsets.all(16),
            color: _isScanning ? Colors.blue[50] : Colors.grey[50],
            child: Row(
              children: [
                if (_isScanning)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.bluetooth_searching, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isScanning
                        ? 'Scanning for TPMS sensors...'
                        : 'Tap refresh to scan for sensors',
                    style: TextStyle(
                      color: _isScanning ? Colors.blue[800] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scan results
          Expanded(
            child: validDevices.isEmpty && !_isScanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching,
                            size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No sensors found',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Make sure your TPMS sensors are active and nearby',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
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

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(Icons.sensors, color: Colors.blue[800]),
                          ),
                          title: Text(
                            'Sensor ID: ${sensorData.sensorId}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Device: ${device.name.isNotEmpty ? device.name : "Unknown"}'),
                              Text('RSSI: $rssi dBm'),
                              SizedBox(height: 4),
                              // Quick preview of sensor data
                              Row(
                                children: [
                                  _buildQuickStat(
                                      Icons.speed,
                                      '${sensorData.pressurePsi.toStringAsFixed(1)} PSI',
                                      Colors.blue),
                                  SizedBox(width: 12),
                                  _buildQuickStat(
                                      Icons.thermostat,
                                      '${sensorData.temperature}°C',
                                      Colors.orange),
                                  SizedBox(width: 12),
                                  _buildQuickStat(
                                      Icons.battery_full,
                                      '${sensorData.batteryVoltage.toStringAsFixed(1)}V',
                                      Colors.green),
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
                                            Colors.blue),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: _buildDetailCard(
                                            'Temperature',
                                            '${sensorData.temperature}°C\n${sensorData.temperatureK.toStringAsFixed(1)} K',
                                            Icons.thermostat,
                                            Colors.orange),
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
                                            Colors.green),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: _buildDetailCard(
                                            'Signal',
                                            'RSSI: $rssi dBm\nUpdated: ${_formatTime(sensorData.timestamp)}',
                                            Icons.signal_cellular_alt,
                                            Colors.purple),
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
                                            backgroundColor: Colors.blue[800],
                                            foregroundColor: Colors.white,
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
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        child: Text(
          'Found ${validDevices.length} TPMS sensors with live data',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'sensor_decoder.dart';
import 'sensor_id_store.dart';
import 'sensor_status_controller.dart';
import 'sensor_config_screen.dart';
import 'threshold_settings_screen.dart';

class SensorLiveScreen extends StatefulWidget {
  final String deviceId;
  final String wheelLabel;

  const SensorLiveScreen({
    Key? key,
    required this.deviceId,
    required this.wheelLabel,
  }) : super(key: key);

  @override
  _SensorLiveScreenState createState() => _SensorLiveScreenState();
}

class _SensorLiveScreenState extends State<SensorLiveScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  SensorData? _latestData;
  BoundSensor? _boundSensor;
  SensorStatusInfo? _statusInfo;
  ThresholdSettings? _globalThresholds;
  bool _isConnected = false;

  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  Timer? _dataTimer;
  List<SensorData> _dataHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBoundSensor();
    _loadGlobalThresholds();
    _startMonitoring();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _dataTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoundSensor() async {
    _boundSensor = await SensorIdStore.getBoundSensor(widget.wheelLabel);
    _latestData = await SensorIdStore.getLatestSensorData(widget.wheelLabel);
    await _updateStatus();
  }

  Future<void> _loadGlobalThresholds() async {
    _globalThresholds = await ThresholdManager.getSettings();
    await _updateStatus();
  }

  Future<void> _updateStatus() async {
    if (_latestData != null && _globalThresholds != null) {
      // Convert global thresholds to sensor thresholds for compatibility
      final sensorThresholds = SensorThresholds(
        pressureMin: _globalThresholds!.pressureMin,
        pressureMax: _globalThresholds!.pressureMax,
        temperatureMax: _globalThresholds!.temperatureMax,
        batteryMin: _globalThresholds!.batteryMinPercentage,
      );

      _statusInfo = await SensorStatusController.getStatusInfo(
          _latestData, sensorThresholds);
    }

    // Add mounted check before setState
    if (mounted) {
      setState(() {});
    }
  }

  void _startMonitoring() {
    // For TPMS sensors, we monitor via advertisement data (broadcast mode)
    // Most TPMS sensors don't support GATT connections
    _scanSubscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.id == widget.deviceId) {
        // Add mounted check
        if (mounted) {
          setState(() {
            _isConnected = true;
          });
        }
        _processAdvertisementData(device);
      }
    });

    // Simulate periodic data updates (every 40 seconds as in original)
    _dataTimer = Timer.periodic(Duration(seconds: 40), (timer) {
      if (_boundSensor != null && mounted) {
        _simulateDataReception();
      }
    });
  }

  void _processAdvertisementData(DiscoveredDevice device) {
    // In flutter_reactive_ble, manufacturerData is List<int> directly
    if (device.manufacturerData.isNotEmpty) {
      List<int> data = device.manufacturerData;
      if (SensorDecoder.isValidPayload(data)) {
        SensorData? sensorData = SensorDecoder.decodeCompleteData(data);
        if (sensorData != null &&
            sensorData.sensorId == _boundSensor?.sensorId) {
          _processNewData(sensorData);
        }
      }
    }
  }

  void _simulateDataReception() {
    // Simulation for demo purposes (remove in production if real data is available)
    if (_boundSensor != null) {
      final sampleData = SensorData(
        sensorId: _boundSensor!.sensorId,
        pressure: 220 + (DateTime.now().millisecond % 40),
        temperature: 45 + (DateTime.now().second % 20),
        battery: 180 - (DateTime.now().minute % 60),
        timestamp: DateTime.now(),
      );

      _processNewData(sampleData);
    }
  }

  void _processNewData(SensorData data) async {
    // Add mounted check before setState
    if (!mounted) return;

    setState(() {
      _latestData = data;
      _dataHistory.add(data);
      if (_dataHistory.length > 100) {
        _dataHistory.removeAt(0);
      }
    });

    await _updateStatus();
    await SensorIdStore.saveLatestSensorData(widget.wheelLabel, data);
  }

  Future<void> _openConfiguration() async {
    if (_boundSensor == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SensorConfigScreen(
          wheelLabel: widget.wheelLabel,
          currentThresholds: _boundSensor!.thresholds,
        ),
      ),
    );

    if (result == true) {
      await _loadBoundSensor();
    }
  }

  Future<void> _openGlobalSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThresholdSettingsScreen(),
      ),
    );

    if (result == true) {
      await _loadGlobalThresholds();
    }
  }

  Future<void> _unbindSensor() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unbind Sensor'),
        content: Text(
            'Are you sure you want to unbind this sensor from ${widget.wheelLabel}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unbind', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SensorIdStore.unbindSensor(widget.wheelLabel);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.wheelLabel} Sensor'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _openGlobalSettings,
            icon: Icon(Icons.tune),
            tooltip: 'Global Settings',
          ),
          IconButton(
            onPressed: _openConfiguration,
            icon: Icon(Icons.settings),
            tooltip: 'Sensor Config',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'unbind',
                child: ListTile(
                  leading: Icon(Icons.link_off, color: Colors.red),
                  title: Text('Unbind Sensor'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'unbind') {
                _unbindSensor();
              }
            },
          ),
        ],
      ),
      body: _boundSensor == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection Status
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _isConnected
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_disabled,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isConnected ? 'Monitoring' : 'Disconnected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isConnected
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Text('Sensor ID: ${_boundSensor!.sensorId}'),
                              ],
                            ),
                          ),
                          if (_statusInfo != null)
                            SensorStatusController.buildStatusIndicator(
                                _statusInfo!,
                                size: 24),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Global Thresholds Display
                  if (_globalThresholds != null)
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.tune, color: Colors.blue[800]),
                                SizedBox(width: 8),
                                Text(
                                  'Active Thresholds',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                Spacer(),
                                TextButton(
                                  onPressed: _openGlobalSettings,
                                  child: Text('Modify'),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildThresholdInfo(
                                    'Pressure',
                                    '${_globalThresholds!.pressureMin}-${_globalThresholds!.pressureMax} PSI',
                                    Icons.speed,
                                    Colors.blue,
                                  ),
                                ),
                                Expanded(
                                  child: _buildThresholdInfo(
                                    'Temperature',
                                    'Max: ${_globalThresholds!.temperatureMax}°C',
                                    Icons.thermostat,
                                    Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            _buildThresholdInfo(
                              'Battery',
                              '${_globalThresholds!.batteryMinPercentage}% (${_globalThresholds!.batteryMinVoltage}V)',
                              Icons.battery_alert,
                              Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: 16),

                  // Current Readings
                  if (_latestData != null) ...[
                    Text(
                      'Current Readings',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDataCard(
                            'Pressure',
                            '${_latestData!.pressurePsi.toStringAsFixed(1)} PSI',
                            Icons.speed,
                            Colors.blue,
                            '${_globalThresholds?.pressureMin ?? 30}-${_globalThresholds?.pressureMax ?? 35}',
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildDataCard(
                            'Temperature',
                            '${_latestData!.temperature}°C',
                            Icons.thermostat,
                            Colors.orange,
                            'Max: ${_globalThresholds?.temperatureMax ?? 80}',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildDataCard(
                      'Battery',
                      '${(((_latestData!.battery / 255.0) * 100).round())}% (${_latestData!.batteryVoltage.toStringAsFixed(2)}V)',
                      Icons.battery_full,
                      Colors.green,
                      'Min: ${_globalThresholds?.batteryMinPercentage ?? 20}% (${_globalThresholds?.batteryMinVoltage ?? 2.2}V)',
                      fullWidth: true,
                    ),

                    SizedBox(height: 16),

                    // Status Information
                    if (_statusInfo != null) ...[
                      Text(
                        'Status',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Card(
                        color: _statusInfo!.color.withOpacity(0.1),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              SensorStatusController.buildStatusIcon(
                                  _statusInfo!),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _statusInfo!.message,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _statusInfo!.color,
                                      ),
                                    ),
                                    if (_statusInfo!.warnings.isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      ...(_statusInfo!.warnings
                                          .map((warning) => Text(
                                                '• $warning',
                                                style: TextStyle(
                                                  color: _statusInfo!.color,
                                                  fontSize: 12,
                                                ),
                                              ))
                                          .toList()),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 16),

                    // Last Updated
                    Text(
                      'Last Updated: ${_formatDateTime(_latestData!.timestamp)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          SizedBox(height: 40),
                          Icon(Icons.sensors,
                              size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'Waiting for sensor data...',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Data is received approximately every 40 seconds',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildThresholdInfo(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String threshold, {
    bool fullWidth = false,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              threshold,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}

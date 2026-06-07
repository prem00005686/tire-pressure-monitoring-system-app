import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'sensor_decoder.dart';
import 'sensor_id_store.dart';
import 'sensor_status_controller.dart';
import 'sensor_config_screen.dart';
import 'threshold_settings_screen.dart';
import 'spare_tire_manager.dart';

class SensorLiveScreen extends StatefulWidget {
  final String deviceId;
  final String wheelLabel;

  SensorLiveScreen({
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
    if (!mounted) return;
    _latestData = await SensorIdStore.getLatestSensorData(widget.wheelLabel);
    if (!mounted) return;
    await _updateStatus();
  }

  Future<void> _loadGlobalThresholds() async {
    _globalThresholds = await ThresholdManager.getSettings();
    if (!mounted) return;
    await _updateStatus();
  }

  Future<void> _updateStatus() async {
    if (!mounted) return;

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

    if (!mounted) return;

    // Add mounted check before setState
    if (mounted) {
      setState(() {});
    }
  }

  void _startMonitoring() {
    _scanSubscription?.cancel();

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
    if (!mounted) return;
    await SensorIdStore.saveLatestSensorData(widget.wheelLabel, data);
    if (!mounted) return;

    // Auto-swap logic: if a severe puncture/blast is detected, and a spare is registered,
    // automatically replace the damaged wheel with the spare to avoid manual steps.
    try {
      await _attemptAutoSwap(data);
    } catch (e) {
      // Do not let auto-swap errors affect normal flow
      print('Auto-swap error: $e');
    }
  }

  Future<void> _attemptAutoSwap(SensorData data) async {
    // Don't run auto-swap for spare or in-service slots
    if (widget.wheelLabel == 'Spare Tire' || widget.wheelLabel == 'In Service') return;

    // Define conservative thresholds for automatic replacement
    double criticalPressurePsi = 8.0; // very low absolute pressure
    double largeDropPsi = 20.0; // sudden large drop

    double latestPsi = data.pressurePsi;
    double previousPsi = _dataHistory.isNotEmpty ? _dataHistory.last.pressurePsi : latestPsi;

    bool severeLow = latestPsi <= criticalPressurePsi;
    bool suddenDrop = (previousPsi - latestPsi) >= largeDropPsi;

    if (severeLow || suddenDrop) {
      final spare = await SpareTireManager.getSpareTireSensor();
      if (spare == null) return; // no spare registered

      // Perform swap
      final success = await SpareTireManager.swapWithSpareTire(widget.wheelLabel);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.wheelLabel} detected a severe puncture â€” spare installed automatically.'),
          backgroundColor: Colors.orange,
        ));
        // Refresh local bound sensor info
        await _loadBoundSensor();
      }
    }
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
      if (!mounted) return;
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
      if (!mounted) return;
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
            child: Text('Cancel', style: TextStyle(color: AppTheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unbind', style: TextStyle(color: AppTheme.error)),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.wheelLabel} Sensor'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.primary,
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
            color: AppTheme.surface,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'unbind',
                child: ListTile(
                  leading: Icon(Icons.link_off, color: AppTheme.error),
                  title: Text('Unbind Sensor', style: TextStyle(color: AppTheme.onBackground)),
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
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection Status
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          color: _isConnected ? AppTheme.primary : AppTheme.error,
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
                                      ? AppTheme.primary
                                      : AppTheme.error,
                                ),
                              ),
                              Text(
                                'Sensor ID: ${_boundSensor!.sensorId}',
                                style: TextStyle(color: AppTheme.onSurfaceVariant),
                              ),
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

                  SizedBox(height: 16),

                  // Global Thresholds Display
                  if (_globalThresholds != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text(
                                'Active Thresholds',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onBackground,
                                ),
                              ),
                              Spacer(),
                              TextButton(
                                onPressed: _openGlobalSettings,
                                child: Text('Modify', style: TextStyle(color: AppTheme.primary)),
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
                                  AppTheme.primary,
                                ),
                              ),
                              Expanded(
                                child: _buildThresholdInfo(
                                  'Temperature',
                                  'Max: ${_globalThresholds!.temperatureMax}Â°C',
                                  Icons.thermostat,
                                  AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          _buildThresholdInfo(
                            'Battery',
                            '${_globalThresholds!.batteryMinPercentage}% (${_globalThresholds!.batteryMinVoltage}V)',
                            Icons.battery_alert,
                            AppTheme.primary,
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 16),

                  // Current Readings
                  if (_latestData != null) ...[
                    Text(
                      'Current Readings',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onBackground),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDataCard(
                            'Pressure',
                            '${_latestData!.pressurePsi.toStringAsFixed(1)} PSI',
                            Icons.speed,
                            AppTheme.primary,
                            '${_globalThresholds?.pressureMin ?? 30}-${_globalThresholds?.pressureMax ?? 35}',
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildDataCard(
                            'Temperature',
                            '${_latestData!.temperature}Â°C',
                            Icons.thermostat,
                            AppTheme.error,
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
                      AppTheme.primary,
                      'Min: ${_globalThresholds?.batteryMinPercentage ?? 20}% (${_globalThresholds?.batteryMinVoltage ?? 2.2}V)',
                      fullWidth: true,
                    ),

                    SizedBox(height: 16),

                    // Status Information
                    if (_statusInfo != null) ...[
                      Text(
                        'Status',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onBackground),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _statusInfo!.color.withValues(alpha: 0.1),
                          border: Border.all(color: _statusInfo!.color.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                                              'â€¢ $warning',
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
                    ],

                    SizedBox(height: 16),

                    // Last Updated
                    Text(
                      'Last Updated: ${_formatDateTime(_latestData!.timestamp)}',
                      style: TextStyle(color: AppTheme.outline),
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          SizedBox(height: 40),
                          Icon(Icons.sensors,
                              size: 64, color: AppTheme.outlineVariant),
                          SizedBox(height: 16),
                          Text(
                            'Waiting for sensor data...',
                            style: TextStyle(
                                fontSize: 18, color: AppTheme.onSurfaceVariant),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Data is received approximately every 40 seconds',
                            style: TextStyle(color: AppTheme.outline),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                    color: AppTheme.onSurfaceVariant,
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
    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
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
                    color: AppTheme.onBackground,
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
                color: AppTheme.outline,
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



import 'dart:convert';
import 'package:flutter/material.dart';
import 'sensor_id_store.dart';
import 'sensor_decoder.dart';
import 'sensor_status_controller.dart';
import 'sensor_status.dart';
import 'sensor_live_screen.dart';
import 'dart:async';
import 'spare_tire_manager.dart';
import 'spare_tire_screen.dart';
import 'tire_service_screen.dart';

class SensorDashboard extends StatefulWidget {
  @override
  _SensorDashboardState createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> {
  List<BoundSensor> _boundSensors = [];
  Map<String, SensorData> _latestData = {};
  Map<String, SensorStatusInfo> _sensorStatusInfo = {};
  Timer? _refreshTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      final boundSensors = await SensorIdStore.getBoundSensors();
      Map<String, SensorData> latestData = {};
      Map<String, SensorStatusInfo> statusInfo = {};

      for (BoundSensor sensor in boundSensors) {
        final data = await SensorIdStore.getLatestSensorData(sensor.wheelLabel);
        if (data != null) {
          latestData[sensor.wheelLabel] = data;
          statusInfo[sensor.wheelLabel] =
              await SensorStatusController.getStatusInfo(
                  data, sensor.thresholds);

          // Update global sensor status
          updateSensorStatus(sensor.wheelLabel,
              SensorStatus.fromStatusInfo(statusInfo[sensor.wheelLabel]!));
        } else {
          statusInfo[sensor.wheelLabel] =
              await SensorStatusController.getStatusInfo(null, null);
          updateSensorStatus(sensor.wheelLabel, SensorStatus.notConnected());
        }
      }

      // Add mounted check before setState
      if (mounted) {
        setState(() {
          _boundSensors = boundSensors;
          _latestData = latestData;
          _sensorStatusInfo = statusInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error loading dashboard data: $e');
    }
  }

  Widget _buildOverviewCard() {
    int totalSensors = _boundSensors.length;
    int connectedSensors = _latestData.length;
    int sensorsWithWarnings = _sensorStatusInfo.values
        .where((status) => SensorStatusController.shouldAlert(status))
        .length;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue[800], size: 28),
                SizedBox(width: 12),
                Text(
                  'System Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Total Sensors',
                      totalSensors.toString(), Icons.sensors, Colors.blue),
                ),
                Expanded(
                  child: _buildStatItem(
                      'Connected',
                      connectedSensors.toString(),
                      Icons.bluetooth_connected,
                      Colors.green),
                ),
                Expanded(
                  child: _buildStatItem(
                      'Warnings',
                      sensorsWithWarnings.toString(),
                      Icons.warning,
                      Colors.orange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSensorCard(BoundSensor sensor) {
    final data = _latestData[sensor.wheelLabel];
    final statusInfo = _sensorStatusInfo[sensor.wheelLabel];

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              statusInfo?.color.withOpacity(0.2) ?? Colors.grey[200],
          child: statusInfo != null
              ? SensorStatusController.buildStatusIcon(statusInfo, size: 20)
              : Icon(Icons.sensors, color: Colors.grey),
        ),
        title: Text(
          sensor.wheelLabel,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sensor ID: ${sensor.sensorId}'),
            if (data != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  _buildQuickStat(
                      Icons.speed,
                      '${data.pressurePsi.toStringAsFixed(1)} PSI',
                      Colors.blue),
                  SizedBox(width: 16),
                  _buildQuickStat(
                      Icons.thermostat, '${data.temperature}°C', Colors.orange),
                  SizedBox(width: 16),
                  _buildQuickStat(
                      Icons.battery_full,
                      '${((data.battery / 255.0) * 100).round()}%',
                      Colors.green),
                ],
              ),
            ] else
              Text('No data received',
                  style: TextStyle(color: Colors.grey[500])),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (statusInfo != null)
              SensorStatusController.buildStatusIndicator(statusInfo, size: 20),
            SizedBox(height: 4),
            Text(
              statusInfo?.message ?? 'Unknown',
              style: TextStyle(
                fontSize: 10,
                color: statusInfo?.color ?? Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sensor details for ${sensor.wheelLabel}'),
              backgroundColor: Colors.blue[800],
            ),
          );
        },
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

  Widget _buildWarningsCard() {
    List<String> criticalIssues = [];

    _sensorStatusInfo.forEach((wheelLabel, statusInfo) {
      if (SensorStatusController.shouldAlert(statusInfo)) {
        for (String warning in statusInfo.warnings) {
          criticalIssues.add('$wheelLabel: $warning');
        }
      }
    });

    if (criticalIssues.isEmpty) {
      return Card(
        color: Colors.green[50],
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All sensors are operating normally',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Text(
                  'Active Warnings (${criticalIssues.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...criticalIssues
                .take(5)
                .map((issue) => Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 6, color: Colors.red[600]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
            if (criticalIssues.length > 5)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'And ${criticalIssues.length - 5} more issues...',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sensor Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCard(),
                    SizedBox(height: 16),
                    _buildWarningsCard(),
                    SizedBox(height: 20),

                    Text(
                      'Sensor Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 12),

                    if (_boundSensors.isEmpty)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.sensors_off,
                                  size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'No sensors configured',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Go to vehicle screens to bind sensors to wheels',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._boundSensors
                          .map((sensor) => _buildSensorCard(sensor))
                          .toList(),

                    SizedBox(height: 16),

                    // Last updated info
                    Center(
                      child: Text(
                        'Last updated: ${DateTime.now().hour.toString().padLeft(2, '0')}:'
                        '${DateTime.now().minute.toString().padLeft(2, '0')}:'
                        '${DateTime.now().second.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'sensor_id_store.dart';
import 'sensor_decoder.dart';
import 'sensor_status_controller.dart';
import 'sensor_status.dart';
import 'dart:async';
// removed unused imports

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
  bool _isRefreshing = false;

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
    if (_isRefreshing) return;
    _isRefreshing = true;

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
    } finally {
      _isRefreshing = false;
    }
  }

  Widget _buildOverviewCard() {
    int totalSensors = _boundSensors.length;
    int connectedSensors = _latestData.length;
    int sensorsWithWarnings = _sensorStatusInfo.values
        .where((status) => SensorStatusController.shouldAlert(status))
        .length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 24),
      color: Color(0x00000000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Sensors',
                  totalSensors.toString(), Icons.sensors, AppTheme.outline),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                    'Connected',
                    connectedSensors.toString(),
                    Icons.bluetooth_connected,
                    AppTheme.primary),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                    'Warning',
                    sensorsWithWarnings.toString(),
                    Icons.warning,
                    AppTheme.error,
                    isWarning: sensorsWithWarnings > 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color,
      {bool isWarning = false}) {
    final bool isConnected = label == 'Connected';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning ? AppTheme.error : AppTheme.outlineVariant,
          width: 1,
        ),
        gradient: (isWarning || isConnected)
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.surface, AppTheme.surface.withValues(alpha: 0.96)],
              ),
        boxShadow: isWarning
            ? [
                BoxShadow(
                  color: AppTheme.error.withValues(alpha: 0.2),
                  blurRadius: 4,
                  spreadRadius: 0,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.9)),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isWarning || isConnected ? color : AppTheme.onSurfaceVariant,
              fontFamily: 'JetBrains Mono',
            ),
            textAlign: TextAlign.center,
          ),
          if (isWarning || isConnected) ...[
            SizedBox(height: 8),
            Container(
              height: 2,
              width: double.infinity,
              color: color.withValues(alpha: 0.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorCard(BoundSensor sensor) {
    final data = _latestData[sensor.wheelLabel];
    final statusInfo = _sensorStatusInfo[sensor.wheelLabel];
    final bool isWarning = statusInfo != null && SensorStatusController.shouldAlert(statusInfo);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning ? AppTheme.error : AppTheme.outlineVariant, // outline-variant or error
        ),
        boxShadow: isWarning
            ? [
                BoxShadow(
                  color: AppTheme.error.withValues(alpha: 0.2),
                  blurRadius: 4,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tire_repair,
                    color: isWarning ? AppTheme.error : AppTheme.primary,
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sensor.wheelLabel,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground, // on-surface
                        ),
                      ),
                      Text(
                        'ID: ${sensor.sensorId}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono',
                          color: AppTheme.onSurfaceVariant, // on-surface-variant
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isWarning)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            statusInfo.message,
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 12,
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isWarning) SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showUnbindSensorDialog(sensor),
                    icon: Icon(Icons.link_off, size: 18),
                    label: Text('Unbind'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error.withValues(alpha: 0.35)),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          if (data != null) ...[
            Container(
              padding: EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickStat(
                      'PSI',
                      data.pressurePsi.toStringAsFixed(0),
                      isWarning ? AppTheme.error : AppTheme.primary,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppTheme.outlineVariant),
                  Expanded(
                    child: _buildQuickStat(
                      'Â°C',
                      data.temperature.toStringAsFixed(0),
                      AppTheme.onBackground,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppTheme.outlineVariant),
                  Expanded(
                    child: _buildQuickStat(
                      'Batt',
                      '${((data.battery / 255.0) * 100).round()}%',
                      AppTheme.onBackground,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'No data received',
                style: TextStyle(color: AppTheme.outline),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showUnbindSensorDialog(BoundSensor sensor) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.9)),
        ),
        title: Text(
          'Unbind ${sensor.wheelLabel}?',
          style: TextStyle(
            color: AppTheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will disconnect sensor ${sensor.sensorId} from ${sensor.wheelLabel} and remove it from the dashboard.',
          style: TextStyle(
            color: AppTheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.onSurfaceVariant,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Unbind'),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;

    await SensorIdStore.unbindSensor(sensor.wheelLabel);
    if (!mounted) return;

    await _loadDashboardData();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sensor.wheelLabel} has been unbound'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
            color: AppTheme.onSurfaceVariant,
          ),
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
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          border: Border.all(color: AppTheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.primary, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'All sensors are operating normally',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color criticalBackground =
        isLight ? const Color(0xFFE91E63) : const Color(0xFF8B1D4B);
    final Color criticalOutline =
        isLight ? const Color(0xFFC2185B) : const Color(0xFFB84D79);

    return Container(
      decoration: BoxDecoration(
        color: criticalBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: criticalOutline),
        boxShadow: [
          BoxShadow(
            color: criticalOutline.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning, color: Colors.white, size: 24),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CRITICAL WARNING',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${criticalIssues.length} active issues',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          ...criticalIssues
              .take(5)
              .map((issue) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(Icons.circle, size: 8, color: AppTheme.error),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            issue,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
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
                  color: Colors.white.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            onPressed: _loadDashboardData,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCard(),
                    _buildWarningsCard(),
                    SizedBox(height: 32),

                    Text(
                      'Sensor Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onBackground, // on-surface
                      ),
                    ),
                    SizedBox(height: 16),

                    if (_boundSensors.isEmpty)
                      Container(
                        padding: EdgeInsets.all(32),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.sensors_off,
                                size: 64, color: AppTheme.outline),
                            SizedBox(height: 16),
                            Text(
                              'No sensors configured',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Go to vehicle screens to bind sensors to wheels',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.outline),
                            ),
                          ],
                        ),
                      )
                    else
                        ..._boundSensors
                          .map((sensor) => Container(
                            key: ValueKey(sensor.sensorId),
                            child: _buildSensorCard(sensor),
                            ))
                          .toList(),

                    SizedBox(height: 16),

                    // Last updated info
                    Center(
                      child: Text(
                        'Last updated: ${DateTime.now().hour.toString().padLeft(2, '0')}:'
                        '${DateTime.now().minute.toString().padLeft(2, '0')}:'
                        '${DateTime.now().second.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: AppTheme.outline,
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



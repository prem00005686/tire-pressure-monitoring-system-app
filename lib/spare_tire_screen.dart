import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'sensor_decoder.dart';
import 'sensor_id_store.dart';
import 'sensor_scan_screen.dart';
import 'spare_tire_manager.dart';

class SpareTireScreen extends StatefulWidget {
  SpareTireScreen({super.key});

  @override
  State<SpareTireScreen> createState() => _SpareTireScreenState();
}

class _SpareTireScreenState extends State<SpareTireScreen> {
  BoundSensor? _spareTireSensor;
  SensorData? _spareTireData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpareTire();
  }

  Future<void> _loadSpareTire() async {
    final spareTire = await SpareTireManager.getSpareTireSensor();
    final spareTireData = await SpareTireManager.getSpareTireData();

    if (mounted) {
      setState(() {
        _spareTireSensor = spareTire;
        _spareTireData = spareTireData;
        _isLoading = false;
      });
    }
  }

  Future<void> _registerNewSpareTire() async {
    final String? selectedDeviceId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => SensorScanScreen(wheelLabel: 'Spare Tire'),
      ),
    );

    if (selectedDeviceId != null) {
      await _loadSpareTire();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Spare Tire Management'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          Icons.tire_repair,
                          color: AppTheme.primary,
                          size: 32,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spare Tire Management',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onBackground,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Register and monitor your spare tire sensor',
                                style: TextStyle(
                                  color: Color.fromRGBO(173, 198, 255, 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  if (_spareTireSensor == null) ...[
                    _buildNoSpareTireView(),
                  ] else ...[
                    _buildSpareTireInfoCard(),
                    SizedBox(height: 24),
                    _buildTireSwapSection(),
                  ],
                  SizedBox(height: 24),
                  _buildTireSwapHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildNoSpareTireView() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tire_repair,
            size: 64,
            color: AppTheme.outline,
          ),
          SizedBox(height: 16),
          Text(
            'No Spare Tire Registered',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.onBackground,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Register your spare tire sensor to monitor its status and use it in case of emergency.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _registerNewSpareTire,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onBackground,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            icon: Icon(Icons.add),
            label: Text(
              'Register Spare Tire',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpareTireInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.secondary),
                ),
                child: Icon(
                  Icons.tire_repair,
                  color: AppTheme.onBackground,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spare Tire',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onBackground,
                      ),
                    ),
                    Text(
                      'Sensor ID: ${_spareTireSensor!.sensorId}',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showRemoveSpareTireDialog,
                icon: Icon(
                  Icons.delete,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_spareTireData != null) ...[
            Divider(color: AppTheme.outlineVariant),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDataItem(
                    'Pressure',
                    '${_spareTireData!.pressurePsi.toStringAsFixed(1)} PSI',
                    Icons.speed,
                    AppTheme.primary,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildDataItem(
                    'Temperature',
                    '${_spareTireData!.temperature}°C',
                    Icons.thermostat,
                    AppTheme.error,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildDataItem(
                    'Battery',
                    '${(((_spareTireData!.battery / 255.0) * 100).round())}%',
                    Icons.battery_full,
                    AppTheme.primary,
                  ),
                ),
              ],
            ),
          ] else ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No data available for spare tire yet',
                style: TextStyle(
                  color: AppTheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _registerNewSpareTire,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.outlineVariant),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              icon: Icon(Icons.refresh),
              label: Text(
                'Update Spare Tire',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'JetBrains Mono',
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTireSwapSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, color: AppTheme.onBackground),
              SizedBox(width: 12),
              Text(
                'Replace Punctured Tire',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onBackground,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Select which tire to replace with the spare:',
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
          SizedBox(height: 16),
          FutureBuilder<List<BoundSensor>>(
            future: SensorIdStore.getBoundSensors(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Text(
                  'No active sensors found',
                  style: TextStyle(
                    color: AppTheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              final activeSensors = snapshot.data!
                  .where((sensor) =>
                      sensor.wheelLabel != 'Spare Tire' &&
                      sensor.wheelLabel != 'In Service')
                  .toList();

              if (activeSensors.isEmpty) {
                return Text(
                  'No active wheel sensors found',
                  style: TextStyle(
                    color: AppTheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              return Column(
                children: activeSensors
                    .map(
                      (sensor) => Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.tire_repair,
                            color: AppTheme.primary,
                          ),
                          title: Text(
                            sensor.wheelLabel,
                            style: TextStyle(
                              color: AppTheme.onBackground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Sensor: ${sensor.sensorId}',
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 12,
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.onBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            onPressed: () => _showTireSwapConfirmation(sensor.wheelLabel),
                            child: Text(
                              'Replace',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTireSwapHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tire Swap History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.onBackground,
          ),
        ),
        SizedBox(height: 12),
        FutureBuilder<List<TireSwapRecord>>(
          future: SpareTireManager.getTireSwapHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    'No tire swap history',
                    style: TextStyle(
                      color: AppTheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppTheme.outlineVariant,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final record = snapshot.data![index];
                  return ListTile(
                    leading: Icon(
                      Icons.history,
                      color: AppTheme.primary,
                    ),
                    title: Text(
                      '${record.wheelLabel} Replaced',
                      style: TextStyle(
                        color: AppTheme.onBackground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date: ${record.formattedDate}',
                          style: TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                        Text(
                          'Original: ${record.damagedTireSensorId}',
                          style: TextStyle(color: AppTheme.outline),
                        ),
                        Text(
                          'Spare: ${record.spareTireSensorId}',
                          style: TextStyle(color: AppTheme.outline),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _showRemoveSpareTireDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Remove Spare Tire',
          style: TextStyle(color: AppTheme.onBackground),
        ),
        content: Text(
          'Are you sure you want to remove the spare tire sensor?',
          style: TextStyle(color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SpareTireManager.removeSpareTireSensor();
              await SensorIdStore.unbindSensor('Spare Tire');
              await _loadSpareTire();
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showTireSwapConfirmation(String wheelLabel) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Replace Tire',
          style: TextStyle(color: AppTheme.onBackground),
        ),
        content: Text(
          'Are you sure you want to replace $wheelLabel with the spare tire?\n\n'
          'This will move the spare tire sensor to $wheelLabel position and mark the original sensor as "In Service".',
          style: TextStyle(color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onBackground,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final swapSuccess = await SpareTireManager.swapWithSpareTire(wheelLabel);
              if (!mounted) return;
              if (swapSuccess) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '$wheelLabel has been replaced with the spare tire',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadSpareTire();
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to replace the tire'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Confirm Swap'),
          ),
        ],
      ),
    );
  }
}


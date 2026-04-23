import 'dart:convert';
import 'package:flutter/material.dart';
import 'sensor_decoder.dart';
import 'sensor_id_store.dart';
import 'sensor_scan_screen.dart';
import 'sensor_status_controller.dart';
import 'sensor_status.dart';
import 'spare_tire_manager.dart'; // Import the updated SpareTireManager

class SpareTireScreen extends StatefulWidget {
  @override
  _SpareTireScreenState createState() => _SpareTireScreenState();
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

    // Add mounted check before setState
    if (mounted) {
      setState(() {
        _spareTireSensor = spareTire;
        _spareTireData = spareTireData;
        _isLoading = false;
      });
    }
  }

  Future<void> _registerNewSpareTire() async {
    final String? selectedDeviceId = await Navigator.push(
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
      appBar: AppBar(
        title: Text('Spare Tire Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.tire_repair,
                              color: Colors.blue[800], size: 32),
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
                                    color: Colors.blue[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Register and monitor your spare tire sensor',
                                  style: TextStyle(color: Colors.blue[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Spare Tire Status
                  if (_spareTireSensor == null) ...[
                    _buildNoSpareTireView()
                  ] else ...[
                    _buildSpareTireInfoCard(),
                    SizedBox(height: 24),
                    _buildTireSwapSection(),
                  ],

                  SizedBox(height: 24),

                  // Tire Swap History
                  _buildTireSwapHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildNoSpareTireView() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tire_repair,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Spare Tire Registered',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Register your spare tire sensor to monitor its status and use it in case of emergency.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _registerNewSpareTire,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.add),
              label: Text('Register Spare Tire'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpareTireInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.tire_repair, color: Colors.blue[800]),
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
                        ),
                      ),
                      Text(
                        'Sensor ID: ${_spareTireSensor!.sensorId}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showRemoveSpareTireDialog,
                  icon: Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_spareTireData != null) ...[
              Divider(),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDataItem(
                      'Pressure',
                      '${_spareTireData!.pressurePsi.toStringAsFixed(1)} PSI',
                      Icons.speed,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDataItem(
                      'Temperature',
                      '${_spareTireData!.temperature}°C',
                      Icons.thermostat,
                      Colors.orange,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDataItem(
                      'Battery',
                      '${(((_spareTireData!.battery / 255.0) * 100).round())}%',
                      Icons.battery_full,
                      Colors.green,
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
                      color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ),
            ],
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _registerNewSpareTire,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                  side: BorderSide(color: Colors.blue[800]!),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.refresh),
                label: Text('Update Spare Tire'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTireSwapSection() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.amber[800]),
                SizedBox(width: 12),
                Text(
                  'Replace Punctured Tire',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Select which tire to replace with the spare:',
              style: TextStyle(color: Colors.amber[800]),
            ),
            SizedBox(height: 16),
            FutureBuilder<List<BoundSensor>>(
              future: SensorIdStore.getBoundSensors(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'No active sensors found',
                    style: TextStyle(
                        color: Colors.grey[600], fontStyle: FontStyle.italic),
                  );
                }

                List<BoundSensor> activeSensors = snapshot.data!
                    .where((sensor) =>
                        sensor.wheelLabel != 'Spare Tire' &&
                        sensor.wheelLabel != 'In Service')
                    .toList();

                if (activeSensors.isEmpty) {
                  return Text(
                    'No active wheel sensors found',
                    style: TextStyle(
                        color: Colors.grey[600], fontStyle: FontStyle.italic),
                  );
                }

                return Column(
                  children: activeSensors
                      .map((sensor) => ListTile(
                            leading: Icon(Icons.tire_repair),
                            title: Text(sensor.wheelLabel),
                            subtitle: Text('Sensor: ${sensor.sensorId}'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _showTireSwapConfirmation(sensor.wheelLabel),
                              child: Text('Replace'),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
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
            color: Colors.blue[800],
          ),
        ),
        SizedBox(height: 8),
        FutureBuilder<List<TireSwapRecord>>(
          future: SpareTireManager.getTireSwapHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No tire swap history',
                      style: TextStyle(
                          color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              );
            }

            return Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final record = snapshot.data![index];
                  return ListTile(
                    leading: Icon(Icons.history, color: Colors.blue[800]),
                    title: Text('${record.wheelLabel} Replaced'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${record.formattedDate}'),
                        Text('Original Sensor: ${record.damagedTireSensorId}'),
                        Text('Spare Sensor: ${record.spareTireSensorId}'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Spare Tire'),
        content: Text('Are you sure you want to remove the spare tire sensor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Use the SpareTireManager method instead of direct SharedPreferences access
              await SpareTireManager.removeSpareTireSensor();
              await SensorIdStore.unbindSensor('Spare Tire');
              await _loadSpareTire();
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTireSwapConfirmation(String wheelLabel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Replace Tire'),
        content: Text(
          'Are you sure you want to replace $wheelLabel with the spare tire?\n\n'
          'This will move the spare tire sensor to $wheelLabel position and mark the original sensor as "In Service".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);

              final swapSuccess =
                  await SpareTireManager.swapWithSpareTire(wheelLabel);

              if (swapSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '$wheelLabel has been replaced with the spare tire'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadSpareTire();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'sensor_id_store.dart';
import 'sensor_decoder.dart';
import 'spare_tire_manager.dart'; // Import the updated SpareTireManager

class TireServiceScreen extends StatefulWidget {
  @override
  _TireServiceScreenState createState() => _TireServiceScreenState();
}

class _TireServiceScreenState extends State<TireServiceScreen> {
  List<BoundSensor> _inServiceSensors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInServiceSensors();
  }

  Future<void> _loadInServiceSensors() async {
    final allSensors = await SensorIdStore.getBoundSensors();

    // Add mounted check before setState
    if (mounted) {
      setState(() {
        _inServiceSensors = allSensors
            .where((sensor) => sensor.wheelLabel == 'In Service')
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _reassignSensor(BoundSensor sensor) async {
    final vehicles = ['CV', 'BIKE', 'PV/SCV'];
    String? selectedVehicle;

    final wheelLabels = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Vehicle Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: vehicles
              .map((type) => ListTile(
                    title: Text(type),
                    onTap: () {
                      selectedVehicle = type;
                      Navigator.pop(
                        context,
                        _getWheelLabelsForVehicleType(type),
                      );
                    },
                  ))
              .toList(),
        ),
      ),
    );

    if (wheelLabels == null) return;

    final wheelLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Wheel Position'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: wheelLabels
              .map((label) => ListTile(
                    title: Text(label),
                    onTap: () => Navigator.pop(context, label),
                  ))
              .toList(),
        ),
      ),
    );

    if (wheelLabel == null) return;

    // Check if position is already occupied
    final existingSensor = await SensorIdStore.getBoundSensor(wheelLabel);
    if (existingSensor != null) {
      final overwrite = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Position Already Occupied'),
              content: Text(
                'This position already has sensor ${existingSensor.sensorId} assigned. '
                'Do you want to replace it with this sensor?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Replace'),
                ),
              ],
            ),
          ) ??
          false;

      if (!overwrite) return;
      await SensorIdStore.unbindSensor(wheelLabel);
    }

    // Unbind from In Service
    await SensorIdStore.unbindSensor('In Service');

    // Bind to new position
    await SensorIdStore.bindSensor(
      wheelLabel: wheelLabel,
      sensorId: sensor.sensorId,
      deviceId: sensor.deviceId,
      thresholds: sensor.thresholds,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sensor reassigned to $wheelLabel'),
        backgroundColor: Colors.green,
      ),
    );

    await _loadInServiceSensors();
  }

  List<String> _getWheelLabelsForVehicleType(String vehicleType) {
    switch (vehicleType) {
      case 'CV':
        return [
          'Sensor 1',
          'Sensor 2',
          'Sensor 3',
          'Sensor 4',
          'Sensor 5',
          'Sensor 6'
        ];
      case 'BIKE':
        return ['Sensor Front', 'Sensor Back'];
      case 'PV/SCV':
        return ['Sensor 1', 'Sensor 2', 'Sensor 3', 'Sensor 4'];
      default:
        return [];
    }
  }

  Future<void> _markAsSpare(BoundSensor sensor) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Mark as Spare Tire'),
            content: Text(
              'Do you want to designate this sensor as your spare tire sensor?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    // Unbind from In Service
    await SensorIdStore.unbindSensor('In Service');

    // Register as spare tire
    await SpareTireManager.registerSpareTireSensor(
      sensorId: sensor.sensorId,
      deviceId: sensor.deviceId,
      thresholds: sensor.thresholds,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sensor designated as spare tire'),
        backgroundColor: Colors.green,
      ),
    );

    await _loadInServiceSensors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tires In Service'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _inServiceSensors.isEmpty
              ? _buildNoSensorsView()
              : ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: _inServiceSensors.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sensor = _inServiceSensors[index];
                    return _buildSensorCard(sensor);
                  },
                ),
    );
  }

  Widget _buildNoSensorsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.car_repair,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Sensors In Service',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'When you replace a tire with a spare, the original sensor will appear here for reassignment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(BoundSensor sensor) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: Icon(Icons.tire_repair, color: Colors.grey[700]),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensor ID: ${sensor.sensorId}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'In Service (Not Mounted)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'Removed: ${_formatDateTime(sensor.boundAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markAsSpare(sensor),
                    icon: Icon(Icons.add_circle_outline),
                    label: Text('Mark as Spare'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[800],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reassignSensor(sensor),
                    icon: Icon(Icons.swap_horiz),
                    label: Text('Reassign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

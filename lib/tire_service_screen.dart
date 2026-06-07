import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'sensor_id_store.dart';
// removed unused imports
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
    // selectedVehicle not used; removed

    final wheelLabels = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Select Vehicle Type', style: TextStyle(color: AppTheme.onBackground)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: vehicles
              .map((type) => ListTile(
                    title: Text(type, style: TextStyle(color: AppTheme.onSurfaceVariant)),
                    onTap: () {
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
        backgroundColor: AppTheme.surface,
        title: Text('Select Wheel Position', style: TextStyle(color: AppTheme.onBackground)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: wheelLabels
              .map((label) => ListTile(
                    title: Text(label, style: TextStyle(color: AppTheme.onSurfaceVariant)),
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
              backgroundColor: AppTheme.surface,
              title: Text('Position Already Occupied', style: TextStyle(color: AppTheme.onBackground)),
              content: Text(
                'This position already has sensor ${existingSensor.sensorId} assigned. '
                'Do you want to replace it with this sensor?',
                style: TextStyle(color: AppTheme.onSurfaceVariant),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.primary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Replace', style: TextStyle(color: AppTheme.error)),
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
            backgroundColor: AppTheme.surface,
            title: Text('Mark as Spare Tire', style: TextStyle(color: AppTheme.onBackground)),
            content: Text(
              'Do you want to designate this sensor as your spare tire sensor?',
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: AppTheme.primary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirm', style: TextStyle(color: AppTheme.primary)),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Tires In Service'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
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
            color: AppTheme.outline,
          ),
          SizedBox(height: 16),
          Text(
            'No Sensors In Service',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.onBackground,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'When you replace a tire with a spare, the original sensor will appear here for reassignment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(BoundSensor sensor) {
    return Container(
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Icon(Icons.tire_repair, color: AppTheme.onSurfaceVariant),
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
                        color: AppTheme.onBackground,
                      ),
                    ),
                    Text(
                      'In Service (Not Mounted)',
                      style: TextStyle(color: AppTheme.onSurfaceVariant),
                    ),
                    Text(
                      'Removed: ${_formatDateTime(sensor.boundAt)}',
                      style: TextStyle(color: AppTheme.outline, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: AppTheme.outlineVariant),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markAsSpare(sensor),
                  icon: Icon(Icons.add_circle_outline),
                  label: Text('Mark as Spare', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.outlineVariant),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _reassignSensor(sensor),
                  icon: Icon(Icons.swap_horiz),
                  label: Text('Reassign', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onBackground,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}


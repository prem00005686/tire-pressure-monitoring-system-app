import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'sensor_id_store.dart';
import 'spare_tire_manager.dart';
import 'spare_tire_screen.dart';
import 'tire_service_screen.dart';


class SensorConfigScreen extends StatefulWidget {
  final String wheelLabel;
  final SensorThresholds currentThresholds;

  const SensorConfigScreen({
    Key? key,
    required this.wheelLabel,
    required this.currentThresholds,
  }) : super(key: key);

  @override
  _SensorConfigScreenState createState() => _SensorConfigScreenState();
}

class _SensorConfigScreenState extends State<SensorConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _pressureMinController;
  late TextEditingController _pressureMaxController;
  late TextEditingController _temperatureMaxController;
  late TextEditingController _batteryMinController;

  @override
  void initState() {
    super.initState();
    _pressureMinController = TextEditingController(
      text: widget.currentThresholds.pressureMin.toString(),
    );
    _pressureMaxController = TextEditingController(
      text: widget.currentThresholds.pressureMax.toString(),
    );
    _temperatureMaxController = TextEditingController(
      text: widget.currentThresholds.temperatureMax.toString(),
    );
    _batteryMinController = TextEditingController(
      text: widget.currentThresholds.batteryMin.toString(),
    );
  }

  @override
  void dispose() {
    _pressureMinController.dispose();
    _pressureMaxController.dispose();
    _temperatureMaxController.dispose();
    _batteryMinController.dispose();
    super.dispose();
  }

  Future<void> _saveThresholds() async {
    if (_formKey.currentState!.validate()) {
      final newThresholds = SensorThresholds(
        pressureMin: double.parse(_pressureMinController.text),
        pressureMax: double.parse(_pressureMaxController.text),
        temperatureMax: double.parse(_temperatureMaxController.text),
        batteryMin: int.parse(_batteryMinController.text),
      );

      await SensorIdStore.updateSensorThresholds(widget.wheelLabel, newThresholds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thresholds updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    }
  }

  void _resetToDefaults() {
    final defaults = SensorThresholds.defaultValues();
    setState(() {
      _pressureMinController.text = defaults.pressureMin.toString();
      _pressureMaxController.text = defaults.pressureMax.toString();
      _temperatureMaxController.text = defaults.temperatureMax.toString();
      _batteryMinController.text = defaults.batteryMin.toString();
    });
  }

  String? _validatePressure(String? value, bool isMin) {
    if (value == null || value.isEmpty) {
      return 'Please enter a pressure value';
    }
    
    final pressure = double.tryParse(value);
    if (pressure == null) {
      return 'Please enter a valid number';
    }
    
    if (pressure < 10 || pressure > 60) {
      return 'Pressure must be between 10-60 PSI';
    }
    
    if (isMin) {
      final maxPressure = double.tryParse(_pressureMaxController.text);
      if (maxPressure != null && pressure >= maxPressure) {
        return 'Minimum must be less than maximum';
      }
    } else {
      final minPressure = double.tryParse(_pressureMinController.text);
      if (minPressure != null && pressure <= minPressure) {
        return 'Maximum must be greater than minimum';
      }
    }
    
    return null;
  }

  String? _validateTemperature(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a temperature value';
    }
    
    final temperature = double.tryParse(value);
    if (temperature == null) {
      return 'Please enter a valid number';
    }
    
    if (temperature < 50 || temperature > 120) {
      return 'Temperature must be between 50-120°C';
    }
    
    return null;
  }

  String? _validateBattery(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a battery level';
    }
    
    final battery = int.tryParse(value);
    if (battery == null) {
      return 'Please enter a valid number';
    }
    
    if (battery < 5 || battery > 50) {
      return 'Battery level must be between 5-50%';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configure ${widget.wheelLabel}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: Text('Reset', style: TextStyle(color: Colors.blue[800])),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue[800]),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sensor Thresholds',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            Text(
                              'Set warning thresholds for ${widget.wheelLabel}',
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
              
              // Pressure Settings
              Text(
                'Pressure Thresholds (PSI)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pressureMinController,
                      validator: (value) => _validatePressure(value, true),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Minimum PSI',
                        prefixIcon: Icon(Icons.arrow_downward, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pressureMaxController,
                      validator: (value) => _validatePressure(value, false),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Maximum PSI',
                        prefixIcon: Icon(Icons.arrow_upward, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Temperature Settings
              Text(
                'Temperature Threshold',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _temperatureMaxController,
                validator: _validateTemperature,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Maximum Temperature (°C)',
                  prefixIcon: Icon(Icons.thermostat, color: Colors.orange),
                  suffixText: '°C',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  helperText: 'Alert when temperature exceeds this value',
                ),
              ),
              
              SizedBox(height: 24),
              
              // Battery Settings
              Text(
                'Battery Threshold',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _batteryMinController,
                validator: _validateBattery,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Minimum Battery Level (%)',
                  prefixIcon: Icon(Icons.battery_alert, color: Colors.amber),
                  suffixText: '%',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  helperText: 'Alert when battery falls below this level',
                ),
              ),
              
              SizedBox(height: 32),
              
              // Warning Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border.all(color: Colors.amber[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Colors.amber[800]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Notes:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '• Alerts will trigger when readings exceed these thresholds\n'
                            '• Recommended pressure range: 30-35 PSI for most vehicles\n'
                            '• Temperature alerts help prevent blowouts\n'
                            '• Low battery alerts ensure sensor reliability',
                            style: TextStyle(color: Colors.amber[700], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveThresholds,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Thresholds',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

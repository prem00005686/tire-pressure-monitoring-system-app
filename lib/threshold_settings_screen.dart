import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ThresholdSettings {
  final double pressureMin;
  final double pressureMax;
  final double temperatureMax;
  final double batteryMinVoltage;
  final int batteryMinPercentage;

  ThresholdSettings({
    required this.pressureMin,
    required this.pressureMax,
    required this.temperatureMax,
    required this.batteryMinVoltage,
    required this.batteryMinPercentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'pressureMin': pressureMin,
      'pressureMax': pressureMax,
      'temperatureMax': temperatureMax,
      'batteryMinVoltage': batteryMinVoltage,
      'batteryMinPercentage': batteryMinPercentage,
    };
  }

  factory ThresholdSettings.fromJson(Map<String, dynamic> json) {
    return ThresholdSettings(
      pressureMin: (json['pressureMin'] ?? 30.0).toDouble(),
      pressureMax: (json['pressureMax'] ?? 35.0).toDouble(),
      temperatureMax: (json['temperatureMax'] ?? 80.0).toDouble(),
      batteryMinVoltage: (json['batteryMinVoltage'] ?? 2.2).toDouble(),
      batteryMinPercentage: json['batteryMinPercentage'] ?? 20,
    );
  }

  factory ThresholdSettings.defaultValues() {
    return ThresholdSettings(
      pressureMin: 30.0,
      pressureMax: 35.0,
      temperatureMax: 80.0,
      batteryMinVoltage: 2.2,
      batteryMinPercentage: 20,
    );
  }
}

class ThresholdSettingsScreen extends StatefulWidget {
  @override
  _ThresholdSettingsScreenState createState() => _ThresholdSettingsScreenState();
}

class _ThresholdSettingsScreenState extends State<ThresholdSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _pressureMinController;
  late TextEditingController _pressureMaxController;
  late TextEditingController _temperatureMaxController;
  late TextEditingController _batteryMinPercentageController;
  
  ThresholdSettings? _currentSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSettings();
  }

  void _initializeControllers() {
    _pressureMinController = TextEditingController();
    _pressureMaxController = TextEditingController();
    _temperatureMaxController = TextEditingController();
    _batteryMinPercentageController = TextEditingController();
  }

  @override
  void dispose() {
    _pressureMinController.dispose();
    _pressureMaxController.dispose();
    _temperatureMaxController.dispose();
    _batteryMinPercentageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('threshold_settings');
      
      ThresholdSettings settings;
      if (settingsJson != null) {
        final decoded = jsonDecode(settingsJson);
        settings = ThresholdSettings.fromJson(decoded);
      } else {
        settings = ThresholdSettings.defaultValues();
      }
      
      setState(() {
        _currentSettings = settings;
        _pressureMinController.text = settings.pressureMin.toString();
        _pressureMaxController.text = settings.pressureMax.toString();
        _temperatureMaxController.text = settings.temperatureMax.toString();
        _batteryMinPercentageController.text = settings.batteryMinPercentage.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final settings = ThresholdSettings(
        pressureMin: double.parse(_pressureMinController.text),
        pressureMax: double.parse(_pressureMaxController.text),
        temperatureMax: double.parse(_temperatureMaxController.text),
        batteryMinVoltage: 2.2, // Fixed at 2.2V as requested
        batteryMinPercentage: int.parse(_batteryMinPercentageController.text),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('threshold_settings', jsonEncode(settings.toJson()));

      setState(() {
        _currentSettings = settings;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to save settings: $e');
    }
  }

  void _resetToDefaults() {
    final defaults = ThresholdSettings.defaultValues();
    setState(() {
      _pressureMinController.text = defaults.pressureMin.toString();
      _pressureMaxController.text = defaults.pressureMax.toString();
      _temperatureMaxController.text = defaults.temperatureMax.toString();
      _batteryMinPercentageController.text = defaults.batteryMinPercentage.toString();
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
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

  String? _validateBatteryPercentage(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a battery percentage';
    }
    
    final percentage = int.tryParse(value);
    if (percentage == null) {
      return 'Please enter a valid number';
    }
    
    if (percentage < 10 || percentage > 50) {
      return 'Battery percentage must be between 10-50%';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Threshold Settings'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue[800],
          elevation: 0,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Threshold Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _resetToDefaults,
            icon: Icon(Icons.refresh, color: Colors.blue[800]),
            tooltip: 'Reset to Defaults',
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
              // Header Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.blue[800], size: 32),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Global Threshold Settings',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Configure warning thresholds for all sensors',
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
              _buildSectionHeader('Pressure Thresholds', Icons.speed, Colors.blue),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _pressureMinController,
                      label: 'Minimum Pressure',
                      hint: 'PSI',
                      icon: Icons.arrow_downward,
                      color: Colors.red,
                      validator: (value) => _validatePressure(value, true),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildInputField(
                      controller: _pressureMaxController,
                      label: 'Maximum Pressure',
                      hint: 'PSI',
                      icon: Icons.arrow_upward,
                      color: Colors.red,
                      validator: (value) => _validatePressure(value, false),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Temperature Settings
              _buildSectionHeader('Temperature Threshold', Icons.thermostat, Colors.orange),
              SizedBox(height: 12),
              _buildInputField(
                controller: _temperatureMaxController,
                label: 'Maximum Temperature',
                hint: '°C',
                icon: Icons.thermostat,
                color: Colors.orange,
                validator: _validateTemperature,
                helperText: 'Alert when temperature exceeds this value',
              ),
              
              SizedBox(height: 24),
              
              // Battery Settings
              _buildSectionHeader('Battery Threshold', Icons.battery_alert, Colors.green),
              SizedBox(height: 12),
              _buildInputField(
                controller: _batteryMinPercentageController,
                label: 'Minimum Battery Level',
                hint: '%',
                icon: Icons.battery_alert,
                color: Colors.amber,
                validator: _validateBatteryPercentage,
                helperText: 'Alert when battery falls below this level',
              ),
              
              // Battery Voltage Info
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.green[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Battery voltage threshold is fixed at 2.2V for optimal sensor performance',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Current Settings Display
              if (_currentSettings != null)
                Card(
                  color: Colors.grey[50],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildSettingRow('Pressure Range', '${_currentSettings!.pressureMin} - ${_currentSettings!.pressureMax} PSI'),
                        _buildSettingRow('Max Temperature', '${_currentSettings!.temperatureMax}°C'),
                        _buildSettingRow('Min Battery', '${_currentSettings!.batteryMinPercentage}% (${_currentSettings!.batteryMinVoltage}V)'),
                      ],
                    ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.amber[800]),
                        SizedBox(width: 8),
                        Text(
                          'Important Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• These settings apply to all sensors globally\n'
                      '• Recommended pressure range: 30-35 PSI for most vehicles\n'
                      '• Temperature alerts help prevent tire blowouts\n'
                      '• Battery voltage is fixed at 2.2V for optimal performance\n'
                      '• Changes take effect immediately for all new readings',
                      style: TextStyle(color: Colors.amber[700], fontSize: 13),
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
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Settings',
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

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required String? Function(String?) validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: hint,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue),
        ),
        helperText: helperText,
        helperStyle: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for threshold management
class ThresholdManager {
  static const String _settingsKey = 'threshold_settings';
  
  static Future<ThresholdSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        final decoded = jsonDecode(settingsJson);
        return ThresholdSettings.fromJson(decoded);
      }
    } catch (e) {
      print('Error loading threshold settings: $e');
    }
    
    return ThresholdSettings.defaultValues();
  }
  
  static Future<void> saveSettings(ThresholdSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    } catch (e) {
      print('Error saving threshold settings: $e');
    }
  }
  
  static Future<void> resetToDefaults() async {
    await saveSettings(ThresholdSettings.defaultValues());
  }
}
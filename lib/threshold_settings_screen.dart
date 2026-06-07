import 'dart:convert';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// (single import above)

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

      if (!mounted) return;
      
      setState(() {
        _currentSettings = settings;
        _pressureMinController.text = settings.pressureMin.toString();
        _pressureMaxController.text = settings.pressureMax.toString();
        _temperatureMaxController.text = settings.temperatureMax.toString();
        _batteryMinPercentageController.text = settings.batteryMinPercentage.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

      if (!mounted) return;

      setState(() {
        _currentSettings = settings;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully!', style: TextStyle(color: AppTheme.onBackground)),
          backgroundColor: AppTheme.surfaceHigh,
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
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Error', style: TextStyle(color: AppTheme.error)),
        content: Text(message, style: TextStyle(color: AppTheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primary)),
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
      return 'Temperature must be between 50-120Â°C';
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
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('Threshold Settings'),
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.primary,
          elevation: 0,
        ),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Threshold Settings'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _resetToDefaults,
            icon: Icon(Icons.refresh, color: AppTheme.primary),
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
                    Icon(Icons.tune, color: AppTheme.primary, size: 32),
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
                              color: AppTheme.onBackground,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Configure warning thresholds for all sensors',
                            style: TextStyle(color: AppTheme.primary.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Pressure Settings
              _buildSectionHeader('Pressure Thresholds', Icons.speed, AppTheme.primary),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _pressureMinController,
                      label: 'Minimum Pressure',
                      hint: 'PSI',
                      icon: Icons.arrow_downward,
                      color: AppTheme.error,
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
                      color: AppTheme.error,
                      validator: (value) => _validatePressure(value, false),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Temperature Settings
              _buildSectionHeader('Temperature Threshold', Icons.thermostat, AppTheme.error),
              SizedBox(height: 12),
              _buildInputField(
                controller: _temperatureMaxController,
                label: 'Maximum Temperature',
                hint: 'Â°C',
                icon: Icons.thermostat,
                color: AppTheme.error,
                validator: _validateTemperature,
                helperText: 'Alert when temperature exceeds this value',
              ),
              
              SizedBox(height: 24),
              
              // Battery Settings
              _buildSectionHeader('Battery Threshold', Icons.battery_alert, AppTheme.primary),
              SizedBox(height: 12),
              _buildInputField(
                controller: _batteryMinPercentageController,
                label: 'Minimum Battery Level',
                hint: '%',
                icon: Icons.battery_alert,
                color: AppTheme.error,
                validator: _validateBatteryPercentage,
                helperText: 'Alert when battery falls below this level',
              ),
              
              // Battery Voltage Info
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Battery voltage threshold is fixed at 2.2V for optimal sensor performance',
                        style: TextStyle(
                          color: AppTheme.primary,
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
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildSettingRow('Pressure Range', '${_currentSettings!.pressureMin} - ${_currentSettings!.pressureMax} PSI'),
                      _buildSettingRow('Max Temperature', '${_currentSettings!.temperatureMax}Â°C'),
                      _buildSettingRow('Min Battery', '${_currentSettings!.batteryMinPercentage}% (${_currentSettings!.batteryMinVoltage}V)'),
                    ],
                  ),
                ),
              
              SizedBox(height: 32),
              
              // Warning Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningContainer.withValues(alpha: 0.5),
                  border: Border.all(color: AppTheme.warning),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: AppTheme.warning),
                        SizedBox(width: 8),
                        Text(
                          'Important Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'â€¢ These settings apply to all sensors globally\n'
                      'â€¢ Recommended pressure range: 30-35 PSI for most vehicles\n'
                      'â€¢ Temperature alerts help prevent tire blowouts\n'
                      'â€¢ Battery voltage is fixed at 2.2V for optimal performance\n'
                      'â€¢ Changes take effect immediately for all new readings',
                      style: TextStyle(color: AppTheme.warning, fontSize: 13),
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
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
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
            color: AppTheme.onBackground,
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
      style: TextStyle(color: AppTheme.onBackground, fontFamily: 'JetBrains Mono'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.outline),
        suffixText: hint,
        suffixStyle: TextStyle(color: AppTheme.onSurfaceVariant),
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary),
        ),
        fillColor: AppTheme.surfaceHigh,
        filled: true,
        helperText: helperText,
        helperStyle: TextStyle(fontSize: 12, color: AppTheme.outline),
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
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.onBackground,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for threshold management
class ThresholdManager {
  static String _settingsKey = 'threshold_settings';
  
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


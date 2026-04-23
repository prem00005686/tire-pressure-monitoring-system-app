import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sensor_dashboard.dart';
import 'sensor_status.dart';
import 'sensor_scan_screen.dart';
import 'sensor_live_screen.dart';
import 'sensor_id_store.dart';
import 'sensor_decoder.dart';
import 'sensor_status_controller.dart';
import 'threshold_settings_screen.dart';
import 'spare_tire_manager.dart';
import 'spare_tire_screen.dart';
import 'tire_service_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TPMS App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: SplashScreen(),
    );
  }
}

// User Model
class User {
  final String email;
  final String phoneNumber;
  final String userName;

  User(
      {required this.email, required this.phoneNumber, required this.userName});

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'userName': userName,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      userName: json['userName'] ?? '',
    );
  }
}

// User Service for managing user data
class UserService {
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.email);
    await prefs.setString('user_phone', user.phoneNumber);
    await prefs.setString('user_name', user.userName);
    await prefs.setBool(_isLoggedInKey, true);
  }

  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_userKey);
    final phone = prefs.getString('user_phone');
    final name = prefs.getString('user_name');

    if (email != null && phone != null && name != null) {
      return User(email: email, phoneNumber: phone, userName: name);
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove('user_phone');
    await prefs.remove('user_name');
    await prefs.setBool(_isLoggedInKey, false);
  }
}

// Spare Tire Manager class
// Spare Tire Manager class
class SpareTireManager {
  static const String _spareTireKey = 'spare_tire_sensor';

  static Future<BoundSensor?> getSpareTireSensor() async {
    final prefs = await SharedPreferences.getInstance();
    final sensorIdString = prefs.getString(_spareTireKey);

    if (sensorIdString != null) {
      try {
        // Import dart:convert at the top of your file
        Map<String, dynamic> sensorMap = Map<String, dynamic>.from(
            json.decode(sensorIdString) // Use json.decode instead of jsonDecode
            );

        return BoundSensor(
          wheelLabel: 'Spare Tire',
          sensorId: sensorMap['sensorId'] ?? '',
          deviceId: sensorMap['deviceId'] ?? '',
          thresholds: SensorThresholds.defaultValues(),
          boundAt: DateTime.now(),
        );
      } catch (e) {
        print('Error parsing spare tire sensor: $e');
        return null;
      }
    }
    return null;
  }

  static Future<void> saveSpareTireSensor(BoundSensor sensor) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> sensorMap = {
      'sensorId': sensor.sensorId,
      'deviceId': sensor.deviceId,
      'wheelLabel': 'Spare Tire',
      'thresholds': sensor.thresholds.toJson(),
      'boundAt': sensor.boundAt.millisecondsSinceEpoch,
    };
    await prefs.setString(_spareTireKey,
        json.encode(sensorMap)); // Use json.encode instead of jsonEncode
  }

  static Future<void> removeSpareTireSensor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spareTireKey);
  }

  // Rest of the code remains the same

  static Future<void> registerSpareTireSensor({
    required String sensorId,
    required String deviceId,
    SensorThresholds? thresholds,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Create bound sensor for spare tire
    final spareTire = BoundSensor(
      wheelLabel: 'Spare Tire',
      sensorId: sensorId,
      deviceId: deviceId,
      thresholds: thresholds ?? SensorThresholds.defaultValues(),
      boundAt: DateTime.now(),
    );

    // Save to SharedPreferences using the saveSpareTireSensor method
    await saveSpareTireSensor(spareTire);

    // Also bind this sensor in the regular sensor store for data tracking
    await SensorIdStore.bindSensor(
      wheelLabel: 'Spare Tire',
      sensorId: sensorId,
      deviceId: deviceId,
      thresholds: thresholds,
    );

    // Update global sensor status
    updateSensorStatus(
        'Spare Tire',
        SensorStatus(
          connected: true,
          statusColor: Colors.blue,
          warningIcons: [
            Icon(Icons.trip_origin, color: Colors.white, size: 12)
          ],
          message: 'Spare Tire',
        ));
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

// Rest of your code remains the same

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(Duration(seconds: 2));
    bool isLoggedIn = await UserService.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TPMS App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

// Login Screen
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await Future.delayed(Duration(seconds: 1));

      User user = User(
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        userName: _nameController.text.trim(),
      );

      await UserService.saveUser(user);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/wheels_india_logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if image fails to load
                        return Icon(
                          Icons.tire_repair,
                          size: 60,
                          color: Colors.blue[800],
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'WHEELS INDIA LIMITED',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Welcome to TPMS',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'Please enter your details to continue',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),
                TextFormField(
                  controller: _nameController,
                  validator: _validateName,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Login', style: TextStyle(fontSize: 16)),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dashboard Screen
class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    User? user = await UserService.getUser();
    setState(() {
      _currentUser = user;
    });
  }

  void navigateToVehicle(String type) {
    Widget screen;
    switch (type) {
      case 'CV':
        screen = CVScreen();
        break;
      case 'BIKE':
        screen = BikeScreen();
        break;
      case 'PV/SCV':
        screen = PVSCVScreen();
        break;
      default:
        return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(currentUser: _currentUser),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.blue[800]),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Dashboard',
          style:
              TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentUser != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  'Welcome, ${_currentUser!.userName}!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['CV', 'BIKE', 'PV/SCV'].map((type) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: InkWell(
                    onTap: () => navigateToVehicle(type),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          type,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// App Drawer
class AppDrawer extends StatelessWidget {
  final User? currentUser;

  const AppDrawer({Key? key, this.currentUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                    bottom: BorderSide(color: Colors.blue.withOpacity(0.2))),
              ),
              child: Column(
                children: [
                  Text(
                    'WHEELS INDIA LIMITED',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue[100],
                    child:
                        Icon(Icons.person, size: 30, color: Colors.blue[800]),
                  ),
                  SizedBox(height: 10),
                  Text(
                    currentUser?.userName ?? 'User',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (currentUser != null) ...[
                    SizedBox(height: 5),
                    Text(
                      currentUser!.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      currentUser!.phoneNumber,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(Icons.dashboard, color: Colors.blue[800]),
                    title: Text('Dashboard'),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.blue[800]),
                    title: Text('My Account'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MyAccountScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.analytics, color: Colors.blue[800]),
                    title: Text('Sensor Dashboard'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SensorDashboard()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.tune, color: Colors.blue[800]),
                    title: Text('Threshold Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ThresholdSettingsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.tire_repair, color: Colors.blue[800]),
                    title: Text('Spare Tire Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SpareTireScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.car_repair, color: Colors.blue[800]),
                    title: Text('Tires In Service'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TireServiceScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.settings, color: Colors.blue[800]),
                    title: Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SettingsScreen()),
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await UserService.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// My Account Screen
class MyAccountScreen extends StatefulWidget {
  @override
  _MyAccountScreenState createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  User? _currentUser;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _loadUser();
  }

  Future<void> _loadUser() async {
    User? user = await UserService.getUser();
    if (user != null) {
      setState(() {
        _currentUser = user;
        _nameController.text = user.userName;
        _emailController.text = user.email;
        _phoneController.text = user.phoneNumber;
      });
    }
  }

  Future<void> _updateUser() async {
    if (_formKey.currentState!.validate()) {
      User updatedUser = User(
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        userName: _nameController.text.trim(),
      );

      await UserService.saveUser(updatedUser);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.blue[800],
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Account', style: TextStyle(color: Colors.blue[800])),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[800]),
      ),
      body: _currentUser == null
          ? Center(child: CircularProgressIndicator(color: Colors.blue))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue[100],
                      child:
                          Icon(Icons.person, size: 50, color: Colors.blue[800]),
                    ),
                    SizedBox(height: 30),
                    TextFormField(
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _updateUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Update Profile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: Colors.blue[800])),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[800]),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.notifications, color: Colors.blue[800]),
            title: Text('Notifications'),
            trailing: Switch(
              value: true,
              onChanged: (value) {},
              activeColor: Colors.blue[800],
            ),
          ),
          ListTile(
            leading: Icon(Icons.bluetooth, color: Colors.blue[800]),
            title: Text('Bluetooth'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue[800]),
            onTap: () {
              // Add bluetooth settings navigation
            },
          ),
          ListTile(
            leading: Icon(Icons.warning, color: Colors.blue[800]),
            title: Text('Alert Settings'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue[800]),
            onTap: () {
              // Navigate to alert settings
            },
          ),
          ListTile(
            leading: Icon(Icons.info, color: Colors.blue[800]),
            title: Text('About'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue[800]),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('About TPMS App'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TPMS App v1.0'),
                      Text('Tire Pressure Monitoring System'),
                      SizedBox(height: 10),
                      Text('© Wheels India Limited'),
                      Text('All rights reserved'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child:
                          Text('OK', style: TextStyle(color: Colors.blue[800])),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Spare Tire Screen
class SpareTireScreen extends StatefulWidget {
  @override
  _SpareTireScreenState createState() => _SpareTireScreenState();
}

class _SpareTireScreenState extends State<SpareTireScreen> {
  BoundSensor? _spareTireSensor;
  SensorStatus? _sensorStatus;
  SensorData? _sensorData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpareTireData();
  }

  Future<void> _loadSpareTireData() async {
    setState(() {
      _isLoading = true;
    });

    _spareTireSensor = await SpareTireManager.getSpareTireSensor();

    if (_spareTireSensor != null) {
      _sensorData = await SensorIdStore.getLatestSensorData('Spare Tire');

      if (_sensorData != null) {
        final statusInfo = await SensorStatusController.getStatusInfo(
            _sensorData!, _spareTireSensor!.thresholds);
        _sensorStatus = SensorStatus.fromStatusInfo(statusInfo);
      } else {
        _sensorStatus = SensorStatus(
          connected: true,
          statusColor: Colors.blue,
          warningIcons: [
            Icon(Icons.bluetooth_connected, color: Colors.white, size: 12)
          ],
          message: 'Connected - Waiting for data',
        );
      }
    } else {
      _sensorStatus = SensorStatus.notConnected();
    }

    if (mounted) {
      setState(() {
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
      // Handle the new device registration
      await _loadSpareTireData();
    }
  }

  Future<void> _removeSpareTire() async {
    // Show confirmation dialog
    final bool shouldRemove = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove Spare Tire'),
            content:
                Text('Are you sure you want to remove the spare tire sensor?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldRemove) {
      await SpareTireManager.removeSpareTireSensor();
      await _loadSpareTireData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spare Tire', style: TextStyle(color: Colors.blue[800])),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[800]),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Spare Tire Sensor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sensorStatus?.statusColor ?? Colors.grey,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_sensorStatus?.statusColor ?? Colors.grey)
                                        .withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _spareTireSensor != null
                                  ? Icons.tire_repair
                                  : Icons.add_circle,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _spareTireSensor != null
                              ? 'Sensor ID: ${_spareTireSensor!.sensorId}'
                              : 'No spare tire sensor registered',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_sensorData != null) ...[
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDataCard(
                                'Pressure',
                                '${_sensorData!.pressurePsi.toStringAsFixed(1)} PSI',
                                Icons.speed,
                                Colors.blue[700]!,
                              ),
                              SizedBox(width: 16),
                              _buildDataCard(
                                'Temperature',
                                '${_sensorData!.temperature}°C',
                                Icons.thermostat,
                                Colors.orange[700]!,
                              ),
                              if (_sensorData != null) ...[
                                SizedBox(width: 16),
                                _buildDataCard(
                                  'Battery',
                                  '${(((_sensorData!.battery / 255.0) * 100).round())}%',
                                  Icons.battery_full,
                                  Colors.green[700]!,
                                ),
                              ],
                            ],
                          ),
                        ],
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _registerNewSpareTire,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _spareTireSensor == null
                                    ? Colors.blue[800]
                                    : Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              child: Text(_spareTireSensor == null
                                  ? 'Register Sensor'
                                  : 'Update Sensor'),
                            ),
                            if (_spareTireSensor != null) ...[
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _removeSpareTire,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                child: Text('Remove'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spare Tire Management',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Register your spare tire sensor to monitor its condition even when not in use. This helps ensure it\'s ready when needed.',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Best practices:',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          _buildBulletPoint(
                              'Check spare tire pressure regularly'),
                          _buildBulletPoint(
                              'Maintain proper inflation even for spare tires'),
                          _buildBulletPoint(
                              'Replace spare tire sensor battery when needed'),
                          _buildBulletPoint(
                              'Rotate spare tire into regular use occasionally'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDataCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: 90,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 14, color: Colors.blue[800])),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

// Tires In Service Screen
class TireServiceScreen extends StatefulWidget {
  @override
  _TireServiceScreenState createState() => _TireServiceScreenState();
}

class _TireServiceScreenState extends State<TireServiceScreen> {
  List<TireServiceRecord> _serviceRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServiceRecords();
  }

  Future<void> _loadServiceRecords() async {
    // Simulate loading service records
    await Future.delayed(Duration(seconds: 1));

    // Dummy data for now
    setState(() {
      _serviceRecords = [
        TireServiceRecord(
          tireId: 'T-001',
          vehicleType: 'CV',
          position: 'Front Left',
          installDate: DateTime.now().subtract(Duration(days: 120)),
          mileage: 15000,
          condition: 'Good',
          nextServiceDate: DateTime.now().add(Duration(days: 30)),
        ),
        TireServiceRecord(
          tireId: 'T-002',
          vehicleType: 'CV',
          position: 'Front Right',
          installDate: DateTime.now().subtract(Duration(days: 120)),
          mileage: 15000,
          condition: 'Good',
          nextServiceDate: DateTime.now().add(Duration(days: 30)),
        ),
        TireServiceRecord(
          tireId: 'T-003',
          vehicleType: 'PV/SCV',
          position: 'Rear Left',
          installDate: DateTime.now().subtract(Duration(days: 60)),
          mileage: 5000,
          condition: 'Excellent',
          nextServiceDate: DateTime.now().add(Duration(days: 90)),
        ),
        TireServiceRecord(
          tireId: 'T-004',
          vehicleType: 'BIKE',
          position: 'Front',
          installDate: DateTime.now().subtract(Duration(days: 200)),
          mileage: 12000,
          condition: 'Fair',
          nextServiceDate: DateTime.now().add(Duration(days: 15)),
          notes: 'Consider replacement soon',
        ),
      ];
      _isLoading = false;
    });
  }

  void _addNewServiceRecord() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TireServiceForm(
          onSave: (TireServiceRecord newRecord) {
            setState(() {
              _serviceRecords.add(newRecord);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Tires In Service', style: TextStyle(color: Colors.blue[800])),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[800]),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.blue[800]),
            onPressed: _addNewServiceRecord,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue))
          : _serviceRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.car_repair,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No tire service records found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _addNewServiceRecord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Add Service Record'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _serviceRecords.length,
                  itemBuilder: (context, index) {
                    final record = _serviceRecords[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tire ID: ${record.tireId}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: record.condition == 'Good' ||
                                            record.condition == 'Excellent'
                                        ? Colors.green[100]
                                        : record.condition == 'Fair'
                                            ? Colors.amber[100]
                                            : Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    record.condition,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: record.condition == 'Good' ||
                                              record.condition == 'Excellent'
                                          ? Colors.green[800]
                                          : record.condition == 'Fair'
                                              ? Colors.amber[800]
                                              : Colors.red[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                _buildInfoItem(
                                    'Vehicle Type:', record.vehicleType),
                                SizedBox(width: 20),
                                _buildInfoItem('Position:', record.position),
                              ],
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                _buildInfoItem(
                                  'Installed:',
                                  '${record.installDate.day}/${record.installDate.month}/${record.installDate.year}',
                                ),
                                SizedBox(width: 20),
                                _buildInfoItem(
                                    'Mileage:', '${record.mileage} km'),
                              ],
                            ),
                            SizedBox(height: 6),
                            _buildInfoItem(
                              'Next Service:',
                              '${record.nextServiceDate.day}/${record.nextServiceDate.month}/${record.nextServiceDate.year}',
                              color:
                                  DateTime.now().isAfter(record.nextServiceDate)
                                      ? Colors.red[700]
                                      : null,
                            ),
                            if (record.notes != null &&
                                record.notes!.isNotEmpty) ...[
                              SizedBox(height: 6),
                              _buildInfoItem('Notes:', record.notes!),
                            ],
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    // Edit record
                                  },
                                  child: Text('Edit'),
                                ),
                                SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    // Record service
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Record Service'),
                                        content: Text(
                                            'Record a maintenance service for this tire?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content:
                                                      Text('Service recorded'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            },
                                            child: Text('Record'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Text('Record Service'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

// Form for adding a new service record
class TireServiceForm extends StatefulWidget {
  final Function(TireServiceRecord) onSave;

  TireServiceForm({required this.onSave});

  @override
  _TireServiceFormState createState() => _TireServiceFormState();
}

class _TireServiceFormState extends State<TireServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tireIdController;
  String _selectedVehicleType = 'CV';
  String _selectedPosition = 'Front Left';
  late TextEditingController _mileageController;
  String _selectedCondition = 'Good';
  DateTime _installDate = DateTime.now();
  DateTime _nextServiceDate = DateTime.now().add(Duration(days: 90));
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _tireIdController = TextEditingController();
    _mileageController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _tireIdController.dispose();
    _mileageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectInstallDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _installDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _installDate) {
      setState(() {
        _installDate = picked;
      });
    }
  }

  void _selectNextServiceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextServiceDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _nextServiceDate) {
      setState(() {
        _nextServiceDate = picked;
      });
    }
  }

  void _saveRecord() {
    if (_formKey.currentState!.validate()) {
      final newRecord = TireServiceRecord(
        tireId: _tireIdController.text,
        vehicleType: _selectedVehicleType,
        position: _selectedPosition,
        installDate: _installDate,
        mileage: int.parse(_mileageController.text),
        condition: _selectedCondition,
        nextServiceDate: _nextServiceDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      widget.onSave(newRecord);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Service Record',
            style: TextStyle(color: Colors.blue[800])),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[800]),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _tireIdController,
                decoration: InputDecoration(
                  labelText: 'Tire ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a tire ID';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['CV', 'BIKE', 'PV/SCV'].map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedVehicleType = newValue;
                      // Update position options based on vehicle type
                      if (newValue == 'BIKE') {
                        _selectedPosition = 'Front';
                      } else if (newValue == 'CV') {
                        _selectedPosition = 'Front Left';
                      } else {
                        _selectedPosition = 'Front Left';
                      }
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: InputDecoration(
                  labelText: 'Position',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _getPositionOptions().map((String position) {
                  return DropdownMenuItem<String>(
                    value: position,
                    child: Text(position),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPosition = newValue;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectInstallDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Install Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_installDate.day}/${_installDate.month}/${_installDate.year}',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _mileageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Mileage (km)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter mileage';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCondition,
                decoration: InputDecoration(
                  labelText: 'Condition',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Excellent', 'Good', 'Fair', 'Poor']
                    .map((String condition) {
                  return DropdownMenuItem<String>(
                    value: condition,
                    child: Text(condition),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCondition = newValue;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              InkWell(
                onTap: _selectNextServiceDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Next Service Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_nextServiceDate.day}/${_nextServiceDate.month}/${_nextServiceDate.year}',
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _saveRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Save Service Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getPositionOptions() {
    switch (_selectedVehicleType) {
      case 'CV':
        return [
          'Front Left',
          'Front Right',
          'Middle Left',
          'Middle Right',
          'Rear Left',
          'Rear Right'
        ];
      case 'BIKE':
        return ['Front', 'Back'];
      case 'PV/SCV':
        return ['Front Left', 'Front Right', 'Rear Left', 'Rear Right'];
      default:
        return ['Front Left', 'Front Right', 'Rear Left', 'Rear Right'];
    }
  }
}

// Tire Service Record model
class TireServiceRecord {
  final String tireId;
  final String vehicleType;
  final String position;
  final DateTime installDate;
  final int mileage;
  final String condition;
  final DateTime nextServiceDate;
  final String? notes;

  TireServiceRecord({
    required this.tireId,
    required this.vehicleType,
    required this.position,
    required this.installDate,
    required this.mileage,
    required this.condition,
    required this.nextServiceDate,
    this.notes,
  });
}

// Vehicle Screens
class CVScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VehicleScreen(title: 'CV', vehicleType: 'CV');
  }
}

class BikeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VehicleScreen(title: 'Bike', vehicleType: 'BIKE');
  }
}

class PVSCVScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VehicleScreen(title: 'PV/SCV', vehicleType: 'PV/SCV');
  }
}

class VehicleScreen extends StatefulWidget {
  final String title;
  final String vehicleType;

  const VehicleScreen(
      {Key? key, required this.title, required this.vehicleType})
      : super(key: key);

  @override
  _VehicleScreenState createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  Map<String, SensorStatus> _sensorStatuses = {};
  Map<String, SensorData> _latestSensorData = {};

  @override
  void initState() {
    super.initState();
    _loadSensorStatuses();
  }

  Future<void> _loadSensorStatuses() async {
    final boundSensors = await SensorIdStore.getBoundSensors();
    Map<String, SensorStatus> statuses = {};
    Map<String, SensorData> sensorData = {};

    // Initialize all sensors as not connected
    List<String> sensorLabels =
        _getSensorLabelsForVehicleType(widget.vehicleType);
    for (String label in sensorLabels) {
      statuses[label] = SensorStatus.notConnected();
    }

    // Update status for bound sensors
    for (BoundSensor boundSensor in boundSensors) {
      if (sensorLabels.contains(boundSensor.wheelLabel)) {
        final latestData =
            await SensorIdStore.getLatestSensorData(boundSensor.wheelLabel);
        if (latestData != null) {
          sensorData[boundSensor.wheelLabel] = latestData;
          final statusInfo = await SensorStatusController.getStatusInfo(
              latestData, boundSensor.thresholds);
          statuses[boundSensor.wheelLabel] =
              SensorStatus.fromStatusInfo(statusInfo);
        } else {
          // Sensor is bound but no data yet - show as connected but waiting for data
          statuses[boundSensor.wheelLabel] = SensorStatus(
            connected: true,
            statusColor: Colors.blue,
            warningIcons: [
              Icon(Icons.bluetooth_connected, color: Colors.white, size: 12)
            ],
            message: 'Connected - Waiting for data',
          );
        }
      }
    }

    // Add mounted check before setState
    if (mounted) {
      setState(() {
        _sensorStatuses = statuses;
        _latestSensorData = sensorData;
      });
    }
  }

  List<String> _getSensorLabelsForVehicleType(String vehicleType) {
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

  Future<void> handleSensorAdd(BuildContext context, String wheelLabel) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SensorScanScreen(wheelLabel: wheelLabel),
      ),
    );

    if (result != null && context.mounted) {
      // Reload sensor statuses after binding
      await _loadSensorStatuses();

      // Get the bound sensor to retrieve device ID
      final boundSensor = await SensorIdStore.getBoundSensor(wheelLabel);
      if (boundSensor != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SensorLiveScreen(
              deviceId: boundSensor.deviceId,
              wheelLabel: wheelLabel,
            ),
          ),
        );
      }
    }
  }

  Widget buildSensorButton(BuildContext context, String label) {
    final status = _sensorStatuses[label] ?? SensorStatus.notConnected();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: status.statusColor.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: status.statusColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: Size(50, 28), // Slightly larger buttons
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          textStyle: TextStyle(fontSize: 8),
        ),
        onPressed: () => handleSensorAdd(context, label),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                )),
            SizedBox(width: 2),
            ...status.warningIcons,
          ],
        ),
      ),
    );
  }

  Widget buildSensorDataDisplay(String label) {
    final sensorData = _latestSensorData[label];
    final status = _sensorStatuses[label];

    if (sensorData == null || !status!.connected) {
      return SizedBox.shrink(); // Don't show data if no sensor data
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${sensorData.pressurePsi.toStringAsFixed(1)} PSI',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          Text(
            '${sensorData.temperature}°C',
            style: TextStyle(
              fontSize: 8,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVehicleImage(String vehicleType) {
    String imagePath;
    double imageWidth;
    double imageHeight;

    switch (vehicleType) {
      case 'BIKE':
        imagePath = 'assets/images/bike.png';
        imageWidth = 350; // Increased from 300
        imageHeight = 250; // Increased from 200
        break;
      case 'CV':
        imagePath = 'assets/images/truck.png';
        imageWidth = 400; // Increased significantly for truck
        imageHeight = 280; // Increased significantly for truck
        break;
      case 'PV/SCV':
        imagePath = 'assets/images/car.png';
        imageWidth = 380; // Increased significantly for car
        imageHeight = 260; // Increased significantly for car
        break;
      default:
        imagePath = 'assets/images/car.png';
        imageWidth = 380;
        imageHeight = 260;
    }

    return Container(
      width: imageWidth,
      height: imageHeight,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image fails to load
            IconData iconData;
            switch (vehicleType) {
              case 'BIKE':
                iconData = Icons.motorcycle;
                break;
              case 'CV':
                iconData = Icons.local_shipping;
                break;
              case 'PV/SCV':
                iconData = Icons.directions_car;
                break;
              default:
                iconData = Icons.directions_car;
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData,
                  size: 100, // Increased icon size too
                  color: Colors.grey[400],
                ),
                SizedBox(height: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 28, // Increased text size
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Image not found',
                  style: TextStyle(
                    fontSize: 14, // Increased text size
                    color: Colors.red[400],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Method to get sensor status for spare tire
  SensorStatus getSensorStatus(String wheelLabel) {
    if (wheelLabel == 'Spare Tire') {
      // This method will retrieve status for spare tire
      return _sensorStatuses[wheelLabel] ??
          SensorStatus(
            connected: true,
            statusColor: Colors.blue,
            warningIcons: [
              Icon(Icons.tire_repair, color: Colors.white, size: 12)
            ],
            message: 'Spare Tire',
          );
    }
    return _sensorStatuses[wheelLabel] ?? SensorStatus.notConnected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.blue[800]),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title, style: TextStyle(color: Colors.blue[800])),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue[800]),
            onPressed: _loadSensorStatuses,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    buildVehicleImage(widget.vehicleType),
                    if (widget.vehicleType == 'BIKE') ...[
                      // Front sensor with data display
                      Positioned(
                        left: 35, // Adjusted for larger image
                        bottom: 35, // Adjusted for larger image
                        child: Column(
                          children: [
                            buildSensorDataDisplay('Sensor Front'),
                            SizedBox(height: 4),
                            buildSensorButton(context, 'Sensor Front'),
                          ],
                        ),
                      ),
                      // Back sensor with data display
                      Positioned(
                        right: 35, // Adjusted for larger image
                        bottom: 35, // Adjusted for larger image
                        child: Column(
                          children: [
                            buildSensorDataDisplay('Sensor Back'),
                            SizedBox(height: 4),
                            buildSensorButton(context, 'Sensor Back'),
                          ],
                        ),
                      ),
                      // Add spare tire visualization
                      Positioned(
                        bottom: 20, // Adjust position as needed
                        child: FutureBuilder<BoundSensor?>(
                          future: SpareTireManager.getSpareTireSensor(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data == null) {
                              return SizedBox
                                  .shrink(); // No spare tire registered
                            }

                            // Get status for spare tire
                            final status = getSensorStatus('Spare Tire');

                            return Column(
                              children: [
                                buildSensorDataDisplay('Spare Tire'),
                                SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                SpareTireScreen()),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Spare Tire',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        SizedBox(width: 2),
                                        ...status.warningIcons,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ] else if (widget.vehicleType == 'CV') ...[
                      // Left side sensors with data displays
                      Positioned(
                        left: 12,
                        top: 35, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorDataDisplay('Sensor 1'),
                            SizedBox(width: 4),
                            buildSensorButton(context, 'Sensor 1'),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 100, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorDataDisplay('Sensor 3'),
                            SizedBox(width: 4),
                            buildSensorButton(context, 'Sensor 3'),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 35, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorDataDisplay('Sensor 5'),
                            SizedBox(width: 4),
                            buildSensorButton(context, 'Sensor 5'),
                          ],
                        ),
                      ),
                      // Right side sensors with data displays
                      Positioned(
                        right: 12,
                        top: 35, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorButton(context, 'Sensor 2'),
                            SizedBox(width: 4),
                            buildSensorDataDisplay('Sensor 2'),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 100, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorButton(context, 'Sensor 4'),
                            SizedBox(width: 4),
                            buildSensorDataDisplay('Sensor 4'),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 35, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorButton(context, 'Sensor 6'),
                            SizedBox(width: 4),
                            buildSensorDataDisplay('Sensor 6'),
                          ],
                        ),
                      ),
                      // Add spare tire visualization
                      Positioned(
                        bottom: 20, // Adjust position as needed
                        child: FutureBuilder<BoundSensor?>(
                          future: SpareTireManager.getSpareTireSensor(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data == null) {
                              return SizedBox
                                  .shrink(); // No spare tire registered
                            }

                            // Get status for spare tire
                            final status = getSensorStatus('Spare Tire');

                            return Column(
                              children: [
                                buildSensorDataDisplay('Spare Tire'),
                                SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                SpareTireScreen()),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Spare Tire',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        SizedBox(width: 2),
                                        ...status.warningIcons,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ] else if (widget.vehicleType == 'PV/SCV') ...[
                      // Left side sensors with data displays
                      Positioned(
                        left: 25, // Adjusted for larger image
                        top: 60, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorDataDisplay('Sensor 1'),
                            SizedBox(width: 4),
                            buildSensorButton(context, 'Sensor 1'),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 25,
                        bottom: 60, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorDataDisplay('Sensor 3'),
                            SizedBox(width: 4),
                            buildSensorButton(context, 'Sensor 3'),
                          ],
                        ),
                      ),
                      // Right side sensors with data displays
                      Positioned(
                        right: 25, // Adjusted for larger image
                        top: 60, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorButton(context, 'Sensor 2'),
                            SizedBox(width: 4),
                            buildSensorDataDisplay('Sensor 2'),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 25,
                        bottom: 60, // Adjusted for larger image
                        child: Row(
                          children: [
                            buildSensorButton(context, 'Sensor 4'),
                            SizedBox(width: 4),
                            buildSensorDataDisplay('Sensor 4'),
                          ],
                        ),
                      ),
                      // Add spare tire visualization
                      Positioned(
                        bottom: 20, // Adjust position as needed
                        child: FutureBuilder<BoundSensor?>(
                          future: SpareTireManager.getSpareTireSensor(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data == null) {
                              return SizedBox
                                  .shrink(); // No spare tire registered
                            }

                            // Get status for spare tire
                            final status = getSensorStatus('Spare Tire');

                            return Column(
                              children: [
                                buildSensorDataDisplay('Spare Tire'),
                                SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                SpareTireScreen()),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Spare Tire',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        SizedBox(width: 2),
                                        ...status.warningIcons,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ]
                  ],
                ),
                SizedBox(height: 30), // Increased spacing
                // Status legend
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sensor Status Legend:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _buildLegendItem(
                                Colors.green, 'Normal', Icons.check_circle),
                            _buildLegendItem(
                                Colors.red, 'Pressure Issue', Icons.warning),
                            _buildLegendItem(
                                Colors.orange, 'High Temp', Icons.thermostat),
                            _buildLegendItem(Colors.amber, 'Low Battery',
                                Icons.battery_alert),
                            _buildLegendItem(Colors.black, 'Not Connected',
                                Icons.bluetooth_disabled),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 10,
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BlePermissions {
  static Future<bool> requestPermissions(BuildContext context) async {
    if (Platform.isAndroid) {
      return await _requestAndroidPermissions(context);
    } else if (Platform.isIOS) {
      return await _requestiOSPermissions();
    }
    return false;
  }

  static Future<bool> _requestAndroidPermissions(BuildContext context) async {
    // Check Android version
    final androidInfo = await _getAndroidVersion();

    Map<Permission, PermissionStatus> statuses;

    if (androidInfo >= 31) {
      // Android 12+ (API 31+)
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    } else if (androidInfo >= 23) {
      // Android 6 - 11 (API 23-30)
      statuses = await [
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ].request();
    } else {
      // Below Android 6
      return true;
    }

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      await _showPermissionDialog(context);
      return false;
    }

    return true;
  }

  static Future<bool> _requestiOSPermissions() async {
    final status = await Permission.bluetooth.request();
    return status.isGranted;
  }

  static Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      return 31; // Default to Android 12+ for safety
    }
    return 0;
  }

  static Future<void> _showPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permissions Required'),
        content: Text(
          'This app needs Bluetooth and Location permissions to scan for TPMS sensors. '
          'Please grant these permissions in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Settings'),
          ),
        ],
      ),
    );
  }

  static Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();

      if (androidInfo >= 31) {
        return await Permission.bluetoothScan.isGranted &&
            await Permission.bluetoothConnect.isGranted &&
            await Permission.locationWhenInUse.isGranted;
      } else {
        return await Permission.bluetooth.isGranted &&
            await Permission.locationWhenInUse.isGranted;
      }
    } else if (Platform.isIOS) {
      return await Permission.bluetooth.isGranted;
    }
    return false;
  }
}

# TPMS Pro (Flutter)

TPMS Pro is a Flutter mobile application for discovering and monitoring tire pressure sensors over Bluetooth Low Energy (BLE). It supports sensor binding, live monitoring, threshold-based alerts, spare-tire workflows, and local persistence for operational continuity.

## Table of Contents

1. Overview
2. Core Features
3. Architecture
4. Data Model and Persistence
5. BLE and Telemetry Pipeline
6. User Flows
7. Setup and Run
8. Build and Release
9. Permissions and Platform Notes
10. Troubleshooting
11. Development Guide

## 1. Overview

The app is designed for vehicle tire monitoring scenarios where sensors broadcast telemetry over BLE advertisement data. It focuses on quick setup and clear operational actions:

- Bind sensors to wheel positions.
- Monitor pressure, temperature, battery, and connectivity.
- Detect abnormal conditions through threshold checks.
- Manage spare-tire registration and wheel replacement workflows.
- Unbind sensors from multiple operational screens.

## 2. Core Features

- Vehicle-specific wheel layouts for CV, BIKE, and PV/SCV.
- Sensor scanning and binding by wheel label.
- Live sensor screen with status evaluation and threshold awareness.
- Sensor dashboard with card-level health summary and unbind action.
- Spare tire management with swap and swap-history support.
- Global threshold settings for pressure, temperature, and battery.
- Local persistence with SharedPreferences for key runtime state.

## 3. Architecture

Primary modules:

- `lib/main.dart`: Entry point and several app screens including vehicle view and routing.
- `lib/sensor_scan_screen.dart`: BLE scan and sensor binding flow.
- `lib/sensor_live_screen.dart`: Monitoring view for a single wheel-bound sensor.
- `lib/sensor_dashboard.dart`: Fleet-style dashboard and per-sensor unbind controls.
- `lib/spare_tire_screen.dart`: Spare-tire registration and management UI.
- `lib/spare_tire_manager.dart`: Spare workflows, swap operation, and swap history persistence.
- `lib/sensor_id_store.dart`: SharedPreferences repository for bound sensors and latest samples.
- `lib/sensor_decoder.dart`: Sensor payload decoding and unit conversion helpers.
- `lib/sensor_status_controller.dart`: Warning evaluation and status classification.
- `lib/threshold_settings_screen.dart`: Global threshold editor.
- `lib/app_theme.dart`: Theme tokens and light/dark theme setup.

## 4. Data Model and Persistence

Main persisted data:

- Bound sensors list (wheel label, sensor ID, device ID, thresholds, bind timestamp).
- Latest sensor sample per wheel label.
- Spare tire sensor record and cached spare sample.
- Tire swap history records.
- Global threshold settings.
- Basic user session/profile values.

Persistence backend:

- SharedPreferences is used as the local data store.
- Data is serialized as JSON for structured models.

Important behavior notes:

- Unbind removes wheel mapping and dashboard visibility for that wheel.
- Spare swap moves the target wheel sensor to `In Service` and installs the spare mapping into the selected wheel.

## 5. BLE and Telemetry Pipeline

At a high level:

1. BLE scanning discovers candidate devices.
2. Advertisement payload is validated and decoded.
3. Decoded samples are matched to bound sensor IDs.
4. Latest sample is persisted and status is recalculated.
5. UI refreshes affected cards and indicators.

Status classification considers:

- Pressure bounds.
- Maximum temperature.
- Minimum battery threshold.
- Connectivity / data availability.

## 6. User Flows

### Bind a sensor

1. Open vehicle screen (CV, BIKE, or PV/SCV).
2. Tap a wheel sensor button.
3. Scan and select a device.
4. Sensor is bound to that wheel label.

### Monitor and unbind

1. Open Sensor Dashboard.
2. Inspect card status and values.
3. Use card-level `Unbind` action to disconnect a wheel mapping.

### Spare-tire operation

1. Register spare in Spare Tire Management.
2. On vehicle screen, tap `Swap with Spare`.
3. Select target wheel in the bottom sheet.
4. App performs swap and updates statuses.

## 7. Setup and Run

Requirements:

- Flutter SDK (stable): https://flutter.dev/docs/get-started/install
- Android Studio / Android SDK for Android builds
- Xcode for iOS builds (macOS only)

Install dependencies:

```bash
flutter pub get
```

Run on a connected device:

```bash
flutter run
```

Optional static checks:

```bash
flutter analyze
flutter test
```

## 8. Build and Release

Android:

```bash
flutter build apk --debug
flutter build apk --release
```

iOS (macOS only):

```bash
flutter build ios --release
```

Clean build cycle when needed:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## 9. Permissions and Platform Notes

BLE behavior depends on platform permissions and runtime settings.

Checklist:

- Bluetooth is enabled on device.
- Required Bluetooth and location permissions are granted.
- Device vendor battery optimizations are not blocking BLE scans.
- Test on physical phone for realistic BLE behavior.

## 10. Troubleshooting

### Runtime errors after multiple hot reloads

- Fully stop and relaunch the app on device.
- Hot restart may not reset all widget and platform state.

### Swap with spare does not complete

- Ensure a spare sensor is registered.
- Ensure at least one eligible wheel is bound.
- Confirm wheel selection was made in bottom sheet (not cancelled).

### Sensor not showing live data

- Verify the sensor ID in bound mapping matches decoded payload.
- Check BLE permissions and device Bluetooth state.
- Refresh dashboard and reopen live screen.

### Binding conflicts

- If sensor already bound elsewhere, unbind first from dashboard or live screen.

## 11. Development Guide

Code style and implementation notes:

- Keep new UI work aligned with `AppTheme` tokens.
- Prefer module-specific screens over adding more legacy logic into `main.dart`.
- Add mounted checks around async UI updates to avoid stale-context issues.
- Validate with `flutter analyze` after editing critical flows.

Suggested improvement backlog:

- Consolidate duplicated legacy screens from `main.dart` into modular files.
- Add automated widget tests for swap and unbind flows.
- Add CI for analyze and test on pull requests.


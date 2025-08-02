// lib/services/ble_service.dart

// This file defines the BleService, a core component responsible for managing
// Bluetooth Low Energy (BLE) communication within the StrumSure application.
// It handles all aspects of interacting with an ESP32-based smart tuner,
// including scanning for devices, establishing and maintaining connections,
// sending commands, and receiving real-time tuning data.
// The service is designed to be platform-aware, gracefully handling differences
// in BLE functionality and permissions across Android, iOS, Windows, and Web platforms.

import 'dart:async'; // For asynchronous operations and stream management.
import 'dart:convert'; // For UTF-8 encoding/decoding of BLE characteristic values.
import 'package:flutter/material.dart'; // Provides ChangeNotifier for state management.
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // The primary plugin for BLE operations.
import 'package:permission_handler/permission_handler.dart'; // For requesting and checking system permissions (Bluetooth, Location).
import 'dart:io' show Platform; // Provides platform detection for native environments.
import 'package:flutter/foundation.dart' show kIsWeb; // Provides `kIsWeb` for web platform detection and `debugPrint` for logging.

/// A service class to manage all Bluetooth Low Energy (BLE) communication.
///
/// This class acts as a central hub for BLE operations, including:
/// - Scanning for nearby Bluetooth devices (specifically the ESP32 tuner).
/// - Connecting to and disconnecting from a selected device.
/// - Discovering BLE services and characteristics.
/// - Sending data (tuning commands) to the connected ESP32.
/// - Receiving real-time data (tuning feedback) from the ESP32.
/// - Managing Bluetooth adapter state and location service status across platforms.
///
/// It extends [ChangeNotifier] to allow UI components to react to changes
/// in BLE connection status, scan results, and received data.
class BleService extends ChangeNotifier {
  // --- BLE Service and Characteristic UUIDs ---
  // These UUIDs are critical for identifying the specific BLE service and
  // characteristics exposed by the ESP32 tuner. They MUST precisely match
  // the UUIDs defined in the ESP32's Arduino (or equivalent) firmware.
  static final Guid serviceUuid = Guid("a0c1d2e3-4f5a-6b7c-8d9e-0f1a2b3c4d5e"); // The main service UUID for the ESP32 tuner.
  static final Guid characteristicUuidTxFromEsp32 = Guid("e5d4c3b2-a1f0-9e8d-7c6b-5a4f3e2d1c0b"); // Characteristic for receiving data FROM the ESP32 (TX from ESP32 perspective).
  static final Guid characteristicUuidRxToEsp32 = Guid("1a2b3c4d-5e6f-7a8b-9c0d-e1f2a3b4c5d6"); // Characteristic for sending data TO the ESP32 (RX from ESP32 perspective).

  // --- BLE State Variables ---
  // These private variables hold the current state of BLE operations and are
  // exposed publicly via getters to allow UI components to react to changes.
  final List<BluetoothDevice> _availableDevices = []; // A list of Bluetooth devices discovered during a scan. Marked as final as the list instance itself doesn't change, only its contents.
  BluetoothDevice? _connectedDevice; // The currently connected Bluetooth device (ESP32 tuner). Null if no device is connected.
  BluetoothCharacteristic? _rxCharacteristic; // The characteristic used for receiving data notifications from the ESP32.
  BluetoothCharacteristic? _txCharacteristic; // The characteristic used for writing commands to the ESP32.
  String _receivedBleData = 'No data yet'; // The most recent data string received from the ESP32.
  bool _isScanning = false; // Flag indicating whether a BLE scan is currently active.
  bool _isConnected = false; // Flag indicating whether the app is currently connected to an ESP32 device.
  String _connectionStatusMessage = 'Disconnected'; // A user-friendly message describing the current BLE connection status.

  // --- Platform-Specific State Variables ---
  BluetoothAdapterState _bluetoothAdapterState = BluetoothAdapterState.unknown; // The current state of the device's Bluetooth adapter (e.g., on, off, unauthorized).
  bool _isLocationServiceEnabled = false; // Flag indicating if location services are enabled (critical for BLE scanning on Android).

  // --- Stream Subscriptions for BLE Events ---
  // These subscriptions listen to various BLE events and are managed to prevent memory leaks.
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription; // Subscription for new scan results during a BLE scan.
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription; // Subscription for changes in the connected device's connection state.
  StreamSubscription<List<int>>? _characteristicValueSubscription; // Subscription for notifications from the RX characteristic (data from ESP32).
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription; // Subscription for changes in the device's Bluetooth adapter state.

  // --- Public Getters for UI Consumption ---
  // These getters provide read-only access to the internal state variables,
  // allowing Flutter widgets to rebuild when these values change (via notifyListeners()).
  List<BluetoothDevice> get availableDevices => _availableDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String get receivedBleData => _receivedBleData;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String get connectionStatusMessage => _connectionStatusMessage;
  BluetoothAdapterState get bluetoothAdapterState => _bluetoothAdapterState;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  /// Constructor for [BleService].
  ///
  /// Initializes the service by setting up listeners for FlutterBluePlus events
  /// and immediately requesting necessary permissions. This ensures the service
  /// is ready to perform BLE operations as soon as it's instantiated.
  BleService() {
    // Listen to FlutterBluePlus's internal scanning state to keep `_isScanning` updated.
    FlutterBluePlus.isScanning.listen((isScanning) {
      _isScanning = isScanning;
      notifyListeners(); // Notify widgets that the scanning state has changed.
      debugPrint('BLE Scan State: $_isScanning'); // Log for debugging.
    });

    // Listen to changes in the device's Bluetooth adapter state.
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) async {
      _bluetoothAdapterState = state;
      debugPrint('Bluetooth Adapter State: $state'); // Log the current adapter state.
      // Immediately check location service status as it's often tied to adapter state (especially on Android).
      await _checkLocationServiceStatus();
      _updateConnectionStatusMessage(); // Update the user-facing status message based on new states.
      notifyListeners(); // Notify widgets of state changes.
    });

    // Request necessary permissions as soon as the service is created.
    _requestPermissions();
  }

  /// Updates the user-facing connection status message.
  ///
  /// This method consolidates various BLE states (connected, scanning, Bluetooth on/off,
  /// location services) into a single, descriptive string that can be displayed in the UI.
  void _updateConnectionStatusMessage() {
    // Determine if platform-specific checks for Bluetooth adapter and location services
    // should be bypassed (e.g., for Web or Windows where these checks might behave differently).
    final bool bypassPlatformChecks = kIsWeb || Platform.isWindows;

    if (_isConnected) {
      // Display connected device name if available, otherwise "Unknown Device".
      _connectionStatusMessage = 'Connected to ${_connectedDevice!.platformName.isEmpty ? "Unknown Device" : _connectedDevice!.platformName}';
    } else if (!bypassPlatformChecks && _bluetoothAdapterState != BluetoothAdapterState.on) {
      // If not bypassing checks and Bluetooth is off, show a specific message.
      _connectionStatusMessage = 'Bluetooth is OFF. Please turn it ON.';
    } else if (!bypassPlatformChecks && !_isLocationServiceEnabled) {
      // If not bypassing checks and location services are off, show a specific message (primarily for Android).
      _connectionStatusMessage = 'Location Services are OFF. Please enable for scanning.';
    } else if (_isScanning) {
      // If scanning is active, indicate that.
      _connectionStatusMessage = 'Scanning for devices...';
    } else if (_availableDevices.isEmpty) {
      // If no devices are found after a scan, prompt the user.
      _connectionStatusMessage = 'No devices found. Ensure ESP32 is ON and advertising.';
    } else {
      // Default disconnected state.
      _connectionStatusMessage = 'Disconnected. Ready to scan.';
    }
  }

  /// Checks if location services are enabled on the device.
  ///
  /// Location services are strictly required for BLE scanning on Android
  /// due to Google's security policies. On iOS and other platforms, this
  /// requirement is typically less stringent or not applicable.
  ///
  /// Returns a [Future<void>] that completes after the check is performed.
  Future<void> _checkLocationServiceStatus() async {
    // For web and Windows platforms, location services are generally not a direct
    // requirement for BLE operations, so we assume they are enabled to bypass checks.
    if (kIsWeb || Platform.isWindows) {
      _isLocationServiceEnabled = true;
      debugPrint('Location Service Enabled: Assumed true for Web/Windows.');
    } else if (Platform.isAndroid) {
      // On Android, explicitly check if location services are enabled.
      _isLocationServiceEnabled = await Permission.locationWhenInUse.serviceStatus.isEnabled;
      debugPrint('Location Service Enabled: $_isLocationServiceEnabled');
    } else {
      // For iOS and other platforms, assume location services are enabled or not critical.
      _isLocationServiceEnabled = true;
    }
    notifyListeners(); // Notify listeners of the updated status.
  }

  /// Requests necessary Bluetooth and Location permissions for BLE operations.
  ///
  /// This method requests `bluetoothScan`, `bluetoothConnect`, and `locationWhenInUse`
  /// permissions. It's crucial for the app to function correctly on Android and iOS.
  /// On web and Windows, explicit permission requests are often handled by the OS
  /// or browser directly, so this step is bypassed.
  ///
  /// Returns a [Future<void>] that completes after permissions are requested.
  Future<void> _requestPermissions() async {
    debugPrint('Requesting BLE permissions...');
    // Skip explicit permission requests for web and Windows platforms,
    // as `permission_handler` might not have implementations for them.
    if (kIsWeb || Platform.isWindows) {
      debugPrint('Skipping explicit permission requests for Web/Windows.');
      _connectionStatusMessage = 'Permissions assumed for Web/Windows. Ready to scan.';
      notifyListeners();
      return;
    }

    // Request permissions for Bluetooth scanning, connecting, and location access.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Required for BLE scanning on Android.
    ].request();

    // After requesting permissions, immediately check the location service status.
    await _checkLocationServiceStatus();

    // Update connection status message based on permission outcomes.
    if (statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
        statuses[Permission.bluetoothConnect] != PermissionStatus.granted ||
        statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
      _connectionStatusMessage = 'Permissions denied. Cannot scan/connect.';
      debugPrint('BLE permissions denied.');
    } else {
      _connectionStatusMessage = 'Permissions granted. Ready to scan.';
      debugPrint('BLE permissions granted.');
    }
    _updateConnectionStatusMessage(); // Final update based on all permission and service states.
    notifyListeners();
  }

  /// Starts scanning for nearby Bluetooth Low Energy (BLE) devices.
  ///
  /// This method initiates a scan, filtering for devices that advertise the
  /// specific `serviceUuid` of the ESP32 tuner. It performs pre-checks for
  /// Bluetooth adapter state, location services, and permissions before starting.
  ///
  /// Returns a [Future<void>] that completes when the scan is initiated.
  Future<void> startScan() async {
    debugPrint('startScan() called.');
    if (_isScanning) {
      debugPrint('Already scanning, aborting new scan request.');
      return;
    }
    if (_isConnected) {
      debugPrint('Already connected, aborting scan request.');
      return;
    }

    // Determine if platform-specific pre-checks should be bypassed (e.g., for Web or Windows).
    final bool bypassPlatformChecks = kIsWeb || Platform.isWindows;

    // Perform pre-checks for scanning, which are bypassed on web/Windows platforms.
    if (!bypassPlatformChecks && _bluetoothAdapterState != BluetoothAdapterState.on) {
      _updateConnectionStatusMessage(); // Update message (already set by adapterState listener).
      debugPrint('Bluetooth is off, cannot start scan.');
      return;
    }
    if (!bypassPlatformChecks && !_isLocationServiceEnabled) {
      _updateConnectionStatusMessage(); // Update message (already set by location service check).
      debugPrint('Location services off, cannot start scan.');
      return;
    }
    // Re-check permissions just before scanning (only on non-web/Windows platforms).
    if (!bypassPlatformChecks) {
      final scanPermissionStatus = await Permission.bluetoothScan.status;
      final connectPermissionStatus = await Permission.bluetoothConnect.status;
      final locationPermissionStatus = await Permission.locationWhenInUse.status;

      if (scanPermissionStatus != PermissionStatus.granted ||
          connectPermissionStatus != PermissionStatus.granted ||
          locationPermissionStatus != PermissionStatus.granted) {
        _connectionStatusMessage = 'Missing required permissions. Please grant them.';
        debugPrint('Missing permissions, cannot start scan.');
        notifyListeners();
        return;
      }
    }

    // Clear any previous scan results to ensure a fresh list of devices.
    _availableDevices.clear();
    _connectionStatusMessage = 'Scanning for devices...';
    _isScanning = true;
    notifyListeners();
    debugPrint('Starting BLE scan...');

    // Cancel any existing scan results subscription to prevent duplicate listeners.
    _scanResultsSubscription?.cancel();

    // Listen to the stream of scan results from FlutterBluePlus.
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Add newly discovered devices to the list if they are not already present.
        if (!_availableDevices.contains(r.device)) {
          _availableDevices.add(r.device);
          debugPrint('Found device: ${r.device.platformName.isEmpty ? "Unknown Device" : r.device.platformName} (${r.device.remoteId})');
          notifyListeners(); // Notify UI to update the list of available devices.
        }
      }
    }, onError: (e) {
      debugPrint('Scan Results Stream Error: $e'); // Log any errors occurring during the scan.
      _connectionStatusMessage = 'Scan Error: $e';
      notifyListeners();
    });

    // Start the actual BLE scan with a timeout and a hint for the target service UUID.
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10), // Scan for 10 seconds.
        withServices: [serviceUuid], // Suggests to the OS to look for devices advertising this service.
      );
      debugPrint('Scan initiated. Will stop after 10 seconds.');
    } catch (e) {
      debugPrint('Error initiating scan: $e'); // Catch errors that prevent the scan from starting.
      _connectionStatusMessage = 'Scan initiation failed: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stops any ongoing BLE scan.
  ///
  /// Returns a [Future<void>] that completes when the scan is stopped.
  Future<void> stopScan() async {
    debugPrint('stopScan() called.');
    if (!_isScanning) return; // Do nothing if no scan is active.
    try {
      await FlutterBluePlus.stopScan();
      debugPrint('FlutterBluePlus.stopScan() successful.');
    } catch (e) {
      debugPrint('Error stopping scan: $e'); // Log any errors during scan cessation.
    } finally {
      // Ensure all scan-related resources are cleaned up regardless of success or failure.
      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
      _isScanning = false;
      _updateConnectionStatusMessage(); // Update the connection status message.
      notifyListeners();
    }
  }

  /// Connects to a specific [BluetoothDevice].
  ///
  /// This method attempts to establish a connection with the provided device,
  /// discovers its services and characteristics, and sets up listeners for
  /// incoming data.
  ///
  /// Parameters:
  /// - [device]: The [BluetoothDevice] object to connect to.
  ///
  /// Returns a [Future<void>] that completes when the connection is established
  /// or an error occurs.
  Future<void> connectToDevice(BluetoothDevice device) async {
    debugPrint('connectToDevice() called for ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}');
    if (_isConnected) {
      debugPrint('Already connected to a device, aborting new connection.');
      return;
    }
    await stopScan(); // Always stop any ongoing scan before attempting to connect.

    _connectionStatusMessage = 'Connecting to ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}...';
    notifyListeners();
    debugPrint('Attempting to connect to ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}...');

    try {
      // Attempt to connect to the device with a timeout.
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      _isConnected = true;
      _updateConnectionStatusMessage(); // Update status message upon successful connection.
      debugPrint('Successfully connected to ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}');
      notifyListeners();

      // Discover all services and characteristics offered by the connected device.
      List<BluetoothService> services = await device.discoverServices();
      bool serviceFound = false;
      for (var service in services) {
        debugPrint('Discovered Service: ${service.serviceUuid}');
        // Check if the discovered service matches our target ESP32 service UUID.
        if (service.serviceUuid == serviceUuid) {
          serviceFound = true;
          debugPrint('Found target Service: ${service.serviceUuid}');
          // Iterate through characteristics within the target service.
          for (var characteristic in service.characteristics) {
            debugPrint('  Characteristic: ${characteristic.characteristicUuid}');
            // Identify the TX characteristic (ESP32 -> Flutter).
            if (characteristic.characteristicUuid == characteristicUuidTxFromEsp32) {
              _rxCharacteristic = characteristic;
              debugPrint('  Found RX Characteristic (ESP32 -> Flutter)');
              // Enable notifications on the RX characteristic to receive real-time data.
              await _rxCharacteristic!.setNotifyValue(true);
              // Subscribe to the stream of values from the RX characteristic.
              _characteristicValueSubscription = _rxCharacteristic!.lastValueStream.listen((value) {
                _receivedBleData = utf8.decode(value); // Decode received bytes to a UTF-8 string.
                debugPrint('Received from ESP32: $_receivedBleData');
                notifyListeners(); // Notify UI to update with the new received data.
              });
            } else if (characteristic.characteristicUuid == characteristicUuidRxToEsp32) {
              // Identify the RX characteristic (Flutter -> ESP32).
              _txCharacteristic = characteristic;
              debugPrint('  Found TX Characteristic (Flutter -> ESP32)');
            }
          }
        }
      }
      // Throw an exception if the required service or characteristics are not found.
      if (!serviceFound) {
        throw Exception('Target service ($serviceUuid) not found on device.');
      }
      if (_rxCharacteristic == null || _txCharacteristic == null) {
        throw Exception('Required characteristics not found on device.');
      }

      // Listen for device disconnection events to handle unexpected disconnections.
      _deviceStateSubscription = device.connectionState.listen((BluetoothConnectionState state) {
        debugPrint('Device ${device.platformName.isEmpty ? "Unknown Device" : device.platformName} connection state changed to: $state');
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected: ${device.platformName.isEmpty ? "Unknown Device" : device.platformName}');
          _resetConnectionState(); // Reset BLE state upon disconnection.
          startScan(); // Automatically restart scan after disconnection to find devices again.
        }
      }, onError: (e) {
        debugPrint('Device State Stream Error: $e'); // Log errors in the connection state stream.
      });

    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _connectionStatusMessage = 'Connection failed: $e';
      _resetConnectionState(); // Reset state if connection fails.
      notifyListeners();
      startScan(); // Restart scan if connection fails to allow retrying.
    }
  }

  /// Disconnects from the currently connected Bluetooth device.
  ///
  /// Returns a [Future<void>] that completes when the disconnection process is finished.
  Future<void> disconnectDevice() async {
    debugPrint('disconnectDevice() called.');
    if (!_isConnected || _connectedDevice == null) {
      debugPrint('Not connected to any device.');
      return;
    }
    try {
      await _connectedDevice!.disconnect(); // Initiate the disconnection.
      debugPrint('Disconnected from ${_connectedDevice!.platformName.isEmpty ? "Unknown Device" : _connectedDevice!.platformName}');
      // The state reset is handled by the `_deviceStateSubscription` listener when it detects `disconnected` state.
    } catch (e) {
      debugPrint('Error disconnecting: $e');
      _connectionStatusMessage = 'Error disconnecting: $e';
      notifyListeners();
    }
  }

  /// Resets all connection-related state variables to their initial disconnected state.
  /// This method is called upon disconnection or connection failure to clean up resources.
  void _resetConnectionState() {
    debugPrint('_resetConnectionState() called.');
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _isConnected = false;
    _receivedBleData = 'Disconnected'; // Reset received data display.
    // Cancel all active subscriptions to prevent memory leaks.
    _characteristicValueSubscription?.cancel();
    _characteristicValueSubscription = null;
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    _updateConnectionStatusMessage(); // Update the status message to reflect the disconnected state.
    notifyListeners();
  }

  /// Sends a string message to the connected ESP32 device via its TX characteristic.
  ///
  /// Parameters:
  /// - [message]: The string message to be sent.
  ///
  /// Returns a [Future<void>] that completes when the data is sent or an error occurs.
  Future<void> sendData(String message) async {
    debugPrint('sendData() called with message: "$message"');
    if (_txCharacteristic == null || !_isConnected) {
      debugPrint('Cannot send data: TX characteristic not available or not connected.');
      _connectionStatusMessage = 'Error: Not connected or TX characteristic missing.';
      notifyListeners();
      return;
    }

    final List<int> bytes = utf8.encode(message); // Encode the string message into UTF-8 bytes.

    try {
      // Attempt to write the data to the characteristic, requesting a response.
      await _txCharacteristic!.write(bytes, withoutResponse: false);
      debugPrint('Sent to ESP32: "$message"');
    } catch (e) {
      debugPrint('Error sending data: $e. Attempting without response...');
      try {
        // If writing with response fails, attempt to write without expecting a response.
        await _txCharacteristic!.write(bytes, withoutResponse: true);
        debugPrint('Sent to ESP32 (without response): "$message"');
      } catch (e2) {
        debugPrint('Failed to send data (even without response): $e2');
        _connectionStatusMessage = 'Failed to send data: $e2';
        notifyListeners();
      }
    }
  }

  @override
  /// Disposes of all active stream subscriptions and resources held by the service.
  /// This method is crucial for preventing memory leaks when the service is no longer needed.
  void dispose() {
    debugPrint('BleService disposed.');
    _scanResultsSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _characteristicValueSubscription?.cancel();
    _adapterStateSubscription?.cancel(); // Cancel the Bluetooth adapter state subscription.
    _connectedDevice?.disconnect(); // Attempt to cleanly disconnect from any connected device.
    super.dispose();
  }
}

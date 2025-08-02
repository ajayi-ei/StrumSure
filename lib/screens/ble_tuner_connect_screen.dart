// lib/screens/ble_tuner_connect_screen.dart

// This file defines the BleTunerConnectScreen, a dedicated user interface
// within the StrumSure application for managing Bluetooth Low Energy (BLE)
// connections with an external ESP32-based smart tuner. It allows users to
// scan for devices, connect, disconnect, and view real-time communication status.

import 'package:flutter/material.dart'; // Core Flutter UI components and Material Design.
import 'package:provider/provider.dart'; // For state management using Provider.
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Imports types like BluetoothDevice, BluetoothAdapterState.
import 'package:strum_sure/services/ble_service.dart'; // Imports the custom BLE service for logic.
import 'package:permission_handler/permission_handler.dart'; // For opening app settings (e.g., for Bluetooth/Location permissions).
import 'dart:io' show Platform; // Provides platform detection (e.g., Android, iOS, Windows).
import 'package:flutter/foundation.dart' show kIsWeb; // Provides `kIsWeb` for web platform detection.

/// A screen dedicated to managing the Bluetooth Low Energy (BLE) connection
/// with an ESP32 smart tuner.
///
/// This screen provides the UI and logic for:
/// - Initiating and stopping BLE device scans.
/// - Displaying a list of available Bluetooth devices.
/// - Connecting to and disconnecting from a selected ESP32 tuner.
/// - Showing the current BLE connection status and received data.
/// - Providing reminders and actions for common BLE issues (e.g., Bluetooth off, location services off).
class BleTunerConnectScreen extends StatefulWidget {
  /// Constructs a [BleTunerConnectScreen] widget.
  const BleTunerConnectScreen({super.key});

  @override
  State<BleTunerConnectScreen> createState() => _BleTunerConnectScreenState();
}

/// The state class for [BleTunerConnectScreen].
///
/// It manages the screen's lifecycle, triggers initial BLE scans,
/// and builds the UI based on the state provided by [BleService].
class _BleTunerConnectScreenState extends State<BleTunerConnectScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule a callback to run after the first frame is rendered.
    // This ensures the context is available and avoids issues with calling
    // `startScan` too early in the widget's lifecycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Access the BleService without listening (`listen: false`) as we only
      // need to trigger an action, not rebuild based on its initial state.
      // The BleService's constructor already handles initial permission requests
      // and adapter state listening, so `startScan` will proceed with necessary checks.
      Provider.of<BleService>(context, listen: false).startScan();
    });
  }

  @override
  void dispose() {
    // Optionally, you might choose to stop the scan when leaving this screen.
    // However, if you want the connection to persist across tabs, you might omit this.
    // Provider.of<BleService>(context, listen: false).stopScan();
    super.dispose();
  }

  /// Helper method to build a standardized reminder/warning card.
  ///
  /// This widget is used to inform the user about potential issues (e.g.,
  /// Bluetooth off, location services disabled) and provides an optional
  /// button to open device settings.
  ///
  /// Parameters:
  /// - `icon`: The [IconData] for the reminder icon.
  /// - `title`: The main title of the reminder (e.g., "Bluetooth is Off").
  /// - `message`: A detailed message explaining the issue.
  /// - `iconColor`: The color of the icon (defaults to orange).
  /// - `onPressed`: An optional callback for a button (e.g., to open settings).
  /// - `buttonText`: The text for the optional button.
  ///
  /// Returns:
  /// - A [Card] widget formatted as a reminder.
  Widget _buildReminderCard({
    required IconData icon,
    required String title,
    required String message,
    Color iconColor = Colors.orange, // Default functional color for warning.
    VoidCallback? onPressed,
    String? buttonText,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      // Themed error color with transparency for a warning background.
      color: colorScheme.error.withAlpha((255 * 0.4).round()),
      margin: const EdgeInsets.only(bottom: 16.0), // Spacing below the card.
      elevation: 4, // Subtle shadow.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners.
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align content to the left.
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28), // The reminder icon.
                const SizedBox(width: 10), // Spacing between icon and title.
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onError, // Text color contrasting with the error background.
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Vertical spacing.
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError.withAlpha((255 * 0.7).round())), // Muted text color.
            ),
            // Conditionally display a button if `onPressed` and `buttonText` are provided.
            if (onPressed != null && buttonText != null) ...[
              const SizedBox(height: 12), // Vertical spacing before the button.
              Align(
                alignment: Alignment.centerRight, // Align button to the right.
                child: ElevatedButton.icon(
                  // Button is disabled on web/Windows platforms as `openAppSettings`
                  // might not be applicable or behave differently.
                  onPressed: (kIsWeb || Platform.isWindows) ? null : onPressed,
                  icon: const Icon(Icons.settings), // Settings icon.
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, // Explicit red accent for settings button.
                    foregroundColor: colorScheme.onError, // Text color on red accent.
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the current theme's color scheme and text theme for consistent styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Use a Consumer to listen to changes in BleService state and rebuild the UI accordingly.
    return Consumer<BleService>(
      builder: (context, bleService, child) {
        // Determine if Bluetooth adapter state or location service checks
        // should be bypassed based on the current platform.
        final bool bypassPlatformChecks = kIsWeb || Platform.isWindows;

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0), // Padding around the screen content.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally.
              children: [
                // --- Scan and Disconnect Buttons ---
                Card(
                  color: colorScheme.surface, // Themed background color for the card.
                  margin: const EdgeInsets.only(bottom: 16.0), // Spacing below the card.
                  elevation: 4, // Subtle shadow.
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners.
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute space evenly between buttons.
                      children: [
                        // Scan Button
                        Column(
                          children: [
                            IconButton(
                              iconSize: 30.0,
                              icon: Icon(
                                // Icon changes based on scanning state.
                                bleService.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_audio,
                                // Color changes based on scanning state.
                                color: bleService.isScanning ? colorScheme.primary : colorScheme.onSurface,
                              ),
                              // Button is disabled if:
                              // - Already scanning.
                              // - Already connected.
                              // - (On native platforms) Bluetooth is off OR Location services are off.
                              onPressed: bleService.isScanning || bleService.isConnected ||
                                  (!bypassPlatformChecks && (bleService.bluetoothAdapterState != BluetoothAdapterState.on || !bleService.isLocationServiceEnabled))
                                  ? null
                                  : () => bleService.startScan(), // Triggers BLE scan.
                              tooltip: 'Scan for ESP32 Tuner', // Tooltip for accessibility.
                            ),
                            Text(
                              bleService.isScanning ? 'Scanning...' : 'Scan Devices', // Dynamic text label.
                              style: textTheme.labelMedium?.copyWith(
                                color: bleService.isScanning ? colorScheme.primary : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        // Disconnect Button (only visible if connected)
                        if (bleService.isConnected)
                          Column(
                            children: [
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.bluetooth_disabled), // Disconnect icon.
                                color: colorScheme.error, // Themed error color.
                                onPressed: () => bleService.disconnectDevice(), // Triggers BLE disconnect.
                                tooltip: 'Disconnect from ESP32',
                              ),
                              Text(
                                'Disconnect',
                                style: textTheme.labelMedium?.copyWith(color: colorScheme.error),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // --- Conditional Reminder Cards ---
                // These cards provide user guidance based on BLE service status.
                // They are conditionally displayed only on native platforms where these checks are relevant.
                if (!bypassPlatformChecks && bleService.bluetoothAdapterState != BluetoothAdapterState.on)
                  _buildReminderCard(
                    icon: Icons.bluetooth_disabled,
                    title: 'Bluetooth is Off',
                    message: 'Please turn on Bluetooth in your device settings to scan for ESP32 tuner.',
                    iconColor: colorScheme.error, // Themed error color.
                    onPressed: () async {
                      await openAppSettings(); // Opens app settings for the user.
                    },
                    buttonText: 'Open Settings',
                  )
                else if (!bypassPlatformChecks && !bleService.isLocationServiceEnabled)
                  _buildReminderCard(
                    icon: Icons.location_off,
                    title: 'Location Services Off',
                    message: 'Location services must be enabled for Bluetooth scanning on Android.',
                    iconColor: colorScheme.error, // Themed error color.
                    onPressed: () async {
                      await openAppSettings();
                    },
                    buttonText: 'Open Settings',
                  )
                else if (!bleService.isScanning && bleService.availableDevices.isEmpty && !bleService.isConnected)
                  // Show this reminder if not scanning, no devices found, and not connected.
                    _buildReminderCard(
                      icon: Icons.lightbulb_outline,
                      title: 'No Devices Found',
                      message: 'Ensure your ESP32 Tuner is powered on and actively advertising. Tap the scan button to retry.',
                      iconColor: Colors.yellow, // Functional yellow for a tip.
                    ),

                // --- Connection Status Display ---
                Card(
                  color: colorScheme.surface, // Themed background color.
                  margin: const EdgeInsets.only(bottom: 16.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status:',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface.withAlpha((255 * 0.7).round()), // Muted text color.
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bleService.connectionStatusMessage, // Displays the current connection status message.
                          style: textTheme.titleLarge?.copyWith(
                            // Dynamic color based on connection state.
                            color: bleService.isConnected ? Colors.greenAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Display connected device details if a device is connected.
                        if (bleService.connectedDevice != null)
                          Text(
                            'Device: ${bleService.connectedDevice!.platformName.isEmpty ? "Unknown Device" : bleService.connectedDevice!.platformName} (${bleService.connectedDevice!.remoteId})',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.5).round())), // Muted text color.
                          ),
                      ],
                    ),
                  ),
                ),

                // --- Received Data Display (Tuning Commands) ---
                Card(
                  color: colorScheme.surface, // Themed background color.
                  margin: const EdgeInsets.only(bottom: 16.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tuning Command from ESP32:',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface.withAlpha((255 * 0.7).round()), // Muted text color.
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bleService.receivedBleData, // Displays the latest data received from ESP32.
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary, // Themed primary color for received data.
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Device List / Scanning Indicator ---
                // This section dynamically displays either a scanning indicator,
                // a "no devices found" message, or the list of available devices.
                Expanded(
                  child: bleService.isScanning
                      ? Center(
                    // Display a circular progress indicator and scanning message.
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary), // Themed primary color.
                        const SizedBox(height: 16),
                        Text(
                          'Scanning for Bluetooth devices...',
                          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())), // Muted text color.
                        ),
                      ],
                    ),
                  )
                      : bleService.availableDevices.isEmpty && !bleService.isConnected && (bypassPlatformChecks || (bleService.bluetoothAdapterState == BluetoothAdapterState.on && bleService.isLocationServiceEnabled))
                      ? Center(
                    // Display a "no devices found" message.
                    child: Text(
                      'No Bluetooth devices found. Ensure Bluetooth is ON and devices are advertising.',
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.5).round())), // Muted text color.
                      textAlign: TextAlign.center,
                    ),
                  )
                      : ListView.builder(
                    // Display the list of available devices.
                    itemCount: bleService.availableDevices.length,
                    itemBuilder: (context, index) {
                      final device = bleService.availableDevices[index];
                      return Card(
                        color: colorScheme.surfaceContainerHighest, // Themed background for list items.
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(
                            device.platformName.isEmpty ? 'Unknown Device' : device.platformName, // Display device name.
                            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            device.remoteId.toString(), // Display device ID.
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())),
                          ),
                          trailing: ElevatedButton(
                            // Connect button is disabled if already connected.
                            onPressed: bleService.isConnected
                                ? null
                                : () => bleService.connectToDevice(device), // Triggers device connection.
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary, // Themed primary color.
                              foregroundColor: colorScheme.onPrimary, // Text color on primary.
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Connect', style: textTheme.labelLarge),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// lib/screens/tuner_screen.dart

// This file defines the TunerScreen, the primary user interface for the
// StrumSure application's guitar tuning functionality. It integrates
// various widgets to display real-time tuning feedback, a frequency graph,
// and controls for selecting strings and managing the tuning process.

import 'package:flutter/material.dart'; // Core Flutter UI components and Material Design.
import 'package:provider/provider.dart'; // For state management using Provider.
import 'dart:math' as math; // For mathematical operations like `math.max`.

// Import custom components and state notifier.
import 'package:strum_sure/state/tuner_data_notifier.dart'; // Manages tuning-related state.
import 'package:strum_sure/widgets/circular_tuner.dart'; // Visual circular tuner gauge.
import 'package:strum_sure/widgets/frequency_graph.dart'; // Real-time frequency visualization.
import 'package:strum_sure/widgets/guitar_string_selector.dart'; // Widget for selecting guitar strings.

/// The main screen for the guitar tuner application.
///
/// This screen is responsible for displaying all the interactive elements
/// and real-time data related to guitar tuning, including the visual tuner,
/// a frequency graph, string selection, and start/stop controls.
class TunerScreen extends StatefulWidget {
  /// Constructs a [TunerScreen] widget.
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

/// The state class for [TunerScreen].
///
/// It manages the screen's internal state, handles app lifecycle changes
/// to control tuning, and orchestrates the interaction with [TunerDataNotifier].
class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
  bool _isStartingTuning = false; // Flag to indicate if tuning is in the process of starting.
  bool _isStoppingTuning = false; // Flag to indicate if tuning is in the process of stopping.

  @override
  void initState() {
    super.initState();
    // Add this widget as an observer for app lifecycle changes.
    // This allows the app to react when it goes to the background or foreground.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove the observer when the widget is disposed to prevent memory leaks.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Handles changes in the application's lifecycle state.
  ///
  /// This method is crucial for managing audio resources. When the app
  /// goes into the background (paused, inactive, detached, hidden),
  /// the real-time tuning process is automatically stopped to conserve
  /// battery and release microphone resources.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Access TunerDataNotifier without listening to avoid unnecessary rebuilds.
    final tunerData = Provider.of<TunerDataNotifier>(context, listen: false);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden: // Handle hidden state for newer Flutter versions.
      // Stop tuning when the app goes into the background or is detached.
        if (tunerData.isTuningActive) {
          tunerData.stopTuning();
        }
        break;
      case AppLifecycleState.resumed:
      // When the app resumes, the user can manually restart tuning if desired.
        break;
    }
  }

  /// Handles the asynchronous process of starting the tuning.
  ///
  /// This method sets a loading state, calls `tunerData.startTuning()`,
  /// and displays a SnackBar if an error occurs during the process.
  ///
  /// Parameters:
  /// - `tunerData`: The [TunerDataNotifier] instance to interact with.
  Future<void> _handleStartTuning(TunerDataNotifier tunerData) async {
    // Prevent starting if already in the process of starting or already active.
    if (_isStartingTuning || tunerData.isTuningActive) return;

    setState(() {
      _isStartingTuning = true; // Set loading state for the start button.
    });

    try {
      await tunerData.startTuning(); // Attempt to start the tuning process.
    } catch (e) {
      // If an error occurs, show a SnackBar with the error message.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start tuning: ${e.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.onError), // Text color for error message.
            ),
            backgroundColor: Theme.of(context).colorScheme.error, // Background color for error SnackBar.
          ),
        );
      }
    } finally {
      // Ensure the loading state is reset regardless of success or failure.
      if (mounted) {
        setState(() {
          _isStartingTuning = false;
        });
      }
    }
  }

  /// Handles the asynchronous process of stopping the tuning.
  ///
  /// This method sets a loading state, calls `tunerData.stopTuning()`,
  /// and displays a SnackBar if an error occurs during the process.
  ///
  /// Parameters:
  /// - `tunerData`: The [TunerDataNotifier] instance to interact with.
  Future<void> _handleStopTuning(TunerDataNotifier tunerData) async {
    // Prevent stopping if already in the process of stopping or not active.
    if (_isStoppingTuning || !tunerData.isTuningActive) return;

    setState(() {
      _isStoppingTuning = true; // Set loading state for the stop button.
    });

    try {
      await tunerData.stopTuning(); // Attempt to stop the tuning process.
    } catch (e) {
      // If an error occurs, show a SnackBar with the error message.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to stop tuning: ${e.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.onError), // Text color for error message.
            ),
            backgroundColor: Theme.of(context).colorScheme.error, // Background color for error SnackBar.
          ),
        );
      }
    } finally {
      // Ensure the loading state is reset regardless of success or failure.
      if (mounted) {
        setState(() {
          _isStoppingTuning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the current theme's color scheme and text theme for consistent styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Calculate available screen height for responsive layout.
    final double screenHeight = MediaQuery.of(context).size.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top; // Height of the status bar.
    final double bottomPadding = MediaQuery.of(context).padding.bottom; // Height of the system navigation bar/safe area.
    const double fixedButtonsHeight = 60.0; // Fixed height allocated for the start/stop buttons.

    // Calculate the height available for the scrollable content area.
    // The AppBar is handled globally in MainAppWrapper, so its height is not subtracted here.
    final double availableHeight = screenHeight - statusBarHeight - bottomPadding - fixedButtonsHeight;

    return Scaffold(
      // The AppBar is now managed by the parent `MainAppWrapper` for global navigation.
      // appBar: AppBar(
      //   title: Text(
      //     'Guitar Tuner',
      //     style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
      //   ),
      //   backgroundColor: colorScheme.primary,
      //   elevation: 0,
      //   systemOverlayStyle: SystemUiOverlayStyle.dark,
      // ),
      body: Column(
        children: [
          // Expanded widget ensures the scrollable content takes up all available vertical space.
          Expanded(
            child: Consumer<TunerDataNotifier>(
              // Consumer rebuilds its child whenever TunerDataNotifier changes.
              builder: (context, tunerData, child) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(), // Provides a pleasant scroll effect.
                  child: Column(
                    children: [
                      // --- Automatic Tuning Toggle ---
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), // Reduced vertical margin.
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.surface, // Themed background color.
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline), // Themed border color.
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Automatic Tuning',
                              style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface), // Themed text color.
                            ),
                            Switch(
                              value: tunerData.isAutoTuningMode, // Current state of the auto-tuning mode.
                              onChanged: (newValue) {
                                // Toggles the auto-tuning mode in the notifier.
                                tunerData.toggleAutoTuningMode(newValue);
                              },
                              // Switch colors are managed by the app's `ThemeData.switchTheme`.
                            ),
                          ],
                        ),
                      ),

                      // --- Guitar String Selector ---
                      // This widget allows manual selection of the target string.
                      // It is conditionally disabled (visually and interactively)
                      // when automatic tuning mode is active.
                      AbsorbPointer( // Prevents user interaction with its child when `absorbing` is true.
                        absorbing: tunerData.isAutoTuningMode, // Disable if auto-tuning is on.
                        child: Opacity( // Reduces opacity to visually indicate disabled state.
                          opacity: tunerData.isAutoTuningMode ? 0.5 : 1.0,
                          child: GuitarStringSelector(
                            selectedNote: tunerData.targetNoteName, // Passes the current target note.
                            onNoteSelected: tunerData.setTargetNote, // Callback for string selection.
                          ),
                        ),
                      ),

                      // --- Target Note Display ---
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Reduced vertical margin.
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: colorScheme.surface, // Themed background color.
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline), // Themed border color.
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Target: ',
                              style: textTheme.bodyMedium?.copyWith(
                                color: textTheme.bodyMedium?.color?.withAlpha((255 * 0.7).round()), // Muted text color.
                              ),
                            ),
                            Text(
                              tunerData.targetNoteName, // Displays the name of the target note.
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface, // Themed text color.
                              ),
                            ),
                            Text(
                              ' (${tunerData.targetFrequency.toStringAsFixed(1)} Hz)', // Displays the target frequency.
                              style: textTheme.bodyMedium?.copyWith(
                                color: textTheme.bodyMedium?.color?.withAlpha((255 * 0.7).round()), // Muted text color.
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- Detected Note and Frequency Display ---
                      // This section is only visible when the tuner is actively listening.
                      if (tunerData.isTuningActive)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2), // Reduced vertical padding.
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown, // Ensures text fits within bounds.
                                child: Text(
                                  tunerData.detectedNoteName, // Displays the name of the detected note.
                                  style: textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface, // Themed text color.
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10), // Spacing between note and frequency.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  // Displays the detected frequency, formatted to one decimal place.
                                  tunerData.detectedFrequency != null && tunerData.detectedFrequency! > 0
                                      ? "${tunerData.detectedFrequency!.toStringAsFixed(1)} Hz"
                                      : "", // Empty string if no valid frequency.
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurface.withAlpha((255 * 0.7).round()), // Muted text color.
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // --- Circular Tuner Gauge ---
                      SizedBox(
                        // Constrains the height of the circular tuner for responsive layout.
                        height: math.max(250, availableHeight * 0.4), // Minimum 250px, up to 40% of available height.
                        child: Padding(
                          padding: const EdgeInsets.all(10), // Reduced padding around the tuner.
                          child: CircularTuner(
                            centsDeviation: tunerData.centsDeviation, // Passes cents deviation for visual feedback.
                            detectedNoteName: tunerData.detectedNoteName, // Passed, but not displayed by tuner.
                            detectedFrequency: tunerData.detectedFrequency ?? 0.0, // Passed, but not displayed by tuner.
                            isListening: tunerData.isTuningActive, // Controls dynamic elements visibility.
                          ),
                        ),
                      ),

                      // --- "Tap 'Start' to Tune" Message ---
                      // This message is only displayed when the tuner is not actively listening.
                      if (!tunerData.isTuningActive)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            "Tap 'Start' to Tune",
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface.withAlpha((255 * 0.5).round()), // Muted text color.
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // --- Frequency Graph ---
                      // Displays the historical frequency deviation data.
                      FrequencyGraph(
                        frequencyData: tunerData.frequencyGraphData, // Data points for the graph.
                        isListening: tunerData.isTuningActive, // Controls graph visibility/message.
                        maxGraphPoints: tunerData.maxGraphPoints, // Number of points to display.
                      ),

                      // Additional bottom padding to ensure content is scrollable above buttons.
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),

          // --- Control Buttons (Start/Stop Tuning) ---
          // These buttons are placed outside the scrollable area at the bottom.
          Consumer<TunerDataNotifier>(
            builder: (context, tunerData, child) {
              return Container(
                height: fixedButtonsHeight, // Fixed height for the button container.
                margin: const EdgeInsets.all(20), // Margin around the button row.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // --- Start Tuning Button ---
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ElevatedButton(
                          // Button is disabled if tuning is active or already starting.
                          onPressed: (tunerData.isTuningActive || _isStartingTuning)
                              ? null
                              : () => _handleStartTuning(tunerData),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary, // Themed primary color (Calm Teal).
                            disabledBackgroundColor: colorScheme.surfaceContainerHighest, // Themed disabled background.
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25), // Rounded button shape.
                            ),
                          ),
                          child: _isStartingTuning
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onError), // White progress indicator.
                            ),
                          )
                              : Text(
                            'Start Tuning',
                            style: textTheme.labelLarge?.copyWith(color: colorScheme.onError), // White text on colored button.
                          ),
                        ),
                      ),
                    ),

                    // --- Stop Tuning Button ---
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: ElevatedButton(
                          // Button is disabled if tuning is not active or already stopping.
                          onPressed: (!tunerData.isTuningActive || _isStoppingTuning)
                              ? null
                              : () => _handleStopTuning(tunerData),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF44336), // Alert Red from theme.
                            disabledBackgroundColor: colorScheme.surfaceContainerHighest, // Themed disabled background.
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25), // Rounded button shape.
                            ),
                          ),
                          child: _isStoppingTuning
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onError), // White progress indicator.
                            ),
                          )
                              : Text(
                            'Stop Tuning',
                            style: textTheme.labelLarge?.copyWith(color: colorScheme.onError), // White text on colored button.
                          ),
                        ),
                      ),
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

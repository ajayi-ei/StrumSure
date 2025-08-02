// lib/state/tuner_data_notifier.dart

// This file defines the TunerDataNotifier, a central state management class
// for the StrumSure application's guitar tuning and chord detection features.
// It integrates with the EnhancedPitchDetector for audio analysis, NoteUtils for
// musical calculations, and BleService for smart tuner communication.
// It manages the real-time state of the tuner, including detected frequencies,
// target notes, cents deviation, and the visual frequency graph data.

import 'dart:async'; // For managing timers and asynchronous operations.
import 'dart:collection'; // For using the Queue data structure for graph data.
import 'package:flutter/material.dart'; // Provides ChangeNotifier for state management.
import 'package:strum_sure/audio/enhanced_pitch_detector.dart'; // Imports the pitch detection logic.
import 'package:strum_sure/utils/note_utils.dart'; // Imports musical note utility functions.
import 'package:strum_sure/services/ble_service.dart'; // Imports the BLE service for smart tuner communication.

/// Represents a single data point to be displayed on the frequency graph.
/// Each point includes its cents deviation (if valid), a timestamp,
/// a color for visual feedback, and a flag indicating if it carries valid data.
class FrequencyPoint {
  /// The cents deviation from the target note. Null if no valid frequency was detected for this point.
  final double? centsDeviation;

  /// The timestamp when this data point was recorded, used for horizontal axis positioning on the graph.
  final DateTime timestamp;

  /// The color associated with this data point, typically indicating tuning accuracy (e.g., green for in-tune, red for off-tune).
  final Color color;

  /// A boolean flag indicating whether this [FrequencyPoint] contains valid frequency data.
  /// Set to `false` for "empty" points used to maintain graph continuity when no sound is detected.
  final bool hasValidData;

  /// Constructs a [FrequencyPoint] with detected cents deviation, timestamp, color,
  /// and an optional `hasValidData` flag (defaults to true).
  FrequencyPoint(this.centsDeviation, this.timestamp, this.color, {this.hasValidData = true});

  /// Factory constructor to create an "empty" [FrequencyPoint].
  /// This is used to add points to the graph when no valid frequency is detected,
  /// ensuring the graph continues to scroll smoothly even during silence or noise.
  /// It delegates to the main constructor, setting `centsDeviation` to `null`,
  /// `color` to a neutral grey, and `hasValidData` to `false`.
  FrequencyPoint.empty(DateTime timestamp)
      : this(null, timestamp, Colors.grey.shade600, hasValidData: false);
}

/// A [ChangeNotifier] that manages the real-time state and data for the guitar tuner.
///
/// This class orchestrates the interaction between the [EnhancedPitchDetector]
/// (for audio analysis), [NoteUtils] (for musical calculations), and [BleService]
/// (for smart tuner communication). It holds the current tuning status (detected note,
/// cents deviation), manages the target note, controls the tuning process lifecycle,
/// and prepares data for the frequency visualization graph.
class TunerDataNotifier extends ChangeNotifier {
  final EnhancedPitchDetector _pitchDetector;
  final NoteUtils _noteUtils = NoteUtils();
  final BleService _bleService; // Injected dependency for BLE communication.

  // --- Tuner State Variables ---
  bool _isTuningActive = false; // Indicates if the real-time tuning process is currently active.
  double? _detectedFrequency; // The most recently detected fundamental frequency from the microphone.
  String _detectedNoteName = 'N/A'; // The musical note name closest to the detected frequency (e.g., 'A4').
  double _centsDeviation = 0.0; // The deviation in cents from the target note's frequency.
  String _targetNoteName = 'E4'; // The currently selected or auto-detected target musical note.
  double _targetFrequency = noteFrequencies['E4']!; // The standard frequency of the `_targetNoteName`.

  /// Flag indicating whether the automatic tuning mode is active.
  /// In auto-tuning mode, the app attempts to identify the string being played
  /// and automatically sets it as the target note.
  bool _isAutoTuningMode = false;

  /// The maximum number of data points to retain in the frequency graph queue.
  /// Reduced to 20 points to optimize memory usage and rendering performance.
  final int _maxGraphPoints = 20;

  /// A queue holding [FrequencyPoint] objects for the real-time frequency graph.
  /// Using a queue ensures efficient addition of new points and removal of old ones.
  final Queue<FrequencyPoint> _frequencyGraphData = Queue<FrequencyPoint>();

  // --- UI Update Throttling and Graph Continuity Timers ---
  Timer? _uiUpdateTimer; // Timer to control the frequency of UI updates (throttling).
  bool _hasPendingUpdate = false; // Flag to indicate if a UI update is pending due to state change.
  static const int _uiUpdateIntervalMs = 100; // Limits UI updates to approximately 10 frames per second (100ms interval).

  Timer? _continuousGraphTimer; // Timer for continuously adding data points to the graph, even during silence.
  static const int _continuousGraphIntervalMs = 200; // Adds a new data point to the graph every 200ms.

  // --- Disposal Management ---
  bool _isDisposed = false; // Flag to track if the notifier has been disposed, preventing operations on a disposed object.

  // --- Public Getters ---
  int get maxGraphPoints => _maxGraphPoints;
  bool get isTuningActive => _isTuningActive;
  double? get detectedFrequency => _detectedFrequency;
  String get detectedNoteName => _detectedNoteName;
  double get centsDeviation => _centsDeviation;
  String get targetNoteName => _targetNoteName;
  double get targetFrequency => _targetFrequency;
  List<FrequencyPoint> get frequencyGraphData => _frequencyGraphData.toList(); // Converts the queue to a list for UI consumption.
  bool get isAutoTuningMode => _isAutoTuningMode;

  /// Constructs a [TunerDataNotifier] instance.
  ///
  /// Requires an instance of [BleService] to be injected, enabling communication
  /// with the smart tuner. It initializes the [EnhancedPitchDetector] and sets up
  /// the UI update throttling mechanism.
  TunerDataNotifier({required BleService bleService})
      : _pitchDetector = EnhancedPitchDetector(),
        _bleService = bleService // Initialize the injected BleService.
  {
    setTargetNote('E4'); // Sets the initial target note to E4 (common low E string).
    _pitchDetector.onFrequencyDetected = _onFrequencyDetected; // Registers the callback for pitch detection.

    _initializeUIUpdateThrottling(); // Starts the UI update throttling timer.
  }

  /// Initializes a periodic timer to throttle UI updates.
  ///
  /// This mechanism prevents excessive calls to `notifyListeners()`, which can
  /// lead to performance issues and unnecessary widget rebuilds, especially
  /// during rapid frequency changes. Updates are batched and sent at a fixed rate.
  void _initializeUIUpdateThrottling() {
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: _uiUpdateIntervalMs), (timer) {
      // If the notifier has been disposed, cancel the timer.
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      // If there's a pending update, notify listeners and reset the flag.
      if (_hasPendingUpdate) {
        _hasPendingUpdate = false;
        notifyListeners();
      }
    });
  }

  /// Starts a periodic timer to continuously add data points to the frequency graph.
  ///
  /// This ensures that the graph continuously scrolls and updates, providing
  /// visual continuity even when no valid frequency is being detected (e.g., during silence).
  void _startContinuousGraphUpdates() {
    _continuousGraphTimer?.cancel(); // Cancel any existing timer to avoid duplicates.

    _continuousGraphTimer = Timer.periodic(const Duration(milliseconds: _continuousGraphIntervalMs), (timer) {
      // If the notifier is disposed or tuning is not active, cancel the timer.
      if (_isDisposed || !_isTuningActive) {
        timer.cancel();
        return;
      }

      // Always add a data point to maintain graph continuity, regardless of frequency detection.
      _addContinuousGraphPoint();
    });
  }

  /// Adds a new data point to the `_frequencyGraphData` queue.
  ///
  /// If a valid frequency is currently detected, a [FrequencyPoint] with its
  /// calculated cents deviation and corresponding color (based on tuning accuracy)
  /// is added. Otherwise, an "empty" [FrequencyPoint] is added to maintain
  /// the graph's scrolling continuity during periods of no sound.
  void _addContinuousGraphPoint() {
    final now = DateTime.now(); // Get the current timestamp for the data point.

    if (_detectedFrequency != null && _detectedFrequency! > 0) {
      // If a valid frequency is detected, calculate cents deviation and determine color.
      final centsDeviation = _noteUtils.calculateCentsDeviation(_detectedFrequency!, _targetFrequency);

      Color lineColor;
      if (centsDeviation.abs() < 5) {
        lineColor = const Color(0xFF00A39A); // Calm Teal (in-tune)
      } else if (centsDeviation.abs() < 15) {
        lineColor = const Color(0xFFFFC107); // Amber (slightly off)
      } else {
        lineColor = const Color(0xFFF44336); // Red (far off)
      }

      _frequencyGraphData.add(FrequencyPoint(centsDeviation, now, lineColor, hasValidData: true));
    } else {
      // If no valid frequency, add an empty point to keep the graph scrolling.
      _frequencyGraphData.add(FrequencyPoint.empty(now));
    }

    // Maintain the queue size by removing the oldest data point if the maximum is exceeded.
    while (_frequencyGraphData.length > _maxGraphPoints) {
      _frequencyGraphData.removeFirst();
    }

    _hasPendingUpdate = true; // Flag that a UI update is pending.
  }

  /// Callback function invoked by the [EnhancedPitchDetector] when a stable frequency is detected.
  ///
  /// This method updates the internal state of the tuner, calculates cents deviation,
  /// implements auto-tuning logic, and sends tuning data to the connected ESP32
  /// via the [BleService].
  void _onFrequencyDetected(double? frequency) {
    if (_isDisposed) return; // Do nothing if the notifier has been disposed.

    if (frequency != null && frequency > 0) {
      _detectedFrequency = frequency; // Store the newly detected frequency.
      final closestNote = _noteUtils.findClosestNote(frequency); // Find the closest musical note.

      if (closestNote != null) {
        _detectedNoteName = closestNote.key; // Update the detected note name.

        // --- Automatic Tuning Mode Logic ---
        if (_isAutoTuningMode) {
          // In auto-tuning mode, the app attempts to automatically set the target note.
          // It only considers standard guitar string notes for automatic target selection.
          const List<String> standardTuningNotes = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];
          if (standardTuningNotes.contains(closestNote.key) && closestNote.key != _targetNoteName) {
            // If the detected note is a standard tuning note and different from the current target,
            // update the target note and its frequency.
            _targetNoteName = closestNote.key;
            _targetFrequency = closestNote.value;
            debugPrint('Auto-tuned to: $_targetNoteName (${_targetFrequency.toStringAsFixed(1)} Hz)');
          }
        }

        // Calculate the cents deviation from the current detected frequency to the target frequency.
        _centsDeviation = _noteUtils.calculateCentsDeviation(frequency, _targetFrequency);

        // --- BLE Communication for Smart Tuner ---
        // If the BLE service is connected, send tuning data to the ESP32.
        if (_bleService.isConnected) {
          final String message = 'FREQ:${frequency.toStringAsFixed(1)},TARGET:${_targetFrequency.toStringAsFixed(1)},NOTE:$_targetNoteName';
          _bleService.sendData(message); // Send a formatted string containing tuning information.
        }

      } else {
        // If no closest note is found, reset detected note and cents deviation.
        _detectedNoteName = 'N/A';
        _centsDeviation = 0.0;
      }
    } else {
      // If no valid frequency is detected (e.g., silence or noise), reset all related state.
      _detectedFrequency = null;
      _detectedNoteName = 'N/A';
      _centsDeviation = 0.0;
    }

    _hasPendingUpdate = true; // Flag that a UI update is pending due to state change.
  }

  /// Sets the target note for tuning.
  ///
  /// This method is primarily used when the user manually selects a guitar string
  /// to tune. It updates the target note name and its corresponding frequency,
  /// and resets the visual graph data and detected frequency state to prepare
  /// for tuning to the new target.
  ///
  /// Parameters:
  /// - [noteName]: The name of the target musical note (e.g., 'A2', 'E4').
  void setTargetNote(String noteName) {
    if (_isDisposed) return; // Do nothing if the notifier has been disposed.

    _targetNoteName = noteName; // Update the target note name.
    // Retrieve the frequency for the new target note. Fallback to E4 if not found.
    _targetFrequency = _noteUtils.getFrequencyForNote(noteName) ?? noteFrequencies['E4']!;

    // Clear previous graph data and reset detection state to reflect the new target.
    _frequencyGraphData.clear();
    _detectedFrequency = null;
    _detectedNoteName = 'N/A';
    _centsDeviation = 0.0;

    _hasPendingUpdate = true; // Flag that a UI update is pending.
  }

  /// Toggles the automatic tuning mode on or off.
  ///
  /// When enabling auto-tuning, the app will attempt to automatically identify
  /// the string being played and set it as the target note. When disabling,
  /// it may revert to a default target if no sound is active.
  ///
  /// Parameters:
  /// - [newValue]: A boolean indicating whether auto-tuning should be enabled (`true`) or disabled (`false`).
  void toggleAutoTuningMode(bool newValue) {
    if (_isDisposed) return; // Do nothing if the notifier has been disposed.
    if (_isAutoTuningMode == newValue) return; // No change in mode, so do nothing.

    _isAutoTuningMode = newValue; // Update the auto-tuning mode state.
    debugPrint('Auto Tuning Mode: $_isAutoTuningMode');

    // Adjust target note behavior based on the new mode.
    if (!_isAutoTuningMode) {
      // If switching to manual mode:
      // If no frequency is currently detected or the target was 'N/A',
      // set a default target (e.g., E4) to provide a starting point for manual tuning.
      if (_targetNoteName == 'N/A' || _detectedFrequency == null || _detectedFrequency! <= 0) {
        setTargetNote('E4'); // Fallback to a common guitar string.
      }
    } else {
      // If switching to auto mode:
      // Clear the current target note to allow the auto-detection logic to immediately
      // take over and identify the played string.
      _targetNoteName = 'N/A';
      _targetFrequency = noteFrequencies['E4']!; // Keep a valid fallback frequency internally.
      _centsDeviation = 0.0;
    }

    _hasPendingUpdate = true; // Flag that a UI update is pending.
  }

  /// Starts the real-time guitar tuning process.
  ///
  /// This method initializes the [EnhancedPitchDetector] if it hasn't been already,
  /// sets the tuning active flag, starts the continuous graph updates, and
  /// begins the audio detection process.
  ///
  /// Returns a [Future<void>] that completes when the tuning process has started.
  Future<void> startTuning() async {
    if (_isTuningActive || _isDisposed) return; // Do nothing if already active or disposed.

    // Initialize the pitch detector if it's not already initialized.
    if (!_pitchDetector.isInitialized) {
      final success = await _pitchDetector.initialize();
      if (!success) {
        debugPrint('Failed to initialize pitch detector');
        return; // Abort if initialization fails.
      }
    }

    _isTuningActive = true; // Set tuning as active.
    _hasPendingUpdate = true; // Flag for immediate UI update.

    _startContinuousGraphUpdates(); // Begin continuous graph updates for smooth visualization.

    await _pitchDetector.startDetection(); // Start the actual audio detection.
  }

  /// Stops the real-time guitar tuning process.
  ///
  /// This method deactivates the tuning process, stops the continuous graph updates,
  /// cleans up the pitch detector, and resets the tuner's state variables.
  ///
  /// Returns a [Future<void>] that completes when the tuning process has stopped.
  Future<void> stopTuning() async {
    if (!_isTuningActive || _isDisposed) return; // Do nothing if not active or disposed.

    _isTuningActive = false; // Set tuning as inactive.

    _continuousGraphTimer?.cancel(); // Stop the continuous graph update timer.
    _continuousGraphTimer = null;

    await _pitchDetector.stopDetection(); // Stop the audio detection and clean up its resources.

    // Reset all relevant state variables to their default/inactive values.
    _detectedFrequency = null;
    _detectedNoteName = 'N/A';
    _centsDeviation = 0.0;
    _frequencyGraphData.clear(); // Clear all data from the frequency graph.

    _hasPendingUpdate = true; // Flag for immediate UI update.
  }

  @override
  /// Disposes of all timers and resources held by the [TunerDataNotifier].
  /// This method is crucial for preventing memory leaks when the notifier
  /// is no longer needed (e.g., when the widget tree it's provided to is removed).
  void dispose() {
    _isDisposed = true; // Set the disposed flag to prevent further operations.

    // Cancel and nullify all timers to prevent them from firing on a disposed object.
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;

    _continuousGraphTimer?.cancel();
    _continuousGraphTimer = null;

    _pitchDetector.dispose(); // Dispose the underlying pitch detector to release its resources.
    _frequencyGraphData.clear(); // Clear any remaining data in the graph queue.

    super.dispose(); // Call the superclass dispose method.
  }
}

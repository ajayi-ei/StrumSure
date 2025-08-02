// lib/audio/enhanced_pitch_detector.dart

// This file contains the core logic for real-time audio input, processing,
// and fundamental pitch detection within the StrumSure application.
// It manages microphone access, audio buffering, noise reduction, and frequency analysis.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart'; // For managing microphone permissions
import 'package:record/record.dart'; // For recording audio from the microphone
import 'package:path_provider/path_provider.dart'; // For accessing temporary file directories
import 'dart:io'; // For File operations
import 'package:flutter/foundation.dart'; // For debugPrint, useful for platform-specific logging. Also provides Uint8List.


/// A class responsible for real-time audio input, processing, and pitch detection.
/// It continuously listens to microphone input, processes the audio data,
/// and detects the fundamental frequency, providing stable readings through debouncing.
class EnhancedPitchDetector {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isInitialized = false;
  String _recordingPath = ''; // Path to the temporary audio file used for analysis
  Timer? _analysisTimer; // Timer for periodic audio analysis
  StreamSubscription<Uint8List>? _audioStreamSubscription; // Subscription to the audio stream

  /// A queue to store recent audio buffers for analysis.
  /// This helps in maintaining a rolling window of audio data for processing.
  final Queue<List<double>> _audioBufferQueue = Queue<List<double>>();
  static const int _maxBufferSize = 5; // Limits the number of audio buffers kept in memory to manage usage.

  /// Stores the last successfully detected frequency to aid in debouncing.
  double? _lastDetectedFrequency;

  /// Counts consecutive stable frequency readings to ensure accuracy.
  int _stableFrequencyCount = 0;

  /// The number of consistent frequency readings required before reporting a stable pitch.
  static const int _stabilityThreshold = 3;

  /// The interval (in milliseconds) at which audio analysis is performed.
  /// Increased to 150ms to reduce CPU load and prevent overload during real-time processing.
  static const int _analysisIntervalMs = 150;

  // Audio analysis parameters
  static const int _sampleRate = 44100; // Standard audio sample rate (samples per second)
  static const int _bufferSize = 2048; // Size of audio chunks processed at a time, optimized for performance.

  /// Callback function invoked when a stable frequency is detected.
  /// It receives the detected frequency as a `double?`.
  Function(double?)? onFrequencyDetected;

  /// Indicates whether the pitch detector has been successfully initialized.
  bool get isInitialized => _isInitialized;

  /// Constructs an [EnhancedPitchDetector] instance.
  ///
  /// [onFrequencyDetected] is an optional callback function that will be called
  /// when a stable frequency is detected, allowing the UI to update.
  EnhancedPitchDetector({this.onFrequencyDetected});

  /// Initializes the pitch detector by requesting necessary microphone permissions.
  /// This must be called before attempting to start audio detection.
  ///
  /// Returns `true` if all required permissions are granted and the recorder is available,
  /// `false` otherwise.
  Future<bool> initialize() async {
    try {
      // Request microphone permission, which is essential for audio input.
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission denied');
      }

      // Verify that the audio recorder has the necessary permissions to operate.
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Audio recorder permission not granted');
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Failed to initialize pitch detector: $e');
      return false;
    }
  }

  /// Starts the real-time audio detection and analysis process.
  /// This method begins recording from the microphone and initiates periodic
  /// analysis of the audio stream to detect pitch.
  ///
  /// Requires the detector to be initialized successfully beforehand.
  Future<void> startDetection() async {
    if (!_isInitialized) {
      debugPrint('Pitch detector not initialized. Call initialize() first.');
      return;
    }

    try {
      // Clear any previous audio data and reset frequency debouncing state
      // to ensure a clean start for new detection.
      _audioBufferQueue.clear();
      _lastDetectedFrequency = null;
      _stableFrequencyCount = 0;

      // Get a temporary directory path to store the ongoing audio recording.
      final directory = await getTemporaryDirectory();
      // Create a unique temporary file path for the WAV recording.
      _recordingPath = '${directory.path}/guitar_tuning_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Configure the audio recorder for efficient real-time analysis.
      // Settings are optimized for reduced memory usage and single-channel audio.
      const config = RecordConfig(
        encoder: AudioEncoder.wav, // Use WAV encoder for raw PCM data
        bitRate: 64000, // Reduced bit rate to 64kbps for smaller file sizes and memory footprint
        sampleRate: _sampleRate, // Set to 44.1 kHz for standard audio quality
        numChannels: 1, // Use mono audio for simpler pitch detection
      );

      // Start recording audio to the temporary file.
      await _audioRecorder.start(config, path: _recordingPath);

      // Begin the periodic real-time analysis of the recorded audio.
      _startOptimizedRealTimeAnalysis();
    } catch (e) {
      debugPrint('Failed to start detection: $e');
    }
  }

  /// Stops the audio detection process and cleans up all associated resources.
  /// This includes stopping the analysis timer, cancelling audio stream subscriptions,
  /// stopping the audio recorder, and deleting the temporary recording file.
  Future<void> stopDetection() async {
    try {
      // Ensure the analysis timer is cancelled to stop periodic processing.
      _analysisTimer?.cancel();
      _analysisTimer = null;

      // Cancel any active audio stream subscriptions to prevent memory leaks.
      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // Stop the audio recorder.
      await _audioRecorder.stop();

      // Clear any remaining audio buffers and reset pitch detection state.
      _audioBufferQueue.clear();
      _lastDetectedFrequency = null;
      _stableFrequencyCount = 0;

      // Clean up the temporary audio file if it exists.
      if (_recordingPath.isNotEmpty) {
        final file = File(_recordingPath);
        if (await file.exists()) {
          await file.delete();
        }
        _recordingPath = ''; // Reset the recording path
      }
    } catch (e) {
      debugPrint('Failed to stop detection: $e');
    }
  }

  /// Initiates a periodic timer that triggers optimized real-time audio analysis.
  /// This timer ensures that audio data is processed at regular intervals
  /// without overwhelming the system.
  void _startOptimizedRealTimeAnalysis() {
    _analysisTimer?.cancel(); // Cancel any existing timer to avoid duplicates.

    // Set up a new periodic timer for analysis.
    _analysisTimer = Timer.periodic(const Duration(milliseconds: _analysisIntervalMs), (timer) async {
      // If the recording path is empty, it means recording has stopped or failed,
      // so the timer should be cancelled.
      if (_recordingPath.isEmpty) {
        timer.cancel();
        return;
      }

      // Perform the actual audio analysis.
      await _analyzeCurrentAudioOptimized();
    });
  }

  /// Analyzes the current audio data from the temporary recording file.
  /// This method reads recent audio bytes, converts them to samples,
  /// applies noise reduction, and then detects the fundamental frequency.
  Future<void> _analyzeCurrentAudioOptimized() async {
    // Ensure a valid recording path exists and the file is present before attempting to read.
    if (_recordingPath.isEmpty || !File(_recordingPath).existsSync()) return;

    try {
      final file = File(_recordingPath);
      final bytes = await file.readAsBytes(); // Read the raw audio bytes from the file.

      // Ensure there's enough data to perform meaningful analysis.
      // A minimum of 2000 bytes is a conservative requirement.
      if (bytes.length < 2000) return;

      // Convert raw bytes to a list of double samples, optimized for efficiency
      // and with bounds checking to handle partial or malformed data.
      final samples = _convertToSamplesOptimized(bytes);
      // Ensure the converted samples meet the minimum buffer size for analysis.
      if (samples.length < _bufferSize) return;

      // Manage the audio buffers, keeping only the most recent relevant samples.
      _manageAudioBuffers(samples);

      // Retrieve the most recent audio buffer for pitch detection.
      if (_audioBufferQueue.isEmpty) return;
      final recentSamples = _audioBufferQueue.last;

      // Apply lightweight noise reduction to improve the quality of samples
      // before pitch detection, minimizing CPU overhead.
      final filteredSamples = _applyLightweightNoiseReduction(recentSamples);

      // Detect the fundamental frequency from the filtered samples using an optimized algorithm.
      final frequency = _detectFrequencyOptimized(filteredSamples);

      // Apply debouncing logic to the detected frequency to filter out erratic readings
      // and provide a more stable, reliable pitch.
      final stableFrequency = _applyFrequencyDebouncing(frequency);

      // If a stable frequency is found, invoke the callback to notify listeners (e.g., UI).
      onFrequencyDetected?.call(stableFrequency);
    } catch (e) {
      // Gracefully handle errors during real-time analysis without spamming the console.
      // Errors here might be transient (e.g., file access issues) and don't necessarily
      // indicate a critical failure requiring immediate user attention.
      // debugPrint('Error during audio analysis: $e'); // Uncomment for detailed debugging
    }
  }

  /// Manages the audio buffer queue, ensuring that only the most recent
  /// and relevant audio samples are retained in memory. This prevents memory
  /// growth during continuous recording.
  ///
  /// Parameters:
  /// - `samples`: A list of double samples representing a chunk of audio.
  void _manageAudioBuffers(List<double> samples) {
    // Extract only the most recent samples up to the defined buffer size.
    final recentSamples = samples.length > _bufferSize
        ? samples.sublist(samples.length - _bufferSize)
        : samples;

    _audioBufferQueue.add(recentSamples); // Add the new recent samples to the queue.

    // Remove older buffers if the queue exceeds the maximum allowed size,
    // maintaining a fixed memory footprint.
    while (_audioBufferQueue.length > _maxBufferSize) {
      _audioBufferQueue.removeFirst();
    }
  }

  /// Converts raw audio bytes (16-bit PCM WAV format) into a list of double samples.
  /// The samples are normalized to a range of -1.0 to 1.0.
  ///
  /// This method is optimized to process only recent data to prevent memory buildup
  /// and includes bounds checking for robust handling of audio data.
  ///
  /// Parameters:
  /// - `bytes`: The raw audio data as a `Uint8List`.
  ///
  /// Returns:
  /// - A `List<double>` representing the normalized audio samples.
  List<double> _convertToSamplesOptimized(Uint8List bytes) {
    const headerSize = 44; // Standard WAV file header size in bytes.
    if (bytes.length <= headerSize) return []; // Return empty if data is too short to contain audio.

    final samples = <double>[];

    // Determine the starting position for processing to focus on recent data,
    // avoiding unnecessary processing of older parts of the temporary file.
    final startPos = math.max(headerSize, bytes.length - (_bufferSize * 2 + headerSize));

    // Iterate through the bytes, converting 16-bit PCM (2 bytes per sample)
    // into double samples.
    for (int i = startPos; i < bytes.length - 1; i += 2) {
      // Combine two bytes to form a 16-bit signed integer.
      final sample = (bytes[i] | (bytes[i + 1] << 8));
      // Normalize the sample to a floating-point value between -1.0 and 1.0.
      final normalizedSample = (sample > 32767 ? sample - 65536 : sample) / 32768.0;
      samples.add(normalizedSample);
    }
    return samples;
  }

  /// Applies lightweight noise reduction techniques to a list of audio samples.
  /// This helps in isolating the primary musical signal from background noise
  /// without incurring significant CPU overhead, making it suitable for real-time use.
  ///
  /// Parameters:
  /// - `samples`: The raw audio samples to be filtered.
  ///
  /// Returns:
  /// - A `List<double>` containing the noise-reduced audio samples.
  List<double> _applyLightweightNoiseReduction(List<double> samples) {
    if (samples.isEmpty) return samples;

    // Apply a simple high-pass filter to remove low-frequency hum and rumble.
    var filtered = _simpleHighPassFilter(samples);
    // Apply an adaptive noise gate to mute samples below a dynamic threshold,
    // effectively silencing very quiet background noise.
    filtered = _adaptiveNoiseGate(filtered);

    return filtered;
  }

  /// Applies a simple first-order high-pass filter to the audio samples.
  /// This filter helps to remove low-frequency components (like hum or rumble)
  /// from the audio signal, which can interfere with pitch detection.
  ///
  /// Parameters:
  /// - `samples`: The audio samples to filter.
  ///
  /// Returns:
  /// - A `List<double>` containing the high-pass filtered samples.
  List<double> _simpleHighPassFilter(List<double> samples) {
    if (samples.length < 2) return samples;

    final filtered = <double>[];
    const alpha = 0.95; // High-pass filter coefficient: higher alpha means higher cutoff frequency.

    double prevInput = samples[0];
    double prevOutput = 0.0;

    for (int i = 1; i < samples.length; i++) {
      // Simple IIR filter equation: y[n] = alpha * (y[n-1] + x[n] - x[n-1])
      final output = alpha * (prevOutput + samples[i] - prevInput);
      filtered.add(output);
      prevInput = samples[i];
      prevOutput = output;
    }

    return filtered;
  }

  /// Applies an adaptive noise gate to the audio samples.
  /// This function calculates the Root Mean Square (RMS) energy of the current
  /// audio buffer to dynamically determine a noise threshold. Samples below this
  /// threshold are muted (set to 0.0), effectively reducing background noise.
  ///
  /// Parameters:
  /// - `samples`: The audio samples to process.
  ///
  /// Returns:
  /// - A `List<double>` with samples below the adaptive threshold set to zero.
  List<double> _adaptiveNoiseGate(List<double> samples) {
    if (samples.isEmpty) return samples;

    // Calculate RMS (Root Mean Square) energy of the samples.
    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    final rms = math.sqrt(sumSquares / samples.length);

    // Define a dynamic threshold as a percentage of the RMS.
    final threshold = rms * 0.15; // 15% of RMS, slightly higher to be more aggressive.

    // Mute (set to 0.0) any sample whose absolute value is below the threshold.
    return samples.map((sample) => sample.abs() > threshold ? sample : 0.0).toList();
  }

  /// Applies debouncing logic to a detected frequency to provide more stable and
  /// less erratic readings. This is crucial for a smooth and reliable tuner experience.
  ///
  /// The function checks if the current `frequency` is consistent with the
  /// `_lastDetectedFrequency` within a small tolerance for a specified number of times
  /// (`_stabilityThreshold`). Only when this threshold is met is the frequency
  /// considered stable and returned.
  ///
  /// Parameters:
  /// - `frequency`: The raw frequency (in Hz) detected from the current audio buffer.
  ///
  /// Returns:
  /// - A `double?` representing the stable frequency, or `null` if the frequency
  ///   is not yet stable or is invalid (e.g., 0 or negative).
  double? _applyFrequencyDebouncing(double frequency) {
    if (frequency <= 0) {
      // Reset debouncing state if frequency is invalid (no sound or error).
      _stableFrequencyCount = 0;
      _lastDetectedFrequency = null;
      return null;
    }

    // If a previous frequency exists, check for stability within a tolerance.
    if (_lastDetectedFrequency != null) {
      final tolerance = _lastDetectedFrequency! * 0.05; // 5% tolerance.
      if ((frequency - _lastDetectedFrequency!).abs() <= tolerance) {
        // Increment count if current frequency is within tolerance of the last stable one.
        _stableFrequencyCount++;
      } else {
        // Reset count and update last detected frequency if it's outside tolerance.
        _stableFrequencyCount = 1;
        _lastDetectedFrequency = frequency;
      }
    } else {
      // Initialize for the first valid frequency detected.
      _stableFrequencyCount = 1;
      _lastDetectedFrequency = frequency;
    }

    // Return the frequency only if it has been stable for the required number of counts.
    return _stableFrequencyCount >= _stabilityThreshold ? frequency : null;
  }

  /// Detects the fundamental frequency from a list of audio samples using
  /// an optimized autocorrelation algorithm.
  ///
  /// This method is designed for performance in real-time applications.
  /// It includes a simple validation step to ensure the detected frequency
  /// falls within the typical range for guitar notes.
  ///
  /// Parameters:
  /// - `samples`: The audio samples (normalized doubles) to analyze.
  ///
  /// Returns:
  /// - The detected fundamental frequency in Hz as a `double`. Returns `0.0`
  ///   if no valid frequency is detected or if the sample length is too short.
  double _detectFrequencyOptimized(List<double> samples) {
    if (samples.length < 256) return 0.0; // Minimum sample length required for analysis.

    // Use the optimized autocorrelation method to find the pitch.
    final autocorrelationFreq = _autocorrelationPitchDetectionOptimized(samples);

    // Validate the detected frequency: ensure it falls within the expected
    // range for guitar (approx. 80 Hz to 1000 Hz). Frequencies outside this
    // range are likely noise or harmonics, and are filtered out.
    return (autocorrelationFreq >= 80 && autocorrelationFreq <= 1000) ? autocorrelationFreq : 0.0;
  }

  /// Performs autocorrelation-based pitch detection on audio samples.
  /// Autocorrelation measures the similarity of a signal with a delayed version of itself,
  /// which helps in identifying periodic patterns (i.e., pitch).
  ///
  /// This implementation is optimized to process fewer periods and samples
  /// for improved real-time performance.
  ///
  /// Parameters:
  /// - `samples`: The audio samples (normalized doubles) to analyze.
  ///
  /// Returns:
  /// - The detected fundamental frequency in Hz as a `double`. Returns `0.0`
  ///   if no significant correlation is found.
  double _autocorrelationPitchDetectionOptimized(List<double> samples) {
    final n = samples.length; // Total number of samples.
    final minPeriod = (_sampleRate / 1000).round(); // Minimum period (for max 1000 Hz).
    final maxPeriod = (_sampleRate / 80).round();   // Maximum period (for min 80 Hz).

    double maxCorrelation = 0.0; // Stores the highest correlation coefficient found.
    int bestPeriod = 0; // Stores the period (lag) corresponding to the maxCorrelation.

    // Define a step size to process fewer periods, optimizing performance.
    // This samples autocorrelation at intervals rather than every single period.
    final stepSize = math.max(1, (maxPeriod - minPeriod) ~/ 100);

    // Iterate through possible periods (lags) within the expected frequency range.
    for (int period = minPeriod; period < maxPeriod && period < n ~/ 3; period += stepSize) {
      double correlation = 0.0; // Sum of products for autocorrelation.
      double energy = 0.0; // Sum of squares for normalization.

      // Define the number of samples to process for each period, optimizing for performance.
      final sampleCount = math.min(n - period, n ~/ 2);

      for (int i = 0; i < sampleCount; i++) {
        correlation += samples[i] * samples[i + period];
        energy += samples[i] * samples[i];
      }

      if (energy > 0) {
        correlation /= energy; // Normalize correlation by energy.

        // Update best period if a higher correlation is found.
        if (correlation > maxCorrelation) {
          maxCorrelation = correlation;
          bestPeriod = period;
        }
      }
    }

    // Return the fundamental frequency if a significant correlation is found.
    // A correlation threshold of 0.4 is used to filter out weak or unreliable detections.
    return bestPeriod > 0 && maxCorrelation > 0.4
        ? _sampleRate / bestPeriod // Frequency = Sample Rate / Period
        : 0.0; // Return 0.0 if no reliable pitch is detected.
  }

  // FIXED: Proper disposal with resource cleanup
  /// Disposes of all resources used by the pitch detector.
  /// This includes cancelling active timers and stream subscriptions,
  /// clearing audio buffers, disposing the audio recorder, and deleting
  /// any temporary audio files to prevent memory leaks and resource exhaustion.
  void dispose() {
    _analysisTimer?.cancel(); // Cancel the periodic analysis timer.
    _analysisTimer = null;

    _audioStreamSubscription?.cancel(); // Cancel any active audio stream subscription.
    _audioStreamSubscription = null;

    _audioBufferQueue.clear(); // Clear any remaining audio data in the buffer.

    try {
      _audioRecorder.dispose(); // Dispose the audio recorder to release hardware resources.
    } catch (e) {
      debugPrint('Error disposing audio recorder: $e'); // Log any errors during disposal.
    }

    // Attempt to clean up the temporary recording file if it exists.
    if (_recordingPath.isNotEmpty) {
      final file = File(_recordingPath);
      // Use catchError to gracefully handle potential file deletion errors
      // without crashing the application. It returns the file itself to satisfy
      // the FutureOr<FileSystemEntity> type requirement of catchError.
      file.delete().catchError((e) {
        debugPrint('Error deleting temp file: $e');
        return file; // Return the file to satisfy the expected type
      });
    }
  }
}

// lib/utils/note_utils.dart

// This file provides essential utility functions for musical note-related calculations,
// primarily for pitch detection and tuning within the StrumSure application.
// It includes a comprehensive map of standard musical note frequencies.

import 'dart:math' as math;

/// A global constant map containing standard frequencies (in Hz) for musical notes
/// across various octaves (from C0 to B8). These frequencies are based on A4 = 440 Hz
/// and are fundamental for accurate pitch detection and tuning.
const Map<String, double> noteFrequencies = {
  'C0': 16.35, 'C#0': 17.32, 'D0': 18.35, 'D#0': 19.45, 'E0': 20.60, 'F0': 21.83,
  'F#0': 23.12, 'G0': 24.50, 'G#0': 25.96, 'A0': 27.50, 'A#0': 29.14, 'B0': 30.87,
  'C1': 32.70, 'C#1': 34.65, 'D1': 36.71, 'D#1': 38.89, 'E1': 41.20, 'F1': 43.65,
  'F#1': 46.25, 'G1': 49.00, 'G#1': 51.91, 'A1': 55.00, 'A#1': 58.27, 'B1': 61.74,
  'C2': 65.41, 'C#2': 69.30, 'D2': 73.42, 'D#2': 77.78, 'E2': 82.41, 'F2': 87.31,
  'F#2': 92.50, 'G2': 98.00, 'G#2': 103.8, 'A2': 110.0, 'A#2': 116.5, 'B2': 123.5,
  'C3': 130.8, 'C#3': 138.6, 'D3': 146.8, 'D#3': 155.6, 'E3': 164.8, 'F3': 174.6,
  'F#3': 185.0, 'G3': 196.0, 'G#3': 207.7, 'A3': 220.0, 'A#3': 233.1, 'B3': 246.9,
  'C4': 261.6, 'C#4': 277.2, 'D4': 293.7, 'D#4': 311.1, 'E4': 329.6, 'F4': 349.2,
  'F#4': 370.0, 'G4': 392.0, 'G#4': 415.3, 'A4': 440.0, 'A#4': 466.2, 'B4': 493.9,
  'C5': 523.3, 'C#5': 554.4, 'D5': 587.3, 'D#5': 622.3, 'E5': 659.3, 'F5': 698.5,
  'F#5': 740.0, 'G5': 784.0, 'G#5': 830.6, 'A5': 880.0, 'A#5': 932.3, 'B5': 987.8,
  'C6': 1047, 'C#6': 1109, 'D6': 1175, 'D#6': 1245, 'E6': 1319, 'F6': 1397,
  'F#6': 1480, 'G6': 1568, 'G#6': 1661, 'A6': 1760, 'A#6': 1865, 'B6': 1976,
  'C7': 2093, 'C#7': 2217, 'D7': 2349, 'D#7': 2489, 'E7': 2637, 'F7': 2794,
  'F#7': 2960, 'G7': 3136, 'G#7': 3322, 'A7': 3520, 'A#7': 3729, 'B7': 3951,
  'C8': 4186, 'C#8': 4435, 'D8': 4699, 'D#8': 4978, 'E8': 5274, 'F8': 5588,
  'F#8': 5920, 'G8': 6272, 'G#8': 6645, 'A8': 7040, 'A#8': 7459, 'B8': 7902,
};

/// A utility class providing methods for common musical note calculations.
/// This includes finding the closest standard note to a given frequency,
/// calculating cents deviation, and retrieving a note's frequency.
class NoteUtils {
  /// Finds the closest standard musical note from the `noteFrequencies` map
  /// to a given `detectedFrequency`.
  ///
  /// This method iterates through the predefined note frequencies and calculates
  /// the absolute difference between the `detectedFrequency` and each standard note's frequency.
  /// It returns the `MapEntry` (note name and its frequency) of the closest match.
  ///
  /// Returns `null` if `detectedFrequency` is zero or negative.
  ///
  /// Parameters:
  /// - `detectedFrequency`: The frequency (in Hz) obtained from audio analysis.
  ///
  /// Returns:
  /// - A `MapEntry<String, double>` representing the closest note (e.g., 'A4': 440.0),
  ///   or `null` if no valid frequency is provided.
  MapEntry<String, double>? findClosestNote(double detectedFrequency) {
    if (detectedFrequency <= 0) return null;

    MapEntry<String, double>? closestNote;
    double minDifference = double.infinity;

    noteFrequencies.forEach((noteName, frequency) {
      final difference = (detectedFrequency - frequency).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestNote = MapEntry(noteName, frequency);
      }
    });
    return closestNote;
  }

  /// Calculates the cents deviation of a `detectedFrequency` from a `targetFrequency`.
  /// Cents are a logarithmic unit of measure used for musical intervals.
  ///
  /// A positive return value indicates that the `detectedFrequency` is sharp (higher)
  /// relative to the `targetFrequency`. A negative value indicates it is flat (lower).
  /// A value close to zero means the detected frequency is in tune with the target.
  ///
  /// Parameters:
  /// - `detectedFrequency`: The frequency (in Hz) obtained from audio analysis.
  /// - `targetFrequency`: The ideal frequency (in Hz) of the note being tuned to.
  ///
  /// Returns:
  /// - The cents deviation as a `double`. Returns `0.0` if either input frequency
  ///   is zero or negative to prevent mathematical errors.
  double calculateCentsDeviation(double detectedFrequency, double targetFrequency) {
    if (detectedFrequency <= 0 || targetFrequency <= 0) return 0.0;
    // Formula for cents deviation: 1200 * log2(detectedFrequency / targetFrequency)
    return 1200 * math.log(detectedFrequency / targetFrequency) / math.log(2);
  }

  /// Retrieves the standard frequency (in Hz) for a given musical note name.
  ///
  /// Parameters:
  /// - `noteName`: The name of the musical note (e.g., "A4", "C#3").
  ///
  /// Returns:
  /// - The frequency as a `double?` if the note name is found in the `noteFrequencies` map,
  ///   otherwise returns `null`.
  double? getFrequencyForNote(String noteName) {
    return noteFrequencies[noteName];
  }
}

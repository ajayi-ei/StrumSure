// lib/models/saved_song.dart

// This file defines the data models used for storing and retrieving
// detected chord information and saved songs within the application.
// It includes classes for individual chord data points and the overall saved song structure.

/// Represents a single chord detection entry, detailing the chord, its time range,
/// and the specific notes detected within that segment.
class ChordData {
  /// The start time of the chord in seconds, relative to the beginning of the audio.
  final double startTime;

  /// The end time of the chord in seconds, relative to the beginning of the audio.
  final double endTime;

  /// The name of the detected chord (e.g., "C Major", "G minor").
  final String chord;

  /// A list of individual notes detected within this chord segment.
  final List<String> detectedNotes;

  /// Constructs a [ChordData] instance with the specified time range, chord name,
  /// and detected notes.
  ChordData({
    required this.startTime,
    required this.endTime,
    required this.chord,
    required this.detectedNotes,
  });

  /// Factory constructor to create a [ChordData] object from a JSON map.
  /// This is typically used when parsing data received from the backend (e.g., Google Colab)
  /// or when loading saved chord data from local storage.
  factory ChordData.fromJson(Map<String, dynamic> json) {
    return ChordData(
      startTime: (json['start_time'] as num).toDouble(),
      endTime: (json['end_time'] as num).toDouble(),
      chord: json['chord'] as String,
      detectedNotes: List<String>.from(json['detected_notes'] as List),
    );
  }

  /// Converts this [ChordData] object into a JSON map.
  /// This is used for serialization, such as sending data to the backend
  /// or saving the chord data to local storage.
  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime,
      'end_time': endTime,
      'chord': chord,
      'detected_notes': detectedNotes,
    };
  }

  /// Provides a string representation of the [ChordData] object, useful for debugging and logging.
  @override
  String toString() {
    return 'ChordData(startTime: $startTime, endTime: $endTime, chord: $chord, detectedNotes: $detectedNotes)';
  }
}

/// Represents a complete saved song, including its metadata, the local path to its audio file,
/// and a list of all detected [ChordData] segments within it.
class SavedSong {
  /// A unique identifier for this saved song, typically a UUID.
  final String id;

  /// The user-provided title for the song.
  final String title;

  /// The local file system path where the original audio file of the song is stored.
  final String audioFilePath;

  /// A list of [ChordData] objects, representing the sequence of chords detected in the song.
  final List<ChordData> chordData;

  /// The timestamp indicating when this song was saved to local storage.
  final DateTime savedAt;

  /// Constructs a [SavedSong] instance with all its required properties.
  SavedSong({
    required this.id,
    required this.title,
    required this.audioFilePath,
    required this.chordData,
    required this.savedAt,
  });

  /// Factory constructor to create a [SavedSong] object from a JSON map.
  /// This is used when loading saved song metadata from local storage.
  factory SavedSong.fromJson(Map<String, dynamic> json) {
    return SavedSong(
      id: json['id'] as String,
      title: json['title'] as String,
      audioFilePath: json['audio_file_path'] as String,
      chordData: (json['chord_data'] as List)
          .map((item) => ChordData.fromJson(item as Map<String, dynamic>))
          .toList(),
      savedAt: DateTime.parse(json['saved_at'] as String), // Parse ISO 8601 string back to DateTime
    );
  }

  /// Converts this [SavedSong] object into a JSON map.
  /// This is used for serialization when saving the song's metadata to local storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'audio_file_path': audioFilePath,
      'chord_data': chordData.map((chord) => chord.toJson()).toList(),
      'saved_at': savedAt.toIso8601String(), // Convert DateTime to ISO 8601 string for JSON
    };
  }

  /// Provides a string representation of the [SavedSong] object, useful for debugging and logging.
  @override
  String toString() {
    return 'SavedSong(id: $id, title: $title, audioFilePath: $audioFilePath, chordDataCount: ${chordData.length}, savedAt: $savedAt)';
  }
}

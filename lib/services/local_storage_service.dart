// lib/services/local_storage_service.dart

// This file defines the LocalStorageService, a singleton class responsible for
// managing the persistent storage and retrieval of user-saved songs and their
// associated audio files and chord data on the device's local file system.
// It ensures data is preserved across application sessions and handles platform-specific
// storage considerations (e.g., for web environments).

import 'dart:convert'; // For JSON encoding and decoding operations.
import 'dart:io'; // For file system operations (File, Directory).
import 'package:path_provider/path_provider.dart'; // Provides access to platform-specific file system directories.
import 'package:uuid/uuid.dart'; // For generating universally unique identifiers (UUIDs).
import 'package:strum_sure/models/saved_song.dart'; // Imports the data model for SavedSong.
import 'package:flutter/foundation.dart'; // Provides `kIsWeb` for platform detection and `debugPrint` for logging.

/// A service class to handle all interactions with local file storage
/// for saving, retrieving, and deleting chord-detected songs.
/// This class is implemented as a singleton to ensure a single point of access
/// to the application's local storage.
class LocalStorageService {
  // Private constructor to enforce the singleton pattern.
  LocalStorageService._internal();

  // The single instance of LocalStorageService.
  static final LocalStorageService _instance = LocalStorageService._internal();

  // Factory constructor to return the singleton instance.
  factory LocalStorageService() {
    return _instance;
  }

  static const String _songsFileName = 'saved_songs.json'; // The file name for storing song metadata in JSON format.
  static const String _audioSubDir = 'saved_audios'; // The subdirectory name for storing actual audio files.

  final Uuid _uuid = const Uuid(); // An instance of Uuid for generating unique IDs.

  /// Retrieves the full path to the application's documents directory.
  /// This directory is used as the base for storing all persistent application data.
  ///
  /// On web platforms, direct file system access is not available. In such cases,
  /// this method returns a dummy path and logs a warning, allowing the application
  /// to run without crashing, though file operations will be skipped.
  ///
  /// Returns a [Future] that completes with a [Directory] object representing
  /// the application's documents directory.
  Future<Directory> _getAppDocumentsDirectory() async {
    // Check if the application is running on a web platform.
    if (kIsWeb) {
      debugPrint('Warning: getApplicationDocumentsDirectory is not supported on web. Returning dummy path.');
      // Return a dummy directory for web to prevent MissingPluginException.
      return Directory('web_dummy_path');
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      debugPrint('App Documents Directory: ${dir.path}');
      return dir;
    } catch (e) {
      debugPrint('Error getting app documents directory: $e');
      rethrow; // Re-throw the error to propagate it for higher-level handling.
    }
  }

  /// Constructs the [File] object representing the JSON file where the metadata
  /// of all saved songs is stored.
  ///
  /// Returns a [Future] that completes with a [File] object.
  Future<File> _getSongsFile() async {
    final directory = await _getAppDocumentsDirectory();
    final file = File('${directory.path}/$_songsFileName');
    debugPrint('Songs metadata file path: ${file.path}');
    return file;
  }

  /// Retrieves the [Directory] where audio files will be permanently saved.
  /// This method also ensures that the directory exists, creating it if necessary.
  ///
  /// On web platforms, directory creation is skipped as direct file system
  /// operations are not applicable.
  ///
  /// Returns a [Future] that completes with a [Directory] object.
  Future<Directory> _getAudioDirectory() async {
    final directory = await _getAppDocumentsDirectory();
    final audioDir = Directory('${directory.path}/$_audioSubDir');
    // Only attempt to create the directory if not on a web platform and if it doesn't already exist.
    if (!kIsWeb && !await audioDir.exists()) {
      debugPrint('Creating audio directory: ${audioDir.path}');
      await audioDir.create(recursive: true); // Create the directory and any necessary parent directories.
    } else if (!kIsWeb) {
      debugPrint('Audio directory already exists: ${audioDir.path}');
    }
    return audioDir;
  }

  /// Reads and deserializes the list of all saved songs from the local JSON file.
  ///
  /// Returns an empty list if the file does not exist, is empty, or if the
  /// application is running on a web platform where file operations are skipped.
  ///
  /// Returns a [Future] that completes with a [List<SavedSong>].
  Future<List<SavedSong>> getSavedSongs() async {
    // Skip file operations entirely if running on a web platform.
    if (kIsWeb) {
      debugPrint('Getting saved songs skipped on web: File operations not supported.');
      return []; // Return an empty list as no songs can be retrieved from local file system.
    }

    try {
      final file = await _getSongsFile();
      // Check if the songs metadata file exists.
      if (!await file.exists()) {
        debugPrint('Saved songs file does not exist. Returning empty list.');
        return []; // No saved songs yet.
      }
      final contents = await file.readAsString(); // Read the entire content of the file as a string.
      // Check if the file content is empty.
      if (contents.isEmpty) {
        debugPrint('Saved songs file is empty. Returning empty list.');
        return []; // File exists but contains no data.
      }
      // Print a substring of the raw JSON contents for debugging purposes.
      debugPrint('Raw JSON contents: ${contents.substring(0, contents.length > 200 ? 200 : contents.length)}...');
      final List<dynamic> jsonList = jsonDecode(contents); // Decode the JSON string into a dynamic list.
      debugPrint('Successfully decoded JSON for ${jsonList.length} songs.');
      // Map each JSON object to a SavedSong instance and return as a list.
      return jsonList.map((json) => SavedSong.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('CRITICAL ERROR reading saved songs from local storage: $e');
      // Re-throw the error to ensure the UI (e.g., SavedSongsListScreen) can
      // catch it, stop any loading indicators, and display an appropriate error message.
      rethrow;
    }
  }

  /// Saves the current list of [SavedSong] objects back to the local JSON file.
  /// This method is typically called after adding or deleting a song.
  ///
  /// Returns a [Future<void>] that completes when the save operation is finished.
  Future<void> _saveSongs(List<SavedSong> songs) async {
    // Skip file operations entirely if running on a web platform.
    if (kIsWeb) {
      debugPrint('Saving songs skipped on web: File operations not supported.');
      return;
    }

    try {
      final file = await _getSongsFile();
      // Encode the list of SavedSong objects into a JSON string.
      final String jsonString = jsonEncode(songs.map((song) => song.toJson()).toList());
      await file.writeAsString(jsonString); // Write the JSON string to the file.
      debugPrint('Successfully saved ${songs.length} songs to local storage.');
    } catch (e) {
      debugPrint('ERROR writing songs to local storage: $e');
      rethrow; // Re-throw the error for higher-level error handling.
    }
  }

  /// Saves a new song and its associated audio file to local storage.
  /// This involves copying the audio file to a permanent location and updating
  /// the song metadata in the JSON file.
  ///
  /// Parameters:
  /// - [originalAudioFile]: The temporary audio file (e.g., from recording or picking) to be saved.
  /// - [chordData]: The list of detected [ChordData] for this song.
  /// - [title]: The user-provided title for the song.
  ///
  /// Returns a [Future] that completes with the newly created [SavedSong] object.
  Future<SavedSong> saveSong({
    required File originalAudioFile,
    required List<ChordData> chordData,
    required String title,
  }) async {
    // If on web, skip actual file saving and return a dummy object to prevent crashes.
    if (kIsWeb) {
      debugPrint('Saving song "$title" skipped on web: File operations not supported.');
      return SavedSong(
        id: _uuid.v4(), // Still generate a UUID for consistency.
        title: title,
        audioFilePath: 'web_dummy_path', // Dummy path for web.
        chordData: chordData,
        savedAt: DateTime.now(),
      );
    }

    try {
      // 1. Copy the audio file to a permanent local directory.
      final audioDir = await _getAudioDirectory();
      // Sanitize the title to create a safe filename, replacing special characters with underscores.
      final String sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s.-]'), '').replaceAll(' ', '_');
      // Generate a unique filename using a UUID to prevent clashes, appending original extension.
      final String uniqueFileName = '${_uuid.v4()}_$sanitizedTitle.'
          '${originalAudioFile.path.split('.').last}';
      final String newAudioFilePath = '${audioDir.path}/$uniqueFileName';
      // Copy the original audio file to its new permanent location.
      final File newAudioFile = await originalAudioFile.copy(newAudioFilePath);
      debugPrint('Audio file copied to: ${newAudioFile.path}');

      // 2. Create the new [SavedSong] object with all its details.
      final newSong = SavedSong(
        id: _uuid.v4(), // Generate a unique ID for the song.
        title: title,
        audioFilePath: newAudioFile.path, // Store the new permanent local path.
        chordData: chordData,
        savedAt: DateTime.now(), // Record the exact time the song was saved.
      );

      // 3. Retrieve existing songs, add the new one, and save the updated list.
      // Any errors from `getSavedSongs` will be re-thrown and caught by this outer try-catch.
      final currentSongs = await getSavedSongs();
      currentSongs.add(newSong); // Add the newly created song to the list.
      await _saveSongs(currentSongs); // Persist the updated list to local storage.

      debugPrint('Song "${newSong.title}" saved successfully to local storage.');
      return newSong; // Return the newly saved song object.
    } catch (e) {
      debugPrint('ERROR in saveSong method: $e');
      rethrow; // Re-throw to allow the UI to handle and display errors.
    }
  }

  /// Deletes a saved song from local storage, removing both its metadata
  /// from the JSON file and its associated audio file from the file system.
  ///
  /// Parameters:
  /// - [songId]: The unique ID of the song to delete.
  ///
  /// Returns a [Future<void>] that completes when the deletion is finished.
  Future<void> deleteSong(String songId) async {
    // Skip file operations entirely if running on a web platform.
    if (kIsWeb) {
      debugPrint('Deleting song "$songId" skipped on web: File operations not supported.');
      return;
    }

    try {
      final currentSongs = await getSavedSongs();
      // Find the index of the song to delete based on its ID.
      final songToDeleteIndex = currentSongs.indexWhere((song) => song.id == songId);

      if (songToDeleteIndex == -1) {
        debugPrint('Song with ID $songId not found in local storage for deletion.');
        return; // Exit if the song is not found.
      }

      final songToDelete = currentSongs[songToDeleteIndex];

      // 1. Delete the local audio file associated with the song.
      final localFile = File(songToDelete.audioFilePath);
      if (await localFile.exists()) {
        await localFile.delete(); // Delete the physical audio file.
        debugPrint('Deleted local audio file: ${songToDelete.audioFilePath}');
      } else {
        debugPrint('Local audio file not found for song ID: $songId at path: ${songToDelete.audioFilePath}. Metadata will still be removed.');
      }

      // 2. Remove the song's metadata from the list and save the updated list.
      currentSongs.removeAt(songToDeleteIndex); // Remove the song from the in-memory list.
      await _saveSongs(currentSongs); // Persist the updated list to local storage.
      debugPrint('Deleted song metadata from local storage: ${songToDelete.title}');
    } catch (e) {
      debugPrint('ERROR deleting song from local storage: $e');
      rethrow; // Re-throw for higher-level error handling.
    }
  }
}

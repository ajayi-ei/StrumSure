// lib/screens/chord_detector_screen.dart

// This file defines the ChordDetectorScreen, a dedicated user interface
// within the StrumSure application for analyzing audio files to detect chords.
// It allows users to pick an audio file, send it to a backend API for analysis,
// display the detected chords, and save the results locally.

import 'package:flutter/material.dart'; // Core Flutter UI components.
import 'package:http/http.dart' as http; // For making HTTP requests to the backend.
import 'package:file_picker/file_picker.dart'; // For picking audio files from the device.
import 'package:permission_handler/permission_handler.dart'; // For requesting and checking system permissions.
import 'dart:convert'; // For JSON encoding and decoding.
import 'dart:io'; // For File operations (reading, accessing paths).
import 'dart:math' as math; // For mathematical functions like `math.min`.

// Import data models and services specific to the application.
import 'package:strum_sure/models/saved_song.dart'; // Imports the data model for SavedSong and ChordData.
import 'package:strum_sure/services/local_storage_service.dart'; // Imports the local storage service for saving songs.

/// A screen dedicated to detecting chords from user-selected audio files.
///
/// This screen provides the UI and logic for:
/// - Requesting necessary storage permissions.
/// - Allowing users to pick audio files from their device.
/// - Uploading the selected audio file to a Google Colab backend for chord analysis.
/// - Displaying the detected chords and their time ranges.
/// - Providing an option to save the analyzed song with its chord data locally.
class ChordDetectorScreen extends StatefulWidget {
  /// Constructs a [ChordDetectorScreen] widget.
  const ChordDetectorScreen({super.key});

  @override
  State<ChordDetectorScreen> createState() => _ChordDetectorScreenState();
}

/// The state class for [ChordDetectorScreen].
///
/// It manages the mutable state of the chord detector screen, including
/// selected file information, analysis results, loading indicators,
/// and interaction with backend services and local storage.
class _ChordDetectorScreenState extends State<ChordDetectorScreen> {
  String _selectedFileName = 'No file selected'; // Displays the name of the audio file chosen by the user.
  File? _selectedAudioFile; // Stores the actual File object of the selected audio.
  List<dynamic> _chordResults = []; // Stores the raw JSON results (list of maps) received from the backend.
  String _statusMessage = 'Pick an audio file and analyze.'; // User-facing message indicating current status or instructions.
  bool _isLoading = false; // Flag to indicate if an audio analysis request is in progress.
  bool _isSaving = false; // Flag to indicate if the song saving process is in progress.

  // IMPORTANT: This URL must be replaced with your active ngrok tunnel URL
  // from your Google Colab backend, appended with the specific endpoint for audio analysis.
  // Ensure this URL is updated regularly as ngrok tunnels typically change.
  final String _colabApiUrl = 'YOUR_NGROK_URL_HERE/analyze_audio'; // <-- Update this line with your actual ngrok URL

  // An instance of the LocalStorageService for saving and retrieving songs.
  final LocalStorageService _localStorageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    // Request necessary permissions immediately when the screen initializes.
    _requestPermissions();
  }

  /// Requests necessary storage permissions for picking audio files on Android.
  ///
  /// This method intelligently handles permissions for different Android versions:
  /// - For Android 13 (API 33) and above, it requests `Permission.audio`.
  /// - For older Android versions (API 32 and below), it requests `Permission.storage`.
  /// It updates the `_statusMessage` based on the permission outcome.
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request audio-specific permission for Android 13+ (API 33+).
      var audioPermissionStatus = await Permission.audio.status;
      if (!audioPermissionStatus.isGranted) {
        audioPermissionStatus = await Permission.audio.request();
      }

      // Request general storage permission for older Android versions or as a fallback.
      var storagePermissionStatus = await Permission.storage.status;
      if (!storagePermissionStatus.isGranted) {
        storagePermissionStatus = await Permission.storage.request();
      }

      // Update status message based on whether permissions were granted.
      if (audioPermissionStatus.isGranted || storagePermissionStatus.isGranted) {
        setState(() {
          _statusMessage = 'Permissions granted. Pick an audio file and analyze.';
        });
      } else {
        setState(() {
          _statusMessage = 'Storage permission denied. Cannot pick files.';
        });
        // Optionally, direct the user to app settings if permissions are crucial and denied.
        // openAppSettings(); // Uncomment if you want to prompt user to open settings.
      }
    } else {
      // For iOS and other platforms, file_picker typically handles permissions
      // via Info.plist entries or they are not required in the same explicit way.
      setState(() {
        _statusMessage = 'Permissions handled. Pick an audio file and analyze.';
      });
    }
  }

  /// Allows the user to pick an audio file from their device's storage.
  ///
  /// This method uses the `file_picker` plugin to open the system file picker,
  /// filters for common audio formats (`.wav`, `.mp3`, `.m4a`), and
  /// updates the UI with the selected file's name and stores its `File` object.
  Future<void> _pickAudioFile() async {
    setState(() {
      _statusMessage = 'Picking file...'; // Indicate file picking is in progress.
      _selectedFileName = 'No file selected'; // Reset previous selection.
      _selectedAudioFile = null; // Clear any previously stored file.
      _chordResults = []; // Clear any previous analysis results.
    });

    try {
      // Open the file picker, allowing only single audio files of specified types.
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'm4a'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        // If a file was successfully picked.
        File audioFile = File(result.files.single.path!);
        setState(() {
          _selectedFileName = audioFile.path.split('/').last; // Extract and display just the file name.
          _selectedAudioFile = audioFile; // Store the File object for analysis.
          _statusMessage = 'File selected: $_selectedFileName. Ready to analyze.';
        });
      } else {
        // If the user canceled the picker.
        setState(() {
          _selectedFileName = 'No file selected';
          _selectedAudioFile = null;
          _statusMessage = 'File picking cancelled.';
        });
      }
    } catch (e) {
      // Catch and display any errors that occur during file picking (e.g., permission issues).
      setState(() {
        _statusMessage = 'Error picking file: $e';
      });
    }
  }

  /// Uploads the selected audio file to the Google Colab backend for chord analysis.
  ///
  /// This method constructs a multipart HTTP request, sends the audio file,
  /// and then parses the JSON response containing the chord analysis results.
  /// It updates the UI with loading states, status messages, and results.
  Future<void> _analyzeAudio() async {
    // Prevent analysis if no file is selected.
    if (_selectedAudioFile == null) {
      setState(() {
        _statusMessage = 'Please pick an audio file first.';
      });
      return;
    }

    setState(() {
      _isLoading = true; // Activate loading indicator.
      _statusMessage = 'Uploading and analyzing... This might take a while.'; // Inform user about process.
      _chordResults = []; // Clear previous results before starting a new analysis.
    });

    try {
      File audioFile = _selectedAudioFile!; // Use the stored File object.

      // Create a multipart request for file upload.
      var request = http.MultipartRequest('POST', Uri.parse(_colabApiUrl));

      // Attach the audio file to the request. The field name 'audio_file'
      // must match what your Flask backend expects.
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          filename: _selectedFileName, // Use the extracted file name for the request.
        ),
      );

      // Send the request and wait for the streamed response.
      var streamedResponse = await request.send();
      // Convert the streamed response into a standard HTTP Response.
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // If the request was successful (HTTP 200 OK).
        final Map<String, dynamic> responseData = jsonDecode(response.body); // Parse the JSON response.
        if (responseData['status'] == 'success') {
          // If the backend indicates successful analysis.
          setState(() {
            _chordResults = responseData['results']; // Store the list of chord analysis results.
            _statusMessage = 'Analysis complete! You can now save this song.'; // Update success message.
          });
        } else {
          // If the backend returned a 'failure' status or an error.
          setState(() {
            _statusMessage = 'Server error: ${responseData['error'] ?? 'Unknown error'}';
          });
        }
      } else {
        // If the HTTP request itself failed (e.g., 400, 500 status codes).
        String errorMessage = 'Failed to analyze audio. Status: ${response.statusCode}';
        try {
          // Attempt to parse a detailed error message from the response body if it's JSON.
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage += '\nError: ${errorData['error'] ?? 'No specific error message'}';
        } catch (e) {
          // If the response body is not JSON, append a truncated version of the raw body.
          errorMessage += '\nResponse body: ${response.body.substring(0, math.min(response.body.length, 200))}...';
        }
        setState(() {
          _statusMessage = errorMessage;
        });
      }
    } catch (e) {
      // Catch network-related errors (e.g., no internet, ngrok tunnel down)
      // or other exceptions during the analysis process.
      setState(() {
        _statusMessage = 'Network or processing error: $e \n(Check Colab/ngrok & internet connection)';
      });
    } finally {
      // Always turn off the loading state, regardless of success or failure.
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Saves the currently analyzed song (audio file and chord data) to local storage.
  ///
  /// This method uses the `LocalStorageService` to persist the song.
  /// It prevents saving if no analysis has been performed or if a save is already in progress.
  Future<void> _saveSong() async {
    // Prevent saving if no audio file is selected, no chord results exist, or already saving.
    if (_selectedAudioFile == null || _chordResults.isEmpty || _isSaving) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No analyzed song to save or already saving.')),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true; // Activate saving indicator.
      _statusMessage = 'Saving song...'; // Update status message.
    });

    // Capture the song title from the selected file name BEFORE clearing state variables.
    final String songTitleToSave = _selectedFileName.split('.').first;

    try {
      // Convert the dynamic list of chord results (from JSON) into a list of ChordData objects.
      final List<ChordData> parsedChordData = _chordResults
          .map((json) => ChordData.fromJson(json as Map<String, dynamic>))
          .toList();

      // Call the LocalStorageService to save the song.
      await _localStorageService.saveSong(
        originalAudioFile: _selectedAudioFile!, // The original file to be copied.
        chordData: parsedChordData, // The parsed chord data.
        title: songTitleToSave, // The captured title for the song.
      );

      setState(() {
        _statusMessage = 'Song "$songTitleToSave" saved successfully!'; // Update success message.
        _chordResults = []; // Clear results after saving to prepare for a new analysis.
        _selectedFileName = 'No file selected'; // Reset file selection.
        _selectedAudioFile = null; // Clear the stored audio file.
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Song "$songTitleToSave" saved successfully!')), // Show success SnackBar.
        );
      }
    } catch (e) {
      // Catch and display any errors that occur during the saving process.
      setState(() {
        _statusMessage = 'Error saving song: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save song: $e')),
        );
      }
    } finally {
      // Always turn off the saving state, regardless of success or failure.
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the current theme's color scheme and text theme for consistent styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // The AppBar is now managed by the parent `MainAppWrapper` for global navigation.
      // appBar: AppBar(
      //   title: Text(
      //     'Audio Chord Detector',
      //     style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      //   ),
      //   elevation: 4,
      //   backgroundColor: colorScheme.surface,
      //   foregroundColor: colorScheme.onSurface,
      // ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Padding around the entire screen content.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally.
          children: <Widget>[
            // --- Pick Audio File Button ---
            ElevatedButton.icon(
              // Button is disabled if an analysis or save operation is in progress.
              onPressed: _isLoading || _isSaving ? null : _pickAudioFile,
              icon: const Icon(Icons.audio_file),
              label: Text('Pick Audio File', style: textTheme.labelLarge), // Themed text style.
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: colorScheme.primary, // Themed primary color.
                foregroundColor: colorScheme.onPrimary, // Themed text color on primary background.
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners.
                ),
              ),
            ),
            const SizedBox(height: 20), // Vertical spacing.

            // --- Display Selected File Name ---
            Text(
              'Selected: $_selectedFileName',
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurface.withAlpha((255 * 0.7).round()), // Muted text color.
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20), // Vertical spacing.

            // --- Analyze Audio Button ---
            ElevatedButton.icon(
              // Button is disabled if loading, no file selected, or saving.
              onPressed: _isLoading || _selectedAudioFile == null || _isSaving
                  ? null
                  : _analyzeAudio,
              icon: _isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2), // Loading indicator.
              )
                  : const Icon(Icons.insights), // Icon for analysis.
              label: Text(
                _isLoading ? 'Analyzing...' : 'Analyze Audio', // Dynamic text based on loading state.
                style: textTheme.labelLarge,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10), // Small vertical space.

            // --- Save Song Button ---
            ElevatedButton.icon(
              // Button is disabled if no chord results, currently saving, or analyzing.
              onPressed: (_chordResults.isEmpty || _isSaving || _isLoading)
                  ? null
                  : _saveSong,
              icon: _isSaving
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2), // Loading indicator.
              )
                  : const Icon(Icons.save), // Icon for saving.
              label: Text(
                _isSaving ? 'Saving...' : 'Save Song', // Dynamic text based on saving state.
                style: textTheme.labelLarge,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20), // Vertical spacing.

            // --- Status Message Display ---
            Text(
              _statusMessage,
              style: textTheme.bodyMedium?.copyWith(
                // Color changes to error red if the message contains "Error".
                color: _statusMessage.contains('Error') ? colorScheme.error : colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20), // Vertical spacing.

            // --- Chord Analysis Results Display ---
            Expanded(
              // This area dynamically displays either instructional messages,
              // a loading indicator, or the list of chord results.
              child: _chordResults.isEmpty && !_isLoading
                  ? Center(
                child: Text(
                  _selectedFileName != 'No file selected'
                      ? 'Results will appear here after analysis.' // Message if file selected but not analyzed.
                      : 'Pick an audio file to start.', // Initial instruction.
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.5).round())), // Muted text color.
                  textAlign: TextAlign.center,
                ),
              )
                  : _chordResults.isEmpty && _isLoading
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary)) // Show loading indicator during analysis.
                  : ListView.builder(
                // Build a scrollable list of chord results.
                itemCount: _chordResults.length,
                itemBuilder: (context, index) {
                  final result = _chordResults[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    elevation: 2, // Subtle shadow for card.
                    color: colorScheme.surfaceContainerHighest, // Themed background for card.
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners for card.
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Display time range (e.g., "0.0s - 2.5s:").
                            '${result['start_time']}s - ${result['end_time']}s:',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // Display detected chord (e.g., "Chord: Cmaj").
                            'Chord: ${result['chord']}',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary), // Highlight chord with primary color.
                          ),
                          Text(
                            // Display detected notes (e.g., "Notes: C, E, G").
                            'Notes: ${result['detected_notes'].join(', ')}',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())), // Muted text color.
                          ),
                        ],
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
  }
}

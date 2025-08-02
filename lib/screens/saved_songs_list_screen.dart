// lib/screens/saved_songs_list_screen.dart

// This file defines the SavedSongsListScreen, a user interface dedicated to
// displaying a list of songs that have been previously analyzed for chords
// and saved locally within the StrumSure application. It allows users to
// view song details, play back songs with synchronized chord display,
// and delete saved recordings.

import 'package:flutter/material.dart'; // Core Flutter UI components and Material Design.
import 'package:strum_sure/models/saved_song.dart'; // Imports the data model for SavedSong.
import 'package:strum_sure/services/local_storage_service.dart'; // Imports the local storage service for data persistence.
import 'package:strum_sure/screens/song_playback_screen.dart'; // Imports the screen for playing back saved songs.

/// A screen that displays a list of songs previously saved after chord detection.
///
/// This screen provides the UI and logic for:
/// - Loading and displaying a list of [SavedSong] objects from local storage.
/// - Showing a loading indicator and status messages during data retrieval.
/// - Providing a pull-to-refresh mechanism to reload the song list.
/// - Allowing users to tap on a song to navigate to the [SongPlaybackScreen].
/// - Implementing functionality to delete individual saved songs with a confirmation dialog.
class SavedSongsListScreen extends StatefulWidget {
  /// Constructs a [SavedSongsListScreen] widget.
  const SavedSongsListScreen({super.key});

  @override
  State<SavedSongsListScreen> createState() => _SavedSongsListScreenState();
}

/// The state class for [SavedSongsListScreen].
///
/// It manages the mutable state of the screen, including the list of
/// saved songs, loading status, and interaction with the [LocalStorageService].
class _SavedSongsListScreenState extends State<SavedSongsListScreen> {
  // An instance of the LocalStorageService to interact with persistent storage.
  final LocalStorageService _localStorageService = LocalStorageService();
  List<SavedSong> _savedSongs = []; // The list of songs loaded from local storage.
  bool _isLoading = true; // Flag to indicate if songs are currently being loaded or deleted.
  String _statusMessage = 'Loading saved songs...'; // User-facing message for loading/empty states.

  @override
  void initState() {
    super.initState();
    // Initiate loading of saved songs as soon as the screen initializes.
    _loadSavedSongs();
  }

  /// Loads the list of saved songs from the local storage.
  ///
  /// This asynchronous method updates the loading state, retrieves songs
  /// using [LocalStorageService], and updates the UI with the fetched data
  /// or an error message if loading fails.
  Future<void> _loadSavedSongs() async {
    setState(() {
      _isLoading = true; // Set loading state to true.
      _statusMessage = 'Loading saved songs...'; // Update status message.
    });
    try {
      final songs = await _localStorageService.getSavedSongs(); // Fetch songs from storage.
      setState(() {
        _savedSongs = songs; // Update the list of saved songs.
        _isLoading = false; // Turn off loading indicator.
        // Set status message based on whether songs were found.
        _statusMessage = songs.isEmpty ? 'No saved songs yet.' : '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false; // Turn off loading indicator even on error.
        _statusMessage = 'Error loading songs: $e'; // Display error message.
      });
      // Show a SnackBar to the user if loading fails.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load saved songs: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError), // Text color for error.
            ),
            backgroundColor: Theme.of(context).colorScheme.error, // Error background color.
          ),
        );
      }
    }
  }

  /// Deletes a specific song from the saved list and its corresponding audio file
  /// from local storage.
  ///
  /// A confirmation dialog is displayed to the user before proceeding with deletion.
  ///
  /// Parameters:
  /// - [songId]: The unique identifier of the song to be deleted.
  /// - [songTitle]: The title of the song, used in the confirmation dialog for clarity.
  Future<void> _deleteSong(String songId, String songTitle) async {
    // Access theme colors for consistent dialog styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Show a confirmation dialog to prevent accidental deletions.
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface, // Themed dialog background.
          title: Text(
            'Confirm Deletion',
            style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface), // Themed title color.
          ),
          content: Text(
            'Are you sure you want to delete "$songTitle"? This cannot be undone.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface), // Themed content text color.
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // User cancels deletion.
              child: Text(
                'Cancel',
                style: textTheme.labelLarge?.copyWith(color: colorScheme.primary), // Themed primary color for cancel.
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // User confirms deletion.
              child: Text(
                'Delete',
                style: textTheme.labelLarge?.copyWith(color: Colors.red), // Functional red for delete action.
              ),
            ),
          ],
        );
      },
    );

    // Proceed with deletion only if the user confirmed.
    if (confirmDelete == true) {
      setState(() {
        _isLoading = true; // Set loading state for deletion.
        _statusMessage = 'Deleting "$songTitle"...'; // Update status message.
      });
      try {
        await _localStorageService.deleteSong(songId); // Call service to delete song.
        await _loadSavedSongs(); // Reload the list to reflect the deletion.
        // Show a success SnackBar.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Song "$songTitle" deleted successfully!',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), // Text color for success.
              ),
              backgroundColor: Theme.of(context).colorScheme.primary, // Success background color.
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false; // Turn off loading indicator.
          _statusMessage = 'Error deleting "$songTitle": $e'; // Display error message.
        });
        // Show an error SnackBar.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete song: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.onError), // Text color for error.
              ),
              backgroundColor: Theme.of(context).colorScheme.error, // Error background color.
            ),
          );
        }
      }
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
      //     'Saved Songs',
      //     style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      //   ),
      //   backgroundColor: colorScheme.surface,
      //   elevation: 0,
      // ),
      body: _isLoading
          ? Center(
        // Display a loading indicator and status message while loading songs.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary), // Themed primary color.
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())), // Muted text color.
            ),
          ],
        ),
      )
          : _savedSongs.isEmpty
          ? Center(
        // Display a "No saved songs yet" message if the list is empty.
        child: Text(
          _statusMessage,
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.5).round())), // Muted text color.
          textAlign: TextAlign.center,
        ),
      )
          : RefreshIndicator(
        // Allows users to pull down to refresh the list of songs.
        onRefresh: _loadSavedSongs, // Callback to reload songs on refresh.
        color: colorScheme.primary, // Themed primary color for the indicator.
        backgroundColor: colorScheme.surface, // Themed surface color for indicator background.
        child: ListView.builder(
          itemCount: _savedSongs.length, // Number of items in the list.
          itemBuilder: (context, index) {
            final song = _savedSongs[index]; // Get the current song object.
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              elevation: 2, // Subtle shadow for cards.
              color: colorScheme.surfaceContainerHighest, // Themed background for cards.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Rounded corners for cards.
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                title: Text(
                  song.title, // Display song title.
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface, // Themed text color.
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${song.chordData.length} chords detected', // Display number of chords.
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())), // Muted text color.
                    ),
                    Text(
                      'Saved: ${song.savedAt.toLocal().toString().split('.')[0]}', // Display saved date/time.
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.5).round())), // Muted text color.
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete), // Delete icon.
                  color: colorScheme.error, // Themed error color for the icon.
                  onPressed: () => _deleteSong(song.id, song.title), // Callback for delete button.
                ),
                onTap: () {
                  // Navigate to the SongPlaybackScreen when a song is tapped.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongPlaybackScreen(savedSong: song),
                    ),
                  ).then((_) {
                    // Optional: Reload songs when returning from the playback screen
                    // to ensure the list is up-to-date (e.g., if a song was deleted from playback screen).
                    _loadSavedSongs();
                  });
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// lib/screens/song_playback_screen.dart

// This file defines the SongPlaybackScreen, a dedicated user interface
// within the StrumSure application for playing back a saved audio recording
// and visually synchronizing its playback with the previously detected chords.
// It provides audio controls and highlights the active chord in real-time.

import 'package:flutter/material.dart'; // Core Flutter UI components.
import 'package:just_audio/just_audio.dart'; // Primary library for robust audio playback.
import 'package:strum_sure/models/saved_song.dart'; // Imports the SavedSong data model.
import 'dart:async'; // For managing StreamSubscription.
import 'dart:io' show Platform; // For platform detection (e.g., Android, iOS, Windows).
import 'package:flutter/foundation.dart' show kIsWeb; // For web platform detection.

/// A screen for playing a saved song and visualizing its detected chords in sync.
///
/// This screen displays:
/// - The currently active chord (highlighted).
/// - Audio playback controls (play, pause, seek).
/// - A progress slider and time display for the audio.
/// - A scrollable list of all detected chords for the song, with the active chord highlighted.
/// - Handles platform compatibility for audio playback (e.g., limited support on Web/Windows).
class SongPlaybackScreen extends StatefulWidget {
  /// The [SavedSong] object containing the audio file path and chord data
  /// that will be played and visualized on this screen.
  final SavedSong savedSong;

  /// Constructs a [SongPlaybackScreen] widget.
  ///
  /// Parameters:
  /// - `savedSong`: The [SavedSong] object to be played.
  const SongPlaybackScreen({super.key, required this.savedSong});

  @override
  State<SongPlaybackScreen> createState() => _SongPlaybackScreenState();
}

/// The state class for [SongPlaybackScreen].
///
/// It manages the audio player's state, playback position, active chord highlighting,
/// and scrolling within the chord list.
class _SongPlaybackScreenState extends State<SongPlaybackScreen> {
  late AudioPlayer _audioPlayer; // The audio player instance from `just_audio`.
  bool _isPlaybackSupported = true; // Flag to indicate if audio playback is supported on the current platform.

  PlayerState? _playerState; // The current state of the audio player (e.g., playing, paused, completed).
  Duration? _duration; // The total duration of the loaded audio file.
  Duration _position = Duration.zero; // The current playback position of the audio.
  StreamSubscription? _playerStateSubscription; // Subscription to the audio player's state changes.
  StreamSubscription? _positionSubscription; // Subscription to the audio player's position changes.

  ChordData? _currentChord; // The [ChordData] object that is currently active based on playback position.

  /// A constant defining a "look-ahead" time (in milliseconds) for chord display.
  /// The next chord will be highlighted this many milliseconds *before* its actual start time,
  /// providing a smoother visual transition for the user.
  static const int _chordLookAheadMs = 500;

  late ScrollController _scrollController; // Controller for the ListView.builder to enable programmatic scrolling.
  /// A map to store [GlobalKey]s for each [ChordData] item in the list.
  /// This allows programmatic scrolling to a specific chord card when it becomes active.
  final Map<ChordData, GlobalKey> _chordKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(); // Initialize the scroll controller.

    // Initialize a unique GlobalKey for each chord data item.
    // This key will be assigned to the corresponding Card in the ListView.
    for (var chord in widget.savedSong.chordData) {
      _chordKeys[chord] = GlobalKey();
    }

    // Check platform support for audio playback.
    // `just_audio` has known limitations on Web and Windows for local file playback.
    if (kIsWeb || Platform.isWindows) {
      _isPlaybackSupported = false;
      debugPrint('Audio playback for local files is not fully supported on this platform (Web/Windows).');
      // Initialize a dummy AudioPlayer to satisfy the `late` keyword requirement,
      // but it will not be used for actual playback.
      _audioPlayer = AudioPlayer();
    } else {
      _audioPlayer = AudioPlayer(); // Initialize AudioPlayer only if playback is supported.
      _initAudioPlayer(); // Proceed with full audio player initialization.
    }
  }

  /// Initializes the audio player, loads the audio file, and sets up stream listeners.
  ///
  /// This method is called only if audio playback is determined to be supported
  /// on the current platform. It handles loading the audio from the saved path
  /// and subscribing to playback state and position changes.
  Future<void> _initAudioPlayer() async {
    // Skip initialization if playback is not supported on this platform.
    if (!_isPlaybackSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Audio playback is not supported on this platform.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      // Load the audio file from the locally saved file path.
      _duration = await _audioPlayer.setFilePath(widget.savedSong.audioFilePath);
      debugPrint('Audio loaded: ${widget.savedSong.audioFilePath}, Duration: $_duration');

      // Listen to changes in the audio player's state (e.g., playing, paused, completed).
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        setState(() {
          _playerState = state;
        });
        // When playback completes, reset the position and current chord.
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _position = Duration.zero;
            _currentChord = null;
          });
        }
      });

      // Listen to changes in the audio player's current playback position.
      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        setState(() {
          _position = position;
          _updateCurrentChord(position); // Update the displayed chord and trigger scrolling.
        });
      });
    } catch (e) {
      debugPrint('Error loading audio: $e');
      // Show a SnackBar to the user if there's an error loading the audio.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading audio: ${e.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      // Consider more robust error handling, like navigating back or showing a persistent error UI.
    }
  }

  /// Updates the [_currentChord] based on the current playback [position].
  ///
  /// This method iterates through the song's chord data to find which chord
  /// should be active at the given playback time, considering a `_chordLookAheadMs`
  /// to highlight the chord slightly before its actual start.
  ///
  /// Parameters:
  /// - `position`: The current playback [Duration] of the audio.
  void _updateCurrentChord(Duration position) {
    // Calculate the effective playback time by adding the look-ahead duration.
    final double effectiveCurrentSeconds = (position.inMilliseconds + _chordLookAheadMs) / 1000.0;
    ChordData? foundChord;

    // Iterate through all chords to find the one that spans the effective current time.
    for (var chord in widget.savedSong.chordData) {
      // A chord is considered "found" if the effective time is greater than or equal to
      // its start time AND less than its end time.
      if (effectiveCurrentSeconds >= chord.startTime && effectiveCurrentSeconds < chord.endTime) {
        foundChord = chord;
        break; // Once found, no need to check further.
      }
    }

    // Only update the state and trigger a scroll if the active chord has actually changed.
    if (foundChord != _currentChord) {
      setState(() {
        _currentChord = foundChord; // Update the active chord.
      });
      // If a new active chord is found, trigger scrolling to make its card visible.
      if (_currentChord != null) {
        _scrollToActiveChord(_currentChord!);
      }
    }
  }

  /// Scrolls the [ListView] of chords to make the currently active chord visible.
  ///
  /// This provides a synchronized visual experience, ensuring the user can
  /// always see the chord being played.
  ///
  /// Parameters:
  /// - [chordToScroll]: The [ChordData] object that is currently active and needs to be scrolled into view.
  void _scrollToActiveChord(ChordData chordToScroll) {
    // Retrieve the GlobalKey associated with the chord's Card widget.
    final key = _chordKeys[chordToScroll];
    if (key != null && key.currentContext != null) {
      // Use `Scrollable.ensureVisible` for smooth, animated scrolling.
      Scrollable.ensureVisible(
        key.currentContext!, // The context of the widget to make visible.
        duration: const Duration(milliseconds: 500), // Duration of the scroll animation.
        alignment: 0.5, // Centers the item in the viewport.
        curve: Curves.easeOut, // Animation curve for a smooth deceleration.
      );
    }
  }

  /// Plays the loaded audio.
  /// This method is conditionally executed only if playback is supported.
  Future<void> _play() async {
    if (_isPlaybackSupported) {
      await _audioPlayer.play();
    }
  }

  /// Pauses the audio playback.
  /// This method is conditionally executed only if playback is supported.
  Future<void> _pause() async {
    if (_isPlaybackSupported) {
      await _audioPlayer.pause();
    }
  }

  /// Seeks to a specific position in the audio.
  /// This method is conditionally executed only if playback is supported.
  ///
  /// Parameters:
  /// - [position]: The [Duration] to seek to.
  Future<void> _seek(Duration position) async {
    if (_isPlaybackSupported) {
      await _audioPlayer.seek(position);
    }
  }

  /// Formats a [Duration] object into a human-readable "MM:SS" string.
  ///
  /// Parameters:
  /// - [d]: The [Duration] to format.
  ///
  /// Returns:
  /// - A [String] representing the formatted duration.
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0"); // Helper for two-digit formatting.
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    // Only dispose audio player and subscriptions if playback was supported and initialized.
    if (_isPlaybackSupported) {
      _playerStateSubscription?.cancel(); // Cancel player state stream subscription.
      _positionSubscription?.cancel(); // Cancel position stream subscription.
      _audioPlayer.dispose(); // Dispose the audio player to release resources.
    }
    _scrollController.dispose(); // Dispose the scroll controller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the current theme's color scheme and text theme for consistent styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Determine current player state for UI updates.
    final bool isPlaying = _playerState?.playing ?? false; // True if audio is playing.
    final bool isLoading = _playerState?.processingState == ProcessingState.loading ||
        _playerState?.processingState == ProcessingState.buffering; // True if audio is loading/buffering.

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.savedSong.title, // Display the title of the saved song.
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface), // Themed title color.
        ),
        backgroundColor: colorScheme.surface, // Themed app bar background.
        foregroundColor: colorScheme.onSurface, // Themed text/icon color for app bar.
        elevation: 4, // Subtle shadow for the app bar.
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Padding around the main content.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally.
          children: [
            // --- Current Chord Display ---
            // This section displays the large, currently active chord.
            Expanded(
              flex: 2, // Takes up 2 parts of the available vertical space.
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown, // Ensures the chord text scales down if too large.
                      child: Text(
                        _currentChord?.chord ?? 'No Chord', // Display the chord name or "No Chord".
                        style: textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          // Highlight active chord with primary color, otherwise muted.
                          color: _currentChord != null ? colorScheme.primary : colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_currentChord != null) // Only display notes if a chord is active.
                      Text(
                        _currentChord!.detectedNotes.join(', '), // Display the notes within the chord.
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface.withAlpha((255 * 0.7).round()), // Muted text color.
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),

            // --- Audio Player Controls ---
            // Conditionally displays playback controls or a message if playback is not supported.
            _isPlaybackSupported
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: colorScheme.surface, // Themed surface color for controls container.
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Play/Pause Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 64.0, // Large icon size for easy tapping.
                        icon: isLoading
                            ? CircularProgressIndicator(color: colorScheme.primary) // Loading indicator.
                            : (isPlaying ? const Icon(Icons.pause_circle_filled) : const Icon(Icons.play_circle_filled)), // Play/Pause icon.
                        onPressed: isLoading
                            ? null // Disable button if loading.
                            : () {
                          if (isPlaying) {
                            _pause();
                          } else {
                            _play();
                          }
                        },
                        color: colorScheme.primary, // Themed primary color for the icon.
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  // Progress Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0), // Smaller thumb.
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0), // Larger tap area.
                      activeTrackColor: colorScheme.primary, // Themed primary color for active track.
                      inactiveTrackColor: colorScheme.surfaceContainerHighest, // Themed background for inactive track.
                      thumbColor: colorScheme.onPrimary, // Themed thumb color.
                      overlayColor: colorScheme.primary.withAlpha((255 * 0.2).round()), // Themed overlay color with opacity.
                    ),
                    child: Slider(
                      min: 0.0,
                      max: _duration?.inMilliseconds.toDouble() ?? 0.0, // Max value is total duration.
                      value: _position.inMilliseconds.toDouble().clamp(0.0, _duration?.inMilliseconds.toDouble() ?? 0.0), // Current position.
                      onChanged: (value) {
                        _seek(Duration(milliseconds: value.toInt())); // Seek on slider change.
                      },
                    ),
                  ),
                  // Time display (Current Position / Total Duration)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position), // Formatted current position.
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())), // Muted text color.
                        ),
                        Text(
                          _formatDuration(_duration ?? Duration.zero), // Formatted total duration.
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())), // Muted text color.
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                : Card( // Display a warning message if audio playback is not supported.
              color: colorScheme.surface,
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber, color: colorScheme.error, size: 40), // Warning icon.
                    const SizedBox(height: 10),
                    Text(
                      'Audio playback is not supported on this platform (e.g., Windows, Web).',
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Chords are still displayed below.', // Inform user that chords are still visible.
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // --- List of All Chords (Scrollable) ---
            // This section displays all detected chords for the song,
            // with the currently active chord highlighted and scrolled into view.
            Expanded(
              flex: 3, // Takes up 3 parts of the available vertical space.
              child: ListView.builder(
                controller: _scrollController, // Assign the scroll controller for programmatic scrolling.
                itemCount: widget.savedSong.chordData.length,
                itemBuilder: (context, index) {
                  final chord = widget.savedSong.chordData[index];
                  final bool isActive = chord == _currentChord; // Check if this chord is currently active.
                  return Card(
                    key: _chordKeys[chord], // Assign the GlobalKey to this card for scrolling.
                    // Dynamic background color: muted primary for active, surface variant for others.
                    color: isActive ? colorScheme.primary.withAlpha((255 * 0.2).round()) : colorScheme.surfaceContainerHighest,
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    elevation: isActive ? 4 : 2, // Higher elevation for active card.
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      // Primary color border for active card.
                      side: isActive ? BorderSide(color: colorScheme.primary, width: 2) : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Display time range (e.g., "00:00 - 00:03").
                            '${_formatDuration(Duration(milliseconds: (chord.startTime * 1000).toInt()))} - '
                                '${_formatDuration(Duration(milliseconds: (chord.endTime * 1000).toInt()))}:',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              // Text color adapts to card background.
                              color: isActive ? colorScheme.onPrimary : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chord: ${chord.chord}', // Display the chord name.
                            style: textTheme.titleSmall?.copyWith(
                              fontSize: 16,
                              // Highlight chord text with primary color if active.
                              color: isActive ? colorScheme.primary : colorScheme.primary.withAlpha((255 * 0.7).round()),
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            'Notes: ${chord.detectedNotes.join(', ')}', // Display the detected notes.
                            style: textTheme.bodySmall?.copyWith(
                              // Muted text color, adapts to card background.
                              color: isActive ? colorScheme.onPrimary.withAlpha((255 * 0.7).round()) : colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                            ),
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

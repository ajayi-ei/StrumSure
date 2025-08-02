// lib/widgets/guitar_string_selector.dart

// This file defines the GuitarStringSelector widget, a UI component
// that allows users to manually select a guitar string (note) as their
// tuning target within the StrumSure application.

import 'package:flutter/material.dart'; // Core Flutter UI components and Material Design.

/// A widget that provides a row of interactive buttons for selecting standard guitar strings.
///
/// This selector is used in the manual tuning mode to allow the user to
/// explicitly choose which string they are currently tuning.
class GuitarStringSelector extends StatelessWidget {
  /// The currently selected musical note (e.g., 'E4', 'A2').
  /// This determines which button is highlighted.
  final String selectedNote;

  /// A callback function invoked when a new note button is tapped.
  /// It receives the `note` (String) of the selected button.
  final Function(String) onNoteSelected;

  /// Constructs a [GuitarStringSelector] widget.
  ///
  /// Parameters:
  /// - `selectedNote`: The note currently highlighted as selected.
  /// - `onNoteSelected`: Callback for when a note button is tapped.
  const GuitarStringSelector({
    super.key,
    required this.selectedNote,
    required this.onNoteSelected,
  });

  /// A static list representing the standard E Standard guitar tuning.
  /// These are the notes (and their octaves) for the six strings of a guitar,
  /// from the thickest (low E) to the thinnest (high E).
  static const List<String> standardTuning = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];

  @override
  Widget build(BuildContext context) {
    // Access the current theme's color scheme and text theme for consistent styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // External spacing around the selector.
      padding: const EdgeInsets.all(15), // Internal padding for content within the container.
      decoration: BoxDecoration(
        color: colorScheme.surface, // Background color of the selector container, derived from theme.
        borderRadius: BorderRadius.circular(12), // Rounded corners for the container.
        border: Border.all(color: colorScheme.outline), // Border color derived from theme.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Aligns content to the start (left).
        children: [
          Text(
            'Guitar Strings', // Title for the string selection section.
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface, // Text color on the surface background.
            ),
          ),
          const SizedBox(height: 10), // Vertical spacing between title and buttons.
          SizedBox(
            width: double.infinity, // Ensures the Row takes up full available width.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distributes buttons evenly.
              children: standardTuning.map((note) {
                final isSelected = note == selectedNote; // Check if the current note is selected.
                return Flexible(
                  // Flexible allows the buttons to share available space.
                  child: GestureDetector(
                    onTap: () => onNoteSelected(note), // Callback when a button is tapped.
                    child: Container(
                      width: 48, // Fixed width for each circular button.
                      height: 48, // Fixed height for each circular button.
                      decoration: BoxDecoration(
                        // Dynamic background color based on selection state.
                        color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24), // Makes the container circular (half of width/height).
                        border: Border.all(
                          // Dynamic border color based on selection state.
                          color: isSelected ? colorScheme.primary : colorScheme.outline,
                          width: 2, // Thickness of the border.
                        ),
                      ),
                      child: Center(
                        child: Text(
                          note, // Display the note name (e.g., "E2").
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            // Dynamic text color for contrast with button background.
                            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(), // Convert the iterable of widgets to a List.
            ),
          ),
        ],
      ),
    );
  }
}

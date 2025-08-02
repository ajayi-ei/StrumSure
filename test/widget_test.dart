// test/widget_test.dart

// This file contains a suite of basic Flutter widget tests for the StrumSure application.
// Widget tests are used to verify the behavior and rendering of individual widgets
// or small widget trees, simulating user interactions and checking the UI state.

import 'package:flutter/material.dart'; // Core Flutter UI components.
import 'package:flutter_test/flutter_test.dart'; // Flutter's testing utility.

import 'package:strum_sure/main.dart'; // Import the main application entry point (StrumSureApp).

/// Main function to define and run the widget test suite.
void main() {
  // Group related tests for the StrumSureApp for better organization and reporting.
  group('StrumSureApp Widget Tests', () {
    /// Test case: Verifies that the application starts with the correct initial message.
    testWidgets('App starts with "Tap \'Start\' to Tune" message', (WidgetTester tester) async {
      // Build the StrumSureApp widget and trigger an initial frame.
      // `tester.pumpWidget()` renders the widget tree.
      await tester.pumpWidget(const StrumSureApp());

      // Verify that the instructional message "Tap 'Start' to Tune" is displayed.
      // `findsOneWidget` asserts that exactly one widget matching the text is found.
      expect(find.text("Tap 'Start' to Tune"), findsOneWidget);

      // Verify the initial state of the tuning buttons:
      // The "Start Tuning" button should be present.
      expect(find.text("Start Tuning"), findsOneWidget);
      // The "Stop Tuning" button should NOT be present initially.
      expect(find.text("Stop Tuning"), findsNothing);
    });

    /// Test case: Verifies that tapping the "Start Tuning" button correctly
    /// activates the tuning process and updates the UI.
    testWidgets('Tapping Start Tuning button activates tuning and shows "Target: E4"', (WidgetTester tester) async {
      await tester.pumpWidget(const StrumSureApp());

      // Simulate a tap on the "Start Tuning" button.
      // `find.widgetWithText(ElevatedButton, 'Start Tuning')` finds an ElevatedButton containing the specified text.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Tuning'));
      // `tester.pump()` rebuilds the widget tree after the tap, allowing state changes to propagate.
      await tester.pump();

      // Verify that the target note display changes, indicating tuning is active.
      // `find.textContaining()` is used as the text includes dynamic frequency.
      expect(find.textContaining('Target: E4'), findsOneWidget);
      // After starting, the "Start Tuning" button should no longer be visible (it becomes disabled or changes).
      expect(find.text("Start Tuning"), findsNothing);
      // The "Stop Tuning" button should now be visible.
      expect(find.text("Stop Tuning"), findsOneWidget);
    });

    /// Test case: Verifies that tapping different guitar string buttons
    /// correctly changes the target note displayed on the tuner.
    testWidgets('Tapping a string button changes the target note', (WidgetTester tester) async {
      await tester.pumpWidget(const StrumSureApp());

      // First, simulate tapping "Start Tuning" to make the tuner active
      // and enable interaction with the string selection buttons.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Tuning'));
      await tester.pump(); // Rebuild to reflect the tuning active state.

      // Verify that the initial target note is E4 (the default).
      expect(find.textContaining('Target: E4'), findsOneWidget);

      // Simulate a tap on the button for the 'A' string.
      // Note: This finds the button by its displayed text, which is 'A' for 'A2'.
      await tester.tap(find.widgetWithText(GestureDetector, 'A')); // Use GestureDetector as it wraps the note buttons.
      await tester.pump(); // Rebuild after tap.

      // Verify that the target note has successfully changed to A2.
      expect(find.textContaining('Target: A2'), findsOneWidget);
      // Ensure the old target note (E4) is no longer displayed as the primary target.
      expect(find.textContaining('Target: E4'), findsNothing);

      // Simulate a tap on the button for the 'D' string.
      await tester.tap(find.widgetWithText(GestureDetector, 'D'));
      await tester.pump();

      // Verify that the target note has now changed to D3.
      expect(find.textContaining('Target: D3'), findsOneWidget);
      // Ensure the previous target note (A2) is no longer displayed.
      expect(find.textContaining('Target: A2'), findsNothing);
    });

    /// Test case: Verifies that tapping the "Stop Tuning" button correctly
    /// deactivates the tuning process and resets the UI messages.
    testWidgets('Tapping Stop Tuning button deactivates tuning and resets message', (WidgetTester tester) async {
      await tester.pumpWidget(const StrumSureApp());

      // First, simulate starting the tuning process to get into an active state.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Tuning'));
      await tester.pump();

      // Verify that tuning is active by checking for the target note display.
      expect(find.textContaining('Target: E4'), findsOneWidget);

      // Simulate a tap on the "Stop Tuning" button.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Tuning'));
      await tester.pump(); // Rebuild after stopping.

      // Verify that the status message reverts to the initial "Tap 'Start' to Tune".
      expect(find.text("Tap 'Start' to Tune"), findsOneWidget);
      // The "Start Tuning" button should reappear.
      expect(find.text("Start Tuning"), findsOneWidget);
      // The "Stop Tuning" button should no longer be visible.
      expect(find.text("Stop Tuning"), findsNothing);
    });

    // Additional, more advanced tests could include:
    // - Verifying the display of detected note/frequency when tuning is active.
    // - Testing the `CircularTuner`'s visual changes based on cents deviation.
    // - Testing the `FrequencyGraph` updates, though this is more complex due to custom painting.
    // - Testing the auto-tuning mode toggle and its effect on string selection.
    // - Testing navigation between different tabs (Tuner, Chord Detector, Saved Songs, ESP32 Tuner).
    // - Testing theme switching functionality.
  });
}

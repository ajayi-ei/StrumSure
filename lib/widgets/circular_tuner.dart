// lib/widgets/circular_tuner.dart

// This file defines the CircularTuner widget, a custom-drawn UI component
// used in the StrumSure application to visually represent the real-time
// cents deviation of a detected musical note from its target frequency.
// It provides intuitive visual feedback for guitar tuning.

import 'package:flutter/material.dart'; // Core Flutter UI components.
import 'dart:math' as math; // For mathematical operations like `min` and `cos/sin`.

/// A circular UI widget that visually represents the cents deviation from the target note.
///
/// This widget dynamically changes its appearance (e.g., pointer position and color)
/// based on the `centsDeviation` to guide the user during guitar tuning.
class CircularTuner extends StatelessWidget {
  /// The deviation of the detected frequency from the target frequency, measured in cents.
  /// A value of 0 indicates perfect tune. Positive values are sharp, negative values are flat.
  final double centsDeviation;

  /// The name of the detected musical note (e.g., "A4", "E2").
  /// This property is passed but not directly used within this widget's `build` method
  /// for display, as the primary visual feedback is based on `centsDeviation`.
  final String detectedNoteName;

  /// The raw frequency (in Hz) detected from the microphone.
  /// This property is passed but not directly used within this widget's `build` method
  /// for display, as the primary visual feedback is based on `centsDeviation`.
  final double detectedFrequency;

  /// A boolean flag indicating whether the microphone is actively listening for sound.
  /// The tuner's visual elements (pointer, status text) are only displayed when `isListening` is true.
  final bool isListening;

  /// Constructs a [CircularTuner] widget.
  ///
  /// Parameters:
  /// - `centsDeviation`: The current cents deviation from the target note.
  /// - `detectedNoteName`: The name of the detected note.
  /// - `detectedFrequency`: The frequency of the detected note.
  /// - `isListening`: A flag indicating if the tuner is actively listening.
  const CircularTuner({
    super.key,
    required this.centsDeviation,
    required this.detectedNoteName,
    required this.detectedFrequency,
    required this.isListening,
  });

  /// Determines the color for visual feedback based on the `centsDeviation`.
  ///
  /// This method provides a clear color-coded indication of tuning accuracy:
  /// - Calm Teal (0xFF00A39A): When the deviation is less than 5 cents (in-tune).
  /// - Amber (0xFFFFC107): When the deviation is between 5 and 15 cents (slightly off).
  /// - Alert Red (0xFFF44336): When the deviation is greater than 15 cents (far off).
  ///
  /// Parameters:
  /// - `cents`: The cents deviation value.
  ///
  /// Returns:
  /// - A [Color] representing the tuning accuracy.
  Color _getCentsColor(double cents) {
    if (cents.abs() < 5) {
      return const Color(0xFF00A39A); // Primary Accent (Calm Teal) - In tune
    } else if (cents.abs() < 15) {
      return const Color(0xFFFFC107); // Amber-like - Slightly off
    } else {
      return const Color(0xFFF44336); // Alert Red - Far off
    }
  }

  /// Provides a textual status message based on the `centsDeviation`.
  ///
  /// This message guides the user on whether the note is "IN TUNE!", "TOO LOW!",
  /// or "TOO HIGH!". It only shows a message when the tuner is actively listening.
  ///
  /// Parameters:
  /// - `cents`: The cents deviation value.
  ///
  /// Returns:
  /// - A [String] representing the tuning status, or an empty string if not listening.
  String _getTuneStatus(double cents) {
    if (!isListening) return ''; // No status message if not listening.
    if (cents.abs() < 5) {
      return 'IN TUNE!';
    } else if (cents < -5) {
      return 'TOO LOW!';
    } else {
      return 'TOO HIGH!';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the current theme's text theme and color scheme for consistent styling.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return CustomPaint(
      // The CustomPaint widget uses a custom painter to draw the circular tuner.
      painter: _CircularTunerPainter(
        centsDeviation: centsDeviation,
        isListening: isListening,
        // Pass theme colors to the painter for consistent theming.
        // `surfaceContainerHighest` is used for the background arc, providing a subtle contrast.
        backgroundColor: colorScheme.surfaceContainerHighest,
        // The pointer's color is dynamically determined by tuning accuracy.
        pointerColor: _getCentsColor(centsDeviation),
        // Text colors are derived from the theme's `onSurface` for good contrast.
        textColor: colorScheme.onSurface,
        secondaryTextColor: colorScheme.onSurface.withAlpha((255 * 0.7).round()), // 70% opacity for secondary text.
      ),
      child: Center(
        child: Column(
          // Aligns the content (e.g., "IN TUNE!" message) to the bottom of the circular tuner area.
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Only display the tune status message when the tuner is actively listening.
            if (isListening) ...[
              FittedBox(
                fit: BoxFit.scaleDown, // Ensures text scales down to fit if too long.
                child: Text(
                  _getTuneStatus(centsDeviation), // Display the tuning status.
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getCentsColor(centsDeviation), // Color-coded based on tuning accuracy.
                  ),
                ),
              ),
              const SizedBox(height: 20), // Provides vertical spacing from the bottom edge.
            ],
          ],
        ),
      ),
    );
  }
}

/// A custom painter class responsible for drawing the visual elements of the circular tuner.
///
/// This painter draws the background arc, the progress arc, the central pointer,
/// and the cents deviation bubble, all dynamically adjusted based on the current
/// tuning state.
class _CircularTunerPainter extends CustomPainter {
  final double centsDeviation;
  final bool isListening;
  final Color backgroundColor;
  final Color pointerColor;
  final Color textColor;
  final Color secondaryTextColor; // Used for consistency, though not explicitly used in this painter's text.

  /// Constructs a [_CircularTunerPainter] with required drawing parameters.
  _CircularTunerPainter({
    required this.centsDeviation,
    required this.isListening,
    required this.backgroundColor,
    required this.pointerColor,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(centerX, centerY) * 0.8; // Radius of the circular tuner.

    // --- Background Arc ---
    // Draws the static background arc of the tuner gauge.
    final Paint backgroundArcPaint = Paint()
      ..color = backgroundColor // Themed background color for the arc.
      ..strokeWidth = 10 // Thickness of the arc.
      ..style = PaintingStyle.stroke // Draw only the outline.
      ..strokeCap = StrokeCap.round; // Rounded ends for the arc.

    const double startAngle = math.pi * 0.75; // Starting angle (135 degrees).
    const double sweepAngle = math.pi * 1.5; // Total sweep angle (270 degrees).

    final Rect rect = Rect.fromCircle(center: Offset(centerX, centerY), radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, backgroundArcPaint);

    // --- Progress Arc (Gradient) ---
    // Draws a colored arc that visually represents the range of tuning,
    // with a gradient from red (flat) to green (in-tune) to red (sharp).
    final Paint progressPaint = Paint()
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF44336), // Alert Red (far flat)
          Color(0xFFFFC107), // Amber-like (slightly flat)
          Color(0xFF00A39A), // Primary Accent (Calm Teal) (in-tune)
          Color(0xFFFFC107), // Amber-like (slightly sharp)
          Color(0xFFF44336), // Alert Red (far sharp)
        ],
        stops: [0.0, 0.4, 0.5, 0.6, 1.0], // Defines the position of each color in the gradient.
      ).createShader(rect); // Creates a shader that applies the gradient across the arc's bounding box.

    // Only draw the progress arc if the tuner is actively listening.
    if (isListening) {
      // Normalize cents deviation from -50 to +50 to a 0.0 to 1.0 range.
      final double normalizedCents = (centsDeviation.clamp(-50.0, 50.0) + 50.0) / 100.0;
      // Calculate the sweep angle for the progress arc based on normalized cents.
      final double currentSweep = sweepAngle * normalizedCents;
      canvas.drawArc(rect, startAngle, currentSweep, false, progressPaint);
    }

    // --- Pointer and Cents Bubble ---
    // These elements provide precise feedback on the current tuning state.
    if (isListening) {
      // Paint for the pointer line.
      final Paint pointerLinePaint = Paint()
        ..color = textColor // Uses the theme's primary text color for visibility.
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Paint for the central pointer circle.
      final Paint pointerCirclePaint = Paint()
        ..color = pointerColor // Dynamically colored based on tuning accuracy.
        ..style = PaintingStyle.fill;

      // Calculate the angle for the pointer based on normalized cents deviation.
      final double pointerAngle = startAngle + (centsDeviation.clamp(-50.0, 50.0) + 50.0) / 100.0 * sweepAngle;
      final double pointerLength = radius * 0.8; // Length of the pointer line.

      // Calculate the coordinates of the pointer's tip.
      final double tipX = centerX + pointerLength * math.cos(pointerAngle);
      final double tipY = centerY + pointerLength * math.sin(pointerAngle);

      // Draw the central circle of the pointer.
      canvas.drawCircle(Offset(centerX, centerY), 10, pointerCirclePaint);

      // Draw the line from the center to the pointer's tip.
      canvas.drawLine(Offset(centerX, centerY), Offset(tipX, tipY), pointerLinePaint);

      // --- Cents Deviation Text Bubble ---
      // Displays the exact cents deviation value in a small bubble.
      final textPainter = TextPainter(
        text: TextSpan(
          text: centsDeviation.toStringAsFixed(0), // Display cents as a whole number.
          style: TextStyle( // Themed text style for the cents bubble.
            color: textColor, // Ensures good contrast with the bubble's background.
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr, // Required for text layout.
      );
      textPainter.layout(); // Calculate the size of the text.

      const double bubblePadding = 8.0; // Padding inside the bubble.
      final double bubbleWidth = textPainter.width + bubblePadding * 2;
      final double bubbleHeight = textPainter.height + bubblePadding * 2;

      // Position the bubble slightly above the center of the tuner.
      final Offset bubbleCenter = Offset(centerX, centerY - 20 - bubbleHeight / 2);
      final RRect bubbleRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: bubbleCenter, width: bubbleWidth, height: bubbleHeight),
        const Radius.circular(8), // Rounded corners for the bubble.
      );

      final Paint bubblePaint = Paint()..color = pointerColor; // Bubble color matches pointer color.
      canvas.drawRRect(bubbleRect, bubblePaint); // Draw the rounded rectangle bubble.

      // --- Bubble Tail ---
      // Draws a small triangular tail connecting the bubble to the center.
      final Path tailPath = Path()
        ..moveTo(centerX, centerY) // Tail starts from the center of the tuner.
        ..lineTo(centerX - 5, centerY - 20 - bubbleHeight / 2) // Connects to the bubble's bottom-left corner.
        ..lineTo(centerX + 5, centerY - 20 - bubbleHeight / 2) // Connects to the bubble's bottom-right corner.
        ..close(); // Closes the path to form a triangle.
      canvas.drawPath(tailPath, bubblePaint); // Draw the tail.

      // Paint the cents text inside the bubble.
      textPainter.paint(canvas, bubbleRect.outerRect.topLeft + const Offset(bubblePadding, bubblePadding));
    }
  }

  @override
  /// Determines if the painter needs to repaint.
  ///
  /// This method is optimized to only repaint when relevant properties change,
  /// preventing unnecessary redraws and improving performance.
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Cast the oldDelegate to our specific painter type for property comparison.
    if (oldDelegate is _CircularTunerPainter) {
      return oldDelegate.centsDeviation != centsDeviation ||
          oldDelegate.isListening != isListening ||
          oldDelegate.backgroundColor != backgroundColor ||
          oldDelegate.pointerColor != pointerColor ||
          oldDelegate.textColor != textColor ||
          oldDelegate.secondaryTextColor != secondaryTextColor;
    }
    return true; // Repaint if the old delegate is not of the same type.
  }
}

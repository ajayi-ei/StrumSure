// lib/widgets/frequency_graph.dart

// This file defines the FrequencyGraph widget, a custom UI component
// responsible for visualizing real-time frequency deviation data in a scrolling graph.
// It provides visual feedback on tuning accuracy over time within the StrumSure application.

import 'package:flutter/material.dart'; // Core Flutter UI components and Material Design.
import 'package:strum_sure/state/tuner_data_notifier.dart'; // Imports the FrequencyPoint data model.

/// A widget that displays a real-time, scrolling graph of frequency deviation in cents.
///
/// This graph provides a historical view of tuning accuracy, showing how the
/// detected pitch fluctuates relative to the target note over a short period.
class FrequencyGraph extends StatelessWidget {
  /// A list of [FrequencyPoint] objects representing the data to be plotted on the graph.
  /// This list is typically a rolling window of recent tuning data.
  final List<FrequencyPoint> frequencyData;

  /// A boolean flag indicating whether the tuner is actively listening for audio.
  /// The graph only displays active data when `isListening` is true; otherwise,
  /// it shows a placeholder message.
  final bool isListening;

  /// The maximum number of data points that the graph should display at any given time.
  /// This controls the "length" of the historical data shown.
  final int maxGraphPoints;

  /// Constructs a [FrequencyGraph] widget.
  ///
  /// Parameters:
  /// - `frequencyData`: The list of data points to display.
  /// - `isListening`: Flag indicating active listening state.
  /// - `maxGraphPoints`: The maximum number of points to show on the graph.
  const FrequencyGraph({
    super.key,
    required this.frequencyData,
    required this.isListening,
    required this.maxGraphPoints,
  });

  @override
  Widget build(BuildContext context) {
    // Access the current theme's color scheme and text theme for consistent styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity, // Occupy full available width.
      height: 250, // Fixed height for the graph container.
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // External spacing.
      padding: const EdgeInsets.all(10), // Internal padding for content.
      decoration: BoxDecoration(
        color: colorScheme.surface, // Background color derived from the theme.
        borderRadius: BorderRadius.circular(12), // Rounded corners for the container.
        border: Border.all(color: colorScheme.outline), // Border color derived from the theme.
      ),
      child: CustomPaint(
        // The CustomPaint widget delegates the actual drawing of the graph
        // to the `_FrequencyGraphPainter`.
        painter: _FrequencyGraphPainter(
          frequencyData: frequencyData,
          isListening: isListening,
          maxGraphPoints: maxGraphPoints,
          // Pass theme-derived colors to the painter for consistent visual style.
          gridColor: colorScheme.onSurface.withAlpha((255 * 0.3).round()), // Muted color for grid lines (30% opacity).
          centerLineColor: const Color(0xFF00A39A).withAlpha((255 * 0.8).round()), // Primary accent for center line (80% opacity).
          noDataTextColor: textTheme.bodyMedium?.color?.withAlpha((255 * 0.5).round()) ?? Colors.grey.shade500, // Muted text color for "no data" message.
          labelTextColor: textTheme.bodySmall?.color?.withAlpha((255 * 0.7).round()) ?? Colors.grey.shade400, // Muted text color for axis labels.
        ),
        child: Container(), // A child container is often used with CustomPaint, though it can be empty.
      ),
    );
  }
}

/// A custom painter class responsible for drawing the real-time frequency deviation graph.
///
/// This painter handles drawing the grid lines, the central "in-tune" line,
/// the scrolling data points (with gaps for invalid data), and axis labels.
class _FrequencyGraphPainter extends CustomPainter {
  final List<FrequencyPoint> frequencyData;
  final bool isListening;
  final int maxGraphPoints;
  // Theme-derived colors passed from the parent widget for drawing.
  final Color gridColor;
  final Color centerLineColor;
  final Color noDataTextColor;
  final Color labelTextColor;

  /// Constructs a [_FrequencyGraphPainter] with all required drawing parameters.
  const _FrequencyGraphPainter({
    required this.frequencyData,
    required this.isListening,
    required this.maxGraphPoints,
    required this.gridColor,
    required this.centerLineColor,
    required this.noDataTextColor,
    required this.labelTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // If the tuner is not listening, display a static message.
    if (!isListening) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Start tuning to see graph',
          style: TextStyle(
            color: noDataTextColor, // Themed muted text color for the message.
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(); // Calculate text size.
      // Position the message in the center of the canvas.
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
      return; // Stop painting if not listening.
    }

    // If listening but no data points have arrived yet, show "Listening..." message.
    if (frequencyData.isEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Listening...',
          style: TextStyle(
            color: noDataTextColor, // Themed muted text color for the message.
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(); // Calculate text size.
      // Position the message in the center of the canvas.
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
      return; // Stop painting until data arrives.
    }

    // Paint for drawing grid lines.
    final Paint gridPaint = Paint()
      ..color = gridColor // Themed color for grid lines.
      ..strokeWidth = 1; // Thin lines.

    // Define the range of cents displayed on the graph (e.g., -200 to +200 cents).
    const double graphCentsRange = 200.0;

    // --- Draw Vertical Grid Lines for Cents Markers ---
    // These lines indicate specific cents deviations (e.g., -200¢, -100¢, 0¢, 100¢, 200¢).
    final centsRangeLines = [-200, -100, 0, 100, 200];
    for (final cents in centsRangeLines) {
      // Calculate the X position for each vertical line.
      // It's centered, then offset by the normalized cents deviation across half the width.
      final x = size.width / 2 + (cents / graphCentsRange) * (size.width / 2);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // --- Draw Prominent Center Line (0 cents) ---
    // This line represents perfect tune (0 cents deviation).
    final Paint centerLinePaint = Paint()
      ..color = centerLineColor // Themed functional green color.
      ..strokeWidth = 2; // Thicker than grid lines to stand out.
    canvas.drawLine(
      Offset(size.width / 2, 0), // Start at the center top.
      Offset(size.width / 2, size.height), // End at the center bottom.
      centerLinePaint,
    );

    // --- Draw Frequency Data Line and Points ---
    if (frequencyData.isNotEmpty) {
      final Paint linePaint = Paint()
        ..strokeWidth = 2 // Thickness of the data line.
        ..style = PaintingStyle.stroke // Draw as an outline.
        ..strokeCap = StrokeCap.round; // Rounded ends for line segments.

      // Calculate the vertical step size for each data point.
      // The graph scrolls from top (newest data) to bottom (oldest data).
      final double stepY = size.height / (maxGraphPoints - 1);

      // `validPaths` stores segments of the graph line where data is valid.
      // `currentPath` builds a single segment until a gap (null data) is encountered.
      final List<Path> validPaths = [];
      Path? currentPath;

      // Iterate through data points from newest to oldest to draw from top to bottom.
      for (int i = 0; i < frequencyData.length; i++) {
        final int dataIndex = frequencyData.length - 1 - i; // Index to access points from the end of the queue.
        if (dataIndex < 0) continue; // Safety check.

        final point = frequencyData[dataIndex];
        final y = i * stepY; // Calculate vertical position based on index.

        if (point.hasValidData && point.centsDeviation != null) {
          // Calculate horizontal position based on cents deviation, clamped to graph range.
          final x = size.width / 2 + (point.centsDeviation!.clamp(-graphCentsRange, graphCentsRange) / graphCentsRange) * (size.width / 2);

          if (currentPath == null) {
            // If no path segment is active, start a new one at the current point.
            currentPath = Path();
            currentPath.moveTo(x, y);
          } else {
            // Otherwise, extend the current path segment to the new point.
            currentPath.lineTo(x, y);
          }
        } else {
          // If data is not valid (e.g., silence), break the current path segment.
          if (currentPath != null) {
            validPaths.add(currentPath); // Add the completed segment to the list.
            currentPath = null; // Reset to start a new segment after the gap.
          }
        }
      }

      // Add the last path segment if it's still active after the loop.
      if (currentPath != null) {
        validPaths.add(currentPath);
      }

      // Draw all accumulated valid path segments.
      for (final path in validPaths) {
        // The line color is determined by the color of the most recent valid data point.
        final validPoints = frequencyData.where((p) => p.hasValidData).toList();
        if (validPoints.isNotEmpty) {
          linePaint.color = validPoints.last.color; // Use the functional color from the data point.
        } else {
          linePaint.color = gridColor; // Fallback to grid color if no valid points exist.
        }
        canvas.drawPath(path, linePaint);
      }

      // --- Draw Data Points (Circles) ---
      final Paint pointPaint = Paint()..style = PaintingStyle.fill; // For valid data points.
      final Paint emptyPointPaint = Paint()
        ..style = PaintingStyle.fill // For "empty" data points (to show continuity).
        ..color = centerLineColor.withAlpha((255 * 0.4).round()); // Muted color for empty points.
      const double emptyPointRadius = 0.8; // Small radius for empty points.

      for (int i = 0; i < frequencyData.length; i++) {
        final int dataIndex = frequencyData.length - 1 - i;
        if (dataIndex < 0) continue;

        final point = frequencyData[dataIndex];
        final y = i * stepY;

        if (point.hasValidData && point.centsDeviation != null) {
          // Draw a filled circle for valid data points.
          final x = size.width / 2 + (point.centsDeviation!.clamp(-graphCentsRange, graphCentsRange) / graphCentsRange) * (size.width / 2);
          pointPaint.color = point.color; // Color from the FrequencyPoint.
          canvas.drawCircle(Offset(x, y), 3, pointPaint); // Larger circle for valid points.
        } else {
          // Draw a small, muted circle at the center for "empty" data points,
          // indicating time progression without valid frequency data.
          final x = size.width / 2;
          canvas.drawCircle(Offset(x, y), emptyPointRadius, emptyPointPaint);
        }
      }
    }

    // --- Draw Cents Labels at the Bottom ---
    final textStyle = TextStyle(
      color: labelTextColor, // Themed color for labels.
      fontSize: 12,
    );

    for (final cents in centsRangeLines) {
      final x = size.width / 2 + (cents / graphCentsRange) * (size.width / 2);
      final textPainter = TextPainter(
        text: TextSpan(text: '$cents¢', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(); // Calculate text size.
      // Position labels at the bottom of the graph.
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - textPainter.height - 5));
    }
  }

  @override
  /// Determines if the painter needs to repaint.
  ///
  /// This method is optimized to only repaint when relevant properties change,
  /// preventing unnecessary redraws and improving performance.
  bool shouldRepaint(covariant _FrequencyGraphPainter oldDelegate) {
    // Repaint if the data list itself changes, or if any core display properties change.
    return oldDelegate.frequencyData != frequencyData ||
        oldDelegate.isListening != isListening ||
        oldDelegate.maxGraphPoints != maxGraphPoints ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.centerLineColor != centerLineColor ||
        oldDelegate.noDataTextColor != noDataTextColor ||
        oldDelegate.labelTextColor != labelTextColor;
  }
}

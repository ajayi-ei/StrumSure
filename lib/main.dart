// main.dart - The main entry point and configuration of the StrumSure application.

// This file sets up the Flutter application's core structure, including:
// - Initializing Flutter bindings.
// - Setting preferred device orientations.
// - Providing global state management (using Provider) for various services and notifiers.
// - Defining the application's visual themes (light and dark modes) using Material 3 guidelines.
// - Managing top-level navigation (using a Drawer) and displaying different screens.

import 'package:flutter/material.dart'; // Core Flutter UI components and Material Design.
import 'package:provider/provider.dart'; // For robust state management across the widget tree.
import 'package:flutter/services.dart'; // For controlling system UI overlays (e.g., status bar icons).

// Import all application-specific state notifiers, screens, and services.
import 'package:strum_sure/state/tuner_data_notifier.dart'; // Manages real-time tuner state.
import 'package:strum_sure/screens/tuner_screen.dart'; // The main guitar tuner UI.
import 'package:strum_sure/screens/chord_detector_screen.dart'; // Screen for audio chord detection.
import 'package:strum_sure/screens/saved_songs_list_screen.dart'; // Screen to view saved analyzed songs.
import 'package:strum_sure/services/ble_service.dart'; // Manages Bluetooth Low Energy communication.
import 'package:strum_sure/screens/ble_tuner_connect_screen.dart'; // Screen for connecting to ESP32 tuner.

/// A [ChangeNotifier] that manages the application's theme mode.
///
/// This notifier allows the application to dynamically switch between
/// light, dark, or system-defined theme modes, and notifies its listeners
/// (the `MaterialApp` in this case) to rebuild with the new theme.
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default theme mode is set to follow system settings.

  /// Public getter to access the current theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Sets the application's theme mode.
  ///
  /// Parameters:
  /// - `mode`: The desired [ThemeMode] (e.g., `ThemeMode.light`, `ThemeMode.dark`, `ThemeMode.system`).
  ///
  /// Notifies listeners if the theme mode has changed, triggering a UI rebuild.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners(); // Inform widgets that depend on this notifier to update.
    }
  }
}

/// The main entry point of the Flutter application.
///
/// This function is responsible for:
/// - Ensuring Flutter's widget binding is initialized.
/// - Setting preferred device orientations.
/// - Setting up global state management using [MultiProvider].
/// - Running the root widget, [StrumSureApp].
void main() {
  // Ensure that the Flutter binding is initialized. This is crucial before
  // interacting with Flutter's engine, especially when using platform channels
  // or services that require native code initialization (like `SystemChrome`).
  WidgetsFlutterBinding.ensureInitialized();

  // Set the preferred device orientations to portrait mode only.
  // This ensures a consistent user experience for the tuner, preventing
  // layout changes when the device is rotated.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Run the application, providing global state management via MultiProvider.
  // MultiProvider allows multiple ChangeNotifierProvider instances to be
  // registered at the root of the widget tree, making their data available
  // to all descendant widgets.
  runApp(
    MultiProvider(
      providers: [
        // Provide BleService first, as TunerDataNotifier depends on it.
        // `create` function ensures a new instance is created once.
        ChangeNotifierProvider(create: (context) => BleService()),
        // Provide TunerDataNotifier. It requires an instance of BleService,
        // which is accessed using `Provider.of<BleService>(context, listen: false)`.
        // `listen: false` is used here because TunerDataNotifier only needs to *access*
        // BleService, not rebuild when BleService itself notifies listeners.
        ChangeNotifierProvider(
          create: (context) => TunerDataNotifier(
            bleService: Provider.of<BleService>(context, listen: false),
          ),
        ),
        // Provide ThemeNotifier for managing the application's theme.
        ChangeNotifierProvider(create: (context) => ThemeNotifier()),
      ],
      child: const StrumSureApp(), // The root widget of the application.
    ),
  );
}

// --- Custom Color Constants for Theming ---
// These colors are defined based on the application's visual design specifications.
const Color _calmTeal = Color(0xFF00A39A); // The primary brand color for the app.

// Light Mode Specific Colors
const Color _lightBackgroundColor = Color(0xFFFFFFFF); // Background for Scaffold.
const Color _lightSurfaceColor = Color(0xFFF5F5F5); // Background for Cards, Dialogs, etc.
const Color _lightTextColor = Color(0xFF333333); // Primary text color in light mode.
const Color _lightSecondaryTextColor = Color(0xFF757575); // Secondary text color in light mode.
const Color _lightInactiveColor = Color(0xFFBBBBBB); // Color for inactive/disabled elements.
const Color _lightSurfaceVariant = Color(0xFFE0E0E0); // A slightly elevated surface color.

// Dark Mode Specific Colors
const Color _darkBackgroundColor = Color(0xFF1A1A1A); // Background for Scaffold.
const Color _darkSurfaceColor = Color(0xFF2C2C2C); // Background for Cards, Dialogs, etc.
const Color _darkTextColor = Color(0xFFFFFFFF); // Primary text color in dark mode.
const Color _darkSecondaryTextColor = Color(0xFFB0B0B0); // Secondary text color in dark mode.
const Color _darkInactiveColor = Color(0xFF606060); // Color for inactive/disabled elements.
const Color _darkSurfaceVariant = Color(0xFF3A3A3A); // A slightly elevated surface color.

// Functional/Status Colors (used directly for specific UI elements,
// often overriding theme colors for strong visual cues).
const Color _functionalRed = Colors.red; // Used for error indicators and delete actions.

// --- Light Theme Definition ---
// Defines the visual properties for the application when in light mode.
final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light, // Specifies light theme.
  primaryColor: _calmTeal, // Sets the primary color for the app.
  scaffoldBackgroundColor: _lightBackgroundColor, // Background color for Scaffold.
  cardColor: _lightSurfaceColor, // Default color for Card widgets.
  dialogTheme: const DialogThemeData( // Defines theme for AlertDialogs.
    backgroundColor: _lightSurfaceColor, // Background color for dialogs.
  ),
  snackBarTheme: const SnackBarThemeData( // Defines theme for SnackBars.
    backgroundColor: _lightSurfaceColor, // Background color for SnackBars.
    contentTextStyle: TextStyle(color: _lightTextColor), // Text style for SnackBar content.
  ),
  appBarTheme: const AppBarTheme( // Defines theme for AppBars.
    backgroundColor: _calmTeal, // AppBar background color.
    elevation: 0, // No shadow under the AppBar.
    systemOverlayStyle: SystemUiOverlayStyle.dark, // Dark status bar icons on light AppBar.
  ),
  colorScheme: const ColorScheme.light( // Defines a comprehensive color scheme for light mode.
    primary: _calmTeal, // Primary color.
    onPrimary: _lightTextColor, // Color for text/icons on primary color.
    secondary: _calmTeal, // Secondary accent color (can be same as primary).
    onSecondary: _lightTextColor, // Color for text/icons on secondary color.
    surface: _lightSurfaceColor, // Surface color for components like cards, dialogs.
    onSurface: _lightTextColor, // Color for text/icons on surface color.
    error: _functionalRed, // Error color.
    onError: _darkTextColor, // Color for text/icons on error color (white for contrast).
    surfaceContainerHighest: _lightSurfaceVariant, // Used for backgrounds of elements like progress indicators, gauge backgrounds.
    outline: _lightInactiveColor, // Color for outlines, borders (e.g., text input borders).
  ),
  textTheme: const TextTheme( // Defines text styles for various text elements.
    displayLarge: TextStyle(color: _lightTextColor),
    displayMedium: TextStyle(color: _lightTextColor),
    displaySmall: TextStyle(color: _lightTextColor),
    headlineLarge: TextStyle(color: _lightTextColor),
    headlineMedium: TextStyle(color: _lightTextColor),
    headlineSmall: TextStyle(color: _lightTextColor),
    titleLarge: TextStyle(color: _lightTextColor),
    titleMedium: TextStyle(color: _lightTextColor),
    titleSmall: TextStyle(color: _lightTextColor),
    bodyLarge: TextStyle(color: _lightTextColor),
    bodyMedium: TextStyle(color: _lightTextColor),
    bodySmall: TextStyle(color: _lightTextColor),
    labelLarge: TextStyle(color: _lightTextColor),
    labelMedium: TextStyle(color: _lightSecondaryTextColor), // Secondary text for labels.
    labelSmall: TextStyle(color: _lightSecondaryTextColor),
  ).apply(
    bodyColor: _lightTextColor, // Default text color for body text.
    displayColor: _lightTextColor, // Default text color for display headings.
  ),
  switchTheme: SwitchThemeData( // Defines theme for Switch widgets.
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return _calmTeal; // Active thumb color (selected).
      }
      return _lightInactiveColor; // Inactive thumb color (unselected).
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return _calmTeal.withAlpha((255 * 0.5).round()); // Active track color (50% opacity).
      }
      return _lightInactiveColor.withAlpha((255 * 0.5).round()); // Inactive track color (50% opacity).
    }),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData( // Defines theme for ElevatedButton widgets.
    style: ElevatedButton.styleFrom(
      backgroundColor: _calmTeal, // Default background color for ElevatedButtons.
      foregroundColor: _lightTextColor, // Default text color on ElevatedButtons.
    ),
  ),
  inputDecorationTheme: InputDecorationTheme( // Defines theme for InputDecoration (for TextFields).
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _lightInactiveColor), // Border color when enabled.
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _calmTeal), // Border color when focused (uses primary accent).
      borderRadius: BorderRadius.circular(8.0),
    ),
    border: OutlineInputBorder( // Default border style.
      borderRadius: BorderRadius.circular(8.0),
    ),
    labelStyle: const TextStyle(color: _lightSecondaryTextColor), // Style for labels.
    hintStyle: TextStyle(color: _lightSecondaryTextColor.withAlpha((255 * 0.7).round())), // Style for hints.
  ),
);

// --- Dark Theme Definition ---
// Defines the visual properties for the application when in dark mode.
final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark, // Specifies dark theme.
  primaryColor: _calmTeal, // Sets the primary color for the app.
  scaffoldBackgroundColor: _darkBackgroundColor, // Background color for Scaffold.
  cardColor: _darkSurfaceColor, // Default color for Card widgets.
  dialogTheme: const DialogThemeData( // Defines theme for AlertDialogs.
    backgroundColor: _darkSurfaceColor, // Background color for dialogs.
  ),
  snackBarTheme: const SnackBarThemeData( // Defines theme for SnackBars.
    backgroundColor: _darkSurfaceColor, // Background color for SnackBars.
    contentTextStyle: TextStyle(color: _darkTextColor), // Text style for SnackBar content.
  ),
  appBarTheme: const AppBarTheme( // Defines theme for AppBars.
    backgroundColor: _darkSurfaceColor, // AppBar background color.
    elevation: 0, // No shadow under the AppBar.
    systemOverlayStyle: SystemUiOverlayStyle.light, // Light status bar icons on dark AppBar.
  ),
  colorScheme: const ColorScheme.dark( // Defines a comprehensive color scheme for dark mode.
    primary: _calmTeal, // Primary color.
    onPrimary: _darkTextColor, // Color for text/icons on primary color.
    secondary: _calmTeal, // Secondary accent color.
    onSecondary: _darkTextColor, // Color for text/icons on secondary color.
    surface: _darkSurfaceColor, // Surface color for components.
    onSurface: _darkTextColor, // Color for text/icons on surface color.
    error: _functionalRed, // Error color.
    onError: _darkTextColor, // Color for text/icons on error color (white for contrast).
    surfaceContainerHighest: _darkSurfaceVariant, // Used for backgrounds of elements.
    outline: _darkInactiveColor, // Color for outlines, borders.
  ),
  textTheme: const TextTheme( // Defines text styles for various text elements.
    displayLarge: TextStyle(color: _darkTextColor),
    displayMedium: TextStyle(color: _darkTextColor),
    displaySmall: TextStyle(color: _darkTextColor),
    headlineLarge: TextStyle(color: _darkTextColor),
    headlineMedium: TextStyle(color: _darkTextColor),
    headlineSmall: TextStyle(color: _darkTextColor),
    titleLarge: TextStyle(color: _darkTextColor),
    titleMedium: TextStyle(color: _darkTextColor),
    titleSmall: TextStyle(color: _darkTextColor),
    bodyLarge: TextStyle(color: _darkTextColor),
    bodyMedium: TextStyle(color: _darkTextColor),
    bodySmall: TextStyle(color: _darkTextColor),
    labelLarge: TextStyle(color: _darkTextColor),
    labelMedium: TextStyle(color: _darkSecondaryTextColor), // Secondary text for labels.
    labelSmall: TextStyle(color: _darkSecondaryTextColor),
  ).apply(
    bodyColor: _darkTextColor, // Default text color for body text.
    displayColor: _darkTextColor, // Default text color for display headings.
  ),
  switchTheme: SwitchThemeData( // Defines theme for Switch widgets.
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return _calmTeal; // Active thumb color (selected).
      }
      return _darkInactiveColor; // Inactive thumb color (unselected).
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return _calmTeal.withAlpha((255 * 0.5).round()); // Active track color (50% opacity).
      }
      return _darkInactiveColor.withAlpha((255 * 0.5).round()); // Inactive track color (50% opacity).
    }),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData( // Defines theme for ElevatedButton widgets.
    style: ElevatedButton.styleFrom(
      backgroundColor: _calmTeal, // Default background color for ElevatedButtons.
      foregroundColor: _darkTextColor, // Default text color on ElevatedButtons.
    ),
  ),
  inputDecorationTheme: InputDecorationTheme( // Defines theme for InputDecoration (for TextFields).
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _darkInactiveColor), // Border color when enabled.
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _calmTeal), // Border color when focused (uses primary accent).
      borderRadius: BorderRadius.circular(8.0),
    ),
    border: OutlineInputBorder( // Default border style.
      borderRadius: BorderRadius.circular(8.0),
    ),
    labelStyle: const TextStyle(color: _darkSecondaryTextColor), // Style for labels.
    hintStyle: TextStyle(color: _darkSecondaryTextColor.withAlpha((255 * 0.7).round())), // Style for hints.
  ),
);

/// The root widget of the StrumSure application.
///
/// This widget sets up the [MaterialApp], defines the application's title,
/// applies the light and dark themes, and manages the overall theme mode
/// based on the [ThemeNotifier]. Its `home` property points to [MainAppWrapper]
/// which handles top-level navigation.
class StrumSureApp extends StatelessWidget {
  /// Constructs a [StrumSureApp] widget.
  const StrumSureApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume the ThemeNotifier to react to theme mode changes.
    // The MaterialApp will rebuild whenever themeNotifier.themeMode changes.
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Guitar Tuner', // The title displayed in the task switcher.
          debugShowCheckedModeBanner: false, // Removes Debug Banner
          theme: _lightTheme, // Defines the light theme for the application.
          darkTheme: _darkTheme, // Defines the dark theme for the application.
          themeMode: themeNotifier.themeMode, // Controls the active theme (light, dark, or system).
          home: const MainAppWrapper(), // The top-level navigation wrapper.
        );
      },
    );
  }
}

/// A wrapper widget that manages the tab navigation for the main application.
///
/// This widget uses a [Scaffold] with a [Drawer] to provide navigation
/// between different screens (Tuner, Chord Detector, Saved Songs, ESP32 Tuner)
/// and also includes options for theme selection.
class MainAppWrapper extends StatefulWidget {
  /// Constructs a [MainAppWrapper] widget.
  const MainAppWrapper({super.key});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

/// The state class for [MainAppWrapper].
///
/// It manages the currently selected tab index and handles navigation
/// within the application using a [Drawer].
class _MainAppWrapperState extends State<MainAppWrapper> {
  int _selectedIndex = 0; // The index of the currently selected tab/screen.

  // A static list of widgets, where each widget corresponds to a tab/screen.
  // The index in this list matches the `_selectedIndex` for navigation.
  static final List<Widget> _widgetOptions = <Widget>[
    const TunerScreen(), // Index 0: Guitar Tuner Tab.
    const ChordDetectorScreen(), // Index 1: Chord Detector Tab.
    const SavedSongsListScreen(), // Index 2: Saved Songs Tab.
    const BleTunerConnectScreen(), // Index 3: ESP32 BLE Tuner Tab.
  ];

  /// Handles tap events on the [Drawer] list items.
  ///
  /// Updates the `_selectedIndex` to switch to the new screen and
  /// closes the drawer.
  ///
  /// Parameters:
  /// - `index`: The index of the tapped item, corresponding to a screen in `_widgetOptions`.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Update the selected index.
    });
    // Close the drawer after an item is tapped to return to the main content.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Access the current theme's color scheme for consistent styling.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // Access the ThemeNotifier to read and potentially change the theme mode.
    final ThemeNotifier themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      // AppBar for the main screen, displaying the title and a drawer icon.
      appBar: AppBar(
        title: Text(
          // Dynamically display the title based on the selected tab.
          _selectedIndex == 0 ? 'Guitar Tuner' :
          _selectedIndex == 1 ? 'Chord Detector' :
          _selectedIndex == 2 ? 'Saved Songs' :
          'ESP32 Tuner', // Default title for the last tab.
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary), // Themed title color.
        ),
        backgroundColor: colorScheme.primary, // Themed AppBar background.
        elevation: 0, // No shadow for a flat design.
        systemOverlayStyle: SystemUiOverlayStyle.dark, // Dark status bar icons on primary color AppBar.
      ),
      body: Center(
        // Display the widget corresponding to the currently selected tab.
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      // The application's main navigation is provided by a Drawer.
      drawer: Drawer(
        backgroundColor: colorScheme.surface, // Themed background color for the drawer.
        child: ListView(
          padding: EdgeInsets.zero, // Remove default ListView padding.
          children: <Widget>[
            // --- Drawer Header ---
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.primary, // Themed background for the drawer header.
              ),
              child: Text(
                'StrumSure App', // Updated app name in drawer header.
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.onPrimary), // Themed text style.
              ),
            ),
            // --- Navigation List Tiles ---
            ListTile(
              leading: Icon(Icons.music_note, color: _selectedIndex == 0 ? colorScheme.primary : colorScheme.onSurface),
              title: Text('Guitar Tuner', style: TextStyle(color: _selectedIndex == 0 ? colorScheme.primary : colorScheme.onSurface)),
              selected: _selectedIndex == 0, // Highlight if this tab is selected.
              onTap: () => _onItemTapped(0), // Navigate to TunerScreen.
            ),
            ListTile(
              leading: Icon(Icons.graphic_eq, color: _selectedIndex == 1 ? colorScheme.primary : colorScheme.onSurface),
              title: Text('Chord Detector', style: TextStyle(color: _selectedIndex == 1 ? colorScheme.primary : colorScheme.onSurface)),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1), // Navigate to ChordDetectorScreen.
            ),
            ListTile(
              leading: Icon(Icons.library_music, color: _selectedIndex == 2 ? colorScheme.primary : colorScheme.onSurface),
              title: Text('Saved Songs', style: TextStyle(color: _selectedIndex == 2 ? colorScheme.primary : colorScheme.onSurface)),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2), // Navigate to SavedSongsListScreen.
            ),
            ListTile(
              leading: Icon(Icons.bluetooth, color: _selectedIndex == 3 ? colorScheme.primary : colorScheme.onSurface),
              title: Text('ESP32 Tuner', style: TextStyle(color: _selectedIndex == 3 ? colorScheme.primary : colorScheme.onSurface)),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3), // Navigate to BleTunerConnectScreen.
            ),
            // --- Theme Selection Section ---
            const Divider(), // Visual separator.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'App Theme',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.onSurface.withAlpha((255 * 0.7).round())),
              ),
            ),
            ListTile(
              leading: Icon(Icons.brightness_auto, color: themeNotifier.themeMode == ThemeMode.system ? colorScheme.primary : colorScheme.onSurface),
              title: Text('Auto (System)', style: TextStyle(color: themeNotifier.themeMode == ThemeMode.system ? colorScheme.primary : colorScheme.onSurface)),
              selected: themeNotifier.themeMode == ThemeMode.system,
              onTap: () {
                themeNotifier.setThemeMode(ThemeMode.system); // Set theme to system.
                Navigator.of(context).pop(); // Close drawer.
              },
            ),
            ListTile(
              leading: Icon(Icons.light_mode, color: themeNotifier.themeMode == ThemeMode.light ? colorScheme.primary : colorScheme.onSurface),
              title: Text('Light Mode', style: TextStyle(color: themeNotifier.themeMode == ThemeMode.light ? colorScheme.primary : colorScheme.onSurface)),
              selected: themeNotifier.themeMode == ThemeMode.light,
              onTap: () {
                themeNotifier.setThemeMode(ThemeMode.light); // Set theme to light.
                Navigator.of(context).pop(); // Close drawer.
              },
            ),
            ListTile(
              leading: Icon(Icons.dark_mode, color: themeNotifier.themeMode == ThemeMode.dark ? colorScheme.primary : colorScheme.onSurface),
              title: Text('Dark Mode', style: TextStyle(color: themeNotifier.themeMode == ThemeMode.dark ? colorScheme.primary : colorScheme.onSurface)),
              selected: themeNotifier.themeMode == ThemeMode.dark,
              onTap: () {
                themeNotifier.setThemeMode(ThemeMode.dark); // Set theme to dark.
                Navigator.of(context).pop(); // Close drawer.
              },
            ),
          ],
        ),
      ),
    );
  }
}

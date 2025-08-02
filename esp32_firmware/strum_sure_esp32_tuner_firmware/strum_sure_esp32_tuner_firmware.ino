// ESP32 BLE Tuner Firmware

// This Arduino sketch for the ESP32-WROOM-32 module implements a Bluetooth Low Energy (BLE)
// peripheral device that acts as a "smart tuner." It establishes a BLE connection with
// a Flutter application (StrumSure), receives real-time frequency and target note data,
// processes this data to calculate tuning adjustments, and sends back simulated
// motor control commands (as text messages) to the Flutter app.

#include <BLEDevice.h> // Core BLE device functionalities (server, advertising).
#include <BLEServer.h> // For creating a BLE server.
#include <BLEUtils.h>  // Utility functions for BLE (e.g., converting UUIDs).
#include <BLE2902.h>   // Required for BLE descriptors, especially for characteristic notifications.
#include <math.h>      // For mathematical functions like log2(), abs(), round(), and fmin().

// ===================================================================
// BLE Service and Characteristic UUIDs
// IMPORTANT: These UUIDs MUST EXACTLY MATCH the UUIDs defined in your Flutter application's BleService.
// Mismatched UUIDs will prevent the Flutter app from discovering and communicating with the ESP32.
// ===================================================================
#define SERVICE_UUID             "a0c1d2e3-4f5a-6b7c-8d9e-0f1a2b3c4d5e" // Custom Service UUID for the smart tuner.
#define CHARACTERISTIC_UUID_TX   "e5d4c3b2-a1f0-9e8d-7c6b-5a4f3e2d1c0b" // Characteristic for data transmission FROM ESP32 TO Flutter App (Notify/Read).
#define CHARACTERISTIC_UUID_RX   "1a2b3c4d-5e6f-7a8b-9c0d-e1f2a3b4c5d6" // Characteristic for data reception FROM Flutter App TO ESP32 (Write).

// ===================================================================
// Global BLE Objects and Connection State Variables
// ===================================================================
BLEServer* pServer = NULL; // Pointer to the BLE server instance.
BLECharacteristic* pCharacteristicTx = NULL; // Pointer to the TX (Transmit) characteristic.
BLECharacteristic* pCharacteristicRx = NULL; // Pointer to the RX (Receive) characteristic.
bool deviceConnected = false;    // Flag indicating the current connection status.
bool oldDeviceConnected = false; // Stores the previous connection status to detect changes.

// ===================================================================
// Variables for Storing Received Tuning Data
// These variables hold the parsed data sent from the Flutter application.
// ===================================================================
double detectedFrequency = 0.0; // The frequency detected by the Flutter app's microphone.
double targetFrequency = 0.0;   // The target frequency for the note being tuned.
String targetNoteName = "N/A";  // The name of the target note (e.g., "E4", "A2").

// ===================================================================
// Tuning Parameters for Motor Control Simulation
// These constants define the logic for calculating simulated motor adjustments.
// ===================================================================
// This ratio determines how many degrees the "simulated motor" should turn per cent of deviation.
// A smaller value results in more precise, less aggressive adjustments.
const float CENTS_TO_DEGREE_RATIO = 0.2; // Example: 10 cents deviation -> 2 degrees rotation.
// Maximum degrees for a single correction step. This clamps the calculated rotation
// to prevent excessively large or unrealistic simulated turns.
const float MAX_MOTOR_DEGREES = 45.0; // E.g., a quarter turn or less.
// Minimum cents deviation required to trigger a tuning command.
// If the deviation is within this threshold (e.g., +/- 5 cents), the note is considered "in tune."
const float MIN_CENTS_THRESHOLD = 5.0;

// ===================================================================
// Function Forward Declarations
// Declares functions before they are fully defined, allowing them to be called earlier in the code.
// ===================================================================
void sendTuningCommand(); // Function to calculate and send tuning commands to the Flutter app.

// ===================================================================
// BLE Server Callback Class
// Handles events related to BLE server (connection and disconnection).
// ===================================================================
class MyServerCallbacks: public BLEServerCallbacks {
  /// Called when a BLE client (Flutter app) connects to the ESP32 server.
  ///
  /// Parameters:
  /// - `pServer`: A pointer to the BLEServer instance.
  void onConnect(BLEServer* pServer) {
    deviceConnected = true; // Set connection flag to true.
    Serial.println("Device connected!"); // Log connection status to Serial Monitor.
    // Optionally, stop advertising after the first connection to save power.
    // This ESP32 firmware is designed to restart advertising on disconnect.
    // pServer->stopAdvertising();
  };

  /// Called when a BLE client (Flutter app) disconnects from the ESP32 server.
  ///
  /// Parameters:
  /// - `pServer`: A pointer to the BLEServer instance.
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false; // Set connection flag to false.
    Serial.println("Device disconnected. Starting advertising again..."); // Log disconnection.
    BLEDevice::startAdvertising(); // Restart advertising to allow new connections.
  }
};

// ===================================================================
// BLE Characteristic Callback Class
// Handles write events to the RX characteristic (data received from Flutter app).
// ===================================================================
class MyCallbacks: public BLECharacteristicCallbacks {
  /// Called when data is written to the RX characteristic by the connected Flutter app.
  ///
  /// This method parses the incoming string to extract detected frequency,
  /// target frequency, and target note name, then triggers the tuning command calculation.
  ///
  /// Parameters:
  /// - `pCharacteristic`: A pointer to the BLECharacteristic that was written to.
  void onWrite(BLECharacteristic *pCharacteristic) {
    // Get the received value as a standard C++ string.
    std::string rxValue = std::string(pCharacteristic->getValue().c_str());

    if (rxValue.length() > 0) {
      Serial.print("Received from Flutter: ");
      Serial.println(rxValue.c_str()); // Print the raw received string to Serial Monitor.

      // Parse the incoming string, which is expected in the format:
      // "FREQ:X.X,TARGET:Y.Y,NOTE:Z" (e.g., "FREQ:440.5,TARGET:440.0,NOTE:A4")
      String receivedStr = String(rxValue.c_str()); // Convert std::string to Arduino String for easier parsing.
      int freqIndex = receivedStr.indexOf("FREQ:");
      int targetIndex = receivedStr.indexOf(",TARGET:");
      int noteIndex = receivedStr.indexOf(",NOTE:");

      // Validate that all expected parts of the string are found.
      if (freqIndex != -1 && targetIndex != -1 && noteIndex != -1) {
        // Extract substrings for frequency, target frequency, and target note.
        String freqStr = receivedStr.substring(freqIndex + 5, targetIndex);
        String targetStr = receivedStr.substring(targetIndex + 8, noteIndex);
        String noteStr = receivedStr.substring(noteIndex + 6);

        // Convert extracted strings to their respective data types.
        detectedFrequency = freqStr.toDouble();
        targetFrequency = targetStr.toDouble();
        targetNoteName = noteStr;

        // Log the parsed values for debugging.
        Serial.print("Parsed - Detected Freq: "); Serial.print(detectedFrequency);
        Serial.print(", Target Freq: "); Serial.print(targetFrequency);
        Serial.print(", Target Note: "); Serial.println(targetNoteName);

        // Calculate and send the appropriate tuning command back to the Flutter app.
        sendTuningCommand();
      } else {
        // Handle cases where the received data format is unexpected.
        Serial.println("Received malformed tuning data.");
        // Optionally, send an error message back to the Flutter app.
        if (deviceConnected) {
          pCharacteristicTx->setValue("Error: Malformed data");
          pCharacteristicTx->notify(); // Notify the app about the error.
        }
      }
    }
  }
};

// ===================================================================
// Tuning Command Logic
// Calculates tuning instructions based on detected and target frequencies.
// ===================================================================
/// Calculates a tuning command based on the detected and target frequencies,
/// then sends this command back to the connected Flutter application via BLE notification.
///
/// The command indicates whether the string is in tune, too sharp, or too flat,
/// and suggests a simulated motor adjustment in degrees if off-tune.
void sendTuningCommand() {
  String command = "N/A"; // Default command string.

  // Check for invalid or initial states where tuning cannot be performed.
  if (targetNoteName == "N/A" || detectedFrequency <= 0 || targetFrequency <= 0) {
    command = "Play a string to tune."; // Instruct the user to play a string.
  } else {
    // Calculate cents deviation using the standard formula: 1200 * log2(f_detected / f_target).
    float centsDeviation = 1200.0 * log2(detectedFrequency / targetFrequency);

    // Determine the tuning action based on the cents deviation.
    if (abs(centsDeviation) < MIN_CENTS_THRESHOLD) {
      // If deviation is within the "in tune" threshold.
      command = targetNoteName + " is in tune!";
    } else {
      // If deviation is outside the "in tune" threshold, calculate simulated motor adjustment.
      float motorDegrees = abs(centsDeviation) * CENTS_TO_DEGREE_RATIO;
      // Clamp the calculated degrees to the maximum allowed to prevent excessive adjustments.
      motorDegrees = fmin(motorDegrees, MAX_MOTOR_DEGREES);
      
      // Round the degrees to the nearest integer for cleaner display in the app.
      int roundedDegrees = round(motorDegrees);

      if (centsDeviation > 0) { // If detected frequency is higher than target (sharp).
        // Needs loosening.
        command = "Loosen " + targetNoteName + " by " + String(roundedDegrees) + " degrees";
      } else { // If detected frequency is lower than target (flat).
        // Needs tightening.
        command = "Tighten " + targetNoteName + " by " + String(roundedDegrees) + " " + "degrees";
      }
    }
  }

  // Log the command being sent to the Serial Monitor for debugging.
  Serial.print("Sending command to Flutter: ");
  Serial.println(command);

  // If a device is connected, send the command via the TX characteristic.
  if (deviceConnected) {
    pCharacteristicTx->setValue(command.c_str()); // Set the characteristic's value.
    pCharacteristicTx->notify(); // Send a notification to the connected client (Flutter app).
  }
}

// ===================================================================
// Arduino Setup Function
// Called once when the ESP32 starts up.
// ===================================================================
void setup() {
  Serial.begin(115200); // Initialize serial communication for debugging output.
  Serial.println("Starting BLE Server for Tuner..."); // Log start message.

  // Initialize the BLE Device and set its local name.
  // This name ("ESP32_Tuner") is what your Flutter app will see during device discovery.
  BLEDevice::init("ESP32_Tuner");

  // Create the BLE Server instance.
  pServer = BLEDevice::createServer();
  // Set the callback for server events (connections/disconnections).
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service using the defined SERVICE_UUID.
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create the TX (Transmit) Characteristic for sending data to the app.
  // It has READ and NOTIFY properties, allowing the app to read its value
  // and receive real-time updates (notifications).
  pCharacteristicTx = pService->createCharacteristic(
                      CHARACTERISTIC_UUID_TX,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  // Add a BLE2902 descriptor, which is essential for enabling notifications on the client side.
  pCharacteristicTx->addDescriptor(new BLE2902());

  // Create the RX (Receive) Characteristic for getting data from the app.
  // It has a WRITE property, allowing the app to write values to it.
  pCharacteristicRx = pService->createCharacteristic(
                      CHARACTERISTIC_UUID_RX,
                      BLECharacteristic::PROPERTY_WRITE
                    );
  // Set the callback for characteristic write events (when Flutter sends data).
  pCharacteristicRx->setCallbacks(new MyCallbacks());

  // Start the defined BLE service.
  pService->start();

  // Configure and start BLE advertising.
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID); // Advertise the UUID of our custom service.
  pAdvertising->setScanResponse(true); // Enable scan responses for more detailed advertisement data.
  // Set preferred advertising intervals for faster connection.
  pAdvertising->setMinPreferred(0x06); // Minimum advertising interval.
  pAdvertising->setMinPreferred(0x12); // Another minimum advertising interval (often used in pairs).
  BLEDevice::startAdvertising(); // Begin advertising the BLE device.
  Serial.println("Advertising started! Waiting for connections..."); // Log advertising status.
}

// ===================================================================
// Arduino Loop Function
// Called repeatedly after setup() completes.
// ===================================================================
void loop() {
  // Check for changes in connection status to gracefully restart advertising.
  // This ensures that if the device disconnects, it immediately starts advertising again
  // so the Flutter app can reconnect without manual intervention.
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Short delay to allow the BLE stack to stabilize after disconnection.
    pServer->startAdvertising(); // Restart advertising.
    Serial.println("Restarted advertising"); // Log the action.
  }
  // Detect when a device has just connected.
  if (deviceConnected && !oldDeviceConnected) {
    Serial.println("Connected and ready for communication."); // Log connection readiness.
  }
  oldDeviceConnected = deviceConnected; // Update the old connection status for the next loop iteration.

  delay(10); // Small delay to prevent the ESP32's watchdog timer from resetting the board.
             // This is good practice in Arduino sketches to avoid busy-waiting.
}

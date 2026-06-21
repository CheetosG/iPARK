#include <ArduinoJson.h>
#include <ArduinoWebsockets.h>
#include <ESP32Servo.h>
#include <WebServer.h>
#include <WiFi.h>

// --- Configuration Constants ---
// ============================================================
// WiFi network credentials
// ============================================================
const char *ssid = "Home";                 // Your WiFi SSID
const char *password = "Cheetos1732005#$"; // Your WiFi Password

// Backend WebSocket Server URL (direct local connection)
const char *ws_url = "ws://192.168.1.2:5000/ws/iot";
// const char* ws_url   = "ws://192.168.1.9:5000/ws/iot";

// The MongoDB object IDs of the Spots this ESP32 is controlling
const char *spot_id_ir1 = "69c505f7d3f0ad5a7f3c9924"; // Sun City Spot A-1
const char *spot_id_ir2 = "69c505f7d3f0ad5a7f3c9926"; // Sun City Spot A-2

// Servo Position Settings (from user setup)
const int GATE_CLOSED_ANGLE = 170; // Closed angle
const int GATE_OPEN_ANGLE = 90;    // Open angle

// --- Pin Definitions (from user setup) ---
const int PIN_SERVO = 4;
const int PIN_TRIG = 5;
const int PIN_ECHO = 18;
const int PIN_IR_1 = 23; // IR1
const int PIN_IR_2 = 22; // IR2

// --- Global Objects ---
Servo gateServo;
using namespace websockets;
WebsocketsClient client;
WebServer server(80);

// --- State Variables ---
bool objectDetected = false;
bool gateOpened = false;
String slotStatus = "FREE";

// Monitoring state for IR1 (Spot A-1)
int stableCount_ir1 = 0;
bool currentOccupancy_ir1 = false;

// Monitoring state for IR2 (Spot A-2)
int stableCount_ir2 = 0;
bool currentOccupancy_ir2 = false;

unsigned long lastSensorPollTime = 0;
const unsigned long SENSOR_POLL_INTERVAL_MS = 100; // Poll sensors every 100ms

// Forward declarations
void connectWiFi();
void connectWebSocket();
void onMessageCallback(WebsocketsMessage message);
void onEventsCallback(WebsocketsEvent event, String data);
long getDistance();
void getStatus();
void verifyAndOpen();

void setup() {
  Serial.begin(9600);
  delay(1000);
  Serial.println("\n[iPARK] Initializing IoT Gate Controller...");

  // Pin Configuration
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);

  pinMode(PIN_IR_1, INPUT);
  pinMode(PIN_IR_2, INPUT);

  // Servo Setup
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  gateServo.setPeriodHertz(50); // Standard 50Hz servo
  gateServo.attach(PIN_SERVO, 500,
                   2400); // Attach with min/max pulse width in microseconds

  // Default to gate closed
  gateServo.write(GATE_CLOSED_ANGLE);
  Serial.printf(
      "[iPARK] Servo attached. Gate initialized to CLOSED (%d deg).\n",
      GATE_CLOSED_ANGLE);

  // Connect to WiFi
  connectWiFi();

  // Setup WebSocket callbacks and connect
  client.onMessage(onMessageCallback);
  client.onEvent(onEventsCallback);
  connectWebSocket();

  // Setup Local HTTP Server
  server.on("/status", getStatus);
  server.on("/verify", verifyAndOpen);
  server.begin();
  Serial.println("[iPARK] Local WebServer started on port 80");
}

void loop() {
  // Keep WebSocket client active
  if (client.available()) {
    client.poll();
  } else {
    // Attempt automatic reconnection if disconnected
    static unsigned long lastReconnectAttempt = 0;
    unsigned long now = millis();
    if (now - lastReconnectAttempt > 5000) {
      lastReconnectAttempt = now;
      Serial.println("[iPARK] WebSocket disconnected. Retrying connection...");
      connectWebSocket();
    }
  }

  // Handle local HTTP server clients
  server.handleClient();

  // Check sensors periodically
  unsigned long now = millis();
  if (now - lastSensorPollTime >= SENSOR_POLL_INTERVAL_MS) {
    lastSensorPollTime = now;

    int s1 = !digitalRead(PIN_IR_1);
    int s2 = !digitalRead(PIN_IR_2);
    long distance = getDistance();

    Serial.print("IR1: ");
    Serial.print(s1);
    Serial.print("  IR2: ");
    Serial.print(s2);

    if (distance == -1) {
      Serial.println("  Dist: No object");
    } else {
      Serial.print("  Dist: ");
      Serial.print(distance);
      Serial.println(" cm");
    }

    // ===================== SLOT OCCUPANCY LOGIC =====================
    // For IR1 (Spot A-1)
    if (s1 == 1) {
      stableCount_ir1++;
      if (stableCount_ir1 >= 2) {
        slotStatus =
            "OCCUPIED"; // For local HTTP server status backward compatibility
        if (currentOccupancy_ir1 == false) {
          currentOccupancy_ir1 = true;
          Serial.println("[iPARK] IR1 (Spot A-1) state changed to: OCCUPIED");

          if (client.available()) {
            StaticJsonDocument<200> doc;
            doc["action"] = "status_change";
            doc["spotId"] = spot_id_ir1;
            doc["occupied"] = true;
            String output;
            serializeJson(doc, output);
            client.send(output);
          }
        }
      }
    } else {
      stableCount_ir1 = 0;
      if (currentOccupancy_ir1 == true) {
        currentOccupancy_ir1 = false;
        Serial.println("[iPARK] IR1 (Spot A-1) state changed to: FREE");

        if (client.available()) {
          StaticJsonDocument<200> doc;
          doc["action"] = "status_change";
          doc["spotId"] = spot_id_ir1;
          doc["occupied"] = false;
          String output;
          serializeJson(doc, output);
          client.send(output);
        }
      }
    }

    // For IR2 (Spot A-2)
    if (s2 == 1) {
      stableCount_ir2++;
      if (stableCount_ir2 >= 2) {
        if (currentOccupancy_ir2 == false) {
          currentOccupancy_ir2 = true;
          Serial.println("[iPARK] IR2 (Spot A-2) state changed to: OCCUPIED");

          if (client.available()) {
            StaticJsonDocument<200> doc;
            doc["action"] = "status_change";
            doc["spotId"] = spot_id_ir2;
            doc["occupied"] = true;
            String output;
            serializeJson(doc, output);
            client.send(output);
          }
        }
      }
    } else {
      stableCount_ir2 = 0;
      if (currentOccupancy_ir2 == true) {
        currentOccupancy_ir2 = false;
        Serial.println("[iPARK] IR2 (Spot A-2) state changed to: FREE");

        if (client.available()) {
          StaticJsonDocument<200> doc;
          doc["action"] = "status_change";
          doc["spotId"] = spot_id_ir2;
          doc["occupied"] = false;
          String output;
          serializeJson(doc, output);
          client.send(output);
        }
      }
    }

    // Update slotStatus helper string
    if (!currentOccupancy_ir1 && !currentOccupancy_ir2) {
      slotStatus = "FREE";
    }
  }
}

// Connect to local Wi-Fi
void connectWiFi() {
  Serial.printf("[iPARK] Connecting to Wi-Fi SSID: %s\n", ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[iPARK] Wi-Fi Connected!");
  Serial.print("[iPARK] IP Address: ");
  Serial.println(WiFi.localIP());
}

// Connect to Backend WebSocket (direct LAN connection)
void connectWebSocket() {
  Serial.printf("[iPARK] Connecting to WebSocket: %s\n", ws_url);

  bool connected = client.connect(ws_url);
  if (connected) {
    Serial.println("[iPARK] WebSocket Connected!");

    // Register Spot A-1
    StaticJsonDocument<200> doc1;
    doc1["action"] = "register";
    doc1["spotId"] = spot_id_ir1;
    String output1;
    serializeJson(doc1, output1);
    client.send(output1);

    delay(200); // Small delay between registrations

    // Register Spot A-2
    StaticJsonDocument<200> doc2;
    doc2["action"] = "register";
    doc2["spotId"] = spot_id_ir2;
    String output2;
    serializeJson(doc2, output2);
    client.send(output2);
  } else {
    Serial.println("[iPARK] WebSocket connection failed!");
  }
}

// Handle incoming commands from the server
void onMessageCallback(WebsocketsMessage message) {
  Serial.printf("[iPARK] Received Command from Server: %s\n",
                message.data().c_str());

  StaticJsonDocument<250> doc;
  DeserializationError error = deserializeJson(doc, message.data());
  if (error) {
    Serial.print("[iPARK] JSON Parsing failed: ");
    Serial.println(error.c_str());
    return;
  }

  const char *action = doc["action"];
  if (action == nullptr)
    return;

  const char *incoming_spot_id = doc["spotId"];
  if (incoming_spot_id == nullptr) {
    incoming_spot_id = spot_id_ir1; // Fallback
  }

  if (strcmp(action, "OPEN_GATE") == 0) {
    Serial.println("[iPARK] Remote Action: OPENING GATE...");
    gateServo.write(GATE_OPEN_ANGLE);
    delay(500);

    // Send ack back to server
    StaticJsonDocument<200> ack;
    ack["action"] = "gate_status";
    ack["spotId"] = incoming_spot_id;
    ack["status"] = "OPEN";
    String out;
    serializeJson(ack, out);
    client.send(out);
  } else if (strcmp(action, "CLOSE_GATE") == 0) {
    Serial.println("[iPARK] Remote Action: CLOSING GATE...");

    // Reset occupancy state for this specific spot
    if (strcmp(incoming_spot_id, spot_id_ir1) == 0) {
      currentOccupancy_ir1 = false;
      stableCount_ir1 = 0;
    } else if (strcmp(incoming_spot_id, spot_id_ir2) == 0) {
      currentOccupancy_ir2 = false;
      stableCount_ir2 = 0;
    }

    // If both spots are free, update slotStatus
    if (!currentOccupancy_ir1 && !currentOccupancy_ir2) {
      slotStatus = "FREE";
    }

    gateServo.write(GATE_CLOSED_ANGLE);
    delay(500);

    // Send ack back to server
    StaticJsonDocument<200> ack;
    ack["action"] = "gate_status";
    ack["spotId"] = incoming_spot_id;
    ack["status"] = "CLOSED";
    String out;
    serializeJson(ack, out);
    client.send(out);
  }
}

// Event callbacks (Connection closed, etc.)
void onEventsCallback(WebsocketsEvent event, String data) {
  if (event == WebsocketsEvent::ConnectionClosed) {
    Serial.println("[iPARK] Connection closed");
  } else if (event == WebsocketsEvent::ConnectionOpened) {
    Serial.println("[iPARK] Connection opened");
  }
}

// ===================== ULTRASONIC =====================
long getDistance() {
  long sum = 0;
  int valid = 0;

  for (int i = 0; i < 3; i++) {
    digitalWrite(PIN_TRIG, LOW);
    delayMicroseconds(2);

    digitalWrite(PIN_TRIG, HIGH);
    delayMicroseconds(10);
    digitalWrite(PIN_TRIG, LOW);

    long duration = pulseIn(PIN_ECHO, HIGH, 30000);

    if (duration > 0) {
      long d = duration * 0.034 / 2;
      if (d > 2 && d < 80) {
        sum += d;
        valid++;
      }
    }
    delay(20);
  }

  if (valid == 0)
    return -1;
  return sum / valid;
}

// ===================== API =====================
void getStatus() { server.send(200, "text/plain", slotStatus); }

void verifyAndOpen() {
  Serial.println("Verify request received");
  long distance = getDistance();

  if (distance != -1 && distance < 6) {
    Serial.println("Verified → Opening Gate");

    gateServo.write(GATE_OPEN_ANGLE); // Open gate
    delay(500);

    // Notify backend WebSocket server
    if (client.available()) {
      StaticJsonDocument<200> ack;
      ack["action"] = "gate_status";
      ack["spotId"] = spot_id_ir1;
      ack["status"] = "OPEN";
      String out;
      serializeJson(ack, out);
      client.send(out);
    }

    server.send(200, "text/plain", "Gate Opened");
    delay(5000); // Wait 5 seconds

    gateServo.write(GATE_CLOSED_ANGLE); // Close gate
    delay(500);

    // Notify backend WebSocket server
    if (client.available()) {
      StaticJsonDocument<200> ack;
      ack["action"] = "gate_status";
      ack["spotId"] = spot_id_ir1;
      ack["status"] = "CLOSED";
      String out;
      serializeJson(ack, out);
      client.send(out);
    }
  } else {
    server.send(403, "text/plain", "No car detected");
  }
}

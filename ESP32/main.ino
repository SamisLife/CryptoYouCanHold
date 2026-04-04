// ===== WIRING =====
// OLED GND → ESP32 GND
// OLED VCC → ESP32 3.3V
// OLED SDA → D21
// OLED SCL → D22
//
// PN532 SCK  → D18
// PN532 MISO → D19
// PN532 MOSI → D23
// PN532 SS   → D5
// ==================

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <SPI.h>
#include <Adafruit_PN532.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// Network
const char* ssid = "xxxx";          // hotspot name
const char* password = "xxxxx";  // hotspot password

// ngrok url
const String transferAPI = "https://ur-ngroook.dev/coins/transfer";

// The digital wallet ID for this ESP32 scanner (the merchant receiving the funds)
const String merchantWalletID = "wallet_person_2";

// oled screen setup
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// PN532 (SPI) SETUP
#define PN532_SS  5  
Adafruit_PN532 nfc(PN532_SS);

// helper function

void updateScreen(String line1, String line2 = "", String line3 = "") {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  
  display.println(line1);
  if(line2.length() > 0) display.println(line2);
  if(line3.length() > 0) display.println(line3);
  
  display.display();
}

bool readPageWithRetry(uint8_t page, uint8_t *data, int retries = 8) {
  for (int i = 0; i < retries; i++) {
    if (nfc.ntag2xx_ReadPage(page, data)) return true;
    delay(12);
  }
  return false;
}

String extractNdefTextFromPages(const uint8_t *buf, int len) {
  int posT = -1;
  for (int i = 0; i < len; i++) {
    if (buf[i] == 0x54) { posT = i; break; }
  }
  if (posT < 0 || posT + 3 >= len) return "";

  uint8_t status = buf[posT + 1];
  uint8_t langLen = status & 0x3F;
  int textStart = posT + 2 + langLen;
  if (textStart >= len) return "";

  String out = "";
  for (int i = textStart; i < len && buf[i] != 0xFE; i++) {
    if (buf[i] == 0x00) break;
    out += (char)buf[i];
  }
  return out;
}

// main api logic

void executeTransfer(String coinID) {
  updateScreen("Processing...", "Authenticating API");
  Serial.println("Initiating Transfer API Call...");

  // FIX 1: Check if Wi-Fi dropped and reconnect if necessary
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi dropped! Reconnecting...");
    WiFi.disconnect();
    WiFi.reconnect();
    delay(2000);
  }

  // FIX 2: Stack allocation prevents memory fragmentation/leaks
  WiFiClientSecure client;
  client.setInsecure(); // Bypass SSL cert validation

  HTTPClient http;
  http.setTimeout(10000); // Give Ngrok 10 seconds to respond to prevent -1 timeouts

  if (http.begin(client, transferAPI)) {
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<200> reqDoc;
    reqDoc["coin_id"] = coinID;
    reqDoc["destination_wallet"] = merchantWalletID;
    
    String requestBody;
    serializeJson(reqDoc, requestBody);

    int httpCode = http.POST(requestBody);
    String responseBody = http.getString();
    
    Serial.printf("HTTP Code: %d\n", httpCode);
    Serial.println("Response: " + responseBody);

    if (httpCode > 0) {
      StaticJsonDocument<512> resDoc;
      DeserializationError error = deserializeJson(resDoc, responseBody);

      if (httpCode == 200 && !error) {
        // SUCCESS!
        float amount = resDoc["amount"];
        const char* symbol = resDoc["symbol"];
        
        updateScreen("PAYMENT SUCCESS!", String(amount) + " " + String(symbol), "Link Destroyed.");
        Serial.println("Transfer Complete!");
        
      } else {
        // DENIED OR PARSE ERROR
        // FIX 3: Safe fallback to prevent substring null-pointer crashes
        String detailMsg = "Unknown Error";
        if (!error && resDoc.containsKey("detail")) {
            detailMsg = resDoc["detail"].as<String>();
        }
        updateScreen("TRANSFER DENIED", detailMsg); 
        Serial.println("Transfer Denied: " + detailMsg);
      }
    } else {
      // HTTP -1 (Timeout or Connection Refused)
      updateScreen("Network Error", "API Timeout (-1)");
      Serial.printf("HTTP Request failed: %s\n", http.errorToString(httpCode).c_str());
    }
    http.end();
  } else {
    updateScreen("System Error", "Unable to connect");
  }
  
  delay(4000);
  updateScreen("System Ready", "Tap NFC Tag...");
}


void setup() {
  Serial.begin(115200);

  Wire.begin(21, 22);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED not found");
    while (true);
  }
  updateScreen("Booting up...");

  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi Connected!");
  updateScreen("Wi-Fi Connected!");

  nfc.begin();
  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    Serial.println("Didn't find PN53x board");
    updateScreen("NFC Error!", "Check wiring.");
    while (1);
  }
  
  nfc.SAMConfig();
  
  Serial.println("System Ready. Waiting for NFC tap...");
  updateScreen("System Ready", "Tap NFC Tag...");
}

void loop() {
  uint8_t uid[7];
  uint8_t uidLength;

  if (nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 100)) {
    
    Serial.println("\n--- Tag Detected ---");
    updateScreen("Scanning...", "Please hold tag still");
    
    const uint8_t firstPage = 4;
    const uint8_t lastPage  = 39;
    const int bufLen = (lastPage - firstPage + 1) * 4;

    uint8_t buf[bufLen];
    uint8_t pageData[4];
    int idx = 0;
    bool success = true;

    for (uint8_t page = firstPage; page <= lastPage; page++) {
      if (!readPageWithRetry(page, pageData)) {
        success = false;
        break;
      }
      for (int i = 0; i < 4; i++) buf[idx++] = pageData[i];
    }

    if (!success) {
      Serial.println("Read failed. Tag removed too quickly?");
      updateScreen("Read Failed", "Try again");
      delay(2000);
      updateScreen("System Ready", "Tap NFC Tag...");
      return;
    }

    String text = extractNdefTextFromPages(buf, bufLen);
    
    if (text.length() == 0) {
      Serial.println("No NDEF Text found on tag.");
      updateScreen("Tag Scanned", "No text found");
      delay(2000);
      updateScreen("System Ready", "Tap NFC Tag...");
    } else {
      Serial.print("Raw Tag Content: ");
      Serial.println(text);

      StaticJsonDocument<512> doc;
      DeserializationError error = deserializeJson(doc, text);

      if (!error) {
        const char* serial = doc["coin_id"] | "UNKNOWN";
        
        if (String(serial) != "UNKNOWN") {
           Serial.printf("Extracted Coin ID: %s\n", serial);
           executeTransfer(String(serial));
        } else {
           updateScreen("Invalid Tag", "No coin_id found");
           delay(2000);
           updateScreen("System Ready", "Tap NFC Tag...");
        }
      } else {
        Serial.println("Data is not JSON. Showing raw text.");
        updateScreen("Scanned Text:", text.substring(0, 20));
        delay(3000);
        updateScreen("System Ready", "Tap NFC Tag...");
      }
    }
  }
}
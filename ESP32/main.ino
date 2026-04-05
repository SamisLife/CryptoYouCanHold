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

// Global variables

// Network
const char* ssid = "xxxxx";          // hotspot name
const char* password = "xxxxx";  // hotspot password

// ngrok url
const String transferAPI = "https://ur-ngrok.dev/coins/transfer";
const String merchantWalletID = "wallet_person_2";

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

#define PN532_SS  5  
Adafruit_PN532 nfc(PN532_SS);

// OLED UI ENGINE

// Helper: Auto-centers text perfectly horizontally
void printCentered(String text, int y) {
  int16_t x1, y1;
  uint16_t w, h;
  display.getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  display.setCursor((SCREEN_WIDTH - w) / 2, y);
  display.print(text);
}

// Renders an inverted header bar with centered text below it
void ui_Screen(String title, String line1, String line2 = "") {
  display.clearDisplay();
  
  // Draw Inverted Title Bar
  display.fillRect(0, 0, SCREEN_WIDTH, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  printCentered(title, 2);
  
  // Draw Standard Body Text
  display.setTextColor(SSD1306_WHITE);
  
  if (line2.length() == 0) {
    // If only one line, center it vertically in the remaining space
    printCentered(line1, 19);
  } else {
    // If two lines, stack them
    printCentered(line1, 15);
    printCentered(line2, 24);
  }
  
  display.display();
}

// Special Full-Screen Success Animation
void ui_Success() {
  display.clearDisplay();
  // Draw full inverted screen
  display.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(2);
  printCentered("SUCCESS", 9);
  display.display();
  
  delay(1500); // Hold the big success screen
  
  // Transition to a sleek confirmation message
  ui_Screen("TRANSFER COMPLETE", "Ownership Secured", "Ledger Updated");
}

// Hardware helpers

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

// API Logic

void executeTransfer(String coinID) {
  ui_Screen("AUTHENTICATING", "Connecting to API...");
  Serial.println("Initiating Transfer API Call...");

  if (WiFi.status() != WL_CONNECTED) {
    ui_Screen("SYSTEM ERROR", "Wi-Fi Dropped", "Reconnecting...");
    WiFi.disconnect();
    WiFi.reconnect();
    delay(2000);
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.setTimeout(10000);

  if (http.begin(client, transferAPI)) {
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<200> reqDoc;
    reqDoc["coin_id"] = coinID;
    reqDoc["destination_wallet"] = merchantWalletID;
    
    String requestBody;
    serializeJson(reqDoc, requestBody);

    int httpCode = http.POST(requestBody);
    String responseBody = http.getString();
    
    if (httpCode > 0) {
      StaticJsonDocument<512> resDoc;
      DeserializationError error = deserializeJson(resDoc, responseBody);

      if (httpCode == 200 && !error) {
        // SUCCESS! Fire the premium animation
        ui_Success();
        Serial.println("Transfer Complete!");
        
      } else {
        String detailMsg = "Unknown Error";
        if (!error && resDoc.containsKey("detail")) {
            detailMsg = resDoc["detail"].as<String>();
        }
        // Substring limits length so it perfectly fits the screen
        ui_Screen("TRANSFER DENIED", detailMsg.substring(0, 20)); 
        Serial.println("Transfer Denied: " + detailMsg);
      }
    } else {
      ui_Screen("NETWORK ERROR", "API Timeout");
    }
    http.end();
  } else {
    ui_Screen("NETWORK ERROR", "Cannot Reach Host");
  }
  
  delay(4000);
  ui_Screen("SECURE POS", "Tap Physical Crypto");
}



void setup() {
  Serial.begin(115200);

  Wire.begin(21, 22);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED not found");
    while (true);
  }
  
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(2);
  printCentered("CH POS", 8);
  display.display();
  delay(1500);

  ui_Screen("NETWORK", "Connecting Wi-Fi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
  
  nfc.begin();
  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    ui_Screen("HARDWARE FAULT", "NFC Module Offline");
    while (1);
  }
  nfc.SAMConfig();
  
  ui_Screen("SECURE POS", "Tap Physical Crypto");
}

void loop() {
  uint8_t uid[7];
  uint8_t uidLength;

  if (nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 100)) {
    
    ui_Screen("SCANNING", "Hold card steady");
    
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
      ui_Screen("READ ERROR", "Tag removed too fast");
      delay(2000);
      ui_Screen("SECURE POS", "Tap Physical Crypto");
      return;
    }

    String text = extractNdefTextFromPages(buf, bufLen);
    
    if (text.length() == 0) {
      ui_Screen("INVALID MEDIA", "No data on tag");
      delay(2000);
      ui_Screen("SECURE POS", "Tap Physical Crypto");
    } else {

      StaticJsonDocument<512> doc;
      DeserializationError error = deserializeJson(doc, text);

      if (!error) {
        const char* serial = doc["coin_id"] | "UNKNOWN";
        
        if (String(serial) != "UNKNOWN") {
           executeTransfer(String(serial));
        } else {
           ui_Screen("INVALID TAG", "No coin ID found");
           delay(2000);
           ui_Screen("SECURE POS", "Tap Physical Crypto");
        }
      } else {
        ui_Screen("UNRECOGNIZED FORMAT", text.substring(0, 18));
        delay(3000);
        ui_Screen("SECURE POS", "Tap Physical Crypto");
      }
    }
  }
}
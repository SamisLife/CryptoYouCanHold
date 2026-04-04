// OLED GND → ESP32 GND
// OLED VCC → ESP32 3.3V
// OLED SDA → D21
// OLED SCL → D22
//
// PN532 SCK  → D18
// PN532 MISO → D19
// PN532 MOSI → D23
// PN532 SS   → D5

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <SPI.h>
#include <Adafruit_PN532.h>
#include <ArduinoJson.h>

// ===== OLED SETUP =====
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ===== PN532 (SPI) SETUP =====
#define PN532_SS  5  // Changed to D5
Adafruit_PN532 nfc(PN532_SS);

// Helper function to update the OLED screen
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

// Function to read NTAG pages reliably
bool readPageWithRetry(uint8_t page, uint8_t *data, int retries = 8) {
  for (int i = 0; i < retries; i++) {
    if (nfc.ntag2xx_ReadPage(page, data)) return true;
    delay(12);
  }
  return false;
}

// Function to extract NDEF text from raw page buffer
String extractNdefTextFromPages(const uint8_t *buf, int len) {
  int posT = -1;
  for (int i = 0; i < len; i++) {
    if (buf[i] == 0x54) { posT = i; break; } // 'T'
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

void setup() {
  Serial.begin(115200);

  // Initialize OLED
  Wire.begin(21, 22);  // SDA, SCK
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED not found");
    while (true);
  }
  
  updateScreen("Booting up...");

  // Initialize NFC
  nfc.begin();
  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    Serial.println("Didn't find PN53x board");
    updateScreen("NFC Error!", "Check wiring.");
    while (1); // Halt
  }
  
  nfc.SAMConfig();
  
  Serial.println("System Ready. Waiting for NFC tap...");
  updateScreen("System Ready", "Tap NFC Tag...");
}

void loop() {
  uint8_t uid[7];
  uint8_t uidLength;

  // Wait for an ISO14443A type cards (Mifare, etc.).
  if (nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 100)) {
    
    Serial.println("\n--- Tag Detected ---");
    updateScreen("Scanning...", "Please hold tag still");
    
    // Read pages 4 to 39
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

    // Extract text payload
    String text = extractNdefTextFromPages(buf, bufLen);
    
    if (text.length() == 0) {
      Serial.println("No NDEF Text found on tag.");
      updateScreen("Tag Scanned", "No text found");
    } else {
      Serial.print("Raw Tag Content: ");
      Serial.println(text);

      // Attempt to parse JSON if it exists
      StaticJsonDocument<512> doc;
      DeserializationError error = deserializeJson(doc, text);

      if (!error) {
        // It's JSON!
        const char* serial   = doc["coin_id"] | "UNKNOWN";
        const char* currency = doc["currency"] | "";
        int value            = doc["value"] | 0;

        Serial.printf("Parsed -> Serial: %s, Value: %d %s\n", serial, value, currency);
        
        // Display parsed data on OLED (max 128x32 fits roughly 3-4 lines of text size 1)
        updateScreen(
          String("SN: ") + String(serial),
          String("Val: ") + String(value) + " " + String(currency)
        );
      } else {
        // Not JSON, just display the raw text
        Serial.println("Data is not JSON. Showing raw text.");
        updateScreen("Scanned Text:", text.substring(0, 20)); // Limit to 20 chars so it doesn't overflow
      }
    }

    delay(3000);
    updateScreen("System Ready", "Tap NFC Tag...");
  }
}
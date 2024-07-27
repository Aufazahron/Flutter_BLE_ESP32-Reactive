#include <SPI.h>
#include <SD.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

const int chipSelect = 5; // Pin untuk CS SD card module
BLECharacteristic *pCharacteristic;
BLEServer *pServer;
BLEService *pService;
bool deviceConnected = false;
bool oldDeviceConnected = false;
bool sendData = false;

// Callback class for handling connections and disconnections
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

// Callback class for handling read and write requests
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue();

      if (value.length() > 0) {
        Serial.print("Received Value: ");
        for (int i = 0; i < value.length(); i++) {
          Serial.print(value[i]);
        }
        Serial.println();
        // If the received value is "send", set sendData to true
        if (value == "send") {
          sendData = true;
        }
      }
    }
};

void setup() {
  Serial.begin(115200);

  // Create the BLE Device
  BLEDevice::init("ESP32");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  pCharacteristic->setCallbacks(new MyCallbacks());

  // Start the service
  pService->start();

  // Start advertising
  pServer->getAdvertising()->start();
  Serial.println("Waiting for a client connection to notify...");
  BLEDevice::setMTU(200);

  // Initialize SD card
  if (!SD.begin(chipSelect)) {
    Serial.println("Inisialisasi kartu SD gagal!");
    return;
  }
  Serial.println("Kartu SD berhasil diinisialisasi.");
}

void loop() {
  // Notify client if connected and sendData is true
  if (deviceConnected && sendData) {
    sendFile("/sensor_data.csv");
    sendData = false;  // Reset sendData after sending
  }

  // Check for device disconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // restart advertising
    Serial.println("Start advertising");
    oldDeviceConnected = deviceConnected;
  }

  // Check for new device connection
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}

// Function to read file from SD card and send via BLE
void sendFile(const char *filename) {
  File file = SD.open(filename);
  
  if (!file) {
    Serial.println("Gagal membuka file");
    return;
  }

  Serial.println("Membaca dan mengirim file:");
  
  while (file.available()) {
    String line = file.readStringUntil('\n');
    pCharacteristic->setValue(line.c_str());
    pCharacteristic->notify();
    Serial.println(line);
    delay(1); // delay to ensure data is sent correctly
  }
  
  file.close();
}

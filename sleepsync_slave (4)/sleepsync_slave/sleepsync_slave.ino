#include <SPI.h>

extern "C" {
  void slave_main();
  void printDebug(const char* msg);
  void setTemperature(uint8_t temp);
}

// Global variable
volatile uint8_t currentTemperature = 25;

void printDebug(const char* msg) {
  Serial.println(msg);
}

void setTemperature(uint8_t temp) {
  currentTemperature = temp;
  SPDR = temp; // Siapkan data untuk dikirim ke Master via SPI
}

extern "C" void debugSensors(uint8_t temp, uint8_t light, uint8_t motion) {
  char buf[60];
  sprintf(buf, "Suhu: %dC | Cahaya: %d | Gerak: %d", temp, light, motion);
  Serial.println(buf);
}

extern "C" void slave_main();

void setup() {
  Serial.begin(9600);
  
  // Inisialisasi SPI Slave
  pinMode(MISO, OUTPUT);
  SPCR = (1 << SPE); 

  // PANGGIL KEMBALI FUNGSI UTAMA ASSEMBLY
  slave_main(); 
}

void loop() {
  // Kosong karena kontrol diambil alih Assembly
}
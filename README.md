# SleepSync Alarm 

SleepSync Alarm adalah sistem alarm cerdas berbasis mikrokontroler ATmega328P yang dirancang untuk membantu meningkatkan kualitas tidur pengguna dengan memanfaatkan teknologi *embedded system*. Berbeda dari alarm konvensional yang bekerja kaku berbasis waktu, SleepSyncAlarm mengintegrasikan pemantauan kondisi lingkungan secara *real-time* dan mekanisme verifikasi bertingkat untuk memastikan pengguna benar-benar terbangun secara optimal tanpa mengalami *sleep inertia*
Sistem ini diimplementasikan menggunakan arsitektur **Master-Slave** yang membagi beban kerja antara dua buah Arduino Uno guna memastikan proses pemantauan dan pengolahan data berjalan stabil.

---

## 👥 Contributors

**Group 6 (Universitas Indonesia)** 
*  **Kayla Joanna Irsy K.** (2406487014) – *Project Idea, Writing and Coding* 
* **Safina Amarani** (2406415665) – *Designing And Writing* 
* **Djukallita Tafiana D.** (2406416573) – *Writing and Physical Circuit* 
* **Thalita Salma Artanti** (2406419354) – *Coding DHT11, GitHub, and Proteus* 

---

## 📌 Features

* **Arsitektur Master-Slave:** Menggunakan dua buah mikrokontroler untuk efisiensi pembacaan sensor (*Slave*) dan pusat kendali utama (*Master*)
* **Smart Sleep Monitoring:** Menganalisis kondisi ideal ruangan (kondisi gelap dan suhu yang sesuai) untuk masuk ke mode monitoring tidur.
* **Akurasi Waktu Real-Time:** Memanfaatkan modul RTC DS3232 eksternal untuk presisi penjadwalan alarm yang tinggi
* **Mekanisme Verifikasi Bertingkat:** Mencegah penonaktifan alarm secara refleks (tidak bisa dimatikan hanya dengan satu tombol biasa) dan mewajibkan interaksi kognitif manual tertentu
* **Otomatisasi Siklus:** Sistem otomatis melakukan *reset* dan kembali ke mode *standby/monitoring* awal setelah pengguna berhasil bangun.

---

## 🛠️ Components

### Hardware Components
* Mikrokontroler ATmega328P (Arduino Uno) 
* Sensor Suhu dan Kelembaban DHT11 
* Sensor Cahaya LDR (*Light Dependent Resistor*) 
* Modul RTC DS3232
*LCD Display (16x2) 
* Buzzer & LED (Indikator Alarm) 
*Push Button (Simulasi Aktivasi & Interaksi Pengguna) 
* Resistor 1k Ohm, Kabel Jumper, & Breadboard

### Software Tools
* **Arduino IDE:** Untuk pemrograman logika sistem
* **Proteus Design Suite:** Untuk perancangan skematik dan simulasi sirkuit

---

## 🧾 Project Structure

```text
SleepSyncAlarm/
├── src/
│   ├── Master_Controller/
│   │   └── Master_Controller.ino   # Logika Arduino Master (RTC, LCD, Kontrol Output)
│   └── Slave_Sensors/
│       └── Slave_Sensors.ino       # Logika Arduino Slave (Akuisisi Data DHT11, LDR, Button)
├── proteus/
│   └── SleepSync_Simulation.pdsprj # File simulasi rangkaian di Proteus
├── docs/
│   ├── Laporan_Proyek_Akhir_MBD_Kelompok_6.pdf
│   └── Flowchart_Sistem.png
└── README.md                       # Dokumentasi proyek ini

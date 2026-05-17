;====================================================
; SleepSync - Complete Assembly Implementation (FINAL)
;====================================================
#define __SFR_OFFSET 0x00
#include "avr/io.h"

;— Constants —
; SPI related
.equ SS_PIN,         2       ; PB2 (Arduino pin 10)
.equ MOSI_PIN,       3       ; PB3 (Arduino pin 11)
.equ MISO_PIN,       4       ; PB4 (Arduino pin 12)
.equ SCK_PIN,        5       ; PB5 (Arduino pin 13)

; Timing constants
.equ US_COUNT,       90
.equ MS_COUNT,       40
.equ TEMP_UPDATE_TIME, 2     ; seconds between temperature updates

; LCD display related
.equ LCD_EN,         0       ; EN pin on PB1 (LCD Enable)
.equ LCD_RS,         1       ; RS pin on PB0 (Register Select)

; DS3231 RTC related
.equ DS3231_ADDR,    0x68    ; DS3231 I2C address
.equ SDA_PIN,        4       ; PC4 (Analog pin A4) for I2C data
.equ SCL_PIN,        5       ; PC5 (Analog pin A5) for I2C clock
.equ SDA_PORT,       PORTC   ; PORT register for SDA
.equ SCL_PORT,       PORTC   ; PORT register for SCL
.equ SDA_DDR,        DDRC    ; Data direction register for SDA
.equ SCL_DDR,        DDRC    ; Data direction register for SCL
.equ SDA_PIN_REG,    PINC    ; PIN register for SDA

.equ TEMP_STORAGE,   0x0600   ; SRAM address to store temperature

.global sleepsync_main           
.global request_spi_temperature_asm  ; Get temperature via SPI
.global ds3231_init                  ; Initialize DS3231
.global ds3231_set_time              ; Set time 
.global ds3231_set_date              ; Set date 
.global ds3231_read_time             ; Read time into SRAM buffer
.global ds3231_read_temp             ; Read temperature

.extern LCD_init_asm
.extern LCD_command_asm
.extern LCD_data_asm
.extern LCD_update_temp_asm
.extern debugPrintDateTime    

; Main entry point
sleepsync_main:
    ; Initialize SPI interface
    RCALL spi_init
    
    ; Initialize I2C and DS3231
    RCALL ds3231_init
    
    ; Set initial time and date (in BCD format)
    LDI   R24, 0x00      ; Seconds (00-59 in BCD)
    LDI   R22, 0x30      ; Minutes (00-59 in BCD)  
    LDI   R20, 0x14      ; Hours (00-23 in BCD)
    RCALL ds3231_set_time
    
    LDI   R24, 0x06      ; Day of week (1=Sunday, 7=Saturday)
    LDI   R22, 0x18      ; Day of month (01-31 in BCD)
    LDI   R20, 0x05      ; Month (01-12 in BCD)
    LDI   R18, 0x25      ; Year (00-99 in BCD)
    RCALL ds3231_set_date
    
    ; Initialize LCD
    CALL  LCD_init_asm
    
    ; Show initial welcome message
    RCALL display_welcome
    
; Main loop 
main_loop:
    LDI   R16, 0                 ; 0 = use SPI
    RCALL request_spi_temperature_asm
    
temp_read_done:
    MOV   R16, R24               ; R16 = Simpan Byte paket dari Slave
    
    ; --- Tampilkan Suhu Murni ---
    LDI   R24, 0x80              
    CALL  LCD_command_asm
    
    ; Cetak "Temp: "
    LDI   R24, 'T'
    CALL  LCD_data_asm
    LDI   R24, 'e'
    CALL  LCD_data_asm
    LDI   R24, 'm'
    CALL  LCD_data_asm
    LDI   R24, 'p'
    CALL  LCD_data_asm
    LDI   R24, ':'
    CALL  LCD_data_asm
    LDI   R24, ' '
    CALL  LCD_data_asm
    
    MOV   R24, R16
    ANDI  R24, 0x7F              
    CALL  LCD_update_temp_asm    ; Cetak "XX°C" di LCD

    LDI   R24, 0x8A              
    CALL  LCD_command_asm

    ; AUTOMATIC TIMER 5 JAM
    SBRS  R16, 7                 ; Cek bit ke-7 
    RJMP  kondisi_bangun

kondisi_tidur:
    LDS   R17, 0x0610            ; Baca status TIMER_ACTIVE di SRAM
    CPI   R17, 1                 ; Apakah timer sudah berjalan?
    BREQ  timer_berhitung        ; Jika iya, lanjut hitung mundur
    CPI   R17, 2                 ; Apakah sudah fase ALARM?
    BREQ  tampilkan_alarm        ; Jika iya, tetap nyalakan alarm
    
    ; JIKA BARU PERTAMA KALI DETEKSI TIDUR:
    LDI   R17, 1                 
    STS   0x0610, R17            ; Set TIMER_ACTIVE = 1
    LDI   R17, 15                ; Set durasi timer untuk DEMO (15 Ticks)
    STS   0x0611, R17            ; Simpan di TIMER_VAL
    RJMP  timer_berhitung

kondisi_bangun:
    LDI   R17, 0
    STS   0x0610, R17            ; TIMER_ACTIVE = 0 (Mati)
    STS   0x0611, R17            ; Reset nilai timer
    CBI   PORTB, 5               ; Matikan LED/Buzzer Alarm Pin 13
    
    ; Tampilkan status [AWK] (Awake)
    LDI   R24, '['
    CALL  LCD_data_asm
    LDI   R24, 'A'
    CALL  LCD_data_asm
    LDI   R24, 'W'
    CALL  LCD_data_asm
    LDI   R24, 'K'
    CALL  LCD_data_asm
    LDI   R24, ']'
    CALL  LCD_data_asm
    LDI   R24, ' '               ; Hapus sisa karakter
    CALL  LCD_data_asm
    RJMP  refresh_display_jam

timer_berhitung:
    LDS   R17, 0x0611            ; Ambil sisa waktu timer
    SUBI  R17, 1                 ; Kurangi 1 tick
    STS   0x0611, R17            ; Simpan kembali
    
    CPI   R17, 0                 ; Cek apakah waktu sudah habis?
    BRNE  tampilkan_countdown    ; Jika belum, tampilkan sisa waktu
    
    ; JIKA TIMER HABIS (SUDAH TIDUR 5 JAM):
    LDI   R17, 2                 
    STS   0x0610, R17            ; Set TIMER_ACTIVE = 2 (Fase Alarm)
    SBI   PORTB, 5               ; NYALAKAN LED ALARM PIN 13!
    RJMP  tampilkan_alarm

tampilkan_countdown:
    ; Tampilkan animasi [Zzz]
    LDI   R24, '['
    CALL  LCD_data_asm
    LDI   R24, 'Z'
    CALL  LCD_data_asm
    LDI   R24, 'z'
    CALL  LCD_data_asm
    LDI   R24, 'z'
    CALL  LCD_data_asm
    LDI   R24, ']'
    CALL  LCD_data_asm
    LDI   R24, ' '
    CALL  LCD_data_asm
    RJMP  refresh_display_jam

tampilkan_alarm:
    ; Tampilkan teks [ALRM]
    LDI   R24, '['
    CALL  LCD_data_asm
    LDI   R24, 'A'
    CALL  LCD_data_asm
    LDI   R24, 'L'
    CALL  LCD_data_asm
    LDI   R24, 'R'
    CALL  LCD_data_asm
    LDI   R24, 'M'
    CALL  LCD_data_asm
    LDI   R24, ']'
    CALL  LCD_data_asm

refresh_display_jam:
    ; Cetak data waktu RTC ke baris kedua LCD seperti biasa
    RCALL ds3231_read_time
    RCALL display_date_time
    
    ; Cetak ke serial terminal Master
    LDS   R24, TEMP_STORAGE+1
    LDS   R22, TEMP_STORAGE+2
    LDS   R20, TEMP_STORAGE+3
    LDS   R18, TEMP_STORAGE+4
    LDS   R16, TEMP_STORAGE+5
    LDS   R14, TEMP_STORAGE+6
    LDS   R12, TEMP_STORAGE+7
    CALL  debugPrintDateTime

    ; Delay putaran loop (2 detik)
    LDI   R17, TEMP_UPDATE_TIME
delay_loop:
    RCALL delay_seconds
    DEC   R17
    BRNE  delay_loop
    RJMP  main_loop
    
; SPI Initialization Function
spi_init:
    ; Configure SPI pins
    SBI   DDRB, MOSI_PIN     ; MOSI as OUTPUT
    CBI   DDRB, MISO_PIN     ; MISO as INPUT  
    SBI   DDRB, SCK_PIN      ; SCK as OUTPUT
    SBI   DDRB, SS_PIN       ; SS as OUTPUT
    SBI   PORTB, SS_PIN      ; SS HIGH initially
    
    ; Configure SPI: Enable, Master mode, Clock / 16
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16
    SBI   DDRB, 5                ; Set PB5 (Digital Pin 13) sebagai OUTPUT untuk Alarm
    CBI   PORTB, 5               ; Pastikan mati di awal
    
    RET

; Display welcome message on LCD
display_welcome:
    ; Clear display first
    LDI   R24, 0x01
    CALL  LCD_command_asm
    RCALL delay_ms
    
    ; Set to first line, first position
    LDI   R24, 0x80
    CALL  LCD_command_asm
    
    ; Display "SleepSync" on first line
    LDI   R24, 'S'
    CALL  LCD_data_asm
    LDI   R24, 'l'
    CALL  LCD_data_asm
    LDI   R24, 'e'
    CALL  LCD_data_asm
    LDI   R24, 'e'
    CALL  LCD_data_asm
    LDI   R24, 'p'
    CALL  LCD_data_asm
    LDI   R24, 'S'
    CALL  LCD_data_asm
    LDI   R24, 'y'
    CALL  LCD_data_asm
    LDI   R24, 'n'
    CALL  LCD_data_asm
    LDI   R24, 'c'
    CALL  LCD_data_asm
    
    ; Set to second line, first position
    LDI   R24, 0xC0
    CALL  LCD_command_asm
    
    ; Display "v1.0" on second line
    LDI   R24, 'v'
    CALL  LCD_data_asm
    LDI   R24, '1'
    CALL  LCD_data_asm
    LDI   R24, '.'
    CALL  LCD_data_asm
    LDI   R24, '0'
    CALL  LCD_data_asm
    
    ; Short delay to show welcome message
    LDI   R17, 4
welcome_delay:
    RCALL delay_seconds
    DEC   R17
    BRNE  welcome_delay
    
    RET

; Request temperature via SPI 
request_spi_temperature_asm:
    PUSH  R16
    PUSH  R17
    PUSH  R20
    PUSH  R21
    
    ; Try up to 3 times to get valid reading
    LDI   R20, 3
    
retry_spi:
    ; Select slave (SS low)
    CBI   PORTB, SS_PIN
    
    ; Small delay for slave to prepare
    LDI   R21, 40
us_delay_loop:
    NOP
    NOP
    NOP
    DEC   R21
    BRNE  us_delay_loop
    
    ; Send command 0x00
    LDI   R16, 0x00
    OUT   SPDR, R16
    
    ; Wait for transfer to complete
wait_spi:
    IN    R17, SPSR
    SBRS  R17, SPIF
    RJMP  wait_spi
    
    ; Read result
    IN    R16, SPDR
    
    ; Deselect slave (SS high)
    SBI   PORTB, SS_PIN
    
    ; Check if reading is valid (≥ 2)
    CPI   R16, 2
    BRSH  valid_reading
    
    ; Try again if attempts remain
    DEC   R20
    BRNE  retry_spi
    
    ; >>> ANTI-GLITCH: JIKA SPI GAGAL TOTAL, AMBIL DATA TERAKHIR <<<
    LDS   R16, TEMP_STORAGE      
    RJMP  return_spi
    
valid_reading:
    ; Store temperature in SRAM for reference
    STS   TEMP_STORAGE, R16
    
return_spi:
    ; Return value in R24 (C calling convention)
    MOV   R24, R16
    
    POP   R21
    POP   R20
    POP   R17
    POP   R16
    RET

; I2C bit-banging implementation 
i2c_init:
    CBI   SDA_PORT, SDA_PIN
    CBI   SCL_PORT, SCL_PIN
    CBI   SDA_DDR, SDA_PIN
    CBI   SCL_DDR, SCL_PIN
    RET

i2c_start:
    CBI   SDA_DDR, SDA_PIN   
    CBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    SBI   SDA_DDR, SDA_PIN   
    RCALL i2c_delay
    SBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    RET

i2c_stop:
    SBI   SDA_DDR, SDA_PIN   
    RCALL i2c_delay
    CBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    CBI   SDA_DDR, SDA_PIN   
    RCALL i2c_delay
    RET

i2c_write_byte:
    PUSH  R16
    PUSH  R17
    LDI   R16, 8
    MOV   R17, R24
i2c_write_bit:
    ROL   R17
    BRCS  i2c_write_one
    SBI   SDA_DDR, SDA_PIN   
    RJMP  i2c_write_clock
i2c_write_one:
    CBI   SDA_DDR, SDA_PIN   
i2c_write_clock:
    RCALL i2c_delay
    CBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    SBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    DEC   R16
    BRNE  i2c_write_bit
    
    CBI   SDA_DDR, SDA_PIN   
    RCALL i2c_delay
    CBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    IN    R16, SDA_PIN_REG
    ANDI  R16, (1<<SDA_PIN)
    SBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    MOV   R24, R16
    POP   R17
    POP   R16
    RET

i2c_read_byte:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    MOV   R18, R24           
    LDI   R17, 0
    LDI   R16, 8
    CBI   SDA_DDR, SDA_PIN   
i2c_read_bit:
    RCALL i2c_delay
    CBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    LSL   R17
    IN    R24, SDA_PIN_REG
    SBRC  R24, SDA_PIN
    ORI   R17, 1
    SBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    DEC   R16
    BRNE  i2c_read_bit
    
    CPI   R18, 0
    BREQ  i2c_send_ack
    CBI   SDA_DDR, SDA_PIN   
    RJMP  i2c_ack_clock
i2c_send_ack:
    SBI   SDA_DDR, SDA_PIN   
i2c_ack_clock:
    RCALL i2c_delay
    CBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    SBI   SCL_DDR, SCL_PIN   
    RCALL i2c_delay
    CBI   SDA_DDR, SDA_PIN   
    MOV   R24, R17
    POP   R18
    POP   R17
    POP   R16
    RET

i2c_delay:
    PUSH  R16
    LDI   R16, 10
i2c_delay_loop:
    NOP
    DEC   R16
    BRNE  i2c_delay_loop
    POP   R16
    RET

; DS3231 RTC Implementation
ds3231_init:
    RCALL i2c_init
    RCALL i2c_delay
    RCALL i2c_start
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    LDI   R24, 0x0F
    RCALL i2c_write_byte
    RCALL i2c_start
    LDI   R24, ((DS3231_ADDR << 1) | 1)
    RCALL i2c_write_byte
    LDI   R24, 1
    RCALL i2c_read_byte
    MOV   R16, R24
    RCALL i2c_stop
    ANDI  R16, 0x7F
    RCALL i2c_start
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    LDI   R24, 0x0F
    RCALL i2c_write_byte
    MOV   R24, R16
    RCALL i2c_write_byte
    RCALL i2c_stop
    RET

ds3231_set_time:
    PUSH  R24
    PUSH  R22
    PUSH  R20
    RCALL i2c_start
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    LDI   R24, 0x00
    RCALL i2c_write_byte
    POP   R20
    POP   R22
    POP   R24
    PUSH  R24
    RCALL i2c_write_byte
    MOV   R24, R22
    RCALL i2c_write_byte
    MOV   R24, R20
    RCALL i2c_write_byte
    RCALL i2c_stop
    POP   R24
    RET

ds3231_set_date:
    PUSH  R24
    PUSH  R22
    PUSH  R20
    PUSH  R18
    RCALL i2c_start
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    LDI   R24, 0x03
    RCALL i2c_write_byte
    POP   R18
    POP   R20
    POP   R22
    POP   R24
    PUSH  R24
    RCALL i2c_write_byte
    MOV   R24, R22
    RCALL i2c_write_byte
    MOV   R24, R20
    RCALL i2c_write_byte
    MOV   R24, R18
    RCALL i2c_write_byte
    RCALL i2c_stop
    POP   R24
    RET

ds3231_read_time:
    RCALL i2c_start
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    LDI   R24, 0x00
    RCALL i2c_write_byte
    RCALL i2c_start
    LDI   R24, ((DS3231_ADDR << 1) | 1)
    RCALL i2c_write_byte
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+1, R24   
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+2, R24   
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+3, R24   
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+4, R24   
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+5, R24   
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+6, R24   
    LDI   R24, 1
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+7, R24   
    RCALL i2c_stop
    RET

ds3231_read_temp:
    RCALL i2c_start
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    LDI   R24, 0x11
    RCALL i2c_write_byte
    RCALL i2c_start
    LDI   R24, ((DS3231_ADDR << 1) | 1)
    RCALL i2c_write_byte
    LDI   R24, 1
    RCALL i2c_read_byte
    MOV   R16, R24
    RCALL i2c_stop
    MOV   R24, R16
    RET

; Display Date and Time from RTC on LCD
display_date_time:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    
    LDI   R24, 0xC0
    CALL  LCD_command_asm
    
    LDS   R16, TEMP_STORAGE+6
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        
    ANDI  R16, 0x0F        
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    LDI   R24, '/'
    CALL  LCD_data_asm
    
    LDS   R16, TEMP_STORAGE+5
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        
    ANDI  R16, 0x0F        
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    LDI   R24, '/'
    CALL  LCD_data_asm
    
    LDS   R16, TEMP_STORAGE+7
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        
    ANDI  R16, 0x0F        
    LDI   R24, '2'
    CALL  LCD_data_asm
    LDI   R24, '0'
    CALL  LCD_data_asm
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    LDI   R24, ' '
    CALL  LCD_data_asm
    
    LDS   R16, TEMP_STORAGE+3
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        
    ANDI  R16, 0x0F        
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    LDI   R24, ':'
    CALL  LCD_data_asm
    
    LDS   R16, TEMP_STORAGE+2
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        
    ANDI  R16, 0x0F        
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     
    
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

; Delay functions
delay_short:
    NOP
    NOP
    RET

delay_us:
    LDI   R20, US_COUNT
us_loop:
    RCALL delay_short
    DEC   R20
    BRNE  us_loop
    RET

delay_ms:
    LDI   R21, MS_COUNT
ms_loop:
    RCALL delay_us
    DEC   R21
    BRNE  ms_loop
    RET

delay_seconds:
    LDI   R20, 255          
ds_loop1:
    LDI   R21, 255          
ds_loop2:
    LDI   R22, 20           
ds_loop3:
    DEC   R22               
    BRNE  ds_loop3          
    DEC   R21               
    BRNE  ds_loop2          
    DEC   R20               
    BRNE  ds_loop1          
    RET
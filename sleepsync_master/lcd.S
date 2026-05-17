;====================================================
; SleepSync Alarm - LCD 4-bit Mode Driver (Base Code)
;====================================================
#define __SFR_OFFSET 0x00
#include <avr/io.h>

; RS dan EN dihubungkan ke PORTB (Pin 9 dan Pin 8 Arduino)
.equ LCD_RS, 1          ; PB1 (Arduino Pin 9)
.equ LCD_EN, 0          ; PB0 (Arduino Pin 8)
.equ LCD_PORT_CTRL, PORTB
.equ LCD_DDR_CTRL, DDRB

; Pin Data D4-D7 dihubungkan ke PORTD (Pin 4, 5, 6, 7 Arduino)
.equ LCD_PORT_DATA, PORTD
.equ LCD_DDR_DATA, DDRD

; Deklarasi fungsi agar bisa dipanggil oleh master.S
.global LCD_init_asm
.global LCD_command_asm
.global LCD_data_asm
.global LCD_update_temp_asm

; Inisialisasi LCD (Mode 4-bit)
LCD_init_asm:
    SBI LCD_DDR_CTRL, LCD_RS
    SBI LCD_DDR_CTRL, LCD_EN
    IN  R16, LCD_DDR_DATA
    ORI R16, 0xF0
    OUT LCD_DDR_DATA, R16

    LDI R24, 255        
    RCALL lcd_delay_ms
    LDI R24, 255
    RCALL lcd_delay_ms

    LDI R24, 0x33
    RCALL LCD_command_asm
    LDI R24, 5          
    RCALL lcd_delay_ms

    LDI R24, 0x32
    RCALL LCD_command_asm
    LDI R24, 5
    RCALL lcd_delay_ms

    LDI R24, 0x28
    RCALL LCD_command_asm
    
    LDI R24, 0x0C
    RCALL LCD_command_asm
    
    LDI R24, 0x01
    RCALL LCD_command_asm
    LDI R24, 5
    RCALL lcd_delay_ms
    RET

; Kirim Perintah (Command) ke LCD -> R24
LCD_command_asm:
    PUSH R16
    CBI  LCD_PORT_CTRL, LCD_RS   ; RS = 0 untuk Command
    RCALL lcd_send_byte
    LDI  R24, 2
    RCALL lcd_delay_ms           ; Beri waktu LCD memproses
    POP  R16
    RET

; Kirim Data/Karakter ke LCD -> R24
LCD_data_asm:
    PUSH R16
    SBI  LCD_PORT_CTRL, LCD_RS   ; RS = 1 untuk Data
    RCALL lcd_send_byte
    LDI  R24, 1
    RCALL lcd_delay_ms           ; Beri waktu LCD memproses
    POP  R16
    RET

; Logika Pengiriman Byte dalam Mode 4-bit 
lcd_send_byte:
    PUSH R16
    PUSH R17
    PUSH R24                    ; data asli R24 ke Stack

    ; 1. Kirim 4-bit atas (High Nibble)
    IN   R16, LCD_PORT_DATA
    ANDI R16, 0x0F              ; Bersihkan PD4-PD7, biarkan PD0-PD3
    MOV  R17, R24
    ANDI R17, 0xF0              ; Ambil 4 bit atas
    OR   R16, R17               ; Gabungkan
    OUT  LCD_PORT_DATA, R16
    RCALL lcd_pulse_en          ; Sinyal EN (R24 akan hancur jadi 0 di sini)

    POP  R24                    
    PUSH R24                    

    ; 2. Kirim 4-bit bawah (Low Nibble)
    IN   R16, LCD_PORT_DATA
    ANDI R16, 0x0F              ; Bersihkan PD4-PD7 lagi
    MOV  R17, R24
    SWAP R17                    ; Pindahkan 4 bit bawah ke posisi atas
    ANDI R17, 0xF0              ; Ambil 4 bit yang sudah pindah ke atas
    OR   R16, R17               ; Gabungkan
    OUT  LCD_PORT_DATA, R16
    RCALL lcd_pulse_en          ; Sinyal EN

    POP  R24                    
    POP  R17
    POP  R16
    RET

; Memberi sinyal Pulse pada pin Enable (EN)
lcd_pulse_en:
    SBI  LCD_PORT_CTRL, LCD_EN   
    LDI  R24, 2                  
    RCALL lcd_delay_ms           
    CBI  LCD_PORT_CTRL, LCD_EN   
    LDI  R24, 2                  
    RCALL lcd_delay_ms           
    RET

; Menampilkan Suhu 
LCD_update_temp_asm:
    PUSH R16
    PUSH R17
    PUSH R18

    MOV  R16, R24                ; R16 = Nilai Suhu (misal 32)
    CLR  R17                     ; Register untuk angka Puluhan
    CLR  R18                     ; Register untuk angka Satuan

calc_digits:
    CPI  R16, 10
    BRLO finish_digits           ; Jika sisa < 10, perhitungan selesai
    SUBI R16, 10                 ; Kurangi 10
    INC  R17                     ; Tambah 1 ke puluhan
    RJMP calc_digits
    
finish_digits:
    MOV  R18, R16                ; Sisa pengurangan adalah angka satuan

    ; Cetak Angka Puluhan
    MOV  R24, R17
    ORI  R24, 0x30               ; Konversi angka asli ke ASCII
    RCALL LCD_data_asm

    ; Cetak Angka Satuan
    MOV  R24, R18
    ORI  R24, 0x30               ; Konversi angka asli ke ASCII
    RCALL LCD_data_asm

    ; Cetak Simbol Derajat 'C'
    LDI  R24, 0xDF               ; Kode ASCII untuk simbol derajat '°'
    RCALL LCD_data_asm
    LDI  R24, 'C'
    RCALL LCD_data_asm

    POP  R18
    POP  R17
    POP  R16
    RET

; Fungsi Delay Sederhana
lcd_delay_short:
    PUSH R16
    LDI  R16, 100
lds_loop:
    DEC  R16
    BRNE lds_loop
    POP  R16
    RET

lcd_delay_ms:
    ; R24 = jumlah milidetik (ms)
    PUSH R24
    PUSH R25
    PUSH R26
ldm_outer:
    LDI  R26, 16      ; Faktor 16 untuk kecepatan clock 16MHz Arduino
ldm_mid:
    LDI  R25, 200     ; Loop dalam: 5 siklus instruksi * 200 = 1000 siklus
ldm_inner:
    NOP
    NOP
    DEC  R25
    BRNE ldm_inner
    DEC  R26
    BRNE ldm_mid
    DEC  R24
    BRNE ldm_outer
    POP  R26
    POP  R25
    POP  R24
    RET
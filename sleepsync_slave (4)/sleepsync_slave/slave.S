;============================================================
; SleepSync - SLAVE
;============================================================

#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global slave_main
.extern printDebug
.extern debugSensors

.data
msg_start:      .asciz "Starting SleepSync Slave..."

.text
slave_main:
    ; Matikan Timer 0 bawaan Arduino
    LDI     R16, (1<<WGM01)
    OUT     TCCR0A, R16
    
    ; Setup Button (D3) dan LED Merah (A1)
    CBI     DDRD, 3
    CBI     PORTD, 3
    SBI     DDRC, 1
    CBI     PORTC, 1
    
    ; Setup ADC LDR (A0)
    LDI     R16, (1<<REFS0) | (1<<ADLAR) | 0
    STS     ADMUX, R16
    LDI     R16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    STS     ADCSRA, R16
    
    SBI     DDRB, 4              ; MISO = Output
    CBI     DDRB, 3              ; MOSI = Input
    CBI     DDRB, 5              ; SCK = Input
    CBI     DDRB, 2              ; SS = Input
    SBI     PORTB, 2             ; Pull-up SS (Anti Hantu!)
    
    LDI     R16, (1<<SPE)        ; Nyalakan SPI Hardware Slave
    OUT     SPCR, R16
    
    LDI     R24, lo8(msg_start)
    LDI     R25, hi8(msg_start)
    CALL    printDebug

main_loop:
    RCALL   delay_2s

    SBI     DDRB, 1
    CBI     PORTB, 1
    RCALL   delay_20ms
    CBI     DDRB, 1
    SBI     PORTB, 1
    
wait_resp_low:
    LDI     R24, 0
    LDI     R25, 40
wrl_loop:
    SBIW    R24, 1
    BREQ    error_1
    SBIC    PINB, 1
    RJMP    wrl_loop
    
wait_resp_high:
    LDI     R24, 0
    LDI     R25, 40
wrh_loop:
    SBIW    R24, 1
    BREQ    error_2
    SBIS    PINB, 1
    RJMP    wrh_loop
    
wait_data_start:
    LDI     R24, 0
    LDI     R25, 40
wds_loop:
    SBIW    R24, 1
    BREQ    error_3
    SBIC    PINB, 1
    RJMP    wds_loop
    
    ; BACA FULL 5 BYTE AGAR SENSOR SEHAT
    RCALL   DHT11_read_byte
    RCALL   DHT11_read_byte
    RCALL   DHT11_read_byte
    MOV     R17, R18             ; Simpan Suhu Asli
    RCALL   DHT11_read_byte
    RCALL   DHT11_read_byte
    
    CPI     R17, 0
    BREQ    error_4
    RJMP    read_other_sensors

error_1: 
error_2: 
error_3: 
error_4: 
    LDI     R17, 0               ; Jika error, suhu 0

read_other_sensors:
    LDI   R16, (1<<REFS0) | (1<<ADLAR) | 0
    STS   ADMUX, R16
    LDS   R16, ADCSRA
    ORI   R16, (1<<ADSC)
    STS   ADCSRA, R16
wait_adc:
    LDS   R16, ADCSRA
    SBRC  R16, ADSC
    RJMP  wait_adc
    LDS   R20, ADCH

    CLR   R21                    
    SBIC  PIND, 3
    LDI   R21, 1                 

    CLR   R25                    
    
    CPI   R17, 24
    BRSH  suhu_hangat
    
    SBI   PORTC, 1               ; Nyalakan LED Merah
    
    CPI   R20, 80
    BRSH  kemas_data
    CPI   R21, 0
    BRNE  kemas_data
    
    LDI   R25, 1                
    RJMP  kemas_data

suhu_hangat:
    CBI   PORTC, 1               ; Matikan LED

kemas_data:
    PUSH  R17
    PUSH  R20
    PUSH  R21
    PUSH  R25
    
    MOV   R24, R17
    MOV   R22, R20
    MOV   R20, R21
    CALL  debugSensors
    
    POP   R25
    POP   R21
    POP   R20
    POP   R17

    MOV   R24, R17               
    ANDI  R24, 0x7F
    CPI   R25, 1
    BRNE  send_to_master
    ORI   R24, 0x80

send_to_master:
    OUT   SPDR, R24              
    RJMP  main_loop

; FUNGSI BANTUAN
DHT11_read_byte:
    LDI   R22, 8
    CLR   R18
bit_loop:
wait_bit_rise:
    SBIS  PINB, 1
    RJMP  wait_bit_rise
    RCALL delay_50us
    SBIS  PINB, 1
    RJMP  zero_bit
    SEC
    ROL   R18
    RJMP  wait_bit_fall
zero_bit:
    LSL   R18
wait_bit_fall:
    SBIC  PINB, 1
    RJMP  wait_bit_fall
    DEC   R22
    BRNE  bit_loop
    RET

delay_50us:
    LDI   R16, 198
wait_50:
    NOP
    DEC   R16
    BRNE  wait_50
    RET

delay_20ms:
    LDI   R16, 255
d20_1: 
    LDI   R23, 210
d20_2: 
    LDI   R26, 2
d20_3: 
    DEC   R26
    BRNE  d20_3
    DEC   R23
    BRNE  d20_2
    DEC   R16
    BRNE  d20_1
    RET

delay_2s:
    LDI   R16, 255
d2_1: 
    LDI   R23, 255
d2_2: 
    LDI   R26, 164
d2_3: 
    DEC   R26
    BRNE  d2_3
    DEC   R23
    BRNE  d2_2
    DEC   R16
    BRNE  d2_1
    RET
; *****************************************************************

              XDEF   Entry, _Startup       ; Export program entry symbols
              ABSENTRY Entry               ; Absolute assembly entry point
              INCLUDE "derivative.inc"     ; Device register definitions

;***************************************************************************************************
; equates section
;***************************************************************************************************

; --- LCD Equates (from Lab 2 style) ---
CLEAR_HOME    EQU   $01                   ; Clear display & home cursor
INTERFACE     EQU   $38                   ; 8-bit, 2 line LCD interface
CURSOR_OFF    EQU   $0C                   ; Display ON, cursor OFF
SHIFT_OFF     EQU   $06                   ; Increment address, no shift
LCD_SEC_LINE  EQU   64                    ; Address of 2nd LCD line

; LCD port mapping on EEBOT
LCD_CNTR      EQU   PTJ                   ; LCD control port (E=PJ7, RS=PJ6)
LCD_DAT       EQU   PORTB                 ; LCD data port (D7–D0 = PB7–PB0)
LCD_E         EQU   $80                   ; Bit mask for E signal (PJ7)
LCD_RS        EQU   $40                   ; Bit mask for RS signal (PJ6)

; Characters
NULL          EQU   0                     ; String terminator
CR            EQU   $0D                   ; Carriage return (unused here)
SPACE         EQU   ' '                   ; ASCII space

; --- Timer constants (TOF based turn durations) ---
T_LEFT        EQU   8                     ; Left turn duration in TOF ticks
T_RIGHT       EQU   8                     ; Right turn duration in TOF ticks

; --- Robot state codes (state machine) ---
START         EQU   0                     ; Waiting for start bump
FWD           EQU   1                     ; Driving forward, line follow
ALL_STOP      EQU   2                     ; All motors stopped
LEFT_TRN      EQU   3                     ; Turning left (partial)
RIGHT_TRN     EQU   4                     ; Turning right (partial)
REV_TRN       EQU   5                     ; Reverse + turn away after bump
LEFT_ALIGN    EQU   6                     ; Fine alignment left
RIGHT_ALIGN   EQU   7                     ; Fine alignment right

;***************************************************************************************************
; variable/data section (RAM)
;***************************************************************************************************

              ORG   $3800                 ; Start of our RAM block

; --- Baseline sensor values (calibrated from initial readings) ---
BASE_LINE     FCB   $AE                   ; Baseline for line sensor
BASE_BOW      FCB   $58                   ; Baseline for bow (front) IR
BASE_MID      FCB   $8A                   ; Baseline for middle IR
BASE_PORT     FCB   $E1                   ; Baseline for port (left) IR
BASE_STBD     FCB   $E4                   ; Baseline for starboard (right) IR

; --- Allowed variance thresholds around the baseline ---
LINE_VARIANCE      FCB   $18              ; Allowed delta for line sensor
BOW_VARIANCE       FCB   $30              ; Allowed delta for bow IR
PORT_VARIANCE      FCB   $20              ; Allowed delta for port IR
MID_VARIANCE       FCB   $20              ; Allowed delta for mid IR
STARBOARD_VARIANCE FCB   $15              ; Allowed delta for starboard IR

; --- LCD text buffers ---
TOP_LINE      RMB   20                    ; Buffer for LCD top line text
              FCB   NULL                  ; Null terminator

BOT_LINE      RMB   20                    ; Buffer for LCD bottom line text
              FCB   NULL                  ; Null terminator

CLEAR_LINE    FCC   '                  '  ; 18+ spaces to clear a line
              FCB   NULL                  ; Null terminator

TEMP          RMB   1                     ; General temp byte

; --- Sensor value storage (5 guider sensors) ---
SENSOR_LINE   FCB   $01                   ; Line sensor (initial test value)
SENSOR_BOW    FCB   $23                   ; Bow/front sensor
SENSOR_PORT   FCB   $45                   ; Left sensor
SENSOR_MID    FCB   $67                   ; Middle sensor
SENSOR_STBD   FCB   $89                   ; Right sensor
SENSOR_NUM    RMB   1                     ; Sensor index for read loop

;***************************************************************************************************
; timer / numeric / state variables
;***************************************************************************************************

              ORG   $3850                 ; Place timer & numeric vars here

TOF_COUNTER   DC.B  0                     ; Timer overflow counter (23 Hz)
CRNT_STATE    DC.B  ALL_STOP              ; Initial robot state = ALL_STOP
T_TURN        DS.B  1                     ; Alarm time for turn completion

TEN_THOUS     DS.B  1                     ; BCD 10,000 digit
THOUSANDS     DS.B  1                     ; BCD 1,000 digit
HUNDREDS      DS.B  1                     ; BCD 100 digit
TENS          DS.B  1                     ; BCD 10 digit
UNITS         DS.B  1                     ; BCD 1 digit
NO_BLANK      DS.B  1                     ; Leading-zero blanking flag

HEX_TABLE     FCC   '0123456789ABCDEF'    ; HEX -> ASCII table
BCD_SPARE     RMB   2                     ; Spare BCD bytes (not used here)

;***************************************************************************************************
; code section
;***************************************************************************************************

              ORG   $4000                 ; Start of program code

Entry:                                    ; Reset entry label
_Startup:                                 ; Alias for startup (C style)

              LDS   #$4000                ; Initialize stack pointer
              CLI                         ; Enable global interrupts

              JSR   INIT                  ; Initialize GPIO directions
              JSR   openADC               ; Initialize ATD (Lab 3 style)
              JSR   initLCD               ; Initialize LCD (4-bit style)
              JSR   CLR_LCD_BUF           ; Clear LCD buffer arrays

              BSET  DDRA,%00000011        ; Make PORTA0,1 outputs (motor dirs)
              BSET  DDRT,%00110000        ; Make PTT4,5 outputs (motor speed)

              JSR   initAD                ; Init ADC used for battery voltage
              JSR   initLCD               ; Re-init LCD (defensive)
              JSR   clrLCD                ; Clear LCD & home the cursor

              LDX   #msg1                 ; Load address of first message
              JSR   putsLCD               ; Display "Battery volt "

              LDAA  #$C0                  ; Move cursor to 2nd line
              JSR   cmd2LCD               ; Issue LCD command

              LDX   #msg2                 ; Load address of second message
              JSR   putsLCD               ; Display "State"

              JSR   ENABLE_TOF            ; Enable TOF interrupt + prescaler

; -------------------- MAIN LOOP --------------------

MAIN:        
              JSR   G_LEDS_ON             ; Turn guider LEDs ON
              JSR   READ_SENSORS          ; Read all 5 guider sensors
              JSR   G_LEDS_OFF            ; Turn guider LEDs OFF

              JSR   UPDT_DISPL            ; Update battery voltage + state

              LDAA  CRNT_STATE            ; Load current state into A
              JSR   DISPATCHER            ; Dispatch to proper state handler

              BRA   MAIN                  ; Repeat forever

;***************************************************************************************************
; data: LCD strings for title and state names
;***************************************************************************************************

msg1          DC.B  "Battery volt ",0     ; First line label
msg2          DC.B  "State",0             ; Second line label

; Table of state names (each null-terminated, used by UPDT_DISPL)
tab           DC.B  "start  ",0           ; Name for START (0)
              DC.B  "fwd    ",0           ; Name for FWD (1)
              DC.B  "all_stp",0           ; Name for ALL_STOP (2)
              DC.B  "LeftTurn  ",0        ; Name for LEFT_TRN (3)
              DC.B  "RightTurn  ",0       ; Name for RIGHT_TRN (4)
              DC.B  "RevTrn ",0           ; Name for REV_TRN (5)
              DC.B  "LeftTimed ",0        ; Name for LEFT_ALIGN (6)
              DC.B  "RTimed ",0           ; Name for RIGHT_ALIGN (7)

;***************************************************************************************************
; STATE DISPATCHER (clean, lab-5 style)
;***************************************************************************************************

DISPATCHER:
              CMPA  #START                ; Is state = START ?
              BNE   D_NOT_START           ; If not, check next
              JSR   START_ST              ; Handle START state
              RTS                         ; Return to MAIN

D_NOT_START:  CMPA  #FWD                  ; Is state = FWD ?
              BNE   D_NOT_FWD             ; If not, next
              JSR   FWD_ST                ; Handle FWD state
              RTS                         ; Return to MAIN

D_NOT_FWD:    CMPA  #ALL_STOP             ; Is state = ALL_STOP ?
              BNE   D_NOT_STOP            ; If not, next
              JSR   ALL_STOP_ST           ; Handle ALL_STOP
              RTS                         ; Return to MAIN

D_NOT_STOP:   CMPA  #LEFT_TRN             ; Is state = LEFT_TRN ?
              BNE   D_NOT_LTRN            ; If not, next
              JSR   LEFT                  ; Handle LEFT_TRN behaviour
              RTS                         ; Return to MAIN

D_NOT_LTRN:   CMPA  #RIGHT_TRN            ; Is state = RIGHT_TRN ?
              BNE   D_NOT_RTRN            ; If not, next
              JSR   RIGHT                 ; Handle RIGHT_TRN behaviour
              RTS                         ; Return to MAIN

D_NOT_RTRN:   CMPA  #REV_TRN              ; Is state = REV_TRN ?
              BNE   D_NOT_REVTRN          ; If not, next
              JSR   REV_TRN_ST            ; Handle REV_TRN state
              RTS                         ; Return to MAIN

D_NOT_REVTRN: CMPA  #LEFT_ALIGN           ; Is state = LEFT_ALIGN ?
              BNE   D_NOT_LALIGN          ; If not, next
              JSR   LEFT_ALIGN_DONE       ; Finish left alignment
              RTS                         ; Return to MAIN

D_NOT_LALIGN: CMPA  #RIGHT_ALIGN          ; Is state = RIGHT_ALIGN ?
              BNE   D_DISP_EXIT           ; If not, invalid/unused
              JSR   RIGHT_ALIGN_DONE      ; Finish right alignment
              RTS                         ; Return to MAIN

D_DISP_EXIT:  RTS                         ; Unknown state: just return

;***************************************************************************************************
; START STATE
; - Wait for front bumper to be pressed
; - When pressed, start forward motion and switch to FWD state
;***************************************************************************************************

START_ST:
              BRCLR PORTAD0,%00000100,ST_RELEASE ; If front bumper *not* set, skip
              JSR   INIT_FWD             ; Front bumper hit -> start driving
              MOVB  #FWD,CRNT_STATE      ; Set state to FWD

ST_RELEASE:   RTS                        ; Return to MAIN

;***************************************************************************************************
; FWD STATE (line following + bumpers + partial turns)
;***************************************************************************************************

FWD_ST:
              ; --- Check front bumper first (highest priority) ---
              BRSET PORTAD0,$04,NO_FWD_BUMP ; If front bumper *not* pressed, skip

              MOVB  #REV_TRN,CRNT_STATE  ; If front bumper pressed, go to REV_TRN
              JSR   UPDT_DISPL           ; Update LCD (show new state)
              JSR   INIT_REV             ; Start reversing
              LDY   #6000                ; Delay while reversing
              JSR   del_50us             ; ~6000*50us delay
              JSR   INIT_RIGHT           ; Then start turning right
              LDY   #6000                ; Delay while turning
              JSR   del_50us
              LBRA  FWD_EXIT             ; Done, return

NO_FWD_BUMP:
              ; --- Check rear bumper (stop robot) ---
              BRSET PORTAD0,$04,NO_FWD_REAR_BUMP ; NOTE: same mask -> assume other bit wired
              MOVB  #ALL_STOP,CRNT_STATE ; If rear bumper triggered, stop
              JSR   INIT_STOP            ; Turn off motors
              LBRA  FWD_EXIT             ; Done

NO_FWD_REAR_BUMP:
              ; --- Check alignment based on bow, mid, line sensors ---
              LDAA  SENSOR_BOW          ; Get bow sensor value
              ADDA  BOW_VARIANCE        ; Add variance threshold
              CMPA  BASE_BOW            ; Compare with baseline
              BPL   NOT_ALIGNED         ; If above, not aligned at front

              LDAA  SENSOR_MID          ; Get middle sensor
              ADDA  MID_VARIANCE
              CMPA  BASE_MID            ; Compare with baseline
              BPL   NOT_ALIGNED         ; If above baseline, misaligned

              LDAA  SENSOR_LINE         ; Get line sensor
              ADDA  LINE_VARIANCE
              CMPA  BASE_LINE           ; Compare with baseline + variance
              BPL   CHECK_RIGHT_ALIGN   ; If too high, we need right align

              LDAA  SENSOR_LINE         ; Re-check on low side
              SUBA  LINE_VARIANCE
              CMPA  BASE_LINE
              BMI   CHECK_LEFT_ALIGN    ; If too low, need left align

              ; If we reach here, alignment is OK -> just exit
              BRA   FWD_EXIT

;***************************************************************************************************
; NOT_ALIGNED: decide partial left/right turns based on side sensors
;***************************************************************************************************

NOT_ALIGNED:
              LDAA  SENSOR_PORT         ; Check left side sensor
              ADDA  PORT_VARIANCE
              CMPA  BASE_PORT
              BPL   PARTIAL_LEFT_TRN    ; Too close on left -> partial left turn
              BMI   NO_PORT             ; Otherwise check bow

NO_PORT:
              LDAA  SENSOR_BOW          ; Check bow again
              ADDA  BOW_VARIANCE
              CMPA  BASE_BOW
              BPL   FWD_EXIT            ; Out of spec at bow, but ignore here
              BMI   NO_BOW              ; Otherwise check starboard

NO_BOW:
              LDAA  SENSOR_STBD         ; Check starboard/right sensor
              ADDA  STARBOARD_VARIANCE
              CMPA  BASE_STBD
              BPL   PARTIAL_RIGHT_TRN   ; Too close on right -> partial right turn
              BMI   FWD_EXIT            ; Else just exit

;***************************************************************************************************
; Partial LEFT turn from FWD
;***************************************************************************************************

PARTIAL_LEFT_TRN:
              LDY   #6000               ; Delay before starting left
              JSR   del_50us
              JSR   INIT_LEFT           ; Start turning left
              MOVB  #LEFT_TRN,CRNT_STATE ; Switch state to LEFT_TRN
              LDY   #6000               ; Small delay in this state
              JSR   del_50us
              BRA   FWD_EXIT            ; Exit to MAIN

; If line too far to right -> go to LEFT_ALIGN
CHECK_LEFT_ALIGN:
              JSR   INIT_LEFT           ; Begin left adjustment
              MOVB  #LEFT_ALIGN,CRNT_STATE ; Switch to LEFT_ALIGN state
              BRA   FWD_EXIT

;***************************************************************************************************
; Partial RIGHT turn from FWD
;***************************************************************************************************

PARTIAL_RIGHT_TRN:
              LDY   #6000               ; Delay before starting right
              JSR   del_50us
              JSR   INIT_RIGHT          ; Start turning right
              MOVB  #RIGHT_TRN,CRNT_STATE ; Switch state to RIGHT_TRN
              LDY   #6000               ; Small delay in this state
              JSR   del_50us
              BRA   FWD_EXIT

; If line too far to left -> go to RIGHT_ALIGN
CHECK_RIGHT_ALIGN:
              JSR   INIT_RIGHT          ; Begin right adjustment
              MOVB  #RIGHT_ALIGN,CRNT_STATE ; Switch to RIGHT_ALIGN state
              BRA   FWD_EXIT

FWD_EXIT:
              RTS                       ; Return from FWD_ST

;***************************************************************************************************
; LEFT_TRN STATE HANDLER
; - Called when CRNT_STATE = LEFT_TRN
; - Uses bow sensor to decide when alignment is restored
;***************************************************************************************************

LEFT:
              LDAA  SENSOR_BOW          ; Look at bow/front sensor
              ADDA  BOW_VARIANCE
              CMPA  BASE_BOW
              BPL   LEFT_ALIGN_DONE     ; If back in range, finish left align
              BMI   LEFT_EXIT           ; Otherwise keep turning (nothing more here)

LEFT_EXIT:
              RTS                       ; Return to MAIN

LEFT_ALIGN_DONE:
              MOVB  #FWD,CRNT_STATE     ; Go back to FWD motion
              JSR   INIT_FWD            ; Initialize forward movement
              BRA   LEFT_EXIT           ; Return

;***************************************************************************************************
; RIGHT_TRN STATE HANDLER
; - Called when CRNT_STATE = RIGHT_TRN
; - Uses bow sensor to decide when alignment is restored
;***************************************************************************************************

RIGHT:
              LDAA  SENSOR_BOW          ; Look at bow/front sensor
              ADDA  BOW_VARIANCE
              CMPA  BASE_BOW
              BPL   RIGHT_ALIGN_DONE    ; If back in range, finish right align
              BMI   RIGHT_EXIT          ; Else keep turning

RIGHT_EXIT:
              RTS                       ; Return to MAIN

RIGHT_ALIGN_DONE:
              MOVB  #FWD,CRNT_STATE     ; Go back to FWD motion
              JSR   INIT_FWD            ; Initialize forward movement
              BRA   RIGHT_EXIT          ; Return

;***************************************************************************************************
; REV_TRN STATE HANDLER
; - Used after front bumper: back up, then turn away until bow is clear
;***************************************************************************************************

REV_TRN_ST:
              LDAA  SENSOR_BOW          ; Check bow distance
              ADDA  BOW_VARIANCE
              CMPA  BASE_BOW
              BMI   REV_EXIT            ; If still too close, keep reversing/turning

              JSR   INIT_LEFT           ; Once clear, start turning left
              MOVB  #FWD,CRNT_STATE     ; Then go back to forward state
              JSR   INIT_FWD            ; Drive forward again

REV_EXIT:
              BRA   REV_RTS             ; Jump to RTS label (for clarity)
REV_RTS:
              RTS                       ; Return to MAIN

;***************************************************************************************************
; ALL_STOP STATE HANDLER
; - Called when CRNT_STATE = ALL_STOP
; - Waits for front bumper to be pressed again to re-enter START
;***************************************************************************************************

ALL_STOP_ST:
              BRSET PORTAD0,%00000100,NO_START_BUMP ; If no front bump, stay
              MOVB  #START,CRNT_STATE   ; If front bumper pressed, go to START

NO_START_BUMP:
              RTS                       ; Return to MAIN

;***************************************************************************************************
; Initialization / motor subroutines
;***************************************************************************************************

; --- RIGHT turn initialization ---
INIT_RIGHT:
              BSET  PORTA,%00000010     ; Set PA1 = 1 (right motor reverse dir)
              BCLR  PORTA,%00000001     ; Clear PA0 = 0 (left motor forward)
              LDAA  TOF_COUNTER         ; Get current TOF time
              ADDA  #T_RIGHT            ; Add right turn interval
              STAA  T_TURN              ; Store as turn alarm time (not fully used)
              RTS

; --- LEFT turn initialization ---
INIT_LEFT:
              BSET  PORTA,%00000001     ; Set PA0 = 1 (left motor reverse dir)
              BCLR  PORTA,%00000010     ; Clear PA1 = 0 (right motor forward)
              LDAA  TOF_COUNTER         ; Get current TOF time
              ADDA  #T_LEFT             ; Add left turn interval
              STAA  T_TURN              ; Store as turn alarm (not fully used)
              RTS

; --- Forward motion initialization ---
INIT_FWD:
              BCLR  PORTA,%00000011     ; PA1..0 = 00 (both motors forward dir)
              BSET  PTT,%00110000       ; Turn drive motors ON (PTT4,PTT5)
              RTS

; --- Reverse motion initialization ---
INIT_REV:
              BSET  PORTA,%00000011     ; PA1..0 = 11 (both motors reverse dir)
              BSET  PTT,%00110000       ; Turn drive motors ON
              RTS

; --- Stop both motors ---
INIT_STOP:
              BCLR  PTT,%00110000       ; Turn motors OFF
              RTS

;***************************************************************************************************
; INIT: configure ADC and LCD-related ports
;***************************************************************************************************

INIT:
              BCLR  DDRAD,$FF           ; Make PORTAD input (ATD pins)
              BSET  DDRA,$FF            ; Make PORTA output (motors, LEDs, mux)
              BSET  DDRB,$FF            ; Make PORTB output (LCD data)
              BSET  DDRJ,$C0            ; Make PJ7,PJ6 outputs (LCD E,RS)
              RTS

;***************************************************************************************************
; openADC: generic ATD setup for guider sensors (Lab 3)
;***************************************************************************************************

openADC:
              MOVB  #$80,ATDCTL2        ; Turn ADC on
              LDY   #1                  ; Delay 50us for ADC to power up
              JSR   del_50us
              MOVB  #$20,ATDCTL3        ; 4 conversions, channel sequence
              MOVB  #$97,ATDCTL4        ; 8-bit, prescaler=48
              RTS

;***************************************************************************************************
; CLR_LCD_BUF: clear TOP_LINE and BOT_LINE buffers with spaces
;***************************************************************************************************

CLR_LCD_BUF:
              LDX   #CLEAR_LINE         ; Address of spaces template
              LDY   #TOP_LINE           ; Destination = TOP_LINE
              JSR   STRCPY              ; Copy spaces to TOP_LINE

CLB_SECOND:
              LDX   #CLEAR_LINE         ; Source again
              LDY   #BOT_LINE           ; Destination = BOT_LINE
              JSR   STRCPY              ; Copy spaces to BOT_LINE

CLB_EXIT:
              RTS

;***************************************************************************************************
; STRCPY: copy null-terminated string from X (src) to Y (dest)
;***************************************************************************************************

STRCPY:
              PSHX                      ; Save X
              PSHY                      ; Save Y
              PSHA                      ; Save A

STRCPY_LOOP:
              LDAA  0,X                 ; Load byte from source
              STAA  0,Y                 ; Store to destination
              BEQ   STRCPY_EXIT         ; If null, done
              INX                       ; Move to next source byte
              INY                       ; Move to next dest byte
              BRA   STRCPY_LOOP         ; Repeat

STRCPY_EXIT:
              PULA                      ; Restore A
              PULY                      ; Restore Y
              PULX                      ; Restore X
              RTS

;***************************************************************************************************
; G_LEDS_ON: turn guider LEDs ON (PA5 = 1)
;***************************************************************************************************

G_LEDS_ON:
              BSET  PORTA,%00100000     ; Set PA5 high
              RTS

;***************************************************************************************************
; G_LEDS_OFF: turn guider LEDs OFF (PA5 = 0)
;***************************************************************************************************

G_LEDS_OFF:
              BCLR  PORTA,%00100000     ; Clear PA5
              RTS

;***************************************************************************************************
; READ_SENSORS: loop through guider inputs using SELECT_SENSOR + ADC
;***************************************************************************************************

READ_SENSORS:
              CLR   SENSOR_NUM          ; Start from sensor 0 (line)
              LDX   #SENSOR_LINE        ; X points to first sensor byte

RS_MAIN_LOOP:
              LDAA  SENSOR_NUM          ; Load current sensor index
              JSR   SELECT_SENSOR       ; Set sensor multiplexer on EEBOT

              LDY   #400                ; Delay ~20ms (400 * 50us)
              JSR   del_50us            ; So sensor reading stabilizes

              LDAA  #%10000001          ; ATD on, single conv, channel AN1
              STAA  ATDCTL5             ; Start conversion
              BRCLR ATDSTAT0,$80,*      ; Wait until conversion complete
              LDAA  ATDDR0L             ; Get 8-bit result
              STAA  0,X                 ; Store into SENSOR_* array

              CPX   #SENSOR_STBD        ; Last sensor?
              BEQ   RS_EXIT             ; If yes, done

              INC   SENSOR_NUM          ; Else increment sensor index
              INX                       ; Move to next sensor variable
              BRA   RS_MAIN_LOOP        ; Repeat

RS_EXIT:
              RTS

;***************************************************************************************************
; SELECT_SENSOR: set PORTA bits for hardware sensor mux
; SENSOR_NUM is passed in A when called
;***************************************************************************************************

SELECT_SENSOR:
              PSHA                      ; Save sensor number
              LDAA  PORTA               ; Read PORTA
              ANDA  #%11100011          ; Clear sensor select bits (PA2–PA4)
              STAA  TEMP                ; Save cleared version

              PULA                      ; Restore sensor number into A
              ASLA                      ; Shift left 2 times to line up bits
              ASLA
              ANDA  #%00011100          ; Keep only PA2–PA4 bits
              ORAA  TEMP                ; Merge with non-sensor bits
              STAA  PORTA               ; Update PORTA (sensor select)
              RTS

;***************************************************************************************************
; DISPLAY_SENSORS: (optional) show sensor values on LCD buffer
; NOTE: not called from MAIN, use for debugging if desired
;***************************************************************************************************

DP_FRONT_SENSOR   EQU TOP_LINE+3         ; Bow value slot
DP_PORT_SENSOR    EQU BOT_LINE+0         ; Port value slot
DP_MID_SENSOR     EQU BOT_LINE+3         ; Mid value slot
DP_STBD_SENSOR    EQU BOT_LINE+6         ; Stbd value slot
DP_LINE_SENSOR    EQU BOT_LINE+9         ; Line value slot

DISPLAY_SENSORS:
              LDAA  SENSOR_BOW          ; Bow/front sensor
              JSR   BIN2ASC             ; Convert to 2 ASCII hex chars
              LDX   #DP_FRONT_SENSOR    ; Where to place on TOP_LINE
              STD   0,X                 ; Store two chars

              LDAA  SENSOR_PORT         ; Port/left sensor
              JSR   BIN2ASC
              LDX   #DP_PORT_SENSOR
              STD   0,X

              LDAA  SENSOR_MID          ; Mid sensor
              JSR   BIN2ASC
              LDX   #DP_MID_SENSOR
              STD   0,X

              LDAA  SENSOR_STBD         ; Stbd/right sensor
              JSR   BIN2ASC
              LDX   #DP_STBD_SENSOR
              STD   0,X

              LDAA  SENSOR_LINE         ; Line sensor
              JSR   BIN2ASC
              LDX   #DP_LINE_SENSOR
              STD   0,X

              LDAA  #CLEAR_HOME         ; Clear LCD and home cursor
              JSR   cmd2LCD
              LDY   #40                 ; Delay 2 ms (40*50us)
              JSR   del_50us

              LDX   #TOP_LINE           ; Print top line buffer
              JSR   putsLCD

              LDAA  #LCD_SEC_LINE       ; Move cursor to second line
              JSR   LCD_POS_CRSR

              LDX   #BOT_LINE           ; Print bottom line buffer
              JSR   putsLCD
              RTS

;***************************************************************************************************
; UPDT_DISPL: ADC battery reading + show voltage + current state (Lab 5 style)
;***************************************************************************************************

UPDT_DISPL:
              MOVB  #$90,ATDCTL5        ; Start ATD chan0, right-justified
              BRCLR ATDSTAT0,$80,*      ; Wait for complete
              LDAA  ATDDR0L             ; Read 8-bit ADC result (battery)

              LDAB  #39                 ; Scale factor for voltage
              MUL                       ; D = A * 39
              ADDD  #600                ; Offset +600 for calibration
              JSR   int2BCD             ; Convert 16-bit D to BCD digits
              JSR   BCD2ASC             ; Convert BCD digits to ASCII chars

              LDAA  #$8D                ; Cursor pos: end of "Battery volt "
              JSR   cmd2LCD             ; Position LCD cursor

              LDAA  TEN_THOUS           ; Print 10,000 digit (ASCII/space)
              JSR   putcLCD

              LDAA  THOUSANDS           ; Print thousands digit
              JSR   putcLCD

              LDAA  #'.'                ; Print decimal point
              JSR   putcLCD

              LDAA  HUNDREDS            ; Print hundreds digit
              JSR   putcLCD

              ; --- Show current state string on 2nd line ---
              LDAA  #$C7                ; Cursor at end of "State"
              JSR   cmd2LCD

              LDAB  CRNT_STATE          ; Load current state number
              LSLB                      ; Multiply by 8 to index table
              LSLB
              LSLB
              LDX   #tab                ; Base of state name table
              ABX                       ; X = tab + 8*state
              JSR   putsLCD             ; Print state name
              RTS

;***************************************************************************************************
; ENABLE_TOF: set up timer overflow interrupt (Lab 4)
;***************************************************************************************************

ENABLE_TOF:
              LDAA  #%10000000          ; Enable main timer (TCNT)
              STAA  TSCR1               ; TSCR1: TEN=1

              STAA  TFLG2               ; Clear TOF flag by writing 1

              LDAA  #%10000100          ; TOI=1, prescaler=16
              STAA  TSCR2               ; Enable TOF interrupt
              RTS

;***************************************************************************************************
; TOF_ISR: timer overflow ISR increments TOF_COUNTER
;***************************************************************************************************

TOF_ISR:
              INC   TOF_COUNTER         ; Increment overflow counter
              LDAA  #%10000000          ; Bit to clear TOF flag
              STAA  TFLG2               ; Clear TOF flag
              RTI                       ; Return from interrupt

;***************************************************************************************************
; utility subroutines: LCD init, clear, delays, LCD writes, ADC init
;***************************************************************************************************

initLCD:
              BSET  DDRB,%11111111      ; PORTB as output (LCD data)
              BSET  DDRJ,%11000000      ; PJ7,PJ6 as outputs (E,RS)
              LDY   #2000               ; Delay ~100ms
              JSR   del_50us

              LDAA  #$28                ; 4-bit, 2 line mode
              JSR   cmd2LCD
              LDAA  #$0C                ; Display ON, cursor off
              JSR   cmd2LCD
              LDAA  #$06                ; Entry mode: increment
              JSR   cmd2LCD
              RTS

clrLCD:
              LDAA  #$01                ; Clear display
              JSR   cmd2LCD
              LDY   #40                 ; 2ms delay
              JSR   del_50us
              RTS

; 50us delay * Y iterations
del_50us:
              PSHX                      ; Save X
eloop:
              LDX   #300                ; Inner loop count ~300
iloop:
              NOP                       ; 1 E-cycle
              DBNE  X,iloop             ; Loop inner until X=0
              DBNE  Y,eloop             ; Outer loop Y times
              PULX                      ; Restore X
              RTS

; Issue LCD command in A
cmd2LCD:
              BCLR  LCD_CNTR, LCD_RS    ; RS=0 -> instruction register
              JSR   dataMov             ; Send byte in A
              RTS

; Write null-terminated string at X to LCD
putsLCD:
              LDAA  1,X+                ; Load char, post-increment X
              BEQ   donePS              ; If null, stop
              JSR   putcLCD             ; Send char
              BRA   putsLCD             ; Loop

donePS:
              RTS

; Write single character in A to LCD
putcLCD:
              BSET  LCD_CNTR, LCD_RS    ; RS=1 -> data register
              JSR   dataMov             ; Send byte in A
              RTS

; Low-level routine: write byte in A as two nibbles to LCD
dataMov:
              BSET  LCD_CNTR, LCD_E     ; E=1 to latch high nibble
              STAA  LCD_DAT             ; Put data on PORTB
              BCLR  LCD_CNTR, LCD_E     ; E=0 to finish high nibble

              LSLA                      ; Shift low nibble to high bits
              LSLA
              LSLA
              LSLA
              BSET  LCD_CNTR, LCD_E     ; E=1 for low nibble
              STAA  LCD_DAT             ; Output shifted nibble
              BCLR  LCD_CNTR, LCD_E     ; E=0 done

              LDY   #1                  ; Short delay
              JSR   del_50us
              RTS

; Initialize ATD for battery measurement (Lab 3 style)
initAD:
              MOVB  #$C0,ATDCTL2        ; Power up AD, fast flag clear
              JSR   del_50us            ; Wait 50us
              MOVB  #$00,ATDCTL3        ; 8 conversions
              MOVB  #$85,ATDCTL4        ; 8-bit, prescaler
              BSET  ATDDIEN,$0C         ; AN2,AN3 as digital inputs
              RTS

;***************************************************************************************************
; int2BCD: convert 16-bit binary in D into BCD digits (TEN_THOUS..UNITS)
;***************************************************************************************************

int2BCD:
              XGDX                      ; Save binary in X
              LDAA  #0
              STAA  TEN_THOUS           ; Clear BCD digits
              STAA  THOUSANDS
              STAA  HUNDREDS
              STAA  TENS
              STAA  UNITS
              STAA  BCD_SPARE
              STAA  BCD_SPARE+1

              CPX   #0                  ; Is input zero?
              BEQ   CON_EXIT            ; If yes, done

              XGDX                      ; Get back binary in D
              LDX   #10                 ; Divisor = 10
              IDIV                      ; D / 10 -> quotient X, remainder B
              STAB  UNITS               ; Store units digit
              CPX   #0
              BEQ   CON_EXIT

              XGDX                      ; Quotient -> D
              LDX   #10
              IDIV
              STAB  TENS                ; Tens digit
              CPX   #0
              BEQ   CON_EXIT

              XGDX
              LDX   #10
              IDIV
              STAB  HUNDREDS            ; Hundreds digit
              CPX   #0
              BEQ   CON_EXIT

              XGDX
              LDX   #10
              IDIV
              STAB  THOUSANDS           ; Thousands digit
              CPX   #0
              BEQ   CON_EXIT

              XGDX
              LDX   #10
              IDIV
              STAB  TEN_THOUS           ; Ten-thousands digit

CON_EXIT:
              RTS

;***************************************************************************************************
; LCD_POS_CRSR: set LCD cursor position using address in A
;***************************************************************************************************

LCD_POS_CRSR:
              ORAA  #%10000000          ; Set DDRAM address bit
              JSR   cmd2LCD             ; Send command to LCD
              RTS

;***************************************************************************************************
; BIN2ASC: convert 8-bit value in A to two ASCII hex characters
; - Returns: A=MS nibble ASCII, B=LS nibble ASCII
;***************************************************************************************************

BIN2ASC:
              PSHA                      ; Save original byte
              TAB                       ; Copy to B
              ANDB #%00001111           ; Keep low nibble
              CLRA                      ; A=0
              ADDD #HEX_TABLE           ; D points into HEX_TABLE
              XGDX                      ; Move pointer into X
              LDAA 0,X                  ; A = ASCII of low nibble
              PULB                      ; B = original input
              PSHA                      ; Save LS ASCII on stack

              RORB                      ; Shift high nibble into low nibble
              RORB
              RORB
              RORB
              ANDB #%00001111           ; Mask low nibble
              CLRA                      ; A=0
              ADDD #HEX_TABLE           ; D points into HEX_TABLE
              XGDX
              LDAA 0,X                  ; A = ASCII of high nibble
              PULB                      ; B = ASCII of low nibble
              RTS

;***************************************************************************************************
; BCD2ASC: convert BCD digits into ASCII characters with leading blanks
;***************************************************************************************************

BCD2ASC:
              LDAA  #0                  ; Clear no-blank flag
              STAA  NO_BLANK

C_TTHOU:
              LDAA  TEN_THOUS           ; Ten-thousands digit
              ORAA  NO_BLANK
              BNE   NOT_BLANK1          ; If already non-blank, show digit

ISBLANK1:
              LDAA  #' '                ; Replace with space
              STAA  TEN_THOUS
              BRA   C_THOU

NOT_BLANK1:
              LDAA  TEN_THOUS           ; Convert to ASCII
              ORAA  #$30
              STAA  TEN_THOUS
              LDAA  #1
              STAA  NO_BLANK

C_THOU:
              LDAA  THOUSANDS
              ORAA  NO_BLANK
              BNE   NOT_BLANK2

ISBLANK2:
              LDAA  #' '
              STAA  THOUSANDS
              BRA   C_HUNS

NOT_BLANK2:
              LDAA  THOUSANDS
              ORAA  #$30
              STAA  THOUSANDS
              LDAA  #1
              STAA  NO_BLANK

C_HUNS:
              LDAA  HUNDREDS
              ORAA  NO_BLANK
              BNE   NOT_BLANK3

ISBLANK3:
              LDAA  #' '
              STAA  HUNDREDS
              BRA   C_TENS

NOT_BLANK3:
              LDAA  HUNDREDS
              ORAA  #$30
              STAA  HUNDREDS
              LDAA  #1
              STAA  NO_BLANK

C_TENS:
              LDAA  TENS
              ORAA  NO_BLANK
              BNE   NOT_BLANK4

ISBLANK4:
              LDAA  #' '
              STAA  TENS
              BRA   C_UNITS

NOT_BLANK4:
              LDAA  TENS
              ORAA  #$30
              STAA  TENS

C_UNITS:
              LDAA  UNITS               ; Units digit is always shown
              ORAA  #$30
              STAA  UNITS
              RTS

;***************************************************************************************************
; INTERRUPT VECTORS
;***************************************************************************************************

              ORG   $FFFE               ; Reset vector address
              DC.W  Entry               ; Reset -> Entry

              ORG   $FFDE               ; TOF vector address
              DC.W  TOF_ISR             ; Timer Overflow -> TOF_ISR

;*********************************** END OF FILE ***************************************************
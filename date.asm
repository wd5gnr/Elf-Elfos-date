; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

#include    ../bios.inc
#include    ../kernel.inc

.op "PUSH","N","9$1 73 8$1 73"
.op "POP","N","60 72 A$1 F0 B$1"
.op "CALL","W","D4 H1 L1"
.op "RTN","","D5"
.op "MOV","NR","9$2 B$1 8$2 A$1"
.op "MOV","NW","f8 H2 B$1 f8 L2 a$1"
           org     2000h-6
           dw      2000h
           dw      end-2000h
           dw      2000h

           org     2000h
begin:     br      start
  	   eever
           db      'Written by Michael H. Riley',0

start:     lda     ra                  ; move past any spaces
           smi     ' '
           lbz     start
           dec     ra                  ; move back to non-space character
           ldn     ra                  ; get byte
           lbz     disp                ; jump if no command line argument
           mov     r7,datetime         ; where to put date
           mov     rf,ra               ; point rf at date
	   ldn     rf
	   smi     '?'
	   bz      prompt
fdatego:	
           sep     scall               ; convert month
           dw      f_atoi
           glo     rd
           str     r7                  ; store it
           inc     r7
           smi     13                  ; check if in range
           lbdf    dateerr             ; error if out of range
           lda     rf                  ; get next byte
           smi     '/'                 ; must be a slash
           lbnz    dateerr             ; jump if not
           sep     scall               ; get day
           dw      f_atoi
           glo     rd
           str     r7                  ; store it
           inc     r7
           smi     32                  ; check range
           lbdf    dateerr             ; jump if out of range
           lda     rf                  ; get next character
           smi     '/'                 ; must be a slash
           lbnz    dateerr
           sep     scall               ; get year
           dw      f_atoi
           glo     rd                  ; subtract 1972
           smi     0b4h
           plo     rd
           ghi     rd
           smbi    7
           phi     rd
           glo     rd                  ; save year offset
           str     r7
           inc     r7
         
           lda     rf                  ; get next byte
           lbz     datego              ; jump no time entered
           smi     ' '                 ; otherwise must be space
           lbnz    dateerr             ; jump if not
           sep     scall               ; get hour
           dw      f_atoi
           glo     rd
           str     r7                  ; store it
           inc     r7
           smi     24                  ; see if in range
           lbdf    dateerr             ; jump if error
         
           lda     rf                  ; get next byte
           lbz     datego              ; jump no time entered
           smi     ':'                 ; otherwise must be colon
           lbnz    dateerr             ; jump if not
           sep     scall               ; get minute
           dw      f_atoi
           glo     rd
           str     r7                  ; store it
           inc     r7
           smi     60                  ; see if in range
           lbdf    dateerr             ; jump if error
         
           lda     rf                  ; get next byte
           lbz     datego              ; jump no time entered
           smi     ':'                 ; otherwise must be colon
           lbnz    dateerr             ; jump if not
           sep     scall               ; get second
           dw      f_atoi
           glo     rd
           str     r7                  ; store it
           inc     r7
           smi     60                  ; see if in range
           lbdf    dateerr             ; jump if error
          
           
datego:    mov     r7,datetime         ; point back to date
           mov     rf,0475h            ; kernel storage for date
           ldi     6                   ; 3 bytes to move
           plo     rc
datelp:    lda     r7                  ; get byte from date
           str     rf                  ; store into kernel var
           inc     rf
           dec     rc                  ; decrement count
           glo     rc                  ; see if done
           lbnz    datelp              ; loop back if not

           sep     scall               ; is RTC present
           dw      hasrtc
           lbnf    disp                ; jump if not

           mov     rf,0475h            ; point to data 
           sep     scall               ; call BIOS to set RTC
           dw      o_settod
           lbr     disp                ; display new date

dateerr:   sep     scall               ; display error
           dw      o_inmsg
           db      'Date format error',10,13,0
           ldi     0bh
           sep     sret                ; return to Elf/OS

prompt:	   sep     scall
	   dw	   o_inmsg
	   db	   'Enter date/time (MM/DD/YYYY HH:MM:SS): ',0
	   mov rf, buffer
	   mov rc, 32
           sep     scall
	   dw      o_inputl
	   lbdf    o_wrmboot   	; quit
	   sep     scall
	   dw      o_inmsg
	   db      10,13,0
	   mov rf, buffer
	   lbr fdatego


disp:      sep     scall               ; see if extended BIOS
           dw      hasrtc
           lbnf    disp2               ; jump if not
           mov     rf,0475h            ; point to kernel date/time
           sep     scall               ; call BIOS to get current date/time from RTC
           dw      0f815h
         
disp2:     mov     rf,buffer           ; point to output buffer
           mov     r7,0475h            ; address of date/time
           lda     r7                  ; retrieve month
           plo     rd
           ldi     0                   ; zero high byte
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     '/'                 ; next a slash
           str     rf
           inc     rf
           lda     r7                  ; retrieve day
           plo     rd
           ldi     0
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     '/'                 ; next a slash
           str     rf
           inc     rf
           lda     r7                  ; get year
           adi     0b4h                ; which is offset from 1972
           plo     rd
           ldi     7
           adci    0
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     ' '                 ; next a sspace
           str     rf
           inc     rf
           lda     r7                  ; get hours
           plo     rd
	   smi     9
	   bdf     hr2
	   ldi    '0'
  	   str    rf
	   inc    rf
hr2:	 
           ldi     0
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     ':'                 ; next a slash
           str     rf
           inc     rf
           lda     r7                  ; get minutes
           plo     rd
	   smi      9
	   bdf      mn2
	   ldi     '0'
	   str     rf
	   inc     rf
mn2:	
           ldi     0
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     ':'                 ; next a slash
           str     rf
           inc     rf
           lda     r7                  ; get seconds
           plo     rd
	   smi     9
	   bdf     sec2
	   ldi     '0'
	   str     rf
	   inc     rf
sec2:	
           ldi     0
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     13                  ; add cr/lf
           str     rf
           inc     rf
           ldi     10
           str     rf
           inc     rf
           ldi     0                   ; and terminator
           str     rf
  

           mov     rf,buffer           ; point to output buffer
           sep     scall               ; and display it
           dw      o_msg
           ldi     0
           sep     sret                ; and return to Elf/OS

hasrtc:    mov     rf,0f818h           ; see if extended BIOS is available
           lda     rf                  ; get byte from set date call
           smi     0c0h                ; must be LBR
           lbnz    nortc               ; jump if not
           lda     rf                  ; retrieve second byte
           ani     0f0h                ; keep only high nybble
           smi     0f0h                ; must be in BIOS space
           lbnz    nortc
           smbi    0                   ; signal RTC present
           sep     sret                ; and return
nortc:     adi     0                   ; clear df
           sep     sret                ; and return


datetime:  db      0,0,0,0,0,0
buffer:    db      0

end:	
endrom:    equ     $

           end     begin


; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include    bios.inc
include    kernel.inc

           org     8000h
           lbr     0ff00h
           db      'date',0
           dw      9000h
           dw      endrom+7000h
           dw      2000h
           dw      endrom-2000h
           dw      2000h
           db      0
 
           org     2000h
           br      start

include    date.inc
include    build.inc
           db      'Written by Michael H. Riley',0

start:     lda     ra                  ; move past any spaces
           smi     ' '
           lbz     start
           dec     ra                  ; move back to non-space character
           ldn     ra                  ; get byte
           lbz     disp                ; jump if no command line argument
           mov     r7,datetime         ; where to put date
           mov     rf,ra               ; point rf at date
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
           dw      f_settod
           lbr     disp                ; display new date

dateerr:   sep     scall               ; display error
           dw      o_inmsg
           db      'Date format error',10,13,0
           lbr     o_wrmboot           ; return to Elf/OS

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
           ldi     0
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     ':'                 ; next a slash
           str     rf
           inc     rf
           lda     r7                  ; get minutes
           plo     rd
           ldi     0
           phi     rd
           sep     scall               ; convert number
           dw      f_intout
           ldi     ':'                 ; next a slash
           str     rf
           inc     rf
           lda     r7                  ; get seconds
           plo     rd
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
           lbr     o_wrmboot           ; and return to Elf/OS

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

endrom:    equ     $



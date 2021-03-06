; --COPYRIGHT--,BSD_EX
;  Copyright (c) 2012, Texas Instruments Incorporated
;  All rights reserved.
; 
;  Redistribution and use in source and binary forms, with or without
;  modification, are permitted provided that the following conditions
;  are met:
; 
;  *  Redistributions of source code must retain the above copyright
;     notice, this list of conditions and the following disclaimer.
; 
;  *  Redistributions in binary form must reproduce the above copyright
;     notice, this list of conditions and the following disclaimer in the
;     documentation and/or other materials provided with the distribution.
; 
;  *  Neither the name of Texas Instruments Incorporated nor the names of
;     its contributors may be used to endorse or promote products derived
;     from this software without specific prior written permission.
; 
;  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
;  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
;  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
;  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
;  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
;  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
;  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
; 
; ******************************************************************************
;  
;                        MSP430 CODE EXAMPLE DISCLAIMER
; 
;  MSP430 code examples are self-contained low-level programs that typically
;  demonstrate a single peripheral function or device feature in a highly
;  concise manner. For this the code may rely on the device's power-on default
;  register values and settings such as the clock configuration and care must
;  be taken when combining code from several examples to avoid potential side
;  effects. Also see www.ti.com/grace for a GUI- and www.ti.com/msp430ware
;  for an API functional library-approach to peripheral configuration.
; 
; --/COPYRIGHT--
;*******************************************************************************
;   MSP430xG461x Demo - ADC12, Sample A10 Temp and Convert to oC and oF
;
;   Description: A single sample is made on A10 with reference to internal
;   1.5V Vref. Software sets ADC12SC to start sample and conversion - ADC12SC
;   automatically cleared at EOC. ADC12 internal oscillator times sample
;   and conversion. In Mainloop MSP430 waits in LPM0 to save power until
;   ADC10 conversion complete, ADC12_ISR will force exit from any LPMx in
;   Mainloop on reti. Result is converted to Temperature represented as
;   BCD 0000 - 0145 representing oC saved at 01100h and 0000 - 0292
;   representing oF saved at 01102h.
;   ACLK = 32kHz, MCLK = SMCLK = default DCO 1048576Hz, ADC12CLK = ADC12OSC
;
;   Uncalibrated temperature measured from device to devive will vary do to
;   slope and offset variance from device to device - please see datasheet.
;
;                MSP430xG461x
;             -----------------
;         /|\|              XIN|-
;          | |                 | 32kHz
;          --|RST          XOUT|-
;            |                 |
;
;
;  JL Bile
;  Texas Instruments Inc.
;  June 2008
;  Built Code Composer Essentials: v3 FET
;*******************************************************************************
 .cdecls C,LIST, "msp430.h"
;-------------------------------------------------------------------------------
			.text							;Program Start
;-----------------------------------------------------------------------------
RESET       mov.w   #900,SP         		; Initialize stackpointer
            mov.w   #WDTPW+WDTHOLD,&WDTCTL  ; Stop WDT
            mov.w   #SHT0_8+REFON+ADC12ON,&ADC12CTL0 ; 1.5v ref.
            mov.w   #13600,&TACCR0          ; Delay to allow Ref to settle
            bis.w   #CCIE,&TACCTL0          ; Compare-mode interrupt.
            mov.w   #TACLR+MC_1+TASSEL_2,&TACTL; up mode, SMCLK
            bis.w   #LPM0+GIE,SR            ; Enter LPM0, enable interrupts
            bic.w   #CCIE,&TACCTL0          ; Disable timer interrupt
            dint                            ; Disable Interrupts
            mov.w   #SHP,&ADC12CTL1         ; Enable sample timer
            mov.b   #SREF_1+INCH_10,&ADC12MCTL0 ; A10, internal reference
            bis.w   #0001h,&ADC12IE         ; Enable interrupt
                                            ;
Mainloop    bis.w   #ENC+ADC12SC,&ADC12CTL0 ; Start sampling/conversion
            bis.w   #CPUOFF+GIE,SR          ; LPM0, ADC10_ISR will force exit
            call    #Trans2TempC            ; Transform voltage to temperature
            call    #BIN2BCD4               ; R13 = TempC = 0000 - 0145 BCD
            mov.w   R13,&0200h              ; 0200h = temperature oC
            call    #Trans2TempF            ; Transform voltage to temperature
            call    #BIN2BCD4               ; R13 = TempF = 0000 - 0292 BCD
            mov.w   R13,&0202h              ; 0202h = temperature oF
            jmp     Mainloop                ; << breakpoint here
                                            ;
;-------------------------------------------------------------------------------
Trans2TempC;Subroutine coverts R12 = R12/4096*423-278
;           oC = ((x/4096)*1500mV)-986mV)*1/3.55mV = x*423/4096 - 278
;           Input:  R12  0000 - 0FFFh, R11 working register
;           Output: R12  0000 - 091h
;-------------------------------------------------------------------------------
;            mov.w   &ADC12MEM0,R12          ; Clear IFG flag (not needed)
            mov.w   R12,&MPY                ;
            mov.w   #423,&OP2               ; C
            mov.w   &RESHI,R12              ;
            mov.w   &RESLO,R11              ;
            rlc.w   R11                     ; /4096
            rlc.w   R12                     ;
            rlc.w   R11                     ;
            rlc.w   R12                     ;
            rlc.w   R11                     ;
            rlc.w   R12                     ;
            rlc.w   R11                     ;
            rlc.w   R12                     ;
            sub.w   #278,R12                ; C
            ret                             ;
                                            ;
;-------------------------------------------------------------------------------
Trans2TempF;Subroutine coverts R12 = R12/4096*761-468
;           oF = ((x/4096*1500mV)-923mV)*1/1.97mV = x*761/4096 - 468
;           Input:  R12  0000 - 0FFFh, R11 working register
;           Output: R12  0000 - 0262
;-------------------------------------------------------------------------------
            mov.w   &ADC12MEM0,R12          ; Clear IFG flag
            mov.w   R12,&MPY                ;
            mov.w   #761,&OP2               ; F
            mov.w   &RESHI,R12              ;
            mov.w   &RESLO,R11              ;
            rlc.w   R11                     ; /4096
            rlc.w   R12                     ;
            rlc.w   R11                     ;
            rlc.w   R12                     ;
            rlc.w   R11                     ;
            rlc.w   R12                     ;
            rlc.w   R11                     ;
            rlc.w   R12                     ;
            sub.w   #468,R12                ; F
            ret                             ;
                                            ;
;-------------------------------------------------------------------------------
BIN2BCD4  ; Subroutine converts binary number R12 -> Packed 4-digit BCD R13
;           Input:  R12  0000 - 0FFFh, R15 working register
;           Output: R13  0000 - 4095
;-------------------------------------------------------------------------------
            mov.w   #16,R15                 ; Loop Counter
            clr.w   R13                     ; 0 -> RESULT LSD
BIN1        rla.w   R12                     ; Binary MSB to carry
            dadd.w  R13,R13                 ; RESULT x2 LSD
            dec.w   R15                     ; Through?
            jnz     BIN1                    ; Not through
            ret                             ;
                                            ;
;-------------------------------------------------------------------------------
TA0_ISR;    ISR for CCR0
;-------------------------------------------------------------------------------
            clr.w   &TACTL                  ; clear Timer_A control registers
            bic.w   #LPM0,0(SP)             ; Exit LPMx, interrupts enabled
            reti                            ;
;-------------------------------------------------------------------------------
ADC12_ISR;  ADC12MEM0 -> R12, exit any LPMx mode
;           Output: R12  0000 - 0FFFh
;-------------------------------------------------------------------------------
            mov.w   &ADC12MEM0,R12          ; Clear IFG flag
            mov.w   #GIE,0(SP)              ; Enable Int. exit LPMx on reti
            reti                            ;
                                            ;
;-------------------------------------------------------------------------------
;			Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect	".int22"          		; Timer_A0 Vector
            .short  TA0_ISR
            .sect   ".int23"            	; ADC12 Vector
            .short  ADC12_ISR
            .sect   ".reset"            ; POR, ext. Reset
            .short  RESET
            .end

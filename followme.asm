/*

Follow Me

Commodore 64

Inspired by this series: https://www.youtube.com/watch?v=A7vYSsLS00Y&ab_channel=MyDeveloperThoughts

*/

#import "lib/all.asm"

BasicUpstart2(Main)

Main:
    jsr InitSound
    jsr InitRandom
    jsr ClearTimers
    jsr SetupTimers
    jsr SetupScreen
    jsr SetupSprites
    jsr SetupInterrupt
    stb #GAME_MODE_ATTRACT:GameMode
    jmp GameLoop

/*
    The interrupt runs 60 times a second and is responsible mostly for maintaining timers.
    For more information, look at the lib/timers.asm file. This bit of code can be used
    to run continuous or one-off items.
*/
SetupInterrupt:
    sei

    lda #LOWER7
    sta vic.CIAICR
    sta vic.CI2ICR

    lda vic.CIAICR
    lda vic.CI2ICR

    lda #$01
    sta vic.VICIRQ
    sta vic.IRQMSK

    stb #$00:vic.RASTER
    stb #$1b:vic.SCROLY
    stb #$35:$01

    StoreWord(IRQ_VECTOR, Irq)

    cli
    rts

/*
    Configure the 4 sprites that we use to indicate which key to press for each
    button. Each sprite is multicolor with a drop shadow.
*/
SetupSprites:
    stb #vic.BLACK:vic.SPMC1
    stb #vic.DK_GRAY:vic.SP0COL
    stb #vic.DK_GRAY:vic.SP1COL
    stb #vic.DK_GRAY:vic.SP2COL
    stb #vic.DK_GRAY:vic.SP3COL

    stb #Sprites/$40:$0400 + $03f8
    stb #(Sprites/$40)+$01:$0400 + $03f8 + $01
    stb #(Sprites/$40)+$02:$0400 + $03f8 + $02
    stb #(Sprites/$40)+$03:$0400 + $03f8 + $03

    stb #$00:vic.SPENA  // Disable sprites 0 - 3
    stb #$0f:vic.SPMC   // Enable multicolor sprites for 0 - 3

    stb #52:vic.SP0X
    stb #135:vic.SP0Y

    stb #132:vic.SP1X
    stb #135:vic.SP1Y

    stb #212:vic.SP2X
    stb #135:vic.SP2Y

    stb #$08:vic.MSIGX  // Need to set MSB for sprite 3

    stb #35:vic.SP3X
    stb #135:vic.SP3Y

    rts

SetupTimers:
    CreateTimer(2, ENABLE, TIMER_CONTINUOUS, 10, AnimateTitle)
    CreateTimer(3, ENABLE, TIMER_CONTINUOUS, 5, AnimateStartMessage)

    rts

Irq:
    PushStack()

    jsr UpdateTimers
    lda GameMode
    cmp #GAME_MODE_ATTRACT
    bne !+
    jsr Keyboard
    bcs !+
    sta LastKeyboardKey
!:
    inc Clock
    bne !+
    inc Clock + $01

!:
    lda #$ff
    sta vic.VICIRQ

    PopStack()

    rti

SetupScreen:
    lda #vic.BLACK
    sta vic.EXTCOL
    sta vic.BGCOL0

    ClearScreen($0400, $20)
    ClearColorRam(vic.WHITE)

    WriteString($0436, TitleScreen)
    WriteString($d836, TitleScreenColor)

    WriteString($072a, StartMessage)

    jsr AllOff

    rts

GameLoop:
!:
    lda GameMode
    cmp #GAME_MODE_ATTRACT
    bne CheckComputer

    jsr Attract
    jmp !-

CheckComputer:
    cmp #GAME_MODE_COMPUTER                 // Is it the computer's turn?
    bne CheckHuman

    WriteString($0726, MyTurn)
    WriteString($db26, MyTurnColor)

    stb #$40:r7L                            // Wait a second
    jsr PauseJiffies

    ldx #$00
    stx r8H
!:
    ldx r8H
    lda GamePattern, x                      // Get the current note
    cmp #$00                                // Have we reached the end of the pattern?
    beq !+
    sta r2H
    stb #$30:r7L
    stb #$05:r7H
    jsr ButtonWithSound
    jsr ButtonHold
    inc r8H

    jmp !-

!:
    jsr GenerateRandom                      // Generate a new note and tack it onto the end of the pattern
    sta GamePattern, x
    sta r2H
    stb #$30:r7L
    stb #$05:r7H
    jsr ButtonWithSound
    jsr ButtonHold

    stb #GAME_MODE_HUMAN:GameMode           // Pass over to the human to recreate

    jmp GameLoop

CheckHuman:
    cmp #GAME_MODE_HUMAN                    // Is it the human's turn?
    bne CheckFail

    WriteString($0722, YourTurn)
    WriteString($db22, YourTurnColor)

    ldx #$00
    stx r8H
!:
    ldx r8H
    lda GamePattern, x                      // Grab the move in the pattern so that we can make sure the human plays the same note
    sta r12L
    cmp #$00                                // End of the pattern?
    bne !+
    stb #GAME_MODE_COMPUTER:GameMode        // Yup. Computer's turn again
    jmp GameLoop

!:
    jsr Keyboard
    bcs !-

    sec
    sbc #$31
    cmp #$04
    bcs !++
    clc
    adc #$01

    cmp r12L                                // Is this the right note?

    beq !+
    stb #GAME_MODE_FAIL:GameMode           // Wrong note. FAILED!
    jmp GameLoop
!:
    sta r2H
    jsr ButtonWithSound

!:
    jsr Keyboard                            // Wait for button to be released
    cmp #$ff
    beq !-

    jsr AllOff
    jsr StopSound
    inc r8H

    jmp !----

CheckFail:
    cmp #GAME_MODE_FAIL
    bne !+

    lda #$00
    jsr PlaySound
    stb #$40:r7L
    jsr PauseJiffies
    jsr StopSound

    stb #GAME_MODE_COMPUTER:GameMode

!:
    jmp GameLoop

Attract:
    lda LastKeyboardKey
    beq !++
    stb #GAME_MODE_COMPUTER:GameMode        // Key was pressed. Make it the computer's turn
    stb #$0f:vic.SPENA  // Enable sprites 0 - 3
    jsr AllOff
    stb #$03:r2H
    stb #DISABLE:r3L
    jsr EnDisTimer
    ldx #TitleScreen - StartMessage
    lda #$20

!:
    sta $0729, x
    dex
    bne !-
    jmp !++
!:
    jsr GenerateRandom                      // Randomly flash buttons in attract mode
    sta r2H
    jsr TurnButtonOn
    stb #$20:r7L
    jsr PauseJiffies
    jsr AllOff
!:
    rts

WriteString:
    ldy #$00
!:
    lda (r6), y
    beq !++
    sta (r5), y
    iny
    bne !+
    inc r6H
    inc r5H
!:
    jmp !--
!:
    rts

AnimateTitle:
    ldx #$00
    ldy CurrentTitleColor
!:
    lda TitleScreenColor, y
    sta $d836, x
    inx
    iny
    cpx #$0c
    bne !-
    inc CurrentTitleColor
    lda CurrentTitleColor
    cmp #$0c
    bne !+
    lda #$00
    sta CurrentTitleColor
!:
    rts

AnimateStartMessage:
    ldx #$00
    ldy CurrentStartMessageColor
    lda StartMessageColors, y
!:
    sta $db2a, x
    inx
    cpx #TitleScreen - StartMessage
    bne !-
    inc CurrentStartMessageColor
    lda CurrentStartMessageColor
    cmp #$08
    bne !+
    lda #$00
    sta CurrentStartMessageColor
!:
    rts

StartMessage:
    .encoding "screencode_mixed"
    .text "press any key to start"
    .byte $00

TitleScreen:
    .encoding "screencode_mixed"
    .text "follow me v1"
    .byte $00

MyTurn:
    .encoding "screencode_mixed"
    .text "watch and listen carefully!"
    .byte $00

MyTurnColor:
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte vic.WHITE, vic.WHITE, vic.WHITE
    .byte $00

YourTurn:
    .encoding "screencode_mixed"
    .text "your turn! show me what ya got, kid!"
    .byte $00

YourTurnColor:
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte $00

TitleScreenColor:
    .byte $0a, $07, $0d, $0e, $0a, $07, $0d, $0e, $0a, $07, $0d, $0e, $0a, $07, $0d, $0e, $0a, $07, $0d, $0e, $0a, $07, $0d, $0e
    .byte $00

StartMessageColors:
    .byte $00, $0b, $0c, $0f, $01, $0f, $0c, $0b

Buttons:
    .byte $55, $43, $43, $43, $43, $43, $43, $43, $43, $49, $55, $43, $43, $43, $43, $43, $43, $43, $43, $49, $55, $43, $43, $43, $43, $43, $43, $43, $43, $49, $55, $43, $43, $43, $43, $43, $43, $43, $43, $49
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d, $5d, $66, $66, $66, $66, $66, $66, $66, $66, $5d
    .byte $4a, $43, $43, $43, $43, $43, $43, $43, $43, $4b, $4a, $43, $43, $43, $43, $43, $43, $43, $43, $4b, $4a, $43, $43, $43, $43, $43, $43, $43, $43, $4b, $4a, $43, $43, $43, $43, $43, $43, $43, $43, $4b
    .byte $00

ButtonColors:
    .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $08, $08, $08, $08, $08, $08, $08, $08, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $06, $06, $06, $06, $06, $06, $06, $06, $01
    .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte $00

    .align $40
Sprites:
    // 1
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $29,$00,$00,$29,$00,$00,$a9,$00
    .byte $02,$a9,$00,$00,$29,$00,$00,$29
    .byte $00,$00,$29,$00,$00,$29,$00,$00
    .byte $29,$00,$00,$29,$00,$02,$aa,$90
    .byte $02,$aa,$90,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

    // 2
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $29,$00,$00,$aa,$40,$02,$92,$90
    .byte $02,$92,$90,$00,$02,$90,$00,$0a
    .byte $40,$00,$29,$00,$00,$a4,$00,$02
    .byte $90,$00,$02,$90,$00,$02,$aa,$90
    .byte $02,$aa,$90,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

    // 3
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $29,$00,$00,$aa,$40,$02,$92,$90
    .byte $00,$02,$90,$00,$02,$90,$00,$2a
    .byte $40,$00,$2a,$40,$00,$02,$90,$00
    .byte $02,$90,$02,$92,$90,$00,$aa,$40
    .byte $00,$29,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

    // 4
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$02
    .byte $92,$90,$02,$92,$90,$02,$92,$90
    .byte $02,$92,$90,$02,$92,$90,$02,$aa
    .byte $90,$02,$aa,$90,$00,$02,$90,$00
    .byte $02,$90,$00,$02,$90,$00,$02,$90
    .byte $00,$02,$90,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

CurrentStartMessageColor:
    .byte $00

CurrentTitleColor:
    .byte $00

// Storage for the moves. Each byte is a single note in the pattern.
// 100 bytes should be enough. I don't think many people will be able
// to follow a 100 note pattern. Maybe make a "You've won!" screen for
// those that can?
GamePattern:
    .fill $64, $00

GameMode:
    .byte $00

Clock:
    .word $00

LastKeyboardKey:
    .byte $00

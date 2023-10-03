/*

Follow Me

Commodore 64

Inspired by this series: https://www.youtube.com/watch?v=A7vYSsLS00Y&ab_channel=MyDeveloperThoughts

*/

#import "lib/all.asm"

.label SPRITES = (Sprites / $40)
.label TITLE_LOCATION = SCREEN_START + $36
.label MESSAGE_LOCATION = SCREEN_START + ($28 * $14)

.label SCORE_ONES = SPRITE_POINTERS + $07
.label SCORE_TENS = SPRITE_POINTERS + $06
.label SCORE_HUNDREDS = SPRITE_POINTERS + $05
.label SCORE_THOUSANDS = SPRITE_POINTERS + $04

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
    lda #vic.DK_GRAY
    sta vic.SP0COL
    sta vic.SP1COL
    sta vic.SP2COL
    sta vic.SP3COL

    lda #vic.WHITE
    sta vic.SP4COL
    sta vic.SP5COL
    sta vic.SP6COL
    sta vic.SP7COL

    // These are the sprites on the buttons
    stb #SPRITES+$01:SPRITE_POINTERS
    stb #SPRITES+$02:SPRITE_POINTERS + $01
    stb #SPRITES+$03:SPRITE_POINTERS + $02
    stb #SPRITES+$04:SPRITE_POINTERS + $03

    // These are the sprites for the score
    lda #SPRITES+$00
    sta SPRITE_POINTERS + $04
    sta SPRITE_POINTERS + $05
    sta SPRITE_POINTERS + $06
    sta SPRITE_POINTERS + $07

    stb #%11110000:vic.SPENA  // Disable sprites 0 - 3, but enable the score sprites
    stb #%11111111:vic.SPMC   // Enable multicolor sprites for 0 - 7

    lda #135
    sta vic.SP0Y
    sta vic.SP1Y
    sta vic.SP2Y
    sta vic.SP3Y

    lda #80
    sta vic.SP4Y
    sta vic.SP5Y
    sta vic.SP6Y
    sta vic.SP7Y

    stb #132:vic.SP4X
    stb #158:vic.SP5X
    stb #184:vic.SP6X
    stb #210:vic.SP7X

    stb #52:vic.SP0X
    stb #132:vic.SP1X
    stb #212:vic.SP2X

    stb #%00001000:vic.MSIGX  // Need to set MSB for sprite 3
    stb #35:vic.SP3X

    rts

SetupTimers:
    CreateTimer(2, ENABLE, TIMER_CONTINUOUS, 10, AnimateTitle)
    CreateTimer(3, ENABLE, TIMER_CONTINUOUS, 30, FlashButtons)

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

    ClearScreen(SCREEN_START, $20)
    ClearColorRam(vic.WHITE)

    WriteString(TITLE_LOCATION, TitleScreen)
    WriteString(TITLE_LOCATION + $d400, TitleScreenColor)

    WriteString(MESSAGE_LOCATION + $03, StartMessage)

    jsr AllOff

    rts

GameLoop:
    jsr UpdateScore
!:
    lda GameMode
    cmp #GAME_MODE_ATTRACT
    bne CheckComputer

    jsr Attract

    jmp !-

CheckComputer:
    cmp #GAME_MODE_COMPUTER                 // Is it the computer's turn?
    bne CheckHuman

    jsr ClearLine
    WriteString(MESSAGE_LOCATION + $06, MyTurn)
    WriteString(MESSAGE_LOCATION + $d400 + $06, MyTurnColor)

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
    stb GameSpeed:r7L
    stb #$05:r7H
    jsr ButtonWithSound
    jsr ButtonHold
    inc r8H

    jmp !-

!:
    jsr GenerateRandom                      // Generate a new note and tack it onto the end of the pattern
    sta GamePattern, x
    sta r2H
    stb GameSpeed:r7L
    stb #$05:r7H
    jsr ButtonWithSound
    jsr ButtonHold

    stb #GAME_MODE_HUMAN:GameMode           // Pass over to the human to recreate

    jmp GameLoop

CheckHuman:
    cmp #GAME_MODE_HUMAN                    // Is it the human's turn?
    beq !+
    jmp CheckFail

!:
    jsr ClearLine
    WriteString(MESSAGE_LOCATION + $02, YourTurn)
    WriteString(MESSAGE_LOCATION + $d400 + $02, YourTurnColor)

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

    sed
    lda Score + $01
    clc
    adc #$10                                // Add 10 points
    sta Score + $01
    bcc !+
    lda Score
    clc
    adc #$01
    sta Score

!:
    cld
    jsr Keyboard                            // Wait for button to be released
    cmp #$ff
    beq !-

    jsr AllOff
    jsr StopSound
    inc r8H

    jmp !----

CheckFail:
    cmp #GAME_MODE_FAIL
    bne CheckGameOver

    lda #$00
    sta Score
    sta Score + $01

    lda r12L
    sta r2H
    jsr TurnButtonOn
    lda #$00
    jsr PlaySound
    stb #$40:r7L
    jsr PauseJiffies
    jsr StopSound
    jsr AllOff

    stb #GAME_MODE_GAME_OVER:GameMode
    jmp GameLoop

CheckGameOver:
    cmp #GAME_MODE_GAME_OVER
    bne !++++

    jsr ClearLine
    WriteString(MESSAGE_LOCATION + $09, GameOver)
    WriteString(MESSAGE_LOCATION + $d400 + $09, GameOverColor)

!:
    jsr Keyboard
    bcs !-

    cmp #$19
    beq !+

    jsr ClearLine
    WriteString(MESSAGE_LOCATION + $06, SeeYa)
    WriteString(MESSAGE_LOCATION + $d400 + $06, SeeYaColor)

    stb #$37:$01                                // Turn the kernal back on and reset the machine
    jsr $fce2

!:
    stb #GAME_MODE_COMPUTER:GameMode
    ldx #$64
    lda #$00
!:
    sta GamePattern, x
    dex
    bpl !-

!:
    jmp GameLoop

Attract:
    jsr Keyboard
    bcs !++

    sec
    sbc #$31
    cmp #$05
    bcs !++

    clc
    adc #$01

    asl
    asl

    sta GameSpeed

    stb #GAME_MODE_COMPUTER:GameMode        // Key was pressed. Make it the computer's turn
    stb #%11111111:vic.SPENA  // Enable sprites 0 - 3
    jsr AllOff
    stb #$03:r2H
    stb #DISABLE:r3L
    jsr EnDisTimer
    ldx #TitleScreen - StartMessage
    lda #$20

!:
    sta MESSAGE_LOCATION, x
    dex
    bne !-
    jmp !++

!:
    rts

FlashButtons:
    lda GameMode
    cmp #GAME_MODE_ATTRACT
    bne !+
    jsr AllOff
    jsr GenerateRandom
    sta r2H
    jsr TurnButtonOn
!:
    rts

/*
    Update the score sprites. Score is stored as 2 BCD bytes.
    One for thousands and hundreds and one for tens and ones
*/
UpdateScore:
    // Ones
    lda Score + $01
    and #$0f
    clc
    adc #SPRITES
    sta SCORE_ONES

    // Tens
    lda Score + $01
    and #$f0
    div16
    clc
    adc #SPRITES
    sta SCORE_TENS

    // Hundreds
    lda Score
    and #$0f
    clc
    adc #SPRITES
    sta SCORE_HUNDREDS

    // Thousands
    lda Score
    and #$f0
    div16
    clc
    adc #SPRITES
    sta SCORE_THOUSANDS

    rts

/*
    Write bytes to a location in memory. This can be used for characters as well as colors

    Requires:
    r6: Address of null terminated data to write
    r5: Start address to write data
*/
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

/*
    Clear the message line on the screen
*/
ClearLine:
    ldy #$00
    lda #$20
!:
    sta MESSAGE_LOCATION, y
    iny
    cpy #$28
    bne !-
    rts

AnimateTitle:
    ldx #$00
    ldy CurrentTitleColor
!:
    lda TitleScreenColor, y
    sta TITLE_LOCATION + $d400, x
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

    .align $40
Sprites:
    // 0
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $29,$00,$00,$aa,$40,$02,$82,$90
    .byte $02,$82,$90,$02,$82,$90,$02,$8a
    .byte $90,$02,$a2,$90,$02,$82,$90,$02
    .byte $82,$90,$02,$82,$90,$00,$aa,$40
    .byte $00,$29,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

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

    // 5
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$02
    .byte $aa,$90,$02,$92,$90,$02,$90,$00
    .byte $02,$90,$00,$02,$90,$00,$02,$aa
    .byte $40,$00,$aa,$90,$00,$02,$90,$00
    .byte $02,$90,$02,$92,$90,$02,$9a,$40
    .byte $00,$a9,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

    // 6
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $0a,$90,$00,$2a,$90,$00,$a4,$00
    .byte $02,$90,$00,$02,$99,$00,$02,$aa
    .byte $90,$02,$a6,$90,$02,$92,$90,$02
    .byte $92,$90,$02,$92,$90,$02,$92,$90
    .byte $00,$aa,$40,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

    // 7
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $aa,$a4,$00,$00,$a4,$00,$00,$a4
    .byte $00,$02,$90,$00,$02,$90,$00,$0a
    .byte $40,$00,$0a,$40,$00,$29,$00,$00
    .byte $29,$00,$00,$29,$00,$00,$29,$00
    .byte $00,$29,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

    // 8
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $29,$00,$00,$aa,$40,$02,$92,$90
    .byte $02,$92,$90,$02,$92,$90,$00,$aa
    .byte $40,$02,$92,$90,$02,$92,$90,$02
    .byte $92,$90,$02,$92,$90,$00,$aa,$40
    .byte $00,$29,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

    // 9
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $aa,$40,$02,$92,$90,$02,$92,$90
    .byte $02,$92,$90,$02,$92,$90,$02,$9a
    .byte $90,$02,$aa,$90,$00,$26,$90,$00
    .byte $02,$90,$00,$0a,$40,$02,$a9,$00
    .byte $02,$a4,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$81

StartMessage:
    .encoding "screencode_mixed"
    .text "select level: 1 (fast) - 5 (slow)"
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

GameOver:
    .encoding "screencode_mixed"
    .text "game over. play again?"
    .byte $00

GameOverColor:
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte $00

SeeYa:
    .encoding "screencode_mixed"
    .text "thanks for playing! see ya!"
    .byte $00

SeeYaColor:
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE, vic.WHITE
    .byte vic.WHITE, vic.WHITE, vic.WHITE
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

CurrentStartMessageColor:
    .byte $00

CurrentTitleColor:
    .byte $00

GameMode:
    .byte $00

Clock:
    .word $0000

LastKeyboardKey:
    .byte $00

Score:
    .word $0000

GameSpeed:
    .byte $00

// Storage for the moves. Each byte is a single note in the pattern.
// 100 bytes should be enough. I don't think many people will be able
// to follow a 100 note pattern. Maybe make a "You've won!" screen for
// those that can?
GamePattern:
    .fill $64, $00

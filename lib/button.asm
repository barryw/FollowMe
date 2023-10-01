/*
    Light a button and play corresponding sound. This will pause once the button
    is lit for a period determined by x and then again once the button is turned
    off by a period determimed by y. The period is in jiffies (1/60sec)

    Requires:
    a: A number from 1-4 for the button to light
    x: Number of jiffies to keep the button lit for
    y: Number of jiffies to wait before returning after the button is turned off
*/
ButtonWithSound:
    sta r2H
    stx r8L
    sty r8H
    jsr PlaySound
    ldx r2H
    txa
    pha
    lda #vic.WHITE
    sta vic.SPMC1, x
    jsr TurnButtonOn
    ldx r8L
    stx r7L
    jsr PauseJiffies
    jsr StopSound
    pla
    tax
    lda #vic.DK_GRAY
    sta vic.SPMC1, x
    jsr AllOff
    ldy r8H
    sty r7L
    jsr PauseJiffies

    rts

/*
    Turn all buttons off
*/
AllOff:
    WriteString($0518, Buttons)
    WriteString($d918, ButtonColors)

    rts

/*
    Turn on a button. This does not turn the button off. You're responsible for that!

    Requires:
    r2H: A number between 1 and 4 of the button to turn on.
*/
TurnButtonOn:
    lda r2H

    cmp #$01
    bne !+
    stb #<RED_ADDRESS:r0L
    stb #>RED_ADDRESS:r0H
    stb #vic.LT_RED:r2L
    jmp !++++
!:
    cmp #$02
    bne !+
    stb #<YELLOW_ADDRESS:r0L
    stb #>YELLOW_ADDRESS:r0H
    stb #vic.YELLOW:r2L
    jmp !+++
!:
    cmp #$03
    bne !+
    stb #<GREEN_ADDRESS:r0L
    stb #>GREEN_ADDRESS:r0H
    stb #vic.LT_GREEN:r2L
    jmp !++
!:
    cmp #$04
    bne !+
    stb #<BLUE_ADDRESS:r0L
    stb #>BLUE_ADDRESS:r0H
    stb #vic.LT_BLUE:r2L

!:
    jsr LightButton
    rts

/*
    Draw the button and color it. Each button is 8x8 characters.

    Requires:
    r0: Start screen address of the button to light up
    r2L: The color to light the button
*/
LightButton:
    ldx #$00
    ldy #$00
!:
    lda #$a0
    sta (r0), y

    // Write to color ram
    lda r0L
    sta r1L
    lda r0H
    clc
    adc #$d4
    sta r1H
    lda r2L
    sta (r1), y

    iny
    cpy #$08
    bne !-
    ldy #$00
    clc
    lda r0L
    adc #$28
    sta r0L
    bcc !+
    inc r0H
!:
    inx
    cpx #$08
    bne !--

    rts

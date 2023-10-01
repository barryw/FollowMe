#importonce

InitSound:
    ldx #$18
    lda #$00
!:
    sta sid.FRELO1, x
    dex
    bpl !-
    stb #$0f:sid.SIGVOL
    stb #$22:sid.ATDCY1
    stb #$80:sid.SUREL1

    rts

PlaySound:
    pha
    tax
    lda Waveforms, x
    sta CurrentWaveform
    pla
    asl
    tax
    lda Notes, x
    sta sid.FREHI1
    lda Notes + 1, x
    sta sid.FRELO1

    lda CurrentWaveform
    sta sid.VCREG1

    rts

StopSound:
    dec CurrentWaveform
    lda CurrentWaveform
    sta sid.VCREG1

    rts

Notes:
    .byte 8,97      // Fail
    .byte 12,143    // G blue
    .byte 16,195    // C yellow
    .byte 21,31     // E red
    .byte 25,30     // G green

Waveforms:
    .byte sid.WAVE_NOISE, sid.WAVE_TRIANGLE, sid.WAVE_TRIANGLE, sid.WAVE_TRIANGLE, sid.WAVE_TRIANGLE

CurrentWaveform:
    .byte $00

INCLUDE "hardware.inc"

; ---------------------------------------------------------------------------
; Interrupt vectors
; ---------------------------------------------------------------------------
SECTION "Vblank", ROM0[$0040]
    reti

SECTION "LCDC", ROM0[$0048]
    reti

SECTION "Timer", ROM0[$0050]
    reti

SECTION "Serial", ROM0[$0058]
    reti

SECTION "Joypad", ROM0[$0060]
    reti

; ---------------------------------------------------------------------------
; Entry point ($0100 -> $0150 is header space, patched by rgbfix)
; ---------------------------------------------------------------------------
SECTION "Entry", ROM0[$0100]
    nop
    jp Start

SECTION "Header", ROM0[$0104]
    ds $150 - $104 ; rgbfix fills in the logo/title/checksum bytes

; ---------------------------------------------------------------------------
; Main
; ---------------------------------------------------------------------------
SECTION "Main", ROM0[$0150]
Start:
    ; TODO - disable LCD, load tiles/palette, enable LCD, init game state

    ; Allow the VBlank interrupt to fire, and let the CPU actually respond
    ; to it—this is what lets `halt` in .loop wake up once per frame.
    ld a, IE_VBLANK
    ld [rIE], a
    ei

    ;; starting yPos
    ; wYPos = LANDER_Y_ST.0 (8.8 fixed-point: low byte = fraction, high byte
    ; = whole pixels)
    ld a, 0
    ld [wYPos], a
    ld a, LANDER_Y_ST
    ld [wYPos+1], a

    ;; starting yVel
    ; wYVel = 0—ship isn't moving yet at boot
    ld a, 0
    ld [wYVel], a
    ld [wYVel+1], a

    ;; set acc of grav
    ; wYAcc = ACC_OF_GRAV—constant downward pull applied every frame
    ; by UpdatePhysics (Requirement 1: falls under gravity)
    ld a, LOW(ACC_OF_GRAV)
    ld [wYAcc], a
    ld a, HIGH(ACC_OF_GRAV)
    ld [wYAcc+1], a

.loop:
    ; Sleep until the next VBlank interrupt, then advance the simulation
    ; by exactly one frame.
    halt
    ; TODO: call ReadInput and an acceleration-update routine here once
    ; input should start affecting wXAcc/wYAcc (worksheet 5)
    call UpdatePhysics
    nop
    jr .loop


; ---------------------------------------------------------------------------
; ReadInput
; Polls the D-pad and records which of Left/Right are currently held into
; wLeft/wRight (1 = held, 0 = not held). Doesn't touch acceleration itself
;—that's a separate routine's job (Requirement 2 keeps input handling and
; physics decoupled).
; ---------------------------------------------------------------------------
ReadInput:
	; Default both flags to "not held"; only overwritten below if a
	; direction bit actually reads as pressed.
	ld a, 0
	ld [wLeft], a
	ld [wRight], a

	; Select the Control Pad (D-pad) group on rJOYP.
	ld a, JOYP_GET_CTRL_PAD
	ld [rJOYP], a

	; Throwaway reads—let the signal settle after switching groups.
	ld a, [rJOYP]
	ld a, [rJOYP]

	; Real read. Stash the raw byte in b so both the Left and Right
	; tests below can reuse it without re-reading hardware.
	ld a, [rJOYP]
	ld b, a

	; Active-low: a bit reads 0 when its button is held. AND-ing against
	; a single bit mask leaves the zero flag set exactly when that bit
	; was 0, i.e. pressed.
	and a, JOYP_LEFT ; sets the zero flag
	jr nz, .right
	ld a, 1
	ld [wLeft], a
.right:
	ld a, b

	and a, JOYP_RIGHT
	jr nz, .end
	ld a, 1
	ld [wRight], a
.end:
	ret


; ---------------------------------------------------------------------------
; UpdatePhysics
; Advances the Y-axis simulation by one frame:
;   wYVel += wYAcc
;   wYPos += wYVel
; All three variables are 16-bit 8.8 fixed-point. The SM83 only adds
; register pairs, not memory operands directly, so each addition is
; loaded into a pair, added, then stored back out.
; ---------------------------------------------------------------------------
UpdatePhysics:
	;; add acceleration to velocity
	ld a, [wYVel]   ; low byte: fraction of pixel
	ld l, a
	ld a, [wYVel+1] ; high byte: whole pixel
	ld h, a

	ld a, [wYAcc]   ; low byte: fraction of pixel
	ld c, a
	ld a, [wYAcc+1] ; high byte: whole pixel
	ld b, a

	add hl, bc

	;; save back into velocity
	ld a, l
	ld [wYVel], a
	ld a, h
	ld [wYVel+1], a

	;; add velocity to position
	ld a, [wYPos]
	ld l, a
	ld a, [wYPos+1]
	ld h, a

	ld a, [wYVel]
	ld c, a
	ld a, [wYVel+1]
	ld b, a

	add hl, bc

	;; save back into position
	ld a, l
	ld [wYPos], a
	ld a, h
	ld [wYPos+1], a


; ---------------------------------------------------------------------------
; Ship state (WRAM)
; ---------------------------------------------------------------------------
SECTION "Ship State", WRAM0

; lander—Y-axis, 8.8 fixed-point
wYPos: dw
wYVel: dw
wYAcc: dw

; pad state—1 = held, 0 = not held, refreshed once per frame by ReadInput
wLeft: db
wRight: db

DEF ACC_OF_GRAV EQU $0008 ; gravity: 1/32 px/frame², applied to wYAcc
DEF LANDER_Y_ST EQU 0     ; ship's starting Y position (whole pixels)

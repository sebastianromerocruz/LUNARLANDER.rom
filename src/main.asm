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



SECTION "Main", ROM0[$0150]
Start:
    ; TODO: disable LCD, load tiles/palette, enable LCD, init game state
    ld a, IEF_VBLANK
    ld [rIE], a
    ei
.loop:
    halt
    call UpdatePhysics
    nop
    jr .loop


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


SECTION "Ship State", WRAM0

; lander
wYPos: dw
wYVel: dw
wYAcc: dw

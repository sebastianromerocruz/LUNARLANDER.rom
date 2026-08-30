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
    ; TODO: turn LCD off, load ShipTile into VRAM, set up OAM entry 0 and
    ; rOBP0, turn LCD back on (worksheet 6)

    ; Allow the VBlank interrupt to fire, and let the CPU actually respond
    ; to it—this is what lets `halt` in .loop wake up once per frame.
    ld a, IE_VBLANK
    ld [rIE], a
    ei

    ; Turn LCD off
    ld a, 0
    ld [rLCDC], a

    ld de, ShipTile
    ld hl, $8000
    ld bc, ShipTileEnd - ShipTile
    call Memcpy

    ; wYPos/wXPos = starting position (8.8 fixed-point: low byte = fraction,
    ; high byte = whole pixels). Only the high byte is meaningful at boot.
    ld a, 0
    ld [wYPos], a
    ld a, LANDER_Y_ST
    ld [wYPos+1], a

    ld a, 0
    ld [wXPos], a
    ld a, LANDER_X_ST
    ld [wXPos+1], a

    ; wYVel/wXVel = 0; ship isn't moving yet at boot.
    ld a, 0
    ld [wYVel], a
    ld [wYVel+1], a
    ld [wXVel], a
    ld [wXVel+1], a

    ; wYAcc = ACC_OF_GRAV; constant downward pull applied every frame by
    ; UpdatePhysics (Requirement 1: falls under gravity).
    ld a, LOW(ACC_OF_GRAV)
    ld [wYAcc], a
    ld a, HIGH(ACC_OF_GRAV)
    ld [wYAcc+1], a

    ; wXAcc = 0; no horizontal pull until UpdateAcceleration sets it from
    ; input, once per frame.
    ld a, 0
    ld [wXAcc], a
    ld [wXAcc+1], a

    ld d, 0 ; initialize OAM with 0s
	ld hl, OAM_START ; start of OAM
	ld bc, OAM_SIZE
	call SetOAM

	; Turn the LCD on
	ld a, LCDC_ON | LCDC_OBJ_ON
	ld [rLCDC], a

	ld a, %11100100
	ld [rOBP0], a

.loop:
    ; Sleep until the next VBlank interrupt, then advance the simulation
    ; by exactly one frame, in order: read this frame's input, let it
    ; decide this frame's horizontal acceleration, then integrate physics.
    halt
    call ReadInput
    call UpdateAcceleration
    call UpdatePhysics
    call UpdateSprite
    nop
    jr .loop

UpdateSprite:
	ld hl, OAM_START
	ld a, [wYPos+1]
	add a, OAM_Y_OFF
	ld [hli], a

	ld a, [wXPos+1]
	add a, OAM_X_OFF
	ld [hli], a
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set OAM
;; - Copies bc bytes from d-register to [hl], one byte at a time.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    SetOAM:
	ld a, d
	ld [hli], a
	dec bc
	ld a, b
	or a, c
	jr nz, SetOAM
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Memcpy
;; - Copies bc bytes from de-register to hl-register, one byte at a time.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Memcpy:
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jr nz, Memcpy
	ret

; ---------------------------------------------------------------------------
; UpdateAcceleration
; Sets wXAcc from this frame's wLeft/wRight flags (Requirement 2: input
; changes acceleration, never velocity or position directly). Left wins
; if both are somehow held at once, since it's checked first and returns
; immediately.
; ---------------------------------------------------------------------------
UpdateAcceleration:
	ld a, [wLeft]
	cp a, 1
	jr nz, .Right
	ld a, LOW(-ACC_MOVE)
	ld [wXAcc], a
	ld a, HIGH(-ACC_MOVE)
	ld [wXAcc+1], a
	ret
.Right:
	ld a, [wRight]
	cp a, 1
	jr nz, .End
	ld a, LOW(ACC_MOVE)
	ld [wXAcc], a
	ld a, HIGH(ACC_MOVE)
	ld [wXAcc+1], a
	ret
.End:
	; Neither held: no horizontal thrust this frame. wXVel is untouched,
	; so the ship keeps drifting at whatever speed it already had.
	ld a, 0
	ld [wXAcc], a
	ld [wXAcc+1], a
	ret

; ---------------------------------------------------------------------------
; ReadInput
; Polls the D-pad and records which of Left/Right are currently held into
; wLeft/wRight (1 = held, 0 = not held). Doesn't touch acceleration itself—
; that's a separate routine's job (Requirement 2 keeps input handling and
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
	;; Y-PHYSICS
	; add acceleration to velocity
	ld a, [wYVel]   ; low byte: fraction of pixel
	ld l, a
	ld a, [wYVel+1] ; high byte: whole pixel
	ld h, a

	ld a, [wYAcc]   ; low byte: fraction of pixel
	ld c, a
	ld a, [wYAcc+1] ; high byte: whole pixel
	ld b, a

	add hl, bc

	; save back into velocity
	ld a, l
	ld [wYVel], a
	ld a, h
	ld [wYVel+1], a

	; add velocity to position
	ld a, [wYPos]
	ld l, a
	ld a, [wYPos+1]
	ld h, a

	ld a, [wYVel]
	ld c, a
	ld a, [wYVel+1]
	ld b, a

	add hl, bc

	; save back into position
	ld a, l
	ld [wYPos], a
	ld a, h
	ld [wYPos+1], a

	;; X-PHYSICS ;;
	ld a, [wXVel]
	ld l, a
	ld a, [wXVel+1]
	ld h, a

	ld a, [wXAcc]
	ld c, a
	ld a, [wXAcc+1]
	ld b, a

	add hl, bc

	ld a, l
	ld [wXVel], a
	ld a, h
	ld [wXVel+1], a

	; add velocity to position
	ld a, [wXPos]
	ld l, a
	ld a, [wXPos+1]
	ld h, a

	ld a, [wXVel]
	ld c, a
	ld a, [wXVel+1]
	ld b, a

	add hl, bc

	ld a, l
	ld [wXPos], a
	ld a, h
	ld [wXPos+1], a

	ret

; ---------------------------------------------------------------------------
; Ship graphics (ROM)
; A single solid-color 8x8 tile (2bpp), a rounded capsule with two landing
; legs. Placeholder art, swap out whenever. Each row is two identical
; bytes since every drawn pixel uses color index 3 (both bitplanes set).
; ---------------------------------------------------------------------------
SECTION "Ship Graphics", ROM0

ShipTile:
	db $18, $18 ; ...##...
	db $3C, $3C ; ..####..
	db $3C, $3C ; ..####..
	db $7E, $7E ; .######.
	db $FF, $FF ; ########
	db $7E, $7E ; .######.
	db $42, $42 ; .#....#.
	db $81, $81 ; #......#
ShipTileEnd:

; ---------------------------------------------------------------------------
; Ship state (WRAM)
; ---------------------------------------------------------------------------
SECTION "Ship State", WRAM0

; lander—Y-axis, 8.8 fixed-point
wYPos: dw
wYVel: dw
wYAcc: dw

; lander—X-axis, 8.8 fixed-point
wXPos: dw
wXVel: dw
wXAcc: dw

; pad state—1 = held, 0 = not held, refreshed once per frame by ReadInput
wLeft: db
wRight: db

DEF ACC_OF_GRAV EQU $0001 ; gravity: 1/256 px/frame², applied to wYAcc
DEF ACC_MOVE    EQU $0001 ; horizontal acceleration
DEF LANDER_Y_ST EQU 0     ; ship's starting Y position (whole pixels)
DEF LANDER_X_ST EQU 88

; OAM related
DEF OAM_START      EQU $FE00
DEF BALL_OAM       EQU $FE0C
DEF OAM_Y_OFF	   EQU 16
DEF OAM_X_OFF	   EQU 8

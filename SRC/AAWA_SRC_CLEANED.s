                  ;;;;;;;;;;;;
                  ;; AAWA.S ;;
                  ;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Adventure of the Adventure Writers Adventure ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

               ;;;;;;;;;;;;;;;;;
               ;; By Ken Rose ;;
               ;;;;;;;;;;;;;;;;;

       ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       ;; CA65 port by mpower-codeworks ;;
       ;;    size-coding experiments    ;;
       ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
         ;; This file has the comments ;;
         ;;   cleaned for redability   ;; 
         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -------
;; history
;; -------
;; 001  port to ca65                2039 bytes
;; 002  use zeroed DATA             1998 bytes
;; 003  direct map access           1891 bytes
;; 004  table parser                1738 bytes
;; 005  ROM line input              1592 bytes
;; 006  5-bit text                  1483 bytes
;; 007  output calls                1407 bytes
;; 008  monster collapse            1352 bytes
;; 009  treasure bitmask            1300 bytes
;; 010  nibble map                  1271 bytes
;; 011  raw SYS - set manually $FF  1213 bytes
;; 012  no ZP preserve              1191 bytes
;; 013  control/state consolidate   1123 bytes
;; 014  zero-page/fold              1076 bytes
;; 015  final code fold             1023 bytes
;; 016  page-folded messages         999 bytes
;; 017  add cls                      998 bytes
;; 018  never quit (reboot for new)  987 bytes
;; 019  fix help pointer gibberish   989 bytes

;;;;;;;;;;
;; init ;;
;;;;;;;;;;
.setcpu "6502"

;;;;;;;;;;;;;;;;;;
;; Apple II ROM ;;
;;;;;;;;;;;;;;;;;;
COUT   = $FDED ; character output
CROUT  = $FD8E ; carriage return
HOME   = $FC58 ; clear text screen
GETLN1 = $FD6F ; ROM line input
PRODOS = $BF00 ; ProDOS MLI

INPUT_BUFFER = $0200 ; ROM input buffer

;;;;;;;;;;;;;;;
;; zero page ;;
;;;;;;;;;;;;;;;
PRINT_PTR       = $06
PRINT_PTR_HI    = $07
room            = $08
direction       = $09
input_len       = $0A
token_start     = $0B
token_len       = $0C
level           = $0D
blocked_count   = $0E
treasures       = $0F

;;;;;;;;;;;;;;;
;; constants ;;
;;;;;;;;;;;;;;;
DIR_NORTH = 0
DIR_SOUTH = 1
DIR_EAST  = 2
DIR_WEST  = 3
INPUT_MAX = 63

;;;;;;;;;;;;
;; output ;;
;;;;;;;;;;;;
.macro PRINT text
        lda     #<text
        ldx     #>text
        jsr     print_string
.endmacro
.macro PRINTLN text
        lda     #<text
        ldx     #>text
        jsr     print_line
.endmacro
.macro PRINTNL text
        lda     #<text
        ldx     #>text
        jsr     print_nl
.endmacro
.macro PRINT22LN text
        lda     #<text
        jsr     print22_line
.endmacro
.macro PRINT22NL text
        lda     #<text
        jsr     print22_nl
.endmacro

;;;;;;;;;;;;;
;; startup ;;
;;;;;;;;;;;;;
        .segment "STARTUP"
Start:
        jsr     HOME
        ldx     #0
        stx     level
        stx     treasures
        inx
        stx     room
        ;; INX leaves Z clear so AppStart
        ;; skips bad_direction
        .segment "CODE"
AppStart:
        bne     main_loop

;;;;;;;;;;;;;;;;;;
;; command loop ;;
;;;;;;;;;;;;;;;;;;
bad_direction:
        PRINTNL msg_only_directions
main_loop:
        jsr     prompt_direction
        bcc     bad_direction
        jsr     move_player
        jsr     post_move
        jmp     main_loop

;;;;;;;;;;;
;; input ;;
;;;;;;;;;;;
prompt_direction:
        PRINT22NL msg_prompt
        jsr     CROUT
        lda     #$BF
        jsr     COUT
        lda     #$A0
        jsr     COUT
        jsr     GETLN1
        stx     input_len

;;;;;;;;;;;;
;; parser ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; uses text after the first ;;
;; space when present        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
parse_direction:
        ldy     #0
@find_space:
        cpy     input_len
        beq     @no_space
        lda     INPUT_BUFFER,y
        and     #$5F
        beq     @found_space
        iny
        bne     @find_space
@no_space:
        ldy     #$FF
@found_space:
        iny
@have_start:
        tya
        eor     #$FF
        sec
        adc     input_len
        sta     token_len
        beq     @parse_fail
        lda     INPUT_BUFFER,y
        and     #$5F
        ldx     #3
@find_dir:
        cmp     dir_initials,x
        beq     @dir_found
        dex
        bpl     @find_dir
@parse_fail:
        clc
        rts
@dir_found:
        stx     direction
        lda     token_len
        cmp     #1
        beq     @parse_ok
        cmp     dir_lengths,x
        bne     @parse_fail
        txa
        asl
        asl
        tax
        iny
@compare:
        cpy     input_len
        beq     @parse_ok
        lda     INPUT_BUFFER,y
        and     #$5F
        cmp     dir_suffixes,x
        bne     @parse_fail
        iny
        inx
        bne     @compare
@parse_ok:
        sec
        rts

;;;;;;;;;;;;;;
;; movement ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; packed map: two destinations per byte ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
move_player:
        lda     room
        asl
        asl
        adc     direction
        sbc     #3
        tax
        lda     level
        beq     @map_ready
        txa
        adc     #39
        tax
@map_ready:
        txa
        lsr
        tax
        lda     map_data,x
        bcc     @map_low
        lsr
        lsr
        lsr
        lsr
@map_low:
        and     #$0F
@destination:
        beq     @blocked
        cmp     #11
        bne     @store_room
        inc     level
        lsr     direction
        bcs     :+
        inc     level
:
        PRINT22NL msg_new_level
        lda     #1
@store_room:
        sta     room
        lda     #0
        sta     blocked_count
        rts
@blocked:
        PRINT22NL msg_cant_move
        inc     blocked_count
        rts

;;;;;;;;;;;;;;;;;;;
;; level actions ;;
;;;;;;;;;;;;;;;;;;;
post_move:
        lda     level
        bne     post_higher
collect_treasures:
        ldx     room
        lda     treasure_bits-1,x
        ora     treasures
        sta     treasures
        rts
post_higher:
        pha
        jsr     show_inventory
        pla
        cmp     #3
        beq     level_three_action
        bcc     check_monsters
finish_game:
        lda     #<msg_lost
        ldx     treasures
        cpx     #$0F
        bne     @finish_text
        lda     #<msg_won
@finish_text:
        ldx     #>msg_won
        jsr     print_nl
exit_program:
        jmp     exit_program

;;;;;;;;;;;;;;
;; monsters ;;
;;;;;;;;;;;;;;
check_monsters:
        lda     room
        cmp     #9
        beq     @monster
        and     #3
        cmp     #3
        bne     @done
@monster:
        lda     blocked_count
        cmp     #2
        bcs     monster_gotcha
        PRINT22NL msg_hurry
        jsr     print_monster
        PRINT22LN msg_after_you
        inc     blocked_count
@done:
        rts
monster_gotcha:
        jsr     CROUT
        PRINT msg_tsk
        jsr     print_monster
        PRINT22LN msg_gotcha
        jmp     player_dead
print_monster:
        lda     room
        lsr
        tay
        lda     monster_text_lo,y
        ldx     #>msg_werewolves
        jmp     print_string

;;;;;;;;;;
;; pits ;;
;;;;;;;;;;
level_three_action:
        PRINT22NL msg_watch_pits
check_pits:
        lda     room
        cmp     #3
        beq     @fall
        and     #3
        beq     @fall
        rts
@fall:
        PRINT22NL msg_falling
        jsr     CROUT
player_dead:
        PRINT22NL msg_dead
        jmp     exit_program

;;;;;;;;;;;;;;;
;; inventory ;;
;;;;;;;;;;;;;;;
show_inventory:
        PRINT22NL msg_carrying
        jsr     CROUT
        lda     treasures
        beq     @nothing
        ldx     #0
@treasure_loop:
        lsr
        bcc     @treasure_next
        pha
        txa
        pha
        lda     treasure_text_lo,x
        ldx     #>msg_treasure1
        jsr     print_line
        pla
        tax
        pla
@treasure_next:
        inx
        cpx     #4
        bne     @treasure_loop
        rts
@nothing:
        PRINT22LN msg_nothing
        rts

;;;;;;;;;;;;;;
;; printing ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PRINT22 calls hard-code message page $22 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print22_nl:
        ldx     #$22
print_nl:
        ;; CROUT preserves X
        pha
        jsr     CROUT
        pla
        bne     print_line
print22_line:
        ldx     #$22
print_line:
        jsr     print_string
        jmp     CROUT

;; 5-bit packed text decoder
print_string:
        sta     PRINT_PTR
        stx     PRINT_PTR_HI
        ldy     #0
        lda     (PRINT_PTR),y
        sta     direction
        inc     PRINT_PTR
        bne     :+
        inc     PRINT_PTR_HI
:
        lda     #$80
        sta     token_start
@next:
        lda     #0
        sta     token_len
        ldx     #5
@text_bit:
        asl     token_len
        ldy     #0
        lda     (PRINT_PTR),y
        and     token_start
        beq     @text_zero
        inc     token_len
@text_zero:
        lsr     token_start
        bne     @text_next_bit
        lda     #$80
        sta     token_start
        inc     PRINT_PTR
        bne     @text_next_bit
        inc     PRINT_PTR_HI
@text_next_bit:
        dex
        bne     @text_bit
        lda     token_len
        tax
        lda     text_chars,x
        jsr     COUT
        dec     direction
        bne     @next
@done:
        rts

;;;;;;;;;;;;
;; RODATA ;;
;;;;;;;;;;;;
        .segment "RODATA"

;; direction parser tables
dir_initials:
        .byte   "NSEW"
dir_lengths:
        .byte   5,5,4,4
dir_suffixes:
        .byte   "ORTH","OUTH","AST ","EST"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; help text is not on page $22; it uses PRINTNL ;;
;; remaining static messages are page-$22 folded ;;
;;            fixes gibberish error              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
msg_only_directions:
        .byte   $48,$46,$1A,$C5,$5B,$09,$63,$6B,$83,$B6,$B8,$93
        .byte   $70,$66,$E1,$8D,$84,$8F,$BC,$45,$B3,$91,$F7,$82
        .byte   $02,$32,$DE,$1B,$0C,$54,$91,$97,$7B,$D3,$CE,$10
        .byte   $B6,$00,$C1,$E2,$50,$B6,$00,$60,$21,$9D
msg_prompt:
        .byte   $20,$7C,$D0,$24,$E7,$39,$C5,$4E,$81,$1F,$15,$05
        .byte   $B1,$13,$B6,$6A,$1E,$11,$83,$37,$F8
msg_new_level:
        .byte   $1F,$A9,$DA,$D7,$47,$78,$A9,$35,$02,$61,$AC,$C0
        .byte   $18,$D9,$1C,$90,$C2,$89,$42,$2B,$A0
msg_cant_move:
        .byte   $1D,$99,$F7,$89,$9F,$BD,$E8,$80,$CD,$4B,$0B,$6D
        .byte   $09,$89,$1C,$12,$C5,$41,$6E,$80
msg_hurry:
        .byte   $0E,$3C,$E1,$0B,$6F,$10,$9B,$3B,$DE,$F4
msg_after_you:
        .byte   $12,$C0,$20,$4C,$00,$B2,$24,$31,$66,$CF,$39,$CE
        .byte   $40
msg_gotcha:
        .byte   $08,$C1,$9B,$21,$1C,$1D
msg_watch_pits:
        .byte   $19,$A8,$24,$23,$E1,$B3,$96,$0A,$D8,$62,$47,$26
        .byte   $1C,$89,$47,$BD,$E8
msg_falling:
        .byte   $45,$B2,$12,$48,$F7,$BD,$B3,$67,$A8,$13,$05,$02
        .byte   $94,$86,$1B,$78,$28,$14,$A4,$30,$DB,$C1,$40,$A5
        .byte   $21,$86,$DE,$0A,$05,$29,$0C,$37,$7B,$D2,$81,$4A
        .byte   $43,$0D,$DE,$F5,$AD,$74,$73,$9C,$80
msg_dead:
        .byte   $10,$05,$77,$8B,$36,$7A,$81,$30,$32,$00,$7D
msg_carrying:
        .byte   $10,$B3,$67,$A8,$13,$02,$04,$21,$64,$30,$DE
msg_nothing:
        .byte   $07,$63,$64,$74,$30,$C0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shared-page lookup tables ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
monster_text_lo:
        .byte   0,<msg_werewolves,0,<msg_ogres,<msg_dragons
.assert >msg_werewolves = >msg_ogres, error, "monster text crossed page"
.assert >msg_werewolves = >msg_dragons, error, "monster text crossed page"
treasure_bits:
        .byte   0,0,0,4,1,2,0,8,0,0
treasure_text_lo:
        .byte   <msg_treasure1,<msg_treasure2,<msg_treasure3,<msg_treasure4
.assert >msg_treasure1 = >msg_treasure2, error, "treasure text crossed page"
.assert >msg_treasure1 = >msg_treasure3, error, "treasure text crossed page"
.assert >msg_treasure1 = >msg_treasure4, error, "treasure text crossed page"
msg_tsk:
        .byte   $0D,$94,$53,$89,$45,$3D,$C4,$8E,$4C,$00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; packed-text alphabet and dynamic-page messages ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
text_chars:
        .byte   $C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CB,$CC,$CD,$CE,$CF,$D0,$D1
        .byte   $D2,$D3,$D4,$D5,$D6,$D7,$D9,$DA,$A0,$A1,$A7,$AC,$AD,$AE,$BA,$BF
msg_won:
        .byte   $21,$39,$2D,$BC,$59,$B3,$C5,$5A,$CE,$F7,$A2,$6B
        .byte   $0D,$00,$4A,$6A,$04,$90,$D6,$47,$39,$C8
msg_lost:
        .byte   $40,$A9,$14,$AD,$E1,$C0,$56,$F1,$66,$CF,$06,$6C
        .byte   $B0,$D9,$CB,$01,$9C,$B1,$54,$48,$ED,$9C,$B0,$05
        .byte   $2B,$12,$39,$31,$28,$10,$11,$9C,$09,$1E,$F7,$B6
        .byte   $6C,$F0,$A6,$C4,$9D
.assert >msg_won = >msg_lost, error, "finish text crossed page"
msg_treasure1:
        .byte   $1C,$06,$23,$20,$4A,$64,$C3,$4B,$80,$60,$CD,$50
        .byte   $C8,$CC,$2E,$71,$4C,$01,$20
msg_treasure2:
        .byte   $1E,$06,$06,$80,$2D,$AC,$1E,$24,$72,$62,$28,$B9
        .byte   $30,$D2,$E0,$18,$73,$64,$09,$34
msg_treasure3:
        .byte   $1B,$06,$1C,$83,$11,$AC,$C4,$8E,$4C,$45,$17,$26
        .byte   $1A,$5C,$03,$10,$98,$6C
msg_treasure4:
        .byte   $0A,$06,$24,$06,$48,$0A,$9C,$40
msg_werewolves:
        .byte   $0A,$A9,$20,$4A,$B5,$54,$24,$40
msg_ogres:
        .byte   $10,$91,$E0,$42,$72,$4D,$20,$F0,$D3,$40,$91
msg_dragons:
        .byte   $10,$3B,$61,$04,$05,$44,$C0,$E0,$03,$35,$91

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; two maps, two 4-bit exits per byte ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
map_data:
        .byte   $20,$00   ; map 1, room  1
        .byte   $50,$03   ; map 1, room  2
        .byte   $60,$24   ; map 1, room  3
        .byte   $70,$30   ; map 1, room  4
        .byte   $82,$06   ; map 1, room  5
        .byte   $93,$57   ; map 1, room  6
        .byte   $A4,$60   ; map 1, room  7
        .byte   $05,$09   ; map 1, room  8
        .byte   $06,$8A   ; map 1, room  9
        .byte   $00,$0B   ; map 1, room 10
        .byte   $20,$00   ; map 2, room  1
        .byte   $40,$35   ; map 2, room  2
        .byte   $60,$02   ; map 2, room  3
        .byte   $A2,$67   ; map 2, room  4
        .byte   $70,$20   ; map 2, room  5
        .byte   $83,$02   ; map 2, room  6
        .byte   $95,$40   ; map 2, room  7
        .byte   $06,$0A   ; map 2, room  8
        .byte   $07,$A0   ; map 2, room  9
        .byte   $B4,$89   ; map 2, room 10

;;;;;;;;;;;;;;
;; segments ;;
;;;;;;;;;;;;;;
        .segment "DATA"
        .segment "BSS"

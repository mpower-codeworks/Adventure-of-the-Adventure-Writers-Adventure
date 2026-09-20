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

           ;;;;;;;;;;;;;;;;;;;;;;;; 
           ;; logs BASIC to CA65 ;;
           ;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;
;; init ;;
;;;;;;;;;;

.setcpu "6502"

;;;;;;;;;;;;;;;;;;;;;;;;
;; apple ii rom entry ;;
;;;;;;;;;;;;;;;;;;;;;;;;

COUT   = $FDED ; output character in A
CROUT  = $FD8E ; output carriage return
; RDKEY  = $FD0C ; wait for key, return it in A
GETLN1 = $FD6F ; ROM line input
PRODOS = $BF00 ; prodos mli entry point
INPUT_BUFFER = $0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; temp zero-page pointer ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PRINT_PTR       = $06
PRINT_PTR_HI    = $07

;;;;; hot state in zero page;;;;;;;;
room            = $08
direction       = $09
input_len       = $0A
token_start     = $0B
token_len       = $0C
;;;;;;persistent state in zero page;;;;;
level           = $0D
blocked_count   = $0E
treasures       = $0F

;;;;;;;;;;;;;;
;; contants ;;
;;;;;;;;;;;;;;

DIR_NORTH = 0
DIR_SOUTH = 1
DIR_EAST  = 2
DIR_WEST  = 3
INPUT_MAX = 63


;;;;;;;;;;;;
;; macros ;;
;;;;;;;;;;;;

.macro PRINT text
        lda     #<text
        ldx     #>text
        jsr     print_string
.endmacro

;;;;;;old PRINTLN;;;;;;
; .macro PRINTLN text
;         lda     #<text
;         ldx     #>text
;         jsr     print_string
;         jsr     newline
; .endmacro

;;;; new! shared output calls;;;;;
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

;;;;;; page-$22 calls;;;;;;
.macro PRINT22LN text
        lda     #<text
        jsr     print22_line
.endmacro

.macro PRINT22NL text
        lda     #<text
        jsr     print22_nl
.endmacro


;;;;;;;;;;;;;
;; program ;;
;;;;;;;;;;;;;

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;; prodos sys entry                   ;;
        ;; STARTUP at $2000 via linker map    ;;
        ;; then jump into normal CODE segment ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        .segment "STARTUP"

Start:
        ;;;;;; fall through into CODE;;;;;;;
        ; jmp     AppStart
        ; ;;;;;;zero persistent ZP state;;
        ; lda     #1
        ; sta     room
        ldx     #0
        stx     level
        ;;;;;; 016 fix: blocked_count resets on valid move;;;;;;
        ; stx     blocked_count
        stx     treasures
        inx
        stx     room

        .segment "CODE"

AppStart:
        ;;;;;;;;;; skip bad_direction on entry;;;;;;
        bne     main_loop
        ;;;;;;;; ZP scratch need not survive SYS;;;;;;
        ; lda     PRINT_PTR
        ; sta     saved_zp06
        ; lda     PRINT_PTR_HI
        ; sta     saved_zp07

        ; DATA already zero
        ; lda     #0
        ; sta     level
        ; sta     blocked_count
        ; sta     monster_active
        ; sta     monster_kind
        ; sta     treasure1
        ; sta     treasure2
        ; sta     treasure3
        ; sta     treasure4
        ; sta     map_index
        ; sta     input_len
        ; sta     token_start
        ; sta     token_len
        ; sta     direction

        ;;;;;;;; room initialized in STARTUP;;;;;;
        ; lda     #1
        ; sta     room

        ;; read map_data direct ;;
        ; jsr     load_map


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines 2-12: main command loop ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bad_direction:
        ;;;;;;;;;;fall into main loop;;;;;;
        PRINT22NL msg_only_directions
        ; jmp     main_loop

main_loop:
        jsr     prompt_direction
        ;;;;; prompt falls into parser;;;;;;
        ; jsr     parse_direction
        bcc     bad_direction

        jsr     move_player

        ;;;;;;level one collapsed in move_player;;;;;
        ; lda     level
        ; cmp     #1
        ; bne     @normal_post_move
        ; lda     #2
        ; sta     level
        ; jsr     show_inventory
        ; jmp     main_loop
        ; @normal_post_move:
        ; jsr     post_move
        ; jmp     main_loop

        jsr     post_move
        jmp     main_loop


;;;;;;;;;;; bad_direction moved above;;;;;;
; bad_direction:
;         ; BASIC line 6.
;         ;;;;; shared newline output;;;;;;;;
;         ; jsr     newline
;         ; PRINTLN msg_only_directions
;         PRINTNL msg_only_directions
;         jmp     main_loop


;;;;;;;;;;;;;;;;
;; user input ;;
;;;;;;;;;;;;;;;;

prompt_direction:

        ; BASIC line 2:
        ; PRINT : PRINT "QUICK!!! WHICH WAY SHOULD I GO? " : PRINT : INPUT "";A$
        ; ;;;;;;;shared newline output
        ; jsr     newline
        ; PRINTLN msg_prompt
        ;;;;;;;page $22;;;;;;
        ; PRINTNL msg_prompt
        PRINT22NL msg_prompt
        ; ;;;;;;;;;ROM newline
        ; jsr     newline
        jsr     CROUT

        ; question mark mimics applesoft INPUT
        ;;;;;;; high-bit constants;;;;;;;;
        ; lda     #'?'
        ; ora     #$80
        lda     #$BF
        jsr     COUT
        ; lda     #' '
        ; ora     #$80
        lda     #$A0
        jsr     COUT

        ;;;;; ROM line input;;;;;;;
        ; jsr     read_line
        jsr     GETLN1
        stx     input_len
        ;;;;;;; fall through into parser;;;
        ; rts


;;;;;;;;;old line input;;;;;;;
; read_line:
;         lda     #0
;         sta     input_len
;
; @next_key:
;         jsr     RDKEY
;         and     #$7F
;
;         cmp     #$0D
;         beq     @done
;
;         cmp     #$08
;         beq     @backspace
;         cmp     #$7F
;         beq     @backspace
;
;         ;; convert lower case to upper (like orig)
;         cmp     #'a'
;         bcc     @store
;         cmp     #'z' + 1
;         bcs     @store
;         and     #$DF
;
; @store:
;         ldx     input_len
;         cpx     #INPUT_MAX
;         bcs     @next_key
;
;         sta     input_buffer,x
;         inc     input_len
;
;         ora     #$80
;         jsr     COUT
;         jmp     @next_key
;
; @backspace:
;         ldx     input_len
;         beq     @next_key
;
;         dec     input_len
;
;         ; erase previous char on screen
;         lda     #$88
;         jsr     COUT
;         lda     #$A0
;         jsr     COUT
;         lda     #$88
;         jsr     COUT
;         jmp     @next_key
;
; @done:
;         ldx     input_len
;         lda     #0
;         sta     input_buffer,x
;         jsr     newline
;         rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC Llines 3-5: direction parser ;;
;                                      ;;;;;;;;;;;;;;;;;;;;;
; the orig program takes everything after the first space ;;
; if present - so both "NORTH" and "GO NORTH" will work   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

parse_direction:
        ;;;;;; Y keeps token start;;;;;;;;
        ; ldy     #0
        ; sty     token_start
        ;
        ; @find_space:
        ; cpy     input_len
        ; beq     @have_start
        ; lda     INPUT_BUFFER,y
        ; and     #$7F
        ; cmp     #' '
        ; beq     @found_space
        ; iny
        ; bne     @find_space
        ;
        ; @found_space:
        ; iny
        ; sty     token_start
        ;
        ; @have_start:
        ; lda     input_len
        ; sec
        ; sbc     token_start
        ; sta     token_len
        ; beq     @parse_fail
        ;
        ; ldy     token_start
        ; lda     INPUT_BUFFER,y
        ; and     #$5F

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
        ; ldy     token_start
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

;;;;;;;;;;;;;;;;
;; old parser ;;
;;;;;;;;;;;;;;;;
; parse_direction:
;         ldy     #0
;
; @find_space:
;         cpy     input_len
;         beq     @no_space
;
;         lda     input_buffer,y
;         cmp     #' '
;         beq     @found_space
;
;         iny
;         bne     @find_space
;
; @found_space:
;         iny
;         sty     token_start
;         jmp     @have_start
;
; @no_space:
;         lda     #0
;         sta     token_start
;
; @have_start:
;         lda     input_len
;         sec
;         sbc     token_start
;         sta     token_len
;
;         cmp     #1
;         beq     @one_char
;         cmp     #4
;         beq     @four_chars
;         cmp     #5
;         beq     @five_chars
;
;         clc
;         rts
;
;
; @one_char:
;         ldy     token_start
;         lda     input_buffer,y
;
;         cmp     #'N'
;         bne     :+
;         jmp     @set_north
; :
;         cmp     #'S'
;         bne     :+
;         jmp     @set_south
; :
;         cmp     #'E'
;         bne     :+
;         jmp     @set_east
; :
;         cmp     #'W'
;         bne     :+
;         jmp     @set_west
; :
;
;         clc
;         rts
;
;
; @four_chars:
;         ldy     token_start
;         lda     input_buffer,y
;
;         cmp     #'E'
;         beq     @check_east
;         cmp     #'W'
;         beq     @check_west
;
;         clc
;         rts
;
;
; @check_east:
;         iny
;         lda     input_buffer,y
;         cmp     #'A'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'S'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'T'
;         bne     @parse_fail
;         jmp     @set_east
;
;
; @check_west:
;         iny
;         lda     input_buffer,y
;         cmp     #'E'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'S'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'T'
;         bne     @parse_fail
;         jmp     @set_west
;
;
; @five_chars:
;         ldy     token_start
;         lda     input_buffer,y
;
;         cmp     #'N'
;         beq     @check_north
;         cmp     #'S'
;         beq     @check_south
;
; @parse_fail:
;         clc
;         rts
;
;
; @check_north:
;         iny
;         lda     input_buffer,y
;         cmp     #'O'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'R'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'T'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'H'
;         bne     @parse_fail
;         jmp     @set_north
;
;
; @check_south:
;         iny
;         lda     input_buffer,y
;         cmp     #'O'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'U'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'T'
;         bne     @parse_fail
;         iny
;         lda     input_buffer,y
;         cmp     #'H'
;         bne     @parse_fail
;         jmp     @set_south
;
;
; @set_north:
;         lda     #DIR_NORTH
;         sta     direction
;         sec
;         rts
;
; @set_south:
;         lda     #DIR_SOUTH
;         sta     direction
;         sec
;         rts
;
; @set_east:
;         lda     #DIR_EAST
;         sta     direction
;         sec
;         rts
;
; @set_west:
;         lda     #DIR_WEST
;         sta     direction
;         sec
;         rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC lines 13-19: move through ten room map ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

move_player:
        lda     room
        ;;;;;;; blocked move leaves room untouched;;;;;;;;
        ; sta     old_room

        ;;;;;;;; direct map_data index;;;;;
        ;;;;;;;;;;;fold carry into index math
        ; sec
        ; sbc     #1
        asl
        asl
        ; clc
        adc     direction
        sbc     #3
        tax
        lda     level
        beq     @map_ready
        txa
        ; adc     #40
        adc     #39
        tax
@map_ready:
        ;;;;;;; packed map;;;;;;
        ; lda     map_data,x
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

        ; sec
        ; sbc     #1
        ; tax
        ;
        ; lda     direction
        ; cmp     #DIR_NORTH
        ; beq     @north
        ; cmp     #DIR_SOUTH
        ; beq     @south
        ; cmp     #DIR_EAST
        ; beq     @east
        ;
        ; @west:
        ; lda     west_map,x
        ; jmp     @destination
        ;
        ; @north:
        ; lda     north_map,x
        ; jmp     @destination
        ;
        ; @south:
        ; lda     south_map,x
        ; jmp     @destination
        ;
        ; @east:
        ; lda     east_map,x

@destination:
        ;;;;;; test destination before storing;;;;;;;
        ; sta     room
        beq     @blocked

        ; BASIC line 17
        cmp     #11
        bne     @store_room

        ;;;;;;;; first exit skips level one;;;
        ; inc     level
        inc     level
        lsr     direction
        bcs     :+
        inc     level
:
        ;;;; new! shared newline output;;;;
        ; jsr     newline
        ; PRINTLN msg_new_level
        ;;;;;;;;page $22;;;;;;;;;;
        ; PRINTNL msg_new_level
        PRINT22NL msg_new_level

        lda     #1

@store_room:
        sta     room

        ; BASIC line 18
        ; lda     room
        ; beq     @blocked

        lda     #0
        ;;;; room is monster state;;;;;;;
        ; sta     monster_active
        sta     blocked_count
        rts

@blocked:
        ; BASIC line 19
        ;;;;;new! shared newline output;;;;
        ; jsr     newline
        ; PRINTLN msg_cant_move
        ;;;;; page $22;;;;;
        ; PRINTNL msg_cant_move
        PRINT22NL msg_cant_move

        ;;;;;;;;room was never changed;;;;;;;
        ; lda     old_room
        ; sta     room

        inc     blocked_count
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC lines 8-11: level-specifc actions after move ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;; old post-move layout;;;;;
; post_move:
;         ;;;;; shared inventory + tail dispatch;;;;;;
;         ; lda     level
;         ; beq     @level_zero
;         ;
;         ; cmp     #2
;         ; beq     @level_two
;         ;
;         ; cmp     #3
;         ; beq     @level_three
;         ;
;         ; cmp     #4
;         ; beq     @level_four
;         ;
;         ; rts
;         ;
;         ; @level_zero:
;         ; jsr     collect_treasures
;         ; rts
;         ;
;         ; @level_two:
;         ; jsr     show_inventory
;         ; jsr     check_monsters
;         ; rts
;         ;
;         ; @level_three:
;         ; jsr     show_inventory
;         ; PRINTNL msg_watch_pits
;         ; jsr     check_pits
;         ; rts
;         ;
;         ; @level_four:
;         ; jsr     show_inventory
;         ; jmp     finish_game
;
;         lda     level
;         beq     collect_treasures
;
;         pha
;         jsr     show_inventory
;         pla
;
;         cmp     #3
;         beq     @level_three
;         bcc     check_monsters
;         jmp     finish_game
;
; @level_three:
;         PRINTNL msg_watch_pits
;         jmp     check_pits
;
;

post_move:
        lda     level
        bne     post_higher

        ;;;;;;; level zero falls into treasure pickup;;;;;;;
collect_treasures:
        ldx     room
        ;;;;; table starts at room one;;;;;;
        ; lda     treasure_bits,x
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

        ;;;;;;; level four falls into finish;;;;;;;
finish_game:
        ;;;;;; select low byte in A;;;;;;
        ; ldx     #<msg_lost
        ; lda     treasures
        ; cmp     #$0F
        ; bne     @finish_text
        ; ldx     #<msg_won
        ; @finish_text:
        ; txa
        lda     #<msg_lost
        ldx     treasures
        cpx     #$0F
        bne     @finish_text
        lda     #<msg_won
@finish_text:
        ldx     #>msg_won
        jsr     print_nl

        ;;;;;; finish falls into quit;;;;
exit_program:
        jsr     PRODOS
        .byte   $65
        .addr   quit_params
        brk

quit_params:
        .byte   4
        .byte   0
        .word   0
        .byte   0
        .word   0

        ;;;;;;;;; level two falls into monster check;;;;;;;
check_monsters:
        ;;;;rooms 3/7 share low two bits;;;;;
        lda     room
        ; cmp     #3
        ; beq     @monster
        ; cmp     #7
        ; beq     @monster
        cmp     #9
        beq     @monster
        and     #3
        cmp     #3
        bne     @done

@monster:
        lda     blocked_count
        cmp     #2
        bcs     monster_gotcha

        ;;;;; page $22;;;;;;;
        ; PRINTNL msg_hurry
        PRINT22NL msg_hurry
        jsr     print_monster
        ;;;;page $22;;;;;
        ; PRINTLN msg_after_you
        PRINT22LN msg_after_you
        inc     blocked_count

@done:
        rts

monster_gotcha:
        jsr     CROUT
        PRINT msg_tsk
        jsr     print_monster
        ;;;;;page $22;;;;;;;
        ; PRINTLN msg_gotcha
        PRINT22LN msg_gotcha
        jmp     player_dead

print_monster:
        lda     room
        lsr
        tay
        lda     monster_text_lo,y
        ldx     #>msg_werewolves
        jmp     print_string

level_three_action:
        ;;;;;;;;page $22;;;;;;
        ; PRINTNL msg_watch_pits
        PRINT22NL msg_watch_pits

        ;;;;;;;; level three falls into pit check;;;;;;;
check_pits:
        lda     room
        cmp     #3
        beq     @fall
        and     #3
        beq     @fall
        rts

@fall:
        ;;;;;;;page $22;;;;;;
        ; PRINTNL msg_falling
        PRINT22NL msg_falling
        jsr     CROUT

        ;;;;;;;; pit death falls into common death;;;;;;;
player_dead:
        ;;;;;; page $22 ;;;;;;
        ; PRINTNL msg_dead
        PRINT22NL msg_dead
        jmp     exit_program

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines20-23: pickup treasure ;
 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;folded above;;;;;;;;;
; collect_treasures:
;         ;;;;;; room-to-bit table;;;;;;;;
;         ldx     room
;         lda     treasure_bits,x
;         ora     treasures
;         sta     treasures
;         rts
;
        ;;;;;; old treasure flags;;;;;;
;         lda     room
;         cmp     #5
;         bne     @not_t1
;         lda     #1
;         sta     treasure1
;
; @not_t1:
;         lda     room
;         cmp     #6
;         bne     @not_t2
;         lda     #1
;         sta     treasure2
;
; @not_t2:
;         lda     room
;         cmp     #4
;         bne     @not_t3
;         lda     #1
;         sta     treasure3
;
; @not_t3:
;         lda     room
;         cmp     #8
;         bne     @done
;         lda     #1
;         sta     treasure4
;
; @done:
;         rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC lines 24-30: inventory ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

show_inventory:
        ;;;;;;;new!shared newline output;;
        ; jsr     newline
        ; PRINTLN msg_carrying
        ;;;;;;;page $22;;;;;;;;
        ; PRINTNL msg_carrying
        PRINT22NL msg_carrying
        ;;;;;;;new!ROM newline;;;
        ; jsr     newline
        jsr     CROUT

        ;;;;;loop four treasure bits;;;;
        ; lda     treasures
        ; beq     @nothing
        ; lsr
        ; bcc     @not_t1
        ; pha
        ; PRINTLN msg_treasure1
        ; pla
        ; @not_t1:
        ; lsr
        ; bcc     @not_t2
        ; pha
        ; PRINTLN msg_treasure2
        ; pla
        ; @not_t2:
        ; lsr
        ; bcc     @not_t3
        ; pha
        ; PRINTLN msg_treasure3
        ; pla
        ; @not_t3:
        ; lsr
        ; bcc     @done
        ; PRINTLN msg_treasure4
        ; @done:
        ; rts

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
        ;;;;; page $22 ;;;;;;;;;
        ; PRINTLN msg_nothing
        PRINT22LN msg_nothing
        rts

        ;;;; old inventory flags;;;;;;;
;         lda     treasure1
;         ora     treasure2
;         ora     treasure3
;         ora     treasure4
;         bne     @have_something
;
;         PRINTLN msg_nothing
;         rts
;
;
; @have_something:
;         lda     treasure1
;         beq     @not_t1
;         PRINTLN msg_treasure1
;
; @not_t1:
;         lda     treasure2
;         beq     @not_t2
;         PRINTLN msg_treasure2
;
; @not_t2:
;         lda     treasure3
;         beq     @not_t3
;         PRINTLN msg_treasure3
;
; @not_t3:
;         lda     treasure4
;         beq     @done
;         PRINTLN msg_treasure4
;
; @done:
;         rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines 31-37: mostros ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;; folded above;;;;;;;;
; check_monsters:
;         ;;;;;;;; derive monster from room;;;;;;
;         lda     room
;         cmp     #3
;         beq     @monster
;         cmp     #7
;         beq     @monster
;         cmp     #9
;         bne     @done
;
; @monster:
;         ; BASIC line 35: IF M > 1 THEN GOTO 37
;         lda     blocked_count
;         cmp     #2
;         bcs     monster_gotcha
;
;         ; BASIC line 36
;         PRINTNL msg_hurry
;         jsr     print_monster
;         PRINTLN msg_after_you
;         inc     blocked_count
;
; @done:
;         rts
;
;
; monster_gotcha:
;         ; BASIC line 37
;         jsr     CROUT
;         PRINT msg_tsk
;         jsr     print_monster
;         PRINTLN msg_gotcha
;         jmp     player_dead
;
;
; print_monster:
;         ;;;;;;;;; room/2 selects text;;;;;;;
;         lda     room
;         lsr
;         tay
;         lda     monster_text_lo,y
;         ;;;;;;monster text shares a page;;;;;
;         ; ldx     monster_text_hi,y
;         ldx     #>msg_werewolves
;         jmp     print_string
;
;
;;;;;;;;;; old monster state/code;;;;;;;;;
; check_monsters:
;         lda     room
;         cmp     #3
;         bne     @not_werewolves
;
;         lda     #0
;         sta     monster_kind
;         lda     #1
;         sta     monster_active
;         jmp     @test_monster
;
; @not_werewolves:
;         cmp     #7
;         bne     @not_ogres
;
;         lda     #1
;         sta     monster_kind
;         lda     #1
;         sta     monster_active
;         jmp     @test_monster
;
; @not_ogres:
;         cmp     #9
;         bne     @test_monster
;
;         lda     #2
;         sta     monster_kind
;         lda     #1
;         sta     monster_active
;
;
; @test_monster:
;         lda     monster_active
;         beq     @done
;
;         ; BASIC line 35: IF M > 1 THEN GOTO 37
;         lda     blocked_count
;         cmp     #2
;         bcs     monster_gotcha
;
;         ; BASIC line 36
;         ;;;;;;;new! shared newline output;
;         ; jsr     newline
;         ; PRINTLN msg_hurry
;         PRINTNL msg_hurry
;
;         jsr     print_monster
;         PRINTLN msg_after_you
;
;         inc     blocked_count
;
; @done:
;         rts
;
;
; monster_gotcha:
;         ; BASIC line 37
;         ;;;;;;;new! ROM newline;;
;         ; jsr     newline
;         jsr     CROUT
;         PRINT msg_tsk
;         jsr     print_monster
;         PRINTLN msg_gotcha
;         jmp     player_dead
;
;
; print_monster:
;         lda     monster_kind
;         beq     @werewolves
;
;         cmp     #1
;         beq     @ogres
;
;         PRINT msg_dragons
;         rts
;
; @werewolves:
;         PRINT msg_werewolves
;         rts
;
; @ogres:
;         PRINT msg_ogres
;         rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines 38-39: pits ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;; folded above;;;;;;;;
; check_pits:
;         lda     room
;         cmp     #3
;         beq     @fall
;         ; 013: 4 and 8 are multiples of four
;         ; cmp     #4
;         ; beq     @fall
;         ; cmp     #8
;         ; beq     @fall
;         and     #3
;         beq     @fall
;         rts
;
; @fall:
;         ;;;;;;;new! shared newline output;;;;;
;         ; jsr     newline
;         ; PRINTLN msg_falling
;         PRINTNL msg_falling
;         ;;;;;;;new! ROM newline ;;
;         ; jsr     newline
;         jsr     CROUT
;         jmp     player_dead
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC lines 41-43: endings ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;; folded above;;;;;;;
; player_dead:
;         ; BASIC line 41.
;         ;;;;;;;new! shared newline output ;;;
;         ; jsr     newline
;         ; PRINTLN msg_dead
;         PRINTNL msg_dead
;         jmp     exit_program
;
;
; finish_game:
;         ;;;;;; all four bits required;;;;;
;         lda     treasures
;         cmp     #$0F
;         bne     @lost
;
;         ;;;;;;;; old treasure tests;;;;;;;;;;;
; ;         lda     treasure1
; ;         beq     @lost
; ;         lda     treasure2
; ;         beq     @lost
; ;         lda     treasure3
; ;         beq     @lost
; ;         lda     treasure4
; ;         beq     @lost
;
;         ; BASIC line 42
;         ;;;;;;;new! shared newline output ;;;;;
;         ; jsr     newline
;         ; PRINTLN msg_won
;         PRINTNL msg_won
;         jmp     exit_program
;
; @lost:
;         ; BASIC line 43
;         ;;;;;;;new! shared newline output ;;;
;         ; jsr     newline
;         ; PRINTLN msg_lost
;         PRINTNL msg_lost
;
;
; exit_program:
;
;         ; 012: no ZP restore on quit
;         ; lda     saved_zp06
;         ; sta     PRINT_PTR
;         ; lda     saved_zp07
;         ; sta     PRINT_PTR_HI
;
;         ; prodos quit
;         jsr     PRODOS
;         .byte   $65
;         .addr   quit_params
;         brk
;
;
; quit_params:
;         .byte   4   ; params count
;         .byte   0   ; quit type
;         .word   0   ; reserved
;         .byte   0   ; reserved
;         .word   0   ; reserved
;
;
;;;;;;;;;;;;;;;;
;; map LOADER ;;
;;              ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC line 1 READs ten N/S/E/W records    ;;
;; the DATA statement has two ten-room maps  ;;
;; second map loaded when first exit reached ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; loader no longer needed ;;
; load_map:
;         ldx     #0
;         ldy     map_index
;
; @room:
;         lda     map_data,y
;         sta     north_map,x
;         iny
;
;         lda     map_data,y
;         sta     south_map,x
;         iny
;
;         lda     map_data,y
;         sta     east_map,x
;         iny
;
;         lda     map_data,y
;         sta     west_map,x
;         iny
;
;         inx
;         cpx     #10
;         bne     @room
;
;         sty     map_index
;         rts


;;;;;;;;;;;;;;;;;
;; output text ;;
;;;;;;;;;;;;;;;;;

;;;;;;; shared newline output;;;;;;;;
print22_nl:
        ldx     #$22
print_nl:
        pha
        txa
        pha
        jsr     CROUT
        pla
        tax
        pla
        ;;;;;;;; all NL low bytes are nonzero;;;;;;
        bne     print_line

print22_line:
        ldx     #$22
print_line:
        jsr     print_string
        jmp     CROUT

print_string:
        ;;;;;; 5-bit text;;;;;;;;
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
        ;;;;;;;nonzero lengths, bottom-test loop;;;;
        ; lda     direction
        ; beq     @done
        ; dec     direction

        ;;;;;;; inline get_text5;;;;;;
        ; jsr     get_text5
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
        ;;;;;;; alphabet already has high bit;;;;;;;
        ; ora     #$80
        jsr     COUT
        ; jmp     @next
        dec     direction
        bne     @next

@done:
        rts


;;;;;;; inlined above;;;;;;;;
; get_text5:
;         lda     #0
;         sta     token_len
;         ldx     #5
;
; @bit:
;         asl     token_len
;         ldy     #0
;         lda     (PRINT_PTR),y
;         and     token_start
;         beq     @zero
;         inc     token_len
;
; @zero:
;         lsr     token_start
;         bne     @next_bit
;
;         lda     #$80
;         sta     token_start
;         inc     PRINT_PTR
;         bne     @next_bit
;         inc     PRINT_PTR_HI
;
; @next_bit:
;         dex
;         bne     @bit
;
;         lda     token_len
;         rts


;;;;;; old printer;;;;;;;;
; print_string:
;         sta     PRINT_PTR
;         stx     PRINT_PTR_HI
;
;         ldy     #0
;
; @next:
;         lda     (PRINT_PTR),y
;         beq     @done
;
;         ora     #$80
;         jsr     COUT
;
;         iny
;         bne     @next
;
; @done:
;         rts


;;;;;;;new! ROM CROUT ;;;;;;
; newline:
;         lda     #$8D
;         jsr     COUT
;         rts


;;;;;;;;;;;;;;;;;;;;
;; read-only data ;;
;;;;;;;;;;;;;;;;;;;;

        .segment "RODATA"

;;;;;;; parser prefix;;;;;;;
dir_initials:
        .byte   "NSEW"

dir_lengths:
        .byte   5,5,4,4

dir_suffixes:
        .byte   "ORTH","OUTH","AST ","EST"

;;;;;; static messages on page $22;;;;;;;
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

;;;;;;; end-page tables;;;;;;;
monster_text_lo:
        .byte   0,<msg_werewolves,0,<msg_ogres,<msg_dragons

; monster_text_hi:
;         .byte   0,>msg_werewolves,0,>msg_ogres,>msg_dragons
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

;;;;;;;;;;;;; page $23 dynamic text/data;;;;;;;
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

map_data:
        .byte   $20,$00                ; map 1, room 1
        .byte   $50,$03                ; map 1, room 2
        .byte   $60,$24                ; map 1, room 3
        .byte   $70,$30                ; map 1, room 4
        .byte   $82,$06                ; map 1, room 5
        .byte   $93,$57                ; map 1, room 6
        .byte   $A4,$60                ; map 1, room 7
        .byte   $05,$09                ; map 1, room 8
        .byte   $06,$8A                ; map 1, room 9
        .byte   $00,$0B                ; map 1, room 10
        .byte   $20,$00                ; map 2, room 1
        .byte   $40,$35                ; map 2, room 2
        .byte   $60,$02                ; map 2, room 3
        .byte   $A2,$67                ; map 2, room 4
        .byte   $70,$20                ; map 2, room 5
        .byte   $83,$02                ; map 2, room 6
        .byte   $95,$40                ; map 2, room 7
        .byte   $06,$0A                ; map 2, room 8
        .byte   $07,$A0                ; map 2, room 9
        .byte   $B4,$89                ; map 2, room 10

;;;;;;; ;;;old RODATA order;;;;;;;
;         .segment "RODATA"
;
; ;; text alphabet ;;
; text_chars:
;         ;;;;;;; high-bit Apple II text;;;;;
;         ; .byte   "ABCDEFGHIKLMNOPQRSTUVWYZ !',-.:?"
;         .byte   $C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CB,$CC,$CD,$CE,$CF,$D0,$D1
;         .byte   $D2,$D3,$D4,$D5,$D6,$D7,$D9,$DA,$A0,$A1,$A7,$AC,$AD,$AE,$BA,$BF
;
; ;;;;;;; parser tables;;;;;;;;;
; dir_initials:
;         .byte   "NSEW"
; dir_lengths:
;         .byte   5,5,4,4
; dir_suffixes:
;         .byte   "ORTH","OUTH","AST ","EST "
;
; ;;;;; monster text by room/2;;;;;;
; monster_text_lo:
;         .byte   0,<msg_werewolves,0,<msg_ogres,<msg_dragons
; ;;;;;;; one shared high byte;;;;;;
; ; monster_text_hi:
; ;         .byte   0,>msg_werewolves,0,>msg_ogres,>msg_dragons
; .assert >msg_werewolves = >msg_ogres, error, "monster text crossed page"
; .assert >msg_werewolves = >msg_dragons, error, "monster text crossed page"
;
; ;;;;;;; treasure bit by room;;;;;;;;
; treasure_bits:
;         ;;;;;;;; rooms 1-10;;;;;;;
;         ; .byte   0,0,0,0,4,1,2,0,8,0,0
;         .byte   0,0,0,4,1,2,0,8,0,0
;
; ;;;;;; treasure text low bytes;;;;;;
; treasure_text_lo:
;         .byte   <msg_treasure1,<msg_treasure2,<msg_treasure3,<msg_treasure4
; .assert >msg_treasure1 = >msg_treasure2, error, "treasure text crossed page"
; .assert >msg_treasure1 = >msg_treasure3, error, "treasure text crossed page"
; .assert >msg_treasure1 = >msg_treasure4, error, "treasure text crossed page"
;
;
; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ;; BASIC line 40: map DATA        ;;
; ;;                                ;;
; ;; each row is N, S, E, W         ;;
; ;; first ten rows are first map   ;;
; ;; second ten rows are the second ;;
; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; map_data:
;         ;;; two exits per byte;;;;;;
;         .byte   $20,$00                ; map 1, room 1
;         .byte   $50,$03                ; map 1, room 2
;         .byte   $60,$24                ; map 1, room 3
;         .byte   $70,$30                ; map 1, room 4
;         .byte   $82,$06                ; map 1, room 5
;         .byte   $93,$57                ; map 1, room 6
;         .byte   $A4,$60                ; map 1, room 7
;         .byte   $05,$09                ; map 1, room 8
;         .byte   $06,$8A                ; map 1, room 9
;         .byte   $00,$0B                ; map 1, room 10
;
;         .byte   $20,$00                ; map 2, room 1
;         .byte   $40,$35                ; map 2, room 2
;         .byte   $60,$02                ; map 2, room 3
;         .byte   $A2,$67                ; map 2, room 4
;         .byte   $70,$20                ; map 2, room 5
;         .byte   $83,$02                ; map 2, room 6
;         .byte   $95,$40                ; map 2, room 7
;         .byte   $06,$0A                ; map 2, room 8
;         .byte   $07,$A0                ; map 2, room 9
;         .byte   $B4,$89                ; map 2, room 10
;
;         ;;;;;;; old byte map;;;;;;;;;;;;;;;
; ;         .byte   0,  2,  0,  0          ; map 1, room 1
; ;         .byte   0,  5,  3,  0          ; map 1, room 2
; ;         .byte   0,  6,  4,  2          ; map 1, room 3
; ;         .byte   0,  7,  0,  3          ; map 1, room 4
; ;         .byte   2,  8,  6,  0          ; map 1, room 5
; ;         .byte   3,  9,  7,  5          ; map 1, room 6
; ;         .byte   4, 10,  0,  6          ; map 1, room 7
; ;         .byte   5,  0,  9,  0          ; map 1, room 8
; ;         .byte   6,  0, 10,  8          ; map 1, room 9
; ;         .byte   0,  0, 11,  0          ; map 1, room 10
;
; ;         .byte   0,  2,  0,  0          ; map 2, room 1
; ;         .byte   0,  4,  5,  3          ; map 2, room 2
; ;         .byte   0,  6,  2,  0          ; map 2, room 3
; ;         .byte   2, 10,  7,  6          ; map 2, room 4
; ;         .byte   0,  7,  0,  2          ; map 2, room 5
; ;         .byte   3,  8,  2,  0          ; map 2, room 6
; ;         .byte   5,  9,  0,  4          ; map 2, room 7
; ;         .byte   6,  0, 10,  0          ; map 2, room 8
; ;         .byte   7,  0,  0, 10          ; map 2, room 9
; ;         .byte   4, 11,  9,  8          ; map 2, room 10
;
;
; ;;;;;;;;;;;;;;;;;;;
; ;; game messages ;;
; ;;;;;;;;;;;;;;;;;;;
;
; ;; packed output text woooo
; msg_prompt:
;         .byte   $20,$7C,$D0,$24,$E7,$39,$C5,$4E,$81,$1F,$15,$05
;         .byte   $B1,$13,$B6,$6A,$1E,$11,$83,$37,$F8
; ;;;;;;; finish texts share high byte;;;;;;;
; msg_won:
;         .byte   $21,$39,$2D,$BC,$59,$B3,$C5,$5A,$CE,$F7,$A2,$6B
;         .byte   $0D,$00,$4A,$6A,$04,$90,$D6,$47,$39,$C8
;
; msg_lost:
;         .byte   $40,$A9,$14,$AD,$E1,$C0,$56,$F1,$66,$CF,$06,$6C
;         .byte   $B0,$D9,$CB,$01,$9C,$B1,$54,$48,$ED,$9C,$B0,$05
;         .byte   $2B,$12,$39,$31,$28,$10,$11,$9C,$09,$1E,$F7,$B6
;         .byte   $6C,$F0,$A6,$C4,$9D
;
; .assert >msg_won = >msg_lost, error, "finish text crossed page"
;
;
; msg_only_directions:
;         .byte   $48,$46,$1A,$C5,$5B,$09,$63,$6B,$83,$B6,$B8,$93
;         .byte   $70,$66,$E1,$8D,$84,$8F,$BC,$45,$B3,$91,$F7,$82
;         .byte   $02,$32,$DE,$1B,$0C,$54,$91,$97,$7B,$D3,$CE,$10
;         .byte   $B6,$00,$C1,$E2,$50,$B6,$00,$60,$21,$9D
;
; msg_new_level:
;         .byte   $1F,$A9,$DA,$D7,$47,$78,$A9,$35,$02,$61,$AC,$C0
;         .byte   $18,$D9,$1C,$90,$C2,$89,$42,$2B,$A0
;
; msg_cant_move:
;         .byte   $1D,$99,$F7,$89,$9F,$BD,$E8,$80,$CD,$4B,$0B,$6D
;         .byte   $09,$89,$1C,$12,$C5,$41,$6E,$80
;
; msg_carrying:
;         .byte   $10,$B3,$67,$A8,$13,$02,$04,$21,$64,$30,$DE
;
; msg_nothing:
;         .byte   $07,$63,$64,$74,$30,$C0
;
; msg_treasure1:
;         .byte   $1C,$06,$23,$20,$4A,$64,$C3,$4B,$80,$60,$CD,$50
;         .byte   $C8,$CC,$2E,$71,$4C,$01,$20
;
; msg_treasure2:
;         .byte   $1E,$06,$06,$80,$2D,$AC,$1E,$24,$72,$62,$28,$B9
;         .byte   $30,$D2,$E0,$18,$73,$64,$09,$34
;
; msg_treasure3:
;         .byte   $1B,$06,$1C,$83,$11,$AC,$C4,$8E,$4C,$45,$17,$26
;         .byte   $1A,$5C,$03,$10,$98,$6C
;
; msg_treasure4:
;         .byte   $0A,$06,$24,$06,$48,$0A,$9C,$40
;
; msg_werewolves:
;         .byte   $0A,$A9,$20,$4A,$B5,$54,$24,$40
;
; msg_ogres:
;         .byte   $10,$91,$E0,$42,$72,$4D,$20,$F0,$D3,$40,$91
;
; msg_dragons:
;         .byte   $10,$3B,$61,$04,$05,$44,$C0,$E0,$03,$35,$91
;
; msg_hurry:
;         .byte   $0E,$3C,$E1,$0B,$6F,$10,$9B,$3B,$DE,$F4
;
; msg_after_you:
;         .byte   $12,$C0,$20,$4C,$00,$B2,$24,$31,$66,$CF,$39,$CE
;         .byte   $40
;
; msg_tsk:
;         .byte   $0D,$94,$53,$89,$45,$3D,$C4,$8E,$4C,$00
;
; msg_gotcha:
;         .byte   $08,$C1,$9B,$21,$1C,$1D
;
; msg_watch_pits:
;         .byte   $19,$A8,$24,$23,$E1,$B3,$96,$0A,$D8,$62,$47,$26
;         .byte   $1C,$89,$47,$BD,$E8
;
; msg_falling:
;         .byte   $45,$B2,$12,$48,$F7,$BD,$B3,$67,$A8,$13,$05,$02
;         .byte   $94,$86,$1B,$78,$28,$14,$A4,$30,$DB,$C1,$40,$A5
;         .byte   $21,$86,$DE,$0A,$05,$29,$0C,$37,$7B,$D2,$81,$4A
;         .byte   $43,$0D,$DE,$F5,$AD,$74,$73,$9C,$80
;
; msg_dead:
;         .byte   $10,$05,$77,$8B,$36,$7A,$81,$30,$32,$00,$7D
; ;
; ;;;;;;;;;;;; moved above;;;;;;;;;;;;;
; ; msg_won:
; ;         .byte   $21,$39,$2D,$BC,$59,$B3,$C5,$5A,$CE,$F7,$A2,$6B
; ;         .byte   $0D,$00,$4A,$6A,$04,$90,$D6,$47,$39,$C8
; ;
; ; msg_lost:
; ;         .byte   $40,$A9,$14,$AD,$E1,$C0,$56,$F1,$66,$CF,$06,$6C
; ;         .byte   $B0,$D9,$CB,$01,$9C,$B1,$54,$48,$ED,$9C,$B0,$05
; ;         .byte   $2B,$12,$39,$31,$28,$10,$11,$9C,$09,$1E,$F7,$B6
; ;         .byte   $6C,$F0,$A6,$C4,$9D
; ;
; ;;;;;old text;;;;
; ; msg_prompt:
; ;         .byte   "QUICK!!! WHICH WAY SHOULD I GO? ",0
; ;
; ; msg_only_directions:
; ;         .byte   "I ONLY KNOW HOW TO GO NORTH, SOUTH, EAST, OR WEST..."
; ;         .byte   "HURRY AND TRY AGAIN.",0
; ;
; ; msg_new_level:
; ;         .byte   "WHOOPS, WE'RE ON ANOTHER LEVEL.",0
; ;
; ; msg_cant_move:
; ;         .byte   "UH, UH...CAN'T MOVE THAT WAY.",0
; ;
; ; msg_carrying:
; ;         .byte   "YOU'RE CARRYING:",0
; ;
; ; msg_nothing:
; ;         .byte   "NOTHING",0
; ;
; ; msg_treasure1:
; ;         .byte   "A STATUE OF A GOLDEN MUSKRAT",0
; ;
; ; msg_treasure2:
; ;         .byte   "A DIAMOND THE SIZE OF A POTATO",0
; ;
; ; msg_treasure3:
; ;         .byte   "A PIGEON THE SIZE OF A RUBY",0
; ;
; ; msg_treasure4:
; ;         .byte   "A TANTALUS",0
; ;
; ; msg_werewolves:
; ;         .byte   "WEREWOLVES",0
; ;
; ; msg_ogres:
; ;         .byte   "THREE-TOED OGRES",0
; ;
; ; msg_dragons:
; ;         .byte   "HORRIBLE DRAGONS",0
; ;
; ; msg_hurry:
; ;         .byte   "HURRY, RUN....",0
; ;
; ; msg_after_you:
; ;         .byte   " ARE AFTER YOU!!!!",0
; ;
; ; msg_tsk:
; ;         .byte   "TSK TSK. THE ",0
; ;
; ; msg_gotcha:
; ;         .byte   " GOTCHA.",0
; ;
; ; msg_watch_pits:
; ;         .byte   "WATCH OUT FOR THE PITS...",0
; ;
; ; msg_falling:
; ;         .byte   "YIKES...YOU'RE FALLING, FALLING, FALLING, FALLING..."
; ;         .byte   "FALLING...OOPS!!!",0
; ;
; ; msg_dead:
; ;         .byte   "AW, YOU'RE DEAD.",0
; ;
; ; msg_won:
; ;         .byte   "HEY, YOU WON...CONGRATULATIONS!!!",0
; ;
; ; msg_lost:
; ;         .byte   "WELL, PAL, YOU GOT OUT BUT WITHOUT ALL THE TREASURES..."
; ;         .byte   "YOU LOSE.",0
;
;

;;;;;;;;;;;;;;
; variables ;;
;;;;;;;;;;;;;;

        .segment "DATA"

;;;;;;; no saved ZP;;;;;;;
; saved_zp06:     .res 1
; saved_zp07:     .res 1

;;;;;;;;; only zero-initial state stays file-backed;;;;;;;;;
; room:           .res 1                  ; BASIC: R
; old_room:       .res 1                  ; BASIC: X during movement
;;;;;;; persistent state moved to $0D-$0F;;;;;
; level:          .res 1                  ; BASIC: L

; blocked_count:  .res 1                  ; BASIC: M
;;;;; room replaces monster state;;;;;;
; monster_active: .res 1                  ; BASIC: Q
; monster_kind:   .res 1                  ; replacement for BASIC B$

;;;;;;; packed treasure flags;;;;;;;
; treasures:      .res 1
; treasure1:      .res 1                  ; BASIC: T1
; treasure2:      .res 1                  ; BASIC: T2
; treasure3:      .res 1                  ; BASIC: T3
; treasure4:      .res 1                  ; BASIC: T4

; direction:      .res 1

; no map copy
; map_index:      .res 1

; input_len:      .res 1
; token_start:    .res 1
; token_len:      .res 1

        .segment "BSS"

;;;;;; hot state moved to $08-$0C;;;;;;
; room:           .res 1                  ; BASIC: R
; direction:      .res 1
; input_len:      .res 1
; token_start:    .res 1
; token_len:      .res 1

;;;;ROM buffer at $0200;;;;;
; input_buffer:   .res INPUT_MAX + 1

; north_map:      .res 10
; south_map:      .res 10
; east_map:       .res 10
; west_map:       .res 10

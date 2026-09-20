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


;; history
;; -------
;; 001  port to ca65       2039 bytes
;; 002  use zeroed DATA    1998 bytes
;; 003  direct map access  1891 bytes
;; 004  table parser       1738 bytes
;; 005  ROM line input     1592 bytes

;;;;;;;;;;
;; init ;;
;;;;;;;;;;

.setcpu "6502"

;;;;;;;;;;;;;;;;;;;;;;;;
;; apple ii rom entry ;;
;;;;;;;;;;;;;;;;;;;;;;;;

COUT   = $FDED ; output character in A
; RDKEY  = $FD0C ; wait for key, return it in A
GETLN1 = $FD6F ; ROM line input
PRODOS = $BF00 ; prodos mli entry point
INPUT_BUFFER = $0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; temp zero-page pointer ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PRINT_PTR       = $06
PRINT_PTR_HI    = $07

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

.macro PRINTLN text
        lda     #<text
        ldx     #>text
        jsr     print_string
        jsr     newline
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
        jmp     AppStart

        .segment "CODE"

AppStart:
        ; preserve the two zero-page 
        ; bytes used by print_string
        lda     PRINT_PTR
        sta     saved_zp06
        lda     PRINT_PTR_HI
        sta     saved_zp07

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

        ; BASIC line 1 begins with R = 1, then READs ten rooms
        lda     #1
        sta     room

        ;; read map_data direct ;;
        ; jsr     load_map


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines 2-12: main command loop ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

main_loop:
        jsr     prompt_direction
        jsr     parse_direction
        bcc     bad_direction

        jsr     move_player

        ; BASIC line 7:
        ; IF L = 1 THEN L = 2: GOTO 1
        lda     level
        cmp     #1
        bne     @normal_post_move

        lda     #2
        sta     level

        ; no map copy
        ; jsr     load_map

        ; BASIC line 1 after the second READ:
        ; IF L = 2 THEN GOSUB 24
        jsr     show_inventory
        jmp     main_loop

@normal_post_move:
        jsr     post_move
        jmp     main_loop


bad_direction:
        ; BASIC line 6.
        jsr     newline
        PRINTLN msg_only_directions
        jmp     main_loop


;;;;;;;;;;;;;;;;
;; user input ;;
;;;;;;;;;;;;;;;;

prompt_direction:

        ; BASIC line 2:
        ; PRINT : PRINT "QUICK!!! WHICH WAY SHOULD I GO? " : PRINT : INPUT "";A$
        jsr     newline
        PRINTLN msg_prompt
        jsr     newline

        ; question mark mimics applesoft INPUT
        lda     #'?'
        ora     #$80
        jsr     COUT
        lda     #' '
        ora     #$80
        jsr     COUT

        ;;;;; ROM line input ;;;;;
        ; jsr     read_line
        jsr     GETLN1
        stx     input_len
        rts


;;;;;  old line input ;;;;;;
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
        ;;;;;;table parser ;;;;;
        ldy     #0
        sty     token_start

@find_space:
        cpy     input_len
        beq     @have_start
        lda     INPUT_BUFFER,y
        and     #$7F
        cmp     #' '
        beq     @found_space
        iny
        bne     @find_space

@found_space:
        iny
        sty     token_start

@have_start:
        lda     input_len
        sec
        sbc     token_start
        sta     token_len
        beq     @parse_fail

        ldy     token_start
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
        ldy     token_start
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
        sta     old_room

        ;;;; direct map_data index ;;;;;
        sec
        sbc     #1
        asl
        asl
        clc
        adc     direction
        tax
        lda     level
        beq     @map_ready
        txa
        adc     #40
        tax
@map_ready:
        lda     map_data,x

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
        sta     room

        ; BASIC line 17
        cmp     #11
        bne     @check_valid

        inc     level
        lda     #1
        sta     room

        jsr     newline
        PRINTLN msg_new_level

@check_valid:
        ; BASIC line 18
        lda     room
        beq     @blocked

        lda     #0
        sta     monster_active
        sta     blocked_count
        rts

@blocked:
        ; BASIC line 19
        jsr     newline
        PRINTLN msg_cant_move

        lda     old_room
        sta     room

        inc     blocked_count
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC lines 8-11: level-specifc actions after move ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

post_move:
        lda     level
        beq     @level_zero

        cmp     #2
        beq     @level_two

        cmp     #3
        beq     @level_three

        cmp     #4
        beq     @level_four

        rts


@level_zero:
        jsr     collect_treasures
        rts


@level_two:
        jsr     show_inventory
        jsr     check_monsters
        rts


@level_three:
        jsr     show_inventory

        jsr     newline
        PRINTLN msg_watch_pits

        jsr     check_pits
        rts


@level_four:
        jsr     show_inventory
        jmp     finish_game


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines20-23: pickup treasure ;
 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

collect_treasures:
        lda     room
        cmp     #5
        bne     @not_t1
        lda     #1
        sta     treasure1

@not_t1:
        lda     room
        cmp     #6
        bne     @not_t2
        lda     #1
        sta     treasure2

@not_t2:
        lda     room
        cmp     #4
        bne     @not_t3
        lda     #1
        sta     treasure3

@not_t3:
        lda     room
        cmp     #8
        bne     @done
        lda     #1
        sta     treasure4

@done:
        rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC lines 24-30: inventory ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

show_inventory:
        jsr     newline
        PRINTLN msg_carrying
        jsr     newline

        lda     treasure1
        ora     treasure2
        ora     treasure3
        ora     treasure4
        bne     @have_something

        PRINTLN msg_nothing
        rts


@have_something:
        lda     treasure1
        beq     @not_t1
        PRINTLN msg_treasure1

@not_t1:
        lda     treasure2
        beq     @not_t2
        PRINTLN msg_treasure2

@not_t2:
        lda     treasure3
        beq     @not_t3
        PRINTLN msg_treasure3

@not_t3:
        lda     treasure4
        beq     @done
        PRINTLN msg_treasure4

@done:
        rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines 31-37: mostros ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_monsters:
        lda     room
        cmp     #3
        bne     @not_werewolves

        lda     #0
        sta     monster_kind
        lda     #1
        sta     monster_active
        jmp     @test_monster

@not_werewolves:
        cmp     #7
        bne     @not_ogres

        lda     #1
        sta     monster_kind
        lda     #1
        sta     monster_active
        jmp     @test_monster

@not_ogres:
        cmp     #9
        bne     @test_monster

        lda     #2
        sta     monster_kind
        lda     #1
        sta     monster_active


@test_monster:
        lda     monster_active
        beq     @done

        ; BASIC line 35: IF M > 1 THEN GOTO 37
        lda     blocked_count
        cmp     #2
        bcs     monster_gotcha

        ; BASIC line 36
        jsr     newline
        PRINTLN msg_hurry

        jsr     print_monster
        PRINTLN msg_after_you

        inc     blocked_count

@done:
        rts


monster_gotcha:
        ; BASIC line 37
        jsr     newline
        PRINT msg_tsk
        jsr     print_monster
        PRINTLN msg_gotcha
        jmp     player_dead


print_monster:
        lda     monster_kind
        beq     @werewolves

        cmp     #1
        beq     @ogres

        PRINT msg_dragons
        rts

@werewolves:
        PRINT msg_werewolves
        rts

@ogres:
        PRINT msg_ogres
        rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BASIC lines 38-39: pits ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_pits:
        lda     room
        cmp     #3
        beq     @fall
        cmp     #4
        beq     @fall
        cmp     #8
        beq     @fall
        rts

@fall:
        jsr     newline
        PRINTLN msg_falling
        jsr     newline
        jmp     player_dead


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC lines 41-43: endings ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

player_dead:
        ; BASIC line 41.
        jsr     newline
        PRINTLN msg_dead
        jmp     exit_program


finish_game:
        lda     treasure1
        beq     @lost
        lda     treasure2
        beq     @lost
        lda     treasure3
        beq     @lost
        lda     treasure4
        beq     @lost

        ; BASIC line 42
        jsr     newline
        PRINTLN msg_won
        jmp     exit_program

@lost:
        ; BASIC line 43
        jsr     newline
        PRINTLN msg_lost


exit_program:

        ; restore the zero-page bytes
        ; borrowed by print_string
        lda     saved_zp06
        sta     PRINT_PTR
        lda     saved_zp07
        sta     PRINT_PTR_HI

        ; prodos quit
        jsr     PRODOS
        .byte   $65
        .addr   quit_params
        brk


quit_params:
        .byte   4   ; params count
        .byte   0   ; quit type
        .word   0   ; reserved
        .byte   0   ; reserved
        .word   0   ; reserved


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

print_string:
        sta     PRINT_PTR
        stx     PRINT_PTR_HI

        ldy     #0

@next:
        lda     (PRINT_PTR),y
        beq     @done

        ora     #$80
        jsr     COUT

        iny
        bne     @next

@done:
        rts


newline:
        lda     #$8D
        jsr     COUT
        rts


;;;;;;;;;;;;;;;;;;;;
;; read-only data ;;
;;;;;;;;;;;;;;;;;;;;

        .segment "RODATA"

;;;;; ;parser tables ;;;;  ;
dir_initials:
        .byte   "NSEW"
dir_lengths:
        .byte   5,5,4,4
dir_suffixes:
        .byte   "ORTH","OUTH","AST ","EST "


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BASIC line 40: map DATA        ;;
;;                                ;;
;; each row is N, S, E, W         ;;
;; first ten rows are first map   ;;
;; second ten rows are the second ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

map_data:
        .byte   0,  2,  0,  0          ; map 1, room 1
        .byte   0,  5,  3,  0          ; map 1, room 2
        .byte   0,  6,  4,  2          ; map 1, room 3
        .byte   0,  7,  0,  3          ; map 1, room 4
        .byte   2,  8,  6,  0          ; map 1, room 5
        .byte   3,  9,  7,  5          ; map 1, room 6
        .byte   4, 10,  0,  6          ; map 1, room 7
        .byte   5,  0,  9,  0          ; map 1, room 8
        .byte   6,  0, 10,  8          ; map 1, room 9
        .byte   0,  0, 11,  0          ; map 1, room 10

        .byte   0,  2,  0,  0          ; map 2, room 1
        .byte   0,  4,  5,  3          ; map 2, room 2
        .byte   0,  6,  2,  0          ; map 2, room 3
        .byte   2, 10,  7,  6          ; map 2, room 4
        .byte   0,  7,  0,  2          ; map 2, room 5
        .byte   3,  8,  2,  0          ; map 2, room 6
        .byte   5,  9,  0,  4          ; map 2, room 7
        .byte   6,  0, 10,  0          ; map 2, room 8
        .byte   7,  0,  0, 10          ; map 2, room 9
        .byte   4, 11,  9,  8          ; map 2, room 10


;;;;;;;;;;;;;;;;;;;
;; game messages ;;
;;;;;;;;;;;;;;;;;;;

msg_prompt:
        .byte   "QUICK!!! WHICH WAY SHOULD I GO? ",0

msg_only_directions:
        .byte   "I ONLY KNOW HOW TO GO NORTH, SOUTH, EAST, OR WEST..."
        .byte   "HURRY AND TRY AGAIN.",0

msg_new_level:
        .byte   "WHOOPS, WE'RE ON ANOTHER LEVEL.",0

msg_cant_move:
        .byte   "UH, UH...CAN'T MOVE THAT WAY.",0

msg_carrying:
        .byte   "YOU'RE CARRYING:",0

msg_nothing:
        .byte   "NOTHING",0

msg_treasure1:
        .byte   "A STATUE OF A GOLDEN MUSKRAT",0

msg_treasure2:
        .byte   "A DIAMOND THE SIZE OF A POTATO",0

msg_treasure3:
        .byte   "A PIGEON THE SIZE OF A RUBY",0

msg_treasure4:
        .byte   "A TANTALUS",0

msg_werewolves:
        .byte   "WEREWOLVES",0

msg_ogres:
        .byte   "THREE-TOED OGRES",0

msg_dragons:
        .byte   "HORRIBLE DRAGONS",0

msg_hurry:
        .byte   "HURRY, RUN....",0

msg_after_you:
        .byte   " ARE AFTER YOU!!!!",0

msg_tsk:
        .byte   "TSK TSK. THE ",0

msg_gotcha:
        .byte   " GOTCHA.",0

msg_watch_pits:
        .byte   "WATCH OUT FOR THE PITS...",0

msg_falling:
        .byte   "YIKES...YOU'RE FALLING, FALLING, FALLING, FALLING..."
        .byte   "FALLING...OOPS!!!",0

msg_dead:
        .byte   "AW, YOU'RE DEAD.",0

msg_won:
        .byte   "HEY, YOU WON...CONGRATULATIONS!!!",0

msg_lost:
        .byte   "WELL, PAL, YOU GOT OUT BUT WITHOUT ALL THE TREASURES..."
        .byte   "YOU LOSE.",0


;;;;;;;;;;;;;;
; variables ;;
;;;;;;;;;;;;;;

        .segment "DATA"

saved_zp06:     .res 1
saved_zp07:     .res 1

room:           .res 1                  ; BASIC: R
old_room:       .res 1                  ; BASIC: X during movement
level:          .res 1                  ; BASIC: L

blocked_count:  .res 1                  ; BASIC: M
monster_active: .res 1                  ; BASIC: Q
monster_kind:   .res 1                  ; replacement for BASIC B$

treasure1:      .res 1                  ; BASIC: T1
treasure2:      .res 1                  ; BASIC: T2
treasure3:      .res 1                  ; BASIC: T3
treasure4:      .res 1                  ; BASIC: T4

direction:      .res 1

; no map copy
; map_index:      .res 1

input_len:      .res 1
token_start:    .res 1
token_len:      .res 1
;;;;; ROM buffer at $0200 ;;;;;;
; input_buffer:   .res INPUT_MAX + 1

; north_map:      .res 10
; south_map:      .res 10
; east_map:       .res 10
; west_map:       .res 10

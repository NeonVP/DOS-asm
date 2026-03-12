.model tiny, C

VIDEO_SEG     equ 0B800h
FRAME_X       equ 22
FRAME_Y       equ 3
FRAME_W       equ 36
FRAME_H       equ 6
REGS_X        equ 23
REGS_Y        equ 4
REGS_STR_LEN  equ 121

.code
org 100h

locals @@

Start:
    call parse_cmd
    call calc_segs
    call main

    mov dx, offset End_of_code
    shr dx, 4
    inc dx
    mov ax, 3100h
    int 21h

main proc 
    cli

    mov ax, 3509h
    int 21h
    mov cs:[Old_Int9_Off], bx
    mov cs:[Old_Int9_Seg], es

    mov ax, 3508h
    int 21h
    mov cs:[Old_Int8_Off], bx
    mov cs:[Old_Int8_Seg], es

    push ds
    push cs
    pop ds

    mov dx, offset My_Int09_Handler
    mov ax, 2509h
    int 21h

    mov dx, offset My_Int08_Handler
    mov ax, 2508h
    int 21h

    pop ds

    push ds
    mov ax, 40h
    mov ds, ax
    mov ax, ds:[1Ch]
    pop ds
    mov cs:[last_kbd_tail], ax

    sti
    ret


main endp


; ----------------------------------------------------------
; void calc_segs()
; ----------------------------------------------------------
; * Description: Calculates segment aliases for draw_buffer and
;                save_buffer so they are addressable at offset 0000.
; * Arguments:   None
; * Preserves:   None
; * Destroys:    AX, BX, FLAGS
; ----------------------------------------------------------
calc_segs proc
    push ax bx
    mov bx, cs

    mov ax, offset draw_buffer
    add ax, 15
    shr ax, 4               
    add ax, bx              
    mov cs:[draw_seg], ax      

    mov ax, offset save_buffer
    add ax, 15
    shr ax, 4
    add ax, bx
    mov cs:[save_seg], ax

    pop bx ax
    ret
calc_segs endp

; ----------------------------------------------------------
; void parse_cmd()
; ----------------------------------------------------------
; * Description: Parses command tail:
;                [ATTR] [Fill] [Flag] [7Chars if Flag=1]
; * Arguments:   None
; * Preserves:   None
; * Destroys:    AX, BX, CX, SI, DI, FLAGS
; ----------------------------------------------------------
parse_cmd proc
    push si di ax bx cx
    cld

    mov cl, ds:[80h]
    cmp cl, 4
    jb @@exit_parse

    mov si, 81h

    call @@skip_space
    call @@hex_pair_to_byte
    mov byte ptr [bg_color], al
    mov byte ptr [msg_color], al

    call @@skip_space
    lodsb
    mov byte ptr [fill_char], al

    call @@skip_space
    lodsb
    cmp al, '1'
    jne @@exit_parse

    call @@skip_space
    mov di, offset frame_chars
    mov cx, 7
    rep movsb

@@exit_parse:
    pop cx bx ax di si
    ret


@@skip_space:
    lodsb
    cmp al, ' '
    je @@skip_space
    dec si
    ret  

@@hex_pair_to_byte:
    lodsb
    call @@char_to_nibble
    shl al, 4
    mov bl, al
    lodsb
    call @@char_to_nibble
    or al, bl
    ret

@@char_to_nibble:
    cmp al, '9'
    jbe @@is_digit
    and al, 11011111b
    sub al, 'A' - 10
    ret

@@is_digit:
    sub al, '0'
    ret

parse_cmd endp


; ----------------------------------------------------------
; void My_Int09_Handler()
; ----------------------------------------------------------
; * Description: Keyboard ISR. Detects Ctrl+S/Ctrl+E,
;                sets pending_action, and removes the hotkey from the queue.
; * Arguments:   None
; * Preserves:   None (all regs restored before IRET)
; * Destroys:    AX, BX, CX, DX, SI, DI, DS, ES, BP, FLAGS
; ----------------------------------------------------------
My_Int09_Handler proc 
    push ax bx cx dx si di ds es bp
    pushf

    call dword ptr cs:Old_Int9

    mov ax, 40h
    mov es, ax
    mov bx, es:[1Ch]
    cmp bx, cs:[last_kbd_tail]
    je @@exit

    mov cs:[last_kbd_tail], bx
    sub bx, 2
    cmp bx, 1Eh
    jae @@have_pos
    add bx, 20h
@@have_pos:
    mov ax, es:[bx]

    cmp ax, 1F13h     ; check for Ctrl + S
    je @@enable_frame
    cmp ax, 1205h     ; check for Ctrl + E
    je @@disable_frame
    jmp @@exit

@@enable_frame:
    mov cs:[pending_action], 1
    jmp @@remove_keys

@@disable_frame:
    mov cs:[pending_action], 2

@@remove_keys:
    mov bx, es:[1Ch]
    sub bx, 2
    cmp bx, 1Eh
    jae @@set_tail
    add bx, 20h
@@set_tail:
    mov es:[1Ch], bx
    mov cs:[last_kbd_tail], bx 

@@exit:
    pop bp es ds di si dx cx bx ax
    iret
My_Int09_Handler endp


; ----------------------------------------------------------
; void My_Int08_Handler()
; ----------------------------------------------------------
; * Description: Timer ISR. Chains original handler, handles pending_action,
;                and updates register snapshot inside the frame when active.
; * Arguments:   None
; * Preserves:   None (all regs restored before IRET)
; * Destroys:    AX, BX, CX, DX, SI, DI, DS, ES, BP, FLAGS
; ----------------------------------------------------------
My_Int08_Handler proc
    push ax bx cx dx si di ds es bp
    mov bp, sp

    push bp
    pushf
    call dword ptr cs:Old_Int8
    pop bp

    push cs
    pop ds

    ; --- ЛОГИКА ПЕРЕКЛЮЧЕНИЯ (pending_action) ---
    mov al, cs:[pending_action]
    cmp al, 0
    je @@check_active

    cmp al, 1
    je short @@do_enable
    
    call disable_frame
    mov cs:[pending_action], 0
    jmp near ptr @@exit

@@do_enable:
    call enable_frame
    mov cs:[pending_action], 0
    jmp near ptr @@exit

@@check_active:
    cmp cs:[active_flag], 1
    je @@active
    jmp @@exit

@@active:
    ; [bp+0]=BP, +2=ES, +4=DS, +6=DI, +8=SI, +10=DX, +12=CX, +14=BX, +16=AX
    ; [bp+18]=IP, [bp+20]=CS, [bp+22]=FLAGS
    mov ax, ss:[bp+16]                ; AX
    mov di, offset ax_hex
    call word_to_hex_at

    mov ax, ss:[bp+14]                ; BX
    mov di, offset bx_hex
    call word_to_hex_at

    mov ax, ss:[bp+12]                ; CX
    mov di, offset cx_hex
    call word_to_hex_at

    mov ax, ss:[bp+10]                ; DX
    mov di, offset dx_hex
    call word_to_hex_at

    mov ax, ss:[bp+8]                 ; SI
    mov di, offset si_hex
    call word_to_hex_at

    mov ax, ss:[bp+6]                 ; DI
    mov di, offset di_hex
    call word_to_hex_at

    mov ax, ss:[bp+0]                 ; BP
    mov di, offset bp_hex
    call word_to_hex_at

    mov ax, bp                        ; SP 
    add ax, 24
    mov di, offset sp_hex
    call word_to_hex_at

    mov ax, ss:[bp+4]                 ; DS
    mov di, offset ds_hex
    call word_to_hex_at

    mov ax, ss:[bp+2]                 ; ES
    mov di, offset es_hex
    call word_to_hex_at

    mov ax, ss                         ; SS
    mov di, offset ss_hex
    call word_to_hex_at

    mov ax, ss:[bp+20]                ; CS
    mov di, offset cs_hex
    call word_to_hex_at

    mov ax, ss:[bp+18]                ; IP
    mov di, offset ip_hex
    call word_to_hex_at

    mov ax, ss:[bp+22]                ; FLAGS
    mov di, offset fl_hex
    call word_to_hex_at

    push VIDEO_SEG
    push REGS_Y
    push REGS_X
    push word ptr cs:[msg_color]
    push REGS_STR_LEN
    push offset regs_render
    call print_string
    add sp, 12

@@exit:
    pop bp es ds di si dx cx bx ax
    iret
My_Int08_Handler endp


enable_frame proc
    mov ax, cs:[bg_color]
    mov cs:[msg_color], ax

    push VIDEO_SEG
    push word ptr cs:[save_seg]
    call copy_screen

    push VIDEO_SEG
    push word ptr cs:[fill_char]
    push word ptr cs:[bg_color]
    push FRAME_H
    push FRAME_W
    push FRAME_Y
    push FRAME_X
    call draw_frame
    add sp, 14

    mov cs:[active_flag], 1
    ret
enable_frame endp

disable_frame proc
    push word ptr cs:[save_seg]
    push VIDEO_SEG
    call copy_screen
    mov cs:[active_flag], 0
    ret
disable_frame endp


; ----------------------------------------------------------
; void word_to_hex_at(word value_in_AX, char* out_ptr_in_DI)
; ----------------------------------------------------------
; * Description: Converts AX to 4 uppercase hex digits at CS:DI.
; * Arguments:   AX - value, DI - destination pointer
; * Preserves:   AX, BX, CX, DI
; * Destroys:    FLAGS
; ----------------------------------------------------------
word_to_hex_at proc
    push ax bx cx di
    mov cx, 4
@@hex_loop:
    rol ax, 4
    mov bx, ax
    and bx, 0Fh
    mov bl, cs:[hex_table + bx]
    mov cs:[di], bl
    inc di
    loop @@hex_loop
    pop di cx bx ax
    ret
hex_table db '0123456789ABCDEF'
word_to_hex_at endp


; ----------------------------------------------------------
; void copy_screen(word source_seg, word target_seg)
; ----------------------------------------------------------
; * Description: Copies one full text page (4000 bytes)
;                from source_seg:0000 to target_seg:0000.
; * Arguments:   source_seg [bp+6], target_seg [bp+4]
; * Preserves:   SI, DI, BP, DS, ES
; * Destroys:    CX, FLAGS
; ----------------------------------------------------------
copy_screen proc
    push bp
    mov  bp, sp
    
    push ds es si di cx

    mov  ds, [bp + 6]
    mov  es, [bp + 4]
    
    xor  si, si
    xor  di, di
    mov  cx, 2000
    
    cld
    rep  movsw
    
    pop  cx di si es ds
    pop  bp
    
    ret  4
copy_screen endp

; ----------------------------------------------------------
; void draw_frame(word x, word y, word w, word h, word attr,
;                 word f_char, word target_seg)
; ----------------------------------------------------------
; * Description: Draws a frame and fills its inner area.
; * Arguments:   x, y, w, h, attr, f_char, target_seg
; * Preserves:   AX, BX, CX, DX, SI, DI, ES
; * Destroys:    FLAGS
; ----------------------------------------------------------
draw_frame proc C, x_pos:word, y_pos:word, w:word, h:word, attr:word, f_char:word, target_seg:word
    push ax bx cx dx si di es

    mov ax, target_seg
    mov es, ax

    mov ax, y_pos
    mov bx, 80
    mul bx
    add ax, x_pos
    shl ax, 1
    mov di, ax          

    mov ax, attr
    mov ah, al

    mov al, [frame_chars + 0]
    stosw
    mov cx, w
    sub cx, 2
    mov al, [frame_chars + 3]
    rep stosw
    mov al, [frame_chars + 6]
    stosw

    mov dx, h
    sub dx, 2
@@mid_rows:
    mov bx, 80
    sub bx, w
    shl bx, 1
    add di, bx

    mov al, [frame_chars + 1]
    stosw
    
    mov al, byte ptr [f_char]
    mov cx, w
    sub cx, 2
@@mid_space:
    stosw
    loop @@mid_space

    mov al, [frame_chars + 5]
    stosw

    dec dx
    jnz @@mid_rows

    mov bx, 80
    sub bx, w
    shl bx, 1
    add di, bx

    mov al, [frame_chars + 2]
    stosw
    mov cx, w
    sub cx, 2
@@bot_line:
    mov al, [frame_chars + 3]
    stosw
    loop @@bot_line
    mov al, [frame_chars + 4]
    stosw

    pop es di si dx cx bx ax
    ret
draw_frame endp


; ----------------------------------------------------------
; void print_string(word p_str, word s_len, word clr,
;                   word x_pos, word y_pos, word target_seg)
; ----------------------------------------------------------
; * Description: Prints fixed-length string to target text page.
; * Arguments:   p_str, s_len, clr, x_pos, y_pos, target_seg
; * Preserves:   DI, SI, BP, ES
; * Destroys:    AX, CX, DX
; ----------------------------------------------------------
print_string proc C, p_str:word, s_len:word, clr:word, x_pos:word, y_pos:word, target_seg:word
    push es di si bp
    
    mov ax, [y_pos]
    mov bx, 160
    mul bx
    mov bx, [x_pos]
    shl bx, 1
    add ax, bx
    mov di, ax          
    
    mov ax, [target_seg]
    mov es, ax
    mov si, [p_str]     
    mov cx, [s_len]
    
    mov ax, [clr]
    mov ah, al
    
    cld
@@print_loop:
    jcxz @@done
    lodsb
    dec cx

    cmp al, 10
    je @@new_line
    
    stosw               
    jmp @@print_loop

@@new_line:
    add di, 160
    push ax dx
    mov ax, di
    mov bx, 160
    xor dx, dx
    div bx
    sub di, dx
    mov bx, [x_pos]
    shl bx, 1
    add di, bx
    pop dx ax
    jmp @@print_loop

@@done:
    pop bp si di es
    ret
print_string endp


; ================ DATA ================
regs_render   db 'AX='
ax_hex        db '0000  BX='
bx_hex        db '0000  CX='
cx_hex        db '0000  DX='
dx_hex        db '0000', 10
              db 'SI='
si_hex        db '0000  DI='
di_hex        db '0000  BP='
bp_hex        db '0000  SP='
sp_hex        db '0000', 10
              db 'DS='
ds_hex        db '0000  ES='
es_hex        db '0000  SS='
ss_hex        db '0000  CS='
cs_hex        db '0000', 10
              db 'IP='
ip_hex        db '0000  FL='
fl_hex        db '0000'

pending_action db 0                   ; 0-none, 1-enable, 2-disable

; Frame settings.
bg_color    dw 001Fh
msg_color   dw 000Fh
fill_char   dw 0020h  
def_msg     db 'The cat ate your output, MEOW!', 0
msg_ptr     dw offset def_msg   

; Frame glyphs: UL, VL, LL, HL, LR, VR, UR.
frame_chars db 0DAh,   0B3h,   0C0h,   0C4h,   0D9h,   0B3h,   0BFh

; Original interrupt vectors.
Old_Int8 label dword
Old_Int8_Off dw 0
Old_Int8_Seg dw 0
Old_Int9 label dword
Old_Int9_Off dw 0
Old_Int9_Seg dw 0

; --- BUFFERS ---
draw_buffer db 4000 dup(0)
save_buffer db 4000 dup(0)

draw_seg dw 0
save_seg dw 0

active_flag   db 0
last_kbd_tail dw 0

End_of_code:
end Start

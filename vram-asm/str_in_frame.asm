.model tiny, C

.code
org 100h

locals @@

Start:
    call parse_cmd
    call main
    mov ax, 4C00h
    int 21h

; --- DATA ---
bg_color    dw 001Fh            
msg_color   dw 000Fh            
def_msg     db 'The cat ate your output, MEOW!', 0
msg_ptr     dw offset def_msg   
msg_len     dw 29


main proc 
    push [bg_color]
    call clear_screen
    add sp, 2

    mov ax, ds:[msg_len]
    shr ax, 1                   ; AX = len / 2
    mov cx, 40
    sub cx, ax                  ; CX = 40 - (len / 2)
    
    push 12                     
    push cx                     
    
    mov ax, [msg_color]
    push ax
    
    push [msg_ptr]   
    call print_string
    add sp, 8

    ret
main endp


; ----------------------------------------------------------
; void parse_cmd()
; ----------------------------------------------------------
; * Description: Parses the commnand line: background color, text color, message 
; * Arguments:   None 
; * Preserves:   None 
; * Destroys:    AX, BX, CX, SI, DI, FLAGS
; ----------------------------------------------------------
parse_cmd proc
    push si di ax bx cx
    cld

    mov cl, ds:[80h]
    cmp cl, 5                   
    jb @@exit_parse

    mov si, 81h
@@skip_space:
    lodsb
    cmp al, ' '
    je @@skip_space
    dec si                      

    call @@hex_pair_to_byte
    mov byte ptr [bg_color], al

@@skip_space2:
    lodsb
    cmp al, ' '
    je @@skip_space2
    dec si

    call @@hex_pair_to_byte
    mov byte ptr [msg_color], al

@@skip_space3:
    lodsb
    cmp al, ' '
    je @@skip_space3
    dec si                      

    mov [msg_ptr], si
    
    xor ax, ax
    mov al, ds:[80h]
    add ax, 81h                 ; AX = 81h + length
    sub ax, si                  ; AX = (81h + length) - current_SI
    mov [msg_len], ax

@@exit_parse:
    pop cx bx ax di si
    ret


@@hex_pair_to_byte:
    lodsb
    call @@char_to_nibble
    shl al, 4                   ; AL = high_nibble * 16
    mov bl, al
    lodsb
    call @@char_to_nibble
    or al, bl                   ; AL = high | low
    ret

@@char_to_nibble:
    cmp al, '9'
    jbe @@is_digit
    and al, 11011111b           
    sub al, 'A'-10
    ret
@@is_digit:
    sub al, '0'
    ret
parse_cmd endp

; ----------------------------------------------------------
; void clear_screen(word color_attr)
; ----------------------------------------------------------
; * Description: Clears the text screen.
; * Arguments: color_attr
; * Preserves: DI, SI, BP, ES
; * Destroys: AX, CX
; ----------------------------------------------------------
clear_screen proc C, color_attr:word
    push es di cx
    mov ax, 0B800h
    mov es, ax
    xor di, di
    mov cx, 2000        
    mov al, ' '         
    mov ah, [byte ptr color_attr] 
    cld
    rep stosw
    pop cx di es
    ret
clear_screen endp


; ----------------------------------------------------------
; void print_string(word p_str, word clr, word x, word y)
; ----------------------------------------------------------
; * Description: Prints a string at given coordinates (X, Y).
;                Offset: DI = (Y * 160) + (X * 2).
; * Arguments:   p_str  - Offset of string
;                clr    - Color attribute (low byte)
;                x_pos  - 0-79
;                y_pos  - 0-24
; * Preserves:   DI, SI, BP, ES
; * Destroys:    AX, CX, DX
; ----------------------------------------------------------
print_string proc C, p_str:word, clr:word, x_pos:word, y_pos:word
    push es di si bp
    
    mov ax, y_pos
    mov bx, 160
    mul bx                      ; AX = Y * 160
    mov bx, x_pos
    shl bx, 1                   ; BX = X * 2
    add ax, bx                  ; AX = (Y * 160) + (X * 2)
    mov di, ax          
    
    mov ax, 0B800h
    mov es, ax
    mov si, [p_str]     
    mov cx, ds:[msg_len]
    
    mov ax, [clr]
    mov ah, al
    
    cld
@@print_loop:
    lodsb               
    stosw               
    loop @@print_loop
    
    pop bp si di es
    ret
print_string endp



end Start
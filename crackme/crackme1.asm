.model tiny
.code
org 100h

Start:
    mov ah, 3Fh
    mov bx, 0           
    mov cx, 255         
    mov dx, offset input_data
    int 21h
    
    mov si, offset input_data
    call hash_string
    mov bl, al

    mov si, offset secret_password
    call hash_string
    
    cmp al, bl
    je .access_allowed

.access_denied:
    mov ah, 09h
    mov dx, offset msg_fail
    int 21h
    jmp exit_

.access_allowed:
    mov ah, 09h
    mov dx, offset msg_ok
    int 21h

exit_:
    mov ax, 4C00h
    int 21h


; ======================================================
; void hash_string
; ------------------------------------------------------
; IN:  SI - Pointer to the beginning of a line in a data segment
; OUT: AL - hash
; Destroys: AL, DL, SI
; ======================================================
hash_string proc
    xor al, al
hash_loop:
    mov dl, [si]
    cmp dl, '$'         
    je hash_done
    cmp dl, 0Dh         
    je hash_done
    cmp dl, 0Ah         
    je hash_done
    
    xor al, dl
    add al, 05h
    rol al, 2
    inc si
    jmp hash_loop
hash_done:
    ret
hash_string endp

; --- ДАННЫЕ ---
input_data      db 10 dup('?')
secret_password db 'Meow_uwu$', 0 

msg_ok          db 0Dh, 0Ah, 'Access Granted!$'
msg_fail        db 0Dh, 0Ah, 'Access Denied!$'

end Start
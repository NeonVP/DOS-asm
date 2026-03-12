.model tiny
.code
org 100h

Start:
    mov ah, 09h
    mov dx, offset msg_prompt
    int 21h

    call check_password
    
    cmp ax, 1
    jne access_denied

access_granted:
    mov ah, 09h
    mov dx, offset msg_ok
    int 21h
    jmp exit_

access_denied:
    mov ah, 09h
    mov dx, offset msg_fail
    int 21h

exit_:
    mov ax, 4C00h
    int 21h

check_password proc
    push bp
    mov bp, sp
    sub sp, 10

    push di
    mov di, sp
    push ds
    pop es
    xor al, al
    mov cx, 10
    cld
    rep stosb
    pop di
    
    mov ah, 3Fh
    mov bx, 0
    mov cx, 255
    mov dx, bp
    sub dx, 10
    int 21h


    mov si, bp
    sub si, 10
    call simple_hash

    cmp al, [stored_hash]
    je pass_correct

pass_wrong:
    xor ax, ax
    jmp end_check

pass_correct:
    mov ax, 1

end_check:
    mov sp, bp
    pop bp
    ret
check_password endp

simple_hash proc
    xor al, al
    mov cx, 10
hash_loop:
    mov dl, [si]
    
    cmp dl, 0Dh
    je hash_done
    cmp dl, 0Ah
    je hash_done
    cmp dl, 00h
    je hash_done
    
    xor al, dl
    add al, 05h
    rol al, 2
    
    inc si
    loop hash_loop
hash_done:
    ret
simple_hash endp


msg_prompt  db 'Enter key: $'
msg_ok      db 0Dh, 0Ah, 'Access Granted!$'
msg_fail    db 0Dh, 0Ah, 'Access Denied!$'
stored_hash db 0AAh

end Start
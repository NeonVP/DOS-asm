.model tiny

.code
org 100h

Start:
    mov ax, 0b800h
    mov es, ax
    xor bx, bx

    mov si, offset msg
    
print_loop:
    mov al, [si]
    cmp al, 0
    je done

    mov [es:bx],   al
    mov [es:bx+1], 0deh

    inc si
    add bx, 2

    jmp print_loop

done:
    mov ax, 4c00h
    int 21h

msg: db 'Hello, DOS World!', 0
end Start
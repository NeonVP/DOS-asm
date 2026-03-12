.model tiny
.code
org 100h

locals @@

Start:
    mov ax, 1111h
    mov bx, 2222h
    mov cx, 3333h
    mov dx, 4444h
    mov si, 5555h
    mov di, 6666h
    mov bp, 7777h

@@loop:
    cli
    in  al, 60h
    cmp al, 01h         ; Esc
    mov al, 11h
    sti
    jne @@loop

@@done:
    mov ax, 4C00h
    int 21h

end Start

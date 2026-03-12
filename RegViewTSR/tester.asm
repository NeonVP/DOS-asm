.model tiny
.code
org 100h

locals @@

Start:
    mov ax, 1984h
    mov bx, 0BEEFh
    mov cx, 0CAFEh
    mov dx, 0DEADh
    mov si, 0F00Dh
    mov di, 0D00Dh
    mov bp, 0FACEh
    mov sp, 0F84h

    mov ax, 0ABCDh
    mov ds, ax
    mov ax, 0BADAh
    mov es, ax

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

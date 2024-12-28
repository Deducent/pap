bits 16

mov dx, 6
mov bp, 1000
mov si, 0
mov [bp + si], si
add si, 2
cmp si, dx
jne 247
mov [bp + si], si
add si, 2
cmp si, dx
jne 247
mov [bp + si], si
add si, 2
cmp si, dx
jne 247
mov bx, 0
mov si, 0
mov cx, [bp + si]
add bx, cx
add si, 2
cmp si, dx
jne 245
mov cx, [bp + si]
add bx, cx
add si, 2
cmp si, dx
jne 245
mov cx, [bp + si]
add bx, cx
add si, 2
cmp si, dx
jne 245

BITS 64
DEFAULT REL

global base64_encode

section .text

; RDI=destination, ESI=destination capacity, RDX=source, ECX=source length.
; EAX=encoded length, or -1 on invalid input/capacity. Output is not NUL-terminated.
base64_encode:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    test ecx, ecx
    js .bad
    mov eax, ecx
    add eax, 2
    jc .bad
    xor edx, edx
    mov ebx, 3
    div ebx
    imul eax, eax, 4
    cmp eax, r13d
    ja .bad
    mov r13d, eax
    xor r8d, r8d
    xor r9d, r9d
.loop:
    cmp r8d, ecx
    jae .done
    movzx eax, byte [r14 + r8]
    inc r8d
    shl eax, 16
    xor ebx, ebx
    cmp r8d, ecx
    jae .one
    movzx ebx, byte [r14 + r8]
    inc r8d
    shl ebx, 8
    or eax, ebx
    mov ebx, 2
    cmp r8d, ecx
    jae .emit
    movzx ebx, byte [r14 + r8]
    inc r8d
    or eax, ebx
    mov ebx, 3
    jmp .emit
.one:
    mov ebx, 1
.emit:
    mov edx, eax
    shr edx, 18
    mov dl, [base64_table + rdx]
    mov [r12 + r9], dl
    mov edx, eax
    shr edx, 12
    and edx, 63
    mov dl, [base64_table + rdx]
    mov [r12 + r9 + 1], dl
    cmp ebx, 1
    je .pad_two
    mov edx, eax
    shr edx, 6
    and edx, 63
    mov dl, [base64_table + rdx]
    mov [r12 + r9 + 2], dl
    cmp ebx, 2
    je .pad_one
    mov edx, eax
    and edx, 63
    mov dl, [base64_table + rdx]
    mov [r12 + r9 + 3], dl
    add r9d, 4
    jmp .loop
.pad_two:
    mov byte [r12 + r9 + 2], '='
    mov byte [r12 + r9 + 3], '='
    add r9d, 4
    jmp .loop
.pad_one:
    mov byte [r12 + r9 + 3], '='
    add r9d, 4
    jmp .loop
.done:
    mov eax, r9d
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata
base64_table: db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

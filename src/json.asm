BITS 64
DEFAULT REL

global json_escape_append

; RDI=destination, ESI=destination capacity, RDX=source, ECX=source length.
; RAX=escaped byte length, or -1 when the bounded destination is insufficient.
; The output is not NUL-terminated. All JSON control, quote, and backslash
; escapes are emitted; non-control UTF-8 bytes pass through unchanged.
section .text
json_escape_append:
    xor r8d, r8d                     ; input offset
    xor r9d, r9d                     ; output offset
.loop:
    cmp r8d, ecx
    jae .done
    movzx eax, byte [rdx + r8]
    inc r8d
    cmp al, '"'
    je .quote
    cmp al, 0x5c
    je .backslash
    cmp al, 8
    je .backspace
    cmp al, 12
    je .formfeed
    cmp al, 10
    je .newline
    cmp al, 13
    je .carriage_return
    cmp al, 9
    je .tab
    cmp al, 0x20
    jb .unicode_control
    cmp r9d, esi
    jae .bad
    mov [rdi + r9], al
    inc r9d
    jmp .loop

.quote:
    mov al, '"'
    jmp .two_byte_escape
.backslash:
    mov al, 0x5c
    jmp .two_byte_escape
.backspace:
    mov al, 'b'
    jmp .two_byte_escape
.formfeed:
    mov al, 'f'
    jmp .two_byte_escape
.newline:
    mov al, 'n'
    jmp .two_byte_escape
.carriage_return:
    mov al, 'r'
    jmp .two_byte_escape
.tab:
    mov al, 't'
.two_byte_escape:
    lea r10d, [r9d + 2]
    cmp r10d, esi
    ja .bad
    mov byte [rdi + r9], 0x5c
    mov [rdi + r9 + 1], al
    mov r9d, r10d
    jmp .loop

.unicode_control:
    lea r10d, [r9d + 6]
    cmp r10d, esi
    ja .bad
    mov byte [rdi + r9], 0x5c
    mov byte [rdi + r9 + 1], 'u'
    mov byte [rdi + r9 + 2], '0'
    mov byte [rdi + r9 + 3], '0'
    mov r11d, eax
    shr r11d, 4
    and eax, 0x0f
    lea r10, [hex_lower]
    mov r11b, [r10 + r11]
    mov [rdi + r9 + 4], r11b
    mov al, [r10 + rax]
    mov [rdi + r9 + 5], al
    add r9d, 6
    jmp .loop
.done:
    mov eax, r9d
    ret
.bad:
    mov eax, -1
    ret

section .rodata
hex_lower: db '0123456789abcdef'

BITS 64
DEFAULT REL

extern base64_encode
global _start
%define SYS_EXIT 60

section .text
_start:
    mov dword [stage], 1
    lea rdi, [out]
    mov esi, 16
    lea rdx, [one]
    mov ecx, one_len
    call base64_encode
    cmp eax, one_expected_len
    jne .fail
    lea rdi, [out]
    lea rsi, [one_expected]
    mov edx, one_expected_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [stage], 2
    lea rdi, [out]
    mov esi, 16
    lea rdx, [two]
    mov ecx, two_len
    call base64_encode
    cmp eax, two_expected_len
    jne .fail
    lea rdi, [out]
    lea rsi, [two_expected]
    mov edx, two_expected_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [stage], 3
    lea rdi, [out]
    mov esi, 16
    lea rdx, [three]
    mov ecx, three_len
    call base64_encode
    cmp eax, three_expected_len
    jne .fail
    lea rdi, [out]
    lea rsi, [three_expected]
    mov edx, three_expected_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [stage], 4
    lea rdi, [out]
    mov esi, 3
    lea rdx, [one]
    mov ecx, one_len
    call base64_encode
    cmp eax, -1
    jne .fail

    mov dword [stage], 5
    lea rdi, [out]
    mov esi, 16
    xor edx, edx
    mov ecx, one_len
    call base64_encode
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [stage]
    syscall

equal_bytes:
    xor ecx, ecx
.loop:
    cmp ecx, edx
    jae .yes
    mov al, [rdi + rcx]
    cmp al, [rsi + rcx]
    jne .no
    inc ecx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

section .rodata
one: db 'M'
one_len equ $ - one
one_expected: db 'TQ=='
one_expected_len equ $ - one_expected
two: db 'Ma'
two_len equ $ - two
two_expected: db 'TWE='
two_expected_len equ $ - two_expected
three: db 'Man'
three_len equ $ - three
three_expected: db 'TWFu'
three_expected_len equ $ - three_expected
section .bss
out: resb 16
stage: resd 1

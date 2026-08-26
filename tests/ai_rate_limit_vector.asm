BITS 64
DEFAULT REL

extern ai_rate_allow
global _start
%define SYS_EXIT 60

section .text
_start:
    xor ebx, ebx
.loop:
    cmp ebx, 10
    jae .full
    lea rdi, [user_one]
    mov esi, user_one_len
    call ai_rate_allow
    test al, al
    jz .fail1
    inc ebx
    jmp .loop
.full:
    lea rdi, [user_one]
    mov esi, user_one_len
    call ai_rate_allow
    test al, al
    jnz .fail2
    lea rdi, [user_two]
    mov esi, user_two_len
    call ai_rate_allow
    test al, al
    jz .fail3
    xor edi, edi
    mov esi, user_one_len
    call ai_rate_allow
    test al, al
    jnz .fail4
    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail1: mov edi, 1
    jmp .exit
.fail2: mov edi, 2
    jmp .exit
.fail3: mov edi, 3
    jmp .exit
.fail4: mov edi, 4
.exit:
    mov eax, SYS_EXIT
    syscall
section .rodata
user_one: db 'user-one'
user_one_len equ $ - user_one
user_two: db 'user-two'
user_two_len equ $ - user_two

BITS 64
DEFAULT REL

extern ai_rate_allow
extern message_rate_allow
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

    lea rdi, [message_user_one]
    mov esi, message_user_one_len
    call message_rate_allow
    test al, al
    jz .fail5
    lea rdi, [message_user_one]
    mov esi, message_user_one_len
    call message_rate_allow
    test al, al
    jnz .fail6
    lea rdi, [message_user_two]
    mov esi, message_user_two_len
    call message_rate_allow
    test al, al
    jz .fail7
    xor edi, edi
    mov esi, message_user_one_len
    call message_rate_allow
    test al, al
    jnz .fail8

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
    jmp .exit
.fail5: mov edi, 5
    jmp .exit
.fail6: mov edi, 6
    jmp .exit
.fail7: mov edi, 7
    jmp .exit
.fail8: mov edi, 8
.exit:
    mov eax, SYS_EXIT
    syscall
section .rodata
user_one: db 'user-one'
user_one_len equ $ - user_one
user_two: db 'user-two'
user_two_len equ $ - user_two
message_user_one: db 'message-user-one'
message_user_one_len equ $ - message_user_one
message_user_two: db 'message-user-two'
message_user_two_len equ $ - message_user_two

BITS 64
DEFAULT REL

extern xp_increment
extern xp_get

global _start

%define SYS_EXIT 60

section .text
_start:
    ; A new guild/user starts at one and increments deterministically.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_increment
    cmp eax, 1
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_increment
    cmp eax, 2
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_get
    cmp eax, 2
    jne .fail

    ; Same user in another guild and another user in the same guild are isolated.
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_increment
    cmp eax, 1
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_two]
    mov ecx, user_two_len
    call xp_get
    test eax, eax
    jnz .fail

    ; Empty identity parts cannot create a score key.
    lea rdi, [guild_one]
    xor esi, esi
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_increment
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall

section .rodata
guild_one: db 'guild-a'
guild_one_len equ $ - guild_one
guild_two: db 'guild-b'
guild_two_len equ $ - guild_two
user_one: db 'user-a'
user_one_len equ $ - user_one
user_two: db 'user-b'
user_two_len equ $ - user_two

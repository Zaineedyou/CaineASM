BITS 64
DEFAULT REL

extern warnings_add
extern warnings_get
extern warnings_clear

global _start

%define SYS_EXIT 60

section .text
_start:
    ; Absent warnings read as zero.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_get
    test eax, eax
    jnz .fail

    ; Count increments persistently for exactly one guild/user pair.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_add
    cmp eax, 1
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_add
    cmp eax, 2
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_get
    cmp eax, 2
    jne .fail

    ; A different guild and user remain isolated.
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_get
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_two]
    mov ecx, user_two_len
    call warnings_get
    test eax, eax
    jnz .fail

    ; Clear is idempotent and removes the persisted count.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_clear
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_get
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_clear
    test eax, eax
    jnz .fail

    ; Invalid identifiers are rejected before touching store state.
    xor edi, edi
    mov esi, guild_one_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call warnings_add
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
guild_one: db 'guild-1'
guild_one_len equ $ - guild_one
guild_two: db 'guild-2'
guild_two_len equ $ - guild_two
user_one: db 'user-1'
user_one_len equ $ - user_one
user_two: db 'user-2'
user_two_len equ $ - user_two

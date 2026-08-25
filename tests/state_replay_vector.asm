BITS 64
DEFAULT REL

global _start

extern persist_configure
extern persist_replay
extern store_replay_record
extern store_delete_raw
extern afk_set
extern afk_clear
extern afk_lookup
extern xp_increment
extern xp_get

%define SYS_UNLINK 87

section .text
_start:
    lea rdi, [state_path]
    mov eax, SYS_UNLINK
    syscall

    lea rdi, [state_path]
    mov esi, state_path_len
    call persist_configure
    test eax, eax
    js fail

    ; Keep one AFK record, then append a deletion for another identity.
    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    lea r8, [reason]
    mov r9d, reason_len
    call afk_set
    test eax, eax
    jnz fail

    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_two]
    mov ecx, user_two_len
    lea r8, [reason]
    mov r9d, reason_len
    call afk_set
    test eax, eax
    jnz fail
    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_two]
    mov ecx, user_two_len
    call afk_clear
    test eax, eax
    jnz fail

    ; Two XP increments must replay to the exact current total.
    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_increment
    cmp eax, 1
    jne fail
    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_increment
    cmp eax, 2
    jne fail

    ; Remove only volatile state. These raw calls must not append journal records.
    lea rdi, [afk_one_key]
    mov esi, afk_one_key_len
    call store_delete_raw
    test eax, eax
    jnz fail
    lea rdi, [xp_one_key]
    mov esi, xp_one_key_len
    call store_delete_raw
    test eax, eax
    jnz fail

    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call afk_lookup
    test rax, rax
    jnz fail
    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_get
    test eax, eax
    jnz fail

    lea rdi, [store_replay_record]
    call persist_replay
    cmp eax, 5
    jne fail

    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call afk_lookup
    test rax, rax
    jz fail
    cmp edx, reason_len
    jne fail
    mov rdi, rax
    lea rsi, [reason]
    mov ecx, reason_len
    call assert_equal
    test eax, eax
    jnz fail

    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_two]
    mov ecx, user_two_len
    call afk_lookup
    test rax, rax
    jnz fail

    lea rdi, [guild]
    mov esi, guild_len
    lea rdx, [user_one]
    mov ecx, user_one_len
    call xp_get
    cmp eax, 2
    jne fail

    lea rdi, [state_path]
    mov eax, SYS_UNLINK
    syscall
    mov eax, 60
    xor edi, edi
    syscall

fail:
    mov eax, 60
    mov edi, 1
    syscall

; RDI=actual, RSI=expected, ECX=count. EAX=0 equal, -1 otherwise.
assert_equal:
    xor eax, eax
.loop:
    cmp eax, ecx
    jae .yes
    mov r8b, [rdi + rax]
    cmp r8b, [rsi + rax]
    jne .no
    inc eax
    jmp .loop
.yes:
    xor eax, eax
    ret
.no:
    mov eax, -1
    ret

section .rodata
state_path: db '/tmp/caineasm-state-replay', 0
state_path_len equ $ - state_path - 1
guild: db '1'
guild_len equ $ - guild
user_one: db '2'
user_one_len equ $ - user_one
user_two: db '3'
user_two_len equ $ - user_two
reason: db 'away'
reason_len equ $ - reason
afk_one_key: db 'afk:1:2'
afk_one_key_len equ $ - afk_one_key
xp_one_key: db 'xp:1:2'
xp_one_key_len equ $ - xp_one_key

BITS 64
DEFAULT REL

extern store_set
extern store_get
extern store_delete
extern afk_set
extern afk_clear
extern afk_lookup

global _start

%define SYS_EXIT 60

section .text
_start:
    ; Store inserts a new bounded key/value pair.
    lea rdi, [store_key]
    mov esi, store_key_len
    lea rdx, [value_one]
    mov ecx, value_one_len
    call store_set
    test eax, eax
    jnz .fail

    lea rdi, [store_key]
    mov esi, store_key_len
    call store_get
    test rax, rax
    jz .fail
    cmp edx, value_one_len
    jne .fail
    lea rsi, [value_one]
    mov rdi, rax
    mov edx, value_one_len
    call equal_bytes
    test al, al
    jz .fail

    ; Updating the same key must replace its value, not corrupt its key slot.
    lea rdi, [store_key]
    mov esi, store_key_len
    lea rdx, [value_two]
    mov ecx, value_two_len
    call store_set
    test eax, eax
    jnz .fail

    lea rdi, [store_key]
    mov esi, store_key_len
    call store_get
    test rax, rax
    jz .fail
    cmp edx, value_two_len
    jne .fail
    lea rsi, [value_two]
    mov rdi, rax
    mov edx, value_two_len
    call equal_bytes
    test al, al
    jz .fail

    lea rdi, [store_key]
    mov esi, store_key_len
    call store_delete
    test eax, eax
    jnz .fail
    lea rdi, [store_key]
    mov esi, store_key_len
    call store_get
    test rax, rax
    jnz .fail
    test edx, edx
    jnz .fail

    ; Key and value caps reject unsafe input deterministically.
    lea rdi, [oversized_key]
    mov esi, oversized_key_len
    lea rdx, [value_one]
    mov ecx, value_one_len
    call store_set
    cmp eax, -1
    jne .fail

    ; AFK registry builds a namespaced key and returns the exact reason bytes.
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    lea r8, [afk_reason]
    mov r9d, afk_reason_len
    call afk_set
    test eax, eax
    jnz .fail

    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    call afk_lookup
    test rax, rax
    jz .fail
    cmp edx, afk_reason_len
    jne .fail
    lea rsi, [afk_reason]
    mov rdi, rax
    mov edx, afk_reason_len
    call equal_bytes
    test al, al
    jz .fail

    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    call afk_clear
    test eax, eax
    jnz .fail
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    call afk_lookup
    test rax, rax
    jnz .fail

    ; Empty guild identifiers cannot produce a valid AFK key.
    lea rdi, [guild_id]
    xor esi, esi
    lea rdx, [user_id]
    mov ecx, user_id_len
    lea r8, [afk_reason]
    mov r9d, afk_reason_len
    call afk_set
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall

; RDI and RSI buffers, EDX count. AL=1 when equal.
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
store_key: db 'guild-1:prefix'
store_key_len equ $ - store_key
value_one: db 'before'
value_one_len equ $ - value_one
value_two: db 'after'
value_two_len equ $ - value_two
guild_id: db '1001'
guild_id_len equ $ - guild_id
user_id: db '2002'
user_id_len equ $ - user_id
afk_reason: db 'away for dinner'
afk_reason_len equ $ - afk_reason
oversized_key: times 96 db 'k'
oversized_key_len equ $ - oversized_key

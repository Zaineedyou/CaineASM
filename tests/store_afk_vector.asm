BITS 64
DEFAULT REL

extern store_set
extern store_get
extern store_delete
extern store_foreach
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

    ; Iterator exposes only active records through a callback ABI.
    lea rdi, [iterator_key_one]
    mov esi, iterator_key_one_len
    lea rdx, [value_one]
    mov ecx, value_one_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [iterator_key_two]
    mov esi, iterator_key_two_len
    lea rdx, [value_two]
    mov ecx, value_two_len
    call store_set
    test eax, eax
    jnz .fail
    mov dword [iterator_seen], 0
    lea rdi, [iterator_callback]
    xor esi, esi
    call store_foreach
    cmp eax, 2
    jne .fail
    cmp dword [iterator_seen], 2
    jne .fail
    lea rdi, [stop_callback]
    xor esi, esi
    call store_foreach
    cmp eax, 1
    jne .fail
    xor edi, edi
    xor esi, esi
    call store_foreach
    cmp eax, -1
    jne .fail

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

; Iterator callback: RDI=context, RSI=key, EDX=key len, RCX=value, R8D=value len.
iterator_callback:
    mov eax, [iterator_seen]
    test eax, eax
    jz .first
    cmp eax, 1
    je .second
    jmp .bad
.first:
    cmp edx, iterator_key_one_len
    jne .bad
    mov rdi, rsi
    lea rsi, [iterator_key_one]
    mov edx, iterator_key_one_len
    call equal_bytes
    test al, al
    jz .bad
    jmp .ok
.second:
    cmp edx, iterator_key_two_len
    jne .bad
    mov rdi, rsi
    lea rsi, [iterator_key_two]
    mov edx, iterator_key_two_len
    call equal_bytes
    test al, al
    jz .bad
.ok:
    inc dword [iterator_seen]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; Stops successfully after its first observed active entry.
stop_callback:
    mov eax, 1
    ret

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
iterator_key_one: db 'iterator:one'
iterator_key_one_len equ $ - iterator_key_one
iterator_key_two: db 'iterator:two'
iterator_key_two_len equ $ - iterator_key_two
guild_id: db '1001'
guild_id_len equ $ - guild_id
user_id: db '2002'
user_id_len equ $ - user_id
afk_reason: db 'away for dinner'
afk_reason_len equ $ - afk_reason
oversized_key: times 96 db 'k'
oversized_key_len equ $ - oversized_key

section .bss
iterator_seen: resd 1

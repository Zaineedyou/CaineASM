BITS 64
DEFAULT REL

global _start

extern guild_word_add
extern guild_word_remove
extern guild_word_matches
extern guild_channel_disable
extern guild_channel_enable
extern guild_channel_is_disabled
extern guild_channel_list

%define SYS_EXIT 60

section .text
_start:
    mov dword [failure_stage], 1
    ; Banned words are persistent exact-guild policy entries.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [word_bad]
    mov ecx, word_bad_len
    call guild_word_add
    test eax, eax
    jnz .fail
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [word_other]
    mov ecx, word_other_len
    call guild_word_add
    test eax, eax
    jnz .fail

    mov dword [failure_stage], 2
    ; Matching is case-insensitive and does not leak across guilds.
    mov dword [failure_stage], 21
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [matching_text]
    mov ecx, matching_text_len
    call guild_word_matches
    test rax, rax
    jz .fail
    mov dword [failure_stage], 22
    cmp edx, word_bad_len
    jne .fail
    mov dword [failure_stage], 23
    mov rdi, rax
    lea rsi, [word_bad]
    mov edx, word_bad_len
    call equal_bytes_folded
    test al, al
    jz .fail
    mov dword [failure_stage], 24
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [matching_text]
    mov ecx, matching_text_len
    call guild_word_matches
    test rax, rax
    jnz .fail

    mov dword [failure_stage], 3
    ; Removing makes the same word no longer match.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [word_bad]
    mov ecx, word_bad_len
    call guild_word_remove
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [matching_text]
    mov ecx, matching_text_len
    call guild_word_matches
    test rax, rax
    jnz .fail

    mov dword [failure_stage], 4
    ; Disabled-channel state is isolated by both guild and channel.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_one]
    mov ecx, channel_one_len
    call guild_channel_disable
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_one]
    mov ecx, channel_one_len
    call guild_channel_is_disabled
    test al, al
    jz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_two]
    mov ecx, channel_two_len
    call guild_channel_is_disabled
    test al, al
    jnz .fail
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [channel_one]
    mov ecx, channel_one_len
    call guild_channel_is_disabled
    test al, al
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_two]
    mov ecx, channel_two_len
    call guild_channel_disable
    test eax, eax
    jnz .fail
    ; A malformed direct policy write must never be rendered by enumeration.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [bad_channel]
    mov ecx, bad_channel_len
    call guild_channel_disable
    test eax, eax
    jnz .fail
    mov dword [failure_stage], 41
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_list_output]
    mov ecx, 512
    call guild_channel_list
    cmp eax, channel_list_expected_len
    jne .fail
    lea rdi, [channel_list_output]
    lea rsi, [channel_list_expected]
    mov edx, channel_list_expected_len
    call equal_bytes_exact
    test al, al
    jz .fail
    mov dword [failure_stage], 42
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [channel_list_output]
    mov ecx, 512
    call guild_channel_list
    cmp eax, channel_list_empty_len
    jne .fail
    lea rdi, [channel_list_output]
    lea rsi, [channel_list_empty]
    mov edx, channel_list_empty_len
    call equal_bytes_exact
    test al, al
    jz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_one]
    mov ecx, channel_one_len
    call guild_channel_enable
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_two]
    mov ecx, channel_two_len
    call guild_channel_enable
    test eax, eax
    jnz .fail
    mov dword [failure_stage], 43
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [channel_list_output]
    mov ecx, 512
    call guild_channel_list
    cmp eax, channel_list_empty_len
    jne .fail
    lea rdi, [channel_list_output]
    lea rsi, [channel_list_empty]
    mov edx, channel_list_empty_len
    call equal_bytes_exact
    test al, al
    jz .fail

    mov dword [failure_stage], 5
    ; Empty components and an oversized final key fail deterministically.
    lea rdi, [guild_one]
    xor esi, esi
    lea rdx, [word_bad]
    mov ecx, word_bad_len
    call guild_word_add
    cmp eax, -1
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [word_empty]
    xor ecx, ecx
    call guild_word_add
    cmp eax, -1
    jne .fail
    lea rdi, [long_guild]
    mov esi, long_guild_len
    lea rdx, [long_word]
    mov ecx, long_word_len
    call guild_word_add
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    cmp dword [failure_stage], 41
    jne .exit
    mov edi, 1
    lea rsi, [channel_list_output]
    mov edx, 512
    mov eax, 1
    syscall
.exit:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; RDI and RSI buffers, EDX count. AL=1 for ASCII case-insensitive equality.
equal_bytes_folded:
    xor ecx, ecx
.loop:
    cmp ecx, edx
    jae .yes
    mov al, [rdi + rcx]
    call fold_ascii
    mov r8b, al
    mov al, [rsi + rcx]
    call fold_ascii
    cmp al, r8b
    jne .no
    inc ecx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret
; RDI and RSI buffers, EDX=count. AL=1 only for exact byte equality.
equal_bytes_exact:
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

fold_ascii:
    cmp al, 'A'
    jb .out
    cmp al, 'Z'
    ja .out
    add al, 'a' - 'A'
.out:
    ret

section .rodata
guild_one: db 'guild-one'
guild_one_len equ $ - guild_one
guild_two: db 'guild-two'
guild_two_len equ $ - guild_two
word_bad: db 'badword'
word_bad_len equ $ - word_bad
word_other: db 'otherword'
word_other_len equ $ - word_other
word_empty: db ''
matching_text: db 'This BADWORD must match.'
matching_text_len equ $ - matching_text
channel_one: db '111111111111111111'
channel_one_len equ $ - channel_one
channel_two: db '222222222222222222'
channel_two_len equ $ - channel_two
bad_channel: db 'not-a-channel'
bad_channel_len equ $ - bad_channel
channel_list_expected: db '<#111111111111111111>, <#222222222222222222>'
channel_list_expected_len equ $ - channel_list_expected
channel_list_empty: db 'Tidak ada'
channel_list_empty_len equ $ - channel_list_empty
long_guild: times 70 db 'g'
long_guild_len equ $ - long_guild
long_word: times 20 db 'w'
long_word_len equ $ - long_word

section .bss
channel_list_output: resb 512

section .data
failure_stage: dd 0

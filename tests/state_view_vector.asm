BITS 64
DEFAULT REL

global _start

extern store_set
extern state_format_afk_list
extern state_format_leaderboard
extern state_format_banned_words

%define SYS_EXIT 60
%define OUTPUT_CAP 2000

section .text
_start:
    ; AFK view must retain only the exact guild namespace and sanitize control bytes.
    lea rdi, [afk_a_key]
    mov esi, afk_a_key_len
    lea rdx, [afk_a_reason]
    mov ecx, afk_a_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [afk_b_key]
    mov esi, afk_b_key_len
    lea rdx, [afk_b_reason]
    mov ecx, afk_b_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [unrelated_key]
    mov esi, unrelated_key_len
    lea rdx, [unrelated_value]
    mov ecx, unrelated_value_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [guild_a]
    mov esi, guild_a_len
    lea rdx, [output]
    mov ecx, OUTPUT_CAP
    call state_format_afk_list
    cmp eax, afk_expected_len
    jne .fail
    lea rdi, [output]
    lea rsi, [afk_expected]
    mov edx, afk_expected_len
    call equal_bytes
    test al, al
    jz .fail

    ; An unrelated guild gets the explicit empty response.
    lea rdi, [guild_empty]
    mov esi, guild_empty_len
    lea rdx, [output]
    mov ecx, OUTPUT_CAP
    call state_format_afk_list
    cmp eax, afk_empty_expected_len
    jne .fail
    lea rdi, [output]
    lea rsi, [afk_empty_expected]
    mov edx, afk_empty_expected_len
    call equal_bytes
    test al, al
    jz .fail

    ; Word view retains only the exact guild namespace and renders explicit empty output.
    mov dword [failure_stage], 1
    lea rdi, [word_a_key]
    mov esi, word_a_key_len
    lea rdx, [word_present]
    mov ecx, word_present_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [word_b_key]
    mov esi, word_b_key_len
    lea rdx, [word_present]
    mov ecx, word_present_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [guild_a]
    mov esi, guild_a_len
    lea rdx, [output]
    mov ecx, OUTPUT_CAP
    call state_format_banned_words
    mov dword [failure_stage], 2
    cmp eax, words_expected_len
    jne .fail
    mov dword [failure_stage], 3
    lea rdi, [output]
    lea rsi, [words_expected]
    mov edx, words_expected_len
    call equal_bytes
    test al, al
    jz .fail
    lea rdi, [guild_empty]
    mov esi, guild_empty_len
    lea rdx, [output]
    mov ecx, OUTPUT_CAP
    call state_format_banned_words
    mov dword [failure_stage], 4
    cmp eax, words_empty_expected_len
    jne .fail
    mov dword [failure_stage], 5
    lea rdi, [output]
    lea rsi, [words_empty_expected]
    mov edx, words_empty_expected_len
    call equal_bytes
    test al, al
    jz .fail

    ; XP ignores unrelated guilds and malformed/overflow decimal values.
    lea rdi, [xp_zoe_key]
    mov esi, xp_zoe_key_len
    lea rdx, [xp_twenty]
    mov ecx, xp_twenty_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [xp_amy_key]
    mov esi, xp_amy_key_len
    lea rdx, [xp_twenty]
    mov ecx, xp_twenty_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [xp_joe_key]
    mov esi, xp_joe_key_len
    lea rdx, [xp_hundred]
    mov ecx, xp_hundred_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [xp_low_key]
    mov esi, xp_low_key_len
    lea rdx, [xp_three]
    mov ecx, xp_three_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [xp_bad_key]
    mov esi, xp_bad_key_len
    lea rdx, [xp_malformed]
    mov ecx, xp_malformed_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [xp_overflow_key]
    mov esi, xp_overflow_key_len
    lea rdx, [xp_overflow]
    mov ecx, xp_overflow_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [xp_other_guild_key]
    mov esi, xp_other_guild_key_len
    lea rdx, [xp_other_guild_value]
    mov ecx, xp_other_guild_value_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [guild_a]
    mov esi, guild_a_len
    lea rdx, [output]
    mov ecx, OUTPUT_CAP
    call state_format_leaderboard
    cmp eax, leaderboard_expected_len
    jne .fail
    lea rdi, [output]
    lea rsi, [leaderboard_expected]
    mov edx, leaderboard_expected_len
    call equal_bytes
    test al, al
    jz .fail

    ; Empty leaderboard output is explicit and bounded.
    lea rdi, [guild_empty]
    mov esi, guild_empty_len
    lea rdx, [output]
    mov ecx, OUTPUT_CAP
    call state_format_leaderboard
    cmp eax, leaderboard_empty_expected_len
    jne .fail
    lea rdi, [output]
    lea rsi, [leaderboard_empty_expected]
    mov edx, leaderboard_empty_expected_len
    call equal_bytes
    test al, al
    jz .fail

    ; Eighteen long AFK entries force the formatter to stop before Discord's cap.
    lea rdi, [long_afk_key_0]
    mov esi, long_afk_key_0_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_1]
    mov esi, long_afk_key_1_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_2]
    mov esi, long_afk_key_2_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_3]
    mov esi, long_afk_key_3_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_4]
    mov esi, long_afk_key_4_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_5]
    mov esi, long_afk_key_5_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_6]
    mov esi, long_afk_key_6_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_7]
    mov esi, long_afk_key_7_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_8]
    mov esi, long_afk_key_8_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_9]
    mov esi, long_afk_key_9_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_a]
    mov esi, long_afk_key_a_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_b]
    mov esi, long_afk_key_b_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_c]
    mov esi, long_afk_key_c_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_d]
    mov esi, long_afk_key_d_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_e]
    mov esi, long_afk_key_e_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_f]
    mov esi, long_afk_key_f_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_g]
    mov esi, long_afk_key_g_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [long_afk_key_h]
    mov esi, long_afk_key_h_len
    lea rdx, [long_reason]
    mov ecx, long_reason_len
    call store_set
    test eax, eax
    jnz .fail
    lea rdi, [guild_long]
    mov esi, guild_long_len
    lea rdx, [output]
    mov ecx, OUTPUT_CAP
    call state_format_afk_list
    cmp eax, 1851
    jne .fail
    cmp eax, OUTPUT_CAP
    ja .fail
    lea rdi, [output]
    add rdi, rax
    sub rdi, truncated_notice_len
    lea rsi, [truncated_notice]
    mov edx, truncated_notice_len
    call equal_bytes
    test al, al
    jz .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
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
guild_a: db 'guild-a'
guild_a_len equ $ - guild_a
guild_empty: db 'empty'
guild_empty_len equ $ - guild_empty
guild_long: db 'longg'
guild_long_len equ $ - guild_long
afk_a_key: db 'afk:guild-a:user-1'
afk_a_key_len equ $ - afk_a_key
afk_a_reason: db 'away', 10, 'now'
afk_a_reason_len equ $ - afk_a_reason
afk_b_key: db 'afk:guild-b:user-2'
afk_b_key_len equ $ - afk_b_key
afk_b_reason: db 'other server'
afk_b_reason_len equ $ - afk_b_reason
unrelated_key: db 'setting:guild-a'
unrelated_key_len equ $ - unrelated_key
unrelated_value: db 'ignored'
unrelated_value_len equ $ - unrelated_value
word_a_key: db 'word:guild-a:spoiler'
word_a_key_len equ $ - word_a_key
word_b_key: db 'word:guild-b:other'
word_b_key_len equ $ - word_b_key
word_present: db '1'
word_present_len equ $ - word_present
words_expected: db 'Banned words:', 10, '- spoiler', 10
words_expected_len equ $ - words_expected
words_empty_expected: db 'Banned words:', 10, '(none)', 10
words_empty_expected_len equ $ - words_empty_expected
afk_expected: db 'AFK members:', 10, '- user-1: away?now', 10
afk_expected_len equ $ - afk_expected
afk_empty_expected: db 'AFK members:', 10, 'No AFK members in this server.', 10
afk_empty_expected_len equ $ - afk_empty_expected
xp_zoe_key: db 'xp:guild-a:zoe'
xp_zoe_key_len equ $ - xp_zoe_key
xp_amy_key: db 'xp:guild-a:amy'
xp_amy_key_len equ $ - xp_amy_key
xp_joe_key: db 'xp:guild-a:joe'
xp_joe_key_len equ $ - xp_joe_key
xp_low_key: db 'xp:guild-a:low'
xp_low_key_len equ $ - xp_low_key
xp_bad_key: db 'xp:guild-a:bad'
xp_bad_key_len equ $ - xp_bad_key
xp_overflow_key: db 'xp:guild-a:overflow'
xp_overflow_key_len equ $ - xp_overflow_key
xp_other_guild_key: db 'xp:guild-b:outside'
xp_other_guild_key_len equ $ - xp_other_guild_key
xp_twenty: db '20'
xp_twenty_len equ $ - xp_twenty
xp_hundred: db '100'
xp_hundred_len equ $ - xp_hundred
xp_three: db '3'
xp_three_len equ $ - xp_three
xp_malformed: db '12x'
xp_malformed_len equ $ - xp_malformed
xp_overflow: db '4294967296'
xp_overflow_len equ $ - xp_overflow
xp_other_guild_value: db '999'
xp_other_guild_value_len equ $ - xp_other_guild_value
leaderboard_expected: db 'XP leaderboard:', 10, '1. joe - 100 XP', 10, '2. amy - 20 XP', 10, '3. zoe - 20 XP', 10, '4. low - 3 XP', 10
leaderboard_expected_len equ $ - leaderboard_expected
leaderboard_empty_expected: db 'XP leaderboard:', 10, 'No XP scores in this server.', 10
leaderboard_empty_expected_len equ $ - leaderboard_empty_expected
long_afk_key_0: db 'afk:longg:0'
long_afk_key_0_len equ $ - long_afk_key_0
long_afk_key_1: db 'afk:longg:1'
long_afk_key_1_len equ $ - long_afk_key_1
long_afk_key_2: db 'afk:longg:2'
long_afk_key_2_len equ $ - long_afk_key_2
long_afk_key_3: db 'afk:longg:3'
long_afk_key_3_len equ $ - long_afk_key_3
long_afk_key_4: db 'afk:longg:4'
long_afk_key_4_len equ $ - long_afk_key_4
long_afk_key_5: db 'afk:longg:5'
long_afk_key_5_len equ $ - long_afk_key_5
long_afk_key_6: db 'afk:longg:6'
long_afk_key_6_len equ $ - long_afk_key_6
long_afk_key_7: db 'afk:longg:7'
long_afk_key_7_len equ $ - long_afk_key_7
long_afk_key_8: db 'afk:longg:8'
long_afk_key_8_len equ $ - long_afk_key_8
long_afk_key_9: db 'afk:longg:9'
long_afk_key_9_len equ $ - long_afk_key_9
long_afk_key_a: db 'afk:longg:a'
long_afk_key_a_len equ $ - long_afk_key_a
long_afk_key_b: db 'afk:longg:b'
long_afk_key_b_len equ $ - long_afk_key_b
long_afk_key_c: db 'afk:longg:c'
long_afk_key_c_len equ $ - long_afk_key_c
long_afk_key_d: db 'afk:longg:d'
long_afk_key_d_len equ $ - long_afk_key_d
long_afk_key_e: db 'afk:longg:e'
long_afk_key_e_len equ $ - long_afk_key_e
long_afk_key_f: db 'afk:longg:f'
long_afk_key_f_len equ $ - long_afk_key_f
long_afk_key_g: db 'afk:longg:g'
long_afk_key_g_len equ $ - long_afk_key_g
long_afk_key_h: db 'afk:longg:h'
long_afk_key_h_len equ $ - long_afk_key_h
long_reason: times 160 db 'r'
long_reason_len equ $ - long_reason
truncated_notice: db '[truncated]', 10
truncated_notice_len equ $ - truncated_notice

section .data
failure_stage: dd 0

section .bss
output: resb OUTPUT_CAP

BITS 64
DEFAULT REL

extern dispatch_message_create

global _start
global discord_send_text
global groq_chat_once
global afk_set
global xp_increment
global xp_get
global afk_clear
global state_format_afk_list
global state_format_leaderboard
global state_format_banned_words
global guild_auth_is_manager
global guild_word_add
global guild_word_remove
global guild_channel_disable
global guild_channel_enable
global guild_channel_is_disabled
global bot_prefix_ptr
global bot_prefix_len

%define SYS_EXIT 60

section .text
_start:
    mov qword [bot_prefix_ptr], 0
    mov dword [bot_prefix_len], 0
    mov qword [send_calls], 0

    mov dword [failure_stage], 1
    lea rax, [help_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], help_response_len
    lea rdi, [help_event]
    mov esi, help_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 1
    jne .fail
    cmp qword [xp_calls], 0
    jne .fail

    ; Bot-authored events are ignored and must not generate a reply loop.
    mov dword [failure_stage], 2
    lea rdi, [bot_event]
    mov esi, bot_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 1
    jne .fail

    ; A message without the configured/default prefix is ignored.
    mov dword [failure_stage], 3
    lea rdi, [unprefixed_event]
    mov esi, unprefixed_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 1
    jne .fail

    ; Custom prefix applies at dispatch time without recompiling the router.
    mov dword [failure_stage], 4
    lea rax, [custom_prefix]
    mov [bot_prefix_ptr], rax
    mov dword [bot_prefix_len], custom_prefix_len
    lea rax, [status_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], status_response_len
    lea rdi, [status_event]
    mov esi, status_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 2
    jne .fail
    cmp qword [xp_calls], 0
    jne .fail

    ; Summarize forwards only text after the command to the NASM Groq client.
    mov dword [failure_stage], 5
    lea rax, [ai_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], ai_response_len
    lea rdi, [summarize_event]
    mov esi, summarize_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 3
    jne .fail
    cmp qword [groq_calls], 1
    jne .fail
    cmp qword [xp_calls], 0
    jne .fail

    ; AFK receives guild, author, and text after the command as bounded state input.
    mov dword [failure_stage], 6
    lea rax, [afk_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], afk_response_len
    lea rdi, [afk_event]
    mov esi, afk_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 4
    jne .fail
    cmp qword [afk_calls], 1
    jne .fail
    cmp qword [xp_calls], 1
    jne .fail

    ; Rank responds with the current NASM XP total for the message author.
    mov dword [failure_stage], 7
    lea rax, [rank_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], rank_response_len
    lea rdi, [rank_event]
    mov esi, rank_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 5
    jne .fail

    ; AFK list is guild-scoped and dispatch still records the message XP first.
    mov dword [failure_stage], 8
    lea rax, [afklist_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], afklist_response_len
    lea rdi, [afklist_event]
    mov esi, afklist_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 6
    jne .fail
    cmp qword [xp_calls], 3
    jne .fail

    ; Leaderboard is guild-scoped and uses the same bounded view reply seam.
    mov dword [failure_stage], 9
    lea rax, [leaderboard_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], leaderboard_response_len
    lea rdi, [leaderboard_event]
    mov esi, leaderboard_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 7
    jne .fail
    cmp qword [xp_calls], 4
    jne .fail

    ; Owner-gated policy commands mutate bounded state and render words.
    mov dword [failure_stage], 10
    lea rax, [word_added_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], word_added_response_len
    lea rdi, [addword_event]
    mov esi, addword_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 8
    jne .fail
    cmp qword [word_add_calls], 1
    jne .fail
    cmp qword [xp_calls], 5
    jne .fail

    mov dword [failure_stage], 11
    lea rax, [words_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], words_response_len
    lea rdi, [words_event]
    mov esi, words_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 9
    jne .fail

    mov dword [failure_stage], 12
    lea rax, [channel_disabled_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], channel_disabled_response_len
    lea rdi, [disable_event]
    mov esi, disable_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 10
    jne .fail
    cmp qword [channel_disable_calls], 1
    jne .fail

    mov dword [failure_stage], 13
    lea rax, [channel_enabled_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], channel_enabled_response_len
    lea rdi, [enable_event]
    mov esi, enable_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 11
    jne .fail
    cmp qword [channel_enable_calls], 1
    jne .fail

    ; Unknown command gets the bounded default help response.
    mov dword [failure_stage], 14
    lea rax, [unknown_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], unknown_response_len
    lea rdi, [unknown_event]
    mov esi, unknown_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 12
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; RDI=prompt, ESI=length, RDX=reply destination, ECX=capacity.
groq_chat_once:
    mov r10, rdx
    mov r11d, ecx
    cmp esi, groq_prompt_len
    jne .bad
    lea r8, [groq_prompt]
    mov r9d, esi
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    cmp r11d, ai_response_len + 1
    jb .bad
    mov rdi, r10
    lea rsi, [ai_response]
    mov edx, ai_response_len
    call copy_bytes
    inc qword [groq_calls]
    mov eax, ai_response_len
    ret
.bad:
    mov eax, -1
    ret

; RDI=guild, ESI=guild length, RDX=user, ECX=user length. EAX=current score.
xp_get:
    mov eax, 42
    ret

afk_clear:
    xor eax, eax
    ret

; Owner seam allows the test fixture's guild owner through the safe temporary gate.
guild_auth_is_manager:
    mov al, 1
    ret

guild_word_add:
    inc qword [word_add_calls]
    xor eax, eax
    ret
guild_word_remove:
    inc qword [word_remove_calls]
    xor eax, eax
    ret
guild_channel_disable:
    inc qword [channel_disable_calls]
    xor eax, eax
    ret
guild_channel_enable:
    inc qword [channel_enable_calls]
    xor eax, eax
    ret
guild_channel_is_disabled:
    xor eax, eax
    ret

; Formatter seams verify dispatch's guild and exact Discord-capacity contract.
; RDI=guild, ESI=guild len, RDX=output, ECX=capacity.
state_format_afk_list:
    push rbx
    mov rbx, rdx
    cmp esi, guild_id_len
    jne .bad
    cmp ecx, 2000
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    mov rdi, rbx
    lea rsi, [afklist_response]
    mov edx, afklist_response_len
    call copy_bytes
    mov eax, afklist_response_len
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

state_format_banned_words:
    push rbx
    mov rbx, rdx
    cmp esi, guild_id_len
    jne .bad
    cmp ecx, 2000
    jne .bad
    mov rdi, rbx
    lea rsi, [words_response]
    mov edx, words_response_len
    call copy_bytes
    mov eax, words_response_len
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

state_format_leaderboard:
    push rbx
    mov rbx, rdx
    cmp esi, guild_id_len
    jne .bad
    cmp ecx, 2000
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    mov rdi, rbx
    lea rsi, [leaderboard_response]
    mov edx, leaderboard_response_len
    call copy_bytes
    mov eax, leaderboard_response_len
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

; RDI=guild, ESI=guild length, RDX=user, ECX=user length. EAX=volatile total.
xp_increment:
    mov r11, rdx
    cmp esi, guild_id_len
    jne .bad
    cmp ecx, author_id_len
    jne .bad
    lea r8, [guild_id]
    mov r9d, esi
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    mov rdi, r11
    lea rsi, [author_id]
    mov edx, author_id_len
    call equal_bytes
    test al, al
    jz .bad
    inc qword [xp_calls]
    mov eax, 1
    ret
.bad:
    mov eax, -1
    ret

; RDI=guild, ESI=guild length, RDX=user, ECX=user length, R8=reason, R9D=reason length.
afk_set:
    push rbx
    mov rbx, r8
    mov r10d, ecx
    mov r11, rdx
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r10d, author_id_len
    jne .bad
    mov rdi, r11
    lea rsi, [author_id]
    mov edx, author_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r9d, afk_reason_len
    jne .bad
    mov rdi, rbx
    lea rsi, [afk_reason]
    mov edx, afk_reason_len
    call equal_bytes
    test al, al
    jz .bad
    inc qword [afk_calls]
    xor eax, eax
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

; NASM test seam for dispatcher. RDI=channel, ESI=channel len, RDX=text, ECX=text len.
discord_send_text:
    mov r10d, ecx
    mov r11, rdx
    cmp esi, channel_id_len
    jne .bad
    lea r8, [channel_id]
    mov r9d, esi
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    cmp r10d, [expected_text_len]
    jne .bad
    mov rdi, r11
    mov rsi, [expected_text_ptr]
    mov edx, r10d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [send_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=destination, RSI=source, EDX=count.
copy_bytes:
    xor ecx, ecx
.copy_loop:
    cmp ecx, edx
    jae .copy_done
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    inc ecx
    jmp .copy_loop
.copy_done:
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
channel_id: db '123456789012345678'
channel_id_len equ $ - channel_id
custom_prefix: db '^'
custom_prefix_len equ $ - custom_prefix
help_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"!help","author":{"bot":false}}}'
help_event_len equ $ - help_event
bot_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"!help","author":{"bot":true}}}'
bot_event_len equ $ - bot_event
unprefixed_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"help","author":{"bot":false}}}'
unprefixed_event_len equ $ - unprefixed_event
status_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"^status","author":{"bot":false}}}'
status_event_len equ $ - status_event
rank_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^rank","author":{"id":"user-2","bot":false}}}'
rank_event_len equ $ - rank_event
afk_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^afk dinner","author":{"id":"user-2","bot":false}}}'
afk_event_len equ $ - afk_event
afklist_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^afklist","author":{"id":"user-2","bot":false}}}'
afklist_event_len equ $ - afklist_event
leaderboard_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^leaderboard","author":{"id":"user-2","bot":false}}}'
leaderboard_event_len equ $ - leaderboard_event
guild_id: db 'guild-1'
guild_id_len equ $ - guild_id
author_id: db 'user-2'
author_id_len equ $ - author_id
afk_reason: db 'dinner'
afk_reason_len equ $ - afk_reason
afk_response: db 'AFK status saved for this server.'
afk_response_len equ $ - afk_response
summarize_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"^summarize brief this","author":{"bot":false}}}'
summarize_event_len equ $ - summarize_event
groq_prompt: db 'brief this'
groq_prompt_len equ $ - groq_prompt
ai_response: db 'AI summary'
ai_response_len equ $ - ai_response
unknown_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"^nonesuch","author":{"bot":false}}}'
unknown_event_len equ $ - unknown_event
addword_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^addword BaD","author":{"id":"user-2","bot":false}}}'
addword_event_len equ $ - addword_event
words_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^words","author":{"id":"user-2","bot":false}}}'
words_event_len equ $ - words_event
disable_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^disable","author":{"id":"user-2","bot":false}}}'
disable_event_len equ $ - disable_event
enable_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^enable","author":{"id":"user-2","bot":false}}}'
enable_event_len equ $ - enable_event
help_response: db 'CaineASM commands: help, status, reset, afk, afklist, rank, leaderboard, summarize, and moderation/config commands.'
help_response_len equ $ - help_response
status_response: db 'CaineASM is online. Gateway and REST command handling are active.'
status_response_len equ $ - status_response
rank_response: db 'Your XP: 42'
rank_response_len equ $ - rank_response
afklist_response: db 'AFK members:', 10, '- user-2: dinner', 10
afklist_response_len equ $ - afklist_response
leaderboard_response: db 'XP leaderboard:', 10, '1. user-2 - 3 XP', 10
leaderboard_response_len equ $ - leaderboard_response
registered_notice: db 'That command is registered, but its handler is not active in this checkpoint.'
registered_notice_len equ $ - registered_notice
words_response: db 'Banned words:', 10, '- bad', 10
words_response_len equ $ - words_response
word_added_response: db 'Banned word added.'
word_added_response_len equ $ - word_added_response
channel_enabled_response: db 'Bot enabled in this channel.'
channel_enabled_response_len equ $ - channel_enabled_response
channel_disabled_response: db 'Bot disabled in this channel.'
channel_disabled_response_len equ $ - channel_disabled_response
unknown_response: db 'Unknown command. Use !help.'
unknown_response_len equ $ - unknown_response

section .data
bot_prefix_ptr: dq 0
bot_prefix_len: dd 0
expected_text_ptr: dq 0
expected_text_len: dd 0
send_calls: dq 0
groq_calls: dq 0
afk_calls: dq 0
xp_calls: dq 0
word_add_calls: dq 0
word_remove_calls: dq 0
channel_disable_calls: dq 0
channel_enable_calls: dq 0
failure_stage: dd 0

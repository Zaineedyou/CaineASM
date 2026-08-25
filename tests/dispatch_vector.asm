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

    ; Unknown command gets the bounded default help response.
    mov dword [failure_stage], 8
    lea rax, [unknown_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], unknown_response_len
    lea rdi, [unknown_event]
    mov esi, unknown_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 6
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
help_response: db 'CaineASM commands: help, status, reset, afk, afklist, rank, leaderboard, summarize, and moderation/config commands.'
help_response_len equ $ - help_response
status_response: db 'CaineASM is online. Gateway and REST command handling are active.'
status_response_len equ $ - status_response
rank_response: db 'Your XP: 42'
rank_response_len equ $ - rank_response
registered_notice: db 'That command is registered, but its handler is not active in this checkpoint.'
registered_notice_len equ $ - registered_notice
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
failure_stage: dd 0

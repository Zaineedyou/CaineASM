BITS 64
DEFAULT REL

global dispatch_message_create

extern json_find_key
extern json_read_string
extern json_value_is_true
extern command_classify
extern discord_send_text
extern bot_prefix_ptr
extern bot_prefix_len

%define MESSAGE_CONTENT_CAP 2048
%define CHANNEL_ID_CAP 64
%define COMMAND_CAP 64

%define CMD_HELP   1
%define CMD_RESET  2
%define CMD_STATUS 7

; RDI=Gateway MESSAGE_CREATE JSON, RSI=length.
; EAX=0 for ignored/handled message, -1 only when the outbound REST operation fails.
; This checkpoint handles text prefix commands. Interactions, moderation, AI, and
; durable state are kept in later modules rather than being silently simulated.
section .text
dispatch_message_create:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                     ; complete frame JSON
    mov r13, rsi                     ; complete frame length

    ; Ignore authored-by-bot events to prevent reply loops.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_bot]
    mov ecx, key_bot_len
    call json_find_key
    test rax, rax
    jz .channel
    mov rdi, rax
    lea rsi, [r12 + r13]
    call json_value_is_true
    test al, al
    jnz .handled

.channel:
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_channel_id]
    mov ecx, key_channel_id_len
    call json_find_key
    test rax, rax
    jz .handled
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [channel_id]
    mov ecx, CHANNEL_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .handled
    mov r14d, eax
    mov byte [channel_id + r14], 0

.content:
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_content]
    mov ecx, key_content_len
    call json_find_key
    test rax, rax
    jz .handled
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [message_content]
    mov ecx, MESSAGE_CONTENT_CAP - 1
    call json_read_string
    test eax, eax
    jle .handled
    mov r15d, eax

    lea rdi, [message_content]
    mov esi, r15d
    call command_offset_after_prefix
    test eax, eax
    js .handled
    mov ebx, eax                     ; offset after prefix
    cmp ebx, r15d
    jae .handled

.skip_spaces:
    cmp ebx, r15d
    jae .handled
    mov al, [message_content + rbx]
    cmp al, ' '
    je .space_advance
    cmp al, 9
    je .space_advance
    jmp .command
.space_advance:
    inc ebx
    jmp .skip_spaces

.command:
    xor ecx, ecx
.copy_command:
    lea eax, [ebx + ecx]
    cmp eax, r15d
    jae .classify
    cmp ecx, COMMAND_CAP - 1
    jae .handled
    mov al, [message_content + rbx + rcx]
    cmp al, ' '
    je .classify
    cmp al, 9
    je .classify
    cmp al, 10
    je .classify
    cmp al, 13
    je .classify
    cmp al, 'A'
    jb .store_command
    cmp al, 'Z'
    ja .store_command
    add al, 'a' - 'A'
.store_command:
    mov [command_buffer + rcx], al
    inc ecx
    jmp .copy_command
.classify:
    test ecx, ecx
    jz .handled
    lea rdi, [command_buffer]
    mov esi, ecx
    call command_classify
    cmp eax, CMD_HELP
    je .help
    cmp eax, CMD_STATUS
    je .status
    cmp eax, CMD_RESET
    je .reset
    test eax, eax
    jz .unknown
    lea rdi, [registered_notice]
    mov esi, registered_notice_len
    jmp .reply
.help:
    lea rdi, [help_response]
    mov esi, help_response_len
    jmp .reply
.status:
    lea rdi, [status_response]
    mov esi, status_response_len
    jmp .reply
.reset:
    lea rdi, [reset_response]
    mov esi, reset_response_len
    jmp .reply
.unknown:
    lea rdi, [unknown_response]
    mov esi, unknown_response_len
.reply:
    mov rdx, rdi
    mov ecx, esi
    lea rdi, [channel_id]
    mov esi, r14d
    call discord_send_text
    jmp .out
.handled:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=content, ESI=content length. EAX=command byte offset, -1 if no valid prefix.
command_offset_after_prefix:
    cmp dword [bot_prefix_len], 0
    je .default_prefix
    mov r8, [bot_prefix_ptr]
    mov r9d, [bot_prefix_len]
    test r8, r8
    jz .bad
    cmp r9d, esi
    ja .bad
    xor edx, edx
.custom_loop:
    cmp edx, r9d
    jae .custom_ok
    mov al, [rdi + rdx]
    cmp al, [r8 + rdx]
    jne .bad
    inc edx
    jmp .custom_loop
.custom_ok:
    mov eax, r9d
    ret
.default_prefix:
    test esi, esi
    jz .bad
    cmp byte [rdi], '!'
    jne .bad
    mov eax, 1
    ret
.bad:
    mov eax, -1
    ret

section .rodata
key_bot: db 'bot'
key_bot_len equ $ - key_bot
key_channel_id: db 'channel_id'
key_channel_id_len equ $ - key_channel_id
key_content: db 'content'
key_content_len equ $ - key_content
help_response: db 'CaineASM commands: help, status, reset, afk, afklist, rank, leaderboard, summarize, and moderation/config commands.'
help_response_len equ $ - help_response
status_response: db 'CaineASM is online. Gateway and REST command handling are active.'
status_response_len equ $ - status_response
reset_response: db 'Reset is reserved for the persistence module; current state is volatile.'
reset_response_len equ $ - reset_response
registered_notice: db 'That command is registered, but its handler is not active in this checkpoint.'
registered_notice_len equ $ - registered_notice
unknown_response: db 'Unknown command. Use !help.'
unknown_response_len equ $ - unknown_response

section .bss
channel_id: resb CHANNEL_ID_CAP
message_content: resb MESSAGE_CONTENT_CAP
command_buffer: resb COMMAND_CAP

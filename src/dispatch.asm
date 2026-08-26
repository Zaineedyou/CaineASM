BITS 64
DEFAULT REL

global dispatch_message_create

extern json_find_key
extern json_read_string
extern json_value_is_true
extern json_object_end
extern command_classify
extern discord_send_text
extern groq_chat_once
extern afk_set
extern afk_clear
extern xp_increment
extern xp_get
extern state_format_afk_list
extern state_format_leaderboard
extern state_format_banned_words
extern guild_auth_is_owner
extern guild_word_add
extern guild_word_remove
extern guild_channel_disable
extern guild_channel_enable
extern bot_prefix_ptr
extern bot_prefix_len

%define MESSAGE_CONTENT_CAP 2048
%define CHANNEL_ID_CAP 64
%define GUILD_ID_CAP 64
%define AUTHOR_ID_CAP 64
%define COMMAND_CAP 64
%define AI_REPLY_CAP 1901
%define STATE_VIEW_REPLY_CAP 2000

%define CMD_HELP   1
%define CMD_RESET  2
%define CMD_AFK    3
%define CMD_AFKLIST 4
%define CMD_RANK   5
%define CMD_LEADERBOARD 6
%define CMD_STATUS 7
%define CMD_SUMMARIZE 8
%define CMD_ADDWORD 17
%define CMD_REMOVEWORD 18
%define CMD_WORDS 19
%define CMD_ENABLE 20
%define CMD_DISABLE 21

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

    ; Guild/user identity is optional for generic commands but required by AFK state.
    mov dword [guild_id_len], 0
    mov dword [author_id_len], 0
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_guild_id]
    mov ecx, key_guild_id_len
    call json_find_key
    test rax, rax
    jz .author
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [guild_id]
    mov ecx, GUILD_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .author
    mov [guild_id_len], eax
    mov byte [guild_id + rax], 0
.author:
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_author]
    mov ecx, key_author_len
    call json_find_key
    test rax, rax
    jz .content
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .content
    mov r9, rax
    mov rdi, rbx
    mov rsi, r9
    sub rsi, rbx
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .content
    mov rdi, rax
    mov rsi, r9
    lea rdx, [author_id]
    mov ecx, AUTHOR_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .content
    mov [author_id_len], eax
    mov byte [author_id + rax], 0
    cmp dword [guild_id_len], 0
    je .content
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [author_id]
    mov ecx, [author_id_len]
    call xp_increment
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [author_id]
    mov ecx, [author_id_len]
    call afk_clear

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
    add ebx, ecx                     ; first byte after command token
    lea rdi, [command_buffer]
    mov esi, ecx
    call command_classify
    cmp eax, CMD_HELP
    je .help
    cmp eax, CMD_AFK
    je .afk
    cmp eax, CMD_AFKLIST
    je .afklist
    cmp eax, CMD_RANK
    je .rank
    cmp eax, CMD_LEADERBOARD
    je .leaderboard
    cmp eax, CMD_STATUS
    je .status
    cmp eax, CMD_RESET
    je .reset
    cmp eax, CMD_SUMMARIZE
    je .summarize
    cmp eax, CMD_ADDWORD
    je .addword
    cmp eax, CMD_REMOVEWORD
    je .removeword
    cmp eax, CMD_WORDS
    je .words
    cmp eax, CMD_ENABLE
    je .enable
    cmp eax, CMD_DISABLE
    je .disable
    test eax, eax
    jz .unknown
    lea rdi, [registered_notice]
    mov esi, registered_notice_len
    jmp .reply
.help:
    lea rdi, [help_response]
    mov esi, help_response_len
    jmp .reply
.afk:
    cmp dword [guild_id_len], 0
    je .afk_unavailable
    cmp dword [author_id_len], 0
    je .afk_unavailable
.afk_skip_reason_spaces:
    cmp ebx, r15d
    jae .afk_default_reason
    mov al, [message_content + rbx]
    cmp al, ' '
    je .afk_reason_space_advance
    cmp al, 9
    je .afk_reason_space_advance
    jmp .afk_set
.afk_reason_space_advance:
    inc ebx
    jmp .afk_skip_reason_spaces
.afk_set:
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [author_id]
    mov ecx, [author_id_len]
    lea r8, [message_content + rbx]
    mov r9d, r15d
    sub r9d, ebx
    call afk_set
    test eax, eax
    jnz .afk_error
    lea rdi, [afk_response]
    mov esi, afk_response_len
    jmp .reply
.afk_default_reason:
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [author_id]
    mov ecx, [author_id_len]
    lea r8, [default_afk_reason]
    mov r9d, default_afk_reason_len
    call afk_set
    test eax, eax
    jnz .afk_error
    lea rdi, [afk_response]
    mov esi, afk_response_len
    jmp .reply
.afklist:
    cmp dword [guild_id_len], 0
    je .state_view_unavailable
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [state_view_reply]
    mov ecx, STATE_VIEW_REPLY_CAP
    call state_format_afk_list
    test eax, eax
    jle .state_view_error
    mov esi, eax
    lea rdi, [state_view_reply]
    jmp .reply
.rank:
    cmp dword [guild_id_len], 0
    je .rank_unavailable
    cmp dword [author_id_len], 0
    je .rank_unavailable
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [author_id]
    mov ecx, [author_id_len]
    call xp_get
    mov [rank_score], eax
    lea rdi, [rank_response]
    lea rsi, [rank_prefix]
    mov edx, rank_prefix_len
    call copy_bytes
    lea rdi, [rank_response + rank_prefix_len]
    mov eax, [rank_score]
    call format_uint32
    test eax, eax
    jle .rank_unavailable
    add eax, rank_prefix_len
    mov esi, eax
    lea rdi, [rank_response]
    jmp .reply
.leaderboard:
    cmp dword [guild_id_len], 0
    je .state_view_unavailable
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [state_view_reply]
    mov ecx, STATE_VIEW_REPLY_CAP
    call state_format_leaderboard
    test eax, eax
    jle .state_view_error
    mov esi, eax
    lea rdi, [state_view_reply]
    jmp .reply
.addword:
    mov dword [policy_command_op], 1
    jmp .word_mutation
.removeword:
    mov dword [policy_command_op], 2
.word_mutation:
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
.word_skip_spaces:
    cmp ebx, r15d
    jae .word_usage
    mov al, [message_content + rbx]
    cmp al, ' '
    je .word_space_advance
    cmp al, 9
    je .word_space_advance
    jmp .word_copy_start
.word_space_advance:
    inc ebx
    jmp .word_skip_spaces
.word_copy_start:
    xor ecx, ecx
.word_copy:
    lea eax, [ebx + ecx]
    cmp eax, r15d
    jae .word_ready
    cmp ecx, COMMAND_CAP - 1
    jae .word_usage
    mov al, [message_content + rbx + rcx]
    cmp al, ' '
    je .word_ready
    cmp al, 9
    je .word_ready
    cmp al, 10
    je .word_ready
    cmp al, 13
    je .word_ready
    cmp al, 'A'
    jb .word_store
    cmp al, 'Z'
    ja .word_store
    add al, 'a' - 'A'
.word_store:
    mov [argument_buffer + rcx], al
    inc ecx
    jmp .word_copy
.word_ready:
    test ecx, ecx
    jz .word_usage
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [argument_buffer]
    cmp dword [policy_command_op], 1
    jne .remove_word
    call guild_word_add
    jmp .word_result
.remove_word:
    call guild_word_remove
.word_result:
    test eax, eax
    jnz .policy_error
    cmp dword [policy_command_op], 1
    jne .word_removed
    lea rdi, [word_added_response]
    mov esi, word_added_response_len
    jmp .reply
.word_removed:
    lea rdi, [word_removed_response]
    mov esi, word_removed_response_len
    jmp .reply
.word_usage:
    lea rdi, [word_usage_response]
    mov esi, word_usage_response_len
    jmp .reply
.words:
    cmp dword [guild_id_len], 0
    je .state_view_unavailable
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [state_view_reply]
    mov ecx, STATE_VIEW_REPLY_CAP
    call state_format_banned_words
    test eax, eax
    jle .state_view_error
    mov esi, eax
    lea rdi, [state_view_reply]
    jmp .reply
.enable:
    mov dword [policy_command_op], 3
    jmp .channel_policy
.disable:
    mov dword [policy_command_op], 4
.channel_policy:
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [channel_id]
    mov ecx, r14d
    cmp dword [policy_command_op], 3
    jne .disable_channel
    call guild_channel_enable
    jmp .channel_result
.disable_channel:
    call guild_channel_disable
.channel_result:
    test eax, eax
    jnz .policy_error
    cmp dword [policy_command_op], 3
    jne .channel_disabled
    lea rdi, [channel_enabled_response]
    mov esi, channel_enabled_response_len
    jmp .reply
.channel_disabled:
    lea rdi, [channel_disabled_response]
    mov esi, channel_disabled_response_len
    jmp .reply
.admin_denied:
    lea rdi, [admin_denied_response]
    mov esi, admin_denied_response_len
    jmp .reply
.policy_error:
    lea rdi, [policy_error_response]
    mov esi, policy_error_response_len
    jmp .reply
.rank_unavailable:
    lea rdi, [rank_unavailable_response]
    mov esi, rank_unavailable_response_len
    jmp .reply
.state_view_unavailable:
    lea rdi, [state_view_unavailable_response]
    mov esi, state_view_unavailable_response_len
    jmp .reply
.state_view_error:
    lea rdi, [state_view_error_response]
    mov esi, state_view_error_response_len
    jmp .reply
.afk_unavailable:
    lea rdi, [afk_unavailable_response]
    mov esi, afk_unavailable_response_len
    jmp .reply
.afk_error:
    lea rdi, [afk_error_response]
    mov esi, afk_error_response_len
    jmp .reply
.status:
    lea rdi, [status_response]
    mov esi, status_response_len
    jmp .reply
.reset:
    lea rdi, [reset_response]
    mov esi, reset_response_len
    jmp .reply
.summarize:
.skip_prompt_spaces:
    cmp ebx, r15d
    jae .summarize_usage
    mov al, [message_content + rbx]
    cmp al, ' '
    je .prompt_space_advance
    cmp al, 9
    je .prompt_space_advance
    jmp .ask_groq
.prompt_space_advance:
    inc ebx
    jmp .skip_prompt_spaces
.ask_groq:
    lea rdi, [message_content + rbx]
    mov esi, r15d
    sub esi, ebx
    lea rdx, [ai_reply]
    mov ecx, AI_REPLY_CAP
    call groq_chat_once
    test eax, eax
    jle .ai_error
    lea rdi, [ai_reply]
    mov esi, eax
    jmp .reply
.summarize_usage:
    lea rdi, [summarize_usage_response]
    mov esi, summarize_usage_response_len
    jmp .reply
.ai_error:
    lea rdi, [ai_error_response]
    mov esi, ai_error_response_len
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

; AL=1 only for a cached server owner in a guild context. This is deliberately
; fail-closed until channel-overwrite authorization is connected for non-owner admins.
dispatch_owner_authorized:
    cmp dword [guild_id_len], 0
    je .no
    cmp dword [author_id_len], 0
    je .no
    sub rsp, 8
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [author_id]
    mov ecx, [author_id_len]
    call guild_auth_is_owner
    add rsp, 8
    ret
.no:
    xor eax, eax
    ret

; RDI=content, ESI=content length. EAX=command byte offset, -1 if no valid prefix.
; RDI=destination, EAX=value. EAX=decimal length.
format_uint32:
    lea r8, [rank_scratch + 10]
    xor ecx, ecx
    test eax, eax
    jnz .digits
    mov byte [rdi], '0'
    mov eax, 1
    ret
.digits:
    mov r9d, 10
.loop:
    xor edx, edx
    div r9d
    add dl, '0'
    dec r8
    mov [r8], dl
    inc ecx
    test eax, eax
    jnz .loop
    xor edx, edx
.copy:
    cmp edx, ecx
    jae .done
    mov al, [r8 + rdx]
    mov [rdi + rdx], al
    inc edx
    jmp .copy
.done:
    mov eax, ecx
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
key_guild_id: db 'guild_id'
key_guild_id_len equ $ - key_guild_id
key_author: db 'author'
key_author_len equ $ - key_author
key_id: db 'id'
key_id_len equ $ - key_id
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
word_usage_response: db 'Usage: addword/removeword <word>.'
word_usage_response_len equ $ - word_usage_response
word_added_response: db 'Banned word added.'
word_added_response_len equ $ - word_added_response
word_removed_response: db 'Banned word removed.'
word_removed_response_len equ $ - word_removed_response
channel_enabled_response: db 'Bot enabled in this channel.'
channel_enabled_response_len equ $ - channel_enabled_response
channel_disabled_response: db 'Bot disabled in this channel.'
channel_disabled_response_len equ $ - channel_disabled_response
admin_denied_response: db 'Admin verification unavailable or denied.'
admin_denied_response_len equ $ - admin_denied_response
policy_error_response: db 'Policy state could not be saved.'
policy_error_response_len equ $ - policy_error_response
unknown_response: db 'Unknown command. Use !help.'
unknown_response_len equ $ - unknown_response
summarize_usage_response: db 'Usage: !summarize <text>'
summarize_usage_response_len equ $ - summarize_usage_response
ai_error_response: db 'AI request failed. Please try again shortly.'
ai_error_response_len equ $ - ai_error_response
afk_response: db 'AFK status saved for this server.'
afk_response_len equ $ - afk_response
afk_unavailable_response: db 'AFK is available only for messages sent in a server.'
afk_unavailable_response_len equ $ - afk_unavailable_response
afk_error_response: db 'AFK status could not be saved.'
afk_error_response_len equ $ - afk_error_response
rank_prefix: db 'Your XP: '
rank_prefix_len equ $ - rank_prefix
rank_unavailable_response: db 'Rank is available only for messages sent in a server.'
rank_unavailable_response_len equ $ - rank_unavailable_response
state_view_unavailable_response: db 'This command is available only for messages sent in a server.'
state_view_unavailable_response_len equ $ - state_view_unavailable_response
state_view_error_response: db 'State view could not be rendered.'
state_view_error_response_len equ $ - state_view_error_response
default_afk_reason: db 'AFK'
default_afk_reason_len equ $ - default_afk_reason

section .bss
channel_id: resb CHANNEL_ID_CAP
guild_id: resb GUILD_ID_CAP
author_id: resb AUTHOR_ID_CAP
argument_buffer: resb COMMAND_CAP
guild_id_len: resd 1
author_id_len: resd 1
rank_score: resd 1
policy_command_op: resd 1
rank_response: resb 32
rank_scratch: resb 10
message_content: resb MESSAGE_CONTENT_CAP
command_buffer: resb COMMAND_CAP
ai_reply: resb AI_REPLY_CAP
state_view_reply: resb STATE_VIEW_REPLY_CAP

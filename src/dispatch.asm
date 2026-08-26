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
extern groq_select_guild
extern afk_set
extern afk_clear
extern xp_increment
extern xp_get
extern state_format_afk_list
extern state_format_leaderboard
extern state_format_banned_words
extern guild_auth_is_manager
extern guild_word_add
extern guild_word_remove
extern guild_channel_disable
extern guild_channel_enable
extern guild_channel_is_disabled
extern guild_config_set
extern guild_config_delete
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
%define CMD_SETPERSONA 22
%define CMD_SETMODEL 23
%define CMD_SETHISTORY 24
%define CMD_AUTOROLE 25
%define CMD_SETWELCOME 26
%define CMD_SETGOODBYE 27
%define CMD_REMOVEAUTOROLE 28
%define CMD_SETLEVELCHANNEL 29
%define CMD_SETLOG 30
%define CMD_SETWELCOMEMSG 31
%define CMD_SETGOODBYEMSG 32

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

    ; Disabled channels still reach prior message-state bookkeeping, but no
    ; command/AI routing is allowed, matching the source event order.
    cmp dword [guild_id_len], 0
    je .routing_enabled
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [channel_id]
    mov ecx, r14d
    call guild_channel_is_disabled
    test al, al
    jnz .handled
.routing_enabled:
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
    cmp eax, CMD_SETPERSONA
    je .setpersona
    cmp eax, CMD_SETMODEL
    je .setmodel
    cmp eax, CMD_SETHISTORY
    je .sethistory
    cmp eax, CMD_AUTOROLE
    je .autorole
    cmp eax, CMD_REMOVEAUTOROLE
    je .removeautorole
    cmp eax, CMD_SETWELCOME
    je .setwelcome
    cmp eax, CMD_SETGOODBYE
    je .setgoodbye
    cmp eax, CMD_SETLEVELCHANNEL
    je .setlevelchannel
    cmp eax, CMD_SETLOG
    je .setlog
    cmp eax, CMD_SETWELCOMEMSG
    je .setwelcomemsg
    cmp eax, CMD_SETGOODBYEMSG
    je .setgoodbyemsg
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
.setpersona:
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .persona_usage
    lea rdi, [setting_persona]
    mov edx, esi
    mov r8, rdi
    mov r9d, edx
    lea rdi, [setting_persona]
    mov esi, setting_persona_len
    ; tail pointer/length returned in RDI/ESI are preserved in temporary state.
    mov rdx, [dispatch_tail_ptr]
    mov ecx, [dispatch_tail_len]
    call dispatch_store_config
    test eax, eax
    jnz .policy_error
    lea rdi, [persona_saved_response]
    mov esi, persona_saved_response_len
    jmp .reply
.persona_usage:
    lea rdi, [persona_usage_response]
    mov esi, persona_usage_response_len
    jmp .reply
.setmodel:
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .model_usage
    call dispatch_copy_first_lower
    test eax, eax
    jle .model_usage
    lea rdi, [argument_buffer]
    mov esi, eax
    call dispatch_model_alias
    test rax, rax
    jz .model_usage
    mov [dispatch_model_ptr], rax
    mov [dispatch_model_len], edx
    lea rdi, [setting_model]
    mov esi, setting_model_len
    mov rdx, [dispatch_model_ptr]
    mov ecx, [dispatch_model_len]
    call dispatch_store_config
    test eax, eax
    jnz .policy_error
    lea rdi, [model_saved_response]
    mov esi, model_saved_response_len
    jmp .reply
.model_usage:
    lea rdi, [model_usage_response]
    mov esi, model_usage_response_len
    jmp .reply
.sethistory:
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .history_usage
    mov rdi, rdi
    call dispatch_parse_history_limit
    jc .history_usage
    lea rdi, [setting_history]
    mov esi, setting_history_len
    mov rdx, [dispatch_tail_ptr]
    mov ecx, [dispatch_tail_len]
    call dispatch_store_config
    test eax, eax
    jnz .policy_error
    lea rdi, [history_saved_response]
    mov esi, history_saved_response_len
    jmp .reply
.history_usage:
    lea rdi, [history_usage_response]
    mov esi, history_usage_response_len
    jmp .reply
.autorole:
    lea rdi, [setting_autorole]
    mov esi, setting_autorole_len
    lea rdx, [role_saved_response]
    mov ecx, role_saved_response_len
    jmp .config_role
.removeautorole:
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [setting_autorole]
    mov ecx, setting_autorole_len
    call guild_config_delete
    test eax, eax
    jnz .policy_error
    lea rdi, [role_removed_response]
    mov esi, role_removed_response_len
    jmp .reply
.setwelcome:
    lea rdi, [setting_welcome_channel]
    mov esi, setting_welcome_channel_len
    lea rdx, [channel_saved_response]
    mov ecx, channel_saved_response_len
    jmp .config_channel
.setgoodbye:
    lea rdi, [setting_goodbye_channel]
    mov esi, setting_goodbye_channel_len
    lea rdx, [channel_saved_response]
    mov ecx, channel_saved_response_len
    jmp .config_channel
.setlevelchannel:
    lea rdi, [setting_level_channel]
    mov esi, setting_level_channel_len
    lea rdx, [channel_saved_response]
    mov ecx, channel_saved_response_len
    jmp .config_channel
.setlog:
    lea rdi, [setting_log_channel]
    mov esi, setting_log_channel_len
    lea rdx, [channel_saved_response]
    mov ecx, channel_saved_response_len
    jmp .config_channel
.config_channel:
    mov [config_setting_ptr], rdi
    mov [config_setting_len], esi
    mov [config_success_ptr], rdx
    mov [config_success_len], ecx
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .channel_usage
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '#'
    call dispatch_extract_mention_id
    test eax, eax
    jle .channel_usage
    mov [config_value_len], eax
    lea rdi, [config_value]
    mov esi, eax
    mov rdx, [config_setting_ptr]
    mov ecx, [config_setting_len]
    xchg rdi, rdx
    xchg esi, ecx
    lea rdx, [config_value]
    mov ecx, [config_value_len]
    call dispatch_store_config
    test eax, eax
    jnz .policy_error
    mov rdi, [config_success_ptr]
    mov esi, [config_success_len]
    jmp .reply
.channel_usage:
    lea rdi, [channel_usage_response]
    mov esi, channel_usage_response_len
    jmp .reply
.config_role:
    mov [config_setting_ptr], rdi
    mov [config_setting_len], esi
    mov [config_success_ptr], rdx
    mov [config_success_len], ecx
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .role_usage
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '&'
    call dispatch_extract_mention_id
    test eax, eax
    jle .role_usage
    mov [config_value_len], eax
    lea rdi, [config_value]
    mov esi, eax
    mov rdx, [config_setting_ptr]
    mov ecx, [config_setting_len]
    xchg rdi, rdx
    xchg esi, ecx
    lea rdx, [config_value]
    mov ecx, [config_value_len]
    call dispatch_store_config
    test eax, eax
    jnz .policy_error
    mov rdi, [config_success_ptr]
    mov esi, [config_success_len]
    jmp .reply
.role_usage:
    lea rdi, [role_usage_response]
    mov esi, role_usage_response_len
    jmp .reply
.setwelcomemsg:
    lea rdi, [setting_welcome_message]
    mov esi, setting_welcome_message_len
    jmp .config_text
.setgoodbyemsg:
    lea rdi, [setting_goodbye_message]
    mov esi, setting_goodbye_message_len
.config_text:
    mov [config_setting_ptr], rdi
    mov [config_setting_len], esi
    call dispatch_owner_authorized
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .text_usage
    mov rdi, [config_setting_ptr]
    mov esi, [config_setting_len]
    mov rdx, [dispatch_tail_ptr]
    mov ecx, [dispatch_tail_len]
    call dispatch_store_config
    test eax, eax
    jnz .policy_error
    lea rdi, [text_saved_response]
    mov esi, text_saved_response_len
    jmp .reply
.text_usage:
    lea rdi, [text_usage_response]
    mov esi, text_usage_response_len
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
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    call groq_select_guild
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

; EAX=0 on stored config; -1 on invalid or persistence failure.
; RDI=setting, ESI=setting len, RDX=value, ECX=value len.
dispatch_store_config:
    push r12
    push r13
    push r14
    push r15
    push rbx
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    mov rdx, r12
    mov ecx, r13d
    mov r8, r14
    mov r9d, r15d
    call guild_config_set
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; Skip command whitespace. RDI=tail pointer, ESI=tail length.
dispatch_tail_after_command:
    mov eax, ebx
.skip:
    cmp eax, r15d
    jae .empty
    mov dl, [message_content + rax]
    cmp dl, ' '
    je .advance
    cmp dl, 9
    je .advance
    jmp .ready
.advance:
    inc eax
    jmp .skip
.ready:
    lea rdi, [message_content + rax]
    mov esi, r15d
    sub esi, eax
    mov [dispatch_tail_ptr], rdi
    mov [dispatch_tail_len], esi
    ret
.empty:
    xor edi, edi
    xor esi, esi
    mov qword [dispatch_tail_ptr], 0
    mov dword [dispatch_tail_len], 0
    ret

; RDI=tail bytes, ESI=len, DL='#' for <#id> or '&' for <@&id>.
; EAX=extracted decimal ID len, or -1. The ID is copied into config_value.
dispatch_extract_mention_id:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    xor ecx, ecx
.scan:
    cmp ecx, r12d
    jae .bad
    cmp byte [rbx + rcx], '<'
    jne .advance
    cmp dl, '#'
    jne .role_open
    lea eax, [rcx + 2]
    cmp eax, r12d
    jae .bad
    cmp byte [rbx + rcx + 1], '#'
    jne .advance
    jmp .digits
.role_open:
    lea eax, [rcx + 3]
    cmp eax, r12d
    jae .bad
    cmp byte [rbx + rcx + 1], '@'
    jne .advance
    cmp byte [rbx + rcx + 2], '&'
    jne .advance
.digits:
    xor esi, esi
.digit_loop:
    cmp eax, r12d
    jae .bad
    cmp esi, AUTHOR_ID_CAP - 1
    jae .bad
    mov r8b, [rbx + rax]
    cmp r8b, '>'
    je .done
    cmp r8b, '0'
    jb .bad
    cmp r8b, '9'
    ja .bad
    mov [config_value + rsi], r8b
    inc esi
    inc eax
    jmp .digit_loop
.done:
    test esi, esi
    jz .bad
    mov eax, esi
    jmp .out
.advance:
    inc ecx
    jmp .scan
.bad:
    mov eax, -1
.out:
    pop r12
    pop rbx
    ret

; RDI=tail, ESI=tail length. EAX=lower-cased first token length, or -1.
dispatch_copy_first_lower:
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    cmp ecx, COMMAND_CAP - 1
    jae .bad
    mov al, [rdi + rcx]
    cmp al, ' '
    je .done
    cmp al, 9
    je .done
    cmp al, 10
    je .done
    cmp al, 13
    je .done
    cmp al, 'A'
    jb .store
    cmp al, 'Z'
    ja .store
    add al, 'a' - 'A'
.store:
    mov [argument_buffer + rcx], al
    inc ecx
    jmp .loop
.done:
    test ecx, ecx
    jz .bad
    mov eax, ecx
    ret
.bad:
    mov eax, -1
    ret

; RDI=normalized alias, ESI=len. RAX=model ID pointer; EDX=len; zero/zero invalid.
dispatch_model_alias:
    mov r8, rdi
    mov r9d, esi
    lea r10, [model_alias_table]
.next:
    mov ecx, [r10]
    test ecx, ecx
    jz .bad
    cmp ecx, r9d
    jne .advance
    mov rdi, r8
    mov rsi, [r10 + 8]
    mov edx, ecx
    call dispatch_bytes_equal
    test al, al
    jnz .found
.advance:
    add r10, 32
    jmp .next
.found:
    mov rax, [r10 + 16]
    mov edx, [r10 + 24]
    ret
.bad:
    xor eax, eax
    xor edx, edx
    ret

; RDI/RSI, EDX length. AL=1 iff exact bytes match.
dispatch_bytes_equal:
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

; RDI=decimal tail, ESI=tail len. CF=0 only for one ASCII decimal token 5..100.
dispatch_parse_history_limit:
    test esi, esi
    jle .bad
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    movzx edx, byte [rdi + rcx]
    cmp dl, '0'
    jb .space_or_bad
    cmp dl, '9'
    ja .space_or_bad
    imul eax, eax, 10
    add eax, edx
    sub eax, '0'
    cmp eax, 100
    ja .bad
    inc ecx
    jmp .loop
.space_or_bad:
    cmp dl, ' '
    je .space_tail
    cmp dl, 9
    je .space_tail
    cmp dl, 10
    je .space_tail
    cmp dl, 13
    je .space_tail
    jmp .bad
.space_tail:
    inc ecx
.tail_loop:
    cmp ecx, esi
    jae .done
    mov dl, [rdi + rcx]
    cmp dl, ' '
    je .tail_advance
    cmp dl, 9
    je .tail_advance
    cmp dl, 10
    je .tail_advance
    cmp dl, 13
    je .tail_advance
    jmp .bad
.tail_advance:
    inc ecx
    jmp .tail_loop
.done:
    cmp eax, 5
    jb .bad
    clc
    ret
.bad:
    stc
    ret

; AL=1 only for BOT_OWNER_ID or a cached server owner in a guild context. This
; remains fail-closed for non-owner administrators until overwrite resolution exists.
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
    call guild_auth_is_manager
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
persona_usage_response: db 'Usage: setpersona <text>.'
persona_usage_response_len equ $ - persona_usage_response
persona_saved_response: db 'Guild persona saved.'
persona_saved_response_len equ $ - persona_saved_response
history_usage_response: db 'Usage: sethistory <number 5-100>.'
history_usage_response_len equ $ - history_usage_response
history_saved_response: db 'Guild history limit saved.'
history_saved_response_len equ $ - history_saved_response
setting_persona: db 'system_prompt'
setting_persona_len equ $ - setting_persona
setting_history: db 'max_history'
setting_history_len equ $ - setting_history
setting_model: db 'model'
setting_model_len equ $ - setting_model
setting_autorole: db 'auto_role'
setting_autorole_len equ $ - setting_autorole
setting_welcome_channel: db 'welcome_channel'
setting_welcome_channel_len equ $ - setting_welcome_channel
setting_goodbye_channel: db 'goodbye_channel'
setting_goodbye_channel_len equ $ - setting_goodbye_channel
setting_level_channel: db 'level_channel'
setting_level_channel_len equ $ - setting_level_channel
setting_log_channel: db 'log_channel'
setting_log_channel_len equ $ - setting_log_channel
setting_welcome_message: db 'welcome_msg'
setting_welcome_message_len equ $ - setting_welcome_message
setting_goodbye_message: db 'goodbye_msg'
setting_goodbye_message_len equ $ - setting_goodbye_message
channel_usage_response: db 'Usage: mention a channel.'
channel_usage_response_len equ $ - channel_usage_response
role_usage_response: db 'Usage: mention a role.'
role_usage_response_len equ $ - role_usage_response
text_usage_response: db 'Usage: provide message text.'
text_usage_response_len equ $ - text_usage_response
channel_saved_response: db 'Guild channel setting saved.'
channel_saved_response_len equ $ - channel_saved_response
role_saved_response: db 'Guild auto-role saved.'
role_saved_response_len equ $ - role_saved_response
role_removed_response: db 'Guild auto-role removed.'
role_removed_response_len equ $ - role_removed_response
text_saved_response: db 'Guild message setting saved.'
text_saved_response_len equ $ - text_saved_response
model_usage_response: db 'Usage: setmodel llama70b|gpt120b|gpt20b|qwen32b.'
model_usage_response_len equ $ - model_usage_response
model_saved_response: db 'Guild model saved.'
model_saved_response_len equ $ - model_saved_response
model_alias_llama: db 'llama70b'
model_alias_llama_len equ $ - model_alias_llama
model_id_llama: db 'llama-3.3-70b-versatile'
model_id_llama_len equ $ - model_id_llama
model_alias_gpt120: db 'gpt120b'
model_alias_gpt120_len equ $ - model_alias_gpt120
model_id_gpt120: db 'openai/gpt-oss-120b'
model_id_gpt120_len equ $ - model_id_gpt120
model_alias_gpt20: db 'gpt20b'
model_alias_gpt20_len equ $ - model_alias_gpt20
model_id_gpt20: db 'openai/gpt-oss-20b'
model_id_gpt20_len equ $ - model_id_gpt20
model_alias_qwen: db 'qwen32b'
model_alias_qwen_len equ $ - model_alias_qwen
model_id_qwen: db 'qwen/qwen3-32b'
model_id_qwen_len equ $ - model_id_qwen
align 8
model_alias_table:
    dd model_alias_llama_len, 0
    dq model_alias_llama, model_id_llama
    dd model_id_llama_len, 0
    dd model_alias_gpt120_len, 0
    dq model_alias_gpt120, model_id_gpt120
    dd model_id_gpt120_len, 0
    dd model_alias_gpt20_len, 0
    dq model_alias_gpt20, model_id_gpt20
    dd model_id_gpt20_len, 0
    dd model_alias_qwen_len, 0
    dq model_alias_qwen, model_id_qwen
    dd model_id_qwen_len, 0
    dd 0, 0
    dq 0, 0
    dd 0, 0
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
dispatch_tail_ptr: resq 1
dispatch_tail_len: resd 1
dispatch_model_ptr: resq 1
dispatch_model_len: resd 1
config_setting_ptr: resq 1
config_setting_len: resd 1
config_success_ptr: resq 1
config_success_len: resd 1
config_value_len: resd 1
config_value: resb AUTHOR_ID_CAP
rank_response: resb 32
rank_scratch: resb 10
message_content: resb MESSAGE_CONTENT_CAP
command_buffer: resb COMMAND_CAP
ai_reply: resb AI_REPLY_CAP
state_view_reply: resb STATE_VIEW_REPLY_CAP

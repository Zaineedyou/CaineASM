BITS 64
DEFAULT REL

global dispatch_message_create

extern json_find_key
extern json_read_string
extern json_value_is_true
extern json_object_end
extern json_object_find_direct_key
extern json_array_end
extern command_classify
extern discord_send_text
extern discord_delete_message
extern groq_chat_once
extern groq_vision_once
extern attachment_extract_image_url
extern attachment_copy_image_mime
extern attachment_fetch_https
extern base64_encode
extern groq_select_guild
extern groq_select_history
extern history_clear
extern ai_rate_allow
extern afk_set
extern afk_clear
extern xp_increment
extern xp_get
extern state_format_afk_list
extern state_format_leaderboard
extern state_format_banned_words
extern guild_auth_is_manager
extern guild_auth_roles_have
extern channel_auth_resolve
extern guild_auth_get_bot_roles
extern guild_auth_bot_above_roles
extern guild_auth_role_position
extern guild_auth_member_highest_position
extern discord_unban_member
extern discord_kick_member
extern discord_ban_member
extern discord_lock_channel
extern discord_unlock_channel
extern discord_set_slowmode
extern discord_set_member_timeout
extern discord_clear_member_timeout
extern discord_set_member_nick
extern discord_add_member_role
extern discord_remove_member_role
extern guild_word_add
extern guild_word_remove
extern guild_word_matches
extern guild_channel_disable
extern guild_channel_enable
extern guild_channel_is_disabled
extern guild_config_set
extern guild_config_get
extern guild_config_delete
extern warnings_add
extern warnings_get
extern warnings_clear
extern bot_prefix_ptr
extern bot_prefix_len
extern message_rate_allow
extern gateway_bot_user_id
extern gateway_bot_user_id_len
extern gateway_guild_count
extern gateway_uptime_format
extern discord_get_json
extern discord_get_channel_messages
extern discord_bulk_delete_messages

%define MESSAGE_CONTENT_CAP 2048
%define CHANNEL_ID_CAP 64
%define GUILD_ID_CAP 64
%define AUTHOR_ID_CAP 64
%define AUTHOR_NAME_CAP 128
%define AUTOMOD_LOG_TEXT_CAP 400
%define COMMAND_CAP 64
%define AI_REPLY_CAP 1901
%define HISTORY_KEY_CAP 64
%define STATE_VIEW_REPLY_CAP 2000
%define REPORT_LOG_CAP 2000
%define STATUS_UPTIME_CAP 64
%define STATUS_REPLY_CAP 128
%define ATTACHMENT_URL_CAP 1024
%define ATTACHMENT_MIME_CAP 64
%define VISION_IMAGE_CAP 11250
%define VISION_B64_CAP 15000
%define REPLY_REFERENCE_ID_CAP 64
%define REPLY_REFERENCE_URL_CAP 512
%define REPLY_REFERENCE_RESPONSE_CAP 4096
%define TARGET_MEMBER_URL_CAP 512
%define TARGET_MEMBER_RESPONSE_CAP 4096
%define CLEAR_RESPONSE_CAP 4096
%define CLEAR_BATCH_MAX 100
%define CLEAR_ID_CAP 64
%define PERMISSION_MANAGE_MESSAGES 0x2000
%define SYS_TIME 201
%define PERMISSION_ADMINISTRATOR 8
%define PERMISSION_KICK_MEMBERS 2
%define PERMISSION_BAN_MEMBERS 4
%define PERMISSION_MANAGE_CHANNELS 16
%define PERMISSION_MANAGE_ROLES 0x10000000
%define PERMISSION_MANAGE_NICKNAMES 0x8000000
%define PERMISSION_MODERATE_MEMBERS 0x10000000000

%define CMD_HELP   1
%define CMD_RESET  2
%define CMD_AFK    3
%define CMD_AFKLIST 4
%define CMD_RANK   5
%define CMD_LEADERBOARD 6
%define CMD_STATUS 7
%define CMD_SUMMARIZE 8
%define CMD_WARN 9
%define CMD_KICK 10
%define CMD_BAN 11
%define CMD_TIMEOUT 12
%define CMD_CLEAR 13
%define CMD_LOCK 14
%define CMD_UNLOCK 15
%define CMD_SLOWMODE 16
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
%define CMD_WARNINGS 33
%define CMD_CLEARWARN 34
%define CMD_UNBAN 35
%define CMD_UNTIMEOUT 36
%define CMD_NICK 37
%define CMD_ROLE 38
%define CMD_REPORT 39

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
    mov [channel_id_len], eax
    mov byte [channel_id + r14], 0

    ; Guild/user identity is optional for generic commands but required by AFK state.
    mov dword [guild_id_len], 0
    mov dword [author_id_len], 0
    mov dword [author_name_len], 0
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
    mov r15, rax
    mov rdi, rbx
    mov rsi, r15
    sub rsi, rbx
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .content
    mov rdi, rax
    mov rsi, r15
    lea rdx, [author_id]
    mov ecx, AUTHOR_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .content
    mov [author_id_len], eax
    mov byte [author_id + rax], 0
    mov rdi, rbx
    mov rsi, r15
    lea rdx, [key_username]
    mov ecx, key_username_len
    call json_object_find_direct_key
    test rax, rax
    jz .author_name_done
    mov rdi, rax
    mov rsi, r15
    lea rdx, [author_name]
    mov ecx, AUTHOR_NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .author_name_done
    mov [author_name_len], eax
    mov byte [author_name + rax], 0
.author_name_done:
    cmp dword [author_id_len], 0
    jle .handled
    lea rdi, [author_id]
    mov esi, [author_id_len]
    call message_rate_allow
    test al, al
    jz .handled
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
    js .handled
    mov r15d, eax
    mov [message_content_len], eax

    ; Source-equivalent automod runs before XP/AFK routing and before disabled
    ; channel suppression. A malformed/missing message ID fails closed: no
    ; delete request is constructed from unverified identifiers.
    cmp dword [guild_id_len], 0
    je .automod_done
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [message_content]
    mov ecx, r15d
    call guild_word_matches
    test rax, rax
    jz .automod_done
    mov [automod_word_ptr], rax
    mov [automod_word_len], edx
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .automod_done
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [automod_message_id]
    mov ecx, AUTHOR_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .automod_done
    lea rdi, [channel_id]
    mov esi, r14d
    lea rdx, [automod_message_id]
    mov ecx, eax
    call discord_delete_message
    call dispatch_log_automod
    lea rdi, [automod_response]
    mov esi, automod_response_len
    jmp .reply
.automod_done:

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
    jns .trigger_ready
    lea rdi, [message_content]
    mov esi, r15d
    call dispatch_offset_after_bot_mention
    test eax, eax
    jns .trigger_ready
    mov rdi, r12
    mov rsi, r13
    call dispatch_is_reply_to_bot
    test al, al
    jz .handled
    xor eax, eax
.trigger_ready:
    mov ebx, eax                     ; offset after prefix or mention
    cmp ebx, r15d
    jae .chat_empty_trigger

.skip_spaces:
    cmp ebx, r15d
    jae .chat_empty_trigger
    mov al, [message_content + rbx]
    cmp al, ' '
    je .space_advance
    cmp al, 9
    je .space_advance
    jmp .command
.space_advance:
    inc ebx
    jmp .skip_spaces

.chat_empty_trigger:
    ; A literal prefix/mention with no text is still an explicit AI trigger.
    ; It can therefore describe a whitelisted first image attachment, but an
    ; untriggered attachment never reaches this path.
    mov [command_start], ebx
    jmp .chat

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
    mov [command_start], ebx
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
    cmp eax, CMD_WARN
    je .warn
    cmp eax, CMD_KICK
    je .kick
    cmp eax, CMD_BAN
    je .ban
    cmp eax, CMD_CLEAR
    je .clear
    cmp eax, CMD_LOCK
    je .lock
    cmp eax, CMD_UNLOCK
    je .unlock
    cmp eax, CMD_SLOWMODE
    je .slowmode
    cmp eax, CMD_TIMEOUT
    je .timeout
    cmp eax, CMD_UNTIMEOUT
    je .untimeout
    cmp eax, CMD_NICK
    je .nick
    cmp eax, CMD_ROLE
    je .role
    cmp eax, CMD_WARNINGS
    je .warnings
    cmp eax, CMD_CLEARWARN
    je .clearwarn
    cmp eax, CMD_UNBAN
    je .unban
    cmp eax, CMD_REPORT
    je .report
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
    jz .chat
    lea rdi, [registered_notice]
    mov esi, registered_notice_len
    jmp .reply
.chat:
    mov eax, [command_start]
    lea rdi, [message_content + rax]
    mov esi, r15d
    sub esi, eax
    mov [dispatch_tail_ptr], rdi
    mov [dispatch_tail_len], esi
    call dispatch_select_history_key
    lea rdi, [author_id]
    mov esi, [author_id_len]
    call ai_rate_allow
    test al, al
    jz .ai_rate_limited
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    call groq_select_guild
    ; Vision is accepted only on the existing prefix-triggered AI path.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [attachment_url]
    mov ecx, ATTACHMENT_URL_CAP
    call attachment_extract_image_url
    test eax, eax
    jle .chat_text
    mov [attachment_url_len], eax
    lea rdi, [attachment_mime]
    mov esi, ATTACHMENT_MIME_CAP
    call attachment_copy_image_mime
    test eax, eax
    jle .chat_text
    mov [attachment_mime_len], eax
    lea rdi, [attachment_url]
    mov esi, [attachment_url_len]
    lea rdx, [vision_image]
    mov ecx, VISION_IMAGE_CAP
    call attachment_fetch_https
    test rax, rax
    jle .ai_error
    mov [vision_image_len], eax
    lea rdi, [vision_b64]
    mov esi, VISION_B64_CAP
    lea rdx, [vision_image]
    mov ecx, [vision_image_len]
    call base64_encode
    test eax, eax
    jle .ai_error
    mov [vision_b64_len], eax
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    test esi, esi
    jg .vision_prompt
    lea rdi, [chat_default_prompt]
    mov esi, chat_default_prompt_len
.vision_prompt:
    mov eax, AI_REPLY_CAP
    push rax
    lea rax, [ai_reply]
    push rax
    lea r8, [vision_b64]
    mov r9d, [vision_b64_len]
    lea rdx, [attachment_mime]
    mov ecx, [attachment_mime_len]
    call groq_vision_once
    add rsp, 16
    jmp .chat_done
.chat_text:
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    test esi, esi
    jg .chat_groq
    lea rdi, [chat_default_prompt]
    mov esi, chat_default_prompt_len
.chat_groq:
    lea rdx, [ai_reply]
    mov ecx, AI_REPLY_CAP
    call groq_chat_once
.chat_done:
    test eax, eax
    jle .ai_error
    mov [ai_reply_len], eax
    lea rdi, [ai_reply]
    mov esi, eax
    jmp .chat_reply
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
    call dispatch_select_history_key
    lea rdi, [history_key]
    mov esi, [history_key_len]
    call history_clear
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
.ai_rate_limited:
    lea rdi, [ai_rate_limited_response]
    mov esi, ai_rate_limited_response_len
    jmp .reply
.ai_error:
    lea rdi, [ai_error_response]
    mov esi, ai_error_response_len
    jmp .reply
.unknown:
    lea rdi, [unknown_response]
    mov esi, unknown_response_len

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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
.bot_denied:
    lea rdi, [bot_denied_response]
    mov esi, bot_denied_response_len
    jmp .reply
.moderation_error:
    lea rdi, [moderation_error_response]
    mov esi, moderation_error_response_len
    jmp .reply
.hierarchy_denied:
    lea rdi, [hierarchy_denied_response]
    mov esi, hierarchy_denied_response_len
    jmp .reply
.policy_error:
    lea rdi, [policy_error_response]
    mov esi, policy_error_response_len
    jmp .reply
.setpersona:
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
    mov r8, PERMISSION_ADMINISTRATOR
    call dispatch_has_permission
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
.warn:
    mov r8, PERMISSION_KICK_MEMBERS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .warn_usage
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '@'
    call dispatch_extract_mention_id
    test eax, eax
    jle .warn_usage
    mov [warning_target_len], eax
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_tail_after_mention
    mov [moderation_reason_ptr], rdi
    mov [moderation_reason_len], esi
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [config_value]
    mov ecx, [warning_target_len]
    call warnings_add
    test eax, eax
    js .policy_error
    mov ebx, eax
    lea rdi, [mod_action_warn]
    mov esi, mod_action_warn_len
    lea rdx, [config_value]
    mov ecx, [warning_target_len]
    mov r8, [moderation_reason_ptr]
    mov r9d, [moderation_reason_len]
    call dispatch_log_moderation
    mov eax, ebx
    lea rdi, [warning_reply + warning_reply_prefix_len]
    call format_uint32
    mov ebx, eax
    lea rdi, [warning_reply]
    lea rsi, [warning_reply_prefix]
    mov edx, warning_reply_prefix_len
    call copy_bytes
    lea rdi, [warning_reply + warning_reply_prefix_len]
    add rdi, rbx
    lea rsi, [warning_reply_suffix]
    mov edx, warning_reply_suffix_len
    call copy_bytes
    mov esi, ebx
    add esi, warning_reply_prefix_len + warning_reply_suffix_len
    lea rdi, [warning_reply]
    jmp .reply
.warn_usage:
    lea rdi, [warn_usage_response]
    mov esi, warn_usage_response_len
    jmp .reply
.warnings:
    call dispatch_tail_after_command
    test esi, esi
    jle .warnings_self
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '@'
    call dispatch_extract_mention_id
    test eax, eax
    jle .warnings_self
    mov [warning_target_len], eax
    jmp .warnings_query
.warnings_self:
    cmp dword [author_id_len], 0
    je .warn_usage
    lea rdi, [config_value]
    lea rsi, [author_id]
    mov edx, [author_id_len]
    call copy_bytes
    mov eax, [author_id_len]
    mov [warning_target_len], eax
.warnings_query:
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [config_value]
    mov ecx, [warning_target_len]
    call warnings_get
    test eax, eax
    js .policy_error
    lea rdi, [warning_reply + warning_reply_prefix_len]
    call format_uint32
    mov ebx, eax
    lea rdi, [warning_reply]
    lea rsi, [warning_reply_prefix]
    mov edx, warning_reply_prefix_len
    call copy_bytes
    lea rdi, [warning_reply + warning_reply_prefix_len]
    add rdi, rbx
    lea rsi, [warning_reply_suffix]
    mov edx, warning_reply_suffix_len
    call copy_bytes
    mov esi, ebx
    add esi, warning_reply_prefix_len + warning_reply_suffix_len
    lea rdi, [warning_reply]
    jmp .reply
.kick:
    mov r8, PERMISSION_KICK_MEMBERS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_KICK_MEMBERS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .kick_usage
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '@'
    call dispatch_extract_mention_id
    test eax, eax
    jle .kick_usage
    mov [moderation_target_len], eax
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_tail_after_mention
    mov [moderation_reason_ptr], rdi
    mov [moderation_reason_len], esi
    lea rdi, [config_value]
    mov esi, [moderation_target_len]
    call dispatch_bot_above_target
    test al, al
    jz .hierarchy_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [config_value]
    mov ecx, [moderation_target_len]
    mov r8, [moderation_reason_ptr]
    mov r9d, [moderation_reason_len]
    call discord_kick_member
    test eax, eax
    jnz .moderation_error
    lea rdi, [mod_action_kick]
    mov esi, mod_action_kick_len
    lea rdx, [config_value]
    mov ecx, [moderation_target_len]
    mov r8, [moderation_reason_ptr]
    mov r9d, [moderation_reason_len]
    call dispatch_log_moderation
    lea rdi, [kick_success_response]
    mov esi, kick_success_response_len
    jmp .reply
.kick_usage:
    lea rdi, [kick_usage_response]
    mov esi, kick_usage_response_len
    jmp .reply

.lock:
    mov r8, PERMISSION_MANAGE_CHANNELS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MANAGE_CHANNELS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    lea rdx, [guild_id]
    mov ecx, [guild_id_len]
    call discord_lock_channel
    test eax, eax
    jnz .moderation_error
    lea rdi, [lock_success_response]
    mov esi, lock_success_response_len
    jmp .reply
.unlock:
    mov r8, PERMISSION_MANAGE_CHANNELS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MANAGE_CHANNELS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    lea rdx, [guild_id]
    mov ecx, [guild_id_len]
    call discord_unlock_channel
    test eax, eax
    jnz .moderation_error
    lea rdi, [unlock_success_response]
    mov esi, unlock_success_response_len
    jmp .reply

.slowmode:
    mov r8, PERMISSION_MANAGE_CHANNELS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MANAGE_CHANNELS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    call dispatch_parse_slowmode
    jc .slowmode_usage
    mov rdx, rax
    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    call discord_set_slowmode
    test eax, eax
    jnz .moderation_error
    lea rdi, [slowmode_success_response]
    mov esi, slowmode_success_response_len
    jmp .reply
.slowmode_usage:
    lea rdi, [slowmode_usage_response]
    mov esi, slowmode_usage_response_len
    jmp .reply

.timeout:
    mov r8, PERMISSION_MODERATE_MEMBERS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MODERATE_MEMBERS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_parse_timeout_command
    test eax, eax
    jle .timeout_usage
    mov [timeout_minutes], eax
    lea rdi, [timeout_target]
    mov esi, [timeout_target_len]
    call dispatch_bot_above_target
    test al, al
    jz .hierarchy_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [timeout_target]
    mov ecx, [timeout_target_len]
    mov r8d, [timeout_minutes]
    call discord_set_member_timeout
    test eax, eax
    jnz .moderation_error
    lea rdi, [mod_action_timeout]
    mov esi, mod_action_timeout_len
    lea rdx, [timeout_target]
    mov ecx, [timeout_target_len]
    mov r8, [moderation_reason_ptr]
    mov r9d, [moderation_reason_len]
    call dispatch_log_moderation
    lea rdi, [timeout_success_response]
    mov esi, timeout_success_response_len
    jmp .reply
.timeout_usage:
    lea rdi, [timeout_usage_response]
    mov esi, timeout_usage_response_len
    jmp .reply
.untimeout:
    mov r8, PERMISSION_MODERATE_MEMBERS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MODERATE_MEMBERS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_parse_untimeout_command
    test eax, eax
    jle .untimeout_usage
    lea rdi, [timeout_target]
    mov esi, [timeout_target_len]
    call dispatch_bot_above_target
    test al, al
    jz .hierarchy_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [timeout_target]
    mov ecx, [timeout_target_len]
    call discord_clear_member_timeout
    test eax, eax
    jnz .moderation_error
    lea rdi, [untimeout_success_response]
    mov esi, untimeout_success_response_len
    jmp .reply
.untimeout_usage:
    lea rdi, [untimeout_usage_response]
    mov esi, untimeout_usage_response_len
    jmp .reply
.nick:
    mov r8, PERMISSION_MANAGE_NICKNAMES
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MANAGE_NICKNAMES
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_parse_nick_command
    test eax, eax
    jle .nick_usage
    lea rdi, [nick_target]
    mov esi, [nick_target_len]
    call dispatch_bot_above_target
    test al, al
    jz .hierarchy_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [nick_target]
    mov ecx, [nick_target_len]
    lea r8, [nick_value]
    mov r9d, [nick_value_len]
    call discord_set_member_nick
    test eax, eax
    jnz .moderation_error
    lea rdi, [nick_success_response]
    mov esi, nick_success_response_len
    jmp .reply
.nick_usage:
    lea rdi, [nick_usage_response]
    mov esi, nick_usage_response_len
    jmp .reply
.role:
    mov r8, PERMISSION_MANAGE_ROLES
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MANAGE_ROLES
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_parse_role_command
    test eax, eax
    jle .role_command_usage
    lea rdi, [role_target]
    mov esi, [role_target_len]
    call dispatch_bot_above_target
    test al, al
    jz .hierarchy_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [role_requested]
    mov ecx, [role_requested_len]
    call guild_auth_role_position
    test eax, eax
    js .hierarchy_denied
    mov [role_requested_position], eax
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    call guild_auth_get_bot_roles
    test rax, rax
    jz .hierarchy_denied
    test edx, edx
    jle .hierarchy_denied
    mov rcx, rdx
    mov rdx, rax
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    call guild_auth_member_highest_position
    test eax, eax
    js .hierarchy_denied
    cmp eax, [role_requested_position]
    jle .hierarchy_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [role_target]
    mov ecx, [role_target_len]
    lea r8, [role_requested]
    mov r9d, [role_requested_len]
    cmp dword [role_action], 1
    je .role_add
    call discord_remove_member_role
    test eax, eax
    jnz .moderation_error
    lea rdi, [role_remove_success_response]
    mov esi, role_remove_success_response_len
    jmp .reply
.role_add:
    call discord_add_member_role
    test eax, eax
    jnz .moderation_error
    lea rdi, [role_add_success_response]
    mov esi, role_add_success_response_len
    jmp .reply
.role_command_usage:
    lea rdi, [role_command_usage_response]
    mov esi, role_command_usage_response_len
    jmp .reply
.ban:
    mov r8, PERMISSION_BAN_MEMBERS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_BAN_MEMBERS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .ban_usage
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '@'
    call dispatch_extract_mention_id
    test eax, eax
    jle .ban_usage
    mov [moderation_target_len], eax
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_tail_after_mention
    mov [moderation_reason_ptr], rdi
    mov [moderation_reason_len], esi
    lea rdi, [config_value]
    mov esi, [moderation_target_len]
    call dispatch_bot_above_target
    test al, al
    jz .hierarchy_denied
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [config_value]
    mov ecx, [moderation_target_len]
    mov r8, [moderation_reason_ptr]
    mov r9d, [moderation_reason_len]
    call discord_ban_member
    test eax, eax
    jnz .moderation_error
    lea rdi, [mod_action_ban]
    mov esi, mod_action_ban_len
    lea rdx, [config_value]
    mov ecx, [moderation_target_len]
    mov r8, [moderation_reason_ptr]
    mov r9d, [moderation_reason_len]
    call dispatch_log_moderation
    lea rdi, [ban_success_response]
    mov esi, ban_success_response_len
    jmp .reply
.ban_usage:
    lea rdi, [ban_usage_response]
    mov esi, ban_usage_response_len
    jmp .reply

.unban:
    mov r8, PERMISSION_BAN_MEMBERS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_BAN_MEMBERS
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .unban_usage
    call dispatch_copy_first_lower
    test eax, eax
    jle .unban_usage
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [argument_buffer]
    mov ecx, eax
    call discord_unban_member
    test eax, eax
    jnz .moderation_error
    lea rdi, [mod_action_unban]
    mov esi, mod_action_unban_len
    lea rdx, [argument_buffer]
    mov ecx, [config_value_len]
    lea r8, [mod_reason_dash]
    mov r9d, mod_reason_dash_len
    call dispatch_log_moderation
    lea rdi, [unban_success_response]
    mov esi, unban_success_response_len
    jmp .reply
.unban_usage:
    lea rdi, [unban_usage_response]
    mov esi, unban_usage_response_len
    jmp .reply


.clear:
    mov r8, PERMISSION_MANAGE_MESSAGES
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    mov r8, PERMISSION_MANAGE_MESSAGES
    call dispatch_bot_has_permission
    test al, al
    jz .bot_denied
    call dispatch_tail_after_command
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_parse_clear_limit
    jc .clear_usage
    mov [clear_amount], eax
    inc eax
    mov [clear_fetch_limit], eax

    ; Resolve the invocation ID from a direct property of the MESSAGE_CREATE
    ; payload object. Nested IDs (author, embeds, and similar data) are never
    ; accepted, so malformed frames cannot place the invocation in a batch.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_gateway_data]
    mov ecx, key_gateway_data_len
    call json_find_key
    test rax, rax
    jz .moderation_error
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .moderation_error
    mov rsi, rax
    mov rdi, rbx
    lea rdx, [clear_invocation_id]
    mov ecx, CLEAR_ID_CAP - 1
    call dispatch_json_object_direct_id
    test eax, eax
    jle .moderation_error
    mov [clear_invocation_id_len], eax

    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    lea rdx, [clear_snapshot]
    mov ecx, CLEAR_RESPONSE_CAP
    mov r8d, [clear_fetch_limit]
    call discord_get_channel_messages
    test rax, rax
    js .moderation_error
    cmp rax, CLEAR_RESPONSE_CAP - 1
    jae .moderation_error
    mov [clear_snapshot_len], eax
    lea rdi, [clear_snapshot]
    mov esi, [clear_snapshot_len]
    call dispatch_parse_clear_snapshot
    test eax, eax
    js .moderation_error
    mov [clear_batch_count], eax
    test eax, eax
    jz .clear_empty
    cmp eax, 1
    jne .clear_bulk
    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    lea rdx, [clear_message_ids]
    mov ecx, [clear_message_id_lens]
    call discord_delete_message
    test eax, eax
    jnz .moderation_error
    jmp .clear_success
.clear_bulk:
    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    lea rdx, [clear_message_ids]
    mov ecx, [clear_batch_count]
    call discord_bulk_delete_messages
    test eax, eax
    jnz .moderation_error
.clear_success:
    lea rdi, [clear_success_response]
    mov esi, clear_success_response_len
    jmp .reply
.clear_empty:
    lea rdi, [clear_empty_response]
    mov esi, clear_empty_response_len
    jmp .reply
.clear_usage:
    lea rdi, [clear_usage_response]
    mov esi, clear_usage_response_len
    jmp .reply

.clearwarn:

    mov r8, PERMISSION_KICK_MEMBERS
    call dispatch_has_permission
    test al, al
    jz .admin_denied
    call dispatch_tail_after_command
    test esi, esi
    jle .warn_usage
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '@'
    call dispatch_extract_mention_id
    test eax, eax
    jle .warn_usage
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [config_value]
    mov ecx, eax
    call warnings_clear
    test eax, eax
    js .policy_error
    lea rdi, [clearwarn_response]
    mov esi, clearwarn_response_len
    jmp .reply
.report:
    cmp dword [guild_id_len], 0
    je .report_usage
    cmp dword [author_id_len], 0
    je .report_usage
    call dispatch_tail_after_command
    test esi, esi
    jle .report_usage
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    mov dl, '@'
    call dispatch_extract_mention_id
    test eax, eax
    jle .report_usage
    mov [report_target_len], eax
    mov dword [report_log_len], 0
    lea rdi, [report_log_prefix]
    mov esi, report_log_prefix_len
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [report_mention_prefix]
    mov esi, report_mention_prefix_len
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [author_id]
    mov esi, [author_id_len]
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [report_target_label]
    mov esi, report_target_label_len
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [config_value]
    mov esi, [report_target_len]
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [report_reason_label]
    mov esi, report_reason_label_len
    call report_append_bytes
    test eax, eax
    js .report_ack
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    call dispatch_tail_after_mention
    test esi, esi
    jle .report_default_reason
    call report_append_sanitized
    test eax, eax
    js .report_ack
    jmp .report_channel_label
.report_default_reason:
    lea rdi, [report_default_reason]
    mov esi, report_default_reason_len
    call report_append_bytes
    test eax, eax
    js .report_ack
.report_channel_label:
    lea rdi, [report_channel_label]
    mov esi, report_channel_label_len
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [report_channel_mention_prefix]
    mov esi, report_channel_mention_prefix_len
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [channel_id]
    mov esi, r14d
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [report_channel_mention_suffix]
    mov esi, report_channel_mention_suffix_len
    call report_append_bytes
    test eax, eax
    js .report_ack
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [setting_log_channel]
    mov ecx, setting_log_channel_len
    call guild_config_get
    test rax, rax
    jz .report_ack
    test edx, edx
    jle .report_ack
    cmp edx, CHANNEL_ID_CAP - 1
    ja .report_ack
    mov ebx, edx
    mov rsi, rax
    lea rdi, [report_log_channel]
    mov edx, ebx
    call copy_bytes
    lea rdi, [report_log_channel]
    mov esi, ebx
    lea rdx, [report_log]
    mov ecx, [report_log_len]
    call discord_send_text
.report_ack:
    lea rdi, [report_saved_response]
    mov esi, report_saved_response_len
    jmp .reply
.report_usage:
    lea rdi, [report_usage_response]
    mov esi, report_usage_response_len
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
    lea rdi, [status_uptime]
    mov esi, STATUS_UPTIME_CAP
    call gateway_uptime_format
    test eax, eax
    jg .uptime_ready
    lea rdi, [status_uptime]
    lea rsi, [status_uptime_fallback]
    mov edx, status_uptime_fallback_len
    call copy_bytes
    mov eax, status_uptime_fallback_len
.uptime_ready:
    mov [status_uptime_len], eax
    lea rdi, [status_reply]
    lea rsi, [status_prefix]
    mov edx, status_prefix_len
    call copy_bytes
    mov ebx, status_prefix_len
    lea rdi, [status_reply + rbx]
    lea rsi, [status_uptime]
    mov edx, [status_uptime_len]
    call copy_bytes
    add ebx, edx
    lea rdi, [status_reply + rbx]
    lea rsi, [status_servers_label]
    mov edx, status_servers_label_len
    call copy_bytes
    add ebx, edx
    call gateway_guild_count
    lea rdi, [status_reply + rbx]
    call format_uint32
    add ebx, eax
    lea rdi, [status_reply]
    mov esi, ebx
    jmp .reply
.reset:
    call dispatch_select_history_key
    lea rdi, [history_key]
    mov esi, [history_key_len]
    call history_clear
    lea rdi, [reset_response]
    mov esi, reset_response_len
    jmp .reply
.chat_reply:
    mov rdx, rdi
    mov ecx, esi
    lea rdi, [channel_id]
    mov esi, r14d
    call discord_send_text
    call dispatch_log_chat
    jmp .out
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

; RDI=target member snowflake, ESI=len. RDX=roles array pointer and ECX=len
; only when one bounded Discord member GET succeeds and yields a complete roles
; array. RAX=-1 otherwise; callers must not perform destructive REST on failure.
dispatch_fetch_target_member_roles:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    test r12, r12
    jz .bad
    test r13d, r13d
    jle .bad
    cmp r13d, AUTHOR_ID_CAP - 1
    ja .bad
    cmp dword [guild_id_len], 0
    jle .bad
    mov rdi, r12
    mov esi, r13d
    call dispatch_is_decimal_identifier
    test al, al
    jz .bad
    mov eax, target_member_url_prefix_len + target_member_url_middle_len
    add eax, [guild_id_len]
    add eax, r13d
    cmp eax, TARGET_MEMBER_URL_CAP - 1
    ja .bad
    mov [target_member_url_len], eax
    lea rdi, [target_member_url]
    lea rsi, [target_member_url_prefix]
    mov edx, target_member_url_prefix_len
    call copy_bytes
    lea rdi, [target_member_url + target_member_url_prefix_len]
    lea rsi, [guild_id]
    mov edx, [guild_id_len]
    call copy_bytes
    lea rdi, [target_member_url + target_member_url_prefix_len]
    mov eax, [guild_id_len]
    add rdi, rax
    lea rsi, [target_member_url_middle]
    mov edx, target_member_url_middle_len
    call copy_bytes
    lea rdi, [target_member_url + target_member_url_prefix_len]
    mov eax, [guild_id_len]
    add rdi, rax
    add rdi, target_member_url_middle_len
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    mov eax, [target_member_url_len]
    mov byte [target_member_url + rax], 0
    lea rdi, [target_member_url]
    mov esi, [target_member_url_len]
    lea rdx, [target_member_response]
    mov ecx, TARGET_MEMBER_RESPONSE_CAP
    call discord_get_json
    test rax, rax
    jle .bad
    mov [target_member_response_len], eax
    lea rdi, [target_member_response]
    mov esi, eax
    lea rdx, [key_roles]
    mov ecx, key_roles_len
    call json_find_key
    test rax, rax
    jz .bad
    cmp byte [rax], '['
    jne .bad
    mov r14, rax
    mov rdi, r14
    lea rsi, [target_member_response]
    mov eax, [target_member_response_len]
    add rsi, rax
    call json_array_end
    test rax, rax
    jz .bad
    mov r15, rax
    mov rdx, r14
    mov rcx, r15
    sub rcx, r14
    xor eax, eax
    jmp .out
.bad:
    mov rax, -1
    xor edx, edx
    xor ecx, ecx
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=full MESSAGE_CREATE JSON, RSI=len. AL=1 only when a bounded
; message_reference points to a message authored by the READY-cached bot ID.
; Exactly one authenticated Discord GET is issued per valid reference candidate;
; malformed IDs, transport/API failures, and non-bot authors all fail closed.
dispatch_is_reply_to_bot:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r15d, r14d                  ; caller's validated channel ID length
    cmp dword [gateway_bot_user_id_len], 0
    jle .no
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_message_reference]
    mov ecx, key_message_reference_len
    call json_find_key
    test rax, rax
    jz .no
    cmp byte [rax], '{'
    jne .no
    mov r14, rax
    mov rdi, r14
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .no
    mov rbx, rax
    mov rdi, r14
    mov rsi, rbx
    sub rsi, r14
    lea rdx, [key_message_id]
    mov ecx, key_message_id_len
    call json_find_key
    test rax, rax
    jz .no
    mov rdi, rax
    mov rsi, rbx
    lea rdx, [reply_reference_id]
    mov ecx, REPLY_REFERENCE_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .no
    mov [reply_reference_id_len], eax
    mov byte [reply_reference_id + rax], 0
    lea rdi, [channel_id]
    mov esi, r15d
    call dispatch_is_decimal_identifier
    test al, al
    jz .no
    lea rdi, [reply_reference_id]
    mov esi, [reply_reference_id_len]
    call dispatch_is_decimal_identifier
    test al, al
    jz .no
    mov eax, reply_reference_url_prefix_len + reply_reference_url_middle_len
    add eax, r15d
    add eax, [reply_reference_id_len]
    cmp eax, REPLY_REFERENCE_URL_CAP - 1
    ja .no
    mov [reply_reference_url_len], eax
    lea rdi, [reply_reference_url]
    lea rsi, [reply_reference_url_prefix]
    mov edx, reply_reference_url_prefix_len
    call copy_bytes
    lea rdi, [reply_reference_url + reply_reference_url_prefix_len]
    lea rsi, [channel_id]
    mov edx, r15d
    call copy_bytes
    lea rdi, [reply_reference_url + reply_reference_url_prefix_len]
    add rdi, r15
    lea rsi, [reply_reference_url_middle]
    mov edx, reply_reference_url_middle_len
    call copy_bytes
    lea rdi, [reply_reference_url + reply_reference_url_prefix_len]
    add rdi, r15
    add rdi, reply_reference_url_middle_len
    lea rsi, [reply_reference_id]
    mov edx, [reply_reference_id_len]
    call copy_bytes
    mov eax, [reply_reference_url_len]
    mov byte [reply_reference_url + rax], 0
    lea rdi, [reply_reference_url]
    mov esi, [reply_reference_url_len]
    lea rdx, [reply_reference_response]
    mov ecx, REPLY_REFERENCE_RESPONSE_CAP
    call discord_get_json
    test rax, rax
    jle .no
    mov [reply_reference_response_len], eax
    lea rdi, [reply_reference_response]
    mov esi, eax
    lea rdx, [key_author]
    mov ecx, key_author_len
    call json_find_key
    test rax, rax
    jz .no
    cmp byte [rax], '{'
    jne .no
    mov r14, rax
    mov rdi, r14
    lea rsi, [reply_reference_response]
    mov eax, [reply_reference_response_len]
    add rsi, rax
    call json_object_end
    test rax, rax
    jz .no
    mov rbx, rax
    mov rdi, r14
    mov rsi, rbx
    sub rsi, r14
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .no
    mov rdi, rax
    mov rsi, rbx
    lea rdx, [reply_reference_author_id]
    mov ecx, AUTHOR_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .no
    cmp eax, [gateway_bot_user_id_len]
    jne .no
    xor ecx, ecx
.compare_author:
    cmp ecx, eax
    jae .yes
    mov dl, [reply_reference_author_id + rcx]
    cmp dl, [gateway_bot_user_id + rcx]
    jne .no
    inc ecx
    jmp .compare_author
.yes:
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=identifier bytes, ESI=len. AL=1 only for a nonzero ASCII decimal ID.
dispatch_is_nonzero_decimal_identifier:
    call dispatch_is_decimal_identifier
    test al, al
    jz .no
    xor edx, edx
.loop:
    cmp edx, esi
    jae .no
    cmp byte [rdi + rdx], '0'
    jne .yes
    inc edx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI=identifier bytes, ESI=len. AL=1 only for nonempty ASCII decimal IDs.
dispatch_is_decimal_identifier:
    test rdi, rdi
    jz .no
    test esi, esi
    jle .no
    cmp esi, AUTHOR_ID_CAP - 1
    ja .no
    xor edx, edx
.loop:
    cmp edx, esi
    jae .yes
    mov al, [rdi + rdx]
    sub al, '0'
    cmp al, 9
    ja .no
    inc edx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
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
; Selects a source-compatible history key and gives it to the Groq builder.
; Server histories are channel scoped; direct messages are author scoped.
dispatch_select_history_key:
    mov dword [history_key_len], 0
    cmp dword [guild_id_len], 0
    je .dm
    lea rdi, [history_key]
    lea rsi, [history_server_prefix]
    mov edx, history_server_prefix_len
    call copy_bytes
    mov eax, history_server_prefix_len
    mov ecx, r14d
    add eax, ecx
    cmp eax, HISTORY_KEY_CAP - 1
    ja .clear
    lea rdi, [history_key + history_server_prefix_len]
    lea rsi, [channel_id]
    mov edx, ecx
    call copy_bytes
    mov [history_key_len], eax
    jmp .select
.dm:
    cmp dword [author_id_len], 0
    jle .clear
    mov eax, history_dm_prefix_len
    mov ecx, [author_id_len]
    add eax, ecx
    cmp eax, HISTORY_KEY_CAP - 1
    ja .clear
    lea rdi, [history_key]
    lea rsi, [history_dm_prefix]
    mov edx, history_dm_prefix_len
    call copy_bytes
    lea rdi, [history_key + history_dm_prefix_len]
    lea rsi, [author_id]
    mov edx, ecx
    call copy_bytes
    mov [history_key_len], eax
    jmp .select
.clear:
    xor edi, edi
    xor esi, esi
    call groq_select_history
    ret
.select:
    lea rdi, [history_key]
    mov esi, [history_key_len]
    call groq_select_history
    ret

; RDI=tail bytes, ESI=tail length. RDI/ESI return text after command whitespace.
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

; RDI=tail bytes, ESI=len. Returns the non-space bytes after the first closing
; mention delimiter in RDI/ESI, or an empty tail when no bounded delimiter exists.
dispatch_tail_after_mention:
    xor eax, eax
.find_end:
    cmp eax, esi
    jae .empty
    cmp byte [rdi + rax], '>'
    je .after_end
    inc eax
    jmp .find_end
.after_end:
    inc eax
.skip_spaces:
    cmp eax, esi
    jae .empty
    mov dl, [rdi + rax]
    cmp dl, ' '
    je .space
    cmp dl, 9
    je .space
    add rdi, rax
    sub esi, eax
    ret
.space:
    inc eax
    jmp .skip_spaces
.empty:
    add rdi, rsi
    xor esi, esi
    ret

; RDI=tail bytes, ESI=len. EAX=amount 1..99, CF=0; an empty tail defaults
; to 10. Only one decimal token plus trailing ASCII whitespace is accepted.
dispatch_parse_clear_limit:
    xor eax, eax
    test esi, esi
    jle .default
    xor ecx, ecx
.digits:
    cmp ecx, esi
    jae .done
    movzx edx, byte [rdi + rcx]
    cmp dl, '0'
    jb .space_or_bad
    cmp dl, '9'
    ja .space_or_bad
    imul eax, eax, 10
    sub edx, '0'
    add eax, edx
    cmp eax, CLEAR_BATCH_MAX - 1
    ja .bad
    inc ecx
    jmp .digits
.space_or_bad:
    test ecx, ecx
    jz .bad
    cmp dl, ' '
    je .tail
    cmp dl, 9
    je .tail
    cmp dl, 10
    je .tail
    cmp dl, 13
    jne .bad
.tail:
    inc ecx
.tail_loop:
    cmp ecx, esi
    jae .done
    mov dl, [rdi + rcx]
    cmp dl, ' '
    je .tail_next
    cmp dl, 9
    je .tail_next
    cmp dl, 10
    je .tail_next
    cmp dl, 13
    jne .bad
.tail_next:
    inc ecx
    jmp .tail_loop
.done:
    test eax, eax
    jz .bad
    clc
    ret
.default:
    mov eax, 10
    clc
    ret
.bad:
    stc
    ret

; RDI=snapshot, ESI=length. EAX=eligible target count (0..99) or -1.
; The snapshot must be one complete array of complete objects, contain the
; invocation exactly once, and provide only unique current snowflakes. Every
; non-invocation message is age-checked before its ID enters the delete table.
dispatch_parse_clear_snapshot:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    mov r12, rdi
    lea r13, [rdi + rsi]
    cld
    lea rdi, [clear_seen_ids]
    xor eax, eax
    mov ecx, CLEAR_BATCH_MAX * CLEAR_ID_CAP
    rep stosb
    lea rdi, [clear_message_ids]
    mov ecx, CLEAR_BATCH_MAX * CLEAR_ID_CAP
    rep stosb
    mov dword [clear_batch_count], 0
    mov dword [clear_invocation_found], 0
    mov dword [clear_json_depth], 0
    xor r15d, r15d
    mov r14, r12
    mov rdi, r14
    mov rsi, r13
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r13
    jae .bad
    cmp byte [r14], '['
    jne .bad
    inc r14
.object_next:
    mov rdi, r14
    mov rsi, r13
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r13
    jae .bad
    cmp byte [r14], ']'
    je .array_done
    cmp byte [r14], '{'
    jne .bad
    mov rdi, r14
    mov rsi, r13
    call json_object_end
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, r14
    mov rsi, rbx
    lea rdx, [clear_current_id]
    mov ecx, CLEAR_ID_CAP - 1
    call dispatch_json_object_direct_id
    test eax, eax
    jle .bad
    mov [clear_current_id_len], eax
    cmp r15d, [clear_fetch_limit]
    jae .bad
    lea rdi, [clear_seen_ids]
    mov esi, r15d
    lea rdx, [clear_current_id]
    mov ecx, eax
    call dispatch_clear_table_contains
    test al, al
    jnz .bad
    lea rdi, [clear_seen_ids]
    mov esi, r15d
    lea rdx, [clear_current_id]
    mov ecx, [clear_current_id_len]
    xor r8d, r8d
    call dispatch_clear_store_slot
    test eax, eax
    js .bad
    inc r15d

    mov eax, [clear_current_id_len]
    cmp eax, [clear_invocation_id_len]
    jne .eligible
    lea rdi, [clear_current_id]
    lea rsi, [clear_invocation_id]
    mov edx, eax
    call dispatch_bytes_equal
    test al, al
    jz .eligible
    inc dword [clear_invocation_found]
    cmp dword [clear_invocation_found], 1
    ja .bad
    jmp .after_object
.eligible:
    lea rdi, [clear_current_id]
    mov esi, [clear_current_id_len]
    call dispatch_clear_snowflake_recent
    test al, al
    jz .bad
    mov eax, [clear_batch_count]
    cmp eax, CLEAR_BATCH_MAX
    jae .bad
    lea rdi, [clear_message_ids]
    mov esi, eax
    lea rdx, [clear_current_id]
    mov ecx, [clear_current_id_len]
    lea r8, [clear_message_id_lens]
    call dispatch_clear_store_slot
    test eax, eax
    js .bad
    inc dword [clear_batch_count]
.after_object:
    mov r14, rbx
    mov rdi, r14
    mov rsi, r13
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r13
    jae .bad
    cmp byte [r14], ','
    je .comma
    cmp byte [r14], ']'
    je .array_done
    jmp .bad
.comma:
    inc r14
    jmp .object_next
.array_done:
    inc r14
    mov rdi, r14
    mov rsi, r13
    call dispatch_json_skip_ws
    cmp rax, r13
    jne .bad
    cmp dword [clear_invocation_found], 1
    jne .bad
    mov eax, [clear_batch_count]
    cmp eax, [clear_amount]
    ja .bad
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=object, RSI=first byte after its matching brace, RDX=destination,
; ECX=destination capacity. EAX=direct top-level decimal `id` length or -1.
dispatch_json_object_direct_id:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rdi, rdi
    jz .bad
    test rdx, rdx
    jz .bad
    test ecx, ecx
    jle .bad
    cmp byte [rdi], '{'
    jne .bad
    mov r12, rdx
    mov r13d, ecx
    mov rbx, rsi
    lea r14, [rdi + 1]
    xor r15d, r15d
.property:
    mov rdi, r14
    mov rsi, rbx
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, rbx
    jae .bad
    cmp byte [r14], '}'
    je .done
    cmp byte [r14], 0x22
    jne .bad
    mov rdi, r14
    mov rsi, rbx
    lea rdx, [clear_string_scratch]
    mov ecx, CLEAR_RESPONSE_CAP - 1
    call json_read_string
    test eax, eax
    js .bad
    mov r14, rdx
    xor r9d, r9d
    cmp eax, 2
    jne .key_done
    cmp byte [clear_string_scratch], 'i'
    jne .key_done
    cmp byte [clear_string_scratch + 1], 'd'
    jne .key_done
    mov r9d, 1
.key_done:
    mov rdi, r14
    mov rsi, rbx
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, rbx
    jae .bad
    cmp byte [r14], ':'
    jne .bad
    inc r14
    mov rdi, r14
    mov rsi, rbx
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, rbx
    jae .bad
    test r9d, r9d
    jz .skip_value
    test r15d, r15d
    jnz .bad
    cmp byte [r14], 0x22
    jne .bad
    mov rdi, r14
    mov rsi, rbx
    mov rdx, r12
    mov ecx, r13d
    call json_read_string
    test eax, eax
    jle .bad
    mov r15d, eax
    mov r14, rdx
    mov byte [r12 + r15], 0
    mov rdi, r12
    mov esi, r15d
    call dispatch_clear_decimal_id
    test al, al
    jz .bad
    jmp .after_value
.skip_value:
    mov rdi, r14
    mov rsi, rbx
    call dispatch_json_skip_value
    test rax, rax
    jz .bad
    mov r14, rax
.after_value:
    mov rdi, r14
    mov rsi, rbx
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, rbx
    jae .bad
    cmp byte [r14], ','
    je .next_property
    cmp byte [r14], '}'
    jne .bad
.done:
    lea rax, [r14 + 1]
    cmp rax, rbx
    jne .bad
    test r15d, r15d
    jz .bad
    mov eax, r15d
    jmp .out
.next_property:
    inc r14
    jmp .property
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=pointer, RSI=exclusive end. RAX=first non-ASCII-whitespace pointer.
dispatch_json_skip_ws:
    mov rax, rdi
.loop:
    cmp rax, rsi
    jae .out
    mov dl, [rax]
    cmp dl, ' '
    je .advance
    cmp dl, 9
    je .advance
    cmp dl, 10
    je .advance
    cmp dl, 13
    jne .out
.advance:
    inc rax
    jmp .loop
.out:
    ret

; RDI=value start, RSI=exclusive end. RAX=first byte after exactly one valid
; bounded JSON value, or zero. This is deliberately strict: object/array
; delimiters, JSON number grammar, strings, and true/false/null are validated
; rather than merely skipped by brace depth.
dispatch_json_skip_value:
    push rbx
    push r12
    push r13
    push r14
    test rdi, rdi
    jz .bad
    cmp rdi, rsi
    jae .bad
    mov r12, rsi
    mov r14, rdi
    cmp byte [r14], 0x22
    je .string
    cmp byte [r14], '{'
    je .object
    cmp byte [r14], '['
    je .array
    cmp byte [r14], 't'
    je .true
    cmp byte [r14], 'f'
    je .false
    cmp byte [r14], 'n'
    je .null
    cmp byte [r14], '-'
    je .number
    cmp byte [r14], '0'
    jb .bad
    cmp byte [r14], '9'
    ja .bad
.number:
    cmp byte [r14], '-'
    jne .number_integer
    inc r14
    cmp r14, r12
    jae .bad
.number_integer:
    cmp byte [r14], '0'
    jne .number_nonzero
    inc r14
    cmp r14, r12
    jae .number_fraction
    mov al, [r14]
    cmp al, '0'
    jb .number_fraction
    cmp al, '9'
    jbe .bad
    jmp .number_fraction
.number_nonzero:
    cmp byte [r14], '1'
    jb .bad
    cmp byte [r14], '9'
    ja .bad
.number_digits:
    inc r14
    cmp r14, r12
    jae .number_fraction
    mov al, [r14]
    cmp al, '0'
    jb .number_fraction
    cmp al, '9'
    jbe .number_digits
.number_fraction:
    cmp r14, r12
    jae .number_done
    cmp byte [r14], '.'
    jne .number_exponent
    inc r14
    cmp r14, r12
    jae .bad
    cmp byte [r14], '0'
    jb .bad
    cmp byte [r14], '9'
    ja .bad
.fraction_digits:
    inc r14
    cmp r14, r12
    jae .number_done
    mov al, [r14]
    cmp al, '0'
    jb .number_exponent
    cmp al, '9'
    jbe .fraction_digits
.number_exponent:
    cmp r14, r12
    jae .number_done
    mov al, [r14]
    cmp al, 'e'
    je .exponent
    cmp al, 'E'
    jne .number_done
.exponent:
    inc r14
    cmp r14, r12
    jae .bad
    mov al, [r14]
    cmp al, '+'
    je .exponent_sign
    cmp al, '-'
    jne .exponent_first
.exponent_sign:
    inc r14
    cmp r14, r12
    jae .bad
.exponent_first:
    cmp byte [r14], '0'
    jb .bad
    cmp byte [r14], '9'
    ja .bad
.exponent_digits:
    inc r14
    cmp r14, r12
    jae .number_done
    mov al, [r14]
    cmp al, '0'
    jb .number_done
    cmp al, '9'
    jbe .exponent_digits
.number_done:
    mov rax, r14
    jmp .out
.true:
    lea rax, [r14 + 4]
    cmp rax, r12
    ja .bad
    cmp byte [r14 + 1], 'r'
    jne .bad
    cmp byte [r14 + 2], 'u'
    jne .bad
    cmp byte [r14 + 3], 'e'
    jne .bad
    jmp .out
.false:
    lea rax, [r14 + 5]
    cmp rax, r12
    ja .bad
    cmp byte [r14 + 1], 'a'
    jne .bad
    cmp byte [r14 + 2], 'l'
    jne .bad
    cmp byte [r14 + 3], 's'
    jne .bad
    cmp byte [r14 + 4], 'e'
    jne .bad
    jmp .out
.null:
    lea rax, [r14 + 4]
    cmp rax, r12
    ja .bad
    cmp byte [r14 + 1], 'u'
    jne .bad
    cmp byte [r14 + 2], 'l'
    jne .bad
    cmp byte [r14 + 3], 'l'
    jne .bad
    jmp .out
.string:
    lea rdx, [clear_string_scratch]
    mov ecx, CLEAR_RESPONSE_CAP - 1
    mov rdi, r14
    mov rsi, r12
    call json_read_string
    test eax, eax
    js .bad
    mov rax, rdx
    jmp .out
.object:
    inc dword [clear_json_depth]
    cmp dword [clear_json_depth], 32
    ja .bad_depth
    inc r14
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    cmp byte [r14], '}'
    je .object_close
.object_property:
    cmp byte [r14], 0x22
    jne .bad_depth
    lea rdx, [clear_string_scratch]
    mov ecx, CLEAR_RESPONSE_CAP - 1
    mov rdi, r14
    mov rsi, r12
    call json_read_string
    test eax, eax
    js .bad_depth
    mov r14, rdx
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    cmp byte [r14], ':'
    jne .bad_depth
    inc r14
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_value
    test rax, rax
    jz .bad_depth
    mov r14, rax
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    cmp byte [r14], ','
    je .object_comma
    cmp byte [r14], '}'
    jne .bad_depth
.object_close:
    inc r14
    dec dword [clear_json_depth]
    mov rax, r14
    jmp .out
.object_comma:
    inc r14
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    jmp .object_property
.array:
    inc dword [clear_json_depth]
    cmp dword [clear_json_depth], 32
    ja .bad_depth
    inc r14
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    cmp byte [r14], ']'
    je .array_close
.array_value:
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_value
    test rax, rax
    jz .bad_depth
    mov r14, rax
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    cmp byte [r14], ','
    je .array_comma
    cmp byte [r14], ']'
    jne .bad_depth
.array_close:
    inc r14
    dec dword [clear_json_depth]
    mov rax, r14
    jmp .out
.array_comma:
    inc r14
    mov rdi, r14
    mov rsi, r12
    call dispatch_json_skip_ws
    mov r14, rax
    cmp r14, r12
    jae .bad_depth
    jmp .array_value
.bad_depth:
    dec dword [clear_json_depth]
.bad:
    xor eax, eax
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=bytes, ESI=len. AL=1 only for bounded non-empty ASCII decimal ID.
dispatch_clear_decimal_id:
    test rdi, rdi
    jz .no
    test esi, esi
    jle .no
    cmp esi, CLEAR_ID_CAP - 1
    ja .no
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .yes
    mov al, [rdi + rcx]
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .no
    inc ecx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI=table, ESI=entry count, RDX=ID, ECX=ID length. AL=1 iff present.
dispatch_clear_table_contains:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov ebx, ecx
    xor r8d, r8d
.entry:
    cmp r8d, r13d
    jae .no
    mov eax, r8d
    imul rax, CLEAR_ID_CAP
    lea rdi, [r12 + rax]
    xor ecx, ecx
.length:
    cmp ecx, CLEAR_ID_CAP
    jae .no
    cmp byte [rdi + rcx], 0
    je .compare
    inc ecx
    jmp .length
.compare:
    cmp ecx, ebx
    jne .next
    mov rsi, r14
    mov edx, ebx
    call dispatch_bytes_equal
    test al, al
    jnz .out
.next:
    inc r8d
    jmp .entry
.no:
    xor eax, eax
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=table, ESI=index, RDX=ID, ECX=len, R8=optional dword length table.
dispatch_clear_store_slot:
    test rdi, rdi
    jz .bad
    test rdx, rdx
    jz .bad
    cmp esi, CLEAR_BATCH_MAX
    jae .bad
    test ecx, ecx
    jle .bad
    cmp ecx, CLEAR_ID_CAP - 1
    ja .bad
    mov eax, esi
    imul rax, CLEAR_ID_CAP
    add rdi, rax
    xor eax, eax
.copy:
    cmp eax, ecx
    jae .finish
    mov r9b, [rdx + rax]
    mov [rdi + rax], r9b
    inc eax
    jmp .copy
.finish:
    mov byte [rdi + rax], 0
    test r8, r8
    jz .ok
    mov [r8 + rsi * 4], ecx
.ok:
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=decimal snowflake, ESI=len. AL=1 iff timestamp is no more than 14 days
; old and not later than the current Unix clock. Decimal overflow is rejected.
dispatch_clear_snowflake_recent:
    push r12
    test rdi, rdi
    jz .no
    test esi, esi
    jle .no
    xor eax, eax
    xor ecx, ecx
.digits:
    cmp ecx, esi
    jae .parsed
    movzx edx, byte [rdi + rcx]
    cmp dl, '0'
    jb .no
    cmp dl, '9'
    ja .no
    mov r9d, edx
    sub r9d, '0'
    mov r8d, 10
    mul r8
    test rdx, rdx
    jnz .no
    add rax, r9
    jc .no
    inc ecx
    jmp .digits
.parsed:
    shr rax, 22
    mov r8, 1420070400000
    add rax, r8
    jc .no
    mov r12, rax
    mov eax, SYS_TIME
    xor edi, edi
    syscall
    test rax, rax
    jle .no
    imul rax, rax, 1000
    jo .no
    cmp r12, rax
    ja .no
    sub rax, 1209600000
    cmp r12, rax
    jb .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r12
    ret

; RDI=tail bytes, ESI=len. EAX=1 (add), 2 (remove), or -1.
; Accepts only: role add|remove <@user> <@&role>, with optional ASCII
; whitespace between ordered tokens and after the final mention. The separate
; fixed buffers avoid the generic mention parser's config_value overwrite.
dispatch_parse_role_command:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov dword [role_target_len], 0
    mov dword [role_requested_len], 0
    test r12, r12
    jz .bad
    test r13d, r13d
    jle .bad
    cmp r13d, 4
    jb .try_remove
    mov al, [r12]
    or al, 0x20
    cmp al, 'a'
    jne .try_remove
    mov al, [r12 + 1]
    or al, 0x20
    cmp al, 'd'
    jne .try_remove
    mov al, [r12 + 2]
    or al, 0x20
    cmp al, 'd'
    jne .try_remove
    mov ebx, 3
    mov dword [role_action], 1
    jmp .action_boundary
.try_remove:
    cmp r13d, 7
    jb .bad
    mov al, [r12]
    or al, 0x20
    cmp al, 'r'
    jne .bad
    mov al, [r12 + 1]
    or al, 0x20
    cmp al, 'e'
    jne .bad
    mov al, [r12 + 2]
    or al, 0x20
    cmp al, 'm'
    jne .bad
    mov al, [r12 + 3]
    or al, 0x20
    cmp al, 'o'
    jne .bad
    mov al, [r12 + 4]
    or al, 0x20
    cmp al, 'v'
    jne .bad
    mov al, [r12 + 5]
    or al, 0x20
    cmp al, 'e'
    jne .bad
    mov ebx, 6
    mov dword [role_action], 2
.action_boundary:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, ' '
    je .skip_user_ws
    cmp al, 9
    je .skip_user_ws
    cmp al, 10
    je .skip_user_ws
    cmp al, 13
    jne .bad
.skip_user_ws:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, ' '
    je .advance_user_ws
    cmp al, 9
    je .advance_user_ws
    cmp al, 10
    je .advance_user_ws
    cmp al, 13
    je .advance_user_ws
    jmp .user_open
.advance_user_ws:
    inc ebx
    jmp .skip_user_ws
.user_open:
    cmp byte [r12 + rbx], '<'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '@'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '!'
    jne .user_digits_start
    inc ebx
.user_digits_start:
    xor r14d, r14d
.user_digits:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, '>'
    je .user_done
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    cmp r14d, AUTHOR_ID_CAP - 1
    jae .bad
    mov [role_target + r14], al
    inc r14d
    inc ebx
    jmp .user_digits
.user_done:
    test r14d, r14d
    jz .bad
    mov [role_target_len], r14d
    inc ebx
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, ' '
    je .skip_role_ws
    cmp al, 9
    je .skip_role_ws
    cmp al, 10
    je .skip_role_ws
    cmp al, 13
    jne .bad
.skip_role_ws:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, ' '
    je .advance_role_ws
    cmp al, 9
    je .advance_role_ws
    cmp al, 10
    je .advance_role_ws
    cmp al, 13
    je .advance_role_ws
    jmp .role_open
.advance_role_ws:
    inc ebx
    jmp .skip_role_ws
.role_open:
    cmp byte [r12 + rbx], '<'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '@'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '&'
    jne .bad
    inc ebx
    xor r14d, r14d
.role_digits:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, '>'
    je .role_done
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    cmp r14d, AUTHOR_ID_CAP - 1
    jae .bad
    mov [role_requested + r14], al
    inc r14d
    inc ebx
    jmp .role_digits
.role_done:
    test r14d, r14d
    jz .bad
    mov [role_requested_len], r14d
    inc ebx
.trailing_ws:
    cmp ebx, r13d
    jae .ok
    mov al, [r12 + rbx]
    cmp al, ' '
    je .advance_trailing_ws
    cmp al, 9
    je .advance_trailing_ws
    cmp al, 10
    je .advance_trailing_ws
    cmp al, 13
    jne .bad
.advance_trailing_ws:
    inc ebx
    jmp .trailing_ws
.ok:
    mov eax, [role_action]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
; RDI=tail bytes, ESI=len. EAX=minutes (1..40320), or -1. Accepts only
; `<@user> <minutes> [reason]` in that order; reason is excluded from timeout
; REST because that endpoint has no reason field, but retained for bounded audit.
dispatch_parse_timeout_command:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov dword [timeout_target_len], 0
    mov qword [moderation_reason_ptr], 0
    mov dword [moderation_reason_len], 0
    test r12, r12
    jz .bad
    test r13d, r13d
    jle .bad
    xor ebx, ebx
    cmp byte [r12 + rbx], '<'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '@'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '!'
    jne .digits_start
    inc ebx
.digits_start:
    xor r14d, r14d
.digits:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, '>'
    je .target_done
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    cmp r14d, AUTHOR_ID_CAP - 1
    jae .bad
    mov [timeout_target + r14], al
    inc r14d
    inc ebx
    jmp .digits
.target_done:
    test r14d, r14d
    jz .bad
    mov [timeout_target_len], r14d
    inc ebx
    cmp ebx, r13d
    jae .bad
.skip_ws:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, ' '
    je .advance_ws
    cmp al, 9
    je .advance_ws
    cmp al, 10
    je .advance_ws
    cmp al, 13
    je .advance_ws
    jmp .minutes_start
.advance_ws:
    inc ebx
    jmp .skip_ws
.minutes_start:
    xor eax, eax
    xor r14d, r14d
.minutes:
    cmp ebx, r13d
    jae .minutes_done
    movzx edx, byte [r12 + rbx]
    cmp dl, '0'
    jb .minutes_tail
    cmp dl, '9'
    ja .minutes_tail
    imul eax, eax, 10
    sub edx, '0'
    add eax, edx
    cmp eax, 40320
    ja .bad
    inc r14d
    inc ebx
    jmp .minutes
.minutes_tail:
    test r14d, r14d
    jz .bad
    test eax, eax
    jz .bad
    cmp dl, ' '
    je .reason_skip_ws
    cmp dl, 9
    je .reason_skip_ws
    cmp dl, 10
    je .reason_skip_ws
    cmp dl, 13
    jne .bad
.reason_skip_ws:
    cmp ebx, r13d
    jae .out
    mov dl, [r12 + rbx]
    cmp dl, ' '
    je .reason_advance
    cmp dl, 9
    je .reason_advance
    cmp dl, 10
    je .reason_advance
    cmp dl, 13
    jne .reason_ready
.reason_advance:
    inc ebx
    jmp .reason_skip_ws
.reason_ready:
    lea rdx, [r12 + rbx]
    mov [moderation_reason_ptr], rdx
    mov edx, r13d
    sub edx, ebx
    mov [moderation_reason_len], edx
    jmp .out
.minutes_done:
    test r14d, r14d
    jz .bad
    test eax, eax
    jz .bad
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    jmp .out
; RDI=tail bytes, ESI=len. EAX=target len or -1. Accepts only a single
; user mention followed by optional ASCII whitespace; extra tokens fail closed.
dispatch_parse_untimeout_command:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov dword [timeout_target_len], 0
    test r12, r12
    jz .bad
    test r13d, r13d
    jle .bad
    xor ebx, ebx
    cmp byte [r12 + rbx], '<'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '@'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '!'
    jne .digits_start
    inc ebx
.digits_start:
    xor r14d, r14d
.digits:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, '>'
    je .target_done
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    cmp r14d, AUTHOR_ID_CAP - 1
    jae .bad
    mov [timeout_target + r14], al
    inc r14d
    inc ebx
    jmp .digits
.target_done:
    test r14d, r14d
    jz .bad
    mov [timeout_target_len], r14d
    inc ebx
.trailing:
    cmp ebx, r13d
    jae .ok
    mov al, [r12 + rbx]
    cmp al, ' '
    je .advance
    cmp al, 9
    je .advance
    cmp al, 10
    je .advance
    cmp al, 13
    jne .bad
.advance:
    inc ebx
    jmp .trailing
.ok:
    mov eax, [timeout_target_len]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
; RDI=tail bytes, ESI=len. EAX=nickname bytes or -1. Accepts only
; `<@user> <nickname>` ordered tokens, trimming only ASCII token whitespace;
; UTF-8, character count, controls, and JSON escaping are enforced by REST NASM.
dispatch_parse_nick_command:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov dword [nick_target_len], 0
    mov dword [nick_value_len], 0
    test r12, r12
    jz .bad
    test r13d, r13d
    jle .bad
    xor ebx, ebx
    cmp byte [r12 + rbx], '<'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '@'
    jne .bad
    inc ebx
    cmp ebx, r13d
    jae .bad
    cmp byte [r12 + rbx], '!'
    jne .digits_start
    inc ebx
.digits_start:
    xor r14d, r14d
.digits:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, '>'
    je .target_done
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    cmp r14d, AUTHOR_ID_CAP - 1
    jae .bad
    mov [nick_target + r14], al
    inc r14d
    inc ebx
    jmp .digits
.target_done:
    test r14d, r14d
    jz .bad
    mov [nick_target_len], r14d
    inc ebx
.leading:
    cmp ebx, r13d
    jae .bad
    mov al, [r12 + rbx]
    cmp al, ' '
    je .lead_next
    cmp al, 9
    je .lead_next
    cmp al, 10
    je .lead_next
    cmp al, 13
    je .lead_next
    jmp .copy_start
.lead_next:
    inc ebx
    jmp .leading
.copy_start:
    mov r14d, ebx
    mov r15d, r13d
.trailing:
    cmp r15d, r14d
    jbe .bad
    mov al, [r12 + r15 - 1]
    cmp al, ' '
    je .trim_last
    cmp al, 9
    je .trim_last
    cmp al, 10
    je .trim_last
    cmp al, 13
    jne .copy
.trim_last:
    dec r15d
    jmp .trailing
.copy:
    mov eax, r15d
    sub eax, r14d
    test eax, eax
    jle .bad
    cmp eax, 128
    ja .bad
    xor ecx, ecx
.copy_loop:
    cmp ecx, eax
    jae .done
    mov edx, r14d
    add edx, ecx
    mov dl, [r12 + rdx]
    mov [nick_value + rcx], dl
    inc ecx
    jmp .copy_loop
.done:
    mov [nick_value_len], eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
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
    jne .not_channel
    lea eax, [rcx + 2]
    cmp eax, r12d
    jae .bad
    cmp byte [rbx + rcx + 1], '#'
    jne .advance
    jmp .digits
.not_channel:
    cmp dl, '@'
    jne .role_open
    lea eax, [rcx + 2]
    cmp eax, r12d
    jae .bad
    cmp byte [rbx + rcx + 1], '@'
    jne .advance
    cmp byte [rbx + rax], '!'
    jne .digits
    inc eax
    jmp .digits
    ; role mention form is <@&id>.
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

; RDI=tail, ESI=len. RAX=0..21600 and CF=0; empty tail defaults to zero.
dispatch_parse_slowmode:
    xor eax, eax
    xor ecx, ecx
    test esi, esi
    jle .ok
.loop:
    cmp ecx, esi
    jae .ok
    movzx edx, byte [rdi + rcx]
    cmp dl, '0'
    jb .space
    cmp dl, '9'
    ja .space
    imul rax, rax, 10
    movzx rdx, dl
    sub rdx, '0'
    add rax, rdx
    cmp rax, 21600
    ja .bad
    inc ecx
    jmp .loop
.space:
    cmp dl, ' '
    je .tail
    cmp dl, 9
    je .tail
    stc
    ret
.tail:
    inc ecx
.tail_loop:
    cmp ecx, esi
    jae .ok
    mov dl, [rdi + rcx]
    cmp dl, ' '
    je .tail_next
    cmp dl, 9
    jne .bad
.tail_next:
    inc ecx
    jmp .tail_loop
.ok:
    clc
    ret
.bad:
    stc
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

; RDI=target snowflake, ESI=len. AL=1 only when a bounded member GET returns
; a complete role array and the cached bot highest role is strictly above it.
dispatch_bot_above_target:
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    call dispatch_fetch_target_member_roles
    test rax, rax
    js .no
    mov r8, rdx
    mov r9d, ecx
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    mov rdx, r8
    mov ecx, r9d
    call guild_auth_bot_above_roles
    jmp .out
.no:
    xor eax, eax
.out:
    pop r13
    pop r12
    ret

; R8=requested Discord permission bitset. AL=1 only if the READY-cached bot
; has a complete role snapshot and its effective permission includes the bit.
dispatch_bot_has_permission:
    push rbx
    push r12
    push r14
    mov r14, r8
    cmp dword [guild_id_len], 0
    je .no
    cmp dword [channel_id_len], 0
    je .no
    cmp dword [gateway_bot_user_id_len], 0
    je .no
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    call guild_auth_get_bot_roles
    test rax, rax
    jz .no
    test edx, edx
    jle .no
    mov rbx, rax
    mov r12d, edx
    push r12
    push rbx
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [channel_id]
    mov ecx, [channel_id_len]
    lea r8, [gateway_bot_user_id]
    mov r9d, [gateway_bot_user_id_len]
    call channel_auth_resolve
    add rsp, 16
    test rax, rax
    js .no
    test rax, r14
    jz .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r14
    pop r12
    pop rbx
    ret

; R8=requested Discord permission bitset. BOT_OWNER_ID and cached guild owner
; retain their source bypass; all other callers require a complete bounded
; GUILD_CREATE role/channel snapshot and effective channel permissions.
dispatch_has_permission:
    push rbx
    push r14
    mov r14, r8
    call dispatch_owner_authorized
    test al, al
    jnz .yes
    cmp dword [guild_id_len], 0
    je .no
    cmp dword [author_id_len], 0
    je .no
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_member]
    mov ecx, key_member_len
    call json_find_key
    test rax, rax
    jz .no
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .no
    mov rdi, rbx
    mov rsi, rax
    sub rsi, rdi
    lea rdx, [key_roles]
    mov ecx, key_roles_len
    call json_find_key
    test rax, rax
    jz .no
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_array_end
    test rax, rax
    jz .no
    mov rcx, rax
    sub rcx, rbx
    push rcx
    push rbx
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [channel_id]
    mov ecx, [channel_id_len]
    lea r8, [author_id]
    mov r9d, [author_id_len]
    call channel_auth_resolve
    add rsp, 16
    test rax, rax
    js .no
    test rax, r14
    jz .no
    mov al, 1
    jmp .out
.yes:
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r14
    pop rbx
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

; RDI=content, ESI=len. EAX=offset after <@bot-id> or <@!bot-id>, else -1.
dispatch_offset_after_bot_mention:
    test rdi, rdi
    jz .bad
    cmp esi, 4
    jb .bad
    cmp byte [rdi], '<'
    jne .bad
    cmp byte [rdi + 1], '@'
    jne .bad
    mov edx, 2
    cmp byte [rdi + rdx], '!'
    jne .id
    inc edx
.id:
    mov ecx, [gateway_bot_user_id_len]
    test ecx, ecx
    jle .bad
    lea eax, [edx + ecx + 1]
    cmp eax, esi
    ja .bad
    xor r8d, r8d
.compare:
    cmp r8d, ecx
    jae .close
    lea r9, [rdi + rdx]
    mov al, [r9 + r8]
    cmp al, [gateway_bot_user_id + r8]
    jne .bad
    inc r8d
    jmp .compare
.close:
    add edx, ecx
    cmp byte [rdi + rdx], '>'
    jne .bad
    lea eax, [rdx + 1]
    ret
.bad:
    mov eax, -1
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

; Sends a bounded chat audit to the configured guild log channel after a
; successful AI response is sent. Missing, malformed, or unsafe log configuration
; fails closed and never changes the user-facing response path.
dispatch_log_chat:
    push rbx
    push r12
    push r13
    push r14
    push r15
    cmp dword [guild_id_len], 0
    jle .out
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [setting_log_channel]
    mov ecx, setting_log_channel_len
    call guild_config_get
    test rax, rax
    jz .out
    test edx, edx
    jle .out
    cmp edx, CHANNEL_ID_CAP - 1
    ja .out
    mov r12, rax
    mov r13d, edx
    mov rdi, r12
    mov esi, r13d
    call dispatch_is_nonzero_decimal_identifier
    test al, al
    jz .out
    lea rdi, [report_log_channel]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    mov dword [report_log_len], 0
    lea rdi, [chat_log_prefix]
    mov esi, chat_log_prefix_len
    call report_append_bytes
    test eax, eax
    js .out
    cmp dword [author_name_len], 0
    jg .author_name
    cmp dword [author_id_len], 0
    jg .author_id
    lea rdi, [chat_log_unknown_user]
    mov esi, chat_log_unknown_user_len
    jmp .author_append
.author_name:
    lea rdi, [author_name]
    mov esi, [author_name_len]
    jmp .author_append
.author_id:
    lea rdi, [author_id]
    mov esi, [author_id_len]
.author_append:
    call automod_append_sanitized
    test eax, eax
    js .out
    lea rdi, [chat_log_channel_label]
    mov esi, chat_log_channel_label_len
    call report_append_bytes
    test eax, eax
    js .out
    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    call report_append_bytes
    test eax, eax
    js .out
    lea rdi, [chat_log_question_label]
    mov esi, chat_log_question_label_len
    call report_append_bytes
    test eax, eax
    js .out
    mov rdi, [dispatch_tail_ptr]
    mov esi, [dispatch_tail_len]
    test rdi, rdi
    jz .empty_question
    test esi, esi
    jle .empty_question
    cmp esi, AUTOMOD_LOG_TEXT_CAP
    jbe .question_cap_ready
    mov esi, AUTOMOD_LOG_TEXT_CAP
.question_cap_ready:
    call automod_append_sanitized
    test eax, eax
    js .out
    jmp .answer_label
.empty_question:
    lea rdi, [chat_log_empty]
    mov esi, chat_log_empty_len
    call report_append_bytes
    test eax, eax
    js .out
.answer_label:
    lea rdi, [chat_log_answer_label]
    mov esi, chat_log_answer_label_len
    call report_append_bytes
    test eax, eax
    js .out
    lea rdi, [ai_reply]
    mov esi, [ai_reply_len]
    test esi, esi
    jle .out
    cmp esi, AUTOMOD_LOG_TEXT_CAP
    jbe .answer_cap_ready
    mov esi, AUTOMOD_LOG_TEXT_CAP
.answer_cap_ready:
    call automod_append_sanitized
    test eax, eax
    js .out
    lea rdi, [report_log_channel]
    mov esi, r13d
    lea rdx, [report_log]
    mov ecx, [report_log_len]
    call discord_send_text
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=action/ESI=len, RDX=target/ECX=len, R8=reason/R9D=len. Sends a bounded
; moderation audit only after a successful local moderation action. Configuration
; errors, malformed IDs, and audit delivery failures remain best-effort.
dispatch_log_moderation:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi
    mov r12d, esi
    mov r14, rdx
    mov r15d, ecx
    mov [rsp], r8
    mov dword [rsp + 8], r9d
    cmp dword [guild_id_len], 0
    jle .out
    test rbx, rbx
    jz .out
    test r12d, r12d
    jle .out
    test r14, r14
    jz .out
    test r15d, r15d
    jle .out
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [setting_log_channel]
    mov ecx, setting_log_channel_len
    call guild_config_get
    test rax, rax
    jz .out
    test edx, edx
    jle .out
    cmp edx, CHANNEL_ID_CAP - 1
    ja .out
    mov r13d, edx
    mov [rsp + 16], rax
    mov rdi, rax
    mov esi, r13d
    call dispatch_is_nonzero_decimal_identifier
    test al, al
    jz .out
    lea rdi, [report_log_channel]
    mov rsi, [rsp + 16]
    mov edx, r13d
    call copy_bytes
    mov dword [report_log_len], 0
    lea rdi, [mod_log_prefix]
    mov esi, mod_log_prefix_len
    call report_append_bytes
    test eax, eax
    js .out
    mov rdi, rbx
    mov esi, r12d
    call report_append_bytes
    test eax, eax
    js .out
    lea rdi, [mod_log_moderator_label]
    mov esi, mod_log_moderator_label_len
    call report_append_bytes
    test eax, eax
    js .out
    cmp dword [author_name_len], 0
    jg .moderator_name
    lea rdi, [author_id]
    mov esi, [author_id_len]
    jmp .moderator_append
.moderator_name:
    lea rdi, [author_name]
    mov esi, [author_name_len]
.moderator_append:
    call automod_append_sanitized
    test eax, eax
    js .out
    lea rdi, [mod_log_target_label]
    mov esi, mod_log_target_label_len
    call report_append_bytes
    test eax, eax
    js .out
    mov rdi, r14
    mov esi, r15d
    call automod_append_sanitized
    test eax, eax
    js .out
    lea rdi, [mod_log_reason_label]
    mov esi, mod_log_reason_label_len
    call report_append_bytes
    test eax, eax
    js .out
    mov rdi, [rsp]
    mov esi, [rsp + 8]
    test rdi, rdi
    jz .default_reason
    test esi, esi
    jle .default_reason
    cmp esi, AUTOMOD_LOG_TEXT_CAP
    jbe .reason_cap_ready
    mov esi, AUTOMOD_LOG_TEXT_CAP
.reason_cap_ready:
    call automod_append_sanitized
    test eax, eax
    js .out
    jmp .send
.default_reason:
    lea rdi, [mod_log_default_reason]
    mov esi, mod_log_default_reason_len
    call report_append_bytes
    test eax, eax
    js .out
.send:
    lea rdi, [report_log_channel]
    mov esi, r13d
    lea rdx, [report_log]
    mov ecx, [report_log_len]
    call discord_send_text
.out:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Sends a bounded Automod audit line to the configured log channel only when the
; persisted channel ID is a valid nonzero decimal. Audit delivery cannot reverse
; a delete decision or prevent the user-facing Automod notice.
dispatch_log_automod:
    push rbx
    push r12
    push r13
    push r14
    push r15
    cmp dword [guild_id_len], 0
    jle .out
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [setting_log_channel]
    mov ecx, setting_log_channel_len
    call guild_config_get
    test rax, rax
    jz .out
    test edx, edx
    jle .out
    cmp edx, CHANNEL_ID_CAP - 1
    ja .out
    mov r12, rax
    mov r13d, edx
    mov rdi, r12
    mov esi, r13d
    call dispatch_is_nonzero_decimal_identifier
    test al, al
    jz .out
    lea rdi, [report_log_channel]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    mov dword [report_log_len], 0
    lea rdi, [automod_log_prefix]
    mov esi, automod_log_prefix_len
    call report_append_bytes
    test eax, eax
    js .out
    cmp dword [author_name_len], 0
    jle .author_id
    lea rdi, [author_name]
    mov esi, [author_name_len]
    jmp .author_append
.author_id:
    lea rdi, [author_id]
    mov esi, [author_id_len]
.author_append:
    call automod_append_sanitized
    test eax, eax
    js .out
    lea rdi, [automod_log_channel_label]
    mov esi, automod_log_channel_label_len
    call report_append_bytes
    test eax, eax
    js .out
    lea rdi, [channel_id]
    mov esi, [channel_id_len]
    call report_append_bytes
    test eax, eax
    js .out
    lea rdi, [automod_log_word_label]
    mov esi, automod_log_word_label_len
    call report_append_bytes
    test eax, eax
    js .out
    mov rdi, [automod_word_ptr]
    mov esi, [automod_word_len]
    call automod_append_sanitized
    test eax, eax
    js .out
    lea rdi, [automod_log_message_label]
    mov esi, automod_log_message_label_len
    call report_append_bytes
    test eax, eax
    js .out
    mov esi, [message_content_len]
    cmp esi, AUTOMOD_LOG_TEXT_CAP
    jbe .message_cap_ready
    mov esi, AUTOMOD_LOG_TEXT_CAP
.message_cap_ready:
    lea rdi, [message_content]
    call automod_append_sanitized
    test eax, eax
    js .out
    lea rdi, [automod_log_fence]
    mov esi, automod_log_fence_len
    call report_append_bytes
    test eax, eax
    js .out
    lea rdi, [report_log_channel]
    mov esi, r13d
    lea rdx, [report_log]
    mov ecx, [report_log_len]
    call discord_send_text
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=source, ESI=len. EAX=out len or -1. Control/non-ASCII bytes become '?';
; @ gains a UTF-8 zero-width separator and backticks become apostrophes, avoiding
; notifications and code-fence injection in a plain-text audit message.
automod_append_sanitized:
    test rdi, rdi
    jz .bad
    test esi, esi
    jl .bad
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    mov al, [rdi + rcx]
    cmp al, '@'
    je .at_sign
    cmp al, '`'
    je .backtick
    cmp al, 32
    jb .replacement
    cmp al, 126
    ja .replacement
    mov edx, [report_log_len]
    inc edx
    cmp edx, REPORT_LOG_CAP
    ja .bad
    mov [report_log + rdx - 1], al
    mov [report_log_len], edx
    inc ecx
    jmp .loop
.at_sign:
    mov edx, [report_log_len]
    add edx, 4
    cmp edx, REPORT_LOG_CAP
    ja .bad
    mov byte [report_log + rdx - 4], '@'
    mov byte [report_log + rdx - 3], 0xe2
    mov byte [report_log + rdx - 2], 0x80
    mov byte [report_log + rdx - 1], 0x8b
    mov [report_log_len], edx
    inc ecx
    jmp .loop
.backtick:
    mov al, 39
    jmp .store_replacement
.replacement:
    mov al, '?'
.store_replacement:
    mov edx, [report_log_len]
    inc edx
    cmp edx, REPORT_LOG_CAP
    ja .bad
    mov [report_log + rdx - 1], al
    mov [report_log_len], edx
    inc ecx
    jmp .loop
.done:
    mov eax, [report_log_len]
    ret
.bad:
    mov eax, -1
    ret

; RDI=source, ESI=len. EAX=output len or -1 if report buffer cannot hold all bytes.
report_append_bytes:
    test rdi, rdi
    jz .bad
    test esi, esi
    jl .bad
    mov r8d, [report_log_len]
    mov eax, r8d
    add eax, esi
    cmp eax, REPORT_LOG_CAP
    ja .bad
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .done
    mov dl, [rdi + rcx]
    mov [report_log + r8 + rcx], dl
    inc ecx
    jmp .copy
.done:
    add dword [report_log_len], esi
    mov eax, [report_log_len]
    ret
.bad:
    mov eax, -1
    ret

; RDI=source, ESI=len. Non-printable ASCII is replaced with '?'.
; EAX=output len or -1 if report buffer cannot hold all bytes.
report_append_sanitized:
    test rdi, rdi
    jz .bad
    test esi, esi
    jl .bad
    mov eax, [report_log_len]
    add eax, esi
    cmp eax, REPORT_LOG_CAP
    ja .bad
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .done
    mov dl, [rdi + rcx]
    cmp dl, 32
    jb .replace
    cmp dl, 126
    jbe .store
.replace:
    mov dl, '?'
.store:
    mov eax, [report_log_len]
    mov [report_log + rax], dl
    inc dword [report_log_len]
    inc ecx
    jmp .copy
.done:
    mov eax, [report_log_len]
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
key_username: db 'username'
key_username_len equ $ - key_username
key_member: db 'member'
key_member_len equ $ - key_member
key_roles: db 'roles'
key_roles_len equ $ - key_roles
key_id: db 'id'
key_id_len equ $ - key_id
key_content: db 'content'
key_content_len equ $ - key_content
key_gateway_data: db 'd'
key_gateway_data_len equ $ - key_gateway_data
automod_response: db 'Automod: message deleted for a banned word.'
automod_response_len equ $ - automod_response
automod_log_prefix: db 'AUTOMOD', 10, 'User: '
automod_log_prefix_len equ $ - automod_log_prefix
automod_log_channel_label: db 10, 'Channel: <#'
automod_log_channel_label_len equ $ - automod_log_channel_label
automod_log_word_label: db '>', 10, 'Kata Terlarang: ||'
automod_log_word_label_len equ $ - automod_log_word_label
automod_log_message_label: db '||', 10, 'Pesan: ```'
automod_log_message_label_len equ $ - automod_log_message_label
automod_log_fence: db '```'
automod_log_fence_len equ $ - automod_log_fence
mod_log_prefix: db 'MODERATION', 10, 'Action: '
mod_log_prefix_len equ $ - mod_log_prefix
mod_log_moderator_label: db 10, 'Moderator: '
mod_log_moderator_label_len equ $ - mod_log_moderator_label
mod_log_target_label: db 10, 'Target: '
mod_log_target_label_len equ $ - mod_log_target_label
mod_log_reason_label: db 10, 'Alasan: '
mod_log_reason_label_len equ $ - mod_log_reason_label
mod_log_default_reason: db 'Tidak ada alasan'
mod_log_default_reason_len equ $ - mod_log_default_reason
mod_reason_dash: db '-'
mod_reason_dash_len equ $ - mod_reason_dash
mod_action_kick: db 'Kick'
mod_action_kick_len equ $ - mod_action_kick
mod_action_ban: db 'Ban'
mod_action_ban_len equ $ - mod_action_ban
mod_action_unban: db 'Unban'
mod_action_unban_len equ $ - mod_action_unban
mod_action_timeout: db 'Timeout'
mod_action_timeout_len equ $ - mod_action_timeout
mod_action_warn: db 'Warn'
mod_action_warn_len equ $ - mod_action_warn
chat_log_prefix: db 'CHAT', 10, 'User: '
chat_log_prefix_len equ $ - chat_log_prefix
chat_log_unknown_user: db '(tidak diketahui)'
chat_log_unknown_user_len equ $ - chat_log_unknown_user
chat_log_channel_label: db 10, 'Channel: <#'
chat_log_channel_label_len equ $ - chat_log_channel_label
chat_log_question_label: db '>', 10, 'Pertanyaan: '
chat_log_question_label_len equ $ - chat_log_question_label
chat_log_empty: db '(kosong)'
chat_log_empty_len equ $ - chat_log_empty
chat_log_answer_label: db 10, 'Jawaban: '
chat_log_answer_label_len equ $ - chat_log_answer_label
report_usage_response: db 'Usage: report @user [reason].'
report_usage_response_len equ $ - report_usage_response
report_saved_response: db 'Report sent to the guild log channel.'
report_saved_response_len equ $ - report_saved_response
report_log_prefix: db 'REPORT', 10, 'Reporter: '
report_log_prefix_len equ $ - report_log_prefix
report_mention_prefix: db '<@'
report_mention_prefix_len equ $ - report_mention_prefix
report_target_label: db '>', 10, 'Target: <@'
report_target_label_len equ $ - report_target_label
report_reason_label: db '>', 10, 'Reason: '
report_reason_label_len equ $ - report_reason_label
report_default_reason: db 'Tidak ada alasan'
report_default_reason_len equ $ - report_default_reason
report_channel_label: db 10, 'Channel: '
report_channel_label_len equ $ - report_channel_label
report_channel_mention_prefix: db '<#'
report_channel_mention_prefix_len equ $ - report_channel_mention_prefix
report_channel_mention_suffix: db '>'
report_channel_mention_suffix_len equ $ - report_channel_mention_suffix
warn_usage_response: db 'Usage: warn/clearwarn @user.'
warn_usage_response_len equ $ - warn_usage_response
clearwarn_response: db 'Warnings cleared.'
clearwarn_response_len equ $ - clearwarn_response
clear_usage_response: db 'Usage: clear [1-99].'
clear_usage_response_len equ $ - clear_usage_response
clear_success_response: db 'Messages cleared.'
clear_success_response_len equ $ - clear_success_response
clear_empty_response: db 'No eligible messages to clear.'
clear_empty_response_len equ $ - clear_empty_response
warning_reply_prefix: db 'Warnings: '
warning_reply_prefix_len equ $ - warning_reply_prefix
warning_reply_suffix: db '.'
warning_reply_suffix_len equ $ - warning_reply_suffix
help_response: db '**Hai sayang! Ini cara pakai aku:**\n`Caine <pertanyaan>` - tanya apapun\n`Caine` + kirim gambar - analisis gambar\n`Caine summarize [jumlah]` - rangkum chat\n`Caine report @user alasan` - laporin user\n`Caine reset` - hapus memory\n`Caine afk [alasan]` - set AFK\n`Caine afklist` - lihat siapa yang AFK\n`Caine rank [@user]` - lihat rank/XP\n`Caine leaderboard` - top 10 XP\n`Caine status` - status bot\n`Caine setmodel <alias>` - ganti model AI\n`Caine sethistory <angka>` - set batas history chat\n`/info` - info bot\n`/dashboard` - buka dashboard (admin)\n\n**Moderasi:** kick, ban, unban, timeout, untimeout, warn, warnings, clearwarn, clear, lock, unlock, slowmode, nick, role add/remove\n\n**Admin:** addword, removeword, words, enable, disable, setlog, setwelcome, setgoodbye, setwelcomemsg, setgoodbyemsg, autorole, removeautorole, setlevelchannel, setpersona, setmodel, sethistory'
help_response_len equ $ - help_response
status_prefix: db 0xf0, 0x9f, 0x93, 0x8a, ' **Status Bot**', 10, 0xe2, 0x8f, 0xb1, ' Uptime: '
status_prefix_len equ $ - status_prefix
status_servers_label: db 10, 0xf0, 0x9f, 0x8c, 0x90, ' Servers: '
status_servers_label_len equ $ - status_servers_label
status_uptime_fallback: db '0d 0h 0m 0s'
status_uptime_fallback_len equ $ - status_uptime_fallback
reset_response: db 0xf0, 0x9f, 0xa7, 0xb9, ' Memory kita udah di-reset sayang!'
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
ai_rate_limited_response: db 'AI rate limit reached. Please wait before sending another request.'
ai_rate_limited_response_len equ $ - ai_rate_limited_response
kick_usage_response: db 'Usage: kick <@user>'
kick_usage_response_len equ $ - kick_usage_response
kick_success_response: db 'User kicked.'
kick_success_response_len equ $ - kick_success_response
lock_success_response: db 'Channel locked.'
lock_success_response_len equ $ - lock_success_response
unlock_success_response: db 'Channel unlocked.'
unlock_success_response_len equ $ - unlock_success_response
slowmode_usage_response: db 'Usage: slowmode <0-21600>'
slowmode_usage_response_len equ $ - slowmode_usage_response
slowmode_success_response: db 'Slowmode updated.'
slowmode_success_response_len equ $ - slowmode_success_response
ban_usage_response: db 'Usage: ban <@user>'
ban_usage_response_len equ $ - ban_usage_response
ban_success_response: db 'User banned.'
ban_success_response_len equ $ - ban_success_response
timeout_usage_response: db 'Usage: timeout <@user> <1-40320 minutes> [reason]'
timeout_usage_response_len equ $ - timeout_usage_response
timeout_success_response: db 'User timed out.'
timeout_success_response_len equ $ - timeout_success_response
untimeout_usage_response: db 'Usage: untimeout <@user>'
untimeout_usage_response_len equ $ - untimeout_usage_response
untimeout_success_response: db 'User timeout removed.'
untimeout_success_response_len equ $ - untimeout_success_response
nick_usage_response: db 'Usage: nick <@user> <nickname>'
nick_usage_response_len equ $ - nick_usage_response
nick_success_response: db 'Nickname changed.'
nick_success_response_len equ $ - nick_success_response
role_command_usage_response: db 'Usage: role add|remove <@user> <@&role>'
role_command_usage_response_len equ $ - role_command_usage_response
role_add_success_response: db 'Role added.'
role_add_success_response_len equ $ - role_add_success_response
role_remove_success_response: db 'Role removed.'
role_remove_success_response_len equ $ - role_remove_success_response
unban_usage_response: db 'Usage: unban <user-id>'
unban_usage_response_len equ $ - unban_usage_response
unban_success_response: db 'User unbanned.'
unban_success_response_len equ $ - unban_success_response
bot_denied_response: db 'Bot lacks the required effective channel permission.'
bot_denied_response_len equ $ - bot_denied_response
moderation_error_response: db 'Moderation request failed.'
moderation_error_response_len equ $ - moderation_error_response
hierarchy_denied_response: db 'Bot cannot moderate this target due to role hierarchy or incomplete member state.'
hierarchy_denied_response_len equ $ - hierarchy_denied_response
chat_default_prompt: db 'Someone called you. Reply with a concise friendly greeting.'
chat_default_prompt_len equ $ - chat_default_prompt
key_message_reference: db 'message_reference'
key_message_reference_len equ $ - key_message_reference
key_message_id: db 'message_id'
key_message_id_len equ $ - key_message_id
reply_reference_url_prefix: db 'https://discord.com/api/v10/channels/'
reply_reference_url_prefix_len equ $ - reply_reference_url_prefix
reply_reference_url_middle: db '/messages/'
reply_reference_url_middle_len equ $ - reply_reference_url_middle
target_member_url_prefix: db 'https://discord.com/api/v10/guilds/'
target_member_url_prefix_len equ $ - target_member_url_prefix
target_member_url_middle: db '/members/'
target_member_url_middle_len equ $ - target_member_url_middle
history_server_prefix: db 'server-'
history_server_prefix_len equ $ - history_server_prefix
history_dm_prefix: db 'dm-'
history_dm_prefix_len equ $ - history_dm_prefix
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
attachment_url: resb ATTACHMENT_URL_CAP
attachment_url_len: resd 1
attachment_mime: resb ATTACHMENT_MIME_CAP
attachment_mime_len: resd 1
vision_image: resb VISION_IMAGE_CAP
vision_image_len: resd 1
vision_b64: resb VISION_B64_CAP
vision_b64_len: resd 1
channel_id: resb CHANNEL_ID_CAP
guild_id: resb GUILD_ID_CAP
author_id: resb AUTHOR_ID_CAP
author_name: resb AUTHOR_NAME_CAP
argument_buffer: resb COMMAND_CAP
guild_id_len: resd 1
channel_id_len: resd 1
author_id_len: resd 1
author_name_len: resd 1
message_content_len: resd 1
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
automod_message_id: resb AUTHOR_ID_CAP
automod_word_ptr: resq 1
automod_word_len: resd 1
warning_target_len: resd 1
moderation_target_len: resd 1
moderation_reason_ptr: resq 1
moderation_reason_len: resd 1
timeout_target_len: resd 1
timeout_minutes: resd 1
timeout_target: resb AUTHOR_ID_CAP
nick_target_len: resd 1
nick_value_len: resd 1
nick_target: resb AUTHOR_ID_CAP
nick_value: resb 128
role_target_len: resd 1
role_requested_len: resd 1
role_action: resd 1
role_requested_position: resd 1
role_target: resb AUTHOR_ID_CAP
role_requested: resb AUTHOR_ID_CAP
report_target_len: resd 1
report_log_len: resd 1
report_log_channel: resb CHANNEL_ID_CAP
report_log: resb REPORT_LOG_CAP
warning_reply: resb 64
rank_response: resb 32
rank_scratch: resb 10
status_uptime: resb STATUS_UPTIME_CAP
status_uptime_len: resd 1
status_reply: resb STATUS_REPLY_CAP
message_content: resb MESSAGE_CONTENT_CAP
command_buffer: resb COMMAND_CAP
ai_reply: resb AI_REPLY_CAP
ai_reply_len: resd 1
state_view_reply: resb STATE_VIEW_REPLY_CAP
history_key_len: resd 1
command_start: resd 1
history_key: resb HISTORY_KEY_CAP
reply_reference_id: resb REPLY_REFERENCE_ID_CAP
reply_reference_id_len: resd 1
reply_reference_url: resb REPLY_REFERENCE_URL_CAP
reply_reference_url_len: resd 1
reply_reference_response: resb REPLY_REFERENCE_RESPONSE_CAP
reply_reference_response_len: resd 1
reply_reference_author_id: resb AUTHOR_ID_CAP
target_member_url: resb TARGET_MEMBER_URL_CAP
target_member_url_len: resd 1
target_member_response: resb TARGET_MEMBER_RESPONSE_CAP
target_member_response_len: resd 1
clear_snapshot_len: resd 1
clear_amount: resd 1
clear_fetch_limit: resd 1
clear_batch_count: resd 1
clear_invocation_id_len: resd 1
clear_invocation_found: resd 1
clear_current_id_len: resd 1
clear_json_depth: resd 1
clear_snapshot: resb CLEAR_RESPONSE_CAP
clear_string_scratch: resb CLEAR_RESPONSE_CAP
clear_invocation_id: resb CLEAR_ID_CAP
clear_current_id: resb CLEAR_ID_CAP
clear_message_ids: resb CLEAR_BATCH_MAX * CLEAR_ID_CAP
clear_message_id_lens: resd CLEAR_BATCH_MAX
clear_seen_ids: resb CLEAR_BATCH_MAX * CLEAR_ID_CAP

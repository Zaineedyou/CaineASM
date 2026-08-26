BITS 64
DEFAULT REL

extern dispatch_message_create

global _start
global discord_send_text
global discord_delete_message
global groq_chat_once
global groq_vision_once
global attachment_extract_image_url
global attachment_copy_image_mime
global attachment_fetch_https
global base64_encode
global groq_select_guild
global groq_select_history
global history_clear
global ai_rate_allow
global afk_set
global xp_increment
global xp_get
global afk_clear
global state_format_afk_list
global state_format_leaderboard
global state_format_banned_words
global guild_auth_is_manager
global guild_auth_roles_have
global guild_word_add
global guild_word_remove
global guild_word_matches
global guild_channel_disable
global guild_channel_enable
global guild_channel_is_disabled
global guild_config_set
global guild_config_get
global guild_config_delete
global warnings_add
global warnings_get
global warnings_clear
global bot_prefix_ptr
global bot_prefix_len

%define SYS_EXIT 60

section .text
_start:
    mov qword [bot_prefix_ptr], 0
    mov dword [bot_prefix_len], 0
    mov qword [send_calls], 0
    lea rax, [groq_prompt]
    mov [expected_groq_ptr], rax
    mov dword [expected_groq_len], groq_prompt_len

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
    cmp qword [groq_select_calls], 1
    jne .fail
    cmp qword [groq_history_select_calls], 1
    jne .fail
    cmp qword [history_clear_calls], 1
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

    mov dword [failure_stage], 14
    lea rax, [persona_saved_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], persona_saved_response_len
    lea rax, [setting_persona]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_persona_len
    lea rax, [persona_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], persona_value_len
    lea rdi, [persona_event]
    mov esi, persona_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 12
    jne .fail
    cmp qword [config_set_calls], 1
    jne .fail

    mov dword [failure_stage], 15
    lea rax, [history_saved_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], history_saved_response_len
    lea rax, [setting_history]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_history_len
    lea rax, [history_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], history_value_len
    lea rdi, [history_event]
    mov esi, history_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 13
    jne .fail
    cmp qword [config_set_calls], 2
    jne .fail

    mov dword [failure_stage], 16
    lea rax, [model_saved_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], model_saved_response_len
    lea rax, [setting_model]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_model_len
    lea rax, [model_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], model_value_len
    lea rdi, [model_event]
    mov esi, model_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 14
    jne .fail
    cmp qword [config_set_calls], 3
    jne .fail

    mov dword [failure_stage], 17
    lea rax, [channel_saved_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], channel_saved_response_len
    lea rax, [setting_log_channel]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_log_channel_len
    lea rax, [log_channel_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], log_channel_value_len
    lea rdi, [setlog_event]
    mov esi, setlog_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 15
    jne .fail
    cmp qword [config_set_calls], 4
    jne .fail

    mov dword [failure_stage], 18
    lea rax, [role_saved_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], role_saved_response_len
    lea rax, [setting_autorole]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_autorole_len
    lea rax, [role_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], role_value_len
    lea rdi, [autorole_event]
    mov esi, autorole_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 16
    jne .fail
    cmp qword [config_set_calls], 5
    jne .fail

    mov dword [failure_stage], 19
    lea rax, [role_removed_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], role_removed_response_len
    lea rdi, [removeautorole_event]
    mov esi, removeautorole_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 17
    jne .fail
    cmp qword [config_delete_calls], 1
    jne .fail

    mov dword [failure_stage], 20
    lea rax, [text_saved_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], text_saved_response_len
    lea rax, [setting_welcome_message]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_welcome_message_len
    lea rax, [welcome_message_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], welcome_message_value_len
    lea rdi, [welcomemsg_event]
    mov esi, welcomemsg_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 18
    jne .fail
    cmp qword [config_set_calls], 6
    jne .fail

    mov dword [failure_stage], 21
    mov dword [automod_enabled], 1
    lea rax, [automod_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], automod_response_len
    lea rdi, [automod_event]
    mov esi, automod_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 1
    jne .fail
    cmp qword [send_calls], 19
    jne .fail
    mov dword [automod_enabled], 0

    mov dword [failure_stage], 22
    lea rax, [warning_reply]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], warning_reply_len
    lea rdi, [warn_event]
    mov esi, warn_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [warnings_add_calls], 1
    jne .fail
    cmp qword [send_calls], 20
    jne .fail

    mov dword [failure_stage], 23
    lea rdi, [warnings_event]
    mov esi, warnings_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [warnings_get_calls], 1
    jne .fail
    cmp qword [send_calls], 21
    jne .fail

    mov dword [failure_stage], 24
    lea rax, [clearwarn_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], clearwarn_response_len
    lea rdi, [clearwarn_event]
    mov esi, clearwarn_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [warnings_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 22
    jne .fail

    mov dword [failure_stage], 25
    lea rax, [report_log_channel_value]
    mov [expected_channel_ptr], rax
    mov dword [expected_channel_len], report_log_channel_value_len
    lea rax, [report_log_text]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], report_log_text_len
    mov dword [report_log_enabled], 1
    mov dword [report_followup_enabled], 1
    lea rdi, [report_event]
    mov esi, report_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [config_get_calls], 1
    jne .fail
    cmp qword [send_calls], 24
    jne .fail

    mov dword [failure_stage], 26
    mov dword [report_log_enabled], 0
    lea rdi, [report_event]
    mov esi, report_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [config_get_calls], 2
    jne .fail
    cmp qword [send_calls], 25
    jne .fail

    mov dword [failure_stage], 27
    lea rax, [ai_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], ai_response_len
    lea rax, [chat_prompt]
    mov [expected_groq_ptr], rax
    mov dword [expected_groq_len], chat_prompt_len
    lea rdi, [chat_event]
    mov esi, chat_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [groq_calls], 2
    jne .fail
    cmp qword [groq_select_calls], 2
    jne .fail
    cmp qword [groq_history_select_calls], 2
    jne .fail
    cmp qword [send_calls], 26
    jne .fail

    ; A recognized future moderation command remains explicitly inactive.
    mov dword [failure_stage], 28
    lea rax, [registered_notice]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], registered_notice_len
    lea rdi, [unknown_event]
    mov esi, unknown_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 27
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; RDI=guild, ESI=guild len. The fixture only records that summarize selects context.
groq_select_guild:
    inc qword [groq_select_calls]
    xor eax, eax
    ret

groq_select_history:
    inc qword [groq_history_select_calls]
    xor eax, eax
    ret

history_clear:
    inc qword [history_clear_calls]
    xor eax, eax
    ret

ai_rate_allow:
    mov al, 1
    ret

; RDI=prompt, ESI=length, RDX=reply destination, ECX=capacity.
groq_chat_once:
    mov r10, rdx
    mov r11d, ecx
    cmp esi, [expected_groq_len]
    jne .bad
    mov r8, [expected_groq_ptr]
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

; Text fixtures do not carry an image; vision seams reject and dispatch falls back to Groq text.
attachment_extract_image_url:
    mov eax, -1
    ret
attachment_copy_image_mime:
    mov eax, -1
    ret
attachment_fetch_https:
    mov eax, -1
    ret
base64_encode:
    mov eax, -1
    ret
groq_vision_once:
    mov eax, -1
    ret

; RDI=guild, ESI=guild length, RDX=user, ECX=user length. EAX=current score.
xp_get:
    mov eax, 42
    ret

afk_clear:
    xor eax, eax
    ret

; Automod seam returns a configured banned-word marker only for its dedicated vector.
guild_word_matches:
    cmp dword [automod_enabled], 1
    jne .no_match
    lea rax, [blocked_word]
    mov edx, blocked_word_len
    ret
.no_match:
    xor eax, eax
    xor edx, edx
    ret

discord_delete_message:
    push rbx
    mov rbx, rdx
    cmp esi, channel_id_len
    jne .bad
    lea r8, [channel_id]
    mov r9d, channel_id_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    cmp ecx, automod_message_id_len
    jne .bad
    mov rdi, rbx
    lea rsi, [automod_message_id]
    mov edx, automod_message_id_len
    call equal_bytes
    test al, al
    jz .bad
    inc qword [delete_calls]
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop rbx
    ret

; Role permission seam remains denied in the owner-focused fixture.
guild_auth_roles_have:
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

; RDI=guild, ESI=guild len, RDX=setting, ECX=setting len, R8=value, R9D=value len.
guild_config_set:
    push rbx
    push r12
    mov rbx, r8
    mov r12, rdx
    mov r11d, ecx
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r11d, [expected_config_setting_len]
    jne .bad
    mov rdi, r12
    mov rsi, [expected_config_setting_ptr]
    mov edx, r11d
    call equal_bytes
    test al, al
    jz .bad
    cmp r9d, [expected_config_value_len]
    jne .bad
    mov rdi, rbx
    mov rsi, [expected_config_value_ptr]
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [config_set_calls]
    xor eax, eax
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop r12
    pop rbx
    ret

guild_config_get:
    inc qword [config_get_calls]
    cmp dword [report_log_enabled], 0
    je .absent
    lea rax, [report_log_channel_value]
    mov edx, report_log_channel_value_len
    ret
.absent:
    xor eax, eax
    xor edx, edx
    ret

guild_config_delete:
    inc qword [config_delete_calls]
    xor eax, eax
    ret

warnings_add:
    inc qword [warnings_add_calls]
    mov eax, 3
    ret
warnings_get:
    inc qword [warnings_get_calls]
    mov eax, 3
    ret
warnings_clear:
    inc qword [warnings_clear_calls]
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
    mov r8, [expected_channel_ptr]
    test r8, r8
    jnz .expected_channel
    lea r8, [channel_id]
    mov r9d, channel_id_len
    jmp .channel_ready
.expected_channel:
    mov r9d, [expected_channel_len]
.channel_ready:
    cmp esi, r9d
    jne .bad
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
    cmp dword [report_followup_enabled], 0
    je .ok
    mov dword [report_followup_enabled], 0
    mov qword [expected_channel_ptr], 0
    mov dword [expected_channel_len], 0
    lea rax, [report_saved_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], report_saved_response_len
.ok:
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
chat_prompt: db 'how are you'
chat_prompt_len equ $ - chat_prompt
ai_response: db 'AI summary'
ai_response_len equ $ - ai_response
unknown_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"^kick","author":{"bot":false}}}'
unknown_event_len equ $ - unknown_event
addword_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^addword BaD","author":{"id":"user-2","bot":false}}}'
addword_event_len equ $ - addword_event
words_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^words","author":{"id":"user-2","bot":false}}}'
words_event_len equ $ - words_event
disable_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^disable","author":{"id":"user-2","bot":false}}}'
disable_event_len equ $ - disable_event
enable_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^enable","author":{"id":"user-2","bot":false}}}'
enable_event_len equ $ - enable_event
persona_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^setpersona Caine santai","author":{"id":"user-2","bot":false}}}'
persona_event_len equ $ - persona_event
history_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^sethistory 30","author":{"id":"user-2","bot":false}}}'
history_event_len equ $ - history_event
model_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^setmodel GPT120B","author":{"id":"user-2","bot":false}}}'
model_event_len equ $ - model_event
setlog_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^setlog <#987654>","author":{"id":"user-2","bot":false}}}'
setlog_event_len equ $ - setlog_event
autorole_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^autorole <@&111222>","author":{"id":"user-2","bot":false}}}'
autorole_event_len equ $ - autorole_event
removeautorole_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^removeautorole","author":{"id":"user-2","bot":false}}}'
removeautorole_event_len equ $ - removeautorole_event
welcomemsg_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^setwelcomemsg Welcome {user}","author":{"id":"user-2","bot":false}}}'
welcomemsg_event_len equ $ - welcomemsg_event
automod_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"id":"998877665544332211","guild_id":"guild-1","channel_id":"123456789012345678","content":"blocked content","author":{"id":"user-2","bot":false}}}'
automod_event_len equ $ - automod_event
warn_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^warn <@555> reason","author":{"id":"user-2","bot":false}}}'
warn_event_len equ $ - warn_event
warnings_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^warnings <@555>","author":{"id":"user-2","bot":false}}}'
warnings_event_len equ $ - warnings_event
clearwarn_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^clearwarn <@555>","author":{"id":"user-2","bot":false}}}'
clearwarn_event_len equ $ - clearwarn_event
report_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^report <@555> flooding chat","author":{"id":"112233445566778899","bot":false}}}'
report_event_len equ $ - report_event
chat_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^how are you","author":{"id":"112233445566778899","bot":false}}}'
chat_event_len equ $ - chat_event
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
persona_saved_response: db 'Guild persona saved.'
persona_saved_response_len equ $ - persona_saved_response
history_saved_response: db 'Guild history limit saved.'
history_saved_response_len equ $ - history_saved_response
setting_persona: db 'system_prompt'
setting_persona_len equ $ - setting_persona
setting_history: db 'max_history'
setting_history_len equ $ - setting_history
persona_value: db 'Caine santai'
persona_value_len equ $ - persona_value
history_value: db '30'
history_value_len equ $ - history_value
model_value: db 'openai/gpt-oss-120b'
model_value_len equ $ - model_value
model_saved_response: db 'Guild model saved.'
model_saved_response_len equ $ - model_saved_response
setting_model: db 'model'
setting_model_len equ $ - setting_model
setting_log_channel: db 'log_channel'
setting_log_channel_len equ $ - setting_log_channel
setting_autorole: db 'auto_role'
setting_autorole_len equ $ - setting_autorole
setting_welcome_message: db 'welcome_msg'
setting_welcome_message_len equ $ - setting_welcome_message
log_channel_value: db '987654'
log_channel_value_len equ $ - log_channel_value
role_value: db '111222'
role_value_len equ $ - role_value
welcome_message_value: db 'Welcome {user}'
welcome_message_value_len equ $ - welcome_message_value
channel_saved_response: db 'Guild channel setting saved.'
channel_saved_response_len equ $ - channel_saved_response
role_saved_response: db 'Guild auto-role saved.'
role_saved_response_len equ $ - role_saved_response
role_removed_response: db 'Guild auto-role removed.'
role_removed_response_len equ $ - role_removed_response
text_saved_response: db 'Guild message setting saved.'
text_saved_response_len equ $ - text_saved_response
automod_response: db 'Automod: message deleted for a banned word.'
automod_response_len equ $ - automod_response
blocked_word: db 'blocked'
blocked_word_len equ $ - blocked_word
automod_message_id: db '998877665544332211'
automod_message_id_len equ $ - automod_message_id
warning_reply: db 'Warnings: 3.'
warning_reply_len equ $ - warning_reply
clearwarn_response: db 'Warnings cleared.'
clearwarn_response_len equ $ - clearwarn_response
report_saved_response: db 'Report sent to the guild log channel.'
report_saved_response_len equ $ - report_saved_response
report_log_text: db 'REPORT', 10, 'Reporter: <@112233445566778899>', 10, 'Target: <@555>', 10, 'Reason: flooding chat', 10, 'Channel: <#123456789012345678>'
report_log_text_len equ $ - report_log_text
report_log_channel_value: db '998877665544332211'
report_log_channel_value_len equ $ - report_log_channel_value

section .data
bot_prefix_ptr: dq 0
bot_prefix_len: dd 0
expected_text_ptr: dq 0
expected_text_len: dd 0
expected_config_setting_ptr: dq 0
expected_config_setting_len: dd 0
expected_config_value_ptr: dq 0
expected_config_value_len: dd 0
send_calls: dq 0
groq_calls: dq 0
groq_history_select_calls: dq 0
history_clear_calls: dq 0
expected_groq_ptr: dq 0
expected_groq_len: dd 0
groq_select_calls: dq 0
afk_calls: dq 0
xp_calls: dq 0
word_add_calls: dq 0
word_remove_calls: dq 0
channel_disable_calls: dq 0
channel_enable_calls: dq 0
config_set_calls: dq 0
config_delete_calls: dq 0
config_get_calls: dq 0
expected_channel_ptr: dq 0
expected_channel_len: dd 0
report_followup_enabled: dd 0
report_log_enabled: dd 0
delete_calls: dq 0
automod_enabled: dd 0
warnings_add_calls: dq 0
warnings_get_calls: dq 0
warnings_clear_calls: dq 0
failure_stage: dd 0

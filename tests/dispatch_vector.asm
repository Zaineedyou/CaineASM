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
global channel_auth_resolve
global guild_auth_get_bot_roles
global guild_auth_bot_above_roles
global guild_auth_role_position
global guild_auth_member_highest_position
global discord_unban_member
global discord_kick_member
global discord_ban_member
global discord_lock_channel
global discord_unlock_channel
global discord_set_slowmode
global discord_set_member_timeout
global discord_clear_member_timeout
global discord_set_member_nick
global discord_add_member_role
global discord_remove_member_role
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
global gateway_bot_user_id
global gateway_bot_user_id_len
global gateway_guild_count
global gateway_uptime_format
global discord_get_json
global discord_get_channel_messages
global discord_bulk_delete_messages

%define SYS_EXIT 60
%define SYS_TIME 201
%define VISION_NONE 0
%define VISION_OK 1
%define VISION_FETCH_FAIL 2
%define REPLY_NONE 0
%define REPLY_BOT 1
%define REPLY_OTHER 2
%define REPLY_ERROR 3
%define TARGET_NONE 0
%define TARGET_VALID 1
%define TARGET_MALFORMED 2
%define TARGET_ERROR 3
%define CLEAR_SNAPSHOT_NONE 0
%define CLEAR_SNAPSHOT_SAFE 1
%define CLEAR_SNAPSHOT_OLD 2
%define CLEAR_SNAPSHOT_DUPLICATE 3
%define CLEAR_SNAPSHOT_MALFORMED 4

section .text
_start:
    mov qword [bot_prefix_ptr], 0
    mov dword [bot_prefix_len], 0
    mov qword [send_calls], 0
    mov dword [vision_mode], VISION_NONE
    mov dword [vision_sequence], 0
    mov byte [rate_allowed], 1
    mov dword [reply_mode], REPLY_NONE
    mov dword [clear_snapshot_mode], CLEAR_SNAPSHOT_NONE
    mov qword [clear_get_calls], 0
    mov qword [clear_bulk_calls], 0
    mov eax, SYS_TIME
    xor edi, edi
    syscall
    test rax, rax
    jle .fail
    imul rax, rax, 1000
    mov r8, 1420070400000
    sub rax, r8
    js .fail
    imul rax, rax, 4194304
    jo .fail
    mov [clear_test_snowflake], rax
    call build_clear_runtime_fixture
    test eax, eax
    js .fail
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
    cmp qword [config_get_calls], 3
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
    cmp qword [config_get_calls], 4
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

    ; A valid explicit prefix plus a whitelisted image executes parser → MIME
    ; → fetch → Base64 → vision exactly once and does not call text Groq.
    mov dword [failure_stage], 28
    mov dword [vision_mode], VISION_OK
    mov dword [vision_sequence], 0
    lea rax, [vision_prompt]
    mov [expected_vision_ptr], rax
    mov dword [expected_vision_len], vision_prompt_len
    lea rax, [ai_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], ai_response_len
    lea rdi, [vision_event]
    mov esi, vision_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp dword [vision_sequence], 5
    jne .fail
    cmp qword [vision_calls], 1
    jne .fail
    cmp qword [groq_calls], 2
    jne .fail
    cmp qword [send_calls], 27
    jne .fail

    ; A prefix-only image is still explicitly triggered and uses the bounded
    ; default prompt; arbitrary image uploads remain ignored below.
    mov dword [failure_stage], 29
    mov dword [vision_sequence], 0
    lea rax, [vision_default_prompt]
    mov [expected_vision_ptr], rax
    mov dword [expected_vision_len], vision_default_prompt_len
    lea rdi, [vision_empty_event]
    mov esi, vision_empty_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp dword [vision_sequence], 5
    jne .fail
    cmp qword [vision_calls], 2
    jne .fail
    cmp qword [send_calls], 28
    jne .fail

    ; Cached READY identity permits the mention trigger without a prefix.
    mov dword [failure_stage], 30
    lea rdi, [gateway_bot_user_id]
    lea rsi, [bot_user_id]
    mov edx, bot_user_id_len
    call copy_bytes
    mov dword [gateway_bot_user_id_len], bot_user_id_len
    mov dword [vision_sequence], 0
    lea rax, [mention_vision_prompt]
    mov [expected_vision_ptr], rax
    mov dword [expected_vision_len], mention_vision_prompt_len
    lea rdi, [mention_vision_event]
    mov esi, mention_vision_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp dword [vision_sequence], 5
    jne .fail
    cmp qword [vision_calls], 3
    jne .fail
    cmp qword [send_calls], 29
    jne .fail

    ; Reply-to-bot makes exactly one bounded GET, verifies the fetched author
    ; against READY identity, then enters the ordinary text AI route.
    mov dword [failure_stage], 301
    mov dword [reply_mode], REPLY_BOT
    lea rax, [reply_prompt]
    mov [expected_groq_ptr], rax
    mov dword [expected_groq_len], reply_prompt_len
    lea rax, [ai_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], ai_response_len
    lea rdi, [reply_to_bot_event]
    mov esi, reply_to_bot_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [reply_get_calls], 1
    jne .fail
    cmp qword [groq_calls], 3
    jne .fail
    cmp qword [send_calls], 30
    jne .fail

    ; A reference to another author is ignored after its single GET; it cannot
    ; invoke AI or send a response.
    mov dword [failure_stage], 302
    mov dword [reply_mode], REPLY_OTHER
    lea rdi, [reply_to_bot_event]
    mov esi, reply_to_bot_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [reply_get_calls], 2
    jne .fail
    cmp qword [groq_calls], 3
    jne .fail
    cmp qword [send_calls], 30
    jne .fail

    ; Transport/API failure on the one permitted reference GET also fails
    ; closed: no Groq call and no reply are emitted.
    mov dword [failure_stage], 303
    mov dword [reply_mode], REPLY_ERROR
    lea rdi, [reply_to_bot_event]
    mov esi, reply_to_bot_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [reply_get_calls], 3
    jne .fail
    cmp qword [groq_calls], 3
    jne .fail
    cmp qword [send_calls], 30
    jne .fail
    mov dword [reply_mode], REPLY_NONE

    ; After an image is selected, fetch failure must report AI failure and
    ; never silently fall back to a text completion or a vision call.
    mov dword [failure_stage], 31
    mov dword [vision_mode], VISION_FETCH_FAIL
    mov dword [vision_sequence], 0
    lea rax, [ai_error_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], ai_error_response_len
    lea rdi, [vision_event]
    mov esi, vision_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    mov dword [failure_stage], 312
    cmp dword [vision_sequence], 3
    jne .fail
    mov dword [failure_stage], 313
    cmp qword [vision_calls], 3
    jne .fail
    mov dword [failure_stage], 314
    cmp qword [groq_calls], 3
    jne .fail
    mov dword [failure_stage], 315
    cmp qword [send_calls], 31
    jne .fail

    ; The limiter runs before attachment handling, so a denied request has no
    ; parser/fetch/Base64/vision work and receives the bounded limiter reply.
    mov dword [failure_stage], 32
    mov byte [rate_allowed], 0
    mov dword [vision_mode], VISION_OK
    mov dword [vision_sequence], 0
    lea rax, [ai_rate_limited_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], ai_rate_limited_response_len
    lea rdi, [vision_event]
    mov esi, vision_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp dword [vision_sequence], 0
    jne .fail
    cmp qword [vision_calls], 3
    jne .fail
    cmp qword [send_calls], 32
    jne .fail
    mov byte [rate_allowed], 1

    ; An image without prefix or bot mention is ignored before parser work.
    mov dword [failure_stage], 33
    mov dword [vision_sequence], 0
    lea rdi, [untriggered_image_event]
    mov esi, untriggered_image_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp dword [vision_sequence], 0
    jne .fail
    cmp qword [vision_calls], 3
    jne .fail
    cmp qword [send_calls], 32
    jne .fail

    ; Kick is now gated by effective bot permission; with no cached bot
    ; permission it must fail closed without calling destructive REST.
    mov dword [failure_stage], 34
    mov dword [vision_mode], VISION_NONE
    lea rax, [admin_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], admin_denied_response_len
    lea rdi, [unknown_event]
    mov esi, unknown_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 33
    jne .fail

    ; Unban requires the caller gate and a separate effective permission for
    ; the bot. Missing bot state must not reach the destructive REST route.
    mov dword [failure_stage], 35
    mov byte [bot_permission_enabled], 0
    lea rax, [bot_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], bot_denied_response_len
    lea rdi, [unban_event]
    mov esi, unban_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [unban_calls], 0
    jne .fail
    cmp qword [send_calls], 34
    jne .fail

    mov dword [failure_stage], 36
    mov byte [bot_permission_enabled], 1
    lea rax, [unban_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], unban_success_response_len
    lea rdi, [unban_event]
    mov esi, unban_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [unban_calls], 1
    jne .fail
    cmp qword [send_calls], 35
    jne .fail
    mov byte [bot_permission_enabled], 0

    mov dword [failure_stage], 37
    mov byte [bot_permission_enabled], 1
    lea rax, [lock_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], lock_success_response_len
    lea rdi, [lock_event]
    mov esi, lock_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [lock_calls], 1
    jne .fail
    cmp qword [send_calls], 36
    jne .fail

    mov dword [failure_stage], 38
    lea rax, [unlock_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], unlock_success_response_len
    lea rdi, [unlock_event]
    mov esi, unlock_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [unlock_calls], 1
    jne .fail
    cmp qword [send_calls], 37
    jne .fail
    mov byte [bot_permission_enabled], 0

    mov dword [failure_stage], 39
    mov byte [bot_permission_enabled], 1
    lea rax, [slowmode_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], slowmode_success_response_len
    lea rdi, [slowmode_event]
    mov esi, slowmode_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [slowmode_calls], 1
    jne .fail
    cmp qword [send_calls], 38
    jne .fail

    mov dword [failure_stage], 40
    mov byte [bot_permission_enabled], 0
    lea rax, [bot_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], bot_denied_response_len
    lea rdi, [slowmode_event]
    mov esi, slowmode_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [slowmode_calls], 1
    jne .fail
    cmp qword [send_calls], 39
    jne .fail

    mov dword [failure_stage], 41
    mov byte [bot_permission_enabled], 1
    lea rax, [slowmode_usage_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], slowmode_usage_response_len
    lea rdi, [slowmode_out_of_range_event]
    mov esi, slowmode_out_of_range_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [slowmode_calls], 1
    jne .fail
    cmp qword [send_calls], 40
    jne .fail
    mov byte [bot_permission_enabled], 0

    ; Kick/ban must make exactly one bounded target GET, require a complete
    ; roles array, then reach destructive REST only when strict hierarchy wins.
    mov dword [failure_stage], 42
    mov byte [bot_permission_enabled], 1
    mov dword [target_mode], TARGET_VALID
    mov byte [hierarchy_allowed], 1
    lea rax, [kick_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], kick_success_response_len
    lea rdi, [kick_target_event]
    mov esi, kick_target_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 1
    jne .fail
    cmp qword [hierarchy_calls], 1
    jne .fail
    cmp qword [kick_calls], 1
    jne .fail
    cmp qword [send_calls], 41
    jne .fail

    mov dword [failure_stage], 43
    mov byte [hierarchy_allowed], 0
    lea rax, [hierarchy_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], hierarchy_denied_response_len
    lea rdi, [ban_target_event]
    mov esi, ban_target_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 2
    jne .fail
    cmp qword [hierarchy_calls], 2
    jne .fail
    cmp qword [ban_calls], 0
    jne .fail
    cmp qword [send_calls], 42
    jne .fail

    mov dword [failure_stage], 44
    mov dword [target_mode], TARGET_MALFORMED
    lea rdi, [kick_target_event]
    mov esi, kick_target_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 3
    jne .fail
    cmp qword [hierarchy_calls], 2
    jne .fail
    cmp qword [kick_calls], 1
    jne .fail
    cmp qword [send_calls], 43
    jne .fail

    mov dword [failure_stage], 45
    mov dword [target_mode], TARGET_ERROR
    lea rdi, [ban_target_event]
    mov esi, ban_target_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 4
    jne .fail
    cmp qword [hierarchy_calls], 2
    jne .fail
    cmp qword [ban_calls], 0
    jne .fail
    cmp qword [send_calls], 44
    jne .fail
        mov dword [target_mode], TARGET_NONE
    ; Role uses ordered mention parsing plus caller/bot effective permission,
    ; one target-member GET, strict target hierarchy, and strict requested-role
    ; hierarchy before it can issue either REST mutation.
    mov dword [failure_stage], 46
    mov byte [bot_permission_enabled], 1
    mov dword [target_mode], TARGET_VALID
    mov byte [hierarchy_allowed], 1
    mov dword [role_position_value], 5
    mov dword [bot_highest_position], 10
    lea rax, [role_add_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], role_add_success_response_len
    lea rdi, [role_add_event]
    mov esi, role_add_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 5
    jne .fail
    cmp qword [hierarchy_calls], 3
    jne .fail
    cmp qword [role_position_calls], 1
    jne .fail
    cmp qword [bot_highest_calls], 1
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 0
    jne .fail
    cmp qword [send_calls], 45
    jne .fail

    mov dword [failure_stage], 47
    lea rax, [role_remove_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], role_remove_success_response_len
    lea rdi, [role_remove_event]
    mov esi, role_remove_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 6
    jne .fail
    cmp qword [hierarchy_calls], 4
    jne .fail
    cmp qword [role_position_calls], 2
    jne .fail
    cmp qword [bot_highest_calls], 2
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 46
    jne .fail

    mov dword [failure_stage], 48
    mov byte [bot_permission_enabled], 0
    lea rax, [bot_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], bot_denied_response_len
    lea rdi, [role_add_event]
    mov esi, role_add_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 6
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 47
    jne .fail

    mov dword [failure_stage], 49
    mov byte [bot_permission_enabled], 1
    mov byte [hierarchy_allowed], 0
    lea rax, [hierarchy_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], hierarchy_denied_response_len
    lea rdi, [role_add_event]
    mov esi, role_add_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 7
    jne .fail
    cmp qword [hierarchy_calls], 5
    jne .fail
    cmp qword [role_position_calls], 2
    jne .fail
    cmp qword [bot_highest_calls], 2
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 48
    jne .fail

    mov dword [failure_stage], 50
    mov byte [hierarchy_allowed], 1
    mov dword [target_mode], TARGET_MALFORMED
    lea rdi, [role_add_event]
    mov esi, role_add_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 8
    jne .fail
    cmp qword [hierarchy_calls], 5
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 49
    jne .fail

    mov dword [failure_stage], 51
    mov dword [target_mode], TARGET_ERROR
    lea rdi, [role_remove_event]
    mov esi, role_remove_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 9
    jne .fail
    cmp qword [hierarchy_calls], 5
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 50
    jne .fail

    mov dword [failure_stage], 52
    mov dword [target_mode], TARGET_VALID
    mov dword [role_position_value], 10
    mov dword [bot_highest_position], 10
    lea rdi, [role_add_event]
    mov esi, role_add_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 10
    jne .fail
    cmp qword [hierarchy_calls], 6
    jne .fail
    cmp qword [role_position_calls], 3
    jne .fail
    cmp qword [bot_highest_calls], 3
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 51
    jne .fail

    mov dword [failure_stage], 53
    mov dword [role_position_value], 11
    mov dword [bot_highest_position], 10
    lea rdi, [role_remove_event]
    mov esi, role_remove_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 11
    jne .fail
    cmp qword [hierarchy_calls], 7
    jne .fail
    cmp qword [role_position_calls], 4
    jne .fail
    cmp qword [bot_highest_calls], 4
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 52
    jne .fail

    mov dword [failure_stage], 54
    mov dword [role_position_value], -1
    lea rdi, [role_add_event]
    mov esi, role_add_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 12
    jne .fail
    cmp qword [hierarchy_calls], 8
    jne .fail
    cmp qword [role_position_calls], 5
    jne .fail
    cmp qword [bot_highest_calls], 4
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 53
    jne .fail

    mov dword [failure_stage], 55
    lea rax, [role_command_usage_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], role_command_usage_response_len
    lea rdi, [role_invalid_action_event]
    mov esi, role_invalid_action_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 12
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 54
    jne .fail

    mov dword [failure_stage], 56
    lea rdi, [role_malformed_mention_event]
    mov esi, role_malformed_mention_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 12
    jne .fail
    cmp qword [role_add_calls], 1
    jne .fail
    cmp qword [role_remove_calls], 1
    jne .fail
    cmp qword [send_calls], 55
    jne .fail

    ; Timeout and untimeout require caller+bot MODERATE_MEMBERS, a complete
    ; target GET, strict bot hierarchy, and ordered bounded command tokens.
    mov dword [failure_stage], 57
    mov byte [bot_permission_enabled], 1
    mov dword [target_mode], TARGET_VALID
    mov byte [hierarchy_allowed], 1
    lea rax, [timeout_success_response_test]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], timeout_success_response_test_len
    lea rdi, [timeout_event]
    mov esi, timeout_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 13
    jne .fail
    cmp qword [hierarchy_calls], 9
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 0
    jne .fail
    cmp qword [send_calls], 56
    jne .fail

    mov dword [failure_stage], 58
    lea rax, [untimeout_success_response_test]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], untimeout_success_response_test_len
    lea rdi, [untimeout_event]
    mov esi, untimeout_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 14
    jne .fail
    cmp qword [hierarchy_calls], 10
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 57
    jne .fail

    mov dword [failure_stage], 59
    mov byte [bot_permission_enabled], 0
    lea rax, [bot_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], bot_denied_response_len
    lea rdi, [timeout_event]
    mov esi, timeout_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 14
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 58
    jne .fail

    mov dword [failure_stage], 60
    mov byte [bot_permission_enabled], 1
    mov byte [hierarchy_allowed], 0
    lea rax, [hierarchy_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], hierarchy_denied_response_len
    lea rdi, [untimeout_event]
    mov esi, untimeout_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 15
    jne .fail
    cmp qword [hierarchy_calls], 11
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 59
    jne .fail

    mov dword [failure_stage], 61
    mov byte [hierarchy_allowed], 1
    lea rax, [timeout_usage_response_test]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], timeout_usage_response_test_len
    lea rdi, [timeout_invalid_event]
    mov esi, timeout_invalid_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 15
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 60
    jne .fail

    mov dword [failure_stage], 62
    lea rax, [untimeout_usage_response_test]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], untimeout_usage_response_test_len
    lea rdi, [untimeout_invalid_event]
    mov esi, untimeout_invalid_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 15
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 61
    jne .fail

    mov dword [failure_stage], 63
    mov dword [target_mode], TARGET_MALFORMED
    lea rax, [hierarchy_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], hierarchy_denied_response_len
    lea rdi, [timeout_event]
    mov esi, timeout_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 16
    jne .fail
    cmp qword [hierarchy_calls], 11
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 62
    jne .fail

    mov dword [failure_stage], 64
    mov dword [target_mode], TARGET_ERROR
    lea rdi, [untimeout_event]
    mov esi, untimeout_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 17
    jne .fail
    cmp qword [hierarchy_calls], 11
    jne .fail
    cmp qword [timeout_calls], 1
    jne .fail
    cmp qword [timeout_clear_calls], 1
    jne .fail
    cmp qword [send_calls], 63
    jne .fail

    mov dword [failure_stage], 65
    mov dword [target_mode], TARGET_VALID
    mov byte [hierarchy_allowed], 1
    lea rax, [nick_success_response_test]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], nick_success_response_test_len
    lea rdi, [nick_event]
    mov esi, nick_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 18
    jne .fail
    cmp qword [hierarchy_calls], 12
    jne .fail
    cmp qword [nick_calls], 1
    jne .fail
    cmp qword [send_calls], 64
    jne .fail

    mov dword [failure_stage], 66
    mov byte [bot_permission_enabled], 0
    lea rax, [bot_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], bot_denied_response_len
    lea rdi, [nick_event]
    mov esi, nick_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 18
    jne .fail
    cmp qword [nick_calls], 1
    jne .fail
    cmp qword [send_calls], 65
    jne .fail

    mov dword [failure_stage], 67
    mov byte [bot_permission_enabled], 1
    mov byte [hierarchy_allowed], 0
    lea rax, [hierarchy_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], hierarchy_denied_response_len
    lea rdi, [nick_event]
    mov esi, nick_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 19
    jne .fail
    cmp qword [hierarchy_calls], 13
    jne .fail
    cmp qword [nick_calls], 1
    jne .fail
    cmp qword [send_calls], 66
    jne .fail

    mov dword [failure_stage], 68
    mov byte [hierarchy_allowed], 1
    lea rax, [nick_usage_response_test]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], nick_usage_response_test_len
    lea rdi, [nick_invalid_event]
    mov esi, nick_invalid_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [target_get_calls], 19
    jne .fail
    cmp qword [nick_calls], 1
    jne .fail
    cmp qword [send_calls], 67
    jne .fail

    ; Clear requires effective MANAGE_MESSAGES for caller and bot, excludes
    ; the invocation itself, and will not mutate when a bounded snapshot is
    ; stale, duplicate, malformed, or otherwise uncertain.
    mov dword [failure_stage], 69
    mov byte [bot_permission_enabled], 1
    mov dword [clear_snapshot_mode], CLEAR_SNAPSHOT_SAFE
    lea rax, [clear_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], clear_success_response_len
    lea rdi, [clear_event_runtime]
    mov esi, [clear_event_runtime_len]
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [clear_get_calls], 1
    jne .fail
    cmp qword [clear_bulk_calls], 1
    jne .fail
    cmp qword [send_calls], 68
    jne .fail

    mov dword [failure_stage], 70
    lea rax, [clear_usage_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], clear_usage_response_len
    lea rdi, [clear_invalid_event]
    mov esi, clear_invalid_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [clear_get_calls], 1
    jne .fail
    cmp qword [clear_bulk_calls], 1
    jne .fail
    cmp qword [send_calls], 69
    jne .fail

    mov dword [failure_stage], 71
    mov dword [clear_snapshot_mode], CLEAR_SNAPSHOT_OLD
    lea rax, [moderation_error_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], moderation_error_response_len
    lea rdi, [clear_event]
    mov esi, clear_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [clear_get_calls], 2
    jne .fail
    cmp qword [clear_bulk_calls], 1
    jne .fail
    cmp qword [send_calls], 70
    jne .fail

    mov dword [failure_stage], 72
    mov dword [clear_snapshot_mode], CLEAR_SNAPSHOT_DUPLICATE
    lea rdi, [clear_event]
    mov esi, clear_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [clear_get_calls], 3
    jne .fail
    cmp qword [clear_bulk_calls], 1
    jne .fail
    cmp qword [send_calls], 71
    jne .fail

    mov dword [failure_stage], 73
    mov dword [clear_snapshot_mode], CLEAR_SNAPSHOT_MALFORMED
    lea rdi, [clear_event]
    mov esi, clear_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [clear_get_calls], 4
    jne .fail
    cmp qword [clear_bulk_calls], 1
    jne .fail
    cmp qword [send_calls], 72
    jne .fail

    mov dword [failure_stage], 74
    mov byte [bot_permission_enabled], 0
    lea rax, [bot_denied_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], bot_denied_response_len
    lea rdi, [clear_event]
    mov esi, clear_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [clear_get_calls], 4
    jne .fail
    cmp qword [clear_bulk_calls], 1
    jne .fail
    cmp qword [send_calls], 73
    jne .fail

    mov dword [failure_stage], 74
    mov dword [automod_enabled], 1
    mov dword [report_log_enabled], 1
    mov dword [automod_followup_enabled], 1
    lea rax, [report_log_channel_value]
    mov [expected_channel_ptr], rax
    mov dword [expected_channel_len], report_log_channel_value_len
    lea rax, [automod_audit_log]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], automod_audit_log_len
    lea rdi, [automod_audit_event]
    mov esi, automod_audit_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 2
    jne .fail
    cmp qword [config_get_calls], 13
    jne .fail
    cmp qword [send_calls], 75
    jne .fail

    mov dword [failure_stage], 75
    mov dword [report_log_enabled], 2
    mov qword [expected_channel_ptr], 0
    mov dword [expected_channel_len], 0
    lea rax, [automod_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], automod_response_len
    lea rdi, [automod_event]
    mov esi, automod_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 3
    jne .fail
    cmp qword [config_get_calls], 14
    jne .fail
    cmp qword [send_calls], 76
    jne .fail

    mov dword [failure_stage], 76
    mov dword [automod_enabled], 0
    mov dword [report_log_enabled], 1
    mov dword [chat_followup_enabled], 1
    lea rax, [ai_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], ai_response_len
    lea rax, [chat_audit_prompt]
    mov [expected_groq_ptr], rax
    mov dword [expected_groq_len], chat_audit_prompt_len
    lea rdi, [chat_audit_event]
    mov esi, chat_audit_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [groq_calls], 4
    jne .fail
    cmp qword [config_get_calls], 15
    jne .fail
    cmp qword [send_calls], 78
    jne .fail

    mov dword [failure_stage], 77
    mov dword [target_mode], TARGET_VALID
    mov byte [hierarchy_allowed], 1
    mov byte [bot_permission_enabled], 1
    lea rax, [report_log_channel_value]
    mov [expected_channel_ptr], rax
    mov dword [expected_channel_len], report_log_channel_value_len
    mov dword [mod_followup_enabled], 1
    lea rax, [mod_audit_log]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], mod_audit_log_len
    lea rdi, [kick_target_event]
    mov esi, kick_target_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [kick_calls], 2
    jne .fail
    cmp qword [config_get_calls], 16
    jne .fail
    cmp qword [send_calls], 80
    jne .fail

    mov dword [failure_stage], 78
    mov qword [expected_channel_ptr], 0
    mov dword [expected_channel_len], 0
    lea rax, [reset_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], reset_response_len
    lea rdi, [reset_event]
    mov esi, reset_event_len
    call dispatch_message_create
    test eax, eax
    jnz .fail
    cmp qword [history_clear_calls], 2
    jne .fail
    cmp qword [send_calls], 81
    jne .fail

    mov dword [target_mode], TARGET_NONE
    mov byte [bot_permission_enabled], 0
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
    inc qword [rate_allow_calls]
    mov al, [rate_allowed]
    ret

; RDI=destination, ESI=capacity. EAX=bytes written.
gateway_uptime_format:
    cmp esi, status_uptime_value_len
    jb .bad
    lea rsi, [status_uptime_value]
    mov edx, status_uptime_value_len
    call copy_bytes
    mov eax, status_uptime_value_len
    ret
.bad:
    mov eax, -1
    ret

gateway_guild_count:
    mov eax, 7
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

; Vision seams implement a small ordered fixture. When no image fixture is
; selected they reject, which preserves the normal text-chat fallback path.
attachment_extract_image_url:
    cmp dword [vision_mode], VISION_NONE
    je .bad
    cmp dword [vision_sequence], 0
    jne .bad
    mov rdi, rdx
    lea rsi, [vision_url]
    mov edx, vision_url_len
    call copy_bytes
    mov dword [vision_sequence], 1
    mov eax, vision_url_len
    ret
.bad:
    mov eax, -1
    ret
attachment_copy_image_mime:
    cmp dword [vision_mode], VISION_NONE
    je .bad
    cmp dword [vision_sequence], 1
    jne .bad
    lea rsi, [vision_mime]
    mov edx, vision_mime_len
    call copy_bytes
    mov dword [vision_sequence], 2
    mov eax, vision_mime_len
    ret
.bad:
    mov eax, -1
    ret
attachment_fetch_https:
    cmp dword [vision_mode], VISION_NONE
    je .bad
    cmp dword [vision_sequence], 2
    jne .bad
    mov dword [vision_sequence], 3
    cmp dword [vision_mode], VISION_FETCH_FAIL
    je .bad
    mov rdi, rdx
    lea rsi, [vision_image]
    mov edx, vision_image_len
    call copy_bytes
    mov eax, vision_image_len
    ret
.bad:
    mov eax, -1
    ret
base64_encode:
    cmp dword [vision_mode], VISION_OK
    jne .bad
    cmp dword [vision_sequence], 3
    jne .bad
    lea rsi, [vision_b64]
    mov edx, vision_b64_len
    call copy_bytes
    mov dword [vision_sequence], 4
    mov eax, vision_b64_len
    ret
.bad:
    mov eax, -1
    ret
; RDI=prompt, ESI=len, RDX=mime, ECX=mime len, R8=Base64, R9D=len.
; Stack holds reply pointer then reply capacity.
groq_vision_once:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdx
    mov r13d, ecx
    mov r14, r8
    mov r15d, r9d
    cmp dword [vision_mode], VISION_OK
    jne .bad
    cmp dword [vision_sequence], 4
    jne .bad
    cmp esi, [expected_vision_len]
    jne .bad
    mov r10, [expected_vision_ptr]
    mov r11d, esi
    mov rsi, r10
    mov edx, r11d
    call equal_bytes
    test al, al
    jz .bad
    cmp r13d, vision_mime_len
    jne .bad
    mov rdi, r12
    lea rsi, [vision_mime]
    mov edx, vision_mime_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r15d, vision_b64_len
    jne .bad
    mov rdi, r14
    lea rsi, [vision_b64]
    mov edx, vision_b64_len
    call equal_bytes
    test al, al
    jz .bad
    mov r10, [rsp + 40]
    mov r11d, [rsp + 48]
    cmp r11d, ai_response_len + 1
    jb .bad
    mov rdi, r10
    lea rsi, [ai_response]
    mov edx, ai_response_len
    call copy_bytes
    mov dword [vision_sequence], 5
    inc qword [vision_calls]
    mov eax, ai_response_len
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=fully constructed Discord URL, ESI=len, RDX=response, ECX=capacity.
; Reply fixture accepts exactly one channel/message route and supplies either
; the cached bot author, another author, or a bounded transport-style failure.
discord_get_json:
    push r12
    push r13
    mov r12, rdx
    mov r13d, ecx
    cmp dword [target_mode], TARGET_NONE
    jne .target
    cmp dword [reply_mode], REPLY_NONE
    je .bad
    lea r8, [reply_expected_url]
    mov r9d, reply_expected_url_len
    cmp esi, r9d
    jne .bad
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [reply_get_calls]
    cmp dword [reply_mode], REPLY_ERROR
    je .bad
    cmp r13d, reply_bot_response_len + 1
    jb .bad
    cmp dword [reply_mode], REPLY_OTHER
    je .other
    lea rsi, [reply_bot_response]
    mov edx, reply_bot_response_len
    jmp .copy
.other:
    lea rsi, [reply_other_response]
    mov edx, reply_other_response_len
.copy:
    mov rdi, r12
    call copy_bytes
    mov byte [r12 + rdx], 0
    mov eax, edx
    jmp .out
.target:
    lea r8, [target_expected_url]
    mov r9d, target_expected_url_len
    cmp esi, r9d
    jne .bad
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [target_get_calls]
    cmp dword [target_mode], TARGET_ERROR
    je .bad
    cmp r13d, target_valid_response_len + 1
    jb .bad
    cmp dword [target_mode], TARGET_MALFORMED
    je .target_malformed
    lea rsi, [target_valid_response]
    mov edx, target_valid_response_len
    jmp .target_copy
.target_malformed:
    lea rsi, [target_malformed_response]
    mov edx, target_malformed_response_len
.target_copy:
    mov rdi, r12
    call copy_bytes
    mov byte [r12 + rdx], 0
    mov eax, edx
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r13
    pop r12
    ret

; RDI=channel, ESI=length, RDX=response, ECX=capacity, R8D=limit.
; This fixture returns only bounded complete channel snapshots for clear.
discord_get_channel_messages:
    push r12
    push r13
    mov r12, rdx
    mov r13d, ecx
    cmp esi, channel_id_len
    jne .bad
    cmp r8d, 3
    jne .bad
    lea rsi, [channel_id]
    mov edx, channel_id_len
    call equal_bytes
    test al, al
    jz .bad
    inc qword [clear_get_calls]
    cmp dword [clear_snapshot_mode], CLEAR_SNAPSHOT_SAFE
    je .safe
    cmp dword [clear_snapshot_mode], CLEAR_SNAPSHOT_OLD
    je .old
    cmp dword [clear_snapshot_mode], CLEAR_SNAPSHOT_DUPLICATE
    je .duplicate
    cmp dword [clear_snapshot_mode], CLEAR_SNAPSHOT_MALFORMED
    je .malformed
    jmp .bad
.safe:
    lea rsi, [clear_snapshot_safe_runtime]
    mov edx, [clear_snapshot_safe_runtime_len]
    jmp .copy
.old:
    lea rsi, [clear_snapshot_old]
    mov edx, clear_snapshot_old_len
    jmp .copy
.duplicate:
    lea rsi, [clear_snapshot_duplicate]
    mov edx, clear_snapshot_duplicate_len
    jmp .copy
.malformed:
    lea rsi, [clear_snapshot_malformed]
    mov edx, clear_snapshot_malformed_len
.copy:
    cmp r13d, edx
    jbe .bad
    mov rdi, r12
    call copy_bytes
    mov byte [r12 + rdx], 0
    mov eax, edx
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r13
    pop r12
    ret

; RDI=channel, ESI=length, RDX=64-byte slots, ECX=count.
discord_bulk_delete_messages:
    push rbx
    mov rbx, rdx
    cmp esi, channel_id_len
    jne .bad
    cmp ecx, 2
    jne .bad
    lea rsi, [channel_id]
    mov edx, channel_id_len
    call equal_bytes
    test al, al
    jz .bad
    mov rdi, rbx
    lea rsi, [clear_candidate_one_runtime]
    mov edx, [clear_candidate_one_runtime_len]
    call equal_bytes
    test al, al
    jz .bad
    lea rdi, [rbx + 64]
    lea rsi, [clear_candidate_two_runtime]
    mov edx, [clear_candidate_two_runtime_len]
    call equal_bytes
    test al, al
    jz .bad
    inc qword [clear_bulk_calls]
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop rbx
    ret

; Builds one current invocation and two current candidate IDs in fixed test
; buffers. EAX=0 on success; this helper never allocates memory.
build_clear_runtime_fixture:
    push rbx
    push r12
    mov r12, [clear_test_snowflake]
    lea rdi, [clear_event_runtime]
    lea rsi, [clear_event_prefix]
    mov edx, clear_event_prefix_len
    call copy_bytes
    add rdi, rdx
    mov rax, r12
    call append_uint64_decimal
    lea rsi, [clear_event_suffix]
    mov edx, clear_event_suffix_len
    call copy_bytes
    add rdi, rdx
    lea rax, [clear_event_runtime]
    sub rdi, rax
    cmp edi, 511
    ja .bad
    mov [clear_event_runtime_len], edi

    lea rdi, [clear_candidate_one_runtime]
    mov rax, r12
    inc rax
    call append_uint64_decimal
    lea rax, [clear_candidate_one_runtime]
    sub rdi, rax
    cmp edi, 63
    ja .bad
    mov [clear_candidate_one_runtime_len], edi

    lea rdi, [clear_candidate_two_runtime]
    mov rax, r12
    add rax, 2
    call append_uint64_decimal
    lea rax, [clear_candidate_two_runtime]
    sub rdi, rax
    cmp edi, 63
    ja .bad
    mov [clear_candidate_two_runtime_len], edi

    lea rdi, [clear_snapshot_safe_runtime]
    lea rsi, [clear_snapshot_prefix]
    mov edx, clear_snapshot_prefix_len
    call copy_bytes
    add rdi, rdx
    mov rax, r12
    call append_uint64_decimal
    lea rsi, [clear_snapshot_middle]
    mov edx, clear_snapshot_middle_len
    call copy_bytes
    add rdi, rdx
    mov rax, r12
    inc rax
    call append_uint64_decimal
    lea rsi, [clear_snapshot_middle]
    mov edx, clear_snapshot_middle_len
    call copy_bytes
    add rdi, rdx
    mov rax, r12
    add rax, 2
    call append_uint64_decimal
    lea rsi, [clear_snapshot_suffix]
    mov edx, clear_snapshot_suffix_len
    call copy_bytes
    add rdi, rdx
    lea rax, [clear_snapshot_safe_runtime]
    sub rdi, rax
    cmp edi, 255
    ja .bad
    mov [clear_snapshot_safe_runtime_len], edi
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r12
    pop rbx
    ret

; RAX=value, RDI=destination. RDI returns after the decimal value.
append_uint64_decimal:
    xor ecx, ecx
    cmp rax, 0
    jne .collect
    mov byte [rdi], '0'
    inc rdi
    ret
.collect:
    xor edx, edx
    mov r8, 10
    div r8
    push rdx
    inc ecx
    test rax, rax
    jnz .collect
.write:
    pop rdx
    add dl, '0'
    mov [rdi], dl
    inc rdi
    dec ecx
    jnz .write
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
; Existing command fixtures use a complete, permissive channel snapshot. Exact
; overwrite ordering is covered independently by channel_permissions_vector.
channel_auth_resolve:
    cmp byte [bot_permission_enabled], 1
    jne .deny
    cmp dword [clear_snapshot_mode], CLEAR_SNAPSHOT_NONE
    jne .clear_permission
    mov rax, 0x10018000016
    ret
.clear_permission:
    mov rax, 0x10018002016
    ret
.deny:
    mov rax, -1
    ret

; Requested role lookup must receive the exact guild and ordered role mention.
guild_auth_role_position:
    push rbx
    push r12
    mov rbx, rdx
    mov r12d, ecx
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, role_rest_requested_len
    jne .bad
    mov rdi, rbx
    lea rsi, [role_rest_requested]
    mov edx, r12d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [role_position_calls]
    mov eax, [role_position_value]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r12
    pop rbx
    ret
; The dispatcher asks this helper only for cached bot roles after target
; hierarchy and requested-role presence have passed.
guild_auth_member_highest_position:
    push rbx
    push r12
    mov rbx, rdx
    mov r12d, ecx
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, bot_roles_len
    jne .bad
    mov rdi, rbx
    lea rsi, [bot_roles]
    mov edx, r12d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [bot_highest_calls]
    mov eax, [bot_highest_position]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r12
    pop rbx
    ret
guild_auth_bot_above_roles:

    inc qword [hierarchy_calls]
    movzx eax, byte [hierarchy_allowed]
    ret

guild_auth_get_bot_roles:
    cmp byte [bot_permission_enabled], 1
    jne .none
    lea rax, [bot_roles]
    mov edx, bot_roles_len
    ret
.none:
    xor eax, eax
    xor edx, edx
    ret

discord_unban_member:
    inc qword [unban_calls]
    xor eax, eax
    ret

discord_kick_member:
    cmp r9d, kick_audit_reason_len
    jne .bad
    mov rdi, r8
    lea rsi, [kick_audit_reason]
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [kick_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

discord_ban_member:
    inc qword [ban_calls]
    xor eax, eax
    ret

discord_lock_channel:
    inc qword [lock_calls]
    xor eax, eax
    ret

discord_unlock_channel:
    inc qword [unlock_calls]
    xor eax, eax
    ret

discord_set_slowmode:
    inc qword [slowmode_calls]
    xor eax, eax
    ret
discord_set_member_timeout:
    push rbx
    push r12
    mov rbx, rdx
    mov r12d, ecx
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, timeout_target_len_expected
    jne .bad
    mov rdi, rbx
    lea rsi, [timeout_target_expected]
    mov edx, r12d
    call equal_bytes
    test al, al
    jz .bad
    cmp r8d, 15
    jne .bad
    inc qword [timeout_calls]
    xor eax, eax
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop r12
    pop rbx
    ret
discord_set_member_nick:
    push rbx
    push r12
    push r13
    mov rbx, rdx
    mov r12d, ecx
    mov r13, r8
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, nick_target_len_expected
    jne .bad
    mov rdi, rbx
    lea rsi, [nick_target_expected]
    mov edx, r12d
    call equal_bytes
    test al, al
    jz .bad
    cmp r9d, nick_value_len_expected
    jne .bad
    mov rdi, r13
    lea rsi, [nick_value_expected]
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [nick_calls]
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r13
    pop r12
    pop rbx
    ret
discord_clear_member_timeout:
    push rbx
    push r12
    mov rbx, rdx
    mov r12d, ecx
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, timeout_target_len_expected
    jne .bad
    mov rdi, rbx
    lea rsi, [timeout_target_expected]
    mov edx, r12d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [timeout_clear_calls]
    xor eax, eax
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop r12
    pop rbx
    ret

discord_add_member_role:
    call assert_role_rest_args
    test eax, eax
    jnz .bad
    inc qword [role_add_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret
discord_remove_member_role:
    call assert_role_rest_args
    test eax, eax
    jnz .bad
    inc qword [role_remove_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret
; RDI=guild, ESI=len, RDX=target, ECX=len, R8=requested role, R9D=len.
; Shared assertion proves destructive calls receive exact, unswapped IDs.
assert_role_rest_args:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdx
    mov r12d, ecx
    mov r13, r8
    mov r14d, r9d
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, role_rest_target_len
    jne .bad
    mov rdi, rbx
    lea rsi, [role_rest_target]
    mov edx, r12d
    call equal_bytes
    test al, al
    jz .bad
    cmp r14d, role_rest_requested_len
    jne .bad
    mov rdi, r13
    lea rsi, [role_rest_requested]
    mov edx, r14d
    call equal_bytes
    test al, al
    jz .bad
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret


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
    cmp dword [report_log_enabled], 1
    je .valid
    cmp dword [report_log_enabled], 2
    je .invalid
.absent:
    xor eax, eax
    xor edx, edx
    ret
.valid:
    lea rax, [report_log_channel_value]
    mov edx, report_log_channel_value_len
    ret
.invalid:
    lea rax, [invalid_log_channel_value]
    mov edx, invalid_log_channel_value_len
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
    jne .bad_channel_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad_channel_bytes
    cmp r10d, [expected_text_len]
    jne .bad_text_len
    mov rdi, r11
    mov rsi, [expected_text_ptr]
    mov edx, r10d
    call equal_bytes
    test al, al
    jz .bad_text_bytes
    inc qword [send_calls]
    cmp dword [automod_followup_enabled], 0
    je .chat_followup
    mov dword [automod_followup_enabled], 0
    mov qword [expected_channel_ptr], 0
    mov dword [expected_channel_len], 0
    lea rax, [automod_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], automod_response_len
    jmp .ok
.chat_followup:
    cmp dword [chat_followup_enabled], 0
    je .mod_followup
    mov dword [chat_followup_enabled], 0
    lea rax, [report_log_channel_value]
    mov [expected_channel_ptr], rax
    mov dword [expected_channel_len], report_log_channel_value_len
    lea rax, [chat_audit_log]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], chat_audit_log_len
    jmp .ok
.mod_followup:
    cmp dword [mod_followup_enabled], 0
    je .report_followup
    mov dword [mod_followup_enabled], 0
    mov qword [expected_channel_ptr], 0
    mov dword [expected_channel_len], 0
    lea rax, [kick_success_response]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], kick_success_response_len
    jmp .ok
.report_followup:
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
.bad_channel_len:
    mov dword [failure_stage], 401
    jmp .bad
.bad_channel_bytes:
    mov dword [failure_stage], 402
    jmp .bad
.bad_text_len:
    mov [failure_stage], r10d
    jmp .bad
.bad_text_bytes:
    mov dword [failure_stage], 404
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
reset_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^reset","author":{"id":"user-2","bot":false}}}'
reset_event_len equ $ - reset_event
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
chat_audit_prompt: db 'ping @here', 10, '`tag`'
chat_audit_prompt_len equ $ - chat_audit_prompt
ai_response: db 'AI summary'
ai_response_len equ $ - ai_response
unknown_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"^kick","author":{"bot":false}}}'
unknown_event_len equ $ - unknown_event
unban_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^unban 998877665544332211","author":{"id":"user-2","bot":false}}}'
unban_event_len equ $ - unban_event
lock_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^lock","author":{"id":"user-2","bot":false}}}'
lock_event_len equ $ - lock_event
unlock_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^unlock","author":{"id":"user-2","bot":false}}}'
unlock_event_len equ $ - unlock_event
slowmode_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^slowmode 15","author":{"id":"user-2","bot":false}}}'
slowmode_event_len equ $ - slowmode_event
slowmode_out_of_range_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^slowmode 21601","author":{"id":"user-2","bot":false}}}'
slowmode_out_of_range_event_len equ $ - slowmode_out_of_range_event
kick_target_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^kick <@555> policy reason","author":{"id":"user-2","bot":false}}}'
kick_target_event_len equ $ - kick_target_event
kick_audit_reason: db 'policy reason'
kick_audit_reason_len equ $ - kick_audit_reason
ban_target_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^ban <@555>","author":{"id":"user-2","bot":false}}}'
ban_target_event_len equ $ - ban_target_event
timeout_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^timeout <@555> 15 reason","author":{"id":"user-2","bot":false}}}'
timeout_event_len equ $ - timeout_event
untimeout_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^untimeout <@555>","author":{"id":"user-2","bot":false}}}'
untimeout_event_len equ $ - untimeout_event
timeout_invalid_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^timeout <@555> 40321","author":{"id":"user-2","bot":false}}}'
timeout_invalid_event_len equ $ - timeout_invalid_event
untimeout_invalid_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^untimeout <@555> trailing","author":{"id":"user-2","bot":false}}}'
untimeout_invalid_event_len equ $ - untimeout_invalid_event
nick_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^nick <@555> New Name","author":{"id":"user-2","bot":false}}}'
nick_event_len equ $ - nick_event
nick_invalid_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^nick <@555>   ","author":{"id":"user-2","bot":false}}}'
nick_invalid_event_len equ $ - nick_invalid_event
clear_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"id":"1542329009700864000","guild_id":"guild-1","channel_id":"123456789012345678","content":"^clear 2","author":{"id":"user-2","bot":false}}}'
clear_event_len equ $ - clear_event
clear_invalid_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"id":"1542329009700864000","guild_id":"guild-1","channel_id":"123456789012345678","content":"^clear 100","author":{"id":"user-2","bot":false}}}'
clear_invalid_event_len equ $ - clear_invalid_event
clear_candidate_one: db '1542329009700864001'
clear_candidate_one_len equ $ - clear_candidate_one
clear_candidate_two: db '1542329009700864002'
clear_candidate_two_len equ $ - clear_candidate_two
clear_event_prefix: db '{"op":0,"t":"MESSAGE_CREATE","d":{"id":"'
clear_event_prefix_len equ $ - clear_event_prefix
clear_event_suffix: db '","guild_id":"guild-1","channel_id":"123456789012345678","content":"^clear 2","author":{"id":"user-2","bot":false}}}'
clear_event_suffix_len equ $ - clear_event_suffix
clear_snapshot_prefix: db '[{"id":"'
clear_snapshot_prefix_len equ $ - clear_snapshot_prefix
clear_snapshot_middle: db '"},{"id":"'
clear_snapshot_middle_len equ $ - clear_snapshot_middle
clear_snapshot_suffix: db '"}]'
clear_snapshot_suffix_len equ $ - clear_snapshot_suffix
clear_snapshot_old: db '[{"id":"1542329009700864000"},{"id":"175928847299117063"}]'
clear_snapshot_old_len equ $ - clear_snapshot_old
clear_snapshot_duplicate: db '[{"id":"1542329009700864000"},{"id":"1542329009700864001"},{"id":"1542329009700864001"}]'
clear_snapshot_duplicate_len equ $ - clear_snapshot_duplicate
clear_snapshot_malformed: db '[{"id":"1542329009700864000"}] trailing'
clear_snapshot_malformed_len equ $ - clear_snapshot_malformed
nick_target_expected: db '555'
nick_target_len_expected equ $ - nick_target_expected
nick_value_expected: db 'New Name'
nick_value_len_expected equ $ - nick_value_expected
nick_usage_response_test: db 'Usage: nick <@user> <nickname>'
nick_usage_response_test_len equ $ - nick_usage_response_test
nick_success_response_test: db 'Nickname changed.'
nick_success_response_test_len equ $ - nick_success_response_test
timeout_target_expected: db '555'
timeout_target_len_expected equ $ - timeout_target_expected
timeout_usage_response_test: db 'Usage: timeout <@user> <1-40320 minutes> [reason]'
timeout_usage_response_test_len equ $ - timeout_usage_response_test
timeout_success_response_test: db 'User timed out.'
timeout_success_response_test_len equ $ - timeout_success_response_test
untimeout_usage_response_test: db 'Usage: untimeout <@user>'
untimeout_usage_response_test_len equ $ - untimeout_usage_response_test
untimeout_success_response_test: db 'User timeout removed.'
untimeout_success_response_test_len equ $ - untimeout_success_response_test
role_add_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^role add <@555> <@&1001>","author":{"id":"user-2","bot":false}}}'
role_add_event_len equ $ - role_add_event
role_remove_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^role remove <@555> <@&1001>","author":{"id":"user-2","bot":false}}}'
role_remove_event_len equ $ - role_remove_event
role_invalid_action_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^role destroy <@555> <@&1001>","author":{"id":"user-2","bot":false}}}'
role_invalid_action_event_len equ $ - role_invalid_action_event
role_malformed_mention_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^role add <@555> <@1001>","author":{"id":"user-2","bot":false}}}'
role_malformed_mention_event_len equ $ - role_malformed_mention_event
target_expected_url: db 'https://discord.com/api/v10/guilds/guild-1/members/555'
target_expected_url_len equ $ - target_expected_url
target_valid_response: db '{"roles":["1001"]}'
target_valid_response_len equ $ - target_valid_response
target_malformed_response: db '{"roles":"broken"}'
target_malformed_response_len equ $ - target_malformed_response
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
automod_audit_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"id":"998877665544332211","guild_id":"guild-1","channel_id":"123456789012345678","content":"blocked @here', 0x5c, 'n`code`","author":{"id":"user-2","username":"Alice@everyone","bot":false}}}'
automod_audit_event_len equ $ - automod_audit_event
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
chat_audit_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^ping @here', 0x5c, 'n`tag`","author":{"id":"112233445566778899","username":"Chat@all","bot":false}}}'
chat_audit_event_len equ $ - chat_audit_event
reply_to_bot_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"reply question","message_reference":{"message_id":"998877665544332211"},"author":{"id":"112233445566778899","bot":false}}}'
reply_to_bot_event_len equ $ - reply_to_bot_event
reply_prompt: db 'reply question'
reply_prompt_len equ $ - reply_prompt
reply_expected_url: db 'https://discord.com/api/v10/channels/123456789012345678/messages/998877665544332211'
reply_expected_url_len equ $ - reply_expected_url
reply_bot_response: db '{"author":{"id":"9001"}}'
reply_bot_response_len equ $ - reply_bot_response
reply_other_response: db '{"author":{"id":"9002"}}'
reply_other_response_len equ $ - reply_other_response
vision_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^describe this","attachments":[{"content_type":"image/png","url":"https://cdn.discordapp.com/a.png"}],"author":{"id":"112233445566778899","bot":false}}}'
vision_event_len equ $ - vision_event
vision_empty_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"^","attachments":[{"content_type":"image/png","url":"https://cdn.discordapp.com/a.png"}],"author":{"id":"112233445566778899","bot":false}}}'
vision_empty_event_len equ $ - vision_empty_event
mention_vision_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"<@9001> inspect","attachments":[{"content_type":"image/png","url":"https://cdn.discordapp.com/a.png"}],"author":{"id":"112233445566778899","bot":false}}}'
mention_vision_event_len equ $ - mention_vision_event
untriggered_image_event: db '{"op":0,"t":"MESSAGE_CREATE","d":{"guild_id":"guild-1","channel_id":"123456789012345678","content":"random image","attachments":[{"content_type":"image/png","url":"https://cdn.discordapp.com/a.png"}],"author":{"id":"112233445566778899","bot":false}}}'
untriggered_image_event_len equ $ - untriggered_image_event
vision_prompt: db 'describe this'
vision_prompt_len equ $ - vision_prompt
mention_vision_prompt: db 'inspect'
mention_vision_prompt_len equ $ - mention_vision_prompt
vision_default_prompt: db 'Someone called you. Reply with a concise friendly greeting.'
vision_default_prompt_len equ $ - vision_default_prompt
vision_url: db 'https://cdn.discordapp.com/a.png'
vision_url_len equ $ - vision_url
vision_mime: db 'image/png'
vision_mime_len equ $ - vision_mime
vision_image: db 1, 2, 3
vision_image_len equ $ - vision_image
vision_b64: db 'AQID'
vision_b64_len equ $ - vision_b64
bot_user_id: db '9001'
bot_user_id_len equ $ - bot_user_id
help_response: db '**Hai sayang! Ini cara pakai aku:**\n`Caine <pertanyaan>` - tanya apapun\n`Caine` + kirim gambar - analisis gambar\n`Caine summarize [jumlah]` - rangkum chat\n`Caine report @user alasan` - laporin user\n`Caine reset` - hapus memory\n`Caine afk [alasan]` - set AFK\n`Caine afklist` - lihat siapa yang AFK\n`Caine rank [@user]` - lihat rank/XP\n`Caine leaderboard` - top 10 XP\n`Caine status` - status bot\n`Caine setmodel <alias>` - ganti model AI\n`Caine sethistory <angka>` - set batas history chat\n`/info` - info bot\n`/dashboard` - buka dashboard (admin)\n\n**Moderasi:** kick, ban, unban, timeout, untimeout, warn, warnings, clearwarn, clear, lock, unlock, slowmode, nick, role add/remove\n\n**Admin:** addword, removeword, words, enable, disable, setlog, setwelcome, setgoodbye, setwelcomemsg, setgoodbyemsg, autorole, removeautorole, setlevelchannel, setpersona, setmodel, sethistory'
help_response_len equ $ - help_response
status_uptime_value: db '2d 3h 4m 5s'
status_uptime_value_len equ $ - status_uptime_value
status_response: db 0xf0, 0x9f, 0x93, 0x8a, ' **Status Bot**', 10, 0xe2, 0x8f, 0xb1, ' Uptime: 2d 3h 4m 5s', 10, 0xf0, 0x9f, 0x8c, 0x90, ' Servers: 7'
status_response_len equ $ - status_response
reset_response: db 0xf0, 0x9f, 0xa7, 0xb9, ' Memory kita udah di-reset sayang!'
reset_response_len equ $ - reset_response
rank_response: db 'Your XP: 42'
rank_response_len equ $ - rank_response
afklist_response: db 'AFK members:', 10, '- user-2: dinner', 10
afklist_response_len equ $ - afklist_response
leaderboard_response: db 'XP leaderboard:', 10, '1. user-2 - 3 XP', 10
leaderboard_response_len equ $ - leaderboard_response
registered_notice: db 'That command is registered, but its handler is not active in this checkpoint.'
registered_notice_len equ $ - registered_notice
admin_denied_response: db 'Admin verification unavailable or denied.'
admin_denied_response_len equ $ - admin_denied_response
bot_denied_response: db 'Bot lacks the required effective channel permission.'
bot_denied_response_len equ $ - bot_denied_response
unban_success_response: db 'User unbanned.'
unban_success_response_len equ $ - unban_success_response
lock_success_response: db 'Channel locked.'
lock_success_response_len equ $ - lock_success_response
unlock_success_response: db 'Channel unlocked.'
unlock_success_response_len equ $ - unlock_success_response
slowmode_success_response: db 'Slowmode updated.'
slowmode_success_response_len equ $ - slowmode_success_response
slowmode_usage_response: db 'Usage: slowmode <0-21600>'
slowmode_usage_response_len equ $ - slowmode_usage_response
kick_success_response: db 'User kicked.'
kick_success_response_len equ $ - kick_success_response
role_command_usage_response: db 'Usage: role add|remove <@user> <@&role>'
role_command_usage_response_len equ $ - role_command_usage_response
role_add_success_response: db 'Role added.'
role_add_success_response_len equ $ - role_add_success_response
role_remove_success_response: db 'Role removed.'
role_remove_success_response_len equ $ - role_remove_success_response
role_rest_target: db '555'
role_rest_target_len equ $ - role_rest_target
role_rest_requested: db '1001'
role_rest_requested_len equ $ - role_rest_requested
hierarchy_denied_response: db 'Bot cannot moderate this target due to role hierarchy or incomplete member state.'
hierarchy_denied_response_len equ $ - hierarchy_denied_response
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
automod_audit_log: db 'AUTOMOD', 10, 'User: Alice@', 0xe2, 0x80, 0x8b, 'everyone', 10, 'Channel: <#123456789012345678>', 10, 'Kata Terlarang: ||blocked||', 10, 'Pesan: ```blocked @', 0xe2, 0x80, 0x8b, 'here?', 39, 'code', 39, '```'
automod_audit_log_len equ $ - automod_audit_log
chat_audit_log: db 'CHAT', 10, 'User: Chat@', 0xe2, 0x80, 0x8b, 'all', 10, 'Channel: <#123456789012345678>', 10, 'Pertanyaan: ping @', 0xe2, 0x80, 0x8b, 'here?', 39, 'tag', 39, 10, 'Jawaban: AI summary'
chat_audit_log_len equ $ - chat_audit_log
mod_audit_log: db 'MODERATION', 10, 'Action: Kick', 10, 'Moderator: user-2', 10, 'Target: 555', 10, 'Alasan: policy reason'
mod_audit_log_len equ $ - mod_audit_log
blocked_word: db 'blocked'
blocked_word_len equ $ - blocked_word
automod_message_id: db '998877665544332211'
automod_message_id_len equ $ - automod_message_id
warning_reply: db 'Warnings: 3.'
warning_reply_len equ $ - warning_reply
clearwarn_response: db 'Warnings cleared.'
clearwarn_response_len equ $ - clearwarn_response
clear_usage_response: db 'Usage: clear [1-99].'
clear_usage_response_len equ $ - clear_usage_response
clear_success_response: db 'Messages cleared.'
clear_success_response_len equ $ - clear_success_response
moderation_error_response: db 'Moderation request failed.'
moderation_error_response_len equ $ - moderation_error_response
report_saved_response: db 'Report sent to the guild log channel.'
report_saved_response_len equ $ - report_saved_response
report_log_text: db 'REPORT', 10, 'Reporter: <@112233445566778899>', 10, 'Target: <@555>', 10, 'Reason: flooding chat', 10, 'Channel: <#123456789012345678>'
report_log_text_len equ $ - report_log_text
report_log_channel_value: db '998877665544332211'
report_log_channel_value_len equ $ - report_log_channel_value
invalid_log_channel_value: db '0000'
invalid_log_channel_value_len equ $ - invalid_log_channel_value
ai_error_response: db 'AI request failed. Please try again shortly.'
ai_error_response_len equ $ - ai_error_response
ai_rate_limited_response: db 'AI rate limit reached. Please wait before sending another request.'
ai_rate_limited_response_len equ $ - ai_rate_limited_response

section .data
bot_prefix_ptr: dq 0
bot_prefix_len: dd 0
gateway_bot_user_id: times 64 db 0
gateway_bot_user_id_len: dd 0
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
automod_followup_enabled: dd 0
chat_followup_enabled: dd 0
mod_followup_enabled: dd 0
report_log_enabled: dd 0
delete_calls: dq 0
clear_get_calls: dq 0
clear_bulk_calls: dq 0
clear_snapshot_mode: dd CLEAR_SNAPSHOT_NONE
clear_test_snowflake: dq 0
clear_event_runtime_len: dd 0
clear_snapshot_safe_runtime_len: dd 0
clear_candidate_one_runtime_len: dd 0
clear_candidate_two_runtime_len: dd 0
clear_event_runtime: times 512 db 0
clear_snapshot_safe_runtime: times 256 db 0
clear_candidate_one_runtime: times 64 db 0
clear_candidate_two_runtime: times 64 db 0
automod_enabled: dd 0
warnings_add_calls: dq 0
warnings_get_calls: dq 0
warnings_clear_calls: dq 0
failure_stage: dd 0
vision_mode: dd VISION_NONE
vision_sequence: dd 0
rate_allowed: db 1
rate_allow_calls: dq 0
vision_calls: dq 0
expected_vision_ptr: dq 0
expected_vision_len: dd 0
reply_mode: dd REPLY_NONE
reply_get_calls: dq 0
unban_calls: dq 0
kick_calls: dq 0
ban_calls: dq 0
lock_calls: dq 0
unlock_calls: dq 0
slowmode_calls: dq 0
role_add_calls: dq 0
role_remove_calls: dq 0
timeout_calls: dq 0
timeout_clear_calls: dq 0
nick_calls: dq 0
role_position_calls: dq 0
bot_highest_calls: dq 0
target_get_calls: dq 0
hierarchy_calls: dq 0
target_mode: dd TARGET_NONE
hierarchy_allowed: db 0
bot_permission_enabled: db 0
role_position_value: dd -1
bot_highest_position: dd -1
bot_roles: db '["2002"]'
bot_roles_len equ $ - bot_roles

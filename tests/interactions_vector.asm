DEFAULT REL

extern interaction_handle_gateway

global _start
global discord_interaction_respond_text
global discord_interaction_respond_json
global bot_owner_ptr
global bot_owner_len
global guild_config_set
global guild_config_delete
global guild_word_add
global guild_word_remove
global guild_auth_bot_above_role
global guild_auth_get_bot_roles
global guild_auth_roles_have
global guild_config_get
global groq_select_guild
global groq_select_history
global groq_chat_once
global discord_interaction_edit_original
global gateway_bot_user_id
global gateway_bot_user_id_len
global gateway_last_heartbeat_latency_ms

%define SYS_EXIT 60

section .text
_start:
    mov qword [callback_calls], 0
    mov dword [failure_stage], 1
    lea rax, [info_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], info_response_len
    lea rdi, [info_frame]
    mov esi, info_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 1
    jne .fail

    mov dword [failure_stage], 2
    lea rax, [help_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], help_response_len
    lea rdi, [help_frame]
    mov esi, help_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 2
    jne .fail

    mov dword [failure_stage], 3
    lea rax, [dashboard_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], dashboard_response_len
    lea rdi, [dashboard_admin_frame]
    mov esi, dashboard_admin_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 1
    jne .fail

    mov dword [failure_stage], 4
    lea rax, [dashboard_back_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], dashboard_back_response_len
    lea rdi, [dashboard_back_frame]
    mov esi, dashboard_back_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 2
    jne .fail

    mov dword [failure_stage], 5
    mov byte [general_log_mode], 1
    lea rax, [dashboard_general_dynamic_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], dashboard_general_dynamic_response_len
    lea rdi, [dashboard_general_frame]
    mov esi, dashboard_general_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 3
    jne .fail
    mov byte [general_log_mode], 0

    mov dword [failure_stage], 6
    lea rax, [dashboard_welcome_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], dashboard_welcome_response_len
    lea rdi, [dashboard_welcome_frame]
    mov esi, dashboard_welcome_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 4
    jne .fail

    mov dword [failure_stage], 7
    lea rax, [dashboard_model_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], dashboard_model_response_len
    lea rdi, [dashboard_model_frame]
    mov esi, dashboard_model_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 5
    jne .fail

    mov dword [failure_stage], 8
    lea rax, [model_guild_id]
    mov [expected_config_guild_ptr], rax
    mov dword [expected_config_guild_len], model_guild_id_len
    lea rax, [setting_model]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_model_len
    lea rax, [model_id_llama]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], model_id_llama_len
    lea rax, [model_llama_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], model_llama_saved_response_len
    lea rdi, [dashboard_model_llama_frame]
    mov esi, dashboard_model_llama_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 1
    jne .fail
    cmp qword [callback_calls], 3
    jne .fail

    mov dword [failure_stage], 9
    lea rax, [model_id_gpt120]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], model_id_gpt120_len
    lea rax, [model_gpt120_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], model_gpt120_saved_response_len
    lea rdi, [dashboard_model_gpt120_frame]
    mov esi, dashboard_model_gpt120_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 2
    jne .fail
    cmp qword [callback_calls], 4
    jne .fail

    mov dword [failure_stage], 10
    lea rax, [model_id_gpt20]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], model_id_gpt20_len
    lea rax, [model_gpt20_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], model_gpt20_saved_response_len
    lea rdi, [dashboard_model_gpt20_frame]
    mov esi, dashboard_model_gpt20_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 3
    jne .fail
    cmp qword [callback_calls], 5
    jne .fail

    mov dword [failure_stage], 11
    lea rax, [model_id_qwen]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], model_id_qwen_len
    lea rax, [model_qwen_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], model_qwen_saved_response_len
    lea rdi, [dashboard_model_qwen_frame]
    mov esi, dashboard_model_qwen_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 4
    jne .fail
    cmp qword [callback_calls], 6
    jne .fail

    mov dword [failure_stage], 12
    lea rax, [modal_setlog_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], modal_setlog_response_len
    lea rdi, [dashboard_setlog_frame]
    mov esi, dashboard_setlog_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 6
    jne .fail

    mov dword [failure_stage], 13
    lea rax, [modal_guild_id]
    mov [expected_config_guild_ptr], rax
    mov dword [expected_config_guild_len], modal_guild_id_len
    lea rax, [setting_log_channel]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_log_channel_len
    lea rax, [modal_channel_id]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], modal_channel_id_len
    lea rax, [setlog_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], setlog_saved_response_len
    lea rdi, [modal_setlog_submit_frame]
    mov esi, modal_setlog_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 5
    jne .fail
    cmp qword [callback_calls], 7
    jne .fail

    mov dword [failure_stage], 14
    lea rax, [model_guild_id]
    mov [expected_config_guild_ptr], rax
    mov dword [expected_config_guild_len], model_guild_id_len
    lea rax, [setting_welcome_channel]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_welcome_channel_len
    lea rax, [welcome_channel_id]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], welcome_channel_id_len
    lea rax, [setwelcome_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], setwelcome_saved_response_len
    lea rdi, [modal_setwelcome_submit_frame]
    mov esi, modal_setwelcome_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 6
    jne .fail
    cmp qword [callback_calls], 8
    jne .fail

    mov dword [failure_stage], 15
    lea rax, [setting_goodbye_channel]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_goodbye_channel_len
    lea rax, [goodbye_channel_id]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], goodbye_channel_id_len
    lea rax, [setgoodbye_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], setgoodbye_saved_response_len
    lea rdi, [modal_setgoodbye_submit_frame]
    mov esi, modal_setgoodbye_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 7
    jne .fail
    cmp qword [callback_calls], 9
    jne .fail

    mov dword [failure_stage], 16
    lea rax, [setting_welcome_message]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_welcome_message_len
    lea rax, [welcome_message]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], welcome_message_len
    lea rax, [setwelcomemsg_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], setwelcomemsg_saved_response_len
    lea rdi, [modal_setwelcomemsg_submit_frame]
    mov esi, modal_setwelcomemsg_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 8
    jne .fail
    cmp qword [callback_calls], 10
    jne .fail

    mov dword [failure_stage], 17
    lea rax, [setting_goodbye_message]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_goodbye_message_len
    lea rax, [goodbye_message]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], goodbye_message_len
    lea rax, [setgoodbyemsg_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], setgoodbyemsg_saved_response_len
    lea rdi, [modal_setgoodbyemsg_submit_frame]
    mov esi, modal_setgoodbyemsg_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 9
    jne .fail
    cmp qword [callback_calls], 11
    jne .fail

    mov dword [failure_stage], 18
    lea rax, [setting_level_channel]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_level_channel_len
    lea rax, [level_channel_id]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], level_channel_id_len
    lea rax, [levelchannel_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], levelchannel_saved_response_len
    lea rdi, [modal_setlevelchannel_submit_frame]
    mov esi, modal_setlevelchannel_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 10
    jne .fail
    cmp qword [callback_calls], 12
    jne .fail

    mov dword [failure_stage], 19
    lea rax, [setting_persona]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_persona_len
    lea rax, [persona_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], persona_value_len
    lea rax, [persona_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], persona_saved_response_len
    lea rdi, [modal_setpersona_submit_frame]
    mov esi, modal_setpersona_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 11
    jne .fail
    cmp qword [callback_calls], 13
    jne .fail

    mov dword [failure_stage], 20
    lea rax, [setting_history]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_history_len
    lea rax, [history_limit]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], history_limit_len
    lea rax, [history_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], history_saved_response_len
    lea rdi, [modal_sethistory_submit_frame]
    mov esi, modal_sethistory_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 12
    jne .fail
    cmp qword [callback_calls], 14
    jne .fail

    mov dword [failure_stage], 21
    lea rax, [setting_persona]
    mov [expected_delete_setting_ptr], rax
    mov dword [expected_delete_setting_len], setting_persona_len
    lea rax, [persona_reset_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], persona_reset_response_len
    lea rdi, [dashboard_resetpersona_frame]
    mov esi, dashboard_resetpersona_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_delete_calls], 1
    jne .fail
    cmp qword [callback_calls], 15
    jne .fail

    mov dword [failure_stage], 22
    lea rax, [normalized_word]
    mov [expected_word_ptr], rax
    mov dword [expected_word_len], normalized_word_len
    lea rax, [word_added_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], word_added_response_len
    lea rdi, [modal_addword_submit_frame]
    mov esi, modal_addword_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [word_add_calls], 1
    jne .fail
    cmp qword [callback_calls], 16
    jne .fail

    mov dword [failure_stage], 23
    lea rax, [word_removed_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], word_removed_response_len
    lea rdi, [modal_removeword_submit_frame]
    mov esi, modal_removeword_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [word_remove_calls], 1
    jne .fail
    cmp qword [callback_calls], 17
    jne .fail

    mov dword [failure_stage], 24
    mov byte [autorole_hierarchy_allowed], 1
    lea rax, [setting_autorole]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], setting_autorole_len
    lea rax, [autorole_id]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], autorole_id_len
    lea rax, [autorole_saved_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], autorole_saved_response_len
    lea rdi, [modal_setautorole_submit_frame]
    mov esi, modal_setautorole_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 13
    jne .fail
    cmp qword [callback_calls], 18
    jne .fail

    mov dword [failure_stage], 25
    mov byte [autorole_hierarchy_allowed], 0
    lea rax, [config_failure_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], config_failure_response_len
    lea rdi, [modal_setautorole_submit_frame]
    mov esi, modal_setautorole_submit_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 13
    jne .fail
    cmp qword [callback_calls], 19
    jne .fail

    mov dword [failure_stage], 26
    lea rax, [healthcheck_deferred_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], healthcheck_deferred_response_len
    lea rax, [health_probe_setting]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], health_probe_setting_len
    mov [expected_delete_setting_ptr], rax
    mov dword [expected_delete_setting_len], health_probe_setting_len
    lea rax, [health_probe_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], health_probe_value_len
    lea rax, [healthcheck_ok_edit]
    mov [expected_health_edit_ptr], rax
    mov dword [expected_health_edit_len], healthcheck_ok_edit_len
    lea rdi, [healthcheck_frame]
    mov esi, healthcheck_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 14
    jne .fail
    cmp qword [config_delete_calls], 2
    jne .fail
    cmp qword [json_callback_calls], 7
    jne .fail
    cmp qword [health_edit_calls], 1
    jne .fail

    mov dword [failure_stage], 27
    mov byte [health_permission_allowed], 0
    lea rax, [healthcheck_deferred_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], healthcheck_deferred_response_len
    lea rax, [health_probe_setting]
    mov [expected_config_setting_ptr], rax
    mov dword [expected_config_setting_len], health_probe_setting_len
    mov [expected_delete_setting_ptr], rax
    mov dword [expected_delete_setting_len], health_probe_setting_len
    lea rax, [health_probe_value]
    mov [expected_config_value_ptr], rax
    mov dword [expected_config_value_len], health_probe_value_len
    lea rax, [healthcheck_degraded_edit]
    mov [expected_health_edit_ptr], rax
    mov dword [expected_health_edit_len], healthcheck_degraded_edit_len
    lea rdi, [healthcheck_frame]
    mov esi, healthcheck_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 15
    jne .fail
    cmp qword [config_delete_calls], 3
    jne .fail
    cmp qword [json_callback_calls], 8
    jne .fail
    cmp qword [health_edit_calls], 2
    jne .fail
    mov byte [health_permission_allowed], 1

    mov dword [failure_stage], 28
    mov byte [status_history_mode], 1
    lea rax, [status_dynamic_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], status_dynamic_response_len
    lea rdi, [dashboard_status_frame]
    mov esi, dashboard_status_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 9
    jne .fail
    mov byte [status_history_mode], 0

    mov dword [failure_stage], 29
    lea rax, [manager_denied_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], manager_denied_response_len
    lea rdi, [healthcheck_denied_frame]
    mov esi, healthcheck_denied_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 15
    jne .fail
    cmp qword [config_delete_calls], 3
    jne .fail
    cmp qword [health_edit_calls], 2
    jne .fail
    cmp qword [callback_calls], 20
    jne .fail

    mov dword [failure_stage], 29
    lea rax, [manager_denied_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], manager_denied_response_len
    lea rdi, [dashboard_denied_frame]
    mov esi, dashboard_denied_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 21
    jne .fail
    cmp qword [json_callback_calls], 9
    jne .fail

    mov dword [failure_stage], 31
    lea rax, [config_failure_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], config_failure_response_len
    lea rdi, [model_missing_guild_frame]
    mov esi, model_missing_guild_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [config_set_calls], 15
    jne .fail
    cmp qword [callback_calls], 22
    jne .fail

    mov dword [failure_stage], 32
    lea rdi, [unknown_frame]
    mov esi, unknown_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 22
    jne .fail

    mov dword [failure_stage], 33
    lea rdi, [wrong_type_frame]
    mov esi, wrong_type_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 22
    jne .fail

    mov dword [failure_stage], 34
    lea rdi, [malformed_frame]
    mov esi, malformed_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 22
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; Bounded healthcheck seams: no network and no durable store are accessed by
; this vector. Dedicated cases below can control their success bits.
guild_config_get:
    cmp byte [general_log_mode], 0
    je .not_general
    lea rax, [general_log_channel]
    mov edx, general_log_channel_len
    ret
.not_general:
    cmp byte [status_history_mode], 0
    je .health
    lea rax, [history_limit]
    mov edx, history_limit_len
    ret
.health:
    lea rax, [health_probe_value]
    mov edx, health_probe_value_len
    ret

groq_select_guild:
    xor eax, eax
    ret

groq_select_history:
    xor eax, eax
    ret

groq_chat_once:
    mov byte [rdx], 0
    xor eax, eax
    ret

guild_auth_get_bot_roles:
    lea rax, [health_bot_roles]
    mov edx, health_bot_roles_len
    ret

guild_auth_roles_have:
    mov al, [health_permission_allowed]
    ret

discord_interaction_edit_original:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, r8
    mov r12d, r9d
    mov r13, rdx
    mov r14d, ecx
    cmp esi, [gateway_bot_user_id_len]
    jne .bad
    lea rsi, [gateway_bot_user_id]
    mov edx, [gateway_bot_user_id_len]
    call equal_bytes
    test al, al
    jz .bad
    cmp r14d, interaction_token_len
    jne .bad
    mov rdi, r13
    lea rsi, [interaction_token]
    mov edx, interaction_token_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, [expected_health_edit_len]
    jne .bad
    mov rdi, rbx
    mov rsi, [expected_health_edit_ptr]
    mov edx, [expected_health_edit_len]
    call equal_bytes
    test al, al
    jz .bad
    inc qword [health_edit_calls]
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=guild, ESI=guild len, RDX=role, ECX=role len. The default test seam
; fails closed unless a later auto-role case explicitly authorizes it.
guild_auth_bot_above_role:
    mov al, [autorole_hierarchy_allowed]
    ret

; RDI=guild, ESI=guild len, RDX=word, ECX=word len. Existing cases do not
; yet invoke word writes; local seams keep handler linkage isolated.
guild_word_add:
    mov r8d, 0
    jmp guild_word_check

guild_word_remove:
    mov r8d, 1

guild_word_check:
    push rbx
    push r12
    push r13
    mov ebx, r8d
    mov r12, rdx
    mov r13d, ecx
    cmp esi, model_guild_id_len
    jne .bad
    lea rsi, [model_guild_id]
    mov edx, model_guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r13d, [expected_word_len]
    jne .bad
    mov rdi, r12
    mov rsi, [expected_word_ptr]
    mov edx, [expected_word_len]
    call equal_bytes
    test al, al
    jz .bad
    test ebx, ebx
    jnz .remove
    inc qword [word_add_calls]
    jmp .ok
.remove:
    inc qword [word_remove_calls]
.ok:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

; RDI=guild, ESI=guild len, RDX=setting, ECX=setting len. The existing
; cases below do not invoke deletion; this local seam provides link coverage.
guild_config_delete:
    push rbx
    push r12
    mov rbx, rdx
    mov r12d, ecx
    cmp esi, model_guild_id_len
    jne .bad
    lea rsi, [model_guild_id]
    mov edx, model_guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, [expected_delete_setting_len]
    jne .bad
    mov rdi, rbx
    mov rsi, [expected_delete_setting_ptr]
    mov edx, [expected_delete_setting_len]
    call equal_bytes
    test al, al
    jz .bad
    inc qword [config_delete_calls]
    xor eax, eax
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    pop r12
    pop rbx
    ret

; RDI=id, ESI=id len, RDX=token, ECX=token len, R8=content, R9D=content len,
; RAX=flags. Test seam accepts only the expected ephemeral callback.
discord_interaction_respond_text:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdx
    mov r13d, ecx
    mov r14, r8
    mov r15d, r9d
    mov ebx, eax
    cmp esi, interaction_id_len
    jne .bad
    lea rsi, [interaction_id]
    mov edx, interaction_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r13d, interaction_token_len
    jne .bad
    mov rdi, r12
    lea rsi, [interaction_token]
    mov edx, interaction_token_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r15d, [expected_content_len]
    jne .bad
    mov rdi, r14
    mov rsi, [expected_content_ptr]
    mov edx, r15d
    call equal_bytes
    test al, al
    jz .bad
    cmp ebx, 64
    jne .bad
    inc qword [callback_calls]
    xor eax, eax
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

; RDI=guild, ESI=guild len, RDX=setting, ECX=setting len, R8=value, R9D=len.
guild_config_set:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdx
    mov r12, r8
    mov r13d, r9d
    mov r14d, ecx
    cmp esi, [expected_config_guild_len]
    jne .bad
    mov rsi, [expected_config_guild_ptr]
    mov edx, [expected_config_guild_len]
    call equal_bytes
    test al, al
    jz .bad
    cmp r14d, [expected_config_setting_len]
    jne .bad
    mov rdi, rbx
    mov rsi, [expected_config_setting_ptr]
    mov edx, [expected_config_setting_len]
    call equal_bytes
    test al, al
    jz .bad
    cmp r13d, [expected_config_value_len]
    jne .bad
    mov rdi, r12
    mov rsi, [expected_config_value_ptr]
    mov edx, [expected_config_value_len]
    call equal_bytes
    test al, al
    jz .bad
    inc qword [config_set_calls]
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

; RDI=id, ESI=len, RDX=token, ECX=len, R8=response JSON, R9D=len.
discord_interaction_respond_json:
    push rbx
    push r12
    mov rbx, r8
    mov r12d, r9d
    cmp esi, interaction_id_len
    jne .bad
    lea rsi, [interaction_id]
    mov edx, interaction_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r12d, [expected_json_len]
    jne .bad
    mov rdi, rbx
    mov rsi, [expected_json_ptr]
    mov edx, r12d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [json_callback_calls]
    xor eax, eax
    jmp .json_out
.bad:
    mov eax, -1
.json_out:
    pop r12
    pop rbx
    ret

; RDI and RSI buffers, EDX count. AL=1 when exact.
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
interaction_id: db '112233445566778899'
interaction_id_len equ $ - interaction_id
interaction_token: db 'abc_DEF-123.token'
interaction_token_len equ $ - interaction_token
info_frame: db '{"op":0,"s":1,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"data":{"id":"1","name":"info","type":1}}}'
info_frame_len equ $ - info_frame
help_frame: db '{"op":0,"s":2,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"data":{"id":"2","name":"help","type":1}}}'
help_frame_len equ $ - help_frame
unknown_frame: db '{"op":0,"s":3,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"data":{"id":"3","name":"other","type":1}}}'
dashboard_admin_frame: db '{"op":0,"s":3,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"id":"3","name":"dashboard","type":1}}}'
dashboard_admin_frame_len equ $ - dashboard_admin_frame
dashboard_denied_frame: db '{"op":0,"s":4,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"guild_id":"1","member":{"permissions":"0","user":{"id":"member-1"}},"data":{"id":"4","name":"dashboard","type":1}}}'
dashboard_denied_frame_len equ $ - dashboard_denied_frame
dashboard_back_frame: db '{"op":0,"s":5,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_back","component_type":2}}}'
dashboard_back_frame_len equ $ - dashboard_back_frame
dashboard_general_frame: db '{"op":0,"s":6,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_general","component_type":2}}}'
dashboard_general_frame_len equ $ - dashboard_general_frame
dashboard_welcome_frame: db '{"op":0,"s":7,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_welcome","component_type":2}}}'
dashboard_welcome_frame_len equ $ - dashboard_welcome_frame
dashboard_model_frame: db '{"op":0,"s":8,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_model","component_type":2}}}'
dashboard_model_frame_len equ $ - dashboard_model_frame
dashboard_model_llama_frame: db '{"op":0,"s":9,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_model_llama70b","component_type":2}}}'
dashboard_model_llama_frame_len equ $ - dashboard_model_llama_frame
dashboard_model_gpt120_frame: db '{"op":0,"s":10,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_model_gpt120b","component_type":2}}}'
dashboard_model_gpt120_frame_len equ $ - dashboard_model_gpt120_frame
dashboard_model_gpt20_frame: db '{"op":0,"s":11,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_model_gpt20b","component_type":2}}}'
dashboard_model_gpt20_frame_len equ $ - dashboard_model_gpt20_frame
dashboard_model_qwen_frame: db '{"op":0,"s":12,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_model_qwen32b","component_type":2}}}'
dashboard_model_qwen_frame_len equ $ - dashboard_model_qwen_frame
model_missing_guild_frame: db '{"op":0,"s":13,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_model_llama70b","component_type":2}}}'
model_missing_guild_frame_len equ $ - model_missing_guild_frame
dashboard_setlog_frame: db '{"op":0,"s":7,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_setlog","component_type":2}}}'
dashboard_setlog_frame_len equ $ - dashboard_setlog_frame
modal_setlog_submit_frame: db '{"op":0,"s":8,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"123456789012345678","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setlog","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","value":"987654321098765432"}]}]}}}'
modal_setlog_submit_frame_len equ $ - modal_setlog_submit_frame
modal_setwelcome_submit_frame: db '{"op":0,"s":14,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setwelcome","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","value":"111111111111111111"}]}]}}}'
modal_setwelcome_submit_frame_len equ $ - modal_setwelcome_submit_frame
modal_setgoodbye_submit_frame: db '{"op":0,"s":15,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setgoodbye","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","value":"222222222222222222"}]}]}}}'
modal_setgoodbye_submit_frame_len equ $ - modal_setgoodbye_submit_frame
modal_setwelcomemsg_submit_frame: db '{"op":0,"s":16,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setwelcomemsg","components":[{"type":1,"components":[{"type":4,"custom_id":"msg","value":"Selamat datang {user}"}]}]}}}'
modal_setwelcomemsg_submit_frame_len equ $ - modal_setwelcomemsg_submit_frame
modal_setgoodbyemsg_submit_frame: db '{"op":0,"s":17,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setgoodbyemsg","components":[{"type":1,"components":[{"type":4,"custom_id":"msg","value":"Sampai jumpa {username}"}]}]}}}'
modal_setgoodbyemsg_submit_frame_len equ $ - modal_setgoodbyemsg_submit_frame
modal_setlevelchannel_submit_frame: db '{"op":0,"s":18,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setlevelchannel","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","value":"333333333333333333"}]}]}}}'
modal_setlevelchannel_submit_frame_len equ $ - modal_setlevelchannel_submit_frame
modal_setpersona_submit_frame: db '{"op":0,"s":19,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setpersona","components":[{"type":1,"components":[{"type":4,"custom_id":"prompt","value":"Kamu adalah asisten ramah."}]}]}}}'
modal_setpersona_submit_frame_len equ $ - modal_setpersona_submit_frame
modal_sethistory_submit_frame: db '{"op":0,"s":20,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_sethistory","components":[{"type":1,"components":[{"type":4,"custom_id":"limit","value":"32"}]}]}}}'
modal_sethistory_submit_frame_len equ $ - modal_sethistory_submit_frame
modal_addword_submit_frame: db '{"op":0,"s":22,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_addword","components":[{"type":1,"components":[{"type":4,"custom_id":"word","value":"Bad_Word"}]}]}}}'
modal_addword_submit_frame_len equ $ - modal_addword_submit_frame
modal_removeword_submit_frame: db '{"op":0,"s":23,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_removeword","components":[{"type":1,"components":[{"type":4,"custom_id":"word","value":"Bad_Word"}]}]}}}'
modal_removeword_submit_frame_len equ $ - modal_removeword_submit_frame
modal_setautorole_submit_frame: db '{"op":0,"s":24,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":5,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"modal_setautorole","components":[{"type":1,"components":[{"type":4,"custom_id":"role_id","value":"444444444444444444"}]}]}}}'
modal_setautorole_submit_frame_len equ $ - modal_setautorole_submit_frame
dashboard_resetpersona_frame: db '{"op":0,"s":21,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_resetpersona","component_type":2}}}'
dashboard_resetpersona_frame_len equ $ - dashboard_resetpersona_frame
healthcheck_frame: db '{"op":0,"s":25,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"id":"1","name":"healthcheck","type":1}}}'
healthcheck_frame_len equ $ - healthcheck_frame
healthcheck_denied_frame: db '{"op":0,"s":26,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"guild_id":"1","member":{"permissions":"0","user":{"id":"member-1"}},"data":{"id":"1","name":"healthcheck","type":1}}}'
healthcheck_denied_frame_len equ $ - healthcheck_denied_frame
dashboard_status_frame: db '{"op":0,"s":27,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":3,"guild_id":"1","member":{"permissions":"8","user":{"id":"admin-1"}},"data":{"custom_id":"dash_status","component_type":2}}}'
dashboard_status_frame_len equ $ - dashboard_status_frame
unknown_frame_len equ $ - unknown_frame
wrong_type_frame: db '{"op":0,"s":4,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":4,"data":{"id":"4","name":"info","type":1}}}'
wrong_type_frame_len equ $ - wrong_type_frame
malformed_frame: db '{"op":0,"s":4,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"data":{"id":"4","name":"info"}}'
malformed_frame_len equ $ - malformed_frame
info_response: db 'Caine — AI Discord Bot. Status: Online. Default model: Llama 3.3 70B.'
info_response_len equ $ - info_response
help_response: db 'Caine commands: chat via prefix or mention; moderation, AFK, leveling, configuration, /info, and /help.'
help_response_len equ $ - help_response
manager_denied_response: db 'Khusus admin atau bot owner.'
manager_denied_response_len equ $ - manager_denied_response
dashboard_response: db '{"type":4,"data":{"flags":64,"embeds":[{"color":5793266,"title":"Dashboard Bot Caine","description":"Pilih menu di bawah:"}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"General","custom_id":"dash_general"},{"type":2,"style":3,"label":"Welcome/Goodbye","custom_id":"dash_welcome"},{"type":2,"style":2,"label":"Auto-role","custom_id":"dash_autorole"},{"type":2,"style":2,"label":"Leveling","custom_id":"dash_leveling"}]},{"type":1,"components":[{"type":2,"style":1,"label":"Persona","custom_id":"dash_persona"},{"type":2,"style":1,"label":"Model AI","custom_id":"dash_model"},{"type":2,"style":4,"label":"Moderation","custom_id":"dash_moderation"},{"type":2,"style":1,"label":"Status Bot","custom_id":"dash_status"}]}]}}'
dashboard_response_len equ $ - dashboard_response
dashboard_back_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":5793266,"title":"Dashboard Bot Caine","description":"Pilih menu di bawah:"}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"General","custom_id":"dash_general"},{"type":2,"style":3,"label":"Welcome/Goodbye","custom_id":"dash_welcome"},{"type":2,"style":2,"label":"Auto-role","custom_id":"dash_autorole"},{"type":2,"style":2,"label":"Leveling","custom_id":"dash_leveling"}]},{"type":1,"components":[{"type":2,"style":1,"label":"Persona","custom_id":"dash_persona"},{"type":2,"style":1,"label":"Model AI","custom_id":"dash_model"},{"type":2,"style":4,"label":"Moderation","custom_id":"dash_moderation"},{"type":2,"style":1,"label":"Status Bot","custom_id":"dash_status"}]}]}}'
dashboard_back_response_len equ $ - dashboard_back_response
dashboard_general_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":5793266,"title":"General Settings","fields":[{"name":"Log Channel","value":"Atur melalui tombol di bawah."}]}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set Log Channel","custom_id":"dash_setlog"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_general_response_len equ $ - dashboard_general_response
dashboard_welcome_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":65407,"title":"Welcome / Goodbye","description":"Atur channel dan pesan melalui tombol di bawah."}],"components":[{"type":1,"components":[{"type":2,"style":3,"label":"Set Welcome Channel","custom_id":"dash_setwelcome"},{"type":2,"style":1,"label":"Set Welcome Message","custom_id":"dash_setwelcomemsg"},{"type":2,"style":4,"label":"Set Goodbye Channel","custom_id":"dash_setgoodbye"},{"type":2,"style":1,"label":"Set Goodbye Message","custom_id":"dash_setgoodbyemsg"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_welcome_response_len equ $ - dashboard_welcome_response
dashboard_model_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":49151,"title":"Model AI","description":"Pilih model aktif."}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Llama 3.3 70B","custom_id":"dash_model_llama70b"},{"type":2,"style":2,"label":"GPT OSS 120B","custom_id":"dash_model_gpt120b"},{"type":2,"style":2,"label":"GPT OSS 20B","custom_id":"dash_model_gpt20b"},{"type":2,"style":2,"label":"Qwen 32B","custom_id":"dash_model_qwen32b"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_model_response_len equ $ - dashboard_model_response
modal_setlog_response: db '{"type":9,"data":{"custom_id":"modal_setlog","title":"Set Log Channel","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","label":"Channel ID","style":1,"required":true,"placeholder":"Contoh: 1234567890123456789"}]}]}}'
modal_setlog_response_len equ $ - modal_setlog_response
setlog_saved_response: db 'Log channel diset.'
setlog_saved_response_len equ $ - setlog_saved_response
modal_guild_id: db '123456789012345678'
modal_guild_id_len equ $ - modal_guild_id
modal_channel_id: db '987654321098765432'
modal_channel_id_len equ $ - modal_channel_id
setting_log_channel: db 'log_channel'
setting_log_channel_len equ $ - setting_log_channel
setting_model: db 'model'
setting_model_len equ $ - setting_model
model_guild_id: db '1'
model_guild_id_len equ $ - model_guild_id
model_id_llama: db 'llama-3.3-70b-versatile'
model_id_llama_len equ $ - model_id_llama
model_id_gpt120: db 'openai/gpt-oss-120b'
model_id_gpt120_len equ $ - model_id_gpt120
model_id_gpt20: db 'openai/gpt-oss-20b'
model_id_gpt20_len equ $ - model_id_gpt20
model_id_qwen: db 'qwen/qwen3-32b'
model_id_qwen_len equ $ - model_id_qwen
model_llama_saved_response: db 'Model diganti ke llama-3.3-70b-versatile.'
model_llama_saved_response_len equ $ - model_llama_saved_response
model_gpt120_saved_response: db 'Model diganti ke openai/gpt-oss-120b.'
model_gpt120_saved_response_len equ $ - model_gpt120_saved_response
model_gpt20_saved_response: db 'Model diganti ke openai/gpt-oss-20b.'
model_gpt20_saved_response_len equ $ - model_gpt20_saved_response
model_qwen_saved_response: db 'Model diganti ke qwen/qwen3-32b.'
model_qwen_saved_response_len equ $ - model_qwen_saved_response
config_failure_response: db 'Konfigurasi tidak dapat disimpan.'
config_failure_response_len equ $ - config_failure_response
setwelcome_saved_response: db 'Welcome channel diset.'
setwelcome_saved_response_len equ $ - setwelcome_saved_response
setgoodbye_saved_response: db 'Goodbye channel diset.'
setgoodbye_saved_response_len equ $ - setgoodbye_saved_response
setwelcomemsg_saved_response: db 'Pesan welcome diupdate.'
setwelcomemsg_saved_response_len equ $ - setwelcomemsg_saved_response
setgoodbyemsg_saved_response: db 'Pesan goodbye diupdate.'
setgoodbyemsg_saved_response_len equ $ - setgoodbyemsg_saved_response
welcome_channel_id: db '111111111111111111'
welcome_channel_id_len equ $ - welcome_channel_id
goodbye_channel_id: db '222222222222222222'
goodbye_channel_id_len equ $ - goodbye_channel_id
welcome_message: db 'Selamat datang {user}'
welcome_message_len equ $ - welcome_message
goodbye_message: db 'Sampai jumpa {username}'
goodbye_message_len equ $ - goodbye_message
setting_welcome_channel: db 'welcome_channel'
setting_welcome_channel_len equ $ - setting_welcome_channel
setting_goodbye_channel: db 'goodbye_channel'
setting_goodbye_channel_len equ $ - setting_goodbye_channel
setting_welcome_message: db 'welcome_msg'
setting_welcome_message_len equ $ - setting_welcome_message
setting_goodbye_message: db 'goodbye_msg'
setting_goodbye_message_len equ $ - setting_goodbye_message
setting_level_channel: db 'level_channel'
setting_level_channel_len equ $ - setting_level_channel
setting_persona: db 'system_prompt'
setting_persona_len equ $ - setting_persona
setting_history: db 'max_history'
setting_history_len equ $ - setting_history
level_channel_id: db '333333333333333333'
level_channel_id_len equ $ - level_channel_id
persona_value: db 'Kamu adalah asisten ramah.'
persona_value_len equ $ - persona_value
history_limit: db '32'
history_limit_len equ $ - history_limit
levelchannel_saved_response: db 'Level-up channel diset.'
levelchannel_saved_response_len equ $ - levelchannel_saved_response
persona_saved_response: db 'Persona diupdate.'
persona_saved_response_len equ $ - persona_saved_response
persona_reset_response: db 'Persona direset ke default.'
persona_reset_response_len equ $ - persona_reset_response
history_saved_response: db 'History limit diset.'
history_saved_response_len equ $ - history_saved_response
normalized_word: db 'bad_word'
normalized_word_len equ $ - normalized_word
word_added_response: db 'Kata ditambahkan ke blacklist.'
word_added_response_len equ $ - word_added_response
word_removed_response: db 'Kata dihapus dari blacklist.'
word_removed_response_len equ $ - word_removed_response
health_probe_value: db 'cache_ping'
health_probe_value_len equ $ - health_probe_value
health_bot_roles: db '["2002"]'
health_bot_roles_len equ $ - health_bot_roles
healthcheck_deferred_response: db '{"type":5,"data":{"flags":64}}'
healthcheck_deferred_response_len equ $ - healthcheck_deferred_response
healthcheck_ok_edit: db '{"embeds":[{"color":65416,"title":"Semua sistem normal","fields":[{"name":"State Storage","value":"Read/write OK","inline":true},{"name":"In-memory Cache","value":"Hit/invalidate OK","inline":true},{"name":"Groq API","value":"Probe respons OK","inline":true},{"name":"Bot Permissions","value":"Permission cache OK","inline":true},{"name":"Discord Latency","value":"Heartbeat ACK <= 500ms","inline":true}]}]}'
healthcheck_ok_edit_len equ $ - healthcheck_ok_edit
healthcheck_degraded_edit: db '{"embeds":[{"color":16729156,"title":"Ada komponen bermasalah","description":"Satu atau lebih probe bounded gagal atau cache belum lengkap. Periksa konfigurasi dan coba lagi."}]}'
healthcheck_degraded_edit_len equ $ - healthcheck_degraded_edit
status_dynamic_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":65416,"title":"Status Bot","fields":[{"name":"Status","value":"Online"},{"name":"History Limit","value":"32 messages"}]}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set History Limit","custom_id":"dash_sethistory"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
status_dynamic_response_len equ $ - status_dynamic_response
general_log_channel: db '111111111111111111'
general_log_channel_len equ $ - general_log_channel
dashboard_general_dynamic_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":5793266,"title":"General Settings","fields":[{"name":"Log Channel ID","value":"111111111111111111"},{"name":"Disabled Channels","value":"Tidak ada atau tidak tercache."}]}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set Log Channel","custom_id":"dash_setlog"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_general_dynamic_response_len equ $ - dashboard_general_dynamic_response
health_probe_setting: db '__healthcheck_probe__'
health_probe_setting_len equ $ - health_probe_setting
autorole_id: db '444444444444444444'
autorole_id_len equ $ - autorole_id
setting_autorole: db 'auto_role'
setting_autorole_len equ $ - setting_autorole
autorole_saved_response: db 'Auto-role diset.'
autorole_saved_response_len equ $ - autorole_saved_response

section .data
callback_calls: dq 0
json_callback_calls: dq 0
config_set_calls: dq 0
config_delete_calls: dq 0
word_add_calls: dq 0
word_remove_calls: dq 0
autorole_hierarchy_allowed: db 0
health_permission_allowed: db 1
status_history_mode: db 0
general_log_mode: db 0
health_edit_calls: dq 0
gateway_bot_user_id: db '998877665544332211'
gateway_bot_user_id_len: dd 18
gateway_last_heartbeat_latency_ms: dq 100
bot_owner_ptr: dq 0
bot_owner_len: dd 0
expected_json_ptr: dq 0
expected_json_len: dd 0
expected_content_ptr: dq 0
expected_content_len: dd 0
expected_config_guild_ptr: dq 0
expected_config_guild_len: dd 0
expected_config_setting_ptr: dq 0
expected_config_setting_len: dd 0
expected_config_value_ptr: dq 0
expected_config_value_len: dd 0
expected_word_ptr: dq 0
expected_word_len: dd 0
expected_delete_setting_ptr: dq 0
expected_delete_setting_len: dd 0
expected_health_edit_ptr: dq 0
expected_health_edit_len: dd 0
failure_stage: dd 0

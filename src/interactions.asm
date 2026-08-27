DEFAULT REL

global interaction_handle_gateway

extern json_object_find_direct_key
extern json_read_string
extern json_read_uint
extern json_object_end
extern json_array_end
extern discord_interaction_respond_text
extern discord_interaction_respond_json
extern bot_owner_ptr
extern bot_owner_len
extern guild_config_set
extern guild_config_delete
extern guild_word_add
extern guild_word_remove
extern guild_auth_bot_above_role
extern guild_auth_get_bot_roles
extern guild_auth_roles_have
extern guild_config_get
extern groq_select_guild
extern groq_select_history
extern groq_chat_once
extern discord_interaction_edit_original
extern gateway_bot_user_id
extern gateway_bot_user_id_len
extern gateway_last_heartbeat_latency_ms

%define FRAME_ID_CAP 64
%define TOKEN_CAP 192
%define NAME_CAP 64
%define CONFIG_TEXT_CAP 512
%define EPHEMERAL_FLAG 64
%define PERMISSION_ADMINISTRATOR 0x8
%define DASHBOARD_DYNAMIC_CAP 1024

section .text

; RDI=full Gateway INTERACTION_CREATE frame, RSI=len. EAX=0 handled/ignored,
; -1 only when a matched callback cannot be delivered. All parsing is bounded;
; the one-time interaction token stays in fixed BSS and is never persisted.
interaction_handle_gateway:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .ignored
    test r13, r13
    jle .ignored
    ; Never parse a partial frame: exactly one complete root object is required.
    mov rdi, r12
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .ignored
    lea rdx, [r12 + r13]
    cmp rax, rdx
    jne .ignored

    ; The payload `d` must be a complete object in the received frame.
    mov rdi, r12
    lea rsi, [r12 + r13]
    lea rdx, [key_data]
    mov ecx, key_data_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .ignored
    mov r14, rax
    mov [interaction_payload_end], r14

    ; Only APPLICATION_COMMAND (type 2) is handled here. The type value must
    ; precede the nested command data in the top-level interaction payload.
    mov rdi, rbx
    mov rsi, r14
    lea rdx, [key_type]
    mov ecx, key_type_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    call json_read_uint
    jc .ignored
    mov [interaction_type], eax
    cmp eax, 2
    je .credentials
    cmp eax, 3
    je .credentials
    cmp eax, 5
    jne .ignored
.credentials:
    ; Interaction ID and token occur at the interaction payload object level.
    mov rdi, rbx
    mov rsi, r14
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_id]
    mov ecx, FRAME_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .ignored
    mov [interaction_id_len], eax
    mov byte [interaction_id + rax], 0

    mov rdi, rbx
    mov rsi, r14
    lea rdx, [key_token]
    mov ecx, key_token_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_token]
    mov ecx, TOKEN_CAP - 1
    call json_read_string
    test eax, eax
    jle .ignored
    mov [interaction_token_len], eax
    mov byte [interaction_token + rax], 0
    cmp dword [interaction_type], 3
    je .component
    cmp dword [interaction_type], 5
    je .modal

    mov rdi, rbx
    mov rsi, r14
    lea rdx, [key_command_data]
    mov ecx, key_command_data_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov r15, rax
    mov rdi, r15
    mov rsi, r14
    call json_object_end
    test rax, rax
    jz .ignored
    mov r14, rax
    mov rdi, r15
    mov rsi, r14
    lea rdx, [key_name]
    mov ecx, key_name_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_name]
    mov ecx, NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .ignored
    mov [interaction_name_len], eax

    lea rdi, [interaction_name]
    mov esi, [interaction_name_len]
    lea rdx, [name_info]
    mov ecx, name_info_len
    call equal_literal
    test al, al
    jnz .info
    lea rdi, [interaction_name]
    mov esi, [interaction_name_len]
    lea rdx, [name_help]
    mov ecx, name_help_len
    call equal_literal
    test al, al
    jnz .help
    lea rdi, [interaction_name]
    mov esi, [interaction_name_len]
    lea rdx, [name_dashboard]
    mov ecx, name_dashboard_len
    call equal_literal
    test al, al
    jnz .dashboard
    lea rdi, [interaction_name]
    mov esi, [interaction_name_len]
    lea rdx, [name_healthcheck]
    mov ecx, name_healthcheck_len
    call equal_literal
    test al, al
    jnz .healthcheck
    jmp .ignored
.component:
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    lea rdx, [key_command_data]
    mov ecx, key_command_data_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov r15, rax
    mov rdi, r15
    mov rsi, [interaction_payload_end]
    call json_object_end
    test rax, rax
    jz .ignored
    mov r14, rax
    mov rdi, r15
    mov rsi, r14
    lea rdx, [key_custom_id]
    mov ecx, key_custom_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_component_id]
    mov ecx, NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .ignored
    mov [interaction_component_id_len], eax
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    call interaction_is_manager
    test al, al
    jz .component_denied
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    call interaction_load_guild_id
    test al, al
    jz .component_config_failure
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_back]
    mov ecx, component_back_len
    call equal_literal
    test al, al
    jnz .component_back
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_general]
    mov ecx, component_general_len
    call equal_literal
    test al, al
    jnz .component_general
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setlog]
    mov ecx, component_setlog_len
    call equal_literal
    test al, al
    jnz .component_setlog
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_welcome]
    mov ecx, component_welcome_len
    call equal_literal
    test al, al
    jnz .component_welcome
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setwelcome]
    mov ecx, component_setwelcome_len
    call equal_literal
    test al, al
    jnz .component_setwelcome
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setgoodbye]
    mov ecx, component_setgoodbye_len
    call equal_literal
    test al, al
    jnz .component_setgoodbye
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setwelcomemsg]
    mov ecx, component_setwelcomemsg_len
    call equal_literal
    test al, al
    jnz .component_setwelcomemsg
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setgoodbyemsg]
    mov ecx, component_setgoodbyemsg_len
    call equal_literal
    test al, al
    jnz .component_setgoodbyemsg
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_autorole]
    mov ecx, component_autorole_len
    call equal_literal
    test al, al
    jnz .component_autorole
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setautorole]
    mov ecx, component_setautorole_len
    call equal_literal
    test al, al
    jnz .component_setautorole
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_removeautorole]
    mov ecx, component_removeautorole_len
    call equal_literal
    test al, al
    jnz .component_removeautorole
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_moderation]
    mov ecx, component_moderation_len
    call equal_literal
    test al, al
    jnz .component_moderation
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_addword]
    mov ecx, component_addword_len
    call equal_literal
    test al, al
    jnz .component_addword
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_removeword]
    mov ecx, component_removeword_len
    call equal_literal
    test al, al
    jnz .component_removeword
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_leveling]
    mov ecx, component_leveling_len
    call equal_literal
    test al, al
    jnz .component_leveling
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setlevelchannel]
    mov ecx, component_setlevelchannel_len
    call equal_literal
    test al, al
    jnz .component_setlevelchannel
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_persona]
    mov ecx, component_persona_len
    call equal_literal
    test al, al
    jnz .component_persona
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_setpersona]
    mov ecx, component_setpersona_len
    call equal_literal
    test al, al
    jnz .component_setpersona
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_resetpersona]
    mov ecx, component_resetpersona_len
    call equal_literal
    test al, al
    jnz .component_resetpersona
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_status]
    mov ecx, component_status_len
    call equal_literal
    test al, al
    jnz .component_status
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_sethistory]
    mov ecx, component_sethistory_len
    call equal_literal
    test al, al
    jnz .component_sethistory
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_model]
    mov ecx, component_model_len
    call equal_literal
    test al, al
    jnz .component_model
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_model_llama]
    mov ecx, component_model_llama_len
    call equal_literal
    test al, al
    jnz .model_llama
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_model_gpt120]
    mov ecx, component_model_gpt120_len
    call equal_literal
    test al, al
    jnz .model_gpt120
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_model_gpt20]
    mov ecx, component_model_gpt20_len
    call equal_literal
    test al, al
    jnz .model_gpt20
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_model_qwen]
    mov ecx, component_model_qwen_len
    call equal_literal
    test al, al
    jz .ignored
.model_qwen:
    lea r8, [model_id_qwen]
    mov r9d, model_id_qwen_len
    lea r10, [model_qwen_saved_response]
    mov r11d, model_qwen_saved_response_len
    jmp .model_save
.model_gpt20:
    lea r8, [model_id_gpt20]
    mov r9d, model_id_gpt20_len
    lea r10, [model_gpt20_saved_response]
    mov r11d, model_gpt20_saved_response_len
    jmp .model_save
.model_gpt120:
    lea r8, [model_id_gpt120]
    mov r9d, model_id_gpt120_len
    lea r10, [model_gpt120_saved_response]
    mov r11d, model_gpt120_saved_response_len
    jmp .model_save
.model_llama:
    lea r8, [model_id_llama]
    mov r9d, model_id_llama_len
    lea r10, [model_llama_saved_response]
    mov r11d, model_llama_saved_response_len
.model_save:
    ; guild_config_set may clobber all caller-saved registers; retain the
    ; selected response on aligned stack storage across the persistence call.
    sub rsp, 16
    mov [rsp], r10
    mov dword [rsp + 8], r11d
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    call guild_config_set
    test eax, eax
    js .model_save_failed
    mov r8, [rsp]
    mov r9d, [rsp + 8]
    add rsp, 16
    jmp .respond
.model_save_failed:
    add rsp, 16
    jmp .component_config_failure
.component_removeautorole:
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [setting_autorole]
    mov ecx, setting_autorole_len
    call guild_config_delete
    test eax, eax
    js .component_config_failure
    lea r8, [autorole_removed_response]
    mov r9d, autorole_removed_response_len
    jmp .respond
.component_setautorole:
    lea r8, [modal_setautorole_response]
    mov r9d, modal_setautorole_response_len
    jmp .component_respond_json
.component_autorole:
    lea r8, [dashboard_autorole_response]
    mov r9d, dashboard_autorole_response_len
    jmp .component_respond_json
.component_removeword:
    lea r8, [modal_removeword_response]
    mov r9d, modal_removeword_response_len
    jmp .component_respond_json
.component_addword:
    lea r8, [modal_addword_response]
    mov r9d, modal_addword_response_len
    jmp .component_respond_json
.component_moderation:
    lea r8, [dashboard_moderation_response]
    mov r9d, dashboard_moderation_response_len
    jmp .component_respond_json
.component_resetpersona:
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [setting_persona]
    mov ecx, setting_persona_len
    call guild_config_delete
    test eax, eax
    js .component_config_failure
    lea r8, [persona_reset_response]
    mov r9d, persona_reset_response_len
    jmp .respond
.component_sethistory:
    lea r8, [modal_sethistory_response]
    mov r9d, modal_sethistory_response_len
    jmp .component_respond_json
.component_status:
    call interaction_build_status_response
    test eax, eax
    js .component_config_failure
    mov r9d, eax
    lea r8, [dashboard_status_dynamic]
    jmp .component_respond_json
.component_setpersona:
    lea r8, [modal_setpersona_response]
    mov r9d, modal_setpersona_response_len
    jmp .component_respond_json
.component_persona:
    lea r8, [dashboard_persona_response]
    mov r9d, dashboard_persona_response_len
    jmp .component_respond_json
.component_setlevelchannel:
    lea r8, [modal_setlevelchannel_response]
    mov r9d, modal_setlevelchannel_response_len
    jmp .component_respond_json
.component_leveling:
    lea r8, [dashboard_leveling_response]
    mov r9d, dashboard_leveling_response_len
    jmp .component_respond_json
.component_model:
    lea r8, [dashboard_model_response]
    mov r9d, dashboard_model_response_len
    jmp .component_respond_json
.component_setgoodbyemsg:
    lea r8, [modal_setgoodbyemsg_response]
    mov r9d, modal_setgoodbyemsg_response_len
    jmp .component_respond_json
.component_setwelcomemsg:
    lea r8, [modal_setwelcomemsg_response]
    mov r9d, modal_setwelcomemsg_response_len
    jmp .component_respond_json
.component_setgoodbye:
    lea r8, [modal_setgoodbye_response]
    mov r9d, modal_setgoodbye_response_len
    jmp .component_respond_json
.component_setwelcome:
    lea r8, [modal_setwelcome_response]
    mov r9d, modal_setwelcome_response_len
    jmp .component_respond_json
.component_welcome:
    lea r8, [dashboard_welcome_response]
    mov r9d, dashboard_welcome_response_len
    jmp .component_respond_json
.component_setlog:
    lea r8, [modal_setlog_response]
    mov r9d, modal_setlog_response_len
    jmp .component_respond_json
.component_general:
    lea r8, [dashboard_general_response]
    mov r9d, dashboard_general_response_len
    jmp .component_respond_json
.component_back:
    lea r8, [dashboard_back_response]
    mov r9d, dashboard_back_response_len
    jmp .component_respond_json
.component_denied:
    lea r8, [manager_denied_response]
    mov r9d, manager_denied_response_len
    jmp .respond
.component_config_failure:
    lea r8, [config_failure_response]
    mov r9d, config_failure_response_len
    jmp .respond
.component_respond_json:
    lea rdi, [interaction_id]
    mov esi, [interaction_id_len]
    lea rdx, [interaction_token]
    mov ecx, [interaction_token_len]
    call discord_interaction_respond_json
    jmp .out

.modal:
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    call interaction_is_manager
    test al, al
    jz .component_denied
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    lea rdx, [key_guild_id]
    mov ecx, key_guild_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .modal_failure
    mov rdi, rax
    mov rsi, [interaction_payload_end]
    lea rdx, [interaction_guild_id]
    mov ecx, FRAME_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .modal_failure
    mov [interaction_guild_id_len], eax
    lea rdi, [interaction_guild_id]
    mov esi, eax
    call decimal_id_valid
    test al, al
    jz .modal_failure
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    lea rdx, [key_command_data]
    mov ecx, key_command_data_len
    call json_object_find_direct_key
    test rax, rax
    jz .modal_failure
    mov r15, rax
    mov rdi, r15
    mov rsi, [interaction_payload_end]
    call json_object_end
    test rax, rax
    jz .modal_failure
    mov r14, rax
    mov rdi, r15
    mov rsi, r14
    lea rdx, [key_custom_id]
    mov ecx, key_custom_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .modal_failure
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_component_id]
    mov ecx, NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .modal_failure
    mov [interaction_component_id_len], eax
    lea rdi, [interaction_component_id]
    mov esi, eax
    lea rdx, [modal_setlog_id]
    mov ecx, modal_setlog_id_len
    call equal_literal
    test al, al
    jnz .modal_setlog
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_setwelcome_id]
    mov ecx, modal_setwelcome_id_len
    call equal_literal
    test al, al
    jnz .modal_setwelcome
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_setgoodbye_id]
    mov ecx, modal_setgoodbye_id_len
    call equal_literal
    test al, al
    jnz .modal_setgoodbye
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_setwelcomemsg_id]
    mov ecx, modal_setwelcomemsg_id_len
    call equal_literal
    test al, al
    jnz .modal_setwelcomemsg
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_setautorole_id]
    mov ecx, modal_setautorole_id_len
    call equal_literal
    test al, al
    jnz .modal_setautorole
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_addword_id]
    mov ecx, modal_addword_id_len
    call equal_literal
    test al, al
    jnz .modal_addword
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_removeword_id]
    mov ecx, modal_removeword_id_len
    call equal_literal
    test al, al
    jnz .modal_removeword
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_setlevelchannel_id]
    mov ecx, modal_setlevelchannel_id_len
    call equal_literal
    test al, al
    jnz .modal_setlevelchannel
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_setpersona_id]
    mov ecx, modal_setpersona_id_len
    call equal_literal
    test al, al
    jnz .modal_setpersona
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_sethistory_id]
    mov ecx, modal_sethistory_id_len
    call equal_literal
    test al, al
    jnz .modal_sethistory
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [modal_setgoodbyemsg_id]
    mov ecx, modal_setgoodbyemsg_id_len
    call equal_literal
    test al, al
    jnz .modal_setgoodbyemsg
    jmp .ignored
.modal_setautorole:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_role_id]
    mov ecx, input_role_id_len
    call interaction_modal_save_autorole
    test eax, eax
    js .modal_failure
    lea r8, [autorole_saved_response]
    mov r9d, autorole_saved_response_len
    jmp .respond
.modal_removeword:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_word]
    mov ecx, input_word_len
    mov r8d, 1
    call interaction_modal_save_word
    test eax, eax
    js .modal_failure
    lea r8, [word_removed_response]
    mov r9d, word_removed_response_len
    jmp .respond
.modal_addword:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_word]
    mov ecx, input_word_len
    xor r8d, r8d
    call interaction_modal_save_word
    test eax, eax
    js .modal_failure
    lea r8, [word_added_response]
    mov r9d, word_added_response_len
    jmp .respond
.modal_sethistory:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_limit]
    mov ecx, input_limit_len
    lea r8, [setting_history]
    mov r9d, setting_history_len
    mov r10d, 2
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [history_saved_response]
    mov r9d, history_saved_response_len
    jmp .respond
.modal_setpersona:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_prompt]
    mov ecx, input_prompt_len
    lea r8, [setting_persona]
    mov r9d, setting_persona_len
    mov r10d, 1
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [persona_saved_response]
    mov r9d, persona_saved_response_len
    jmp .respond
.modal_setlevelchannel:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_channel_id]
    mov ecx, input_channel_id_len
    lea r8, [setting_level_channel]
    mov r9d, setting_level_channel_len
    xor r10d, r10d
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [levelchannel_saved_response]
    mov r9d, levelchannel_saved_response_len
    jmp .respond
.modal_setgoodbyemsg:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_msg]
    mov ecx, input_msg_len
    lea r8, [setting_goodbye_message]
    mov r9d, setting_goodbye_message_len
    mov r10d, 1
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [setgoodbyemsg_saved_response]
    mov r9d, setgoodbyemsg_saved_response_len
    jmp .respond
.modal_setwelcomemsg:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_msg]
    mov ecx, input_msg_len
    lea r8, [setting_welcome_message]
    mov r9d, setting_welcome_message_len
    mov r10d, 1
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [setwelcomemsg_saved_response]
    mov r9d, setwelcomemsg_saved_response_len
    jmp .respond
.modal_setgoodbye:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_channel_id]
    mov ecx, input_channel_id_len
    lea r8, [setting_goodbye_channel]
    mov r9d, setting_goodbye_channel_len
    xor r10d, r10d
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [setgoodbye_saved_response]
    mov r9d, setgoodbye_saved_response_len
    jmp .respond
.modal_setwelcome:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_channel_id]
    mov ecx, input_channel_id_len
    lea r8, [setting_welcome_channel]
    mov r9d, setting_welcome_channel_len
    xor r10d, r10d
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [setwelcome_saved_response]
    mov r9d, setwelcome_saved_response_len
    jmp .respond
.modal_setlog:
    mov rdi, r15
    mov rsi, r14
    lea rdx, [input_channel_id]
    mov ecx, input_channel_id_len
    lea r8, [setting_log_channel]
    mov r9d, setting_log_channel_len
    xor r10d, r10d
    call interaction_modal_save_config
    test eax, eax
    js .modal_failure
    lea r8, [setlog_saved_response]
    mov r9d, setlog_saved_response_len
    jmp .respond
.modal_failure:
    lea r8, [config_failure_response]
    mov r9d, config_failure_response_len
    jmp .respond

.info:
    lea r8, [info_response]
    mov r9d, info_response_len
    jmp .respond
.help:
    lea r8, [help_response]
    mov r9d, help_response_len
    jmp .respond
.healthcheck:
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    call interaction_is_manager
    test al, al
    jz .dashboard_denied
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    call interaction_load_guild_id
    test al, al
    jz .component_config_failure
    lea r8, [healthcheck_deferred_response]
    mov r9d, healthcheck_deferred_response_len
    lea rdi, [interaction_id]
    mov esi, [interaction_id_len]
    lea rdx, [interaction_token]
    mov ecx, [interaction_token_len]
    call discord_interaction_respond_json
    test eax, eax
    js .out
    call interaction_run_healthcheck
    ; Initial ACK already completed. A failed edit must not tear down Gateway.
    xor eax, eax
    jmp .out
.dashboard:
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    call interaction_is_manager
    test al, al
    jz .dashboard_denied
    lea r8, [dashboard_main_response]
    mov r9d, dashboard_main_response_len
    lea rdi, [interaction_id]
    mov esi, [interaction_id_len]
    lea rdx, [interaction_token]
    mov ecx, [interaction_token_len]
    call discord_interaction_respond_json
    jmp .out
.dashboard_denied:
    lea r8, [manager_denied_response]
    mov r9d, manager_denied_response_len
.respond:
    lea rdi, [interaction_id]
    mov esi, [interaction_id_len]
    lea rdx, [interaction_token]
    mov ecx, [interaction_token_len]
    mov eax, EPHEMERAL_FLAG
    call discord_interaction_respond_text
    jmp .out
.ignored:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Builds a type-7 dashboard status response without exposing arbitrary stored
; data. Only `max_history` accepted by interaction_history_valid is emitted.
; RAX is the response length, or -1 when the fixed body capacity would overflow.
interaction_build_status_response:
    push rbx
    push r12
    push r13
    push r14
    push r15
    lea r12, [status_default_history]
    mov r15d, status_default_history_len
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [setting_history]
    mov ecx, setting_history_len
    call guild_config_get
    test rax, rax
    jz .build
    test edx, edx
    jle .build
    mov r13, rax
    mov r14d, edx
    mov rdi, r13
    mov esi, r14d
    call interaction_history_valid
    test al, al
    jz .build
    mov r12, r13
    mov r15d, r14d
.build:
    mov eax, dashboard_status_prefix_len
    add eax, r15d
    add eax, dashboard_status_suffix_len
    cmp eax, DASHBOARD_DYNAMIC_CAP - 1
    ja .bad
    mov ebx, eax
    lea rdi, [dashboard_status_dynamic]
    lea rsi, [dashboard_status_prefix]
    mov edx, dashboard_status_prefix_len
    call interaction_copy_bytes
    lea rdi, [dashboard_status_dynamic + dashboard_status_prefix_len]
    mov rsi, r12
    mov edx, r15d
    call interaction_copy_bytes
    lea rdi, [dashboard_status_dynamic + dashboard_status_prefix_len]
    add rdi, r15
    lea rsi, [dashboard_status_suffix]
    mov edx, dashboard_status_suffix_len
    call interaction_copy_bytes
    mov byte [dashboard_status_dynamic + rbx], 0
    mov eax, ebx
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

; RDI=destination, RSI=source, EDX=count. Bounded callers prevalidate space.
interaction_copy_bytes:
    xor ecx, ecx
.loop:
    cmp ecx, edx
    jae .done
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    inc ecx
    jmp .loop
.done:
    ret

; Runs bounded synchronous probes after the initial type-5 callback. The
; bitmask is local-only: storage/cache=1, Groq=2, bot permissions=4, latency=8.
; The interaction token is reused only to edit its original response.
interaction_run_healthcheck:
    push rbx
    sub rsp, 8
    xor ebx, ebx
    call interaction_health_storage_probe
    test al, al
    jz .storage_done
    or ebx, 1
.storage_done:
    call interaction_health_groq_probe
    test al, al
    jz .groq_done
    or ebx, 2
.groq_done:
    call interaction_health_permissions_probe
    test al, al
    jz .permissions_done
    or ebx, 4
.permissions_done:
    call interaction_health_latency_probe
    test al, al
    jz .latency_done
    or ebx, 8
.latency_done:
    cmp ebx, 15
    jne .degraded
    lea r8, [healthcheck_ok_edit]
    mov r9d, healthcheck_ok_edit_len
    jmp .edit
.degraded:
    lea r8, [healthcheck_degraded_edit]
    mov r9d, healthcheck_degraded_edit_len
.edit:
    lea rdi, [gateway_bot_user_id]
    mov esi, [gateway_bot_user_id_len]
    lea rdx, [interaction_token]
    mov ecx, [interaction_token_len]
    call discord_interaction_edit_original
    add rsp, 8
    pop rbx
    ret

; AL=1 only after temporary guild config write, readback, and delete all work.
interaction_health_storage_probe:
    push r12
    push r13
    sub rsp, 8
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [health_probe_setting]
    mov ecx, health_probe_setting_len
    lea r8, [health_probe_value]
    mov r9d, health_probe_value_len
    call guild_config_set
    test eax, eax
    js .no
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [health_probe_setting]
    mov ecx, health_probe_setting_len
    call guild_config_get
    mov r12, rax
    mov r13d, edx
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [health_probe_setting]
    mov ecx, health_probe_setting_len
    call guild_config_delete
    test eax, eax
    js .no
    test r12, r12
    jz .no
    cmp r13d, health_probe_value_len
    jne .no
    mov rdi, r12
    lea rsi, [health_probe_value]
    mov edx, health_probe_value_len
    call equal_bytes
    test al, al
    jz .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    add rsp, 8
    pop r13
    pop r12
    ret

; AL=1 only after a bounded non-streaming Groq ping. No response is retained.
interaction_health_groq_probe:
    sub rsp, 8
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    call groq_select_guild
    xor edi, edi
    xor esi, esi
    call groq_select_history
    lea rdi, [health_probe_ping]
    mov esi, health_probe_ping_len
    lea rdx, [health_probe_reply]
    mov ecx, 1901
    call groq_chat_once
    test eax, eax
    js .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    add rsp, 8
    ret

; AL=1 only when cached bot roles prove all requested permissions or Administrator.
interaction_health_permissions_probe:
    sub rsp, 8
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    call guild_auth_get_bot_roles
    test rax, rax
    jz .no
    test edx, edx
    jle .no
    mov r9d, edx
    mov rdx, rax
    mov ecx, r9d
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    mov r8, 0x16800
    call guild_auth_roles_have
    test al, al
    jz .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    add rsp, 8
    ret

; AL=1 only for a freshly observed ACK latency at or below 500 milliseconds.
interaction_health_latency_probe:
    mov rax, [gateway_last_heartbeat_latency_ms]
    test rax, rax
    jz .no
    cmp rax, 500
    ja .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI bytes, ESI len, RDX literal, ECX literal len. AL=1 exact.
; RDI=interaction payload object, RSI=exclusive end. AL=1 only when the
; actor matches configured BOT_OWNER_ID or a guild member carries Administrator.
interaction_is_manager:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    xor r14d, r14d
    ; Member is optional for owner-operated DMs, but administrators require it.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_member]
    mov ecx, key_member_len
    call json_object_find_direct_key
    test rax, rax
    jz .outer_user
    cmp byte [rax], '{'
    jne .no
    mov r14, rax
    mov rdi, r14
    mov rsi, r13
    call json_object_end
    test rax, rax
    jz .no
    mov r15, rax
    mov rdi, r14
    mov rsi, r15
    lea rdx, [key_user]
    mov ecx, key_user_len
    call json_object_find_direct_key
    test rax, rax
    jz .no
    cmp byte [rax], '{'
    jne .no
    mov rbx, rax
    mov rdi, rbx
    mov rsi, r15
    call json_object_end
    test rax, rax
    jz .no
    mov r15, rax
    jmp .user_id
.outer_user:
    mov rbx, r12
    mov rdi, rbx
    mov rsi, r13
    lea rdx, [key_user]
    mov ecx, key_user_len
    call json_object_find_direct_key
    test rax, rax
    jz .no
    cmp byte [rax], '{'
    jne .no
    mov rbx, rax
    mov rdi, rbx
    mov rsi, r13
    call json_object_end
    test rax, rax
    jz .no
    mov r15, rax
.user_id:
    mov rdi, rbx
    mov rsi, r15
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .no
    mov rdi, rax
    mov rsi, r15
    lea rdx, [interaction_user_id]
    mov ecx, FRAME_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .no
    mov [interaction_user_id_len], eax
    mov eax, [bot_owner_len]
    test eax, eax
    jz .administrator
    cmp eax, [interaction_user_id_len]
    jne .administrator
    mov rdi, [bot_owner_ptr]
    test rdi, rdi
    jz .administrator
    lea rsi, [interaction_user_id]
    mov edx, [interaction_user_id_len]
    call equal_bytes
    test al, al
    jnz .yes
.administrator:
    test r14, r14
    jz .no
    ; Permissions must be a direct member field, never a descendant of member.
    mov rdi, r14
    mov rsi, r13
    call json_object_end
    test rax, rax
    jz .no
    mov r15, rax
    mov rdi, r14
    mov rsi, r15
    lea rdx, [key_permissions]
    mov ecx, key_permissions_len
    call json_object_find_direct_key
    test rax, rax
    jz .no
    mov rdi, rax
    mov rsi, r15
    lea rdx, [interaction_permissions]
    mov ecx, 31
    call json_read_string
    test eax, eax
    jle .no
    mov rdi, rdx
    sub rdi, rax
    dec rdi
    mov esi, eax
    call parse_decimal_u64
    test rdx, rdx
    jnz .no
    test rax, PERMISSION_ADMINISTRATOR
    jz .no
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

; RDI=modal data, RSI=end, RDX=input ID, ECX=input ID len. EAX=0 only if
; a decimal role ID is known and cached bot hierarchy proves it is assignable.
interaction_modal_save_autorole:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov ecx, r15d
    lea r8, [interaction_modal_value]
    mov r9d, FRAME_ID_CAP - 1
    call interaction_modal_read_value
    test eax, eax
    jle .bad
    mov [interaction_modal_value_len], eax
    lea rdi, [interaction_modal_value]
    mov esi, eax
    call decimal_id_valid
    test al, al
    jz .bad
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [interaction_modal_value]
    mov ecx, [interaction_modal_value_len]
    call guild_auth_bot_above_role
    test al, al
    jz .bad
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [setting_autorole]
    mov ecx, setting_autorole_len
    lea r8, [interaction_modal_value]
    mov r9d, [interaction_modal_value_len]
    call guild_config_set
    test eax, eax
    js .bad
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=modal data, RSI=end, RDX=input ID, ECX=input ID len, R8D=0 add/1
; remove. EAX=0 only if a normalized blacklist word is persisted successfully.
interaction_modal_save_word:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    mov ebx, r8d
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov ecx, r15d
    lea r8, [interaction_modal_value]
    mov r9d, CONFIG_TEXT_CAP - 1
    call interaction_modal_read_value
    test eax, eax
    jle .bad
    lea rdi, [interaction_modal_value]
    mov esi, eax
    call interaction_word_normalize
    test eax, eax
    jle .bad
    mov [interaction_word_len], eax
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    lea rdx, [interaction_word]
    mov ecx, eax
    test ebx, ebx
    jnz .remove
    call guild_word_add
    jmp .result
.remove:
    call guild_word_remove
.result:
    test eax, eax
    js .bad
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

; RDI=source, ESI=len. EAX=normalized ASCII word len (1..26), or -1.
; Only letters, digits, underscore, and hyphen are accepted; A-Z is folded.
interaction_word_normalize:
    test rdi, rdi
    jz .bad
    cmp esi, 1
    jb .bad
    cmp esi, 26
    ja .bad
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    mov al, [rdi + rcx]
    cmp al, 'A'
    jb .classify
    cmp al, 'Z'
    ja .classify
    add al, 'a' - 'A'
.classify:
    cmp al, 'a'
    jb .nonalpha
    cmp al, 'z'
    jbe .store
.nonalpha:
    cmp al, '0'
    jb .punctuation
    cmp al, '9'
    jbe .store
.punctuation:
    cmp al, '_'
    je .store
    cmp al, '-'
    jne .bad
.store:
    mov [interaction_word + rcx], al
    inc ecx
    jmp .loop
.done:
    mov eax, ecx
    ret
.bad:
    mov eax, -1
    ret

; RDI=modal data, RSI=end, RDX=input ID, ECX=input ID len, R8=setting,
; R9D=setting len, R10D=0 for decimal channel IDs or 1 for bounded text.
; EAX=0 only after a validated guild-scoped configuration write; -1 otherwise.
interaction_modal_save_config:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    mov [rsp], r8
    mov dword [rsp + 8], r9d
    mov dword [rsp + 12], r10d
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov ecx, r15d
    lea r8, [interaction_modal_value]
    mov r9d, CONFIG_TEXT_CAP - 1
    call interaction_modal_read_value
    test eax, eax
    jle .bad
    mov [interaction_modal_value_len], eax
    cmp dword [rsp + 12], 0
    je .channel
    cmp dword [rsp + 12], 1
    je .text
    cmp dword [rsp + 12], 2
    jne .bad
    lea rdi, [interaction_modal_value]
    mov esi, eax
    call interaction_history_valid
    test al, al
    jz .bad
    jmp .store
.channel:
    lea rdi, [interaction_modal_value]
    mov esi, eax
    call decimal_id_valid
    test al, al
    jz .bad
    jmp .store
.text:
    lea rdi, [interaction_modal_value]
    mov esi, eax
    call interaction_text_valid
    test al, al
    jz .bad
.store:
    lea rdi, [interaction_guild_id]
    mov esi, [interaction_guild_id_len]
    mov rdx, [rsp]
    mov ecx, [rsp + 8]
    lea r8, [interaction_modal_value]
    mov r9d, [interaction_modal_value_len]
    call guild_config_set
    test eax, eax
    js .bad
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=exact decimal ASCII bytes, ESI=len. AL=1 only for a value 5..100.
; Whitespace, signs, leading text, and overlong numeric forms are rejected.
interaction_history_valid:
    test rdi, rdi
    jz .no
    cmp esi, 1
    jb .no
    cmp esi, 3
    ja .no
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    movzx edx, byte [rdi + rcx]
    cmp dl, '0'
    jb .no
    cmp dl, '9'
    ja .no
    imul eax, eax, 10
    sub edx, '0'
    add eax, edx
    cmp eax, 100
    ja .no
    inc ecx
    jmp .loop
.done:
    cmp eax, 5
    jb .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI=decoded text bytes, ESI=len. AL=1 only for 1..511 byte user text
; containing no unsafe control bytes and at least one non-whitespace byte.
interaction_text_valid:
    test rdi, rdi
    jz .no
    cmp esi, 1
    jb .no
    cmp esi, CONFIG_TEXT_CAP - 1
    ja .no
    xor ecx, ecx
    xor edx, edx
.loop:
    cmp ecx, esi
    jae .done
    mov al, [rdi + rcx]
    cmp al, 0x20
    jae .printable
    cmp al, 9
    je .advance
    cmp al, 10
    je .advance
    cmp al, 13
    jne .no
.advance:
    inc ecx
    jmp .loop
.printable:
    cmp al, ' '
    je .advance
    mov edx, 1
    jmp .advance
.done:
    test edx, edx
    jz .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI=interaction payload object, RSI=exclusive end. AL=1 only when a direct
; nonzero decimal guild_id is present. The value is copied into fixed storage.
interaction_load_guild_id:
    mov r11, rsi
    lea rdx, [key_guild_id]
    mov ecx, key_guild_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .no
    mov rdi, rax
    mov rsi, r11
    lea rdx, [interaction_guild_id]
    mov ecx, FRAME_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .no
    mov [interaction_guild_id_len], eax
    lea rdi, [interaction_guild_id]
    mov esi, eax
    call decimal_id_valid
    ret
.no:
    xor eax, eax
    ret

; RDI=modal data object, RSI=exclusive end, RDX=expected text-input custom ID,
; ECX=ID len, R8=output, R9D=output cap. EAX=nonzero decoded value length,
; or -1 if JSON shape is invalid, the input is absent/duplicate, or its type
; is not a text input. Traversal remains bounded by the validated data object.
interaction_modal_read_value:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 80
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    mov [rsp], r8
    mov dword [rsp + 8], r9d
    mov dword [rsp + 32], 0
    mov dword [rsp + 64], 0
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_components]
    mov ecx, key_components_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    cmp byte [rax], '['
    jne .bad
    mov [rsp + 24], rax              ; retain outer array start across call
    mov rdi, rax
    mov rsi, r13
    call json_array_end
    test rax, rax
    jz .bad
    mov [rsp + 16], rax              ; outer array end
    mov rax, [rsp + 24]
    inc rax
    mov [rsp + 24], rax              ; outer array cursor
.outer_ws:
    mov rbx, [rsp + 24]
    mov rax, [rsp + 16]
    cmp rbx, rax
    jae .bad
    mov al, [rbx]
    cmp al, ' '
    je .outer_ws_advance
    cmp al, 9
    je .outer_ws_advance
    cmp al, 10
    je .outer_ws_advance
    cmp al, 13
    je .outer_ws_advance
    cmp al, ']'
    je .finish
    cmp al, '{'
    jne .bad
    mov rdi, rbx
    mov rsi, [rsp + 16]
    call json_object_end
    test rax, rax
    jz .bad
    mov [rsp + 40], rax              ; action row end
    mov rdi, rbx
    mov rsi, rax
    lea rdx, [key_components]
    mov ecx, key_components_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    cmp byte [rax], '['
    jne .bad
    mov [rsp + 56], rax              ; retain row array start across call
    mov rdi, rax
    mov rsi, [rsp + 40]
    call json_array_end
    test rax, rax
    jz .bad
    mov [rsp + 48], rax              ; row components end
    mov rax, [rsp + 56]
    inc rax
    mov [rsp + 56], rax              ; row components cursor
.inner_ws:
    mov rbx, [rsp + 56]
    mov rax, [rsp + 48]
    cmp rbx, rax
    jae .bad
    mov al, [rbx]
    cmp al, ' '
    je .inner_ws_advance
    cmp al, 9
    je .inner_ws_advance
    cmp al, 10
    je .inner_ws_advance
    cmp al, 13
    je .inner_ws_advance
    cmp al, ']'
    je .after_row
    cmp al, '{'
    jne .bad
    mov rdi, rbx
    mov rsi, [rsp + 48]
    call json_object_end
    test rax, rax
    jz .bad
    mov [rsp + 72], rax              ; text-input component end
    mov rdi, rbx
    mov rsi, rax
    lea rdx, [key_custom_id]
    mov ecx, key_custom_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, [rsp + 72]
    lea rdx, [interaction_component_id]
    mov ecx, NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .next_input
    mov [interaction_component_id_len], eax
    lea rdi, [interaction_component_id]
    mov esi, eax
    mov rdx, r14
    mov ecx, r15d
    call equal_literal
    test al, al
    jz .next_input
    ; A matching ID must name a Discord text-input component (type 4).
    mov rdi, rbx
    mov rsi, [rsp + 72]
    lea rdx, [key_type]
    mov ecx, key_type_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, [rsp + 72]
    call json_read_uint
    jc .bad
    cmp eax, 4
    jne .bad
    mov rdi, rbx
    mov rsi, [rsp + 72]
    lea rdx, [key_value]
    mov ecx, key_value_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    inc dword [rsp + 32]
    cmp dword [rsp + 32], 1
    jne .bad
    mov rdi, rax
    mov rsi, [rsp + 72]
    mov rdx, [rsp]
    mov ecx, [rsp + 8]
    call json_read_string
    test eax, eax
    jle .bad
    mov [rsp + 64], eax
.next_input:
    mov rbx, [rsp + 72]
    mov [rsp + 56], rbx
.inner_tail:
    mov rbx, [rsp + 56]
    mov rax, [rsp + 48]
    cmp rbx, rax
    jae .bad
    mov al, [rbx]
    cmp al, ' '
    je .inner_tail_advance
    cmp al, 9
    je .inner_tail_advance
    cmp al, 10
    je .inner_tail_advance
    cmp al, 13
    je .inner_tail_advance
    cmp al, ','
    je .inner_comma
    cmp al, ']'
    je .after_row
    jmp .bad
.inner_ws_advance:
    inc rbx
    mov [rsp + 56], rbx
    jmp .inner_ws
.inner_tail_advance:
    inc rbx
    mov [rsp + 56], rbx
    jmp .inner_tail
.inner_comma:
    inc rbx
    mov [rsp + 56], rbx
    jmp .inner_ws
.after_row:
    mov rbx, [rsp + 40]
    mov [rsp + 24], rbx
.outer_tail:
    mov rbx, [rsp + 24]
    mov rax, [rsp + 16]
    cmp rbx, rax
    jae .bad
    mov al, [rbx]
    cmp al, ' '
    je .outer_tail_advance
    cmp al, 9
    je .outer_tail_advance
    cmp al, 10
    je .outer_tail_advance
    cmp al, 13
    je .outer_tail_advance
    cmp al, ','
    je .outer_comma
    cmp al, ']'
    je .finish
    jmp .bad
.outer_ws_advance:
    inc rbx
    mov [rsp + 24], rbx
    jmp .outer_ws
.outer_tail_advance:
    inc rbx
    mov [rsp + 24], rbx
    jmp .outer_tail
.outer_comma:
    inc rbx
    mov [rsp + 24], rbx
    jmp .outer_ws
.finish:
    cmp dword [rsp + 32], 1
    jne .bad
    mov eax, [rsp + 64]
    test eax, eax
    jle .bad
    jmp .out
.bad:
    mov eax, -1
.out:
    add rsp, 80
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=decimal identifier, ESI=len. AL=1 only for a complete nonzero bounded
; decimal snowflake-like identifier.
decimal_id_valid:
    test rdi, rdi
    jz .no
    cmp esi, 1
    jb .no
    cmp esi, FRAME_ID_CAP - 1
    ja .no
    xor ecx, ecx
    xor edx, edx
.loop:
    cmp ecx, esi
    jae .yes
    mov al, [rdi + rcx]
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .no
    cmp al, '0'
    jne .nonzero
    inc ecx
    jmp .loop
.nonzero:
    mov edx, 1
    inc ecx
    jmp .loop
.yes:
    test edx, edx
    jz .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI=decimal bytes, ESI=len. RAX=value, RDX=0 success; RDX=1 invalid/overflow.
parse_decimal_u64:
    test esi, esi
    jle .bad
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    movzx edx, byte [rdi + rcx]
    cmp dl, '0'
    jb .bad
    cmp dl, '9'
    ja .bad
    mov r8, rdx
    sub r8, '0'
    mov r9, 10
    mul r9
    test rdx, rdx
    jnz .bad
    add rax, r8
    jc .bad
    inc ecx
    jmp .loop
.done:
    xor edx, edx
    ret
.bad:
    mov edx, 1
    ret

; RDI=left, RSI=right, EDX=len. AL=1 exact.
equal_bytes:
    xor ecx, ecx
.bytes_loop:
    cmp ecx, edx
    jae .bytes_yes
    mov al, [rdi + rcx]
    cmp al, [rsi + rcx]
    jne .bytes_no
    inc ecx
    jmp .bytes_loop
.bytes_yes:
    mov al, 1
    ret
.bytes_no:
    xor eax, eax
    ret

equal_literal:
    cmp esi, ecx
    jne .no
    xor eax, eax
.loop:
    cmp eax, ecx
    jae .yes
    mov r8b, [rdi + rax]
    cmp r8b, [rdx + rax]
    jne .no
    inc eax
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

section .rodata
key_data: db 'd'
key_data_len equ $ - key_data
key_command_data: db 'data'
key_command_data_len equ $ - key_command_data
key_id: db 'id'
key_id_len equ $ - key_id
key_member: db 'member'
key_member_len equ $ - key_member
key_user: db 'user'
key_user_len equ $ - key_user
key_guild_id: db 'guild_id'
key_guild_id_len equ $ - key_guild_id
key_value: db 'value'
key_value_len equ $ - key_value
key_components: db 'components'
key_components_len equ $ - key_components
input_channel_id: db 'channel_id'
input_channel_id_len equ $ - input_channel_id
input_msg: db 'msg'
input_msg_len equ $ - input_msg
input_prompt: db 'prompt'
input_prompt_len equ $ - input_prompt
input_limit: db 'limit'
input_limit_len equ $ - input_limit
input_word: db 'word'
input_word_len equ $ - input_word
input_role_id: db 'role_id'
input_role_id_len equ $ - input_role_id
key_custom_id: db 'custom_id'
key_custom_id_len equ $ - key_custom_id
key_permissions: db 'permissions'
key_permissions_len equ $ - key_permissions
key_type: db 'type'
key_type_len equ $ - key_type
key_token: db 'token'
key_token_len equ $ - key_token
key_name: db 'name'
key_name_len equ $ - key_name
name_info: db 'info'
name_info_len equ $ - name_info
name_help: db 'help'
name_help_len equ $ - name_help
name_dashboard: db 'dashboard'
name_dashboard_len equ $ - name_dashboard
name_healthcheck: db 'healthcheck'
name_healthcheck_len equ $ - name_healthcheck
component_back: db 'dash_back'
component_back_len equ $ - component_back
component_general: db 'dash_general'
component_general_len equ $ - component_general
component_setlog: db 'dash_setlog'
component_setlog_len equ $ - component_setlog
component_welcome: db 'dash_welcome'
component_welcome_len equ $ - component_welcome
component_setwelcome: db 'dash_setwelcome'
component_setwelcome_len equ $ - component_setwelcome
component_setgoodbye: db 'dash_setgoodbye'
component_setgoodbye_len equ $ - component_setgoodbye
component_setwelcomemsg: db 'dash_setwelcomemsg'
component_setwelcomemsg_len equ $ - component_setwelcomemsg
component_setgoodbyemsg: db 'dash_setgoodbyemsg'
component_setgoodbyemsg_len equ $ - component_setgoodbyemsg
component_autorole: db 'dash_autorole'
component_autorole_len equ $ - component_autorole
component_setautorole: db 'dash_setautorole'
component_setautorole_len equ $ - component_setautorole
component_removeautorole: db 'dash_removeautorole'
component_removeautorole_len equ $ - component_removeautorole
component_moderation: db 'dash_moderation'
component_moderation_len equ $ - component_moderation
component_addword: db 'dash_addword'
component_addword_len equ $ - component_addword
component_removeword: db 'dash_removeword'
component_removeword_len equ $ - component_removeword
component_leveling: db 'dash_leveling'
component_leveling_len equ $ - component_leveling
component_setlevelchannel: db 'dash_setlevelchannel'
component_setlevelchannel_len equ $ - component_setlevelchannel
component_persona: db 'dash_persona'
component_persona_len equ $ - component_persona
component_setpersona: db 'dash_setpersona'
component_setpersona_len equ $ - component_setpersona
component_resetpersona: db 'dash_resetpersona'
component_resetpersona_len equ $ - component_resetpersona
component_status: db 'dash_status'
component_status_len equ $ - component_status
component_sethistory: db 'dash_sethistory'
component_sethistory_len equ $ - component_sethistory
component_model: db 'dash_model'
component_model_len equ $ - component_model
component_model_llama: db 'dash_model_llama70b'
component_model_llama_len equ $ - component_model_llama
component_model_gpt120: db 'dash_model_gpt120b'
component_model_gpt120_len equ $ - component_model_gpt120
component_model_gpt20: db 'dash_model_gpt20b'
component_model_gpt20_len equ $ - component_model_gpt20
component_model_qwen: db 'dash_model_qwen32b'
component_model_qwen_len equ $ - component_model_qwen
modal_setlog_id: db 'modal_setlog'
modal_setlog_id_len equ $ - modal_setlog_id
modal_setwelcome_id: db 'modal_setwelcome'
modal_setwelcome_id_len equ $ - modal_setwelcome_id
modal_setgoodbye_id: db 'modal_setgoodbye'
modal_setgoodbye_id_len equ $ - modal_setgoodbye_id
modal_setwelcomemsg_id: db 'modal_setwelcomemsg'
modal_setwelcomemsg_id_len equ $ - modal_setwelcomemsg_id
modal_setgoodbyemsg_id: db 'modal_setgoodbyemsg'
modal_setgoodbyemsg_id_len equ $ - modal_setgoodbyemsg_id
modal_setautorole_id: db 'modal_setautorole'
modal_setautorole_id_len equ $ - modal_setautorole_id
modal_addword_id: db 'modal_addword'
modal_addword_id_len equ $ - modal_addword_id
modal_removeword_id: db 'modal_removeword'
modal_removeword_id_len equ $ - modal_removeword_id
modal_setlevelchannel_id: db 'modal_setlevelchannel'
modal_setlevelchannel_id_len equ $ - modal_setlevelchannel_id
modal_setpersona_id: db 'modal_setpersona'
modal_setpersona_id_len equ $ - modal_setpersona_id
modal_sethistory_id: db 'modal_sethistory'
modal_sethistory_id_len equ $ - modal_sethistory_id
setting_log_channel: db 'log_channel'
setting_log_channel_len equ $ - setting_log_channel
setting_model: db 'model'
setting_model_len equ $ - setting_model
setting_welcome_channel: db 'welcome_channel'
setting_welcome_channel_len equ $ - setting_welcome_channel
setting_goodbye_channel: db 'goodbye_channel'
setting_goodbye_channel_len equ $ - setting_goodbye_channel
setting_welcome_message: db 'welcome_msg'
setting_welcome_message_len equ $ - setting_welcome_message
setting_goodbye_message: db 'goodbye_msg'
setting_goodbye_message_len equ $ - setting_goodbye_message
setting_autorole: db 'auto_role'
setting_autorole_len equ $ - setting_autorole
setting_level_channel: db 'level_channel'
setting_level_channel_len equ $ - setting_level_channel
setting_persona: db 'system_prompt'
setting_persona_len equ $ - setting_persona
setting_history: db 'max_history'
setting_history_len equ $ - setting_history
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
healthcheck_deferred_response: db '{"type":5,"data":{"flags":64}}'
healthcheck_deferred_response_len equ $ - healthcheck_deferred_response
healthcheck_ok_edit: db '{"embeds":[{"color":65416,"title":"Semua sistem normal","fields":[{"name":"State Storage","value":"Read/write OK","inline":true},{"name":"In-memory Cache","value":"Hit/invalidate OK","inline":true},{"name":"Groq API","value":"Probe respons OK","inline":true},{"name":"Bot Permissions","value":"Permission cache OK","inline":true},{"name":"Discord Latency","value":"Heartbeat ACK <= 500ms","inline":true}]}]}'
healthcheck_ok_edit_len equ $ - healthcheck_ok_edit
healthcheck_degraded_edit: db '{"embeds":[{"color":16729156,"title":"Ada komponen bermasalah","description":"Satu atau lebih probe bounded gagal atau cache belum lengkap. Periksa konfigurasi dan coba lagi."}]}'
healthcheck_degraded_edit_len equ $ - healthcheck_degraded_edit
health_probe_setting: db '__healthcheck_probe__'
health_probe_setting_len equ $ - health_probe_setting
health_probe_value: db 'cache_ping'
health_probe_value_len equ $ - health_probe_value
status_default_history: db '30'
status_default_history_len equ $ - status_default_history
dashboard_status_prefix: db '{"type":7,"data":{"flags":64,"embeds":[{"color":65416,"title":"Status Bot","fields":[{"name":"Status","value":"Online"},{"name":"History Limit","value":"'
dashboard_status_prefix_len equ $ - dashboard_status_prefix
dashboard_status_suffix: db ' messages"}]}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set History Limit","custom_id":"dash_sethistory"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_status_suffix_len equ $ - dashboard_status_suffix
health_probe_ping: db 'ping'
health_probe_ping_len equ $ - health_probe_ping
info_response: db 'Caine — AI Discord Bot. Status: Online. Default model: Llama 3.3 70B.'
info_response_len equ $ - info_response
help_response: db 'Caine commands: chat via prefix or mention; moderation, AFK, leveling, configuration, /info, and /help.'
help_response_len equ $ - help_response
manager_denied_response: db 'Khusus admin atau bot owner.'
manager_denied_response_len equ $ - manager_denied_response
dashboard_main_response: db '{"type":4,"data":{"flags":64,"embeds":[{"color":5793266,"title":"Dashboard Bot Caine","description":"Pilih menu di bawah:"}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"General","custom_id":"dash_general"},{"type":2,"style":3,"label":"Welcome/Goodbye","custom_id":"dash_welcome"},{"type":2,"style":2,"label":"Auto-role","custom_id":"dash_autorole"},{"type":2,"style":2,"label":"Leveling","custom_id":"dash_leveling"}]},{"type":1,"components":[{"type":2,"style":1,"label":"Persona","custom_id":"dash_persona"},{"type":2,"style":1,"label":"Model AI","custom_id":"dash_model"},{"type":2,"style":4,"label":"Moderation","custom_id":"dash_moderation"},{"type":2,"style":1,"label":"Status Bot","custom_id":"dash_status"}]}]}}'
dashboard_main_response_len equ $ - dashboard_main_response
dashboard_back_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":5793266,"title":"Dashboard Bot Caine","description":"Pilih menu di bawah:"}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"General","custom_id":"dash_general"},{"type":2,"style":3,"label":"Welcome/Goodbye","custom_id":"dash_welcome"},{"type":2,"style":2,"label":"Auto-role","custom_id":"dash_autorole"},{"type":2,"style":2,"label":"Leveling","custom_id":"dash_leveling"}]},{"type":1,"components":[{"type":2,"style":1,"label":"Persona","custom_id":"dash_persona"},{"type":2,"style":1,"label":"Model AI","custom_id":"dash_model"},{"type":2,"style":4,"label":"Moderation","custom_id":"dash_moderation"},{"type":2,"style":1,"label":"Status Bot","custom_id":"dash_status"}]}]}}'
dashboard_back_response_len equ $ - dashboard_back_response
dashboard_general_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":5793266,"title":"General Settings","fields":[{"name":"Log Channel","value":"Atur melalui tombol di bawah."}]}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set Log Channel","custom_id":"dash_setlog"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_general_response_len equ $ - dashboard_general_response
dashboard_welcome_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":65407,"title":"Welcome / Goodbye","description":"Atur channel dan pesan melalui tombol di bawah."}],"components":[{"type":1,"components":[{"type":2,"style":3,"label":"Set Welcome Channel","custom_id":"dash_setwelcome"},{"type":2,"style":1,"label":"Set Welcome Message","custom_id":"dash_setwelcomemsg"},{"type":2,"style":4,"label":"Set Goodbye Channel","custom_id":"dash_setgoodbye"},{"type":2,"style":1,"label":"Set Goodbye Message","custom_id":"dash_setgoodbyemsg"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_welcome_response_len equ $ - dashboard_welcome_response
dashboard_model_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":49151,"title":"Model AI","description":"Pilih model aktif."}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Llama 3.3 70B","custom_id":"dash_model_llama70b"},{"type":2,"style":2,"label":"GPT OSS 120B","custom_id":"dash_model_gpt120b"},{"type":2,"style":2,"label":"GPT OSS 20B","custom_id":"dash_model_gpt20b"},{"type":2,"style":2,"label":"Qwen 32B","custom_id":"dash_model_qwen32b"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_model_response_len equ $ - dashboard_model_response
dashboard_autorole_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":16753920,"title":"Auto-role","description":"Atur role yang diberikan saat anggota bergabung."}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set Auto-role","custom_id":"dash_setautorole"},{"type":2,"style":4,"label":"Hapus Auto-role","custom_id":"dash_removeautorole"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_autorole_response_len equ $ - dashboard_autorole_response
dashboard_moderation_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":16711680,"title":"Moderation","description":"Kelola kata blacklist dengan tombol di bawah."}],"components":[{"type":1,"components":[{"type":2,"style":4,"label":"Tambah Banned Word","custom_id":"dash_addword"},{"type":2,"style":2,"label":"Hapus Banned Word","custom_id":"dash_removeword"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_moderation_response_len equ $ - dashboard_moderation_response
dashboard_leveling_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":16766720,"title":"Leveling","description":"Atur channel notifikasi level-up."}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set Level Channel","custom_id":"dash_setlevelchannel"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_leveling_response_len equ $ - dashboard_leveling_response
dashboard_persona_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":14365436,"title":"Persona Bot","description":"Atur system prompt khusus server."}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Edit Persona","custom_id":"dash_setpersona"},{"type":2,"style":4,"label":"Reset ke Default","custom_id":"dash_resetpersona"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_persona_response_len equ $ - dashboard_persona_response
dashboard_status_response: db '{"type":7,"data":{"flags":64,"embeds":[{"color":65416,"title":"Status Bot","fields":[{"name":"Status","value":"Online"},{"name":"History Limit","value":"Atur melalui tombol di bawah."}]}],"components":[{"type":1,"components":[{"type":2,"style":1,"label":"Set History Limit","custom_id":"dash_sethistory"}]},{"type":1,"components":[{"type":2,"style":2,"label":"Kembali","custom_id":"dash_back"}]}]}}'
dashboard_status_response_len equ $ - dashboard_status_response
modal_setlog_response: db '{"type":9,"data":{"custom_id":"modal_setlog","title":"Set Log Channel","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","label":"Channel ID","style":1,"required":true,"placeholder":"Contoh: 1234567890123456789"}]}]}}'
modal_setlog_response_len equ $ - modal_setlog_response
modal_setautorole_response: db '{"type":9,"data":{"custom_id":"modal_setautorole","title":"Set Auto-role","components":[{"type":1,"components":[{"type":4,"custom_id":"role_id","label":"Role ID","style":1,"required":true}]}]}}'
modal_setautorole_response_len equ $ - modal_setautorole_response
modal_addword_response: db '{"type":9,"data":{"custom_id":"modal_addword","title":"Tambah Banned Word","components":[{"type":1,"components":[{"type":4,"custom_id":"word","label":"Kata","style":1,"required":true,"max_length":26}]}]}}'
modal_addword_response_len equ $ - modal_addword_response
modal_removeword_response: db '{"type":9,"data":{"custom_id":"modal_removeword","title":"Hapus Banned Word","components":[{"type":1,"components":[{"type":4,"custom_id":"word","label":"Kata yang dihapus","style":1,"required":true,"max_length":26}]}]}}'
modal_removeword_response_len equ $ - modal_removeword_response
modal_setlevelchannel_response: db '{"type":9,"data":{"custom_id":"modal_setlevelchannel","title":"Set Level-up Channel","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","label":"Channel ID","style":1,"required":true}]}]}}'
modal_setlevelchannel_response_len equ $ - modal_setlevelchannel_response
modal_setpersona_response: db '{"type":9,"data":{"custom_id":"modal_setpersona","title":"Edit Persona Bot","components":[{"type":1,"components":[{"type":4,"custom_id":"prompt","label":"System Prompt","style":2,"required":true,"max_length":511}]}]}}'
modal_setpersona_response_len equ $ - modal_setpersona_response
modal_sethistory_response: db '{"type":9,"data":{"custom_id":"modal_sethistory","title":"Set History Limit","components":[{"type":1,"components":[{"type":4,"custom_id":"limit","label":"Limit History (5-100)","style":1,"required":true,"placeholder":"Contoh: 15","max_length":3}]}]}}'
modal_sethistory_response_len equ $ - modal_sethistory_response
modal_setwelcome_response: db '{"type":9,"data":{"custom_id":"modal_setwelcome","title":"Set Welcome Channel","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","label":"Channel ID","style":1,"required":true}]}]}}'
modal_setwelcome_response_len equ $ - modal_setwelcome_response
modal_setgoodbye_response: db '{"type":9,"data":{"custom_id":"modal_setgoodbye","title":"Set Goodbye Channel","components":[{"type":1,"components":[{"type":4,"custom_id":"channel_id","label":"Channel ID","style":1,"required":true}]}]}}'
modal_setgoodbye_response_len equ $ - modal_setgoodbye_response
modal_setwelcomemsg_response: db '{"type":9,"data":{"custom_id":"modal_setwelcomemsg","title":"Set Welcome Message","components":[{"type":1,"components":[{"type":4,"custom_id":"msg","label":"Pesan Welcome","style":2,"required":true,"max_length":511}]}]}}'
modal_setwelcomemsg_response_len equ $ - modal_setwelcomemsg_response
modal_setgoodbyemsg_response: db '{"type":9,"data":{"custom_id":"modal_setgoodbyemsg","title":"Set Goodbye Message","components":[{"type":1,"components":[{"type":4,"custom_id":"msg","label":"Pesan Goodbye","style":2,"required":true,"max_length":511}]}]}}'
modal_setgoodbyemsg_response_len equ $ - modal_setgoodbyemsg_response
setlog_saved_response: db 'Log channel diset.'
setlog_saved_response_len equ $ - setlog_saved_response
setwelcome_saved_response: db 'Welcome channel diset.'
setwelcome_saved_response_len equ $ - setwelcome_saved_response
setgoodbye_saved_response: db 'Goodbye channel diset.'
setgoodbye_saved_response_len equ $ - setgoodbye_saved_response
setwelcomemsg_saved_response: db 'Pesan welcome diupdate.'
setwelcomemsg_saved_response_len equ $ - setwelcomemsg_saved_response
setgoodbyemsg_saved_response: db 'Pesan goodbye diupdate.'
setgoodbyemsg_saved_response_len equ $ - setgoodbyemsg_saved_response
levelchannel_saved_response: db 'Level-up channel diset.'
levelchannel_saved_response_len equ $ - levelchannel_saved_response
persona_saved_response: db 'Persona diupdate.'
persona_saved_response_len equ $ - persona_saved_response
persona_reset_response: db 'Persona direset ke default.'
persona_reset_response_len equ $ - persona_reset_response
history_saved_response: db 'History limit diset.'
history_saved_response_len equ $ - history_saved_response
word_added_response: db 'Kata ditambahkan ke blacklist.'
word_added_response_len equ $ - word_added_response
word_removed_response: db 'Kata dihapus dari blacklist.'
word_removed_response_len equ $ - word_removed_response
autorole_saved_response: db 'Auto-role diset.'
autorole_saved_response_len equ $ - autorole_saved_response
autorole_removed_response: db 'Auto-role dihapus.'
autorole_removed_response_len equ $ - autorole_removed_response
setlog_failed_response: db 'Log channel tidak dapat disimpan.'
setlog_failed_response_len equ $ - setlog_failed_response

section .bss
interaction_id: resb FRAME_ID_CAP
interaction_id_len: resd 1
interaction_token: resb TOKEN_CAP
interaction_token_len: resd 1
interaction_name: resb NAME_CAP
interaction_name_len: resd 1
interaction_payload_end: resq 1
interaction_user_id: resb FRAME_ID_CAP
interaction_user_id_len: resd 1
interaction_permissions: resb 32
interaction_type: resd 1
interaction_component_id: resb NAME_CAP
interaction_component_id_len: resd 1
interaction_guild_id: resb FRAME_ID_CAP
interaction_guild_id_len: resd 1
interaction_modal_value: resb CONFIG_TEXT_CAP
interaction_modal_value_len: resd 1
interaction_word: resb 27
interaction_word_len: resd 1
health_probe_reply: resb 1901
dashboard_status_dynamic: resb DASHBOARD_DYNAMIC_CAP

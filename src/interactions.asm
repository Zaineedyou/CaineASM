DEFAULT REL

global interaction_handle_gateway

extern json_find_key
extern json_read_string
extern json_read_uint
extern json_object_end
extern discord_interaction_respond_text
extern discord_interaction_respond_json
extern bot_owner_ptr
extern bot_owner_len

%define FRAME_ID_CAP 64
%define TOKEN_CAP 192
%define NAME_CAP 64
%define EPHEMERAL_FLAG 64
%define PERMISSION_ADMINISTRATOR 0x8

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
    mov rsi, r13
    lea rdx, [key_data]
    mov ecx, key_data_len
    call json_find_key
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
    sub rsi, rbx
    lea rdx, [key_type]
    mov ecx, key_type_len
    call json_find_key
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
    jne .ignored
.credentials:
    ; Interaction ID and token occur at the interaction payload object level.
    mov rdi, rbx
    mov rsi, r14
    sub rsi, rbx
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
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
    sub rsi, rbx
    lea rdx, [key_token]
    mov ecx, key_token_len
    call json_find_key
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

    mov rdi, rbx
    mov rsi, r14
    sub rsi, rbx
    lea rdx, [key_command_data]
    mov ecx, key_command_data_len
    call json_find_key
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
    sub rsi, r15
    lea rdx, [key_name]
    mov ecx, key_name_len
    call json_find_key
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
    jmp .ignored
.component:
    mov rdi, rbx
    mov rsi, [interaction_payload_end]
    sub rsi, rbx
    lea rdx, [key_command_data]
    mov ecx, key_command_data_len
    call json_find_key
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
    sub rsi, r15
    lea rdx, [key_custom_id]
    mov ecx, key_custom_id_len
    call json_find_key
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
    lea rdi, [interaction_component_id]
    mov esi, [interaction_component_id_len]
    lea rdx, [component_back]
    mov ecx, component_back_len
    call equal_literal
    test al, al
    jz .ignored
    lea r8, [dashboard_back_response]
    mov r9d, dashboard_back_response_len
    jmp .component_respond_json
.component_denied:
    lea r8, [manager_denied_response]
    mov r9d, manager_denied_response_len
    jmp .respond
.component_respond_json:
    lea rdi, [interaction_id]
    mov esi, [interaction_id_len]
    lea rdx, [interaction_token]
    mov ecx, [interaction_token_len]
    call discord_interaction_respond_json
    jmp .out

.info:
    lea r8, [info_response]
    mov r9d, info_response_len
    jmp .respond
.help:
    lea r8, [help_response]
    mov r9d, help_response_len
    jmp .respond
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
    sub rsi, r12
    lea rdx, [key_member]
    mov ecx, key_member_len
    call json_find_key
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
    sub rsi, r14
    lea rdx, [key_user]
    mov ecx, key_user_len
    call json_find_key
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
    sub rsi, rbx
    lea rdx, [key_user]
    mov ecx, key_user_len
    call json_find_key
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
    sub rsi, rbx
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
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
    mov rdi, r14
    mov rsi, r13
    sub rsi, r14
    lea rdx, [key_permissions]
    mov ecx, key_permissions_len
    call json_find_key
    test rax, rax
    jz .no
    mov rdi, rax
    mov rsi, r13
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
component_back: db 'dash_back'
component_back_len equ $ - component_back
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

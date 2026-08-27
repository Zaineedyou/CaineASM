DEFAULT REL

extern interaction_handle_gateway

global _start
global discord_interaction_respond_text
global discord_interaction_respond_json
global bot_owner_ptr
global bot_owner_len

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
    lea rax, [dashboard_general_response]
    mov [expected_json_ptr], rax
    mov dword [expected_json_len], dashboard_general_response_len
    lea rdi, [dashboard_general_frame]
    mov esi, dashboard_general_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [json_callback_calls], 3
    jne .fail

    mov dword [failure_stage], 7
    lea rax, [manager_denied_response]
    mov [expected_content_ptr], rax
    mov dword [expected_content_len], manager_denied_response_len
    lea rdi, [dashboard_denied_frame]
    mov esi, dashboard_denied_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 3
    jne .fail
    cmp qword [json_callback_calls], 3
    jne .fail

    mov dword [failure_stage], 8
    lea rdi, [unknown_frame]
    mov esi, unknown_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 3
    jne .fail

    mov dword [failure_stage], 9
    lea rdi, [wrong_type_frame]
    mov esi, wrong_type_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 3
    jne .fail

    mov dword [failure_stage], 10
    lea rdi, [malformed_frame]
    mov esi, malformed_frame_len
    call interaction_handle_gateway
    test eax, eax
    jnz .fail
    cmp qword [callback_calls], 3
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

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

section .data
callback_calls: dq 0
json_callback_calls: dq 0
bot_owner_ptr: dq 0
bot_owner_len: dd 0
expected_json_ptr: dq 0
expected_json_len: dd 0
expected_content_ptr: dq 0
expected_content_len: dd 0
failure_stage: dd 0

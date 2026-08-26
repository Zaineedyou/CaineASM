BITS 64
DEFAULT REL

extern groq_chat_once
extern groq_vision_once
extern groq_select_guild
extern groq_select_history
extern groq_get_selected_history_limit
extern history_append

global _start
global secure_https_post_json
global groq_key_ptr
global groq_key_len
global guild_config_get

%define SYS_EXIT 60
%define CONFIG_NONE 0
%define CONFIG_CUSTOM 1
%define CONFIG_HISTORY_ONLY 2
%define CONFIG_BOUNDED 3
%define CONFIG_HISTORY_33 4
%define CONFIG_HISTORY_INVALID 5

section .text
_start:
    lea rax, [api_key]
    mov [groq_key_ptr], rax
    mov dword [groq_key_len], api_key_len
    mov qword [mock_calls], 0
    mov qword [mock_status], 200
    mov dword [mock_retry_429_once], 0
    mov dword [mock_invalid_json], 0
    lea rax, [expected_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_body_len

    ; Valid prompt is escaped in a strict JSON body and decoded from choice content.
    mov dword [failure_stage], 1
    lea rdi, [prompt]
    mov esi, prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    jne .fail
    lea rdi, [reply]
    lea rsi, [expected_reply]
    mov edx, expected_reply_len
    call equal_bytes
    test al, al
    jz .fail
    cmp qword [mock_calls], 1
    jne .fail

    ; Guild-selected model and persona are escaped and used in the next request.
    mov dword [failure_stage], 2
    mov dword [config_mode], CONFIG_CUSTOM
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    lea rax, [expected_custom_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_custom_body_len
    lea rdi, [plain_prompt]
    mov esi, plain_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    jne .fail
    cmp qword [mock_calls], 2
    jne .fail

    ; A selected conversation key stores successful user/assistant turns and
    ; serializes the newest bounded context on the next request.
    mov dword [failure_stage], 3
    lea rdi, [history_key]
    mov esi, history_key_len
    call groq_select_history
    lea rax, [expected_history_first_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_history_first_body_len
    lea rdi, [history_prompt_first]
    mov esi, history_prompt_first_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    jne .fail
    cmp qword [mock_calls], 3
    jne .fail

    mov dword [failure_stage], 4
    lea rax, [expected_history_second_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_history_second_body_len
    lea rdi, [history_prompt_second]
    mov esi, history_prompt_second_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    jne .fail
    cmp qword [mock_calls], 4
    jne .fail

    ; Vision serializes the fixed source model, selected persona, escaped data
    ; URI/text content, retries one 429, and commits marker plus reply only after
    ; a decoded response succeeds.
    mov dword [failure_stage], 5
    mov dword [config_mode], CONFIG_CUSTOM
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    lea rdi, [vision_history_key]
    mov esi, vision_history_key_len
    call groq_select_history
    lea rax, [expected_vision_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_vision_body_len
    mov dword [mock_retry_429_once], 1
    mov dword [mock_invalid_json], 0
    lea rdi, [vision_prompt]
    mov esi, vision_prompt_len
    lea rdx, [vision_mime]
    mov ecx, vision_mime_len
    lea r8, [vision_b64]
    mov r9d, vision_b64_len
    mov eax, 64
    push rax
    lea rax, [reply]
    push rax
    call groq_vision_once
    add rsp, 16
    cmp eax, expected_reply_len
    jne .fail
    cmp qword [mock_calls], 6
    jne .fail

    ; The next text request must contain the success-only image marker and the
    ; matching assistant response in chronological history order.
    mov dword [failure_stage], 6
    lea rax, [expected_vision_history_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_vision_history_body_len
    lea rdi, [after_vision_prompt]
    mov esi, after_vision_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    jne .fail
    cmp qword [mock_calls], 7
    jne .fail

    ; Failed response decode is not retried and must not append image history.
    mov dword [failure_stage], 7
    lea rdi, [failed_vision_history_key]
    mov esi, failed_vision_history_key_len
    call groq_select_history
    lea rax, [expected_vision_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_vision_body_len
    mov dword [mock_invalid_json], 1
    lea rdi, [vision_prompt]
    mov esi, vision_prompt_len
    lea rdx, [vision_mime]
    mov ecx, vision_mime_len
    lea r8, [vision_b64]
    mov r9d, vision_b64_len
    mov eax, 64
    push rax
    lea rax, [reply]
    push rax
    call groq_vision_once
    add rsp, 16
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 8
    jne .fail
    mov dword [mock_invalid_json], 0
    lea rax, [expected_failed_vision_history_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_failed_vision_history_body_len
    lea rdi, [after_vision_prompt]
    mov esi, after_vision_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    jne .fail
    cmp qword [mock_calls], 9
    jne .fail

    ; Oversize Base64 fails before touching the bounded transport seam.
    mov dword [failure_stage], 8
    lea rdi, [vision_prompt]
    mov esi, vision_prompt_len
    lea rdx, [vision_mime]
    mov ecx, vision_mime_len
    lea r8, [vision_b64]
    mov r9d, 15001
    mov eax, 64
    push rax
    lea rax, [reply]
    push rax
    call groq_vision_once
    add rsp, 16
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 9
    jne .fail

    ; Missing persona still consumes a valid max_history config and keeps the
    ; default persona instead of bypassing the lookup.
    mov dword [failure_stage], 9
    xor edi, edi
    xor esi, esi
    call groq_select_history
    mov dword [config_mode], CONFIG_HISTORY_ONLY
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    call groq_get_selected_history_limit
    cmp eax, 5
    jne .fail
    lea rax, [expected_default_plain_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_default_plain_body_len
    lea rdi, [plain_prompt]
    mov esi, plain_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    jne .fail
    cmp qword [mock_calls], 10
    jne .fail

    ; Clamp values above fixed ring capacity to 32, including the source-facing
    ; 33 and 100 settings; missing/invalid values retain deterministic 30.
    mov dword [failure_stage], 91
    mov dword [config_mode], CONFIG_HISTORY_33
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    call groq_get_selected_history_limit
    cmp eax, 32
    jne .fail
    mov dword [config_mode], CONFIG_BOUNDED
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    call groq_get_selected_history_limit
    cmp eax, 32
    jne .fail
    mov dword [config_mode], CONFIG_HISTORY_INVALID
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    call groq_get_selected_history_limit
    cmp eax, 30
    jne .fail
    mov dword [config_mode], CONFIG_NONE
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    call groq_get_selected_history_limit
    cmp eax, 30
    jne .fail

    ; A full fixed ring with near-maximum entries must not overflow the 16 KiB
    ; request body. The selector walks newest-first, retains only a complete
    ; tail that fits, then serializes that tail chronologically.
    mov dword [failure_stage], 10
    mov dword [config_mode], CONFIG_BOUNDED
    lea rdi, [guild_id]
    mov esi, guild_id_len
    call groq_select_guild
    lea rdi, [bounded_history_key]
    mov esi, bounded_history_key_len
    call groq_select_history
    xor ebx, ebx
.fill_bounded_history:
    cmp ebx, 32
    jae .bounded_history_ready
    lea rdi, [bounded_history_key]
    mov esi, bounded_history_key_len
    lea rdx, [role_user]
    mov ecx, role_user_len
    lea r8, [near_max_history_content]
    mov r9d, near_max_history_content_len
    call history_append
    mov dword [failure_stage], 101
    test eax, eax
    js .fail
    inc ebx
    jmp .fill_bounded_history
.bounded_history_ready:
    mov dword [failure_stage], 102
    mov dword [mock_relaxed_body], 1
    mov dword [mock_transport_diag], 0
    lea rdi, [plain_prompt]
    mov esi, plain_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, expected_reply_len
    je .bounded_request_ok
    mov eax, [mock_transport_diag]
    test eax, eax
    jz .bounded_builder_fail
    mov [failure_stage], eax
    jmp .fail
.bounded_builder_fail:
    mov dword [failure_stage], 103
    jmp .fail
.bounded_request_ok:
    jne .fail
    mov dword [mock_relaxed_body], 0
    mov dword [failure_stage], 104
    cmp qword [mock_calls], 11
    jne .fail

    ; Non-retriable HTTP errors return failure instead of accepting error JSON.
    mov dword [failure_stage], 11
    xor edi, edi
    xor esi, esi
    call groq_select_history
    mov qword [mock_status], 400
    lea rax, [expected_default_plain_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_default_plain_body_len
    lea rdi, [plain_prompt]
    mov esi, plain_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 12
    jne .fail
    mov qword [mock_status], 200

    ; Header injection bytes in an API key are rejected before touching transport.
    mov dword [failure_stage], 12
    lea rax, [bad_key]
    mov [groq_key_ptr], rax
    mov dword [groq_key_len], bad_key_len
    lea rdi, [plain_prompt]
    mov esi, plain_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 12
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; Config seam returns bounded optional values. The history-only case has no
; persona; this catches the selector fall-through bug directly via its request.
guild_config_get:
    ; model and max_history both start with 'm'; distinguish the latter by its
    ; third byte ('x') so configuration vectors exercise the real lookup key.
    cmp byte [rdx], 's'
    je .persona
    cmp byte [rdx + 2], 'x'
    je .history
.model:
    cmp dword [config_mode], CONFIG_CUSTOM
    jne .missing
    lea rax, [custom_model]
    mov edx, custom_model_len
    ret
.persona:
    cmp dword [config_mode], CONFIG_CUSTOM
    jne .missing
    lea rax, [custom_persona]
    mov edx, custom_persona_len
    ret
.history:
    cmp dword [config_mode], CONFIG_HISTORY_ONLY
    je .history_5
    cmp dword [config_mode], CONFIG_BOUNDED
    je .history_100
    cmp dword [config_mode], CONFIG_HISTORY_33
    je .history_33
    cmp dword [config_mode], CONFIG_HISTORY_INVALID
    je .history_invalid
    jmp .missing
.history_5:
    lea rax, [history_limit_5]
    mov edx, history_limit_5_len
    ret
.history_100:
    lea rax, [history_limit_100]
    mov edx, history_limit_100_len
    ret
.history_33:
    lea rax, [history_limit_33]
    mov edx, history_limit_33_len
    ret
.history_invalid:
    lea rax, [history_limit_invalid]
    mov edx, history_limit_invalid_len
    ret
.missing:
    xor eax, eax
    xor edx, edx
    ret

; RDI=url, RSI=authorization, RDX=body, RCX=body len,
; R8=response, R9=capacity, [RSP+8]=long *status_out.
secure_https_post_json:
    push rbx
    mov dword [mock_transport_diag], 106
    mov rbx, rdx
    cmp r9, response_json_len + 1
    jb .bad
    lea r10, [groq_url]
    mov r11d, groq_url_len
    call equal_cstring
    test al, al
    jz .bad
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jz .bad
    cmp dword [mock_relaxed_body], 0
    je .strict_body
    cmp ecx, 16383
    ja .bad
    cmp byte [rbx], '{'
    jne .bad
    mov eax, ecx
    dec eax
    cmp byte [rbx + rax], '}'
    jne .bad
    jmp .body_ready
.strict_body:
    cmp ecx, [mock_body_len]
    jne .bad
    mov rdi, rbx
    mov rsi, [mock_body_ptr]
    mov edx, [mock_body_len]
    call equal_bytes
    test al, al
    jz .bad
.body_ready:
    mov r10, [rsp + 16]
    cmp dword [mock_retry_429_once], 0
    je .response
    mov dword [mock_retry_429_once], 0
    mov qword [r10], 429
    inc qword [mock_calls]
    xor eax, eax
    pop rbx
    ret
.response:
    cmp dword [mock_invalid_json], 0
    je .valid_json
    lea rsi, [invalid_response_json]
    mov edx, invalid_response_json_len
    jmp .copy_response
.valid_json:
    lea rsi, [response_json]
    mov edx, response_json_len
.copy_response:
    cmp r9d, edx
    jbe .bad
    mov rdi, r8
    call copy_bytes
    mov byte [r8 + rdx], 0
    mov rax, [mock_status]
    mov [r10], rax
    inc qword [mock_calls]
    mov eax, edx
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

; RDI=C string; R10=expected bytes; R11D=expected length. AL=1 on exact match.
equal_cstring:
    xor eax, eax
.loop:
    cmp eax, r11d
    jae .terminator
    mov dl, [rdi + rax]
    cmp dl, [r10 + rax]
    jne .no
    inc eax
    jmp .loop
.terminator:
    cmp byte [rdi + rax], 0
    jne .no
    mov al, 1
    ret
.no:
    xor eax, eax
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

; RDI=destination, RSI=source, EDX=count.
copy_bytes:
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

section .rodata
api_key: db 'gsk_test_value'
api_key_len equ $ - api_key
bad_key: db 'bad', 10, 'key'
bad_key_len equ $ - bad_key
prompt: db 'Say ', '"', 'hi', '"', 10, 0x5c, ' now'
prompt_len equ $ - prompt
plain_prompt: db 'hello'
plain_prompt_len equ $ - plain_prompt
history_key: db 'server-333'
history_key_len equ $ - history_key
vision_history_key: db 'server-vision'
vision_history_key_len equ $ - vision_history_key
failed_vision_history_key: db 'server-vision-fail'
failed_vision_history_key_len equ $ - failed_vision_history_key
bounded_history_key: db 'server-bounded'
bounded_history_key_len equ $ - bounded_history_key
history_prompt_first: db 'first'
history_prompt_first_len equ $ - history_prompt_first
history_prompt_second: db 'second'
history_prompt_second_len equ $ - history_prompt_second
after_vision_prompt: db 'after'
after_vision_prompt_len equ $ - after_vision_prompt
vision_prompt: db 'look ', '"', 'here', '"', 10
vision_prompt_len equ $ - vision_prompt
vision_mime: db 'image/png'
vision_mime_len equ $ - vision_mime
vision_b64: db 'QUJD'
vision_b64_len equ $ - vision_b64
guild_id: db 'guild-1'
guild_id_len equ $ - guild_id
custom_model: db 'openai/gpt-oss-120b'
custom_model_len equ $ - custom_model
custom_persona: db 'Custom "persona"'
custom_persona_len equ $ - custom_persona
history_limit_5: db '5'
history_limit_5_len equ $ - history_limit_5
history_limit_100: db '100'
history_limit_100_len equ $ - history_limit_100
history_limit_33: db '33'
history_limit_33_len equ $ - history_limit_33
history_limit_invalid: db 'no'
history_limit_invalid_len equ $ - history_limit_invalid
near_max_history_content: times 511 db 'x'
near_max_history_content_len equ $ - near_max_history_content
role_user: db 'user'
role_user_len equ $ - role_user
groq_url: db 'https://api.groq.com/openai/v1/chat/completions'
groq_url_len equ $ - groq_url
expected_authorization: db 'Authorization: Bearer gsk_test_value'
expected_authorization_len equ $ - expected_authorization
expected_body: db '{"model":"llama-3.3-70b-versatile","messages":[{"role":"system","content":"You are CaineASM, a concise Discord assistant."},{"role":"user","content":"Say ', 0x5c, '"', 'hi', 0x5c, '"', 0x5c, 'n', 0x5c, 0x5c, ' now"}],"max_completion_tokens":512,"temperature":0.7}'
expected_body_len equ $ - expected_body
expected_default_plain_body: db '{"model":"llama-3.3-70b-versatile","messages":[{"role":"system","content":"You are CaineASM, a concise Discord assistant."},{"role":"user","content":"hello"}],"max_completion_tokens":512,"temperature":0.7}'
expected_default_plain_body_len equ $ - expected_default_plain_body
expected_custom_body: db '{"model":"openai/gpt-oss-120b","messages":[{"role":"system","content":"Custom ', 0x5c, '"', 'persona', 0x5c, '"', '"},{"role":"user","content":"hello"}],"max_completion_tokens":512,"temperature":0.7}'
expected_custom_body_len equ $ - expected_custom_body
expected_history_first_body: db '{"model":"openai/gpt-oss-120b","messages":[{"role":"system","content":"Custom ', 0x5c, '"', 'persona', 0x5c, '"', '"},{"role":"user","content":"first"}],"max_completion_tokens":512,"temperature":0.7}'
expected_history_first_body_len equ $ - expected_history_first_body
expected_history_second_body: db '{"model":"openai/gpt-oss-120b","messages":[{"role":"system","content":"Custom ', 0x5c, '"', 'persona', 0x5c, '"', '"},{"role":"user","content":"first"},{"role":"assistant","content":"Answer', 0x5c, 'nOK"},{"role":"user","content":"second"}],"max_completion_tokens":512,"temperature":0.7}'
expected_history_second_body_len equ $ - expected_history_second_body
expected_vision_body: db '{"model":"meta-llama/llama-4-scout-17b-16e-instruct","messages":[{"role":"system","content":"Custom ', 0x5c, '"', 'persona', 0x5c, '"', '"},{"role":"user","content":[{"type":"image_url","image_url":{"url":"data:image/png;base64,QUJD"}},{"type":"text","text":"look ', 0x5c, '"', 'here', 0x5c, '"', 0x5c, 'n', '"}]}],"max_completion_tokens":1024,"temperature":0.8}'
expected_vision_body_len equ $ - expected_vision_body
expected_vision_history_body: db '{"model":"openai/gpt-oss-120b","messages":[{"role":"system","content":"Custom ', 0x5c, '"', 'persona', 0x5c, '"', '"},{"role":"user","content":"[kirim gambar] look ', 0x5c, '"', 'here', 0x5c, '"', 0x5c, 'n"},{"role":"assistant","content":"Answer', 0x5c, 'nOK"},{"role":"user","content":"after"}],"max_completion_tokens":512,"temperature":0.7}'
expected_vision_history_body_len equ $ - expected_vision_history_body
expected_failed_vision_history_body: db '{"model":"openai/gpt-oss-120b","messages":[{"role":"system","content":"Custom ', 0x5c, '"', 'persona', 0x5c, '"', '"},{"role":"user","content":"after"}],"max_completion_tokens":512,"temperature":0.7}'
expected_failed_vision_history_body_len equ $ - expected_failed_vision_history_body
response_json: db '{"choices":[{"message":{"content":"Answer', 0x5c, 'nOK"}}]}'
response_json_len equ $ - response_json
invalid_response_json: db '{"choices":[]}'
invalid_response_json_len equ $ - invalid_response_json
expected_reply: db 'Answer', 10, 'OK'
expected_reply_len equ $ - expected_reply

section .data
groq_key_ptr: dq 0
groq_key_len: dd 0
mock_status: dq 0
mock_calls: dq 0
mock_retry_429_once: dd 0
mock_invalid_json: dd 0
failure_stage: dd 0
mock_body_ptr: dq 0
mock_body_len: dd 0
config_mode: dd 0
mock_relaxed_body: dd 0
mock_transport_diag: dd 0

section .bss
reply: resb 64

BITS 64
DEFAULT REL

extern groq_chat_once
extern groq_select_guild

global _start
global secure_https_post_json
global groq_key_ptr
global groq_key_len
global guild_config_get

%define SYS_EXIT 60

section .text
_start:
    lea rax, [api_key]
    mov [groq_key_ptr], rax
    mov dword [groq_key_len], api_key_len
    mov qword [mock_calls], 0
    mov qword [mock_status], 200
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
    mov dword [config_mode], 1
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

    ; Non-retriable HTTP errors return failure instead of accepting error JSON.
    mov dword [failure_stage], 3
    mov qword [mock_status], 400
    lea rax, [expected_custom_body]
    mov [mock_body_ptr], rax
    mov dword [mock_body_len], expected_custom_body_len
    lea rdi, [plain_prompt]
    mov esi, plain_prompt_len
    lea rdx, [reply]
    mov ecx, 64
    call groq_chat_once
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 3
    jne .fail

    ; Header injection bytes in an API key are rejected before touching transport.
    mov dword [failure_stage], 4
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
    cmp qword [mock_calls], 3
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; Config seam returns optional per-guild model/persona only after selection test enables it.
guild_config_get:
    cmp dword [config_mode], 1
    jne .missing
    cmp byte [rdx], 'm'
    jne .persona
    lea rax, [custom_model]
    mov edx, custom_model_len
    ret
.persona:
    cmp byte [rdx], 's'
    jne .missing
    lea rax, [custom_persona]
    mov edx, custom_persona_len
    ret
.missing:
    xor eax, eax
    xor edx, edx
    ret

; RDI=url, RSI=authorization, RDX=body, RCX=body len,
; R8=response, R9=capacity, [RSP+8]=long *status_out.
secure_https_post_json:
    push rbx
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
    cmp ecx, [mock_body_len]
    jne .bad
    mov rdi, rbx
    mov rsi, [mock_body_ptr]
    mov edx, [mock_body_len]
    call equal_bytes
    test al, al
    jz .bad
    mov rdi, r8
    lea rsi, [response_json]
    mov edx, response_json_len
    call copy_bytes
    mov byte [r8 + response_json_len], 0
    mov r10, [rsp + 16]
    mov rax, [mock_status]
    mov [r10], rax
    inc qword [mock_calls]
    mov eax, response_json_len
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
guild_id: db 'guild-1'
guild_id_len equ $ - guild_id
custom_model: db 'openai/gpt-oss-120b'
custom_model_len equ $ - custom_model
custom_persona: db 'Custom "persona"'
custom_persona_len equ $ - custom_persona
groq_url: db 'https://api.groq.com/openai/v1/chat/completions'
groq_url_len equ $ - groq_url
expected_authorization: db 'Authorization: Bearer gsk_test_value'
expected_authorization_len equ $ - expected_authorization
expected_body: db '{"model":"llama-3.3-70b-versatile","messages":[{"role":"system","content":"You are CaineASM, a concise Discord assistant."},{"role":"user","content":"Say ', 0x5c, '"', 'hi', 0x5c, '"', 0x5c, 'n', 0x5c, 0x5c, ' now"}],"max_completion_tokens":512,"temperature":0.7}'
expected_body_len equ $ - expected_body
expected_plain_body: db '{"model":"llama-3.3-70b-versatile","messages":[{"role":"system","content":"You are CaineASM, a concise Discord assistant."},{"role":"user","content":"hello"}],"max_completion_tokens":512,"temperature":0.7}'
expected_plain_body_len equ $ - expected_plain_body
expected_custom_body: db '{"model":"openai/gpt-oss-120b","messages":[{"role":"system","content":"Custom ', 0x5c, '"', 'persona', 0x5c, '"', '"},{"role":"user","content":"hello"}],"max_completion_tokens":512,"temperature":0.7}'
expected_custom_body_len equ $ - expected_custom_body
response_json: db '{"choices":[{"message":{"content":"Answer', 0x5c, 'nOK"}}]}'
response_json_len equ $ - response_json
expected_reply: db 'Answer', 10, 'OK'
expected_reply_len equ $ - expected_reply

section .data
groq_key_ptr: dq 0
groq_key_len: dd 0
mock_status: dq 0
mock_calls: dq 0
failure_stage: dd 0
mock_body_ptr: dq 0
mock_body_len: dd 0
config_mode: dd 0

section .bss
reply: resb 64

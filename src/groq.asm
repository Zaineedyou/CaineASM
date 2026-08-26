BITS 64
DEFAULT REL

global groq_chat_once
global groq_vision_once
global groq_select_guild
global groq_select_history
global groq_get_selected_history_limit

extern secure_https_post_json
extern groq_key_ptr
extern groq_key_len
extern json_escape_append
extern vision_build_payload
extern json_find_key
extern json_read_string
extern guild_config_get
extern history_visit_recent
extern history_visit_recent_reverse
extern history_append

%define SYS_NANOSLEEP 35

%define GROQ_PROMPT_MAX 1800
%define GROQ_REPLY_MAX 1900
%define GROQ_AUTH_CAP 512
%define GROQ_BODY_CAP 16384
%define GROQ_VISION_B64_MAX 15000
%define GROQ_VISION_MIME_MAX 63
%define GROQ_RESPONSE_CAP 8192
%define GROQ_RETRIES 3
%define GROQ_HISTORY_MAX 2
%define GROQ_HISTORY_DEFAULT 30
%define GROQ_HISTORY_SAFE_MAX 32
%define GROQ_HISTORY_KEY_MAX 63

; RDI=prompt bytes, ESI=prompt length, RDX=reply destination, ECX=reply capacity.
; EAX=decoded reply length on HTTP success, -1 on validation, transport, API, or parse failure.
; The caller owns any user-visible error response. No secrets are copied into logs.
section .text
groq_chat_once:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov [current_prompt_ptr], r12
    mov [current_prompt_len], r13d
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    test r13d, r13d
    jz .bad
    cmp r13d, GROQ_PROMPT_MAX
    ja .bad
    cmp r15d, 1
    jbe .bad
    cmp r15d, GROQ_REPLY_MAX + 1
    ja .bad
    mov rbx, [groq_key_ptr]
    mov eax, [groq_key_len]
    test rbx, rbx
    jz .bad
    test eax, eax
    jz .bad
    cmp eax, GROQ_AUTH_CAP - authorization_prefix_len - 1
    ja .bad
    mov rdi, rbx
    mov esi, eax
    call header_value_safe
    test al, al
    jz .bad

    ; Authorization: Bearer <GROQ_API_KEY>
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, rbx
    mov edx, [groq_key_len]
    call copy_bytes
    mov byte [rdi + rdx], 0

    ; Non-streaming Chat Completions body with bounded model, system, and user escaping.
    mov dword [request_body_len], 0
    lea rdi, [request_prefix]
    mov esi, request_prefix_len
    call request_append_bytes
    test eax, eax
    js .bad
    mov rdi, [selected_model_ptr]
    mov esi, [selected_model_len]
    call request_append_escaped
    test eax, eax
    js .bad
    lea rdi, [request_after_model]
    mov esi, request_after_model_len
    call request_append_bytes
    test eax, eax
    js .bad
    mov rdi, [selected_persona_ptr]
    mov esi, [selected_persona_len]
    call request_append_escaped
    test eax, eax
    js .bad
    lea rdi, [request_after_persona]
    mov esi, request_after_persona_len
    call request_append_bytes
    test eax, eax
    js .bad
    mov rdi, [selected_history_key_ptr]
    mov esi, [selected_history_key_len]
    test rdi, rdi
    jz .history_done
    test esi, esi
    jle .history_done
    ; First walk newest-to-oldest only to count complete history entries that
    ; still leave space for the current user turn and suffix. A second bounded
    ; chronological walk emits that newest tail. This keeps the 16 KiB body
    ; valid at mature ring depth without heap or a second message buffer.
    mov dword [selected_history_emit_count], 0
    mov dword [selected_history_emit_bytes], 0
    lea rdx, [groq_history_select_callback]
    mov ecx, [selected_history_limit]
    call history_visit_recent_reverse
    test eax, eax
    js .bad
    mov ecx, [selected_history_emit_count]
    test ecx, ecx
    jle .history_done
    mov rdi, [selected_history_key_ptr]
    mov esi, [selected_history_key_len]
    lea rdx, [groq_history_callback]
    call history_visit_recent
    test eax, eax
    js .bad
.history_done:
    lea rdi, [request_before_user]
    mov esi, request_before_user_len
    call request_append_bytes
    test eax, eax
    js .bad
    mov rdi, r12
    mov esi, r13d
    call request_append_escaped
    test eax, eax
    js .bad
    lea rdi, [request_suffix]
    mov esi, request_suffix_len
    call request_append_bytes
    test eax, eax
    js .bad
    mov ebx, [request_body_len]
    mov byte [request_body + rbx], 0

    xor r12d, r12d
.retry:
    lea rdi, [groq_url]
    lea rsi, [authorization]
    lea rdx, [request_body]
    mov ecx, ebx
    lea r8, [response_body]
    mov r9, GROQ_RESPONSE_CAP
    call groq_secure_post
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .retryable_status
    cmp rax, 300
    jae .retryable_status

    ; Chat completion responses put visible text in choices[0].message.content.
    lea rdi, [response_body]
    mov rsi, [response_length]
    lea rdx, [key_content]
    mov ecx, key_content_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    lea rsi, [response_body]
    add rsi, [response_length]
    mov rdx, r14
    mov ecx, r15d
    dec ecx
    call json_read_string
    test eax, eax
    jle .bad
    mov byte [r14 + rax], 0
    mov [last_reply_len], eax
    call groq_store_history
    mov eax, [last_reply_len]
    jmp .out
.retryable_status:
    cmp rax, 429
    je .retryable
    cmp rax, 500
    jb .bad
.retryable:
    inc r12d
    cmp r12d, GROQ_RETRIES
    jae .bad
    lea rdi, [retry_pause]
    xor esi, esi
    mov eax, SYS_NANOSLEEP
    syscall
    jmp .retry
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=prompt, ESI=len, RDX=mime, ECX=mime len, R8=base64, R9D=base64 len.
; Stack: [RSP+8]=reply destination, [RSP+16]=reply capacity.
; EAX=decoded reply length, or -1. History is committed only on response success.
groq_vision_once:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov [vision_mime_ptr], rdx
    mov [vision_mime_len], ecx
    mov [vision_b64_ptr], r8
    mov [vision_b64_len], r9d
    mov [current_prompt_ptr], r12
    mov [current_prompt_len], r13d
    mov r14, [rsp + 48]
    mov r15d, [rsp + 56]
    test r12, r12
    jz .bad
    test r13d, r13d
    js .bad
    cmp r13d, GROQ_PROMPT_MAX
    ja .bad
    cmp qword [vision_mime_ptr], 0
    je .bad
    cmp dword [vision_mime_len], 1
    jl .bad
    cmp dword [vision_mime_len], GROQ_VISION_MIME_MAX
    ja .bad
    cmp qword [vision_b64_ptr], 0
    je .bad
    cmp dword [vision_b64_len], 1
    jl .bad
    cmp dword [vision_b64_len], GROQ_VISION_B64_MAX
    ja .bad
    test r14, r14
    jz .bad
    cmp r15d, 2
    jb .bad
    cmp r15d, GROQ_REPLY_MAX + 1
    ja .bad
    mov rbx, [groq_key_ptr]
    mov eax, [groq_key_len]
    test rbx, rbx
    jz .bad
    test eax, eax
    jz .bad
    cmp eax, GROQ_AUTH_CAP - authorization_prefix_len - 1
    ja .bad
    mov rdi, rbx
    mov esi, eax
    call header_value_safe
    test al, al
    jz .bad
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, rbx
    mov edx, [groq_key_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    ; Build exact multimodal body entirely in NASM.
    mov eax, r13d
    push rax
    push r12
    mov eax, [vision_b64_len]
    push rax
    mov rax, [vision_b64_ptr]
    push rax
    lea rdi, [request_body]
    mov esi, GROQ_BODY_CAP
    mov rdx, [selected_persona_ptr]
    mov ecx, [selected_persona_len]
    mov r8, [vision_mime_ptr]
    mov r9d, [vision_mime_len]
    call vision_build_payload
    add rsp, 32
    test eax, eax
    js .bad
    mov ebx, eax
    mov [request_body_len], eax
    xor r12d, r12d
.retry:
    lea rdi, [groq_url]
    lea rsi, [authorization]
    lea rdx, [request_body]
    mov ecx, ebx
    lea r8, [response_body]
    mov r9, GROQ_RESPONSE_CAP
    call groq_secure_post
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .retry_status
    cmp rax, 300
    jae .retry_status
    lea rdi, [response_body]
    mov rsi, [response_length]
    lea rdx, [key_content]
    mov ecx, key_content_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    lea rsi, [response_body]
    add rsi, [response_length]
    mov rdx, r14
    mov ecx, r15d
    dec ecx
    call json_read_string
    test eax, eax
    jle .bad
    mov byte [r14 + rax], 0
    mov [last_reply_len], eax
    ; Keep the bounded source-compatible marker, then commit only after success.
    lea rdi, [vision_history_marker]
    lea rsi, [vision_history_prefix]
    mov edx, vision_history_prefix_len
    call copy_bytes
    lea rdi, [vision_history_marker + vision_history_prefix_len]
    mov rsi, [current_prompt_ptr]
    mov edx, [current_prompt_len]
    call copy_bytes
    lea rax, [vision_history_marker]
    mov [current_prompt_ptr], rax
    mov eax, r13d
    add eax, vision_history_prefix_len
    mov [current_prompt_len], eax
    call groq_store_history
    mov eax, [last_reply_len]
    jmp .out
.retry_status:
    cmp rax, 429
    je .retry_wait
    cmp rax, 500
    jb .bad
.retry_wait:
    inc r12d
    cmp r12d, GROQ_RETRIES
    jae .bad
    lea rdi, [retry_pause]
    xor esi, esi
    mov eax, SYS_NANOSLEEP
    syscall
    jmp .retry
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=history key, ESI=history key len. The selection is process-local and is
; consumed by the next successful groq_chat_once call. Invalid/missing input clears it.
groq_select_history:
    mov qword [selected_history_key_ptr], 0
    mov dword [selected_history_key_len], 0
    test rdi, rdi
    jz .done
    test esi, esi
    jle .done
    cmp esi, GROQ_HISTORY_KEY_MAX
    ja .done
    mov [selected_history_key_ptr], rdi
    mov [selected_history_key_len], esi
.done:
    xor eax, eax
    ret

; RDI=guild, ESI=guild len. Selects bounded stored model/persona for the next
; request. Missing/invalid values deterministically fall back to source defaults.
groq_select_guild:
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    lea rax, [default_model]
    mov [selected_model_ptr], rax
    mov dword [selected_model_len], default_model_len
    lea rax, [default_persona]
    mov [selected_persona_ptr], rax
    mov dword [selected_persona_len], default_persona_len
    mov dword [selected_history_limit], GROQ_HISTORY_DEFAULT
    test r12, r12
    jz .done
    test r13d, r13d
    jle .done
    lea rdi, [r12]
    mov esi, r13d
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    call guild_config_get
    test rax, rax
    jz .persona
    test edx, edx
    jle .persona
    cmp edx, 96
    ja .persona
    mov [selected_model_ptr], rax
    mov [selected_model_len], edx
.persona:
    mov rdi, r12
    mov esi, r13d
    lea rdx, [setting_persona]
    mov ecx, setting_persona_len
    call guild_config_get
    test rax, rax
    jz .history_limit
    test edx, edx
    jle .history_limit
    cmp edx, 511
    ja .history_limit
    mov [selected_persona_ptr], rax
    mov [selected_persona_len], edx
.history_limit:
    mov rdi, r12
    mov esi, r13d
    lea rdx, [setting_history]
    mov ecx, setting_history_len
    call guild_config_get
    test rax, rax
    jz .done
    test edx, edx
    jle .done
    mov rdi, rax
    mov esi, edx
    call groq_parse_history_limit
    test eax, eax
    jle .done
    mov [selected_history_limit], eax
.done:
    xor eax, eax
    pop r13
    pop r12
    ret

; EAX=current effective bound selected for the next text request. This read-only
; accessor is used by local vectors to lock the 5..32 clamp contract.
groq_get_selected_history_limit:
    mov eax, [selected_history_limit]
    ret

; RDI=decimal bytes, ESI=len. EAX=5..32, or -1.
groq_parse_history_limit:
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    cmp esi, 3
    ja .bad
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .range
    movzx edx, byte [rdi + rcx]
    sub edx, '0'
    cmp edx, 9
    ja .bad
    imul eax, eax, 10
    add eax, edx
    inc ecx
    jmp .loop
.range:
    cmp eax, 5
    jb .bad
    cmp eax, GROQ_HISTORY_SAFE_MAX
    ja .clamp
    ret
.clamp:
    mov eax, GROQ_HISTORY_SAFE_MAX
    ret
.bad:
    mov eax, -1
    ret

; Reverse selection callback. It receives entries newest first and stops at
; the first entry that would make the final request exceed GROQ_BODY_CAP - 1.
; RDI=role, ESI=role len, RDX=content, ECX=content len. EAX=0 continue,
; 1 successful stop, or -1 on impossible bounded input.
groq_history_select_callback:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    cmp r13d, role_user_len
    je .user_role
    cmp r13d, role_assistant_len
    jne .skip
    mov ebx, role_assistant_len
    jmp .role_ready
.user_role:
    mov ebx, role_user_len
.role_ready:
    mov rdi, r14
    mov esi, r15d
    call groq_escaped_length
    test eax, eax
    js .bad
    add eax, request_history_prefix_len + request_history_middle_len + request_history_suffix_len
    add eax, ebx
    mov r13d, eax
    mov edx, [request_body_len]
    add edx, [selected_history_emit_bytes]
    add edx, r13d
    mov r15d, edx
    mov rdi, [current_prompt_ptr]
    mov esi, [current_prompt_len]
    call groq_escaped_length
    test eax, eax
    js .bad
    add eax, request_before_user_len + request_suffix_len
    add r15d, eax
    cmp r15d, GROQ_BODY_CAP - 1
    ja .stop
    add [selected_history_emit_bytes], r13d
    inc dword [selected_history_emit_count]
.skip:
    xor eax, eax
    jmp .out
.stop:
    mov eax, 1
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

; history_visit_recent callback. RDI=role, ESI=role len, RDX=content, ECX=content len.
; Only source-compatible user/assistant entries are included in the Groq message list.
groq_history_callback:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    cmp r13d, role_user_len
    je .user_role
    cmp r13d, role_assistant_len
    jne .done
    lea rdi, [role_assistant]
    mov esi, role_assistant_len
    jmp .role_ready
.user_role:
    lea rdi, [role_user]
    mov esi, role_user_len
.role_ready:
    mov [history_role_ptr], rdi
    mov [history_role_len], esi
    lea rdi, [request_history_prefix]
    mov esi, request_history_prefix_len
    call request_append_bytes
    test eax, eax
    js .bad
    mov rdi, [history_role_ptr]
    mov esi, [history_role_len]
    call request_append_bytes
    test eax, eax
    js .bad
    lea rdi, [request_history_middle]
    mov esi, request_history_middle_len
    call request_append_bytes
    test eax, eax
    js .bad
    mov rdi, r14
    mov esi, r15d
    call request_append_escaped
    test eax, eax
    js .bad
    lea rdi, [request_history_suffix]
    mov esi, request_history_suffix_len
    call request_append_bytes
    test eax, eax
    js .bad
.done:
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; Saves the successful roundtrip only after a reply has been decoded.
groq_store_history:
    push r12
    push r13
    cmp qword [selected_history_key_ptr], 0
    je .done
    mov r12, [selected_history_key_ptr]
    mov r13d, [selected_history_key_len]
    test r12, r12
    jz .done
    test r13d, r13d
    jle .done
    mov rdi, r12
    mov esi, r13d
    lea rdx, [role_user]
    mov ecx, role_user_len
    mov r8, [current_prompt_ptr]
    mov r9d, [current_prompt_len]
    call history_append
    mov rdi, r12
    mov esi, r13d
    lea rdx, [role_assistant]
    mov ecx, role_assistant_len
    mov r8, r14
    mov r9d, [last_reply_len]
    call history_append
.done:
    pop r13
    pop r12
    ret

; RDI=source, ESI=len. EAX=JSON-escaped byte length, or -1 for invalid input.
; This mirrors json_escape_append without writing, so capacity selection is exact.
groq_escaped_length:
    test rdi, rdi
    jz .bad
    test esi, esi
    js .bad
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    movzx edx, byte [rdi + rcx]
    inc ecx
    cmp dl, '"'
    je .two
    cmp dl, 0x5c
    je .two
    cmp dl, 8
    je .two
    cmp dl, 12
    je .two
    cmp dl, 10
    je .two
    cmp dl, 13
    je .two
    cmp dl, 9
    je .two
    cmp dl, 0x20
    jb .six
    inc eax
    jmp .loop
.two:
    add eax, 2
    jmp .loop
.six:
    add eax, 6
    jmp .loop
.done:
    ret
.bad:
    mov eax, -1
    ret

; RDI=source, ESI=len. EAX=0 or -1.
request_append_bytes:
    test rdi, rdi
    jz .bad
    test esi, esi
    js .bad
    mov eax, [request_body_len]
    mov edx, GROQ_BODY_CAP - 1
    sub edx, eax
    cmp esi, edx
    ja .bad
    lea r8, [request_body + rax]
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .done
    mov dl, [rdi + rcx]
    mov [r8 + rcx], dl
    inc ecx
    jmp .copy
.done:
    add [request_body_len], esi
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=source, ESI=len. EAX=0 or -1.
request_append_escaped:
    test rdi, rdi
    jz .bad
    test esi, esi
    js .bad
    mov r8, rdi
    mov ecx, esi
    lea rdi, [request_body]
    mov eax, [request_body_len]
    add rdi, rax
    mov esi, GROQ_BODY_CAP - 1
    sub esi, [request_body_len]
    mov rdx, r8
    call json_escape_append
    test eax, eax
    js .bad
    add [request_body_len], eax
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; System V wrapper for the seventh `long *status_out` argument.
; RDI URL, RSI auth, RDX body, RCX length, R8 response, R9 response capacity.
; RAX=response length or negative transport error.
groq_secure_post:
    sub rsp, 8
    lea rax, [response_status]
    mov [rsp], rax
    call secure_https_post_json
    mov [response_length], rax
    add rsp, 8
    ret

; RDI=header value, ESI=length. AL=1 if it is bounded and cannot inject a new header line.
header_value_safe:
    xor edx, edx
.loop:
    cmp edx, esi
    jae .yes
    mov al, [rdi + rdx]
    cmp al, 0x21
    jb .no
    cmp al, 0x7e
    ja .no
    inc edx
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
vision_history_prefix: db '[kirim gambar] '
vision_history_prefix_len equ $ - vision_history_prefix
groq_url: db 'https://api.groq.com/openai/v1/chat/completions',0
authorization_prefix: db 'Authorization: Bearer '
authorization_prefix_len equ $ - authorization_prefix
request_prefix: db '{"model":"'
request_prefix_len equ $ - request_prefix
request_after_model: db '","messages":[{"role":"system","content":"'
request_after_model_len equ $ - request_after_model
request_after_persona: db '"'
request_after_persona_len equ $ - request_after_persona
request_history_prefix: db '},{"role":"'
request_history_prefix_len equ $ - request_history_prefix
request_history_middle: db '","content":"'
request_history_middle_len equ $ - request_history_middle
request_history_suffix: db '"'
request_history_suffix_len equ $ - request_history_suffix
request_before_user: db '},{"role":"user","content":"'
request_before_user_len equ $ - request_before_user
request_suffix: db '"}],"max_completion_tokens":512,"temperature":0.7}'
request_suffix_len equ $ - request_suffix
key_content: db 'content'
key_content_len equ $ - key_content
retry_pause: dq 1, 0
setting_model: db 'model'
setting_model_len equ $ - setting_model
setting_persona: db 'system_prompt'
setting_persona_len equ $ - setting_persona
setting_history: db 'max_history'
setting_history_len equ $ - setting_history
default_model: db 'llama-3.3-70b-versatile'
default_model_len equ $ - default_model
default_persona: db 'You are CaineASM, a concise Discord assistant.'
default_persona_len equ $ - default_persona
role_user: db 'user'
role_user_len equ $ - role_user
role_assistant: db 'assistant'
role_assistant_len equ $ - role_assistant

section .data
response_status: dq 0
response_length: dq 0
request_body_len: dd 0
selected_model_ptr: dq default_model
selected_model_len: dd default_model_len
selected_persona_ptr: dq default_persona
selected_persona_len: dd default_persona_len
selected_history_key_ptr: dq 0
selected_history_key_len: dd 0
selected_history_limit: dd GROQ_HISTORY_DEFAULT
selected_history_emit_count: dd 0
selected_history_emit_bytes: dd 0
current_prompt_ptr: dq 0
current_prompt_len: dd 0
last_reply_len: dd 0
vision_mime_ptr: dq 0
vision_mime_len: dd 0
vision_b64_ptr: dq 0
vision_b64_len: dd 0
history_role_ptr: dq 0
history_role_len: dd 0

section .bss
authorization: resb GROQ_AUTH_CAP
request_body: resb GROQ_BODY_CAP
response_body: resb GROQ_RESPONSE_CAP
vision_history_marker: resb GROQ_PROMPT_MAX + 16

BITS 64
DEFAULT REL

global groq_chat_once
global groq_select_guild

extern secure_https_post_json
extern groq_key_ptr
extern groq_key_len
extern json_escape_append
extern json_find_key
extern json_read_string
extern guild_config_get

%define SYS_NANOSLEEP 35

%define GROQ_PROMPT_MAX 1800
%define GROQ_REPLY_MAX 1900
%define GROQ_AUTH_CAP 512
%define GROQ_BODY_CAP 4096
%define GROQ_RESPONSE_CAP 8192
%define GROQ_RETRIES 3

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
    jz .done
    test edx, edx
    jle .done
    cmp edx, 511
    ja .done
    mov [selected_persona_ptr], rax
    mov [selected_persona_len], edx
.done:
    xor eax, eax
    pop r13
    pop r12
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
groq_url: db 'https://api.groq.com/openai/v1/chat/completions',0
authorization_prefix: db 'Authorization: Bearer '
authorization_prefix_len equ $ - authorization_prefix
request_prefix: db '{"model":"'
request_prefix_len equ $ - request_prefix
request_after_model: db '","messages":[{"role":"system","content":"'
request_after_model_len equ $ - request_after_model
request_after_persona: db '"},{"role":"user","content":"'
request_after_persona_len equ $ - request_after_persona
request_suffix: db '"}],"max_completion_tokens":512,"temperature":0.7}'
request_suffix_len equ $ - request_suffix
key_content: db 'content'
key_content_len equ $ - key_content
retry_pause: dq 1, 0
setting_model: db 'model'
setting_model_len equ $ - setting_model
setting_persona: db 'system_prompt'
setting_persona_len equ $ - setting_persona
default_model: db 'llama-3.3-70b-versatile'
default_model_len equ $ - default_model
default_persona: db 'You are CaineASM, a concise Discord assistant.'
default_persona_len equ $ - default_persona

section .data
response_status: dq 0
response_length: dq 0
request_body_len: dd 0
selected_model_ptr: dq default_model
selected_model_len: dd default_model_len
selected_persona_ptr: dq default_persona
selected_persona_len: dd default_persona_len

section .bss
authorization: resb GROQ_AUTH_CAP
request_body: resb GROQ_BODY_CAP
response_body: resb GROQ_RESPONSE_CAP

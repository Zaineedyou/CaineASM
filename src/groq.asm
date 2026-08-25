BITS 64
DEFAULT REL

global groq_chat_once

extern secure_https_post_json
extern groq_key_ptr
extern groq_key_len
extern json_escape_append
extern json_find_key
extern json_read_string

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

    ; Non-streaming Chat Completions body with bounded user-content escaping.
    lea rdi, [request_body]
    lea rsi, [request_prefix]
    mov edx, request_prefix_len
    call copy_bytes
    lea rdi, [request_body + request_prefix_len]
    mov esi, GROQ_BODY_CAP - request_prefix_len - request_suffix_len
    mov rdx, r12
    mov ecx, r13d
    call json_escape_append
    test eax, eax
    js .bad
    mov ebx, eax
    lea rdi, [request_body + request_prefix_len]
    add rdi, rbx
    lea rsi, [request_suffix]
    mov edx, request_suffix_len
    call copy_bytes
    add ebx, request_prefix_len + request_suffix_len
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
request_prefix: db '{"model":"llama-3.3-70b-versatile","messages":[{"role":"system","content":"You are CaineASM, a concise Discord assistant."},{"role":"user","content":"'
request_prefix_len equ $ - request_prefix
request_suffix: db '"}],"max_completion_tokens":512,"temperature":0.7}'
request_suffix_len equ $ - request_suffix
key_content: db 'content'
key_content_len equ $ - key_content
retry_pause: dq 1, 0

section .data
response_status: dq 0
response_length: dq 0

section .bss
authorization: resb GROQ_AUTH_CAP
request_body: resb GROQ_BODY_CAP
response_body: resb GROQ_RESPONSE_CAP

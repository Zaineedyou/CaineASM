BITS 64
DEFAULT REL

global discord_send_text

extern secure_https_post_json
extern discord_token_ptr
extern discord_token_len

; RDI=channel ID pointer, ESI=channel ID length, RDX=text pointer, ECX=text length.
; EAX=0 only when Discord reports HTTP 2xx. The adapter only transports the request.
discord_send_text:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r13d, r13d
    jz .bad
    test r15d, r15d
    jz .bad
    cmp r13d, 64
    ja .bad
    cmp r15d, 1900
    ja .bad
    cmp dword [discord_token_len], 0
    je .bad

    ; URL: https://discord.com/api/v10/channels/<id>/messages
    lea rdi, [request_url]
    lea rsi, [url_prefix]
    mov edx, url_prefix_len
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    add rdi, r13
    lea rsi, [url_suffix]
    mov edx, url_suffix_len
    call copy_bytes
    mov byte [rdi + rdx], 0

    ; Header: Authorization: Bot <token>
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0

    ; Strict JSON text subset: refuse control chars, quote and slash until full
    ; JSON escape logic is reached. This keeps the request injection-safe.
    lea rdi, [json_body]
    lea rsi, [json_prefix]
    mov edx, json_prefix_len
    call copy_bytes
    xor ebx, ebx
.text:
    cmp ebx, r15d
    jae .text_done
    mov al, [r14 + rbx]
    cmp al, 0x20
    jb .bad
    cmp al, '"'
    je .bad
    cmp al, 0x5c
    je .bad
    mov [json_body + json_prefix_len + rbx], al
    inc ebx
    jmp .text
.text_done:
    lea rdi, [json_body + json_prefix_len]
    add rdi, r15
    lea rsi, [json_suffix]
    mov edx, json_suffix_len
    call copy_bytes
    mov rax, r15
    add rax, json_prefix_len + json_suffix_len

    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [json_body]
    mov rcx, rax
    lea r8, [response_body]
    mov r9, 4096
    call call_secure_post
    test rax, rax
    js .bad
    ; The C ABI status pointer is passed as seventh argument on the stack.
    ; The response status lives in response_status after the wrapper below.
    mov rax, [response_status]
    cmp rax, 200
    jb .bad
    cmp rax, 300
    jae .bad
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

; Wrapper maintains System V stack arguments for `long *status_out` (argument 7).
; RDI URL, RSI auth, RDX body, RCX length, R8 response, R9 capacity.
; RAX=status return.
call_secure_post:
    sub rsp, 8
    lea rax, [response_status]
    push rax
    call secure_https_post_json
    add rsp, 16
    ret

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
url_prefix: db 'https://discord.com/api/v10/channels/'
url_prefix_len equ $ - url_prefix
url_suffix: db '/messages'
url_suffix_len equ $ - url_suffix
authorization_prefix: db 'Authorization: Bot '
authorization_prefix_len equ $ - authorization_prefix
json_prefix: db '{"content":"'
json_prefix_len equ $ - json_prefix
json_suffix: db '"}'
json_suffix_len equ $ - json_suffix

section .data
response_status: dq 0

section .bss
request_url: resb 256
authorization: resb 512
json_body: resb 2048
response_body: resb 4096

BITS 64
DEFAULT REL

extern discord_send_text
extern json_escape_append

global _start
global secure_https_post_json
global discord_token_ptr
global discord_token_len

%define SYS_EXIT 60

section .text
_start:
    lea rax, [token]
    mov [discord_token_ptr], rax
    mov dword [discord_token_len], token_len
    mov qword [mock_status], 201
    mov qword [mock_calls], 0
    mov dword [mock_failure_reason], 0

    mov dword [failure_stage], 1
    ; Direct helper coverage: all JSON-sensitive bytes are escaped boundedly.
    lea rdi, [escape_output]
    mov esi, 64
    lea rdx, [message_text]
    mov ecx, message_text_len
    call json_escape_append
    cmp eax, escaped_text_len
    jne .fail
    lea rdi, [escape_output]
    lea rsi, [escaped_text]
    mov edx, escaped_text_len
    call equal_bytes
    test al, al
    jz .fail

    lea rdi, [escape_output]
    xor esi, esi
    lea rdx, [message_text]
    mov ecx, message_text_len
    call json_escape_append
    cmp eax, -1
    jne .fail

    mov dword [failure_stage], 2
    ; The full Discord request must use URL, bot authorization, escaped JSON,
    ; and a 2xx response status delivered through the seventh C ABI argument.
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_text]
    mov ecx, message_text_len
    call discord_send_text
    test eax, eax
    jnz .fail
    cmp qword [mock_calls], 1
    jne .fail

    mov dword [failure_stage], 3
    ; Non-2xx statuses propagate as a failure even when transport succeeds.
    mov qword [mock_status], 429
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_text]
    mov ecx, message_text_len
    call discord_send_text
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 2
    jne .fail

    mov dword [failure_stage], 4
    ; Invalid channel identifiers and over-limit text must not reach transport.
    lea rdi, [invalid_channel]
    mov esi, invalid_channel_len
    lea rdx, [message_text]
    mov ecx, message_text_len
    call discord_send_text
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 2
    jne .fail

    mov dword [failure_stage], 5
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [oversized_text]
    mov ecx, oversized_text_len
    call discord_send_text
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 2
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov edi, [mock_failure_reason]
    test edi, edi
    jnz .fail_exit
    mov edi, [failure_stage]
.fail_exit:
    mov eax, SYS_EXIT
    syscall

; NASM mock for the sole external transport boundary.
; RDI=url, RSI=authorization, RDX=body, RCX=body length,
; R8=response, R9=response capacity, [RSP+16]=long *status_out after saved RBX.
secure_https_post_json:
    push rbx
    mov rbx, rdx
    lea r10, [expected_url]
    mov r11d, expected_url_len
    call equal_cstring
    test al, al
    jnz .url_ok
    mov dword [mock_failure_reason], 21
    jmp .transport_fail
.url_ok:
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jnz .authorization_ok
    mov dword [mock_failure_reason], 22
    jmp .transport_fail
.authorization_ok:
    cmp ecx, expected_body_len
    je .length_ok
    mov dword [mock_failure_reason], 23
    jmp .transport_fail
.length_ok:
    mov rdi, rbx
    lea rsi, [expected_body]
    mov edx, expected_body_len
    call equal_bytes
    test al, al
    jnz .body_ok
    mov dword [mock_failure_reason], 24
    jmp .transport_fail
.body_ok:
    cmp r9, 2
    jae .capacity_ok
    mov dword [mock_failure_reason], 25
    jmp .transport_fail
.capacity_ok:
    mov byte [r8], 0
    mov r10, [rsp + 16]
    test r10, r10
    jnz .status_pointer_ok
    mov dword [mock_failure_reason], 26
    jmp .transport_fail
.status_pointer_ok:
    mov rax, [mock_status]
    mov [r10], rax
    inc qword [mock_calls]
    mov eax, 1
    pop rbx
    ret
.transport_fail:
    mov eax, -1
    pop rbx
    ret

; RDI=C string; R10=expected bytes; R11D=expected len. AL=1 on exact match.
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

section .rodata
token: db 'token-value'
token_len equ $ - token
channel_id: db '123456789012345678'
channel_id_len equ $ - channel_id
invalid_channel: db '12x'
invalid_channel_len equ $ - invalid_channel
message_text: db 'say ', '"', 'hi', '"', ' ', 0x5c, ' L', 10, 'T', 9, 'C', 1
message_text_len equ $ - message_text
escaped_text: db 'say ', 0x5c, '"', 'hi', 0x5c, '"', ' ', 0x5c, 0x5c, ' L', 0x5c, 'n', 'T', 0x5c, 't', 'C', 0x5c, 'u0001'
escaped_text_len equ $ - escaped_text
expected_url: db 'https://discord.com/api/v10/channels/123456789012345678/messages'
expected_url_len equ $ - expected_url
expected_authorization: db 'Authorization: Bot token-value'
expected_authorization_len equ $ - expected_authorization
expected_body: db '{"content":"say ', 0x5c, '"', 'hi', 0x5c, '"', ' ', 0x5c, 0x5c, ' L', 0x5c, 'n', 'T', 0x5c, 't', 'C', 0x5c, 'u0001', '"}'
expected_body_len equ $ - expected_body
oversized_text: times 2001 db 'x'
oversized_text_len equ $ - oversized_text

section .data
discord_token_ptr: dq 0
discord_token_len: dd 0
mock_status: dq 0
mock_calls: dq 0
failure_stage: dd 0
mock_failure_reason: dd 0

section .bss
escape_output: resb 64

BITS 64
DEFAULT REL

extern gateway_process_frame
extern gateway_reset_state

global _start
global secure_gateway_connect
global secure_gateway_send_text
global secure_gateway_recv_text
global secure_gateway_close
global dispatch_message_create
global discord_token_ptr
global discord_token_len

%define SYS_EXIT 60
%define ACTION_RECONNECT 1

section .text
_start:
    lea rax, [token]
    mov [discord_token_ptr], rax
    mov dword [discord_token_len], token_len
    call gateway_reset_state
    mov qword [send_calls], 0
    mov qword [dispatch_calls], 0

    ; Hello starts the scheduler and sends an escaped bounded Identify payload.
    mov dword [failure_stage], 1
    lea rax, [identify_payload]
    mov [expected_payload_ptr], rax
    mov dword [expected_payload_len], identify_payload_len
    lea rdi, [hello_frame]
    mov esi, hello_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 1
    jne .fail

    ; READY caches session/resume URL and records the latest dispatch sequence.
    mov dword [failure_stage], 2
    lea rdi, [ready_frame]
    mov esi, ready_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail

    ; Server heartbeat request emits the stored sequence, then ACK is accepted.
    mov dword [failure_stage], 3
    lea rax, [heartbeat_payload]
    mov [expected_payload_ptr], rax
    mov dword [expected_payload_len], heartbeat_payload_len
    mov dword [failure_stage], 31
    lea rdi, [heartbeat_request]
    mov esi, heartbeat_request_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 2
    jne .fail
    mov dword [failure_stage], 32
    lea rdi, [heartbeat_ack]
    mov esi, heartbeat_ack_len
    call gateway_process_frame
    test eax, eax
    jnz .fail

    ; A resumable invalid session reconnects and uses token/session/sequence in Resume.
    mov dword [failure_stage], 4
    lea rdi, [invalid_true]
    mov esi, invalid_true_len
    call gateway_process_frame
    cmp eax, ACTION_RECONNECT
    jne .fail
    lea rax, [resume_payload]
    mov [expected_payload_ptr], rax
    mov dword [expected_payload_len], resume_payload_len
    lea rdi, [hello_frame]
    mov esi, hello_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 3
    jne .fail

    ; A non-resumable invalid session clears resume state and re-identifies.
    mov dword [failure_stage], 5
    lea rdi, [invalid_false]
    mov esi, invalid_false_len
    call gateway_process_frame
    cmp eax, ACTION_RECONNECT
    jne .fail
    lea rax, [identify_payload]
    mov [expected_payload_ptr], rax
    mov dword [expected_payload_len], identify_payload_len
    lea rdi, [hello_frame]
    mov esi, hello_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [send_calls], 4
    jne .fail

    ; MESSAGE_CREATE is dispatched only after its Gateway type is recognized.
    mov dword [failure_stage], 6
    lea rdi, [message_frame]
    mov esi, message_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [dispatch_calls], 1
    jne .fail

    ; Opcode 7 requests a reconnect without parsing unrelated state.
    mov dword [failure_stage], 7
    lea rdi, [reconnect_frame]
    mov esi, reconnect_frame_len
    call gateway_process_frame
    cmp eax, ACTION_RECONNECT
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; Gateway transport seam: input is fully formed NASM JSON payload.
secure_gateway_send_text:
    cmp esi, [expected_payload_len]
    jne .bad
    mov r8, rdi
    mov rdi, r8
    mov rsi, [expected_payload_ptr]
    mov edx, [expected_payload_len]
    call equal_bytes
    test al, al
    jz .bad
    inc qword [send_calls]
    mov rax, rdx
    ret
.bad:
    mov rax, -1
    ret

; Dispatcher seam: confirms the complete MESSAGE_CREATE frame reached policy code.
dispatch_message_create:
    cmp rsi, message_frame_len
    jne .bad
    lea r8, [message_frame]
    mov r9d, message_frame_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [dispatch_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

secure_gateway_connect:
    xor eax, eax
    ret
secure_gateway_recv_text:
    mov rax, -1
    ret
secure_gateway_close:
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
hello_frame: db '{"op":10,"d":{"heartbeat_interval":45000}}'
hello_frame_len equ $ - hello_frame
ready_frame: db '{"op":0,"s":42,"t":"READY","d":{"session_id":"session-1","resume_gateway_url":"wss://resume.example/?v=10&encoding=json"}}'
ready_frame_len equ $ - ready_frame
heartbeat_request: db '{"op":1,"d":null}'
heartbeat_request_len equ $ - heartbeat_request
heartbeat_ack: db '{"op":11,"d":null}'
heartbeat_ack_len equ $ - heartbeat_ack
invalid_true: db '{"op":9,"d":true}'
invalid_true_len equ $ - invalid_true
invalid_false: db '{"op":9,"d":false}'
invalid_false_len equ $ - invalid_false
message_frame: db '{"op":0,"s":43,"t":"MESSAGE_CREATE","d":{"channel_id":"123456789012345678","content":"!status","author":{"bot":false}}}'
message_frame_len equ $ - message_frame
reconnect_frame: db '{"op":7,"d":null}'
reconnect_frame_len equ $ - reconnect_frame
identify_payload: db '{"op":2,"d":{"token":"token-value","intents":37379,"properties":{"os":"linux","browser":"caine-asm","device":"caine-asm"}}}'
identify_payload_len equ $ - identify_payload
heartbeat_payload: db '{"op":1,"d":42}'
heartbeat_payload_len equ $ - heartbeat_payload
resume_payload: db '{"op":6,"d":{"token":"token-value","session_id":"session-1","seq":42}}'
resume_payload_len equ $ - resume_payload

section .data
discord_token_ptr: dq 0
discord_token_len: dd 0
expected_payload_ptr: dq 0
expected_payload_len: dd 0
send_calls: dq 0
dispatch_calls: dq 0
failure_stage: dd 0

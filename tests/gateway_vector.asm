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
global guild_auth_reset
global guild_auth_cache_guild_create
global channel_auth_reset
global channel_auth_cache_guild_create
global lifecycle_member_add
global lifecycle_member_remove
global interaction_handle_gateway
global discord_register_application_commands
global discord_token_ptr
global discord_token_len
extern gateway_bot_user_id
extern gateway_bot_user_id_len
extern gateway_guild_name_get
extern gateway_guild_member_count_get
extern gateway_guild_count
extern gateway_uptime_format

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
    mov qword [interaction_calls], 0
    mov qword [command_registration_calls], 0

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
    cmp dword [gateway_bot_user_id_len], bot_user_id_len
    jne .fail
    lea rdi, [gateway_bot_user_id]
    lea rsi, [bot_user_id]
    mov edx, bot_user_id_len
    call equal_bytes
    test al, al
    jz .fail
    cmp qword [command_registration_calls], 1
    jne .fail

    ; A repeated READY re-caches session metadata but must not duplicate global
    ; application command registration in the same process.
    mov dword [failure_stage], 21
    lea rdi, [ready_frame]
    mov esi, ready_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [command_registration_calls], 1
    jne .fail

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

    ; GUILD_CREATE reaches only the authorization cache and does not dispatch a message.
    mov dword [failure_stage], 6
    lea rdi, [guild_create_frame]
    mov esi, guild_create_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [auth_cache_calls], 1
    jne .fail
    cmp qword [channel_cache_calls], 1
    jne .fail
    cmp qword [dispatch_calls], 0
    jne .fail
    mov dword [failure_stage], 65
    lea rdi, [cached_guild_id]
    mov esi, cached_guild_id_len
    call gateway_guild_name_get
    test rax, rax
    jz .fail
    cmp edx, cached_guild_name_len
    jne .fail
    mov rdi, rax
    lea rsi, [cached_guild_name]
    mov edx, cached_guild_name_len
    call equal_bytes
    test al, al
    jz .fail
    mov dword [failure_stage], 661
    lea rdi, [cached_guild_id]
    mov esi, cached_guild_id_len
    call gateway_guild_member_count_get
    jc .fail
    cmp eax, 42
    jne .fail
    mov dword [failure_stage], 66
    call gateway_guild_count
    cmp eax, 1
    jne .fail
    mov dword [failure_stage], 67
    lea rdi, [uptime_output]
    mov esi, 64
    call gateway_uptime_format
    test eax, eax
    jle .fail
    mov esi, eax
    lea rdi, [uptime_output]
    call uptime_shape_valid
    test al, al
    jz .fail
    mov dword [failure_stage], 68
    lea rdi, [missing_guild_id]
    mov esi, missing_guild_id_len
    call gateway_guild_name_get
    test rax, rax
    jnz .fail
    test edx, edx
    jnz .fail
    ; GUILD_DELETE removes only presentation cache state and never dispatches.
    mov dword [failure_stage], 69
    lea rdi, [guild_delete_frame]
    mov esi, guild_delete_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    call gateway_guild_count
    test eax, eax
    jnz .fail
    lea rdi, [cached_guild_id]
    mov esi, cached_guild_id_len
    call gateway_guild_name_get
    test rax, rax
    jnz .fail
    mov dword [failure_stage], 691
    lea rdi, [cached_guild_id]
    mov esi, cached_guild_id_len
    call gateway_guild_member_count_get
    jnc .fail

    ; MESSAGE_CREATE is dispatched only after its Gateway type is recognized.
    mov dword [failure_stage], 61
    lea rdi, [message_frame]
    mov esi, message_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [dispatch_calls], 1
    jne .fail

    ; INTERACTION_CREATE is isolated from message commands and callback errors
    ; cannot alter Gateway session routing.
    mov dword [failure_stage], 64
    lea rdi, [interaction_frame]
    mov esi, interaction_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [interaction_calls], 1
    jne .fail
    cmp qword [dispatch_calls], 1
    jne .fail

    ; Member lifecycle events are routed separately from message commands.
    mov dword [failure_stage], 62
    lea rdi, [member_add_frame]
    mov esi, member_add_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [member_add_calls], 1
    jne .fail
    mov dword [failure_stage], 63
    lea rdi, [member_remove_frame]
    mov esi, member_remove_frame_len
    call gateway_process_frame
    test eax, eax
    jnz .fail
    cmp qword [member_remove_calls], 1
    jne .fail

    ; Opcode 7 requests a reconnect without parsing unrelated state.
    mov dword [failure_stage], 7
    lea rdi, [reconnect_frame]
    mov esi, reconnect_frame_len
    call gateway_process_frame
    cmp eax, ACTION_RECONNECT
    jne .fail

    ; Reset invalidates cached READY identity before any later dispatch.
    mov dword [failure_stage], 8
    call gateway_reset_state
    cmp dword [gateway_bot_user_id_len], 0
    jne .fail
    cmp byte [gateway_bot_user_id], 0
    jne .fail
    cmp qword [channel_reset_calls], 2
    jne .fail
    mov dword [failure_stage], 81
    lea rdi, [cached_guild_id]
    mov esi, cached_guild_id_len
    call gateway_guild_name_get
    test rax, rax
    jnz .fail
    test edx, edx
    jnz .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; READY registration seam. REST construction is covered by discord_rest_vector;
; this vector only asserts routing and one-shot lifecycle behavior.
discord_register_application_commands:
    inc qword [command_registration_calls]
    xor eax, eax
    ret

; Auth cache seam: reset happens once for a process-start state reset.
guild_auth_reset:
    inc qword [auth_reset_calls]
    ret

channel_auth_reset:
    inc qword [channel_reset_calls]
    ret

; Auth cache seam: complete GUILD_CREATE frame is routed separately from messages.
guild_auth_cache_guild_create:
    cmp rsi, guild_create_frame_len
    jne .bad
    lea r8, [guild_create_frame]
    mov r9d, guild_create_frame_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [auth_cache_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

channel_auth_cache_guild_create:
    cmp rsi, guild_create_frame_len
    jne .bad
    lea r8, [guild_create_frame]
    mov r9d, guild_create_frame_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [channel_cache_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

lifecycle_member_add:
    cmp rsi, member_add_frame_len
    jne .bad
    lea r8, [member_add_frame]
    mov r9d, member_add_frame_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [member_add_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

lifecycle_member_remove:
    cmp rsi, member_remove_frame_len
    jne .bad
    lea r8, [member_remove_frame]
    mov r9d, member_remove_frame_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [member_remove_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

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

; Interaction seam: verifies the complete typed Gateway frame reaches only
; the interaction handler, never message dispatch.
interaction_handle_gateway:
    cmp rsi, interaction_frame_len
    jne .bad
    lea r8, [interaction_frame]
    mov r9d, interaction_frame_len
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc qword [interaction_calls]
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

; RDI=uptime ASCII buffer, ESI=len. AL=1 for '<digits>d <digits>h <digits>m <digits>s'.
uptime_shape_valid:
    xor ecx, ecx
    xor edx, edx
.digits:
    cmp ecx, esi
    jae .no
    mov al, [rdi + rcx]
    cmp al, '0'
    jb .suffix
    cmp al, '9'
    ja .suffix
    mov edx, 1
    inc ecx
    jmp .digits
.suffix:
    test edx, edx
    jz .no
    cmp al, 'd'
    je .day
    cmp al, 'h'
    je .hour
    cmp al, 'm'
    je .minute
    cmp al, 's'
    je .second
    jmp .no
.day:
    cmp ecx, esi
    jae .no
    cmp byte [rdi + rcx + 1], ' '
    jne .no
    add ecx, 2
    xor edx, edx
    jmp .digits
.hour:
    cmp ecx, esi
    jae .no
    cmp byte [rdi + rcx + 1], ' '
    jne .no
    add ecx, 2
    xor edx, edx
    jmp .digits
.minute:
    cmp ecx, esi
    jae .no
    cmp byte [rdi + rcx + 1], ' '
    jne .no
    add ecx, 2
    xor edx, edx
    jmp .digits
.second:
    inc ecx
    cmp ecx, esi
    jne .no
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
ready_frame: db '{"op":0,"s":42,"t":"READY","d":{"session_id":"session-1","resume_gateway_url":"wss://resume.example/?v=10&encoding=json","user":{"id":"9001"}}}'
ready_frame_len equ $ - ready_frame
bot_user_id: db '9001'
bot_user_id_len equ $ - bot_user_id
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
interaction_frame: db '{"op":0,"s":431,"t":"INTERACTION_CREATE","d":{"id":"112233445566778899","token":"abc_DEF-123.token","type":2,"data":{"id":"1","name":"info","type":1}}}'
interaction_frame_len equ $ - interaction_frame
reconnect_frame: db '{"op":7,"d":null}'
reconnect_frame_len equ $ - reconnect_frame
guild_create_frame: db '{"op":0,"s":44,"t":"GUILD_CREATE","d":{"id":"1001","name":"Guild \"A\"","member_count":42,"owner_id":"9001","roles":[]}}'
guild_create_frame_len equ $ - guild_create_frame
guild_delete_frame: db '{"op":0,"s":441,"t":"GUILD_DELETE","d":{"id":"1001"}}'
guild_delete_frame_len equ $ - guild_delete_frame
cached_guild_id: db '1001'
cached_guild_id_len equ $ - cached_guild_id
cached_guild_name: db 'Guild "A"'
cached_guild_name_len equ $ - cached_guild_name
missing_guild_id: db '1002'
missing_guild_id_len equ $ - missing_guild_id
member_add_frame: db '{"op":0,"s":45,"t":"GUILD_MEMBER_ADD","d":{"guild_id":"1001","user":{"id":"2001","username":"Alice"}}}'
member_add_frame_len equ $ - member_add_frame
member_remove_frame: db '{"op":0,"s":46,"t":"GUILD_MEMBER_REMOVE","d":{"guild_id":"1001","user":{"id":"2001","username":"Alice"}}}'
member_remove_frame_len equ $ - member_remove_frame
identify_payload: db '{"op":2,"d":{"token":"token-value","intents":37379,"properties":{"os":"linux","browser":"caine-asm","device":"caine-asm"}}}'
identify_payload_len equ $ - identify_payload
heartbeat_payload: db '{"op":1,"d":42}'
heartbeat_payload_len equ $ - heartbeat_payload
resume_payload: db '{"op":6,"d":{"token":"token-value","session_id":"session-1","seq":42}}'
resume_payload_len equ $ - resume_payload

section .bss
uptime_output: resb 64

section .data
discord_token_ptr: dq 0
discord_token_len: dd 0
expected_payload_ptr: dq 0
expected_payload_len: dd 0
send_calls: dq 0
dispatch_calls: dq 0
interaction_calls: dq 0
command_registration_calls: dq 0
auth_reset_calls: dq 0
auth_cache_calls: dq 0
channel_cache_calls: dq 0
channel_reset_calls: dq 0
member_add_calls: dq 0
member_remove_calls: dq 0
failure_stage: dd 0

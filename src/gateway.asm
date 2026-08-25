BITS 64
DEFAULT REL

global gateway_run

extern secure_gateway_connect
extern secure_gateway_send_text
extern secure_gateway_recv_text
extern secure_gateway_close
extern discord_token_ptr
extern discord_token_len

%define SYS_NANOSLEEP 35

section .text

gateway_run:
    lea rdi, [gateway_url]
    call secure_gateway_connect
    test eax, eax
    jnz .failure
    mov byte [identified], 0
    mov dword [heartbeat_ms], 45000
    mov qword [sequence], 0
    mov byte [has_sequence], 0
.loop:
    lea rdi, [gateway_buffer]
    mov esi, 16384
    lea rdx, [gateway_length]
    call secure_gateway_recv_text
    test rax, rax
    js .wait
    test rax, rax
    jz .wait
    mov rsi, [gateway_length]
    lea rdi, [gateway_buffer]
    call gateway_extract_opcode
    cmp eax, 10
    je .hello
    cmp eax, 1
    je .heartbeat_now
    cmp eax, 7
    je .reconnect
    cmp eax, 9
    je .reconnect
    jmp .loop
.hello:
    lea rdi, [gateway_buffer]
    mov rsi, [gateway_length]
    call gateway_extract_heartbeat_ms
    test eax, eax
    jz .loop
    mov [heartbeat_ms], eax
    call gateway_send_identify
    test eax, eax
    jnz .failure
    mov byte [identified], 1
    jmp .loop
.heartbeat_now:
    call gateway_send_heartbeat
    jmp .loop
.reconnect:
    call secure_gateway_close
    lea rdi, [reconnect_pause]
    xor rsi, rsi
    mov eax, SYS_NANOSLEEP
    syscall
    lea rdi, [gateway_url]
    call secure_gateway_connect
    test eax, eax
    jnz .failure
    mov byte [identified], 0
    jmp .loop
.wait:
    lea rdi, [receive_pause]
    xor rsi, rsi
    mov eax, SYS_NANOSLEEP
    syscall
    jmp .loop
.failure:
    mov eax, 69
    ret

; Build and send the minimal Discord Gateway Identify payload.
gateway_send_identify:
    push r12
    mov r12, [discord_token_ptr]
    mov ecx, [discord_token_len]
    mov eax, ecx
    add eax, identify_prefix_len + identify_suffix_len
    cmp eax, 4096
    ja .bad
    lea rdi, [outbound_buffer]
    lea rsi, [identify_prefix]
    mov edx, identify_prefix_len
    call copy_bytes
    lea rdi, [outbound_buffer + identify_prefix_len]
    mov rsi, r12
    mov edx, ecx
    call copy_bytes
    lea rdi, [outbound_buffer + identify_prefix_len]
    add rdi, rcx
    lea rsi, [identify_suffix]
    mov edx, identify_suffix_len
    call copy_bytes
    lea rdi, [outbound_buffer]
    mov esi, [discord_token_len]
    add esi, identify_prefix_len + identify_suffix_len
    call secure_gateway_send_text
    test rax, rax
    js .bad
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r12
    ret

gateway_send_heartbeat:
    lea rdi, [outbound_buffer]
    lea rsi, [heartbeat_null]
    mov edx, heartbeat_null_len
    call copy_bytes
    lea rdi, [outbound_buffer]
    mov esi, heartbeat_null_len
    call secure_gateway_send_text
    test rax, rax
    js .bad
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; rdi=JSON, rsi=len. EAX=opcode, -1 absent.
gateway_extract_opcode:
    lea rdx, [op_key]
    mov ecx, op_key_len
    call find_key
    test rax, rax
    jz .bad
    add rax, op_key_len
    mov rdi, rax
    mov esi, 3
    call parse_decimal
    ret
.bad:
    mov eax, -1
    ret

; rdi=JSON, rsi=len. EAX=heartbeat milliseconds, 0 absent.
gateway_extract_heartbeat_ms:
    lea rdx, [heartbeat_key]
    mov ecx, heartbeat_key_len
    call find_key
    test rax, rax
    jz .bad
    add rax, heartbeat_key_len
    mov rdi, rax
    mov esi, 9
    call parse_decimal
    ret
.bad:
    xor eax, eax
    ret

; rdi=json, rsi=json len, rdx=key, rcx=key len. RAX=location or zero.
find_key:
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
.scan:
    cmp r13, rcx
    jb .none
    xor r8d, r8d
.equal:
    cmp r8, rcx
    jae .found
    mov al, [r12 + r8]
    cmp al, [rdx + r8]
    jne .next
    inc r8
    jmp .equal
.next:
    inc r12
    dec r13
    jmp .scan
.found:
    mov rax, r12
    jmp .out
.none:
    xor eax, eax
.out:
    pop r13
    pop r12
    ret

; rdi=decimal pointer, esi=max digits. EAX=value, 0 when none.
parse_decimal:
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    movzx edx, byte [rdi + rcx]
    sub dl, '0'
    cmp dl, 9
    ja .done
    imul eax, eax, 10
    movzx edx, dl
    add eax, edx
    inc ecx
    jmp .loop
.done:
    test ecx, ecx
    jnz .return
    xor eax, eax
.return:
    ret

; rdi=destination, rsi=source, edx=count.
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
gateway_url: db 'wss://gateway.discord.gg/?v=10&encoding=json',0
op_key: db '"op":'
op_key_len equ $ - op_key
heartbeat_key: db '"heartbeat_interval":'
heartbeat_key_len equ $ - heartbeat_key
identify_prefix: db '{"op":2,"d":{"token":"'
identify_prefix_len equ $ - identify_prefix
identify_suffix: db '","intents":37379,"properties":{"os":"linux","browser":"caine-asm","device":"caine-asm"}}}'
identify_suffix_len equ $ - identify_suffix
heartbeat_null: db '{"op":1,"d":null}'
heartbeat_null_len equ $ - heartbeat_null
receive_pause: dq 0, 50000000
reconnect_pause: dq 2, 0

section .data
heartbeat_ms: dd 45000
identified: db 0
has_sequence: db 0
sequence: dq 0
gateway_length: dq 0

section .bss
gateway_buffer: resb 16384
outbound_buffer: resb 4096

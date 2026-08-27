DEFAULT REL

global interaction_handle_gateway

extern json_find_key
extern json_read_string
extern json_read_uint
extern json_object_end
extern discord_interaction_respond_text

%define FRAME_ID_CAP 64
%define TOKEN_CAP 192
%define NAME_CAP 64
%define EPHEMERAL_FLAG 64

section .text

; RDI=full Gateway INTERACTION_CREATE frame, RSI=len. EAX=0 handled/ignored,
; -1 only when a matched callback cannot be delivered. All parsing is bounded;
; the one-time interaction token stays in fixed BSS and is never persisted.
interaction_handle_gateway:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .ignored
    test r13, r13
    jle .ignored
    ; Never parse a partial frame: exactly one complete root object is required.
    mov rdi, r12
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .ignored
    lea rdx, [r12 + r13]
    cmp rax, rdx
    jne .ignored

    ; The payload `d` must be a complete object in the received frame.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_data]
    mov ecx, key_data_len
    call json_find_key
    test rax, rax
    jz .ignored
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .ignored
    mov r14, rax

    ; Only APPLICATION_COMMAND (type 2) is handled here. The type value must
    ; precede the nested command data in the top-level interaction payload.
    mov rdi, rbx
    mov rsi, r14
    sub rsi, rbx
    lea rdx, [key_type]
    mov ecx, key_type_len
    call json_find_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    call json_read_uint
    jc .ignored
    cmp eax, 2
    jne .ignored

    ; Interaction ID and token occur at the interaction payload object level.
    mov rdi, rbx
    mov rsi, r14
    sub rsi, rbx
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_id]
    mov ecx, FRAME_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .ignored
    mov [interaction_id_len], eax
    mov byte [interaction_id + rax], 0

    mov rdi, rbx
    mov rsi, r14
    sub rsi, rbx
    lea rdx, [key_token]
    mov ecx, key_token_len
    call json_find_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_token]
    mov ecx, TOKEN_CAP - 1
    call json_read_string
    test eax, eax
    jle .ignored
    mov [interaction_token_len], eax
    mov byte [interaction_token + rax], 0

    mov rdi, rbx
    mov rsi, r14
    sub rsi, rbx
    lea rdx, [key_command_data]
    mov ecx, key_command_data_len
    call json_find_key
    test rax, rax
    jz .ignored
    mov r15, rax
    mov rdi, r15
    mov rsi, r14
    call json_object_end
    test rax, rax
    jz .ignored
    mov r14, rax
    mov rdi, r15
    mov rsi, r14
    sub rsi, r15
    lea rdx, [key_name]
    mov ecx, key_name_len
    call json_find_key
    test rax, rax
    jz .ignored
    mov rdi, rax
    mov rsi, r14
    lea rdx, [interaction_name]
    mov ecx, NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .ignored
    mov [interaction_name_len], eax

    lea rdi, [interaction_name]
    mov esi, [interaction_name_len]
    lea rdx, [name_info]
    mov ecx, name_info_len
    call equal_literal
    test al, al
    jnz .info
    lea rdi, [interaction_name]
    mov esi, [interaction_name_len]
    lea rdx, [name_help]
    mov ecx, name_help_len
    call equal_literal
    test al, al
    jnz .help
    jmp .ignored
.info:
    lea r8, [info_response]
    mov r9d, info_response_len
    jmp .respond
.help:
    lea r8, [help_response]
    mov r9d, help_response_len
.respond:
    lea rdi, [interaction_id]
    mov esi, [interaction_id_len]
    lea rdx, [interaction_token]
    mov ecx, [interaction_token_len]
    mov eax, EPHEMERAL_FLAG
    call discord_interaction_respond_text
    jmp .out
.ignored:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI bytes, ESI len, RDX literal, ECX literal len. AL=1 exact.
equal_literal:
    cmp esi, ecx
    jne .no
    xor eax, eax
.loop:
    cmp eax, ecx
    jae .yes
    mov r8b, [rdi + rax]
    cmp r8b, [rdx + rax]
    jne .no
    inc eax
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

section .rodata
key_data: db 'd'
key_data_len equ $ - key_data
key_command_data: db 'data'
key_command_data_len equ $ - key_command_data
key_id: db 'id'
key_id_len equ $ - key_id
key_type: db 'type'
key_type_len equ $ - key_type
key_token: db 'token'
key_token_len equ $ - key_token
key_name: db 'name'
key_name_len equ $ - key_name
name_info: db 'info'
name_info_len equ $ - name_info
name_help: db 'help'
name_help_len equ $ - name_help
info_response: db 'Caine — AI Discord Bot. Status: Online. Default model: Llama 3.3 70B.'
info_response_len equ $ - info_response
help_response: db 'Caine commands: chat via prefix or mention; moderation, AFK, leveling, configuration, /info, and /help.'
help_response_len equ $ - help_response

section .bss
interaction_id: resb FRAME_ID_CAP
interaction_id_len: resd 1
interaction_token: resb TOKEN_CAP
interaction_token_len: resd 1
interaction_name: resb NAME_CAP
interaction_name_len: resd 1

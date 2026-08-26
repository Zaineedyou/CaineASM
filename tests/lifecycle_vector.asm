BITS 64
DEFAULT REL

extern lifecycle_member_add
extern lifecycle_member_remove

global _start
global guild_config_get
global discord_send_text

%define SYS_EXIT 60

section .text
_start:
    mov dword [failure_stage], 1
    mov dword [mode], 1
    lea rax, [welcome_expected]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], welcome_expected_len
    lea rdi, [member_add_event]
    mov esi, member_add_event_len
    call lifecycle_member_add
    mov dword [failure_stage], 2
    test eax, eax
    jnz .fail
    cmp dword [send_calls], 1
    jne .fail

    mov dword [mode], 2
    lea rax, [goodbye_expected]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], goodbye_expected_len
    lea rdi, [member_remove_event]
    mov esi, member_remove_event_len
    call lifecycle_member_remove
    test eax, eax
    jnz .fail
    cmp dword [send_calls], 2
    jne .fail

    ; Missing configured destination performs no send and is not an error.
    mov dword [mode], 3
    lea rdi, [member_add_event]
    mov esi, member_add_event_len
    call lifecycle_member_add
    test eax, eax
    jnz .fail
    cmp dword [send_calls], 2
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; RDI=guild, ESI=len, RDX=setting, ECX=len. RAX=value, EDX=len.
guild_config_get:
    cmp dword [mode], 3
    je .missing
    cmp dword [mode], 1
    jne .goodbye
    cmp ecx, welcome_channel_len
    jne .welcome_message
    lea rax, [welcome_channel]
    mov edx, welcome_channel_value_len
    ret
.welcome_message:
    cmp ecx, welcome_message_len
    jne .missing
    lea rax, [welcome_template]
    mov edx, welcome_template_len
    ret
.goodbye:
    cmp ecx, goodbye_channel_len
    jne .goodbye_message
    lea rax, [goodbye_channel]
    mov edx, goodbye_channel_value_len
    ret
.goodbye_message:
    ; Explicit miss selects lifecycle's source fallback template.
.missing:
    xor eax, eax
    xor edx, edx
    ret

; RDI=channel ESI=len RDX=text ECX=len.
discord_send_text:
    cmp dword [mode], 1
    jne .goodbye
    cmp esi, welcome_channel_value_len
    jne .bad
    lea r8, [welcome_channel]
    jmp .channel
.goodbye:
    cmp esi, goodbye_channel_value_len
    jne .bad
    lea r8, [goodbye_channel]
.channel:
    mov r9d, ecx
    mov r10, rdx
    mov edx, esi
    mov rsi, r8
    call equal_bytes
    test al, al
    jz .bad
    cmp r9d, [expected_text_len]
    jne .bad
    mov rdi, r10
    mov rsi, [expected_text_ptr]
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc dword [send_calls]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI/RSI, EDX len. AL=1 iff equal.
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
member_add_event: db '{"op":0,"t":"GUILD_MEMBER_ADD","d":{"guild_id":"g1","user":{"id":"u1","username":"Alice"}}}'
member_add_event_len equ $ - member_add_event
member_remove_event: db '{"op":0,"t":"GUILD_MEMBER_REMOVE","d":{"guild_id":"g1","user":{"id":"u1","username":"Alice"}}}'
member_remove_event_len equ $ - member_remove_event
welcome_channel: db 'chan-w'
welcome_channel_value_len equ $ - welcome_channel
goodbye_channel: db 'chan-g'
goodbye_channel_value_len equ $ - goodbye_channel
welcome_channel_len equ 15
goodbye_channel_len equ 15
welcome_message_len equ 11
welcome_template: db 'Hi {user} {username} {server} {count}'
welcome_template_len equ $ - welcome_template
welcome_expected: db 'Hi <@u1> Alice this server ?'
welcome_expected_len equ $ - welcome_expected
goodbye_expected: db 'Selamat tinggal **Alice** dari **this server**.'
goodbye_expected_len equ $ - goodbye_expected

section .data
mode: dd 0
send_calls: dd 0
expected_text_ptr: dq 0
expected_text_len: dd 0
failure_stage: dd 0

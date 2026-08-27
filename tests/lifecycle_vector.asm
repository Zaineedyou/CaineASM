BITS 64
DEFAULT REL

extern lifecycle_member_add
extern lifecycle_member_remove

global _start
global guild_config_get
global discord_send_text
global discord_add_member_role
global gateway_guild_name_get
global gateway_guild_member_count_get

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
    cmp dword [role_calls], 1
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

    ; A cache miss mirrors source State fallback: blank server name and zero
    ; members, without failing configured lifecycle delivery.
    mov dword [failure_stage], 4
    mov dword [mode], 1
    mov dword [cache_available], 0
    lea rax, [welcome_cache_miss_expected]
    mov [expected_text_ptr], rax
    mov dword [expected_text_len], welcome_cache_miss_expected_len
    lea rdi, [member_add_event]
    mov esi, member_add_event_len
    call lifecycle_member_add
    test eax, eax
    jnz .fail
    cmp dword [send_calls], 3
    jne .fail
    cmp dword [role_calls], 2
    jne .fail
    mov dword [cache_available], 1

    ; Missing configured destination performs no send and is not an error.
    mov dword [mode], 3
    lea rdi, [member_add_event]
    mov esi, member_add_event_len
    call lifecycle_member_add
    test eax, eax
    jnz .fail
    cmp dword [send_calls], 3
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; RDI=guild, ESI=len. RAX=name and EDX=len from the fixed Gateway cache seam.
gateway_guild_name_get:
    cmp dword [cache_available], 1
    jne .miss
    cmp esi, guild_id_len
    jne .miss
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .miss
    lea rax, [cached_guild_name]
    mov edx, cached_guild_name_len
    ret
.miss:
    xor eax, eax
    xor edx, edx
    ret

; RDI=guild, ESI=len. EAX=count and CF=0 on cache hit; CF=1 on miss.
gateway_guild_member_count_get:
    cmp dword [cache_available], 1
    jne .miss
    cmp esi, guild_id_len
    jne .miss
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .miss
    mov eax, 42
    clc
    ret
.miss:
    xor eax, eax
    stc
    ret

; RDI=guild, ESI=len, RDX=setting, ECX=len. RAX=value, EDX=len.
guild_config_get:
    cmp dword [mode], 3
    je .missing
    cmp dword [mode], 1
    jne .goodbye
    cmp ecx, auto_role_setting_len
    jne .welcome_channel_query
    lea rax, [auto_role]
    mov edx, auto_role_len
    ret
.welcome_channel_query:
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

; RDI=guild ESI=len RDX=user ECX=len R8=role R9D=len.
discord_add_member_role:
    push rbx
    push r12
    push r13
    mov rbx, rdx
    mov r12, r8
    mov r13d, r9d
    mov r11d, ecx
    cmp esi, guild_id_len
    jne .bad
    lea rsi, [guild_id]
    mov edx, guild_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r11d, user_id_len
    jne .bad
    mov rdi, rbx
    lea rsi, [user_id]
    mov edx, user_id_len
    call equal_bytes
    test al, al
    jz .bad
    cmp r13d, auto_role_len
    jne .bad
    mov rdi, r12
    lea rsi, [auto_role]
    mov edx, auto_role_len
    call equal_bytes
    test al, al
    jz .bad
    inc dword [role_calls]
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r13
    pop r12
    pop rbx
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
auto_role_setting_len equ 9
auto_role: db '99'
auto_role_len equ $ - auto_role
guild_id: db 'g1'
guild_id_len equ $ - guild_id
user_id: db 'u1'
user_id_len equ $ - user_id
goodbye_channel_len equ 15
welcome_message_len equ 11
welcome_template: db 'Hi {user} {username} {server} {count}'
welcome_template_len equ $ - welcome_template
cached_guild_name: db 'Guild Cache'
cached_guild_name_len equ $ - cached_guild_name
welcome_expected: db 'Hi <@u1> Alice Guild Cache 42'
welcome_expected_len equ $ - welcome_expected
goodbye_expected: db 'Selamat tinggal **Alice** dari **Guild Cache**. ', 0xf0, 0x9f, 0x91, 0x8b
goodbye_expected_len equ $ - goodbye_expected
welcome_cache_miss_expected: db 'Hi <@u1> Alice  0'
welcome_cache_miss_expected_len equ $ - welcome_cache_miss_expected

section .data
mode: dd 0
cache_available: dd 1
send_calls: dd 0
role_calls: dd 0
expected_text_ptr: dq 0
expected_text_len: dd 0
failure_stage: dd 0

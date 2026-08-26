BITS 64
DEFAULT REL

; Fixed-capacity Discord channel permission-overwrite cache. This module keeps
; authorization policy in NASM; it has no transport, heap, polling, or dynamic
; allocation. Unknown channels/roles/overwrites fail closed at the resolver.

global channel_auth_reset
global channel_auth_cache_channel
global channel_auth_cache_overwrite
global channel_auth_resolve
global channel_auth_cache_guild_create

extern json_array_end
extern json_object_end
extern json_find_key
extern json_read_string
extern json_read_uint
extern guild_auth_roles_permissions

%define ID_CAP 64
%define CHANNEL_SLOT_COUNT 64
%define CHANNEL_SLOT_SIZE 152
%define OVERWRITE_SLOT_COUNT 256
%define OVERWRITE_SLOT_SIZE 224
%define TYPE_ROLE 0
%define TYPE_MEMBER 1
%define PERMISSION_ADMINISTRATOR 8

section .text

; Clear all bounded channel/overwrite entries.
channel_auth_reset:
    xor eax, eax
    mov ecx, CHANNEL_SLOT_COUNT * CHANNEL_SLOT_SIZE + OVERWRITE_SLOT_COUNT * OVERWRITE_SLOT_SIZE
    lea rdi, [channel_slots]
.clear:
    cmp eax, ecx
    jae .done
    mov byte [rdi + rax], 0
    inc eax
    jmp .clear
.done:
    ret

; RDI=guild, ESI=guild len, RDX=channel, ECX=channel len. EAX=0 or -1.
channel_auth_cache_channel:
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
    jle .bad
    test r15d, r15d
    jle .bad
    cmp r13d, ID_CAP - 1
    ja .bad
    cmp r15d, ID_CAP - 1
    ja .bad
    call find_channel_slot
    test rax, rax
    jz .bad
    mov r11, rax
    mov byte [r11], 1
    mov [r11 + 4], r13d
    mov [r11 + 8], r15d
    lea rdi, [r11 + 16]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [r11 + 16 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=channel, ECX=channel len, R8=target ID,
; R9D=target len. Stack [RSP+8]=type (0 role, 1 member), +16=allow u64,
; +24=deny u64. EAX=0 or -1. The channel must first be recorded as known.
channel_auth_cache_overwrite:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rbx, r8
    mov eax, [rsp + 48]
    mov [input_type], eax
    mov rax, [rsp + 56]
    mov [input_allow], rax
    mov rax, [rsp + 64]
    mov [input_deny], rax
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    test rbx, rbx
    jz .bad
    test r13d, r13d
    jle .bad
    test r15d, r15d
    jle .bad
    test r9d, r9d
    jle .bad
    cmp r13d, ID_CAP - 1
    ja .bad
    cmp r15d, ID_CAP - 1
    ja .bad
    cmp r9d, ID_CAP - 1
    ja .bad
    cmp dword [input_type], TYPE_MEMBER
    ja .bad
    mov [input_target_len], r9d
    call find_existing_channel
    test rax, rax
    jz .bad
    call find_overwrite_slot
    test rax, rax
    jz .bad
    mov r11, rax
    mov byte [r11], 1
    mov eax, [input_type]
    mov [r11 + 1], al
    mov [r11 + 4], r13d
    mov [r11 + 8], r15d
    mov eax, [input_target_len]
    mov [r11 + 12], eax
    mov rax, [input_allow]
    mov [r11 + 16], rax
    mov rax, [input_deny]
    mov [r11 + 24], rax
    lea rdi, [r11 + 32]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [r11 + 32 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    lea rdi, [r11 + 32 + ID_CAP + ID_CAP]
    mov rsi, rbx
    mov edx, [input_target_len]
    call copy_bytes
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

; RDI=guild, ESI=guild len, RDX=channel, ECX=channel len, R8=member ID,
; R9D=member len. Stack [RSP+8]=member roles JSON pointer, +16=roles len.
; RAX=effective permission bitset, or -1 if channel state/roles are incomplete.
; Discord order: base role union, @everyone overwrite, role overwrites, member.
channel_auth_resolve:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rbx, r8
    mov [resolve_guild_ptr], r12
    mov [resolve_guild_len], r13d
    mov [resolve_channel_ptr], r14
    mov [resolve_channel_len], r15d
    mov eax, [rsp + 48]
    mov [resolve_roles_ptr], rax
    mov eax, [rsp + 56]
    mov [resolve_roles_len], eax
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    test rbx, rbx
    jz .bad
    test r13d, r13d
    jle .bad
    test r15d, r15d
    jle .bad
    test r9d, r9d
    jle .bad
    cmp r9d, ID_CAP - 1
    ja .bad
    mov [resolve_member_len], r9d
    call find_existing_channel
    test rax, rax
    jz .bad
    mov rdi, r12
    mov esi, r13d
    mov rdx, [resolve_roles_ptr]
    mov ecx, [resolve_roles_len]
    call guild_auth_roles_permissions
    test rax, rax
    js .bad
    mov [resolve_permissions], rax
    test rax, PERMISSION_ADMINISTRATOR
    jnz .done
    ; @everyone overwrite is a role overwrite whose target ID equals guild ID.
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    mov r8, r12
    mov r9d, r13d
    mov eax, TYPE_ROLE
    push rax
    call find_overwrite_exact
    add rsp, 8
    test rax, rax
    jz .role_union
    mov rdx, [rax + 24]
    not rdx
    and [resolve_permissions], rdx
    mov rdx, [rax + 16]
    or [resolve_permissions], rdx
.role_union:
    mov qword [resolve_role_allow], 0
    mov qword [resolve_role_deny], 0
    mov rdi, [resolve_roles_ptr]
    mov esi, [resolve_roles_len]
    call collect_role_overwrites
    test eax, eax
    js .bad
    mov rax, [resolve_role_deny]
    not rax
    and [resolve_permissions], rax
    mov rax, [resolve_role_allow]
    or [resolve_permissions], rax
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    mov r8, rbx
    mov r9d, [resolve_member_len]
    mov eax, TYPE_MEMBER
    push rax
    call find_overwrite_exact
    add rsp, 8
    test rax, rax
    jz .done
    mov rdx, [rax + 24]
    not rdx
    and [resolve_permissions], rdx
    mov rdx, [rax + 16]
    or [resolve_permissions], rdx
.done:
    mov rax, [resolve_permissions]
    jmp .out
.bad:
    mov rax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=roles array, ESI=len. EAX=0 or -1. Uses current resolver guild/channel.
collect_role_overwrites:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    test r12, r12
    jz .bad
    test r13d, r13d
    jle .bad
    lea rax, [r12 + r13]
    mov [resolve_roles_end], rax
    mov rdi, r12
    mov rsi, rax
    call json_array_end
    test rax, rax
    jz .bad
    cmp rax, [resolve_roles_end]
    jne .bad
    lea r15, [r12 + 1]
.loop:
    mov r11, [resolve_roles_end]
    dec r11
    cmp r15, r11
    jae .done
    mov al, [r15]
    cmp al, ' '
    je .advance
    cmp al, 9
    je .advance
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    cmp al, ','
    je .advance
    cmp al, '"'
    jne .bad
    mov rdi, r15
    mov rsi, [resolve_roles_end]
    lea rdx, [resolve_role_id]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov r15, rdx
    mov r14d, eax
    mov rbx, r15
    mov rdi, [resolve_guild_ptr]
    mov esi, [resolve_guild_len]
    mov rdx, [resolve_channel_ptr]
    mov ecx, [resolve_channel_len]
    lea r8, [resolve_role_id]
    mov r9d, r14d
    mov eax, TYPE_ROLE
    push rax
    call find_overwrite_exact
    add rsp, 8
    mov r15, rbx
    test rax, rax
    jz .loop
    mov rdx, [rax + 16]
    or [resolve_role_allow], rdx
    mov rdx, [rax + 24]
    or [resolve_role_deny], rdx
    jmp .loop
.advance:
    inc r15
    jmp .loop
.done:
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

; RDI=guild, ESI=guild len. Clears all fixed channel/overwrite records for one guild.
channel_auth_clear_guild:
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    xor r10d, r10d
.channel_loop:
    cmp r10d, CHANNEL_SLOT_COUNT
    jae .overwrite_start
    imul rax, r10, CHANNEL_SLOT_SIZE
    lea r9, [channel_slots + rax]
    cmp byte [r9], 1
    jne .channel_next
    cmp r13d, [r9 + 4]
    jne .channel_next
    lea rdi, [r9 + 16]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .channel_next
    mov byte [r9], 0
.channel_next:
    inc r10d
    jmp .channel_loop
.overwrite_start:
    xor r10d, r10d
.overwrite_loop:
    cmp r10d, OVERWRITE_SLOT_COUNT
    jae .out
    imul rax, r10, OVERWRITE_SLOT_SIZE
    lea r9, [overwrite_slots + rax]
    cmp byte [r9], 1
    jne .overwrite_next
    cmp r13d, [r9 + 4]
    jne .overwrite_next
    lea rdi, [r9 + 32]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .overwrite_next
    mov byte [r9], 0
.overwrite_next:
    inc r10d
    jmp .overwrite_loop
.out:
    pop r13
    pop r12
    ret

; RDI=full GUILD_CREATE Gateway frame, RSI=len. EAX=0 on complete bounded
; channel snapshot, -1 otherwise. A failure clears the affected guild cache.
channel_auth_cache_guild_create:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .bad
    test r13, r13
    jz .bad
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_data]
    mov ecx, key_data_len
    call json_find_key
    test rax, rax
    jz .bad
    cmp byte [rax], '{'
    jne .bad
    mov r14, rax
    mov rdi, r14
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .bad
    mov r15, rax
    mov rdi, r14
    mov rsi, r15
    sub rsi, rdi
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, r15
    lea rdx, [snapshot_guild]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [snapshot_guild_len], eax
    mov rdi, r14
    mov rsi, r15
    sub rsi, rdi
    lea rdx, [key_channels]
    mov ecx, key_channels_len
    call json_find_key
    test rax, rax
    jz .clear_bad
    cmp byte [rax], '['
    jne .clear_bad
    mov [snapshot_channels_start], rax
    mov rdi, rax
    mov rsi, r15
    call json_array_end
    test rax, rax
    jz .clear_bad
    cmp rax, r15
    ja .clear_bad
    mov [snapshot_channels_end], rax
    lea rdi, [snapshot_guild]
    mov esi, [snapshot_guild_len]
    call channel_auth_clear_guild
    mov rbx, [snapshot_channels_start]
    inc rbx
.channel_loop:
    mov rdi, rbx
    mov rsi, [snapshot_channels_end]
    call skip_delimiters
    mov rbx, rax
    mov r11, [snapshot_channels_end]
    dec r11
    cmp rbx, r11
    jae .done
    cmp byte [rbx], '{'
    jne .clear_bad
    mov rdi, rbx
    mov rsi, [snapshot_channels_end]
    call json_object_end
    test rax, rax
    jz .clear_bad
    mov [snapshot_channel_object_end], rax
    mov rdi, rbx
    mov rsi, rax
    sub rsi, rdi
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .clear_bad
    mov rdi, rax
    mov rsi, [snapshot_channel_object_end]
    lea rdx, [snapshot_channel]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .clear_bad
    mov [snapshot_channel_len], eax
    mov rdi, rbx
    mov rsi, [snapshot_channel_object_end]
    sub rsi, rdi
    lea rdx, [key_permission_overwrites]
    mov ecx, key_permission_overwrites_len
    call json_find_key
    test rax, rax
    jz .clear_bad
    cmp byte [rax], '['
    jne .clear_bad
    mov [snapshot_overwrites_start], rax
    mov rdi, rax
    mov rsi, [snapshot_channel_object_end]
    call json_array_end
    test rax, rax
    jz .clear_bad
    mov [snapshot_overwrites_end], rax
    lea rdi, [snapshot_guild]
    mov esi, [snapshot_guild_len]
    lea rdx, [snapshot_channel]
    mov ecx, [snapshot_channel_len]
    call channel_auth_cache_channel
    test eax, eax
    jnz .clear_bad
    mov r14, [snapshot_overwrites_start]
    inc r14
.overwrite_loop:
    mov rdi, r14
    mov rsi, [snapshot_overwrites_end]
    call skip_delimiters
    mov r14, rax
    mov r11, [snapshot_overwrites_end]
    dec r11
    cmp r14, r11
    jae .next_channel
    cmp byte [r14], '{'
    jne .clear_bad
    mov rdi, r14
    mov rsi, [snapshot_overwrites_end]
    call json_object_end
    test rax, rax
    jz .clear_bad
    mov [snapshot_overwrite_object_end], rax
    mov rdi, r14
    mov rsi, rax
    sub rsi, rdi
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .clear_bad
    mov rdi, rax
    mov rsi, [snapshot_overwrite_object_end]
    lea rdx, [snapshot_target]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .clear_bad
    mov [snapshot_target_len], eax
    mov rdi, r14
    mov rsi, [snapshot_overwrite_object_end]
    sub rsi, rdi
    lea rdx, [key_type]
    mov ecx, key_type_len
    call json_find_key
    test rax, rax
    jz .clear_bad
    mov rdi, rax
    mov rsi, [snapshot_overwrite_object_end]
    call json_read_uint
    jc .clear_bad
    cmp rax, TYPE_MEMBER
    ja .clear_bad
    mov [snapshot_type], eax
    mov rdi, r14
    mov rsi, [snapshot_overwrite_object_end]
    sub rsi, rdi
    lea rdx, [key_allow]
    mov ecx, key_allow_len
    call json_find_key
    test rax, rax
    jz .clear_bad
    mov rdi, rax
    mov rsi, [snapshot_overwrite_object_end]
    lea rdx, [snapshot_allow_text]
    mov ecx, 31
    call json_read_string
    test eax, eax
    jle .clear_bad
    lea rdi, [snapshot_allow_text]
    lea rsi, [snapshot_allow_text + rax]
    call json_read_uint
    jc .clear_bad
    mov [snapshot_allow], rax
    mov rdi, r14
    mov rsi, [snapshot_overwrite_object_end]
    sub rsi, rdi
    lea rdx, [key_deny]
    mov ecx, key_deny_len
    call json_find_key
    test rax, rax
    jz .clear_bad
    mov rdi, rax
    mov rsi, [snapshot_overwrite_object_end]
    lea rdx, [snapshot_deny_text]
    mov ecx, 31
    call json_read_string
    test eax, eax
    jle .clear_bad
    lea rdi, [snapshot_deny_text]
    lea rsi, [snapshot_deny_text + rax]
    call json_read_uint
    jc .clear_bad
    mov [snapshot_deny], rax
    mov rax, [snapshot_deny]
    push rax
    mov rax, [snapshot_allow]
    push rax
    mov eax, [snapshot_type]
    push rax
    lea rdi, [snapshot_guild]
    mov esi, [snapshot_guild_len]
    lea rdx, [snapshot_channel]
    mov ecx, [snapshot_channel_len]
    lea r8, [snapshot_target]
    mov r9d, [snapshot_target_len]
    call channel_auth_cache_overwrite
    add rsp, 24
    test eax, eax
    jnz .clear_bad
    mov r14, [snapshot_overwrite_object_end]
    jmp .overwrite_loop
.next_channel:
    mov rbx, [snapshot_channel_object_end]
    jmp .channel_loop
.done:
    xor eax, eax
    jmp .out
.clear_bad:
    lea rdi, [snapshot_guild]
    mov esi, [snapshot_guild_len]
    call channel_auth_clear_guild
.bad:
    call channel_auth_reset
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=cursor, RSI=exclusive array end. RAX=first non-delimiter cursor.
skip_delimiters:
    mov rax, rdi
.loop:
    cmp rax, rsi
    jae .done
    mov dl, [rax]
    cmp dl, ' '
    je .advance
    cmp dl, 9
    je .advance
    cmp dl, 10
    je .advance
    cmp dl, 13
    je .advance
    cmp dl, ','
    je .advance
    jmp .done
.advance:
    inc rax
    jmp .loop
.done:
    ret

; R12=guild, R13D=len, R14=channel, R15D=len. RAX=existing/unused channel slot.
find_channel_slot:
    xor r10d, r10d
    xor r8d, r8d
.loop:
    cmp r10d, CHANNEL_SLOT_COUNT
    jae .done
    imul rax, r10, CHANNEL_SLOT_SIZE
    lea r9, [channel_slots + rax]
    cmp byte [r9], 1
    jne .empty
    cmp r13d, [r9 + 4]
    jne .next
    lea rdi, [r9 + 16]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .next
    cmp r15d, [r9 + 8]
    jne .next
    lea rdi, [r9 + 16 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call equal_bytes
    test al, al
    jnz .found
.next:
    inc r10d
    jmp .loop
.empty:
    test r8, r8
    jnz .next
    mov r8, r9
    jmp .next
.done:
    mov rax, r8
    ret
.found:
    mov rax, r9
    ret

; R12=guild, R13D=len, R14=channel, R15D=len. RAX=existing channel or zero.
find_existing_channel:
    call find_channel_slot
    test rax, rax
    jz .out
    cmp byte [rax], 1
    je .out
    xor eax, eax
.out:
    ret

; Inputs in R12/R13/R14/R15, target R8/R9D, type EAX. RAX=entry or zero.
find_overwrite_exact:
    push rbx
    mov ebx, eax
    mov r12, [resolve_guild_ptr]
    mov r13d, [resolve_guild_len]
    mov r14, [resolve_channel_ptr]
    mov r15d, [resolve_channel_len]
    xor r10d, r10d
.loop:
    cmp r10d, OVERWRITE_SLOT_COUNT
    jae .missing
    imul rax, r10, OVERWRITE_SLOT_SIZE
    lea r11, [overwrite_slots + rax]
    cmp byte [r11], 1
    jne .next
    cmp bl, [r11 + 1]
    jne .next
    cmp r13d, [r11 + 4]
    jne .next
    cmp r15d, [r11 + 8]
    jne .next
    cmp r9d, [r11 + 12]
    jne .next
    lea rdi, [r11 + 32]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .next
    lea rdi, [r11 + 32 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call equal_bytes
    test al, al
    jz .next
    lea rdi, [r11 + 32 + ID_CAP + ID_CAP]
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .next
    mov rax, r11
    jmp .out
.next:
    inc r10d
    jmp .loop
.missing:
    xor eax, eax
.out:
    pop rbx
    ret

; Uses current cache inputs + input target/type. RAX=existing/unused overwrite.
find_overwrite_slot:
    xor r10d, r10d
    xor r8d, r8d
.loop:
    cmp r10d, OVERWRITE_SLOT_COUNT
    jae .done
    imul rax, r10, OVERWRITE_SLOT_SIZE
    lea r11, [overwrite_slots + rax]
    cmp byte [r11], 1
    jne .empty
    mov eax, [input_type]
    cmp al, [r11 + 1]
    jne .next
    cmp r13d, [r11 + 4]
    jne .next
    cmp r15d, [r11 + 8]
    jne .next
    mov eax, [input_target_len]
    cmp eax, [r11 + 12]
    jne .next
    lea rdi, [r11 + 32]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .next
    lea rdi, [r11 + 32 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call equal_bytes
    test al, al
    jz .next
    lea rdi, [r11 + 32 + ID_CAP + ID_CAP]
    mov rsi, rbx
    mov edx, [input_target_len]
    call equal_bytes
    test al, al
    jnz .found
.next:
    inc r10d
    jmp .loop
.empty:
    test r8, r8
    jnz .next
    mov r8, r11
    jmp .next
.done:
    mov rax, r8
    ret
.found:
    mov rax, r11
    ret

; RDI/RSI bytes, EDX len. AL=1 iff exactly equal.
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
key_data: db 'd'
key_data_len equ $ - key_data
key_id: db 'id'
key_id_len equ $ - key_id
key_channels: db 'channels'
key_channels_len equ $ - key_channels
key_permission_overwrites: db 'permission_overwrites'
key_permission_overwrites_len equ $ - key_permission_overwrites
key_type: db 'type'
key_type_len equ $ - key_type
key_allow: db 'allow'
key_allow_len equ $ - key_allow
key_deny: db 'deny'
key_deny_len equ $ - key_deny

section .data
input_type: dd 0
input_target_len: dd 0
input_allow: dq 0
input_deny: dq 0
resolve_roles_ptr: dq 0
resolve_roles_len: dd 0
resolve_roles_end: dq 0
resolve_member_len: dd 0
resolve_permissions: dq 0
resolve_role_allow: dq 0
resolve_role_deny: dq 0
resolve_role_id: times ID_CAP db 0
resolve_guild_ptr: dq 0
resolve_guild_len: dd 0
resolve_channel_ptr: dq 0
resolve_channel_len: dd 0
snapshot_guild_len: dd 0
snapshot_channel_len: dd 0
snapshot_target_len: dd 0
snapshot_type: dd 0
snapshot_allow: dq 0
snapshot_deny: dq 0
snapshot_channels_start: dq 0
snapshot_channels_end: dq 0
snapshot_channel_object_end: dq 0
snapshot_overwrites_start: dq 0
snapshot_overwrites_end: dq 0
snapshot_overwrite_object_end: dq 0

section .bss
channel_slots: resb CHANNEL_SLOT_COUNT * CHANNEL_SLOT_SIZE
overwrite_slots: resb OVERWRITE_SLOT_COUNT * OVERWRITE_SLOT_SIZE
snapshot_guild: resb ID_CAP
snapshot_channel: resb ID_CAP
snapshot_target: resb ID_CAP
snapshot_allow_text: resb 32
snapshot_deny_text: resb 32

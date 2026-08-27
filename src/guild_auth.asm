BITS 64
DEFAULT REL

global guild_auth_reset
global guild_auth_cache_owner
global guild_auth_cache_role
global guild_auth_cache_role_position
global guild_auth_role_position
global guild_auth_member_highest_position
global guild_auth_bot_above_member
global guild_auth_cache_bot_member
global guild_auth_bot_above_roles
global guild_auth_get_bot_roles
global guild_auth_bot_above_role
global guild_auth_is_owner
global guild_auth_is_manager
global guild_auth_roles_have
global guild_auth_roles_permissions
global guild_auth_cache_guild_create

extern json_find_key
extern json_object_end
extern json_array_end
extern json_read_string
extern json_read_uint
extern bot_owner_ptr
extern bot_owner_len
extern gateway_bot_user_id
extern gateway_bot_user_id_len

%define ID_CAP 64
%define OWNER_SLOT_COUNT 64
%define OWNER_SLOT_SIZE 144
%define ROLE_SLOT_COUNT 256
%define ROLE_SLOT_SIZE 160
%define BOT_MEMBER_SLOT_COUNT 64
%define BOT_MEMBER_SLOT_SIZE 1104
%define BOT_MEMBER_ROLES_CAP 1024
%define PERMISSION_ADMINISTRATOR 8

; Ephemeral authorization cache. It is populated from trusted Gateway guild
; state and is never persisted. Text-message role IDs are parsed directly in
; NASM. Channel overwrite resolution is intentionally a separate layer before
; destructive REST actions are enabled.

section .text

; Clear cached guild owner and role entries.
guild_auth_reset:
    xor eax, eax
    mov ecx, OWNER_SLOT_COUNT * OWNER_SLOT_SIZE + ROLE_SLOT_COUNT * ROLE_SLOT_SIZE + BOT_MEMBER_SLOT_COUNT * BOT_MEMBER_SLOT_SIZE
    lea rdi, [owner_slots]
.clear:
    cmp eax, ecx
    jae .done
    mov byte [rdi + rax], 0
    inc eax
    jmp .clear
.done:
    ret

; RDI=guild, ESI=guild len, RDX=owner, ECX=owner len. EAX=0 success, -1 invalid/full.
guild_auth_cache_owner:
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
    cmp r13d, ID_CAP - 1
    ja .bad
    cmp r15d, ID_CAP - 1
    ja .bad
    call find_owner_slot
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

; RDI=guild, ESI=guild len, RDX=role, ECX=role len, R8=permission bitset.
; EAX=0 success, -1 invalid/full.
guild_auth_cache_role:
    xor r9d, r9d
    jmp guild_auth_cache_role_position

guild_auth_cache_role_position:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov [cached_permission], r8
    mov [cached_position], r9d
    test r13d, r13d
    jz .bad
    test r15d, r15d
    jz .bad
    cmp r13d, ID_CAP - 1
    ja .bad
    cmp r15d, ID_CAP - 1
    ja .bad
    call find_role_slot
    test rax, rax
    jz .bad
    mov r11, rax
    mov byte [r11], 1
    mov [r11 + 4], r13d
    mov [r11 + 8], r15d
    mov r8, [cached_permission]
    mov [r11 + 16], r8
    mov eax, [cached_position]
    mov [r11 + 24], eax
    lea rdi, [r11 + 32]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [r11 + 32 + ID_CAP]
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

; RDI=guild, ESI=guild len, RDX=user, ECX=user len. AL=1 when the user
; matches BOT_OWNER_ID (if configured) or the trusted cached guild owner.
guild_auth_is_manager:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r14, r14
    jz .owner
    test r15d, r15d
    jz .owner
    mov eax, [bot_owner_len]
    test eax, eax
    jz .owner
    cmp eax, r15d
    jne .owner
    mov rdi, [bot_owner_ptr]
    test rdi, rdi
    jz .owner
    mov rsi, r14
    mov edx, r15d
    call equal_bytes
    test al, al
    jnz .out
.owner:
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call guild_auth_is_owner
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=user, ECX=user len. AL=1 only for cached owner.
guild_auth_is_owner:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r13d, r13d
    jz .no
    test r15d, r15d
    jz .no
    call find_existing_owner
    test rax, rax
    jz .no
    cmp r15d, [rax + 8]
    jne .no
    lea rdi, [rax + 16 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call equal_bytes
    jmp .out
.no:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=opening member roles JSON array, ECX=array len,
; R8=requested permission bitset. AL=1 iff cached @everyone and member roles
; include every requested bit, or include ADMINISTRATOR.
guild_auth_roles_have:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rbx, r8
    test r12, r12
    jz .no
    test r13d, r13d
    jz .no
    test r14, r14
    jz .no
    test r15d, r15d
    jle .no
    lea rax, [r14 + r15]
    mov [rsp], rax
    mov rdi, r14
    mov rsi, rax
    call json_array_end
    test rax, rax
    jz .no
    cmp rax, [rsp]
    jne .no
    ; @everyone role ID equals the guild ID.
    mov rdi, r12
    mov esi, r13d
    mov rdx, r12
    mov ecx, r13d
    call get_role_permissions
    mov [accumulated_permissions], rax
    lea r15, [r14 + 1]
.skip_ws:
    mov r11, [rsp]
    dec r11
    cmp r15, r11
    jae .finish
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
    jne .no
    mov rdi, r15
    mov rsi, [rsp]
    lea rdx, [role_id]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .no
    mov r15, rdx
    mov r10d, eax
    mov rdi, r12
    mov esi, r13d
    lea rdx, [role_id]
    mov ecx, r10d
    call get_role_permissions
    or [accumulated_permissions], rax
    jmp .skip_ws
.advance:
    inc r15
    jmp .skip_ws
.finish:
    mov rax, [accumulated_permissions]
    test rax, PERMISSION_ADMINISTRATOR
    jnz .yes
    mov rdx, rbx
    and rax, rdx
    cmp rax, rdx
    jne .no
.yes:
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=complete GUILD_CREATE Gateway frame, RSI=frame len. EAX=0 if owner and
; every bounded role record were cached, -1 for malformed/oversized input. A
; failure leaves no usable role state for the affected guild after clearing it.
guild_auth_cache_guild_create:
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
    mov r14, rax
    mov rdi, r14
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .bad
    mov r15, rax
    mov [snapshot_data_ptr], r14
    mov [snapshot_data_end], r15

    ; Cache guild ID and owner ID from the top-level guild payload.
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
    lea rdx, [key_owner_id]
    mov ecx, key_owner_id_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, r15
    lea rdx, [snapshot_owner]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [snapshot_owner_len], eax

    lea rdi, [snapshot_guild]
    mov esi, [snapshot_guild_len]
    call auth_clear_guild
    lea rdi, [snapshot_guild]
    mov esi, [snapshot_guild_len]
    lea rdx, [snapshot_owner]
    mov ecx, [snapshot_owner_len]
    call guild_auth_cache_owner
    test eax, eax
    jnz .bad

    mov rdi, r14
    mov rsi, r15
    sub rsi, rdi
    lea rdx, [key_roles]
    mov ecx, key_roles_len
    call json_find_key
    test rax, rax
    jz .bad
    mov [snapshot_array_start], rax
    mov rdi, rax
    mov rsi, r15
    call json_array_end
    test rax, rax
    jz .bad
    cmp rax, r15
    ja .bad
    mov [snapshot_array_end], rax
    mov rbx, [snapshot_array_start]
    inc rbx
.role_loop:
    mov rdi, rbx
    mov rsi, [snapshot_array_end]
    call snapshot_skip_delimiters
    mov rbx, rax
    mov r11, [snapshot_array_end]
    dec r11
    cmp rbx, r11
    jae .done
    cmp byte [rbx], '{'
    jne .bad
    mov rdi, rbx
    mov rsi, [snapshot_array_end]
    call json_object_end
    test rax, rax
    jz .bad
    cmp rax, [snapshot_array_end]
    ja .bad
    mov [snapshot_object_end], rax

    mov rdi, rbx
    mov rsi, rax
    sub rsi, rdi
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, [snapshot_object_end]
    lea rdx, [snapshot_role]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [snapshot_role_len], eax

    mov rdi, rbx
    mov rsi, [snapshot_object_end]
    sub rsi, rdi
    lea rdx, [key_permissions]
    mov ecx, key_permissions_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, [snapshot_object_end]
    lea rdx, [snapshot_permission_text]
    mov ecx, 31
    call json_read_string
    test eax, eax
    jle .bad
    lea rdi, [snapshot_permission_text]
    lea rsi, [snapshot_permission_text + rax]
    call json_read_uint
    jc .bad
    mov [snapshot_permission], rax

    mov rdi, rbx
    mov rsi, [snapshot_object_end]
    sub rsi, rdi
    lea rdx, [key_position]
    mov ecx, key_position_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, [snapshot_object_end]
    call json_read_uint
    jc .bad
    cmp rax, 2147483647
    ja .bad
    mov [snapshot_position], eax

    lea rdi, [snapshot_guild]
    mov esi, [snapshot_guild_len]
    lea rdx, [snapshot_role]
    mov ecx, [snapshot_role_len]
    mov r8, [snapshot_permission]
    mov r9d, [snapshot_position]
    call guild_auth_cache_role_position
    test eax, eax
    jnz .bad
    mov rbx, [snapshot_object_end]
    jmp .role_loop
.done:
    mov rdi, [snapshot_data_ptr]
    mov rsi, [snapshot_data_end]
    lea rdx, [snapshot_guild]
    mov ecx, [snapshot_guild_len]
    call guild_auth_cache_bot_from_payload
    test eax, eax
    js .bad
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

; RDI=guild data object, RSI=exclusive end, RDX=guild ID, ECX=len. EAX=0 when
; the READY-cached bot member is stored if present; absent members remain a
; fail-closed hierarchy cache miss rather than invalidating role permissions.
guild_auth_cache_bot_from_payload:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    cmp dword [gateway_bot_user_id_len], 0
    jle .done
    mov rdi, r12
    mov rsi, r13
    sub rsi, rdi
    lea rdx, [key_members]
    mov ecx, key_members_len
    call json_find_key
    test rax, rax
    jz .done
    cmp byte [rax], '['
    jne .done
    mov [snapshot_members_start], rax
    mov rdi, rax
    mov rsi, r13
    call json_array_end
    test rax, rax
    jz .bad
    cmp rax, r13
    ja .bad
    mov [snapshot_members_end], rax
    mov rbx, [snapshot_members_start]
    inc rbx
.loop:
    mov rdi, rbx
    mov rsi, [snapshot_members_end]
    call snapshot_skip_delimiters
    mov rbx, rax
    mov r11, [snapshot_members_end]
    dec r11
    cmp rbx, r11
    jae .done
    cmp byte [rbx], '{'
    jne .bad
    mov rdi, rbx
    mov rsi, [snapshot_members_end]
    call json_object_end
    test rax, rax
    jz .bad
    mov [snapshot_member_object_end], rax
    mov rdi, rbx
    mov rsi, rax
    sub rsi, rdi
    lea rdx, [key_user]
    mov ecx, key_user_len
    call json_find_key
    test rax, rax
    jz .bad
    cmp byte [rax], '{'
    jne .bad
    mov rdi, rax
    mov rsi, [snapshot_member_object_end]
    call json_object_end
    test rax, rax
    jz .bad
    mov [snapshot_user_object_end], rax
    mov rdi, [snapshot_user_object_end]
    ; json_find_key needs object start, so reconstruct from user pointer preserved below.
    mov rdi, rbx
    mov rsi, [snapshot_member_object_end]
    sub rsi, rdi
    lea rdx, [key_user]
    mov ecx, key_user_len
    call json_find_key
    test rax, rax
    jz .bad
    mov [snapshot_user_object_start], rax
    mov rdi, rax
    mov rsi, [snapshot_user_object_end]
    sub rsi, rdi
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, [snapshot_user_object_end]
    lea rdx, [snapshot_member_id]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    cmp eax, [gateway_bot_user_id_len]
    jne .next
    lea rdi, [snapshot_member_id]
    lea rsi, [gateway_bot_user_id]
    mov edx, eax
    call equal_bytes
    test al, al
    jz .next
    mov rdi, rbx
    mov rsi, [snapshot_member_object_end]
    sub rsi, rdi
    lea rdx, [key_roles]
    mov ecx, key_roles_len
    call json_find_key
    test rax, rax
    jz .bad
    cmp byte [rax], '['
    jne .bad
    mov [snapshot_bot_roles_start], rax
    mov rdi, rax
    mov rsi, [snapshot_member_object_end]
    call json_array_end
    test rax, rax
    jz .bad
    mov [snapshot_bot_roles_end], rax
    lea rdi, [r14]
    mov esi, r15d
    mov rdx, [snapshot_bot_roles_start]
    mov rcx, [snapshot_bot_roles_end]
    sub rcx, rdx
    call guild_auth_cache_bot_member
    jmp .out
.next:
    mov rbx, [snapshot_member_object_end]
    jmp .loop
.done:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    jmp .out

; RDI=cursor, RSI=exclusive array end. RAX=first non-delimiter cursor.
snapshot_skip_delimiters:
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

; RDI=guild, ESI=guild len. Clears owner and role records for that exact guild.
auth_clear_guild:
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    xor r10d, r10d
.owner_loop:
    cmp r10d, OWNER_SLOT_COUNT
    jae .roles_start
    imul rax, r10, OWNER_SLOT_SIZE
    lea r9, [owner_slots + rax]
    cmp byte [r9], 1
    jne .owner_next
    cmp r13d, [r9 + 4]
    jne .owner_next
    lea rdi, [r9 + 16]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .owner_next
    mov byte [r9], 0
.owner_next:
    inc r10d
    jmp .owner_loop
.roles_start:
    xor r10d, r10d
.role_loop:
    cmp r10d, ROLE_SLOT_COUNT
    jae .bot_members_start
    imul rax, r10, ROLE_SLOT_SIZE
    lea r9, [role_slots + rax]
    cmp byte [r9], 1
    jne .role_next
    cmp r13d, [r9 + 4]
    jne .role_next
    lea rdi, [r9 + 32]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .role_next
    mov byte [r9], 0
.role_next:
    inc r10d
    jmp .role_loop
.bot_members_start:
    xor r10d, r10d
.bot_member_loop:
    cmp r10d, BOT_MEMBER_SLOT_COUNT
    jae .out
    imul rax, r10, BOT_MEMBER_SLOT_SIZE
    lea r9, [bot_member_slots + rax]
    cmp byte [r9], 1
    jne .bot_member_next
    cmp r13d, [r9 + 4]
    jne .bot_member_next
    lea rdi, [r9 + 16]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .bot_member_next
    mov byte [r9], 0
.bot_member_next:
    inc r10d
    jmp .bot_member_loop
.out:
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=opening member roles JSON array, ECX=array len.
; RAX=base permission union for cached @everyone plus listed roles, or -1 for
; invalid/missing bounded state. This does not apply channel overwrites.
guild_auth_roles_permissions:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .bad
    test r13d, r13d
    jz .bad
    test r14, r14
    jz .bad
    test r15d, r15d
    jle .bad
    lea rax, [r14 + r15]
    mov [rsp], rax
    mov rdi, r14
    mov rsi, rax
    call json_array_end
    test rax, rax
    jz .bad
    cmp rax, [rsp]
    jne .bad
    mov rdi, r12
    mov esi, r13d
    mov rdx, r12
    mov ecx, r13d
    call get_role_permissions
    mov [accumulated_permissions], rax
    lea r15, [r14 + 1]
.skip_ws:
    mov r11, [rsp]
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
    mov rsi, [rsp]
    lea rdx, [role_id]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov r15, rdx
    mov r10d, eax
    mov rdi, r12
    mov esi, r13d
    lea rdx, [role_id]
    mov ecx, r10d
    call get_role_permissions
    or [accumulated_permissions], rax
    jmp .skip_ws
.advance:
    inc r15
    jmp .skip_ws
.done:
    mov rax, [accumulated_permissions]
    jmp .out
.bad:
    mov rax, -1
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; R12=guild, R13D=len. RAX=existing or first unused bot-member slot, else zero.
find_bot_member_slot:
    xor r10d, r10d
    xor r8d, r8d
.loop:
    cmp r10d, BOT_MEMBER_SLOT_COUNT
    jae .done
    imul rax, r10, BOT_MEMBER_SLOT_SIZE
    lea r9, [bot_member_slots + rax]
    cmp byte [r9], 1
    jne .empty
    cmp r13d, [r9 + 4]
    jne .next
    lea rdi, [r9 + 16]
    mov rsi, r12
    mov edx, r13d
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

; R12=guild, R13D=len. RAX=existing bot-member slot or zero.
find_existing_bot_member:
    call find_bot_member_slot
    test rax, rax
    jz .out
    cmp byte [rax], 1
    je .out
    xor eax, eax
.out:
    ret

; R12=guild, R13D=len. RAX=existing or first unused owner slot, else zero.
find_owner_slot:
    xor r10d, r10d
    xor r8d, r8d
.loop:
    cmp r10d, OWNER_SLOT_COUNT
    jae .done
    imul rax, r10, OWNER_SLOT_SIZE
    lea r9, [owner_slots + rax]
    cmp byte [r9], 1
    jne .empty
    cmp r13d, [r9 + 4]
    jne .next
    lea rdi, [r9 + 16]
    mov rsi, r12
    mov edx, r13d
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

; R12=guild, R13D=len. RAX=existing owner slot or zero.
find_existing_owner:
    xor r10d, r10d
.loop:
    cmp r10d, OWNER_SLOT_COUNT
    jae .missing
    imul rax, r10, OWNER_SLOT_SIZE
    lea r9, [owner_slots + rax]
    cmp byte [r9], 1
    jne .next
    cmp r13d, [r9 + 4]
    jne .next
    lea rdi, [r9 + 16]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jnz .found
.next:
    inc r10d
    jmp .loop
.found:
    mov rax, r9
    ret
.missing:
    xor eax, eax
    ret

; R12=guild, R13D=len, R14=role, R15D=len. RAX=existing or first unused role slot.
find_role_slot:
    xor r10d, r10d
    xor r8d, r8d
.loop:
    cmp r10d, ROLE_SLOT_COUNT
    jae .done
    imul rax, r10, ROLE_SLOT_SIZE
    lea r9, [role_slots + rax]
    cmp byte [r9], 1
    jne .empty
    cmp r13d, [r9 + 4]
    jne .next
    lea rdi, [r9 + 32]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .next
    cmp r15d, [r9 + 8]
    jne .next
    lea rdi, [r9 + 32 + ID_CAP]
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

; RDI=guild, ESI=guild len, RDX=role, ECX=role len. RAX=permissions or zero.
get_role_permissions:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    xor r10d, r10d
.loop:
    cmp r10d, ROLE_SLOT_COUNT
    jae .missing
    imul rax, r10, ROLE_SLOT_SIZE
    lea r9, [role_slots + rax]
    cmp byte [r9], 1
    jne .next
    cmp r13d, [r9 + 4]
    jne .next
    lea rdi, [r9 + 32]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .next
    cmp r15d, [r9 + 8]
    jne .next
    lea rdi, [r9 + 32 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call equal_bytes
    test al, al
    jz .next
    mov rax, [r9 + 16]
    jmp .out
.next:
    inc r10d
    jmp .loop
.missing:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=role, ECX=role len. EAX=position or -1
; when the exact bounded role record is absent.
guild_auth_role_position:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    xor r10d, r10d
.loop:
    cmp r10d, ROLE_SLOT_COUNT
    jae .missing
    imul rax, r10, ROLE_SLOT_SIZE
    lea r9, [role_slots + rax]
    cmp byte [r9], 1
    jne .next
    cmp r13d, [r9 + 4]
    jne .next
    lea rdi, [r9 + 32]
    mov rsi, r12
    mov edx, r13d
    call equal_bytes
    test al, al
    jz .next
    cmp r15d, [r9 + 8]
    jne .next
    lea rdi, [r9 + 32 + ID_CAP]
    mov rsi, r14
    mov edx, r15d
    call equal_bytes
    test al, al
    jz .next
    mov eax, [r9 + 24]
    jmp .out
.next:
    inc r10d
    jmp .loop
.missing:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=bot roles JSON array, ECX=array len.
; EAX=0 on a complete bounded cache update, or -1 on invalid/full input.
guild_auth_cache_bot_member:
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
    cmp r15d, BOT_MEMBER_ROLES_CAP - 1
    ja .bad
    lea r11, [r14 + r15]
    mov rdi, r14
    mov rsi, r11
    call json_array_end
    test rax, rax
    jz .bad
    cmp rax, r11
    jne .bad
    call find_bot_member_slot
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
    mov byte [r11 + 16 + ID_CAP + r15], 0
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

; RDI=guild, ESI=guild len. RAX=role array pointer and EDX=len only for a
; complete cached bot member; RAX=0/EDX=0 when unavailable.
guild_auth_get_bot_roles:
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    test r12, r12
    jz .no
    test r13d, r13d
    jle .no
    call find_existing_bot_member
    test rax, rax
    jz .no
    mov edx, [rax + 8]
    lea rax, [rax + 16 + ID_CAP]
    jmp .out
.no:
    xor eax, eax
    xor edx, edx
.out:
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=one target role ID, ECX=role len. AL=1
; only when that role and the bot role cache are complete and bot highest
; position is strictly above target. Unknown cache/roles fail closed.
guild_auth_bot_above_role:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    call guild_auth_role_position
    test eax, eax
    js .no
    mov [rsp], eax
    mov rdi, r12
    mov esi, r13d
    call guild_auth_get_bot_roles
    test rax, rax
    jz .no
    test edx, edx
    jle .no
    mov r14, rax
    mov r15d, edx
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call guild_auth_member_highest_position
    test eax, eax
    js .no
    cmp eax, [rsp]
    jle .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=target roles JSON array, ECX=len. AL=1 only
; when the cached bot member is strictly above the target; absent cache fails closed.
guild_auth_bot_above_roles:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .no
    test r14, r14
    jz .no
    test r13d, r13d
    jle .no
    test r15d, r15d
    jle .no
    call find_existing_bot_member
    test rax, rax
    jz .no
    lea rdi, [r12]
    mov esi, r13d
    lea rdx, [rax + 16 + ID_CAP]
    mov ecx, [rax + 8]
    mov r8, r14
    mov r9d, r15d
    call guild_auth_bot_above_member
    jmp .out
.no:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=opening roles JSON array, ECX=array len.
; EAX=highest cached role position including @everyone, or -1 for malformed or
; incomplete role state. This is a hierarchy primitive, not a permission grant.
guild_auth_member_highest_position:
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
    test r13d, r13d
    jle .bad
    test r14, r14
    jz .bad
    test r15d, r15d
    jle .bad
    lea rax, [r14 + r15]
    mov [hierarchy_array_end], rax
    mov rdi, r14
    mov rsi, rax
    call json_array_end
    test rax, rax
    jz .bad
    cmp rax, [hierarchy_array_end]
    jne .bad
    mov rdi, r12
    mov esi, r13d
    mov rdx, r12                    ; @everyone role ID equals guild ID
    mov ecx, r13d
    call guild_auth_role_position
    test eax, eax
    js .bad
    mov ebx, eax
    lea r15, [r14 + 1]
.skip_ws:
    mov r11, [hierarchy_array_end]
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
    mov rsi, [hierarchy_array_end]
    lea rdx, [role_id]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov r15, rdx
    mov r10d, eax
    mov rdi, r12
    mov esi, r13d
    lea rdx, [role_id]
    mov ecx, r10d
    call guild_auth_role_position
    test eax, eax
    js .bad
    cmp eax, ebx
    jle .skip_ws
    mov ebx, eax
    jmp .skip_ws
.advance:
    inc r15
    jmp .skip_ws
.done:
    mov eax, ebx
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

; RDI=guild, ESI=guild len, RDX=bot roles JSON, ECX=len, R8=target roles JSON,
; R9D=len. AL=1 only if bot highest position is strictly above target highest.
guild_auth_bot_above_member:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, r8
    mov r13d, r9d
    mov r14, rdi
    mov r15d, esi
    call guild_auth_member_highest_position
    test eax, eax
    js .no
    mov ebx, eax
    mov rdi, r14
    mov esi, r15d
    mov rdx, r12
    mov ecx, r13d
    call guild_auth_member_highest_position
    test eax, eax
    js .no
    cmp ebx, eax
    jle .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI and RSI buffers, EDX=count. AL=1 when equal.
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
key_data: db 'd'
key_data_len equ $ - key_data
key_id: db 'id'
key_id_len equ $ - key_id
key_owner_id: db 'owner_id'
key_owner_id_len equ $ - key_owner_id
key_roles: db 'roles'
key_roles_len equ $ - key_roles
key_permissions: db 'permissions'
key_permissions_len equ $ - key_permissions
key_position: db 'position'
key_position_len equ $ - key_position
key_members: db 'members'
key_members_len equ $ - key_members
key_user: db 'user'
key_user_len equ $ - key_user

section .data
cached_permission: dq 0
cached_position: dd 0
accumulated_permissions: dq 0
snapshot_data_ptr: dq 0
snapshot_data_end: dq 0
snapshot_array_start: dq 0
snapshot_array_end: dq 0
snapshot_object_end: dq 0
snapshot_guild_len: dd 0
snapshot_owner_len: dd 0
snapshot_role_len: dd 0
snapshot_permission: dq 0
snapshot_position: dd 0
hierarchy_array_end: dq 0
snapshot_members_start: dq 0
snapshot_members_end: dq 0
snapshot_member_object_end: dq 0
snapshot_user_object_start: dq 0
snapshot_user_object_end: dq 0
snapshot_bot_roles_start: dq 0
snapshot_bot_roles_end: dq 0

section .bss
owner_slots: resb OWNER_SLOT_COUNT * OWNER_SLOT_SIZE
role_slots: resb ROLE_SLOT_COUNT * ROLE_SLOT_SIZE
bot_member_slots: resb BOT_MEMBER_SLOT_COUNT * BOT_MEMBER_SLOT_SIZE
role_id: resb ID_CAP
snapshot_guild: resb ID_CAP
snapshot_owner: resb ID_CAP
snapshot_role: resb ID_CAP
snapshot_permission_text: resb 32
snapshot_member_id: resb ID_CAP

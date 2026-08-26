BITS 64
DEFAULT REL

global _start
global bot_owner_ptr
global bot_owner_len

extern guild_auth_reset
extern guild_auth_cache_owner
extern guild_auth_cache_role
extern guild_auth_cache_role_position
extern guild_auth_role_position
extern guild_auth_member_highest_position
extern guild_auth_bot_above_member
extern guild_auth_is_owner
extern guild_auth_is_manager
extern guild_auth_roles_have
extern guild_auth_roles_permissions
extern guild_auth_cache_guild_create

%define SYS_EXIT 60
%define PERM_KICK 2
%define PERM_BAN 4
%define PERM_ADMIN 8
%define PERM_MANAGE_CHANNELS 16

section .text
_start:
    mov qword [bot_owner_ptr], 0
    mov dword [bot_owner_len], 0
    call guild_auth_reset

    ; Owner identity is exact-guild and exact-user scoped.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [owner_one]
    mov ecx, owner_one_len
    call guild_auth_cache_owner
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [owner_one]
    mov ecx, owner_one_len
    call guild_auth_is_owner
    test al, al
    jz .fail
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [owner_one]
    mov ecx, owner_one_len
    call guild_auth_is_owner
    test al, al
    jnz .fail
    lea rax, [external_owner]
    mov [bot_owner_ptr], rax
    mov dword [bot_owner_len], external_owner_len
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [external_owner]
    mov ecx, external_owner_len
    call guild_auth_is_manager
    test al, al
    jz .fail
    mov qword [bot_owner_ptr], 0
    mov dword [bot_owner_len], 0

    ; @everyone and member roles combine with a bitwise union.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [guild_one]
    mov ecx, guild_one_len
    mov r8, PERM_KICK
    call guild_auth_cache_role
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [role_mod]
    mov ecx, role_mod_len
    mov r8, PERM_BAN
    call guild_auth_cache_role
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    mov r8, PERM_KICK | PERM_BAN
    call guild_auth_roles_have
    test al, al
    jz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    mov r8, PERM_MANAGE_CHANNELS
    call guild_auth_roles_have
    test al, al
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    call guild_auth_roles_permissions
    cmp rax, PERM_KICK | PERM_BAN
    jne .fail

    ; Role positions are cached independently from permission bitsets and are
    ; available for later bot/target hierarchy checks.
    mov dword [failure_stage], 8
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [role_mod]
    mov ecx, role_mod_len
    mov r8, PERM_BAN
    mov r9d, 10
    call guild_auth_cache_role_position
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [role_mod]
    mov ecx, role_mod_len
    call guild_auth_role_position
    cmp eax, 10
    jne .fail

    ; Administrator role bypasses individual requested permission bits.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [role_admin]
    mov ecx, role_admin_len
    mov r8, PERM_ADMIN
    mov r9d, 20
    call guild_auth_cache_role_position
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_admin_roles]
    mov ecx, member_admin_roles_len
    mov r8, PERM_MANAGE_CHANNELS
    call guild_auth_roles_have
    test al, al
    jz .fail

    ; Hierarchy uses strict highest-position comparison and never treats an
    ; unknown/malformed member role list as manageable.
    mov dword [failure_stage], 9
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_admin_roles]
    mov ecx, member_admin_roles_len
    call guild_auth_member_highest_position
    cmp eax, 20
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    call guild_auth_member_highest_position
    cmp eax, 10
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_admin_roles]
    mov ecx, member_admin_roles_len
    lea r8, [member_roles]
    mov r9d, member_roles_len
    call guild_auth_bot_above_member
    test al, al
    jz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    lea r8, [member_admin_roles]
    mov r9d, member_admin_roles_len
    call guild_auth_bot_above_member
    test al, al
    jnz .fail

    ; Malformed roles JSON and unknown guild role entries fail closed.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [malformed_roles]
    mov ecx, malformed_roles_len
    mov r8, PERM_KICK
    call guild_auth_roles_have
    test al, al
    jnz .fail
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    mov r8, PERM_KICK
    call guild_auth_roles_have
    test al, al
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [malformed_roles]
    mov ecx, malformed_roles_len
    call guild_auth_roles_permissions
    cmp rax, -1
    jne .fail

    ; Reset clears every owner and role cache record.
    call guild_auth_reset
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [owner_one]
    mov ecx, owner_one_len
    call guild_auth_is_owner
    test al, al
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    mov r8, PERM_KICK
    call guild_auth_roles_have
    test al, al
    jnz .fail

    ; GUILD_CREATE parsing populates the same owner and role cache in NASM.
    mov dword [failure_stage], 7
    call guild_auth_reset
    lea rdi, [guild_create_event]
    mov esi, guild_create_event_len
    call guild_auth_cache_guild_create
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [owner_one]
    mov ecx, owner_one_len
    call guild_auth_is_owner
    test al, al
    jz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [member_roles]
    mov ecx, member_roles_len
    mov r8, PERM_KICK | PERM_BAN
    call guild_auth_roles_have
    test al, al
    jz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [role_mod]
    mov ecx, role_mod_len
    call guild_auth_role_position
    cmp eax, 10
    jne .fail

    ; A truncated guild payload fails safely.
    lea rdi, [truncated_guild_create]
    mov esi, truncated_guild_create_len
    call guild_auth_cache_guild_create
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

section .rodata
guild_one: db '1001'
guild_one_len equ $ - guild_one
guild_two: db '1002'
guild_two_len equ $ - guild_two
owner_one: db '9001'
owner_one_len equ $ - owner_one
external_owner: db 'external-owner'
external_owner_len equ $ - external_owner
role_mod: db '2001'
role_mod_len equ $ - role_mod
role_admin: db '2002'
role_admin_len equ $ - role_admin
member_roles: db '["2001"]'
member_roles_len equ $ - member_roles
member_admin_roles: db '["2002"]'
member_admin_roles_len equ $ - member_admin_roles
malformed_roles: db '["2001"'
malformed_roles_len equ $ - malformed_roles
guild_create_event: db '{"op":0,"t":"GUILD_CREATE","d":{"id":"1001","owner_id":"9001","roles":[{"id":"1001","permissions":"2","position":0},{"id":"2001","permissions":"4","position":10}]}}'
guild_create_event_len equ $ - guild_create_event
truncated_guild_create: db '{"op":0,"t":"GUILD_CREATE","d":{"id":"1001"'
truncated_guild_create_len equ $ - truncated_guild_create

section .data
bot_owner_ptr: dq 0
bot_owner_len: dd 0
failure_stage: dd 1

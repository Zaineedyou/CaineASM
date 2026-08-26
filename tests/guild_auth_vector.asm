BITS 64
DEFAULT REL

global _start

extern guild_auth_reset
extern guild_auth_cache_owner
extern guild_auth_cache_role
extern guild_auth_is_owner
extern guild_auth_roles_have
extern guild_auth_cache_guild_create

%define SYS_EXIT 60
%define PERM_KICK 2
%define PERM_BAN 4
%define PERM_ADMIN 8
%define PERM_MANAGE_CHANNELS 16

section .text
_start:
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

    ; Administrator role bypasses individual requested permission bits.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [role_admin]
    mov ecx, role_admin_len
    mov r8, PERM_ADMIN
    call guild_auth_cache_role
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
guild_create_event: db '{"op":0,"t":"GUILD_CREATE","d":{"id":"1001","owner_id":"9001","roles":[{"id":"1001","permissions":"2"},{"id":"2001","permissions":"4"}]}}'
guild_create_event_len equ $ - guild_create_event
truncated_guild_create: db '{"op":0,"t":"GUILD_CREATE","d":{"id":"1001"'
truncated_guild_create_len equ $ - truncated_guild_create

section .data
failure_stage: dd 1

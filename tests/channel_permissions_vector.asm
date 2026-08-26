BITS 64
DEFAULT REL

global _start
global bot_owner_ptr
global bot_owner_len
global gateway_bot_user_id
global gateway_bot_user_id_len

extern guild_auth_reset
extern guild_auth_cache_role_position
extern channel_auth_reset
extern channel_auth_cache_channel
extern channel_auth_cache_overwrite
extern channel_auth_resolve
extern channel_auth_cache_guild_create

%define SYS_EXIT 60
%define TYPE_ROLE 0
%define TYPE_MEMBER 1
%define PERM_KICK 2
%define PERM_BAN 4
%define PERM_ADMIN 8
%define PERM_MANAGE_CHANNELS 16

section .text
_start:
    call guild_auth_reset
    call channel_auth_reset

    ; Base union: @everyone grants kick; member role grants ban.
    mov dword [failure_stage], 1
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [guild_id]
    mov ecx, guild_id_len
    mov r8, PERM_KICK
    xor r9d, r9d
    call guild_auth_cache_role_position
    test eax, eax
    jnz .fail
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [role_mod]
    mov ecx, role_mod_len
    mov r8, PERM_BAN
    mov r9d, 10
    call guild_auth_cache_role_position
    test eax, eax
    jnz .fail

    ; Channel known state is explicit even when no overwrite exists.
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    call channel_auth_cache_channel
    test eax, eax
    jnz .fail

    ; @everyone deny kick.
    mov dword [failure_stage], 2
    mov rax, PERM_KICK
    push rax
    xor eax, eax
    push rax
    mov rax, TYPE_ROLE
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [guild_id]
    mov r9d, guild_id_len
    call channel_auth_cache_overwrite
    add rsp, 24
    test eax, eax
    jnz .fail

    ; Role deny ban plus allow manage-channels. Role allow is applied after all
    ; role denies; member explicit allow then restores ban.
    mov dword [failure_stage], 3
    mov rax, PERM_BAN
    push rax
    mov rax, PERM_MANAGE_CHANNELS
    push rax
    mov rax, TYPE_ROLE
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [role_mod]
    mov r9d, role_mod_len
    call channel_auth_cache_overwrite
    add rsp, 24
    test eax, eax
    jnz .fail

    mov dword [failure_stage], 4
    xor eax, eax
    push rax
    mov rax, PERM_BAN
    push rax
    mov rax, TYPE_MEMBER
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [member_id]
    mov r9d, member_id_len
    call channel_auth_cache_overwrite
    add rsp, 24
    test eax, eax
    jnz .fail

    mov dword [failure_stage], 5
    mov rax, member_roles_len
    push rax
    lea rax, [member_roles]
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [member_id]
    mov r9d, member_id_len
    call channel_auth_resolve
    add rsp, 16
    cmp rax, PERM_BAN | PERM_MANAGE_CHANNELS
    jne .fail

    ; Administrator bypasses channel overwrite masks after a complete base role
    ; cache resolves it.
    mov dword [failure_stage], 6
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [role_admin]
    mov ecx, role_admin_len
    mov r8, PERM_ADMIN
    mov r9d, 20
    call guild_auth_cache_role_position
    test eax, eax
    jnz .fail
    mov rax, admin_roles_len
    push rax
    lea rax, [admin_roles]
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [member_id]
    mov r9d, member_id_len
    call channel_auth_resolve
    add rsp, 16
    test rax, PERM_ADMIN
    jz .fail

    ; Unknown channel and malformed role arrays never grant a permission.
    mov dword [failure_stage], 7
    mov rax, member_roles_len
    push rax
    lea rax, [member_roles]
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [unknown_channel]
    mov ecx, unknown_channel_len
    lea r8, [member_id]
    mov r9d, member_id_len
    call channel_auth_resolve
    add rsp, 16
    cmp rax, -1
    jne .fail
    mov rax, malformed_roles_len
    push rax
    lea rax, [malformed_roles]
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [member_id]
    mov r9d, member_id_len
    call channel_auth_resolve
    add rsp, 16
    cmp rax, -1
    jne .fail

    ; GUILD_CREATE parser replaces the guild's snapshot atomically enough for
    ; resolution: complete channel and overwrite state stays in fixed slots.
    mov dword [failure_stage], 8
    lea rdi, [guild_create_channels]
    mov esi, guild_create_channels_len
    call channel_auth_cache_guild_create
    test eax, eax
    jnz .fail
    mov rax, member_roles_len
    push rax
    lea rax, [member_roles]
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [member_id]
    mov r9d, member_id_len
    call channel_auth_resolve
    add rsp, 16
    cmp rax, PERM_BAN | PERM_MANAGE_CHANNELS
    jne .fail

    ; A malformed replacement snapshot clears that guild and fails closed.
    mov dword [failure_stage], 9
    lea rdi, [truncated_guild_create_channels]
    mov esi, truncated_guild_create_channels_len
    call channel_auth_cache_guild_create
    cmp eax, -1
    jne .fail
    mov rax, member_roles_len
    push rax
    lea rax, [member_roles]
    push rax
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [channel_id]
    mov ecx, channel_id_len
    lea r8, [member_id]
    mov r9d, member_id_len
    call channel_auth_resolve
    add rsp, 16
    cmp rax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

section .rodata
guild_id: db '1001'
guild_id_len equ $ - guild_id
channel_id: db '3001'
channel_id_len equ $ - channel_id
unknown_channel: db '3002'
unknown_channel_len equ $ - unknown_channel
role_mod: db '2001'
role_mod_len equ $ - role_mod
role_admin: db '2002'
role_admin_len equ $ - role_admin
member_id: db '4001'
member_id_len equ $ - member_id
member_roles: db '["2001"]'
member_roles_len equ $ - member_roles
admin_roles: db '["2002"]'
admin_roles_len equ $ - admin_roles
malformed_roles: db '["2001"'
malformed_roles_len equ $ - malformed_roles
guild_create_channels: db '{"op":0,"t":"GUILD_CREATE","d":{"id":"1001","channels":[{"id":"3001","permission_overwrites":[{"id":"1001","type":0,"allow":"0","deny":"2"},{"id":"2001","type":0,"allow":"16","deny":"4"},{"id":"4001","type":1,"allow":"4","deny":"0"}]}]}}'
guild_create_channels_len equ $ - guild_create_channels
truncated_guild_create_channels: db '{"op":0,"t":"GUILD_CREATE","d":{"id":"1001","channels":['
truncated_guild_create_channels_len equ $ - truncated_guild_create_channels

section .data
bot_owner_ptr: dq 0
bot_owner_len: dd 0
gateway_bot_user_id: times 64 db 0
gateway_bot_user_id_len: dd 0
failure_stage: dd 0

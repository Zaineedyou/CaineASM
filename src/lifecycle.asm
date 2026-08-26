BITS 64
DEFAULT REL

global lifecycle_member_add
global lifecycle_member_remove

extern json_find_key
extern json_read_string
extern guild_config_get
extern discord_send_text
extern discord_add_member_role

%define ID_CAP 64
%define NAME_CAP 128
%define OUTPUT_CAP 2000

; RDI=full Gateway dispatch frame, RSI=length. EAX=0 handled/no configured
; channel, -1 only if an outbound Discord REST send fails. The handler is
; deliberately bounded and consumes no display-name cache outside the event.
section .text

lifecycle_member_add:
    mov dword [member_add_mode], 1
    lea rdx, [setting_welcome_channel]
    mov ecx, setting_welcome_channel_len
    lea r8, [setting_welcome_message]
    mov r9d, setting_welcome_message_len
    lea r10, [default_welcome]
    mov r11d, default_welcome_len
    jmp lifecycle_handle

lifecycle_member_remove:
    mov dword [member_add_mode], 0
    lea rdx, [setting_goodbye_channel]
    mov ecx, setting_goodbye_channel_len
    lea r8, [setting_goodbye_message]
    mov r9d, setting_goodbye_message_len
    lea r10, [default_goodbye]
    mov r11d, default_goodbye_len

; RDI=frame RSI=len RDX=channel-setting ECX=len R8=message-setting R9D=len
; R10=default template R11D=len.
lifecycle_handle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    mov [message_setting_ptr], r8
    mov [message_setting_len], r9d
    mov [template_default_ptr], r10
    mov [template_default_len], r11d

    ; guild_id belongs to the member event root and is required.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_guild_id]
    mov ecx, key_guild_id_len
    call json_find_key
    test rax, rax
    jz .done
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [guild_id]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .done
    mov [guild_id_len], eax

    ; The first generic id in GUILD_MEMBER_ADD/REMOVE is user.id.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .done
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [user_id]
    mov ecx, ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .done
    mov [user_id_len], eax

    cmp dword [member_add_mode], 1
    jne .username
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [setting_auto_role]
    mov ecx, setting_auto_role_len
    call guild_config_get
    test rax, rax
    jz .username
    test edx, edx
    jle .username
    cmp edx, ID_CAP - 1
    ja .username
    mov [auto_role_ptr], rax
    mov [auto_role_len], edx
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    lea rdx, [user_id]
    mov ecx, [user_id_len]
    mov r8, [auto_role_ptr]
    mov r9d, [auto_role_len]
    call discord_add_member_role
    ; Role hierarchy/permission failure must not suppress lifecycle messaging.
.username:
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_username]
    mov ecx, key_username_len
    call json_find_key
    test rax, rax
    jz .username_default
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [username]
    mov ecx, NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .username_default
    mov [username_len], eax
    jmp .channel
.username_default:
    lea rdi, [user_id]
    mov esi, [user_id_len]
    lea rdx, [username]
    call copy_bytes
    mov eax, [user_id_len]
    mov [username_len], eax

.channel:
    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    mov rdx, r14
    mov ecx, r15d
    call guild_config_get
    test rax, rax
    jz .done
    test edx, edx
    jle .done
    cmp edx, ID_CAP - 1
    ja .done
    mov rbx, rax
    mov [channel_len], edx
    lea rdi, [channel_id]
    mov esi, edx
    mov rdx, rbx
    call copy_bytes

    lea rdi, [guild_id]
    mov esi, [guild_id_len]
    mov rdx, [message_setting_ptr]
    mov ecx, [message_setting_len]
    call guild_config_get
    test rax, rax
    jz .default_template
    test edx, edx
    jle .default_template
    cmp edx, 511
    ja .default_template
    mov [template_ptr], rax
    mov [template_len], edx
    jmp .format
.default_template:
    mov rax, [template_default_ptr]
    mov [template_ptr], rax
    mov eax, [template_default_len]
    mov [template_len], eax
.format:
    mov dword [output_len], 0
    mov rdi, [template_ptr]
    mov esi, [template_len]
    call render_template
    test eax, eax
    js .done
    mov ecx, eax
    lea rdi, [channel_id]
    mov esi, [channel_len]
    lea rdx, [output]
    call discord_send_text
    jmp .out
.done:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=template, ESI=len. EAX=rendered len, -1 on cap exhaustion.
render_template:
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    xor r14d, r14d
.loop:
    cmp r14d, r13d
    jae .done
    cmp byte [r12 + r14], '{'
    jne .literal
    lea r8d, [r14d + 6]
    cmp r8d, r13d
    ja .literal
    lea rdx, [r12 + r14]
    lea r9, [placeholder_user]
    mov eax, placeholder_user_len
    call literal_at
    test al, al
    jz .username
    lea rdi, [mention_prefix]
    mov esi, mention_prefix_len
    call append_bytes
    test eax, eax
    js .bad
    lea rdi, [user_id]
    mov esi, [user_id_len]
    call append_bytes
    test eax, eax
    js .bad
    lea rdi, [mention_suffix]
    mov esi, mention_suffix_len
    call append_bytes
    test eax, eax
    js .bad
    add r14d, placeholder_user_len
    jmp .loop
.username:
    lea rdx, [r12 + r14]
    lea r9, [placeholder_username]
    mov eax, placeholder_username_len
    call literal_at
    test al, al
    jz .server
    lea rdi, [username]
    mov esi, [username_len]
    call append_sanitized
    test eax, eax
    js .bad
    add r14d, placeholder_username_len
    jmp .loop
.server:
    lea rdx, [r12 + r14]
    lea r9, [placeholder_server]
    mov eax, placeholder_server_len
    call literal_at
    test al, al
    jz .count
    lea rdi, [fallback_server]
    mov esi, fallback_server_len
    call append_bytes
    test eax, eax
    js .bad
    add r14d, placeholder_server_len
    jmp .loop
.count:
    lea rdx, [r12 + r14]
    lea r9, [placeholder_count]
    mov eax, placeholder_count_len
    call literal_at
    test al, al
    jz .literal
    lea rdi, [fallback_count]
    mov esi, fallback_count_len
    call append_bytes
    test eax, eax
    js .bad
    add r14d, placeholder_count_len
    jmp .loop
.literal:
    movzx edi, byte [r12 + r14]
    call append_byte
    test eax, eax
    js .bad
    inc r14d
    jmp .loop
.done:
    mov eax, [output_len]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    ret

; RDX=input at potential placeholder, R9=literal, EAX=len. AL=1 iff match.
literal_at:
    push rcx
    xor ecx, ecx
.loop:
    cmp ecx, eax
    jae .yes
    mov r8b, [rdx + rcx]
    cmp r8b, [r9 + rcx]
    jne .no
    inc ecx
    jmp .loop
.yes:
    mov al, 1
    pop rcx
    ret
.no:
    xor eax, eax
    pop rcx
    ret

; RDI=source, ESI=len. EAX=0/-1.
append_bytes:
    mov eax, [output_len]
    mov edx, OUTPUT_CAP
    sub edx, eax
    cmp esi, edx
    ja .bad
    lea r8, [output + rax]
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .done
    mov dl, [rdi + rcx]
    mov [r8 + rcx], dl
    inc ecx
    jmp .copy
.done:
    add [output_len], esi
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=source, ESI=len. ASCII control and non-ASCII bytes become '?'.
append_sanitized:
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    xor ecx, ecx
.loop:
    cmp ecx, r13d
    jae .done
    movzx edi, byte [r12 + rcx]
    cmp dil, 0x20
    jb .replace
    cmp dil, 0x7e
    ja .replace
    jmp .append
.replace:
    mov edi, '?'
.append:
    call append_byte
    test eax, eax
    js .bad
    inc ecx
    jmp .loop
.done:
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r13
    pop r12
    ret

; EDI=byte. EAX=0/-1.
append_byte:
    mov eax, [output_len]
    cmp eax, OUTPUT_CAP
    jae .bad
    mov [output + rax], dil
    inc eax
    mov [output_len], eax
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=destination, ESI=len, RDX=source.
copy_bytes:
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    mov al, [rdx + rcx]
    mov [rdi + rcx], al
    inc ecx
    jmp .loop
.done:
    ret

section .rodata
key_guild_id: db 'guild_id'
key_guild_id_len equ $ - key_guild_id
key_id: db 'id'
key_id_len equ $ - key_id
key_username: db 'username'
key_username_len equ $ - key_username
setting_welcome_channel: db 'welcome_channel'
setting_welcome_channel_len equ $ - setting_welcome_channel
setting_goodbye_channel: db 'goodbye_channel'
setting_goodbye_channel_len equ $ - setting_goodbye_channel
setting_welcome_message: db 'welcome_msg'
setting_welcome_message_len equ $ - setting_welcome_message
setting_goodbye_message: db 'goodbye_msg'
setting_goodbye_message_len equ $ - setting_goodbye_message
setting_auto_role: db 'auto_role'
setting_auto_role_len equ $ - setting_auto_role
default_welcome: db 'Selamat datang {user} di **{server}**!'
default_welcome_len equ $ - default_welcome
default_goodbye: db 'Selamat tinggal **{username}** dari **{server}**.'
default_goodbye_len equ $ - default_goodbye
placeholder_user: db '{user}'
placeholder_user_len equ $ - placeholder_user
placeholder_username: db '{username}'
placeholder_username_len equ $ - placeholder_username
placeholder_server: db '{server}'
placeholder_server_len equ $ - placeholder_server
placeholder_count: db '{count}'
placeholder_count_len equ $ - placeholder_count
mention_prefix: db '<@'
mention_prefix_len equ $ - mention_prefix
mention_suffix: db '>'
mention_suffix_len equ $ - mention_suffix
fallback_server: db 'this server'
fallback_server_len equ $ - fallback_server
fallback_count: db '?'
fallback_count_len equ $ - fallback_count

section .data
guild_id_len: dd 0
user_id_len: dd 0
username_len: dd 0
channel_len: dd 0
template_ptr: dq 0
template_len: dd 0
template_default_ptr: dq 0
template_default_len: dd 0
message_setting_ptr: dq 0
message_setting_len: dd 0
member_add_mode: dd 0
auto_role_ptr: dq 0
auto_role_len: dd 0
output_len: dd 0

section .bss
guild_id: resb ID_CAP
user_id: resb ID_CAP
username: resb NAME_CAP
channel_id: resb ID_CAP
output: resb OUTPUT_CAP

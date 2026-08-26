BITS 64
DEFAULT REL

global discord_send_text
global discord_delete_message
global discord_get_json
global discord_unban_member
global discord_kick_member
global discord_ban_member
global discord_lock_channel
global discord_unlock_channel
global discord_add_member_role

extern secure_https_post_json
extern secure_https_delete
extern secure_https_get
extern secure_https_put_empty
extern secure_https_put_json
extern json_escape_append
extern discord_token_ptr
extern discord_token_len

%define REQUEST_URL_CAP 256
%define AUTHORIZATION_CAP 512
%define JSON_BODY_CAP 12288
%define RESPONSE_BODY_CAP 4096
%define GET_URL_CAP 512
%define DISCORD_TEXT_MAX 2000

; RDI=channel ID pointer, ESI=channel ID length, RDX=text pointer, ECX=text length.
; EAX=0 only when Discord reports HTTP 2xx. The adapter only transports the request.
discord_send_text:
    push rbx
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
    cmp r13d, 64
    ja .bad
    cmp r15d, DISCORD_TEXT_MAX
    ja .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad

    ; URL: https://discord.com/api/v10/channels/<id>/messages
    lea rdi, [request_url]
    lea rsi, [url_prefix]
    mov edx, url_prefix_len
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    add rdi, r13
    lea rsi, [url_suffix]
    mov edx, url_suffix_len
    call copy_bytes
    mov byte [rdi + rdx], 0

    ; Header: Authorization: Bot <token>
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0

    ; JSON: {"content":"<fully escaped text>"}
    lea rdi, [json_body]
    lea rsi, [json_prefix]
    mov edx, json_prefix_len
    call copy_bytes
    lea rdi, [json_body + json_prefix_len]
    mov esi, JSON_BODY_CAP - json_prefix_len - json_suffix_len
    mov rdx, r14
    mov ecx, r15d
    call json_escape_append
    test eax, eax
    js .bad
    mov ebx, eax
    lea rdi, [json_body + json_prefix_len]
    add rdi, rbx
    lea rsi, [json_suffix]
    mov edx, json_suffix_len
    call copy_bytes
    mov eax, ebx
    add eax, json_prefix_len + json_suffix_len
    mov byte [json_body + rax], 0

    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [json_body]
    mov ecx, eax
    lea r8, [response_body]
    mov r9, RESPONSE_BODY_CAP
    call call_secure_post
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .bad
    cmp rax, 300
    jae .bad
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

; RDI=URL, ESI=URL length, RDX=response destination, ECX=response capacity.
; RAX=response byte length only for Discord HTTP 2xx, or -1 on invalid input,
; transport failure, or non-success HTTP status. Route policy stays with NASM
; callers; the C adapter receives only a fully constructed HTTPS request.
discord_get_json:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov ebx, ecx
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    cmp r13d, api_url_prefix_len
    jb .bad
    cmp r13d, GET_URL_CAP - 1
    ja .bad
    cmp ebx, 2
    jb .bad
    mov rdi, r12
    lea rsi, [api_url_prefix]
    mov edx, api_url_prefix_len
    call equal_bytes
    test al, al
    jz .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    lea rdi, [get_url]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    mov byte [get_url + r13], 0
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    lea rdi, [get_url]
    lea rsi, [authorization]
    mov rdx, r14
    mov ecx, ebx
    lea r8, [response_status]
    call secure_https_get
    test rax, rax
    js .bad
    mov rdx, [response_status]
    cmp rdx, 200
    jb .bad
    cmp rdx, 300
    jae .bad
    jmp .out
.bad:
    mov rax, -1
.out:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=channel ID, ESI=channel length, RDX=message ID, ECX=message length.
; EAX=0 only for Discord HTTP 2xx. Authorization and route construction stay NASM-owned.
discord_delete_message:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r13d, r13d
    jz .delete_bad
    test r15d, r15d
    jz .delete_bad
    cmp r13d, 64
    ja .delete_bad
    cmp r15d, 64
    ja .delete_bad
    cmp dword [discord_token_len], 0
    je .delete_bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .delete_bad
    mov rdi, r14
    mov esi, r15d
    call is_decimal_identifier
    test al, al
    jz .delete_bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .delete_bad
    lea rdi, [request_url]
    lea rsi, [url_prefix]
    mov edx, url_prefix_len
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    add rdi, r13
    lea rsi, [url_suffix]
    mov edx, url_suffix_len
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    add rdi, r13
    add rdi, url_suffix_len
    mov byte [rdi], '/'
    inc rdi
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    add rdi, r13
    add rdi, url_suffix_len + 1
    add rdi, r15
    mov byte [rdi], 0
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [response_body]
    mov ecx, RESPONSE_BODY_CAP
    lea r8, [response_status]
    call secure_https_delete
    test rax, rax
    js .delete_bad
    mov rax, [response_status]
    cmp rax, 200
    jb .delete_bad
    cmp rax, 300
    jae .delete_bad
    xor eax, eax
    jmp .delete_out
.delete_bad:
    mov eax, -1
.delete_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=channel ID, ESI=len, RDX=guild ID, ECX=len. EAX=0 on HTTP 2xx.
discord_lock_channel:
    mov r8d, 1
    jmp discord_channel_permission_route

; RDI=channel ID, ESI=len, RDX=guild ID, ECX=len. EAX=0 on HTTP 2xx.
discord_unlock_channel:
    xor r8d, r8d

; R8B selects PUT JSON lock (1) or DELETE exact @everyone overwrite (0).
discord_channel_permission_route:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov [channel_permission_mode], r8b
    test r13d, r13d
    jz .bad
    test r15d, r15d
    jz .bad
    cmp r13d, 64
    ja .bad
    cmp r15d, 64
    ja .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov rdi, r14
    mov esi, r15d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov eax, channel_permission_prefix_len
    add eax, r13d
    add eax, channel_permission_middle_len
    add eax, r15d
    cmp eax, REQUEST_URL_CAP - 1
    ja .bad
    mov [guild_ban_url_len], rax
    lea rdi, [request_url]
    lea rsi, [channel_permission_prefix]
    mov edx, channel_permission_prefix_len
    call copy_bytes
    lea rdi, [request_url + channel_permission_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + channel_permission_prefix_len]
    add rdi, r13
    lea rsi, [channel_permission_middle]
    mov edx, channel_permission_middle_len
    call copy_bytes
    lea rdi, [request_url + channel_permission_prefix_len]
    add rdi, r13
    add rdi, channel_permission_middle_len
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    lea rdi, [request_url]
    add rdi, [guild_ban_url_len]
    mov byte [rdi], 0
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    cmp byte [channel_permission_mode], 1
    jne .delete
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [lock_body]
    mov ecx, lock_body_len
    lea r8, [response_body]
    mov r9d, RESPONSE_BODY_CAP
    call call_secure_put_json
    jmp .status
.delete:
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [response_body]
    mov ecx, RESPONSE_BODY_CAP
    lea r8, [response_status]
    call secure_https_delete
.status:
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .bad
    cmp rax, 300
    jae .bad
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

; RDI=guild ID, ESI=guild len, RDX=user ID, ECX=user len. EAX=0 only for
; Discord HTTP 2xx. Dispatch verifies target member hierarchy before this route.
discord_kick_member:
    push rbx
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
    cmp r13d, 64
    ja .bad
    cmp r15d, 64
    ja .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov rdi, r14
    mov esi, r15d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    mov eax, guild_ban_prefix_len
    add eax, r13d
    add eax, guild_kick_middle_len
    add eax, r15d
    cmp eax, REQUEST_URL_CAP - 1
    ja .bad
    mov [guild_ban_url_len], rax
    lea rdi, [request_url]
    lea rsi, [guild_ban_prefix]
    mov edx, guild_ban_prefix_len
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    add rdi, r13
    lea rsi, [guild_kick_middle]
    mov edx, guild_kick_middle_len
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    add rdi, r13
    add rdi, guild_kick_middle_len
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    lea rdi, [request_url]
    add rdi, [guild_ban_url_len]
    mov byte [rdi], 0
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [response_body]
    mov ecx, RESPONSE_BODY_CAP
    lea r8, [response_status]
    call secure_https_delete
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .bad
    cmp rax, 300
    jae .bad
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

; RDI=guild ID, ESI=guild len, RDX=user ID, ECX=user len. EAX=0 only for
; Discord HTTP 2xx. Dispatch validates target hierarchy before this route.
discord_ban_member:
    push rbx
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
    cmp r13d, 64
    ja .bad
    cmp r15d, 64
    ja .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov rdi, r14
    mov esi, r15d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    mov eax, guild_ban_prefix_len
    add eax, r13d
    add eax, guild_ban_middle_len
    add eax, r15d
    cmp eax, REQUEST_URL_CAP - 1
    ja .bad
    mov [guild_ban_url_len], rax
    lea rdi, [request_url]
    lea rsi, [guild_ban_prefix]
    mov edx, guild_ban_prefix_len
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    add rdi, r13
    lea rsi, [guild_ban_middle]
    mov edx, guild_ban_middle_len
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    add rdi, r13
    add rdi, guild_ban_middle_len
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    lea rdi, [request_url]
    add rdi, [guild_ban_url_len]
    mov byte [rdi], 0
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [ban_body]
    mov ecx, ban_body_len
    lea r8, [response_body]
    mov r9d, RESPONSE_BODY_CAP
    call call_secure_put_json
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .bad
    cmp rax, 300
    jae .bad
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

; RDI=guild ID, ESI=guild len, RDX=user ID, ECX=user len. EAX=0 only for
; Discord HTTP 2xx. This route is intentionally limited to unban; target-role
; hierarchy is not applicable because the target is not a current guild member.
discord_unban_member:
    push rbx
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
    cmp r13d, 64
    ja .bad
    cmp r15d, 64
    ja .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov rdi, r14
    mov esi, r15d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    mov eax, guild_ban_prefix_len
    add eax, r13d
    add eax, guild_ban_middle_len
    add eax, r15d
    cmp eax, REQUEST_URL_CAP - 1
    ja .bad
    mov [guild_ban_url_len], rax
    lea rdi, [request_url]
    lea rsi, [guild_ban_prefix]
    mov edx, guild_ban_prefix_len
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    add rdi, r13
    lea rsi, [guild_ban_middle]
    mov edx, guild_ban_middle_len
    call copy_bytes
    lea rdi, [request_url + guild_ban_prefix_len]
    add rdi, r13
    add rdi, guild_ban_middle_len
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    lea rdi, [request_url]
    add rdi, [guild_ban_url_len]
    mov byte [rdi], 0
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [response_body]
    mov ecx, RESPONSE_BODY_CAP
    lea r8, [response_status]
    call secure_https_delete
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .bad
    cmp rax, 300
    jae .bad
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

; RDI=guild, ESI=guild len, RDX=user, ECX=user len, R8=role, R9D=role len.
; EAX=0 only on Discord HTTP 2xx. All route construction and identifier checks are NASM-owned.
discord_add_member_role:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov [role_id_ptr], r8
    mov [role_id_len], r9d
    test r13d, r13d
    jz .bad
    test r15d, r15d
    jz .bad
    cmp r13d, 64
    ja .bad
    cmp r15d, 64
    ja .bad
    cmp dword [role_id_len], 64
    ja .bad
    test dword [role_id_len], 0xffffffff
    jz .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov rdi, r14
    mov esi, r15d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov rdi, [role_id_ptr]
    mov esi, [role_id_len]
    call is_decimal_identifier
    test al, al
    jz .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    mov eax, guild_role_prefix_len
    add eax, r13d
    add eax, guild_role_middle_len
    add eax, r15d
    add eax, guild_role_suffix_len
    add eax, [role_id_len]
    cmp eax, REQUEST_URL_CAP - 1
    ja .bad
    lea rdi, [request_url]
    lea rsi, [guild_role_prefix]
    mov edx, guild_role_prefix_len
    call copy_bytes
    lea rdi, [request_url + guild_role_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [request_url + guild_role_prefix_len]
    add rdi, r13
    lea rsi, [guild_role_middle]
    mov edx, guild_role_middle_len
    call copy_bytes
    lea rdi, [request_url + guild_role_prefix_len]
    add rdi, r13
    add rdi, guild_role_middle_len
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    lea rdi, [request_url + guild_role_prefix_len]
    add rdi, r13
    add rdi, guild_role_middle_len
    add rdi, r15
    lea rsi, [guild_role_suffix]
    mov edx, guild_role_suffix_len
    call copy_bytes
    lea rdi, [request_url + guild_role_prefix_len]
    add rdi, r13
    add rdi, guild_role_middle_len
    add rdi, r15
    add rdi, guild_role_suffix_len
    mov rsi, [role_id_ptr]
    mov edx, [role_id_len]
    call copy_bytes
    lea rdi, [request_url + guild_role_prefix_len]
    add rdi, r13
    add rdi, guild_role_middle_len
    add rdi, r15
    add rdi, guild_role_suffix_len
    mov eax, [role_id_len]
    add rdi, rax
    mov byte [rdi], 0
    lea rdi, [authorization]
    lea rsi, [authorization_prefix]
    mov edx, authorization_prefix_len
    call copy_bytes
    lea rdi, [authorization + authorization_prefix_len]
    mov rsi, [discord_token_ptr]
    mov edx, [discord_token_len]
    call copy_bytes
    mov byte [rdi + rdx], 0
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [response_body]
    mov ecx, RESPONSE_BODY_CAP
    call call_secure_put
    test rax, rax
    js .bad
    mov rax, [response_status]
    cmp rax, 200
    jb .bad
    cmp rax, 300
    jae .bad
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

; Wrapper maintains System V stack arguments for `long *status_out` (argument 5).
; Wrapper keeps the seventh status pointer on the System V stack.
call_secure_put_json:
    sub rsp, 8
    lea rax, [response_status]
    mov [rsp], rax
    call secure_https_put_json
    add rsp, 8
    ret

call_secure_put:
    sub rsp, 8
    lea rax, [response_status]
    mov [rsp], rax
    call secure_https_put_empty
    add rsp, 8
    ret

; Wrapper maintains System V stack arguments for `long *status_out` (argument 7).
; RDI URL, RSI auth, RDX body, RCX length, R8 response, R9 capacity.
; RAX=transport return.
call_secure_post:
    sub rsp, 8
    lea rax, [response_status]
    mov [rsp], rax
    call secure_https_post_json
    add rsp, 8
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

; RDI=identifier bytes, ESI=length. AL=1 when the identifier contains only ASCII digits.
is_decimal_identifier:
    xor edx, edx
.loop:
    cmp edx, esi
    jae .yes
    mov al, [rdi + rdx]
    sub al, '0'
    cmp al, 9
    ja .no
    inc edx
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
api_url_prefix: db 'https://discord.com/api/v10/'
api_url_prefix_len equ $ - api_url_prefix
url_prefix: db 'https://discord.com/api/v10/channels/'
url_prefix_len equ $ - url_prefix
url_suffix: db '/messages'
url_suffix_len equ $ - url_suffix
channel_permission_prefix: db 'https://discord.com/api/v10/channels/'
channel_permission_prefix_len equ $ - channel_permission_prefix
channel_permission_middle: db '/permissions/'
channel_permission_middle_len equ $ - channel_permission_middle
guild_ban_prefix: db 'https://discord.com/api/v10/guilds/'
guild_ban_prefix_len equ $ - guild_ban_prefix
guild_ban_middle: db '/bans/'
guild_ban_middle_len equ $ - guild_ban_middle
guild_kick_middle: db '/members/'
guild_kick_middle_len equ $ - guild_kick_middle
guild_role_prefix: db 'https://discord.com/api/v10/guilds/'
guild_role_prefix_len equ $ - guild_role_prefix
guild_role_middle: db '/members/'
guild_role_middle_len equ $ - guild_role_middle
guild_role_suffix: db '/roles/'
guild_role_suffix_len equ $ - guild_role_suffix
authorization_prefix: db 'Authorization: Bot '
authorization_prefix_len equ $ - authorization_prefix
json_prefix: db '{"content":"'
json_prefix_len equ $ - json_prefix
json_suffix: db '"}'
json_suffix_len equ $ - json_suffix
ban_body: db '{"delete_message_seconds":0}'
ban_body_len equ $ - ban_body
lock_body: db '{"type":0,"allow":"0","deny":"2048"}'
lock_body_len equ $ - lock_body

section .data
response_status: dq 0
role_id_ptr: dq 0
role_id_len: dd 0
guild_ban_url_len: dq 0
channel_permission_mode: db 0

section .bss
request_url: resb REQUEST_URL_CAP
get_url: resb GET_URL_CAP
authorization: resb AUTHORIZATION_CAP
json_body: resb JSON_BODY_CAP
response_body: resb RESPONSE_BODY_CAP

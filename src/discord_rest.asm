BITS 64
DEFAULT REL

global discord_send_text
global discord_delete_message
global discord_get_json
global discord_get_channel_messages
global discord_bulk_delete_messages
global discord_unban_member
global discord_kick_member
global discord_ban_member
global discord_lock_channel
global discord_unlock_channel
global discord_set_slowmode
global discord_set_member_timeout
global discord_set_member_timeout_at
global discord_clear_member_timeout
global discord_set_member_nick
global discord_add_member_role
global discord_remove_member_role

extern secure_https_post_json
extern secure_https_delete
extern secure_https_delete_with_header
extern secure_https_get
extern secure_https_put_empty
extern secure_https_put_json
extern secure_https_put_json_with_header
extern secure_https_patch_json
extern json_escape_append
extern discord_token_ptr
extern discord_token_len

%define REQUEST_URL_CAP 256
%define AUTHORIZATION_CAP 512
%define JSON_BODY_CAP 12288
%define RESPONSE_BODY_CAP 4096
%define GET_URL_CAP 512
%define DISCORD_TEXT_MAX 2000
%define AUDIT_REASON_MAX 512
%define AUDIT_HEADER_CAP 544
%define SYS_TIME 201
%define TIMEOUT_MAX_MINUTES 40320
%define TIMEOUT_BODY_CAP 64
%define NICK_BYTES_MAX 128
%define NICK_CHARS_MAX 32
%define CLEAR_FETCH_MIN 2
%define CLEAR_FETCH_MAX 100

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

; RDI=channel, ESI=len, RDX=response, ECX=capacity, R8D=limit (2..100).
; RAX=response bytes only after a bounded authenticated Discord GET. This
; primitive does not parse messages or build delete policy.
; RDI=channel, ESI=channel len, RDX=fixed 64-byte NUL-terminated ID slots,
; ECX=count (2..100). EAX=0 only after an authenticated HTTP 2xx POST.
; Every slot must be a non-empty decimal ID and all IDs must be unique. The
; application payload is constructed here, not in the C transport boundary.
discord_bulk_delete_messages:
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
    test r14, r14
    jz .bad
    test r13d, r13d
    jz .bad
    cmp r13d, 64
    ja .bad
    cmp r15d, 2
    jb .bad
    cmp r15d, CLEAR_FETCH_MAX
    ja .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    mov eax, url_prefix_len
    add eax, r13d
    add eax, bulk_delete_suffix_len
    cmp eax, REQUEST_URL_CAP - 1
    ja .bad
    mov rdi, r14
    mov esi, r15d
    call validate_bulk_message_slots
    test eax, eax
    js .bad

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
    lea rsi, [bulk_delete_suffix]
    mov edx, bulk_delete_suffix_len
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    add rdi, r13
    add rdi, bulk_delete_suffix_len
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

    lea rdi, [json_body]
    lea rsi, [bulk_delete_body_prefix]
    mov edx, bulk_delete_body_prefix_len
    call copy_bytes
    mov ebx, bulk_delete_body_prefix_len
    xor r11d, r11d
.build_ids:
    cmp r11d, r15d
    jae .finish_body
    cmp r11d, 0
    je .open_quote
    cmp ebx, JSON_BODY_CAP - 1
    jae .bad
    mov byte [json_body + rbx], ','
    inc ebx
.open_quote:
    cmp ebx, JSON_BODY_CAP - 1
    jae .bad
    mov byte [json_body + rbx], 0x22
    inc ebx
    mov eax, r11d
    imul rax, 64
    lea rdi, [r14 + rax]
    xor ecx, ecx
.copy_id:
    mov al, [rdi + rcx]
    test al, al
    jz .close_quote
    cmp ebx, JSON_BODY_CAP - 1
    jae .bad
    mov [json_body + rbx], al
    inc ebx
    inc ecx
    cmp ecx, 64
    jb .copy_id
    jmp .bad
.close_quote:
    cmp ebx, JSON_BODY_CAP - 1
    jae .bad
    mov byte [json_body + rbx], 0x22
    inc ebx
    inc r11d
    jmp .build_ids
.finish_body:
    mov eax, ebx
    add eax, bulk_delete_body_suffix_len
    cmp eax, JSON_BODY_CAP - 1
    ja .bad
    mov r10d, eax
    lea rdi, [json_body + rbx]
    lea rsi, [bulk_delete_body_suffix]
    mov edx, bulk_delete_body_suffix_len
    call copy_bytes
    mov ebx, r10d
    mov byte [json_body + rbx], 0
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [json_body]
    mov ecx, ebx
    lea r8, [response_body]
    mov r9d, RESPONSE_BODY_CAP
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

; RDI=fixed 64-byte NUL-terminated decimal-ID slots, ESI=count 2..100.
; EAX=0 only when every ID is bounded and no two slots encode the same ID.
validate_bulk_message_slots:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    xor r14d, r14d
.slot:
    cmp r14d, r13d
    jae .ok
    mov eax, r14d
    imul rax, 64
    lea r15, [r12 + rax]
    xor ebx, ebx
.length:
    cmp ebx, 64
    jae .bad
    cmp byte [r15 + rbx], 0
    je .got_length
    inc ebx
    jmp .length
.got_length:
    test ebx, ebx
    jz .bad
    mov rdi, r15
    mov esi, ebx
    call is_decimal_identifier
    test al, al
    jz .bad
    xor r10d, r10d
.previous:
    cmp r10d, r14d
    jae .next_slot
    mov eax, r10d
    imul rax, 64
    lea rdi, [r12 + rax]
    xor ecx, ecx
.previous_length:
    cmp ecx, 64
    jae .bad
    cmp byte [rdi + rcx], 0
    je .compare_length
    inc ecx
    jmp .previous_length
.compare_length:
    cmp ecx, ebx
    jne .different
    mov rsi, r15
    mov edx, ebx
    call equal_bytes
    test al, al
    jnz .bad
.different:
    inc r10d
    jmp .previous
.next_slot:
    inc r14d
    jmp .slot
.ok:
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

; RDI=channel, ESI=len, RDX=response, ECX=capacity, R8D=limit (2..100).
discord_get_channel_messages:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov ebx, r8d
    test r13d, r13d
    jz .bad
    cmp r13d, 64
    ja .bad
    test r14, r14
    jz .bad
    cmp r15d, 2
    jb .bad
    cmp ebx, CLEAR_FETCH_MIN
    jb .bad
    cmp ebx, CLEAR_FETCH_MAX
    ja .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov eax, url_prefix_len
    add eax, r13d
    add eax, url_suffix_len
    add eax, clear_limit_prefix_len
    add eax, 3
    cmp eax, GET_URL_CAP - 1
    ja .bad
    lea rdi, [get_url]
    lea rsi, [url_prefix]
    mov edx, url_prefix_len
    call copy_bytes
    lea rdi, [get_url + url_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [get_url + url_prefix_len]
    add rdi, r13
    lea rsi, [url_suffix]
    mov edx, url_suffix_len
    call copy_bytes
    lea rdi, [get_url + url_prefix_len]
    add rdi, r13
    add rdi, url_suffix_len
    lea rsi, [clear_limit_prefix]
    mov edx, clear_limit_prefix_len
    call copy_bytes
    lea rdi, [get_url + url_prefix_len]
    add rdi, r13
    add rdi, url_suffix_len
    add rdi, clear_limit_prefix_len
    mov rax, rbx
    call append_uint_decimal
    test eax, eax
    js .bad
    mov edx, eax
    mov eax, url_prefix_len
    add eax, r13d
    add eax, url_suffix_len
    add eax, clear_limit_prefix_len
    add eax, edx
    mov [clear_get_url_len], eax
    mov byte [get_url + rax], 0
    lea rdi, [get_url]
    mov esi, eax
    mov rdx, r14
    mov ecx, r15d
    call discord_get_json
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

; RDI=guild, ESI=guild len, RDX=user, ECX=user len, R8D=minutes.
; EAX=0 only for an authenticated 2xx PATCH. The duration is bounded to
; Discord's 28-day maximum before NASM reads the current Unix time.
discord_set_member_timeout:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov ebx, r8d
    test ebx, ebx
    jle .bad
    cmp ebx, TIMEOUT_MAX_MINUTES
    ja .bad
    mov eax, SYS_TIME
    xor edi, edi
    syscall
    test rax, rax
    jle .bad
    mov r8, rbx
    imul r8, 60
    add rax, r8
    jc .bad
    mov r8, rax
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call discord_set_member_timeout_at
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
; RDI=guild, ESI=guild len, RDX=user, ECX=user len, R8=UTC Unix expiry.
; The deterministic primitive permits exact local vectors without a clock seam.
discord_set_member_timeout_at:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov [timeout_expiry_epoch], r8
    test r8, r8
    jle .bad
    call discord_build_member_patch_route
    test eax, eax
    js .bad
    lea rdi, [timeout_body]
    lea rsi, [timeout_body_prefix]
    mov edx, timeout_body_prefix_len
    call copy_bytes
    lea rdi, [timeout_body + timeout_body_prefix_len]
    mov rax, [timeout_expiry_epoch]
    call format_discord_timestamp
    cmp eax, 20
    jne .bad
    lea rdi, [timeout_body + timeout_body_prefix_len + 20]
    lea rsi, [timeout_body_suffix]
    mov edx, timeout_body_suffix_len
    call copy_bytes
    mov dword [timeout_body_len], timeout_body_prefix_len + 20 + timeout_body_suffix_len
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [timeout_body]
    mov ecx, [timeout_body_len]
    lea r8, [response_body]
    mov r9d, RESPONSE_BODY_CAP
    call call_secure_patch_json
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
; RDI=guild, ESI=guild len, RDX=user, ECX=user len, R8=nick bytes, R9D=len.
; EAX=0 only on HTTP 2xx. UTF-8 validation and JSON construction remain NASM.
discord_set_member_nick:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov [nick_ptr], r8
    mov [nick_len], r9d
    test r8, r8
    jz .bad
    test r9d, r9d
    jle .bad
    cmp r9d, NICK_BYTES_MAX
    ja .bad
    mov rdi, r8
    mov esi, r9d
    call validate_nick_utf8
    test eax, eax
    js .bad
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call discord_build_member_patch_route
    test eax, eax
    js .bad
    lea rdi, [json_body]
    lea rsi, [nick_body_prefix]
    mov edx, nick_body_prefix_len
    call copy_bytes
    lea rdi, [json_body + nick_body_prefix_len]
    mov esi, JSON_BODY_CAP - nick_body_prefix_len - nick_body_suffix_len
    mov rdx, [nick_ptr]
    mov ecx, [nick_len]
    call json_escape_append
    test eax, eax
    js .bad
    mov ebx, eax
    lea rdi, [json_body + nick_body_prefix_len]
    add rdi, rbx
    lea rsi, [nick_body_suffix]
    mov edx, nick_body_suffix_len
    call copy_bytes
    mov eax, ebx
    add eax, nick_body_prefix_len + nick_body_suffix_len
    lea rdi, [json_body]
    mov byte [rdi + rax], 0
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [json_body]
    mov ecx, eax
    lea r8, [response_body]
    mov r9d, RESPONSE_BODY_CAP
    call call_secure_patch_json
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
; RDI=nick bytes, ESI=len. EAX=1..32 characters or -1. It rejects controls,
; overlong sequences, surrogate code points, and Unicode beyond U+10FFFF.
validate_nick_utf8:
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    cmp esi, NICK_BYTES_MAX
    ja .bad
    xor ecx, ecx
    xor edx, edx
.next:
    cmp edx, esi
    jae .done
    movzx eax, byte [rdi + rdx]
    cmp al, 0x20
    jb .bad
    cmp al, 0x7f
    je .bad
    cmp al, 0x80
    jb .ascii
    cmp al, 0xc2
    jb .bad
    cmp al, 0xdf
    jbe .two
    cmp al, 0xe0
    je .three_e0
    cmp al, 0xed
    je .three_ed
    cmp al, 0xef
    jbe .three
    cmp al, 0xf0
    je .four_f0
    cmp al, 0xf4
    je .four_f4
    cmp al, 0xf1
    jb .bad
    cmp al, 0xf3
    jbe .four
    jmp .bad
.ascii:
    inc edx
    jmp .char
.two:
    lea eax, [rdx + 1]
    cmp eax, esi
    jae .bad
    movzx eax, byte [rdi + rdx + 1]
    cmp al, 0x80
    jb .bad
    cmp al, 0xbf
    ja .bad
    add edx, 2
    jmp .char
.three_e0:
    lea eax, [rdx + 2]
    cmp eax, esi
    jae .bad
    movzx eax, byte [rdi + rdx + 1]
    cmp al, 0xa0
    jb .bad
    cmp al, 0xbf
    ja .bad
    jmp .three_last
.three_ed:
    lea eax, [rdx + 2]
    cmp eax, esi
    jae .bad
    movzx eax, byte [rdi + rdx + 1]
    cmp al, 0x80
    jb .bad
    cmp al, 0x9f
    ja .bad
    jmp .three_last
.three:
    lea eax, [rdx + 2]
    cmp eax, esi
    jae .bad
    movzx eax, byte [rdi + rdx + 1]
    cmp al, 0x80
    jb .bad
    cmp al, 0xbf
    ja .bad
.three_last:
    movzx eax, byte [rdi + rdx + 2]
    cmp al, 0x80
    jb .bad
    cmp al, 0xbf
    ja .bad
    add edx, 3
    jmp .char
.four_f0:
    lea eax, [rdx + 3]
    cmp eax, esi
    jae .bad
    movzx eax, byte [rdi + rdx + 1]
    cmp al, 0x90
    jb .bad
    cmp al, 0xbf
    ja .bad
    jmp .four_last
.four_f4:
    lea eax, [rdx + 3]
    cmp eax, esi
    jae .bad
    movzx eax, byte [rdi + rdx + 1]
    cmp al, 0x80
    jb .bad
    cmp al, 0x8f
    ja .bad
    jmp .four_last
.four:
    lea eax, [rdx + 3]
    cmp eax, esi
    jae .bad
    movzx eax, byte [rdi + rdx + 1]
    cmp al, 0x80
    jb .bad
    cmp al, 0xbf
    ja .bad
.four_last:
    movzx eax, byte [rdi + rdx + 2]
    cmp al, 0x80
    jb .bad
    cmp al, 0xbf
    ja .bad
    movzx eax, byte [rdi + rdx + 3]
    cmp al, 0x80
    jb .bad
    cmp al, 0xbf
    ja .bad
    add edx, 4
    jmp .char
.char:
    inc ecx
    cmp ecx, NICK_CHARS_MAX
    ja .bad
    jmp .next
.done:
    test ecx, ecx
    jz .bad
    mov eax, ecx
    ret
.bad:
    mov eax, -1
    ret
; RDI=guild, ESI=guild len, RDX=user, ECX=user len. EAX=0 only on HTTP 2xx.
discord_clear_member_timeout:
    push rbx
    push r12
    push r13
    push r14
    push r15
    call discord_build_member_patch_route
    test eax, eax
    js .bad
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [timeout_clear_body]
    mov ecx, timeout_clear_body_len
    lea r8, [response_body]
    mov r9d, RESPONSE_BODY_CAP
    call call_secure_patch_json
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
; RDI=guild, ESI=guild len, RDX=user, ECX=user len. EAX=0 only when route,
; authorization, and decimal IDs are all bounded and ready for PATCH.
discord_build_member_patch_route:
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
    lea rdi, [request_url + guild_ban_prefix_len]
    add rdi, r13
    add rdi, guild_kick_middle_len
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
; RAX=positive Unix seconds, RDI=20-byte output. EAX=20 or -1.
format_discord_timestamp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rax, rax
    jle .bad
    xor edx, edx
    mov rbx, 86400
    div rbx
    mov r12, rax
    mov rax, rdx
    xor edx, edx
    mov rbx, 3600
    div rbx
    mov [timestamp_hour], eax
    mov rax, rdx
    xor edx, edx
    mov rbx, 60
    div rbx
    mov [timestamp_minute], eax
    mov [timestamp_second], edx
    mov rax, r12
    add rax, 719468
    xor edx, edx
    mov rbx, 146097
    div rbx
    mov r8d, eax
    mov r9d, edx
    mov eax, r9d
    xor edx, edx
    mov ecx, 1460
    div ecx
    mov r10d, eax
    mov eax, r9d
    xor edx, edx
    mov ecx, 36524
    div ecx
    mov r11d, eax
    mov eax, r9d
    xor edx, edx
    mov ecx, 146096
    div ecx
    mov r12d, eax
    mov eax, r9d
    sub eax, r10d
    add eax, r11d
    sub eax, r12d
    xor edx, edx
    mov ecx, 365
    div ecx
    mov r13d, eax
    imul r8d, r8d, 400
    add r13d, r8d
    mov eax, r13d
    sub eax, r8d
    imul eax, eax, 365
    mov r10d, eax
    mov eax, r13d
    sub eax, r8d
    xor edx, edx
    mov ecx, 4
    div ecx
    add r10d, eax
    mov eax, r13d
    sub eax, r8d
    xor edx, edx
    mov ecx, 100
    div ecx
    sub r10d, eax
    mov eax, r9d
    sub eax, r10d
    mov r9d, eax
    imul eax, r9d, 5
    add eax, 2
    xor edx, edx
    mov ecx, 153
    div ecx
    mov r10d, eax
    imul eax, r10d, 153
    add eax, 2
    xor edx, edx
    mov ecx, 5
    div ecx
    mov r11d, r9d
    sub r11d, eax
    inc r11d
    mov r12d, r10d
    cmp r12d, 10
    jb .month_early
    sub r12d, 9
    jmp .month_ready
.month_early:
    add r12d, 3
.month_ready:
    cmp r12d, 2
    ja .year_ready
    inc r13d
.year_ready:
    cmp r13d, 9999
    ja .bad
    mov eax, r13d
    call write_four_decimal
    mov byte [rdi], '-'
    inc rdi
    mov eax, r12d
    call write_two_decimal
    mov byte [rdi], '-'
    inc rdi
    mov eax, r11d
    call write_two_decimal
    mov byte [rdi], 'T'
    inc rdi
    mov eax, [timestamp_hour]
    call write_two_decimal
    mov byte [rdi], ':'
    inc rdi
    mov eax, [timestamp_minute]
    call write_two_decimal
    mov byte [rdi], ':'
    inc rdi
    mov eax, [timestamp_second]
    call write_two_decimal
    mov byte [rdi], 'Z'
    mov eax, 20
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
; EAX=0..99, RDI=dest. RDI advances by 2.
write_two_decimal:
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi], al
    add dl, '0'
    mov [rdi + 1], dl
    add rdi, 2
    ret
; EAX=0..9999, RDI=dest. RDI advances by 4.
write_four_decimal:
    xor edx, edx
    mov ecx, 1000
    div ecx
    add al, '0'
    mov [rdi], al
    mov eax, edx
    xor edx, edx
    mov ecx, 100
    div ecx
    add al, '0'
    mov [rdi + 1], al
    mov eax, edx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi + 2], al
    add dl, '0'
    mov [rdi + 3], dl
    add rdi, 4
    ret
; RDI=channel ID, ESI=len, RDX=seconds (0..21600). EAX=0 on HTTP 2xx.
discord_set_slowmode:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    test r13d, r13d
    jz .bad
    cmp r13d, 64
    ja .bad
    cmp r14, 21600
    ja .bad
    cmp dword [discord_token_len], 0
    je .bad
    mov rdi, r12
    mov esi, r13d
    call is_decimal_identifier
    test al, al
    jz .bad
    mov eax, [discord_token_len]
    add eax, authorization_prefix_len
    cmp eax, AUTHORIZATION_CAP - 1
    ja .bad
    mov eax, url_prefix_len
    add eax, r13d
    cmp eax, REQUEST_URL_CAP - 1
    ja .bad
    mov [guild_ban_url_len], rax
    lea rdi, [request_url]
    lea rsi, [url_prefix]
    mov edx, url_prefix_len
    call copy_bytes
    lea rdi, [request_url + url_prefix_len]
    mov rsi, r12
    mov edx, r13d
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
    lea rdi, [slowmode_body]
    lea rsi, [slowmode_body_prefix]
    mov edx, slowmode_body_prefix_len
    call copy_bytes
    lea rdi, [slowmode_body + slowmode_body_prefix_len]
    mov rax, r14
    call append_uint_decimal
    test eax, eax
    js .bad
    mov ebx, eax
    lea rdi, [slowmode_body + slowmode_body_prefix_len]
    add rdi, rbx
    lea rsi, [slowmode_body_suffix]
    mov edx, slowmode_body_suffix_len
    call copy_bytes
    mov eax, ebx
    add eax, slowmode_body_prefix_len + slowmode_body_suffix_len
    mov [slowmode_body_len], eax
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [slowmode_body]
    mov ecx, eax
    lea r8, [response_body]
    mov r9d, RESPONSE_BODY_CAP
    call call_secure_patch_json
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
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RAX=value (0..21600), RDI=destination. EAX=decimal length.
append_uint_decimal:
    mov r9, rdi
    xor ecx, ecx
    cmp rax, 0
    jne .collect
    mov byte [rdi], '0'
    mov eax, 1
    ret
.collect:
    xor edx, edx
    mov r8, 10
    div r8
    push rdx
    inc ecx
    test rax, rax
    jnz .collect
.write:
    pop rdx
    add dl, '0'
    mov [rdi], dl
    inc rdi
    dec ecx
    jnz .write
    mov rax, rdi
    sub rax, r9
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

; RDI=guild ID, ESI=guild len, RDX=user ID, ECX=user len, R8=reason, R9D=len.
; EAX=0 only for Discord HTTP 2xx. The bounded UTF-8 reason is RFC3986-encoded
; into the audit header entirely in NASM; dispatch verifies target hierarchy.
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
    mov [audit_reason_ptr], r8
    mov [audit_reason_len], r9d
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
    mov rdi, [audit_reason_ptr]
    mov esi, [audit_reason_len]
    call build_audit_reason_header
    test eax, eax
    js .bad
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [audit_reason_header]
    lea rcx, [response_body]
    mov r8d, RESPONSE_BODY_CAP
    lea r9, [response_status]
    call secure_https_delete_with_header
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

; RDI=guild ID, ESI=guild len, RDX=user ID, ECX=user len, R8=reason, R9D=len.
; EAX=0 only for Discord HTTP 2xx. Dispatch validates target hierarchy before
; this route; NASM creates the bounded audit header before transport.
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
    mov [audit_reason_ptr], r8
    mov [audit_reason_len], r9d
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
    mov rdi, [audit_reason_ptr]
    mov esi, [audit_reason_len]
    call build_audit_reason_header
    test eax, eax
    js .bad
    lea rdi, [request_url]
    lea rsi, [authorization]
    lea rdx, [audit_reason_header]
    lea rcx, [ban_body]
    mov r8d, ban_body_len
    lea r9, [response_body]
    call call_secure_put_json_with_header
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
    mov byte [role_remove_mode], 0
    jmp discord_member_role_route

; Same validated endpoint as add-role, but DELETEs the exact member role.
discord_remove_member_role:
    mov byte [role_remove_mode], 1

discord_member_role_route:
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
    cmp byte [role_remove_mode], 1
    je .delete_role
    lea rdx, [response_body]
    mov ecx, RESPONSE_BODY_CAP
    call call_secure_put
    jmp .transport_done
.delete_role:
    lea rdx, [response_body]
    mov ecx, RESPONSE_BODY_CAP
    lea r8, [response_status]
    call secure_https_delete
.transport_done:
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

; Wrapper keeps the seventh status pointer on the System V stack.
call_secure_patch_json:
    sub rsp, 8
    lea rax, [response_status]
    mov [rsp], rax
    call secure_https_patch_json
    add rsp, 8
    ret

; Wrapper keeps the seventh status pointer on the System V stack.
call_secure_put_json:
    sub rsp, 8
    lea rax, [response_status]
    mov [rsp], rax
    call secure_https_put_json
    add rsp, 8
    ret
; RDI URL, RSI auth, RDX extra header, RCX JSON body, R8 body length,
; R9 response. The seventh capacity and eighth status pointer are placed on
; the System V stack with 16-byte call alignment.
call_secure_put_json_with_header:
    sub rsp, 24
    mov qword [rsp], RESPONSE_BODY_CAP
    lea rax, [response_status]
    mov [rsp + 8], rax
    call secure_https_put_json_with_header
    add rsp, 24
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

; RDI=reason bytes, ESI=len. EAX=0 and audit_reason_header populated only
; for a bounded RFC3986 header. Empty input preserves the Go source default.
build_audit_reason_header:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    test r12, r12
    jz .default
    test r13d, r13d
    jz .default
    cmp r13d, AUDIT_REASON_MAX
    ja .bad
.begin:
    lea rdi, [audit_reason_header]
    lea rsi, [audit_reason_prefix]
    mov edx, audit_reason_prefix_len
    call copy_bytes
    mov ebx, audit_reason_prefix_len
    xor r14d, r14d
.encode:
    cmp r14d, r13d
    jae .done
    movzx eax, byte [r12 + r14]
    cmp al, 'A'
    jb .lower
    cmp al, 'Z'
    jbe .plain
.lower:
    cmp al, 'a'
    jb .digit
    cmp al, 'z'
    jbe .plain
.digit:
    cmp al, '0'
    jb .symbol
    cmp al, '9'
    jbe .plain
.symbol:
    cmp al, '-'
    je .plain
    cmp al, '.'
    je .plain
    cmp al, '_'
    je .plain
    cmp al, '~'
    je .plain
    lea ecx, [ebx + 3]
    sub ecx, audit_reason_prefix_len
    cmp ecx, AUDIT_REASON_MAX
    ja .bad
    mov byte [audit_reason_header + rbx], '%'
    mov ecx, eax
    shr ecx, 4
    and eax, 15
    lea rdx, [hex_upper]
    mov cl, [rdx + rcx]
    mov [audit_reason_header + rbx + 1], cl
    mov al, [rdx + rax]
    mov [audit_reason_header + rbx + 2], al
    add ebx, 3
    inc r14d
    jmp .encode
.plain:
    lea ecx, [ebx + 1]
    sub ecx, audit_reason_prefix_len
    cmp ecx, AUDIT_REASON_MAX
    ja .bad
    mov [audit_reason_header + rbx], al
    inc ebx
    inc r14d
    jmp .encode
.done:
    mov byte [audit_reason_header + rbx], 0
    xor eax, eax
    jmp .out
.default:
    lea r12, [audit_reason_default]
    mov r13d, audit_reason_default_len
    jmp .begin
.bad:
    mov eax, -1
.out:
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
clear_limit_prefix: db '?limit='
clear_limit_prefix_len equ $ - clear_limit_prefix
bulk_delete_suffix: db '/messages/bulk-delete'
bulk_delete_suffix_len equ $ - bulk_delete_suffix
bulk_delete_body_prefix: db '{"messages":['
bulk_delete_body_prefix_len equ $ - bulk_delete_body_prefix
bulk_delete_body_suffix: db ']}'
bulk_delete_body_suffix_len equ $ - bulk_delete_body_suffix
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
audit_reason_prefix: db 'X-Audit-Log-Reason: '
audit_reason_prefix_len equ $ - audit_reason_prefix
audit_reason_default: db 'Tidak ada alasan'
audit_reason_default_len equ $ - audit_reason_default
hex_upper: db '0123456789ABCDEF'
json_prefix: db '{"content":"'
json_prefix_len equ $ - json_prefix
json_suffix: db '"}'
json_suffix_len equ $ - json_suffix
ban_body: db '{"delete_message_seconds":0}'
ban_body_len equ $ - ban_body
lock_body: db '{"type":0,"allow":"0","deny":"2048"}'
lock_body_len equ $ - lock_body
slowmode_body_prefix: db '{"rate_limit_per_user":'
slowmode_body_prefix_len equ $ - slowmode_body_prefix
slowmode_body_suffix: db '}'
slowmode_body_suffix_len equ $ - slowmode_body_suffix
timeout_body_prefix: db '{"communication_disabled_until":"'
timeout_body_prefix_len equ $ - timeout_body_prefix
timeout_body_suffix: db '"}'
timeout_body_suffix_len equ $ - timeout_body_suffix
timeout_clear_body: db '{"communication_disabled_until":null}'
timeout_clear_body_len equ $ - timeout_clear_body
nick_body_prefix: db '{"nick":"'
nick_body_prefix_len equ $ - nick_body_prefix
nick_body_suffix: db '"}'
nick_body_suffix_len equ $ - nick_body_suffix

section .data
response_status: dq 0
role_id_ptr: dq 0
role_id_len: dd 0
role_remove_mode: db 0
guild_ban_url_len: dq 0
channel_permission_mode: db 0
slowmode_body_len: dd 0
timeout_body_len: dd 0
timestamp_hour: dd 0
timestamp_minute: dd 0
timestamp_second: dd 0
timeout_expiry_epoch: dq 0
nick_ptr: dq 0
nick_len: dd 0
clear_get_url_len: dd 0
audit_reason_ptr: dq 0
audit_reason_len: dd 0
section .bss

request_url: resb REQUEST_URL_CAP
get_url: resb GET_URL_CAP
authorization: resb AUTHORIZATION_CAP
json_body: resb JSON_BODY_CAP
response_body: resb RESPONSE_BODY_CAP
slowmode_body: resb 64
timeout_body: resb TIMEOUT_BODY_CAP
audit_reason_header: resb AUDIT_HEADER_CAP

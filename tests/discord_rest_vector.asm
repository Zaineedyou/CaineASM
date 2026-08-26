BITS 64
DEFAULT REL

extern discord_send_text
extern discord_delete_message
extern discord_get_json
extern discord_unban_member
extern discord_kick_member
extern discord_ban_member
extern discord_lock_channel
extern discord_unlock_channel
extern discord_set_slowmode
extern discord_set_member_timeout
extern discord_set_member_timeout_at
extern discord_clear_member_timeout
extern discord_add_member_role
extern discord_remove_member_role
extern json_escape_append

global _start
global secure_https_post_json
global secure_https_delete
global secure_https_delete_with_header
global secure_https_get
global secure_https_put_empty
global secure_https_put_json
global secure_https_put_json_with_header
global secure_https_patch_json
global discord_token_ptr
global discord_token_len

%define SYS_EXIT 60

section .text
_start:
    lea rax, [token]
    mov [discord_token_ptr], rax
    mov dword [discord_token_len], token_len
    mov qword [mock_status], 201
    mov qword [mock_calls], 0
    mov dword [mock_failure_reason], 0
    lea rax, [expected_unban_url]
    mov [expected_put_url_ptr], rax
    mov dword [expected_put_url_len], expected_unban_url_len
    lea rax, [ban_body]
    mov [expected_put_body_ptr], rax
    mov dword [expected_put_body_len], ban_body_len
    lea rax, [expected_delete_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_delete_url_len
    lea rax, [expected_slowmode_url]
    mov [expected_patch_url_ptr], rax
    mov dword [expected_patch_url_len], expected_slowmode_url_len

    mov dword [failure_stage], 1
    ; Direct helper coverage: all JSON-sensitive bytes are escaped boundedly.
    lea rdi, [escape_output]
    mov esi, 64
    lea rdx, [message_text]
    mov ecx, message_text_len
    call json_escape_append
    cmp eax, escaped_text_len
    jne .fail
    lea rdi, [escape_output]
    lea rsi, [escaped_text]
    mov edx, escaped_text_len
    call equal_bytes
    test al, al
    jz .fail

    lea rdi, [escape_output]
    xor esi, esi
    lea rdx, [message_text]
    mov ecx, message_text_len
    call json_escape_append
    cmp eax, -1
    jne .fail

    mov dword [failure_stage], 2
    ; The full Discord request must use URL, bot authorization, escaped JSON,
    ; and a 2xx response status delivered through the seventh C ABI argument.
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_text]
    mov ecx, message_text_len
    call discord_send_text
    test eax, eax
    jnz .fail
    cmp qword [mock_calls], 1
    jne .fail

    mov dword [failure_stage], 3
    ; Non-2xx statuses propagate as a failure even when transport succeeds.
    mov qword [mock_status], 429
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_text]
    mov ecx, message_text_len
    call discord_send_text
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 2
    jne .fail

    mov dword [failure_stage], 4
    ; Invalid channel identifiers and over-limit text must not reach transport.
    lea rdi, [invalid_channel]
    mov esi, invalid_channel_len
    lea rdx, [message_text]
    mov ecx, message_text_len
    call discord_send_text
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 2
    jne .fail

    mov dword [failure_stage], 5
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [oversized_text]
    mov ecx, oversized_text_len
    call discord_send_text
    cmp eax, -1
    jne .fail
    cmp qword [mock_calls], 2
    jne .fail

    mov dword [failure_stage], 6
    mov qword [delete_status], 204
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_id]
    mov ecx, message_id_len
    call discord_delete_message
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 1
    jne .fail

    mov dword [failure_stage], 7
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [invalid_channel]
    mov ecx, invalid_channel_len
    call discord_delete_message
    cmp eax, -1
    jne .fail
    cmp qword [delete_calls], 1
    jne .fail

    mov dword [failure_stage], 75
    mov qword [delete_status], 204
    lea rax, [expected_unban_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_unban_url_len
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    call discord_unban_member
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 2
    jne .fail

    mov dword [failure_stage], 755
    mov qword [delete_status], 204
    lea rax, [expected_kick_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_kick_url_len
    lea rax, [expected_audit_header_reason]
    mov [expected_audit_header_ptr], rax
    mov dword [expected_audit_header_len], expected_audit_header_reason_len
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    lea r8, [audit_reason]
    mov r9d, audit_reason_len
    call discord_kick_member
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 2
    jne .fail
    cmp qword [audit_delete_calls], 1
    jne .fail
    lea rax, [expected_unban_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_unban_url_len

    mov dword [failure_stage], 756
    mov qword [put_status], 204
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    lea r8, [audit_reason]
    mov r9d, audit_reason_len
    call discord_ban_member
    test eax, eax
    jnz .fail
    cmp qword [put_json_calls], 0
    jne .fail
    cmp qword [audit_put_json_calls], 1
    jne .fail

    ; Empty reason preserves the source default and still reaches the exact
    ; audit-header transport path, while overlong input must stop beforehand.
    mov dword [failure_stage], 7561
    lea rax, [expected_audit_header_default]
    mov [expected_audit_header_ptr], rax
    mov dword [expected_audit_header_len], expected_audit_header_default_len
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    xor r8d, r8d
    xor r9d, r9d
    call discord_kick_member
    test eax, eax
    jnz .fail
    cmp qword [audit_delete_calls], 2
    jne .fail

    mov dword [failure_stage], 7562
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    lea r8, [audit_reason_too_long]
    mov r9d, audit_reason_too_long_len
    call discord_kick_member
    cmp eax, -1
    jne .fail
    cmp qword [audit_delete_calls], 2
    jne .fail

    mov dword [failure_stage], 7563
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    lea r8, [audit_reason_encoded_too_long]
    mov r9d, audit_reason_encoded_too_long_len
    call discord_kick_member
    cmp eax, -1
    jne .fail
    cmp qword [audit_delete_calls], 2
    jne .fail

    mov dword [failure_stage], 757
    lea rax, [expected_lock_url]
    mov [expected_put_url_ptr], rax
    mov dword [expected_put_url_len], expected_lock_url_len
    lea rax, [lock_body]
    mov [expected_put_body_ptr], rax
    mov dword [expected_put_body_len], lock_body_len
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [guild_id]
    mov ecx, guild_id_len
    call discord_lock_channel
    test eax, eax
    jnz .fail
    cmp qword [put_json_calls], 1
    jne .fail

    mov dword [failure_stage], 758
    lea rax, [expected_lock_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_lock_url_len
    mov qword [delete_status], 204
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [guild_id]
    mov ecx, guild_id_len
    call discord_unlock_channel
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 3
    jne .fail
    lea rax, [expected_unban_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_unban_url_len

    mov dword [failure_stage], 759
    lea rax, [slowmode_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], slowmode_body_len
    mov qword [patch_status], 200
    lea rdi, [channel_id]
    mov esi, channel_id_len
    mov edx, 15
    call discord_set_slowmode
    test eax, eax
    jnz .fail
    cmp qword [patch_calls], 1
    jne .fail

    mov dword [failure_stage], 760
    lea rax, [slowmode_zero_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], slowmode_zero_body_len
    lea rdi, [channel_id]
    mov esi, channel_id_len
    xor edx, edx
    call discord_set_slowmode
    test eax, eax
    jnz .fail
    cmp qword [patch_calls], 2
    jne .fail

    mov dword [failure_stage], 761
    lea rax, [slowmode_max_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], slowmode_max_body_len
    lea rdi, [channel_id]
    mov esi, channel_id_len
    mov edx, 21600
    call discord_set_slowmode
    test eax, eax
    jnz .fail
    cmp qword [patch_calls], 3
    jne .fail

    mov dword [failure_stage], 762
    lea rdi, [channel_id]
    mov esi, channel_id_len
    mov edx, 21601
    call discord_set_slowmode
    cmp eax, -1
    jne .fail
    cmp qword [patch_calls], 3
    jne .fail

    mov dword [failure_stage], 763
    lea rax, [slowmode_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], slowmode_body_len
    mov qword [patch_status], 429
    lea rdi, [channel_id]
    mov esi, channel_id_len
    mov edx, 15
    call discord_set_slowmode
    cmp eax, -1
    jne .fail
    cmp qword [patch_calls], 4
    jne .fail
    mov qword [patch_status], 200

    ; Timeout PATCH uses the exact guild-member route and a UTC ISO-8601 body;
    ; untimeout sends JSON null. Both retain the same bounded PATCH boundary.
    mov dword [failure_stage], 764
    lea rax, [expected_member_url]
    mov [expected_patch_url_ptr], rax
    mov dword [expected_patch_url_len], expected_member_url_len
    lea rax, [timeout_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], timeout_body_len
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    mov r8, 1787747696
    call discord_set_member_timeout_at
    test eax, eax
    jnz .fail
    cmp qword [patch_calls], 5
    jne .fail

    mov dword [failure_stage], 7641
    lea rax, [timeout_leap_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], timeout_leap_body_len
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    mov r8, 1709251199
    call discord_set_member_timeout_at
    test eax, eax
    jnz .fail
    cmp qword [patch_calls], 6
    jne .fail

    mov dword [failure_stage], 765
    lea rax, [timeout_clear_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], timeout_clear_body_len
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    call discord_clear_member_timeout
    test eax, eax
    jnz .fail
    cmp qword [patch_calls], 7
    jne .fail

    mov dword [failure_stage], 766
    mov qword [patch_status], 429
    lea rax, [timeout_body]
    mov [expected_patch_body_ptr], rax
    mov dword [expected_patch_body_len], timeout_body_len
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    mov r8, 1787747696
    call discord_set_member_timeout_at
    cmp eax, -1
    jne .fail
    cmp qword [patch_calls], 8
    jne .fail
    mov qword [patch_status], 200

    mov dword [failure_stage], 767
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    xor r8d, r8d
    call discord_set_member_timeout_at
    cmp eax, -1
    jne .fail
    cmp qword [patch_calls], 8
    jne .fail

    lea rax, [expected_slowmode_url]
    mov [expected_patch_url_ptr], rax
    mov dword [expected_patch_url_len], expected_slowmode_url_len

    mov dword [failure_stage], 76
    mov qword [delete_status], 403
    lea rdi, [guild_id]
    mov esi, guild_id_len
    lea rdx, [user_id]
    mov ecx, user_id_len
    call discord_unban_member
    cmp eax, -1
    jne .fail
    cmp qword [delete_calls], 4
    jne .fail
    mov qword [delete_status], 204
    lea rax, [expected_delete_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_delete_url_len

    mov dword [failure_stage], 8
    mov qword [get_status], 200
    lea rdi, [expected_get_url]
    mov esi, expected_get_url_len
    lea rdx, [get_response]
    mov ecx, 16
    call discord_get_json
    mov dword [failure_stage], 81
    cmp rax, get_payload_len
    jne .fail
    cmp qword [get_calls], 1
    jne .fail
    mov dword [failure_stage], 82
    lea rdi, [get_response]
    lea rsi, [get_payload]
    mov edx, get_payload_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [failure_stage], 9
    mov qword [get_status], 403
    lea rdi, [expected_get_url]
    mov esi, expected_get_url_len
    lea rdx, [get_response]
    mov ecx, 16
    call discord_get_json
    cmp rax, -1
    jne .fail
    cmp qword [get_calls], 2
    jne .fail

    mov dword [failure_stage], 10
    mov qword [put_status], 204
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_id]
    mov ecx, message_id_len
    lea r8, [role_id]
    mov r9d, role_id_len
    call discord_add_member_role
    test eax, eax
    jnz .fail
    cmp qword [put_calls], 1
    jne .fail

    mov dword [failure_stage], 11
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_id]
    mov ecx, message_id_len
    lea r8, [invalid_channel]
    mov r9d, invalid_channel_len
    call discord_add_member_role
    cmp eax, -1
    jne .fail
    cmp qword [put_calls], 1
    jne .fail

    mov dword [failure_stage], 115
    mov qword [delete_calls], 0
    mov qword [delete_status], 204
    lea rax, [expected_role_url]
    mov [expected_delete_ptr], rax
    mov dword [expected_delete_len], expected_role_url_len
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_id]
    mov ecx, message_id_len
    lea r8, [role_id]
    mov r9d, role_id_len
    call discord_remove_member_role
    test eax, eax
    jnz .fail
    cmp qword [delete_calls], 1
    jne .fail

    mov dword [failure_stage], 116
    lea rdi, [channel_id]
    mov esi, channel_id_len
    lea rdx, [message_id]
    mov ecx, message_id_len
    lea r8, [invalid_channel]
    mov r9d, invalid_channel_len
    call discord_remove_member_role
    cmp eax, -1
    jne .fail
    cmp qword [delete_calls], 1
    jne .fail

    mov dword [failure_stage], 12
    lea rdi, [bad_get_url]
    mov esi, bad_get_url_len
    lea rdx, [get_response]
    mov ecx, 16
    call discord_get_json
    cmp rax, -1
    jne .fail
    cmp qword [get_calls], 2
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov edi, [mock_failure_reason]
    test edi, edi
    jnz .fail_exit
    mov edi, [failure_stage]
.fail_exit:
    mov eax, SYS_EXIT
    syscall

; NASM mock for the sole external transport boundary.
; RDI=url, RSI=authorization, RDX=body, RCX=body length,
; R8=response, R9=response capacity, [RSP+16]=long *status_out after saved RBX.
secure_https_post_json:
    push rbx
    mov rbx, rdx
    lea r10, [expected_url]
    mov r11d, expected_url_len
    call equal_cstring
    test al, al
    jnz .url_ok
    mov dword [mock_failure_reason], 21
    jmp .transport_fail
.url_ok:
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jnz .authorization_ok
    mov dword [mock_failure_reason], 22
    jmp .transport_fail
.authorization_ok:
    cmp ecx, expected_body_len
    je .length_ok
    mov dword [mock_failure_reason], 23
    jmp .transport_fail
.length_ok:
    mov rdi, rbx
    lea rsi, [expected_body]
    mov edx, expected_body_len
    call equal_bytes
    test al, al
    jnz .body_ok
    mov dword [mock_failure_reason], 24
    jmp .transport_fail
.body_ok:
    cmp r9, 2
    jae .capacity_ok
    mov dword [mock_failure_reason], 25
    jmp .transport_fail
.capacity_ok:
    mov byte [r8], 0
    mov r10, [rsp + 16]
    test r10, r10
    jnz .status_pointer_ok
    mov dword [mock_failure_reason], 26
    jmp .transport_fail
.status_pointer_ok:
    mov rax, [mock_status]
    mov [r10], rax
    inc qword [mock_calls]
    mov eax, 1
    pop rbx
    ret
.transport_fail:
    mov eax, -1
    pop rbx
    ret

; RDI=url, RSI=authorization, RDX=response, RCX=response cap, R8=status out.
secure_https_delete:
    mov r10, [expected_delete_ptr]
    mov r11d, [expected_delete_len]
    call equal_cstring
    test al, al
    jz .delete_fail
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jz .delete_fail
    cmp rcx, 2
    jb .delete_fail
    test r8, r8
    jz .delete_fail
    mov byte [rdx], 0
    mov rax, [delete_status]
    mov [r8], rax
    inc qword [delete_calls]
    xor eax, eax
    ret
.delete_fail:
    mov eax, -1
    ret

; RDI=url, RSI=authorization, RDX=extra header, RCX=response, R8=capacity,
; R9=status out. It carries opaque headers only; audit formatting stays NASM.
secure_https_delete_with_header:
    push rbx
    push r12
    push r13
    mov rbx, rdx
    mov r12, rcx
    mov r13, r9
    lea r10, [expected_kick_url]
    mov r11d, expected_kick_url_len
    call equal_cstring
    test al, al
    jz .audit_delete_fail
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jz .audit_delete_fail
    mov rdi, rbx
    mov r10, [expected_audit_header_ptr]
    mov r11d, [expected_audit_header_len]
    call equal_cstring
    test al, al
    jz .audit_delete_fail
    cmp r8d, 2
    jb .audit_delete_fail
    test r13, r13
    jz .audit_delete_fail
    mov byte [r12], 0
    mov rax, [delete_status]
    mov [r13], rax
    inc qword [audit_delete_calls]
    xor eax, eax
    jmp .audit_delete_out
.audit_delete_fail:
    mov eax, -1
.audit_delete_out:
    pop r13
    pop r12
    pop rbx
    ret
; RDI=url, RSI=authorization, RDX=response, RCX=response cap, R8=status out.
secure_https_get:
    push rbx
    mov rbx, rdx
    lea r10, [expected_get_url]
    mov r11d, expected_get_url_len
    call equal_cstring
    test al, al
    jz .get_fail
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jz .get_fail
    cmp rcx, get_payload_len + 1
    jb .get_fail
    test r8, r8
    jz .get_fail
    mov r9, rbx
    lea rsi, [get_payload]
    mov edx, get_payload_len
    mov rdi, r9
    call copy_bytes
    mov byte [rdi + rdx], 0
    mov rax, [get_status]
    mov [r8], rax
    inc qword [get_calls]
    mov eax, get_payload_len
    pop rbx
    ret
.get_fail:
    mov dword [mock_failure_reason], 31
    mov eax, -1
    pop rbx
    ret

; RDI=url, RSI=authorization, RDX=JSON body, RCX=len, R8=response, R9=cap,
; [RSP+8]=status out.
secure_https_patch_json:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdx
    mov r12, r8
    mov r13, r9
    mov r14, [rsp + 48]
    mov r15d, ecx
    mov r10, [expected_patch_url_ptr]
    mov r11d, [expected_patch_url_len]
    call equal_cstring
    test al, al
    jnz .patch_url_ok
    mov dword [mock_failure_reason], 61
    jmp .patch_fail
.patch_url_ok:
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jnz .patch_auth_ok
    mov dword [mock_failure_reason], 62
    jmp .patch_fail
.patch_auth_ok:
    cmp r15d, [expected_patch_body_len]
    je .patch_len_ok
    mov dword [mock_failure_reason], 63
    jmp .patch_fail
.patch_len_ok:
    mov rdi, rbx
    mov rsi, [expected_patch_body_ptr]
    mov edx, [expected_patch_body_len]
    call equal_bytes
    test al, al
    jnz .patch_body_ok
    mov dword [mock_failure_reason], 64
    jmp .patch_fail
.patch_body_ok:
    cmp r13d, 2
    jae .patch_cap_ok
    mov dword [mock_failure_reason], 65
    jmp .patch_fail
.patch_cap_ok:
    test r14, r14
    jnz .patch_status_ok
    mov dword [mock_failure_reason], 66
    jmp .patch_fail
.patch_status_ok:
    mov byte [r12], 0
    mov rax, [patch_status]
    mov [r14], rax
    inc qword [patch_calls]
    xor eax, eax
    jmp .patch_done
.patch_fail:
    mov eax, -1
.patch_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=url, RSI=authorization, RDX=JSON body, RCX=len, R8=response, R9=cap,
; [RSP+8]=status out.
secure_https_put_json:
    mov [put_json_body_ptr], rdx
    mov r10, [expected_put_url_ptr]
    mov r11d, [expected_put_url_len]
    call equal_cstring
    test al, al
    jnz .put_json_url_ok
    mov dword [failure_stage], 758
    jmp .put_json_fail
.put_json_url_ok:
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jnz .put_json_auth_ok
    mov dword [failure_stage], 759
    jmp .put_json_fail
.put_json_auth_ok:
    cmp ecx, [expected_put_body_len]
    je .put_json_body_len_ok
    mov dword [failure_stage], 760
    jmp .put_json_fail
.put_json_body_len_ok:
    mov rdi, [put_json_body_ptr]
    mov rsi, [expected_put_body_ptr]
    mov edx, [expected_put_body_len]
    call equal_bytes
    test al, al
    jnz .put_json_body_ok
    mov dword [failure_stage], 761
    jmp .put_json_fail
.put_json_body_ok:
    cmp r9d, 2
    jae .put_json_cap_ok
    mov dword [failure_stage], 762
    jmp .put_json_fail
.put_json_cap_ok:
    mov r10, [rsp + 8]
    test r10, r10
    jnz .put_json_status_ok
    mov dword [failure_stage], 763
    jmp .put_json_fail
.put_json_status_ok:
    mov byte [r8], 0
    mov rax, [put_status]
    mov [r10], rax
    inc qword [put_json_calls]
    xor eax, eax
    ret
.put_json_fail:
    cmp dword [failure_stage], 757
    jne .put_json_fail_code_ready
    mov dword [failure_stage], 757
.put_json_fail_code_ready:
    mov eax, -1
    ret

; RDI=url, RSI=authorization, RDX=extra header, RCX=JSON body, R8=len,
; R9=response, [RSP+8]=capacity, [RSP+16]=status out.
secure_https_put_json_with_header:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdx
    mov r12, rcx
    mov r13d, r8d
    mov r14, r9
    mov r15, [rsp + 48]
    mov r8, [rsp + 56]
    lea r10, [expected_unban_url]
    mov r11d, expected_unban_url_len
    call equal_cstring
    test al, al
    jz .audit_put_fail
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jz .audit_put_fail
    mov rdi, rbx
    mov r10, [expected_audit_header_ptr]
    mov r11d, [expected_audit_header_len]
    call equal_cstring
    test al, al
    jz .audit_put_fail
    cmp r13d, ban_body_len
    jne .audit_put_fail
    mov rdi, r12
    lea rsi, [ban_body]
    mov edx, ban_body_len
    call equal_bytes
    test al, al
    jz .audit_put_fail
    cmp r15d, 2
    jb .audit_put_fail
    test r8, r8
    jz .audit_put_fail
    mov byte [r14], 0
    mov rax, [put_status]
    mov [r8], rax
    inc qword [audit_put_json_calls]
    xor eax, eax
    jmp .audit_put_out
.audit_put_fail:
    mov eax, -1
.audit_put_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
; RDI=url, RSI=authorization, RDX=response, RCX=response cap, [RSP+8]=status out.
secure_https_put_empty:
    lea r10, [expected_role_url]
    mov r11d, expected_role_url_len
    call equal_cstring
    test al, al
    jz .put_fail
    mov rdi, rsi
    lea r10, [expected_authorization]
    mov r11d, expected_authorization_len
    call equal_cstring
    test al, al
    jz .put_fail
    cmp rcx, 2
    jb .put_fail
    mov byte [rdx], 0
    mov r10, [rsp + 8]
    test r10, r10
    jz .put_fail
    mov rax, [put_status]
    mov [r10], rax
    inc qword [put_calls]
    xor eax, eax
    ret
.put_fail:
    mov eax, -1
    ret

; RDI=C string; R10=expected bytes; R11D=expected len. AL=1 on exact match.
equal_cstring:
    xor eax, eax
.loop:
    cmp eax, r11d
    jae .terminator
    mov dl, [rdi + rax]
    cmp dl, [r10 + rax]
    jne .no
    inc eax
    jmp .loop
.terminator:
    cmp byte [rdi + rax], 0
    jne .no
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

; RDI and RSI buffers, EDX count. AL=1 when equal.
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
token: db 'token-value'
token_len equ $ - token
channel_id: db '123456789012345678'
channel_id_len equ $ - channel_id
invalid_channel: db '12x'
invalid_channel_len equ $ - invalid_channel
message_text: db 'say ', '"', 'hi', '"', ' ', 0x5c, ' L', 10, 'T', 9, 'C', 1
message_text_len equ $ - message_text
escaped_text: db 'say ', 0x5c, '"', 'hi', 0x5c, '"', ' ', 0x5c, 0x5c, ' L', 0x5c, 'n', 'T', 0x5c, 't', 'C', 0x5c, 'u0001'
escaped_text_len equ $ - escaped_text
expected_url: db 'https://discord.com/api/v10/channels/123456789012345678/messages'
expected_url_len equ $ - expected_url
message_id: db '987654321098765432'
message_id_len equ $ - message_id
role_id: db '111222333444555666'
role_id_len equ $ - role_id
expected_role_url: db 'https://discord.com/api/v10/guilds/123456789012345678/members/987654321098765432/roles/111222333444555666'
expected_role_url_len equ $ - expected_role_url
expected_delete_url: db 'https://discord.com/api/v10/channels/123456789012345678/messages/987654321098765432'
expected_delete_url_len equ $ - expected_delete_url
guild_id: db '123456789012345678'
guild_id_len equ $ - guild_id
user_id: db '987654321098765432'
user_id_len equ $ - user_id
expected_unban_url: db 'https://discord.com/api/v10/guilds/123456789012345678/bans/987654321098765432'
expected_unban_url_len equ $ - expected_unban_url
expected_kick_url: db 'https://discord.com/api/v10/guilds/123456789012345678/members/987654321098765432'
expected_kick_url_len equ $ - expected_kick_url
expected_lock_url: db 'https://discord.com/api/v10/channels/123456789012345678/permissions/123456789012345678'
expected_lock_url_len equ $ - expected_lock_url
expected_slowmode_url: db 'https://discord.com/api/v10/channels/123456789012345678'
expected_slowmode_url_len equ $ - expected_slowmode_url
expected_member_url: db 'https://discord.com/api/v10/guilds/123456789012345678/members/987654321098765432'
expected_member_url_len equ $ - expected_member_url
slowmode_body: db '{"rate_limit_per_user":15}'
slowmode_body_len equ $ - slowmode_body
slowmode_zero_body: db '{"rate_limit_per_user":0}'
slowmode_zero_body_len equ $ - slowmode_zero_body
slowmode_max_body: db '{"rate_limit_per_user":21600}'
slowmode_max_body_len equ $ - slowmode_max_body
timeout_body: db '{"communication_disabled_until":"2026-08-26T12:34:56Z"}'
timeout_body_len equ $ - timeout_body
timeout_leap_body: db '{"communication_disabled_until":"2024-02-29T23:59:59Z"}'
timeout_leap_body_len equ $ - timeout_leap_body
timeout_clear_body: db '{"communication_disabled_until":null}'
timeout_clear_body_len equ $ - timeout_clear_body
ban_body: db '{"delete_message_seconds":0}'
ban_body_len equ $ - ban_body
lock_body: db '{"type":0,"allow":"0","deny":"2048"}'
lock_body_len equ $ - lock_body
expected_get_url: db 'https://discord.com/api/v10/guilds/123456789012345678/members/987654321098765432'
expected_get_url_len equ $ - expected_get_url
bad_get_url: db 'https://example.invalid/api/v10/guilds/1'
bad_get_url_len equ $ - bad_get_url
get_payload: db '{}'
get_payload_len equ $ - get_payload
expected_authorization: db 'Authorization: Bot token-value'
expected_authorization_len equ $ - expected_authorization
audit_reason: db 'Escalated: 50% & review'
audit_reason_len equ $ - audit_reason
expected_audit_header_reason: db 'X-Audit-Log-Reason: Escalated%3A%2050%25%20%26%20review'
expected_audit_header_reason_len equ $ - expected_audit_header_reason
expected_audit_header_default: db 'X-Audit-Log-Reason: Tidak%20ada%20alasan'
expected_audit_header_default_len equ $ - expected_audit_header_default
audit_reason_too_long: times 513 db 'a'
audit_reason_too_long_len equ $ - audit_reason_too_long
audit_reason_encoded_too_long: times 171 db ' '
audit_reason_encoded_too_long_len equ $ - audit_reason_encoded_too_long
expected_body: db '{"content":"say ', 0x5c, '"', 'hi', 0x5c, '"', ' ', 0x5c, 0x5c, ' L', 0x5c, 'n', 'T', 0x5c, 't', 'C', 0x5c, 'u0001', '"}'
expected_body_len equ $ - expected_body
oversized_text: times 2001 db 'x'
oversized_text_len equ $ - oversized_text

section .data
discord_token_ptr: dq 0
discord_token_len: dd 0
mock_status: dq 0
mock_calls: dq 0
delete_status: dq 0
expected_delete_ptr: dq 0
expected_delete_len: dd 0
delete_calls: dq 0
audit_delete_calls: dq 0
get_calls: dq 0
get_status: dq 0
patch_status: dq 0
patch_calls: dq 0
expected_patch_url_ptr: dq 0
expected_patch_url_len: dd 0
expected_patch_body_ptr: dq 0
expected_patch_body_len: dd 0
put_status: dq 0
put_calls: dq 0
put_json_calls: dq 0
audit_put_json_calls: dq 0
put_json_body_ptr: dq 0
expected_put_url_ptr: dq 0
expected_put_url_len: dd 0
expected_put_body_ptr: dq 0
expected_put_body_len: dd 0
expected_audit_header_ptr: dq 0
expected_audit_header_len: dd 0
failure_stage: dd 0
mock_failure_reason: dd 0

section .bss
escape_output: resb 64
get_response: resb 16

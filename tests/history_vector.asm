BITS 64
DEFAULT REL

extern history_append
extern history_clear
extern history_visit
extern history_visit_recent

global _start

%define SYS_EXIT 60

section .text
_start:
    mov dword [failure_stage], 1
    lea rdi, [key_a]
    mov esi, key_a_len
    lea rdx, [role_user]
    mov ecx, role_user_len
    lea r8, [content_one]
    mov r9d, content_one_len
    call history_append
    test eax, eax
    jnz .fail

    mov dword [failure_stage], 2
    lea rdi, [key_a]
    mov esi, key_a_len
    lea rdx, [role_assistant]
    mov ecx, role_assistant_len
    lea r8, [content_two]
    mov r9d, content_two_len
    call history_append
    test eax, eax
    jnz .fail

    mov dword [expected_index], 0
    mov dword [failure_stage], 3
    lea rdi, [key_a]
    mov esi, key_a_len
    lea rdx, [ordered_callback]
    call history_visit
    cmp eax, 2
    jne .fail
    cmp dword [expected_index], 2
    jne .fail

    mov dword [failure_stage], 4
    mov dword [expected_index], 1
    lea rdi, [key_a]
    mov esi, key_a_len
    lea rdx, [ordered_callback]
    mov ecx, 1
    call history_visit_recent
    cmp eax, 1
    jne .fail
    cmp dword [expected_index], 2
    jne .fail

    mov dword [failure_stage], 5
    lea rdi, [key_a]
    mov esi, key_a_len
    call history_clear
    test eax, eax
    jnz .fail
    lea rdi, [key_a]
    mov esi, key_a_len
    lea rdx, [count_callback]
    call history_visit
    test eax, eax
    jnz .fail

    ; A second key survives the clear of key_a.
    mov dword [failure_stage], 6
    lea rdi, [key_c]
    mov esi, key_c_len
    lea rdx, [role_user]
    mov ecx, role_user_len
    lea r8, [content_three]
    mov r9d, content_three_len
    call history_append
    test eax, eax
    jnz .fail
    mov dword [callback_count], 0
    lea rdi, [key_c]
    mov esi, key_c_len
    lea rdx, [count_callback]
    call history_visit
    cmp eax, 1
    jne .fail
    cmp dword [callback_count], 1
    jne .fail

    ; 33 writes retain exactly the newest bounded 32 entries for one key.
    mov dword [failure_stage], 7
    xor ebx, ebx
.fill_b:
    cmp ebx, 33
    jae .filled_b
    lea rdi, [key_b]
    mov esi, key_b_len
    lea rdx, [role_user]
    mov ecx, role_user_len
    lea r8, [content_repeat]
    mov r9d, content_repeat_len
    call history_append
    test eax, eax
    jnz .fail
    inc ebx
    jmp .fill_b
.filled_b:
    mov dword [callback_count], 0
    lea rdi, [key_b]
    mov esi, key_b_len
    lea rdx, [count_callback]
    call history_visit
    cmp eax, 32
    jne .fail
    cmp dword [callback_count], 32
    jne .fail

    ; Previously distinct key data remains isolated after ring updates.
    mov dword [failure_stage], 8
    mov dword [callback_count], 0
    lea rdi, [key_c]
    mov esi, key_c_len
    lea rdx, [count_callback]
    call history_visit
    cmp eax, 1
    jne .fail
    cmp dword [callback_count], 1
    jne .fail

    mov dword [failure_stage], 9
    xor edi, edi
    mov esi, key_a_len
    lea rdx, [role_user]
    mov ecx, role_user_len
    lea r8, [content_one]
    mov r9d, content_one_len
    call history_append
    cmp eax, -1
    jne .fail

    mov dword [failure_stage], 10
    lea rdi, [key_a]
    xor esi, esi
    lea rdx, [count_callback]
    call history_visit
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
    syscall

; RDI=role, ESI=role len, RDX=content, ECX=content len.
ordered_callback:
    mov eax, [expected_index]
    cmp eax, 2
    jae .bad
    mov r8, [expected_role_ptrs + rax * 8]
    mov r9d, [expected_role_lens + rax * 4]
    cmp esi, r9d
    jne .bad
    push rdx
    push rcx
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    pop rcx
    pop rdx
    test al, al
    jz .bad
    mov eax, [expected_index]
    mov r8, [expected_content_ptrs + rax * 8]
    mov r9d, [expected_content_lens + rax * 4]
    cmp ecx, r9d
    jne .bad
    mov rdi, rdx
    mov rsi, r8
    mov edx, r9d
    call equal_bytes
    test al, al
    jz .bad
    inc dword [expected_index]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

count_callback:
    inc dword [callback_count]
    xor eax, eax
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
key_a: db 'server-100'
key_a_len equ $ - key_a
key_b: db 'server-200'
key_b_len equ $ - key_b
key_c: db 'dm-300'
key_c_len equ $ - key_c
role_user: db 'user'
role_user_len equ $ - role_user
role_assistant: db 'assistant'
role_assistant_len equ $ - role_assistant
content_one: db 'one'
content_one_len equ $ - content_one
content_two: db 'two'
content_two_len equ $ - content_two
content_three: db 'three'
content_three_len equ $ - content_three
content_repeat: db 'repeat'
content_repeat_len equ $ - content_repeat
align 8
expected_role_ptrs: dq role_user, role_assistant
expected_role_lens: dd role_user_len, role_assistant_len
align 8
expected_content_ptrs: dq content_one, content_two
expected_content_lens: dd content_one_len, content_two_len

section .bss
failure_stage: resd 1
expected_index: resd 1
callback_count: resd 1

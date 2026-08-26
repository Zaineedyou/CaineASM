BITS 64
DEFAULT REL

global history_append
global history_clear
global history_visit
global history_visit_recent

%define HISTORY_SLOTS 16
%define HISTORY_ENTRIES 32
%define HISTORY_KEY_CAP 64
%define HISTORY_ROLE_CAP 10
%define HISTORY_CONTENT_CAP 512

section .text

; RDI=key, ESI=key len, RDX=role, ECX=role len, R8=content, R9D=content len.
; EAX=0 on append; -1 on invalid inputs or when no bounded conversation slot exists.
history_append:
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov ebp, esi
    mov r12, rdx
    mov r13d, ecx
    mov r14, r8
    mov r15d, r9d
    test rbx, rbx
    jz .bad
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    test ebp, ebp
    jle .bad
    cmp ebp, HISTORY_KEY_CAP - 1
    ja .bad
    test r13d, r13d
    jle .bad
    cmp r13d, HISTORY_ROLE_CAP - 1
    ja .bad
    test r15d, r15d
    jle .bad
    cmp r15d, HISTORY_CONTENT_CAP - 1
    ja .bad
    mov rdi, rbx
    mov esi, ebp
    call history_find_or_alloc
    test eax, eax
    js .bad
    mov r10d, eax
    mov ecx, [history_counts + r10 * 4]
    cmp ecx, HISTORY_ENTRIES
    jb .append_at_end
    mov ecx, [history_heads + r10 * 4]
    inc ecx
    cmp ecx, HISTORY_ENTRIES
    jb .store_head
    xor ecx, ecx
.store_head:
    mov [history_heads + r10 * 4], ecx
    dec ecx
    jns .have_entry_row
    mov ecx, HISTORY_ENTRIES - 1
    jmp .have_entry_row
.append_at_end:
    add ecx, [history_heads + r10 * 4]
    cmp ecx, HISTORY_ENTRIES
    jb .increment_count
    sub ecx, HISTORY_ENTRIES
.increment_count:
    inc dword [history_counts + r10 * 4]
    jmp .have_entry_row
.have_entry_row:
    mov eax, r10d
    imul eax, HISTORY_ENTRIES
    add eax, ecx
    mov r11d, eax
    mov [history_role_lens + r11 * 4], r13d
    mov [history_content_lens + r11 * 4], r15d
    mov edi, r11d
    imul edi, HISTORY_ROLE_CAP
    lea rdi, [history_roles + rdi]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    mov edi, r11d
    imul edi, HISTORY_CONTENT_CAP
    lea rdi, [history_contents + rdi]
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    inc qword [history_clock]
    mov rax, [history_clock]
    mov [history_stamps + r10 * 8], rax
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
    pop rbp
    ret

; RDI=key, ESI=key len. EAX=0 for cleared or absent conversation, -1 for invalid input.
history_clear:
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    cmp esi, HISTORY_KEY_CAP - 1
    ja .bad
    call history_find
    test eax, eax
    js .ok
    mov dword [history_heads + rax * 4], 0
    mov dword [history_counts + rax * 4], 0
    inc qword [history_clock]
    mov rdx, [history_clock]
    mov [history_stamps + rax * 8], rdx
.ok:
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=key, ESI=key len, RDX=callback. Callback receives RDI=role, ESI=role len,
; RDX=content, ECX=content len and returns zero to continue. EAX=entry count,
; or -1 on invalid input/callback failure.
history_visit:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    cmp esi, HISTORY_KEY_CAP - 1
    ja .bad
    test rdx, rdx
    jz .bad
    mov r12, rdx
    call history_find
    test eax, eax
    js .none
    mov r13d, eax
    mov r14d, [history_counts + r13 * 4]
    mov r15d, [history_heads + r13 * 4]
    xor ebx, ebx
.loop:
    cmp ebx, r14d
    jae .done
    mov eax, r15d
    add eax, ebx
    cmp eax, HISTORY_ENTRIES
    jb .entry_row
    sub eax, HISTORY_ENTRIES
.entry_row:
    mov ecx, r13d
    imul ecx, HISTORY_ENTRIES
    add ecx, eax
    mov eax, ecx
    imul eax, HISTORY_ROLE_CAP
    lea rdi, [history_roles + rax]
    mov esi, [history_role_lens + rcx * 4]
    mov eax, ecx
    imul eax, HISTORY_CONTENT_CAP
    lea rdx, [history_contents + rax]
    mov ecx, [history_content_lens + rcx * 4]
    call r12
    test eax, eax
    jnz .bad
    inc ebx
    jmp .loop
.done:
    mov eax, r14d
    jmp .out
.none:
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

; RDI=key, ESI=key len, RDX=callback, ECX=max newest entries. Callback has
; the same ABI as history_visit. EAX=visited count, or -1 on invalid input/callback failure.
history_visit_recent:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    cmp esi, HISTORY_KEY_CAP - 1
    ja .bad
    test rdx, rdx
    jz .bad
    test ecx, ecx
    jle .bad
    mov r12, rdx
    mov r11d, ecx
    call history_find
    test eax, eax
    js .none
    mov r13d, eax
    mov r14d, [history_counts + r13 * 4]
    mov r15d, [history_heads + r13 * 4]
    cmp r14d, r11d
    jbe .start
    sub r14d, r11d
    add r15d, r14d
    cmp r15d, HISTORY_ENTRIES
    jb .limit_count
    sub r15d, HISTORY_ENTRIES
.limit_count:
    mov r14d, r11d
.start:
    xor ebx, ebx
.loop:
    cmp ebx, r14d
    jae .done
    mov eax, r15d
    add eax, ebx
    cmp eax, HISTORY_ENTRIES
    jb .entry_row
    sub eax, HISTORY_ENTRIES
.entry_row:
    mov ecx, r13d
    imul ecx, HISTORY_ENTRIES
    add ecx, eax
    mov eax, ecx
    imul eax, HISTORY_ROLE_CAP
    lea rdi, [history_roles + rax]
    mov esi, [history_role_lens + rcx * 4]
    mov eax, ecx
    imul eax, HISTORY_CONTENT_CAP
    lea rdx, [history_contents + rax]
    mov ecx, [history_content_lens + rcx * 4]
    call r12
    test eax, eax
    jnz .bad
    inc ebx
    jmp .loop
.done:
    mov eax, r14d
    jmp .out
.none:
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

; RDI=key, ESI=key len. EAX=slot, or -1 when absent/invalid.
history_find:
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    cmp esi, HISTORY_KEY_CAP - 1
    ja .bad
    xor eax, eax
.slot:
    cmp eax, HISTORY_SLOTS
    jae .bad
    cmp dword [history_active + rax * 4], 0
    je .next
    cmp esi, [history_key_lens + rax * 4]
    jne .next
    mov r8d, eax
    imul r8, HISTORY_KEY_CAP
    xor ecx, ecx
.compare:
    cmp ecx, esi
    jae .found
    mov dl, [rdi + rcx]
    cmp dl, [history_keys + r8 + rcx]
    jne .next
    inc ecx
    jmp .compare
.next:
    inc eax
    jmp .slot
.found:
    ret
.bad:
    mov eax, -1
    ret

; RDI=key, ESI=len. EAX=existing or allocated slot, or -1 on invalid input.
history_find_or_alloc:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    call history_find
    test eax, eax
    jns .out
    xor ecx, ecx
.find_free:
    cmp ecx, HISTORY_SLOTS
    jae .evict
    cmp dword [history_active + rcx * 4], 0
    je .allocate
    inc ecx
    jmp .find_free
.evict:
    xor ecx, ecx
    mov r8, [history_stamps]
    mov edx, 1
.oldest:
    cmp edx, HISTORY_SLOTS
    jae .allocate
    mov r9, [history_stamps + rdx * 8]
    cmp r9, r8
    jae .next_oldest
    mov r8, r9
    mov ecx, edx
.next_oldest:
    inc edx
    jmp .oldest
.allocate:
    mov r8d, ecx
    mov dword [history_active + r8 * 4], 1
    mov [history_key_lens + r8 * 4], r12d
    mov dword [history_heads + r8 * 4], 0
    mov dword [history_counts + r8 * 4], 0
    mov edi, r8d
    imul edi, HISTORY_KEY_CAP
    lea rdi, [history_keys + rdi]
    mov rsi, rbx
    mov edx, r12d
    call copy_bytes
    inc qword [history_clock]
    mov rax, [history_clock]
    mov [history_stamps + r8 * 8], rax
    mov eax, r8d
.out:
    pop r12
    pop rbx
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

section .data
history_clock: dq 0

section .bss
history_active: resd HISTORY_SLOTS
history_key_lens: resd HISTORY_SLOTS
history_heads: resd HISTORY_SLOTS
history_counts: resd HISTORY_SLOTS
history_stamps: resq HISTORY_SLOTS
history_keys: resb HISTORY_SLOTS * HISTORY_KEY_CAP
history_role_lens: resd HISTORY_SLOTS * HISTORY_ENTRIES
history_content_lens: resd HISTORY_SLOTS * HISTORY_ENTRIES
history_roles: resb HISTORY_SLOTS * HISTORY_ENTRIES * HISTORY_ROLE_CAP
history_contents: resb HISTORY_SLOTS * HISTORY_ENTRIES * HISTORY_CONTENT_CAP

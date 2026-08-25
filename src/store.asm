BITS 64
DEFAULT REL

global store_set
global store_get
global store_delete

%define SLOT_COUNT 128
%define KEY_CAP 96
%define VALUE_CAP 512
%define SLOT_SIZE 616

; Fixed-size in-memory KV for the first assembly checkpoint.
; Keys are formed by the caller as `guild_id:key` or `history_key:index`.
; Future append-only persistence can replay into the same table without changing
; command policy or Gateway logic.

section .text

; RDI=key, ESI=key length, RDX=value, ECX=value length. EAX=0 success, -1 invalid/full.
store_set:
    cmp esi, 0
    je .bad
    cmp esi, KEY_CAP - 1
    ja .bad
    cmp ecx, VALUE_CAP - 1
    ja .bad
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rdx
    mov r14d, esi
    mov r15d, ecx
    call find_or_empty_slot
    test rax, rax
    jz .out_bad
    mov byte [rax], 1
    mov [rax + 4], r14d
    mov [rax + 8], r15d
    mov rbx, rax
    lea rdi, [rbx + 16]
    mov rsi, r12
    mov edx, r14d
    call copy_bytes
    lea rdi, [rbx + 16 + KEY_CAP]
    mov rsi, r13
    mov edx, r15d
    call copy_bytes
    xor eax, eax
    jmp .out
.out_bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad:
    mov eax, -1
    ret

; RDI=key, ESI=key length. RAX=value pointer or zero. EDX=value length if found.
store_get:
    sub rsp, 8
    cmp esi, 0
    je .missing
    cmp esi, KEY_CAP - 1
    ja .missing
    mov r8d, esi
    mov r11, rdi
    xor r10d, r10d
.loop:
    cmp r10d, SLOT_COUNT
    jae .missing
    imul rax, r10, SLOT_SIZE
    lea r9, [store_slots + rax]
    cmp byte [r9], 1
    jne .next
    cmp [r9 + 4], r8d
    jne .next
    lea rdi, [r9 + 16]
    mov rsi, r11
    mov edx, r8d
    call equal_bytes
    test al, al
    jz .next
    lea rax, [r9 + 16 + KEY_CAP]
    mov edx, [r9 + 8]
    add rsp, 8
    ret
.next:
    inc r10d
    jmp .loop
.missing:
    xor eax, eax
    xor edx, edx
    add rsp, 8
    ret

; RDI=key, ESI=key length. EAX=0 removed, -1 absent.
store_delete:
    sub rsp, 8
    call store_get_slot
    test rax, rax
    jz .missing
    mov byte [rax], 0
    xor eax, eax
    add rsp, 8
    ret
.missing:
    mov eax, -1
    add rsp, 8
    ret

; RDI=key, ESI=key length -> RAX slot pointer or zero.
store_get_slot:
    sub rsp, 8
    cmp esi, 0
    je .missing
    cmp esi, KEY_CAP - 1
    ja .missing
    mov r8d, esi
    mov r11, rdi
    xor r10d, r10d
.loop:
    cmp r10d, SLOT_COUNT
    jae .missing
    imul rax, r10, SLOT_SIZE
    lea r9, [store_slots + rax]
    cmp byte [r9], 1
    jne .next
    cmp [r9 + 4], r8d
    jne .next
    lea rdi, [r9 + 16]
    mov rsi, r11
    mov edx, r8d
    call equal_bytes
    test al, al
    jnz .found
.next:
    inc r10d
    jmp .loop
.found:
    mov rax, r9
    add rsp, 8
    ret
.missing:
    xor eax, eax
    add rsp, 8
    ret

; Finds an existing matching slot or first unused slot. R12 key; R14D key length.
find_or_empty_slot:
    sub rsp, 8
    xor r9d, r9d
    xor r10d, r10d
.loop:
    cmp r9d, SLOT_COUNT
    jae .finish
    imul rax, r9, SLOT_SIZE
    lea r11, [store_slots + rax]
    cmp byte [r11], 1
    jne .empty
    cmp [r11 + 4], r14d
    jne .next
    lea rdi, [r11 + 16]
    mov rsi, r12
    mov edx, r14d
    call equal_bytes
    test al, al
    jnz .found
.next:
    inc r9d
    jmp .loop
.empty:
    test r10, r10
    jnz .next
    mov r10, r11
    jmp .next
.finish:
    mov rax, r10
    add rsp, 8
    ret
.found:
    mov rax, r11
    add rsp, 8
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

section .bss
align 16
store_slots: resb SLOT_COUNT * SLOT_SIZE

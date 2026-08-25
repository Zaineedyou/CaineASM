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
    push r12
    push r13
    mov r12, rdi
    mov r13, rdx
    mov r8d, esi
    mov r9d, ecx
    call find_or_empty_slot
    test rax, rax
    jz .out_bad
    mov byte [rax], 1
    mov [rax + 4], r8d
    mov [rax + 8], r9d
    lea rdi, [rax + 16]
    mov rsi, r12
    mov edx, r8d
    call copy_bytes
    lea rdi, [rax + 16 + KEY_CAP]
    mov rsi, r13
    mov edx, r9d
    call copy_bytes
    xor eax, eax
    jmp .out
.out_bad:
    mov eax, -1
.out:
    pop r13
    pop r12
    ret
.bad:
    mov eax, -1
    ret

; RDI=key, ESI=key length. RAX=value pointer or zero. EDX=value length if found.
store_get:
    cmp esi, 0
    je .missing
    mov r8d, esi
    xor ecx, ecx
.loop:
    cmp ecx, SLOT_COUNT
    jae .missing
    imul rax, rcx, SLOT_SIZE
    lea r9, [store_slots + rax]
    cmp byte [r9], 1
    jne .next
    cmp [r9 + 4], r8d
    jne .next
    lea rsi, [r9 + 16]
    mov edx, r8d
    push rdi
    call equal_bytes
    pop rdi
    test al, al
    jz .next
    lea rax, [r9 + 16 + KEY_CAP]
    mov edx, [r9 + 8]
    ret
.next:
    inc ecx
    jmp .loop
.missing:
    xor eax, eax
    xor edx, edx
    ret

; RDI=key, ESI=key length. EAX=0 removed, -1 absent.
store_delete:
    call store_get_slot
    test rax, rax
    jz .missing
    mov byte [rax], 0
    xor eax, eax
    ret
.missing:
    mov eax, -1
    ret

; RDI=key, ESI=key length -> RAX slot pointer or zero.
store_get_slot:
    mov r8d, esi
    xor ecx, ecx
.loop:
    cmp ecx, SLOT_COUNT
    jae .missing
    imul rax, rcx, SLOT_SIZE
    lea r9, [store_slots + rax]
    cmp byte [r9], 1
    jne .next
    cmp [r9 + 4], r8d
    jne .next
    lea rsi, [r9 + 16]
    mov edx, r8d
    push rdi
    call equal_bytes
    pop rdi
    test al, al
    jnz .found
.next:
    inc ecx
    jmp .loop
.found:
    mov rax, r9
    ret
.missing:
    xor eax, eax
    ret

; Finds an existing matching slot or first unused slot. R12 key; R8d key length.
find_or_empty_slot:
    xor ecx, ecx
    xor r10d, r10d
.loop:
    cmp ecx, SLOT_COUNT
    jae .finish
    imul rax, rcx, SLOT_SIZE
    lea r11, [store_slots + rax]
    cmp byte [r11], 1
    jne .empty
    cmp [r11 + 4], r8d
    jne .next
    lea rdi, [r11 + 16]
    mov rsi, r12
    mov edx, r8d
    call equal_bytes
    test al, al
    jnz .found
.next:
    inc ecx
    jmp .loop
.empty:
    test r10, r10
    jnz .next
    mov r10, r11
    jmp .next
.finish:
    mov rax, r10
    ret
.found:
    mov rax, r11
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

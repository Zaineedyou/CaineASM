BITS 64
DEFAULT REL

global warnings_add
global warnings_get
global warnings_clear

extern store_get
extern store_set
extern store_delete

%define ID_CAP 64
%define WARNING_KEY_CAP 96

section .text

; RDI=guild, ESI=guild len, RDX=user, ECX=user len.
; EAX=new count (>=1), or -1 on malformed/full/persistence failure.
warnings_add:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    call build_warning_key
    test eax, eax
    js .bad
    mov esi, eax
    lea rdi, [warning_key]
    call store_get
    test rax, rax
    jz .new
    mov rdi, rax
    mov esi, edx
    call parse_decimal
    test eax, eax
    js .bad
    cmp eax, 999999999
    jae .bad
    inc eax
    jmp .store
.new:
    mov eax, 1
.store:
    mov [warning_count], eax
    lea rdi, [warning_value]
    call format_decimal
    test eax, eax
    jle .bad
    mov ecx, eax
    lea rdi, [warning_key]
    mov esi, [warning_key_len]
    lea rdx, [warning_value]
    call store_set
    test eax, eax
    js .bad
    mov eax, [warning_count]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=user, ECX=user len.
; EAX=current count (zero when absent), -1 for malformed stored data/input.
warnings_get:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    call build_warning_key
    test eax, eax
    js .bad
    mov esi, eax
    lea rdi, [warning_key]
    call store_get
    test rax, rax
    jz .zero
    mov rdi, rax
    mov esi, edx
    call parse_decimal
    jmp .out
.zero:
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=user, ECX=user len.
; EAX=0 when the warning count is cleared or was absent; -1 on invalid/durability failure.
warnings_clear:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    call build_warning_key
    test eax, eax
    js .bad
    mov esi, eax
    lea rdi, [warning_key]
    call store_delete
    cmp eax, -1
    je .ok
    test eax, eax
    js .bad
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
    ret

; Inputs held in R12/R13 (guild) and R14/R15 (user). EAX=key len or -1.
build_warning_key:
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    test r13d, r13d
    jle .bad
    test r15d, r15d
    jle .bad
    cmp r13d, ID_CAP - 1
    ja .bad
    cmp r15d, ID_CAP - 1
    ja .bad
    mov eax, warning_prefix_len
    add eax, r13d
    add eax, r15d
    add eax, 1
    cmp eax, WARNING_KEY_CAP - 1
    ja .bad
    mov [warning_key_len], eax
    lea rdi, [warning_key]
    lea rsi, [warning_prefix]
    mov edx, warning_prefix_len
    call copy_bytes
    lea rdi, [warning_key + warning_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [warning_key + warning_prefix_len]
    add rdi, r13
    mov byte [rdi], ':'
    inc rdi
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    mov eax, [warning_key_len]
    ret
.bad:
    mov eax, -1
    ret

; RDI=ASCII decimal, ESI=len. EAX=integer or -1 if invalid/overflow.
parse_decimal:
    test rdi, rdi
    jz .bad
    test esi, esi
    jle .bad
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .done
    movzx edx, byte [rdi + rcx]
    sub edx, '0'
    cmp edx, 9
    ja .bad
    cmp eax, 429496729
    ja .bad
    imul eax, eax, 10
    add eax, edx
    jc .bad
    inc ecx
    jmp .loop
.done:
    ret
.bad:
    mov eax, -1
    ret

; EAX=value, RDI=destination. EAX=decimal length.
format_decimal:
    lea r8, [decimal_scratch + 10]
    xor ecx, ecx
    test eax, eax
    jnz .digits
    mov byte [rdi], '0'
    mov eax, 1
    ret
.digits:
    mov r9d, 10
.loop:
    xor edx, edx
    div r9d
    add dl, '0'
    dec r8
    mov [r8], dl
    inc ecx
    test eax, eax
    jnz .loop
    xor edx, edx
.copy:
    cmp edx, ecx
    jae .done
    mov al, [r8 + rdx]
    mov [rdi + rdx], al
    inc edx
    jmp .copy
.done:
    mov eax, ecx
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
warning_prefix: db 'warn:'
warning_prefix_len equ $ - warning_prefix

section .data
warning_key_len: dd 0
warning_count: dd 0

section .bss
warning_key: resb WARNING_KEY_CAP
warning_value: resb 16
decimal_scratch: resb 16

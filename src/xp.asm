BITS 64
DEFAULT REL

global xp_increment
global xp_get

extern store_get
extern store_set

%define KEY_CAP 96
%define VALUE_CAP 16

; RDI=guild bytes, ESI=guild length, RDX=user bytes, ECX=user length.
; EAX=new unsigned 32-bit XP total, or -1 when the bounded state cannot be updated.
section .text
xp_increment:
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    mov r13d, esi
    call build_key
    test eax, eax
    js .bad
    mov esi, eax
    lea rdi, [xp_key]
    call store_get
    test rax, rax
    jz .new
    mov rdi, rax
    mov esi, edx
    call parse_uint32
    jc .bad
    cmp eax, -1
    je .have_value
    inc eax
    jmp .have_value
.new:
    mov eax, 1
.have_value:
    mov [xp_score], eax
    lea rdi, [xp_value]
    call format_uint32
    test eax, eax
    jle .bad
    mov r13d, eax
    lea rdi, [xp_key]
    mov esi, [xp_key_len]
    lea rdx, [xp_value]
    mov ecx, r13d
    call store_set
    test eax, eax
    jnz .bad
    mov eax, [xp_score]
    jmp .out
.bad:
    mov eax, -1
.out:
    add rsp, 8
    pop r13
    pop r12
    ret

; RDI=guild bytes, ESI=guild length, RDX=user bytes, ECX=user length.
; EAX=current XP or zero when no score exists. Malformed stored state reads as zero.
xp_get:
    sub rsp, 8
    call build_key
    test eax, eax
    js .missing
    mov esi, eax
    lea rdi, [xp_key]
    call store_get
    test rax, rax
    jz .missing
    mov rdi, rax
    mov esi, edx
    call parse_uint32
    jc .missing
    add rsp, 8
    ret
.missing:
    xor eax, eax
    add rsp, 8
    ret

; RDI=guild, ESI=guild len, RDX=user, ECX=user len. EAX=key len or -1.
build_key:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r13d, r13d
    jz .bad
    test r15d, r15d
    jz .bad
    mov eax, r13d
    add eax, r15d
    add eax, xp_prefix_len + 1
    cmp eax, KEY_CAP - 1
    ja .bad
    mov [xp_key_len], eax
    lea rdi, [xp_key]
    lea rsi, [xp_prefix]
    mov edx, xp_prefix_len
    call copy_bytes
    lea rdi, [xp_key + xp_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [xp_key + xp_prefix_len]
    add rdi, r13
    mov byte [rdi], ':'
    inc rdi
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    mov eax, [xp_key_len]
    jmp .out
.bad:
    mov eax, -1
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=decimal bytes, ESI=len. EAX=value, CF=0 valid; CF=1 invalid/overflow.
parse_uint32:
    test esi, esi
    jz .bad
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .good
    movzx edx, byte [rdi + rcx]
    sub dl, '0'
    cmp dl, 9
    ja .bad
    cmp eax, 429496729
    ja .bad
    jb .multiply
    cmp dl, 5
    ja .bad
.multiply:
    imul eax, eax, 10
    movzx edx, dl
    add eax, edx
    inc ecx
    jmp .loop
.good:
    clc
    ret
.bad:
    xor eax, eax
    stc
    ret

; RDI=destination, EAX=value. EAX=written decimal length.
format_uint32:
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
xp_prefix: db 'xp:'
xp_prefix_len equ $ - xp_prefix

section .data
xp_key_len: dd 0
xp_score: dd 0

section .bss
xp_key: resb KEY_CAP
xp_value: resb VALUE_CAP
decimal_scratch: resb 10

BITS 64
DEFAULT REL

global afk_set
global afk_clear
global afk_lookup

extern store_set
extern store_get
extern store_delete

; Fixed bounded AFK registry. Caller supplies guild/user identifiers already
; normalized by the Gateway dispatcher. Keys are `afk:<guild>:<user>`.

section .text

; RDI=guild bytes, ESI=guild len, RDX=user bytes, ECX=user len,
; R8=reason bytes, R9D=reason len. EAX propagates store status.
afk_set:
    push r12
    push r13
    mov r12, r8
    mov r13d, r9d
    call build_key
    test eax, eax
    jnz .bad
    lea rdi, [afk_key]
    mov esi, eax
    mov rdx, r12
    mov ecx, r13d
    call store_set
.bad:
    pop r13
    pop r12
    ret

; RDI=guild bytes, ESI=guild len, RDX=user bytes, ECX=user len.
afk_clear:
    call build_key
    test eax, eax
    jnz .bad
    lea rdi, [afk_key]
    mov esi, eax
    call store_delete
.bad:
    ret

; RDI=guild bytes, ESI=guild len, RDX=user bytes, ECX=user len.
; RAX=reason pointer, EDX=reason length; zero means not AFK.
afk_lookup:
    call build_key
    test eax, eax
    jnz .missing
    lea rdi, [afk_key]
    mov esi, eax
    call store_get
    ret
.missing:
    xor eax, eax
    xor edx, edx
    ret

; Build afk:<guild>:<user> in afk_key. EAX=key length or -1.
build_key:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                     ; guild pointer
    mov r13d, esi                    ; guild length
    mov r14, rdx                     ; user pointer
    mov r15d, ecx                    ; user length
    mov eax, r13d
    add eax, r15d
    add eax, afk_prefix_len + 1
    cmp eax, 95
    ja .bad
    push rax
    lea rdi, [afk_key]
    lea rsi, [afk_prefix]
    mov edx, afk_prefix_len
    call copy_bytes
    lea rdi, [afk_key + afk_prefix_len]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [afk_key + afk_prefix_len]
    add rdi, r13
    mov byte [rdi], ':'
    inc rdi
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    pop rax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

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
afk_prefix: db 'afk:'
afk_prefix_len equ $ - afk_prefix
section .bss
afk_key: resb 96

BITS 64
DEFAULT REL

global attachment_fetch_https

extern secure_https_get

%define URL_CAP 1024

section .text

; RDI=url bytes, ESI=url length, RDX=output bytes, ECX=output capacity.
; RAX=received length on HTTP 2xx, -1 on invalid URL, transport, or HTTP error.
; The URL is validated and C-string construction is NASM-owned. The C boundary
; receives an empty Authorization header and only performs verified HTTPS I/O.
attachment_fetch_https:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    test r13d, r13d
    jle .bad
    cmp r13d, URL_CAP - 1
    ja .bad
    cmp ecx, 2
    jb .bad
    cmp r13d, 8
    jb .bad
    cmp byte [r12], 'h'
    jne .bad
    cmp byte [r12 + 1], 't'
    jne .bad
    cmp byte [r12 + 2], 't'
    jne .bad
    cmp byte [r12 + 3], 'p'
    jne .bad
    cmp byte [r12 + 4], 's'
    jne .bad
    cmp byte [r12 + 5], ':'
    jne .bad
    cmp byte [r12 + 6], '/'
    jne .bad
    cmp byte [r12 + 7], '/'
    jne .bad
    xor ebx, ebx
.validate:
    cmp ebx, r13d
    jae .copy
    mov al, [r12 + rbx]
    cmp al, 0x21
    jb .bad
    cmp al, 0x7e
    ja .bad
    inc ebx
    jmp .validate
.copy:
    xor ebx, ebx
.copy_loop:
    cmp ebx, r13d
    jae .request
    mov al, [r12 + rbx]
    mov [fetch_url + rbx], al
    inc ebx
    jmp .copy_loop
.request:
    mov byte [fetch_url + rbx], 0
    sub rsp, 8
    lea rdi, [fetch_url]
    lea rsi, [empty_auth]
    mov rdx, r14
    mov r8d, ecx
    mov ecx, r8d
    lea r8, [fetch_status]
    call secure_https_get
    add rsp, 8
    test rax, rax
    js .bad
    cmp qword [fetch_status], 200
    jb .bad
    cmp qword [fetch_status], 300
    jae .bad
    jmp .out
.bad:
    mov rax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata
empty_auth: db 0
section .data
fetch_status: dq 0
section .bss
fetch_url: resb URL_CAP

BITS 64
DEFAULT REL

global attachment_extract_image_url

extern json_find_key
extern json_read_string
extern json_array_end
extern json_object_end

%define MIME_CAP 64

section .text

; RDI=full MESSAGE_CREATE JSON, RSI=len, RDX=url destination, ECX=URL capacity.
; EAX=url length, or -1 unless first attachment is an image with a valid URL.
attachment_extract_image_url:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .bad
    test r14, r14
    jz .bad
    cmp r15d, 2
    jb .bad
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_attachments]
    mov ecx, key_attachments_len
    call json_find_key
    test rax, rax
    jz .bad
    cmp byte [rax], '['
    jne .bad
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_array_end
    test rax, rax
    jz .bad
    mov r13, rax
    inc rbx
.skip:
    cmp rbx, r13
    jae .bad
    mov al, [rbx]
    cmp al, ' '
    je .advance
    cmp al, 9
    je .advance
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    cmp al, '{'
    jne .bad
    mov r12, rbx
    mov rdi, r12
    mov rsi, r13
    call json_object_end
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, r12
    mov rsi, rbx
    sub rsi, r12
    lea rdx, [key_content_type]
    mov ecx, key_content_type_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, rbx
    lea rdx, [attachment_mime]
    mov ecx, MIME_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    cmp eax, 6
    jb .bad
    cmp byte [attachment_mime], 'i'
    jne .bad
    cmp byte [attachment_mime + 1], 'm'
    jne .bad
    cmp byte [attachment_mime + 2], 'a'
    jne .bad
    cmp byte [attachment_mime + 3], 'g'
    jne .bad
    cmp byte [attachment_mime + 4], 'e'
    jne .bad
    cmp byte [attachment_mime + 5], '/'
    jne .bad
    mov rdi, r12
    mov rsi, rbx
    sub rsi, r12
    lea rdx, [key_url]
    mov ecx, key_url_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, rbx
    mov rdx, r14
    mov ecx, r15d
    call json_read_string
    test eax, eax
    jle .bad
    mov byte [r14 + rax], 0
    jmp .out
.advance:
    inc rbx
    jmp .skip
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata
key_attachments: db 'attachments'
key_attachments_len equ $ - key_attachments
key_content_type: db 'content_type'
key_content_type_len equ $ - key_content_type
key_url: db 'url'
key_url_len equ $ - key_url
section .bss
attachment_mime: resb MIME_CAP

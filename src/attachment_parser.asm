BITS 64
DEFAULT REL

global attachment_extract_image_url
global attachment_copy_image_mime

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
    ; Clear the process-local MIME cache before every parse so callers can
    ; never reuse a prior attachment's type after a failed extraction.
    mov byte [attachment_mime], 0
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
    mov byte [attachment_mime + rax], 0
    mov esi, eax
    lea rdi, [attachment_mime]
    call attachment_mime_allowed
    test al, al
    jz .bad
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
    mov byte [attachment_mime], 0
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=destination, ESI=capacity. EAX=MIME length or -1.
; Only these exact MIME values are accepted for data URIs. This intentionally
; rejects arbitrary image/* subtypes and MIME parameters within the same small
; fixed-capacity parser.
attachment_mime_allowed:
    mov r8, rdi
    mov r9d, esi
    lea rdi, [r8]
    mov esi, r9d
    lea rdx, [mime_png]
    mov ecx, mime_png_len
    call attachment_mime_equals
    test al, al
    jnz .yes
    lea rdi, [r8]
    mov esi, r9d
    lea rdx, [mime_jpeg]
    mov ecx, mime_jpeg_len
    call attachment_mime_equals
    test al, al
    jnz .yes
    lea rdi, [r8]
    mov esi, r9d
    lea rdx, [mime_gif]
    mov ecx, mime_gif_len
    call attachment_mime_equals
    test al, al
    jnz .yes
    lea rdi, [r8]
    mov esi, r9d
    lea rdx, [mime_webp]
    mov ecx, mime_webp_len
    call attachment_mime_equals
    ret
.yes:
    mov al, 1
    ret

; RDI=actual bytes, ESI=actual len, RDX=expected bytes, ECX=expected len.
; AL=1 only for an exact byte-for-byte MIME match.
attachment_mime_equals:
    cmp esi, ecx
    jne .no
    xor eax, eax
.loop:
    cmp eax, ecx
    jae .yes
    mov r10b, [rdi + rax]
    cmp r10b, [rdx + rax]
    jne .no
    inc eax
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

attachment_copy_image_mime:
    test rdi, rdi
    jz .bad
    cmp esi, 2
    jb .bad
    xor ecx, ecx
.copy:
    cmp ecx, MIME_CAP - 1
    jae .bad
    mov al, [attachment_mime + rcx]
    test al, al
    jz .done
    cmp ecx, esi
    jae .bad
    mov [rdi + rcx], al
    inc ecx
    jmp .copy
.done:
    test ecx, ecx
    jz .bad
    cmp ecx, esi
    jae .bad
    mov byte [rdi + rcx], 0
    mov eax, ecx
    ret
.bad:
    mov eax, -1
    ret

section .rodata
key_attachments: db 'attachments'
key_attachments_len equ $ - key_attachments
key_content_type: db 'content_type'
key_content_type_len equ $ - key_content_type
key_url: db 'url'
key_url_len equ $ - key_url
mime_png: db 'image/png'
mime_png_len equ $ - mime_png
mime_jpeg: db 'image/jpeg'
mime_jpeg_len equ $ - mime_jpeg
mime_gif: db 'image/gif'
mime_gif_len equ $ - mime_gif
mime_webp: db 'image/webp'
mime_webp_len equ $ - mime_webp
section .bss
attachment_mime: resb MIME_CAP

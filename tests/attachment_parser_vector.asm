BITS 64
DEFAULT REL

extern attachment_extract_image_url
global _start
%define SYS_EXIT 60

section .text
_start:
    mov dword [stage], 1
    lea rdi, [image_event]
    mov esi, image_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, expected_url_len
    jne .fail
    lea rdi, [url_out]
    lea rsi, [expected_url]
    mov edx, expected_url_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [stage], 2
    lea rdi, [text_event]
    mov esi, text_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, -1
    jne .fail

    mov dword [stage], 3
    lea rdi, [empty_event]
    mov esi, empty_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [stage]
    syscall

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
image_event: db '{"attachments":[{"content_type":"image/png","url":"https://cdn.discordapp.com/a.png"}]}'
image_event_len equ $ - image_event
text_event: db '{"attachments":[{"content_type":"text/plain","url":"https://cdn.discordapp.com/a.txt"}]}'
text_event_len equ $ - text_event
empty_event: db '{"attachments":[]}'
empty_event_len equ $ - empty_event
expected_url: db 'https://cdn.discordapp.com/a.png'
expected_url_len equ $ - expected_url
section .bss
url_out: resb 256
stage: resd 1

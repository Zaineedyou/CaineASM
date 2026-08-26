BITS 64
DEFAULT REL

extern attachment_extract_image_url
extern attachment_copy_image_mime
global _start
%define SYS_EXIT 60

section .text
_start:
    ; Accepted image gets both URL and an exact cached MIME copy.
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
    lea rdi, [mime_out]
    mov esi, 64
    call attachment_copy_image_mime
    cmp eax, expected_png_mime_len
    jne .fail
    lea rdi, [mime_out]
    lea rsi, [expected_png_mime]
    mov edx, expected_png_mime_len
    call equal_bytes
    test al, al
    jz .fail

    ; The remaining bounded allowlist values are accepted exactly.
    mov dword [stage], 2
    lea rdi, [jpeg_event]
    mov esi, jpeg_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, expected_url_len
    jne .fail
    lea rdi, [mime_out]
    mov esi, 64
    call attachment_copy_image_mime
    cmp eax, expected_jpeg_mime_len
    jne .fail

    mov dword [stage], 3
    lea rdi, [gif_event]
    mov esi, gif_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    mov dword [stage], 31
    cmp eax, expected_url_len
    jne .fail
    lea rdi, [mime_out]
    mov esi, 64
    call attachment_copy_image_mime
    mov [stage], eax
    cmp eax, expected_gif_mime_len
    jne .fail

    mov dword [stage], 4
    lea rdi, [webp_event]
    mov esi, webp_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, expected_url_len
    jne .fail
    lea rdi, [mime_out]
    mov esi, 64
    call attachment_copy_image_mime
    cmp eax, expected_webp_mime_len
    jne .fail

    ; Non-images and unbounded/parameterized image types fail closed; the
    ; cache is cleared so a later MIME copy cannot reuse an old accepted type.
    mov dword [stage], 5
    lea rdi, [text_event]
    mov esi, text_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, -1
    jne .fail
    lea rdi, [mime_out]
    mov esi, 64
    call attachment_copy_image_mime
    cmp eax, -1
    jne .fail

    mov dword [stage], 6
    lea rdi, [svg_event]
    mov esi, svg_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, -1
    jne .fail

    mov dword [stage], 7
    lea rdi, [parameterized_event]
    mov esi, parameterized_event_len
    lea rdx, [url_out]
    mov ecx, 256
    call attachment_extract_image_url
    cmp eax, -1
    jne .fail

    mov dword [stage], 8
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
jpeg_event: db '{"attachments":[{"content_type":"image/jpeg","url":"https://cdn.discordapp.com/a.png"}]}'
jpeg_event_len equ $ - jpeg_event
gif_event: db '{"attachments":[{"content_type":"image/gif","url":"https://cdn.discordapp.com/a.png"}]}'
gif_event_len equ $ - gif_event
webp_event: db '{"attachments":[{"content_type":"image/webp","url":"https://cdn.discordapp.com/a.png"}]}'
webp_event_len equ $ - webp_event
text_event: db '{"attachments":[{"content_type":"text/plain","url":"https://cdn.discordapp.com/a.txt"}]}'
text_event_len equ $ - text_event
svg_event: db '{"attachments":[{"content_type":"image/svg+xml","url":"https://cdn.discordapp.com/a.svg"}]}'
svg_event_len equ $ - svg_event
parameterized_event: db '{"attachments":[{"content_type":"image/png; charset=binary","url":"https://cdn.discordapp.com/a.png"}]}'
parameterized_event_len equ $ - parameterized_event
empty_event: db '{"attachments":[]}'
empty_event_len equ $ - empty_event
expected_url: db 'https://cdn.discordapp.com/a.png'
expected_url_len equ $ - expected_url
expected_png_mime: db 'image/png'
expected_png_mime_len equ $ - expected_png_mime
expected_jpeg_mime: db 'image/jpeg'
expected_jpeg_mime_len equ $ - expected_jpeg_mime
expected_gif_mime: db 'image/gif'
expected_gif_mime_len equ $ - expected_gif_mime
expected_webp_mime: db 'image/webp'
expected_webp_mime_len equ $ - expected_webp_mime

section .bss
url_out: resb 256
mime_out: resb 64
stage: resd 1

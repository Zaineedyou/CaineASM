BITS 64
DEFAULT REL

extern attachment_fetch_https
global _start
global secure_https_get
%define SYS_EXIT 60

section .text
_start:
    mov dword [stage], 1
    mov qword [mock_status], 200
    lea rdi, [good_url]
    mov esi, good_url_len
    lea rdx, [out]
    mov ecx, 64
    call attachment_fetch_https
    cmp rax, payload_len
    jne .fail
    cmp qword [fetch_calls], 1
    jne .fail
    lea rdi, [out]
    lea rsi, [payload]
    mov edx, payload_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [stage], 2
    lea rdi, [bad_http]
    mov esi, bad_http_len
    lea rdx, [out]
    mov ecx, 64
    call attachment_fetch_https
    cmp rax, -1
    jne .fail
    cmp qword [fetch_calls], 1
    jne .fail

    mov dword [stage], 3
    mov qword [mock_status], 404
    lea rdi, [good_url]
    mov esi, good_url_len
    lea rdx, [out]
    mov ecx, 64
    call attachment_fetch_https
    cmp rax, -1
    jne .fail
    cmp qword [fetch_calls], 2
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [stage]
    syscall

; RDI=url C string, RSI=auth C string, RDX=out, RCX=cap, R8=status pointer.
secure_https_get:
    cmp byte [rdi], 'h'
    jne .bad
    cmp byte [rsi], 0
    jne .bad
    cmp ecx, payload_len + 1
    jb .bad
    mov r9, rdx
    lea rsi, [payload]
    mov edx, payload_len
    mov rdi, r9
    call copy_bytes
    mov byte [r9 + payload_len], 0
    mov rax, [mock_status]
    mov [r8], rax
    inc qword [fetch_calls]
    mov eax, payload_len
    ret
.bad:
    mov eax, -1
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
good_url: db 'https://cdn.discordapp.com/a.png'
good_url_len equ $ - good_url
bad_http: db 'http://cdn.discordapp.com/a.png'
bad_http_len equ $ - bad_http
payload: db 1,2,3,4
payload_len equ $ - payload
section .data
mock_status: dq 0
fetch_calls: dq 0
section .bss
out: resb 64
stage: resd 1

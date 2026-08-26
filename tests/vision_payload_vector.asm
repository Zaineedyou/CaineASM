BITS 64
DEFAULT REL

extern vision_build_payload
global _start
%define SYS_EXIT 60

section .text
_start:
    mov dword [stage], 1
    mov eax, prompt_len
    push rax
    lea rax, [prompt]
    push rax
    mov eax, encoded_len
    push rax
    lea rax, [encoded]
    push rax
    lea rdi, [out]
    mov esi, 1024
    lea rdx, [persona]
    mov ecx, persona_len
    lea r8, [mime]
    mov r9d, mime_len
    call vision_build_payload
    add rsp, 32
    cmp eax, expected_len
    je .length_ok
    mov dword [stage], 11
    jmp .fail
.length_ok:
    lea rdi, [out]
    lea rsi, [expected]
    mov edx, expected_len
    call equal_bytes
    test al, al
    jnz .bytes_ok
    mov dword [stage], 12
    jmp .fail
.bytes_ok:

    mov dword [stage], 2
    mov eax, prompt_len
    push rax
    lea rax, [prompt]
    push rax
    mov eax, encoded_len
    push rax
    lea rax, [encoded]
    push rax
    lea rdi, [out]
    mov esi, 12
    lea rdx, [persona]
    mov ecx, persona_len
    lea r8, [mime]
    mov r9d, mime_len
    call vision_build_payload
    add rsp, 32
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
persona: db 'See "this"'
persona_len equ $ - persona
mime: db 'image/png'
mime_len equ $ - mime
encoded: db 'AQIDBA=='
encoded_len equ $ - encoded
prompt: db 'What', 10, 'now?'
prompt_len equ $ - prompt
expected: db '{"model":"meta-llama/llama-4-scout-17b-16e-instruct","messages":[{"role":"system","content":"See ', 0x5c, '"', 'this', 0x5c, '"', '"},{"role":"user","content":[{"type":"image_url","image_url":{"url":"data:image/png;base64,AQIDBA=="}},{"type":"text","text":"What', 0x5c, 'nnow?"}]}],"max_completion_tokens":1024,"temperature":0.8}'
expected_len equ $ - expected
section .bss
out: resb 1024
stage: resd 1

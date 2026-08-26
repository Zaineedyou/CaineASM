BITS 64
DEFAULT REL

global vision_build_payload

extern json_escape_append

%define VISION_MODEL_LEN 44

section .text

; RDI=dst, ESI=cap, RDX=persona, ECX=persona len, R8=mime, R9D=mime len.
; Stack args: [RSP+8]=base64 ptr, +16=base64 len, +24=prompt ptr, +32=prompt len.
; EAX=JSON length or -1. Output is NUL-terminated when successful.
vision_build_payload:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov [mime_ptr], r8
    mov [mime_len], r9d
    test r12, r12
    jz .bad
    cmp r13d, 2
    jb .bad
    test r14, r14
    jz .bad
    test r15d, r15d
    jle .bad
    mov rax, [rsp + 48]
    mov [base64_ptr], rax
    mov eax, [rsp + 56]
    mov [base64_len], eax
    mov rax, [rsp + 64]
    mov [prompt_ptr], rax
    mov eax, [rsp + 72]
    mov [prompt_len], eax
    cmp qword [base64_ptr], 0
    je .bad
    test dword [base64_len], 0xffffffff
    jle .bad
    cmp qword [prompt_ptr], 0
    je .bad
    test dword [prompt_len], 0xffffffff
    js .bad
    mov [payload_dst], r12
    mov [payload_cap], r13d
    mov dword [payload_len], 0
    lea rdi, [payload_prefix]
    mov esi, payload_prefix_len
    call append_bytes
    test eax, eax
    js .bad
    mov rdi, r14
    mov esi, r15d
    call append_escaped
    test eax, eax
    js .bad
    lea rdi, [payload_after_persona]
    mov esi, payload_after_persona_len
    call append_bytes
    test eax, eax
    js .bad
    mov rdi, [mime_ptr]
    mov esi, [mime_len]
    call append_escaped
    test eax, eax
    js .bad
    lea rdi, [payload_after_mime]
    mov esi, payload_after_mime_len
    call append_bytes
    test eax, eax
    js .bad
    mov rdi, [base64_ptr]
    mov esi, [base64_len]
    call append_bytes
    test eax, eax
    js .bad
    lea rdi, [payload_before_prompt]
    mov esi, payload_before_prompt_len
    call append_bytes
    test eax, eax
    js .bad
    mov rdi, [prompt_ptr]
    mov esi, [prompt_len]
    call append_escaped
    test eax, eax
    js .bad
    lea rdi, [payload_suffix]
    mov esi, payload_suffix_len
    call append_bytes
    test eax, eax
    js .bad
    mov eax, [payload_len]
    mov byte [r12 + rax], 0
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=bytes, ESI=len.
append_bytes:
    test rdi, rdi
    jz .bad
    test esi, esi
    js .bad
    mov eax, [payload_cap]
    dec eax
    sub eax, [payload_len]
    cmp esi, eax
    ja .bad
    mov r8, [payload_dst]
    mov eax, [payload_len]
    add r8, rax
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .done
    mov al, [rdi + rcx]
    mov [r8 + rcx], al
    inc ecx
    jmp .copy
.done:
    add [payload_len], esi
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=bytes, ESI=len.
append_escaped:
    test rdi, rdi
    jz .bad
    test esi, esi
    js .bad
    mov r8, rdi
    mov ecx, esi
    mov rdi, [payload_dst]
    mov eax, [payload_len]
    add rdi, rax
    mov esi, [payload_cap]
    dec esi
    sub esi, [payload_len]
    mov rdx, r8
    call json_escape_append
    test eax, eax
    js .bad
    add [payload_len], eax
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

section .rodata
payload_prefix: db '{"model":"meta-llama/llama-4-scout-17b-16e-instruct","messages":[{"role":"system","content":"'
payload_prefix_len equ $ - payload_prefix
payload_after_persona: db '"},{"role":"user","content":[{"type":"image_url","image_url":{"url":"data:'
payload_after_persona_len equ $ - payload_after_persona
payload_after_mime: db ';base64,'
payload_after_mime_len equ $ - payload_after_mime
payload_before_prompt: db '"}},{"type":"text","text":"'
payload_before_prompt_len equ $ - payload_before_prompt
payload_suffix: db '"}]}],"max_completion_tokens":1024,"temperature":0.8}'
payload_suffix_len equ $ - payload_suffix

section .data
payload_dst: dq 0
payload_cap: dd 0
payload_len: dd 0
mime_ptr: dq 0
mime_len: dd 0
base64_ptr: dq 0
base64_len: dd 0
prompt_ptr: dq 0
prompt_len: dd 0

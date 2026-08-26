BITS 64
DEFAULT REL

global guild_config_set
global guild_config_get
global guild_config_delete

extern store_set
extern store_get
extern store_delete

%define STORE_KEY_MAX 95
%define CONFIG_KEY_CAP 96

; Guild-scoped configuration maps to store keys of the exact form:
; cfg:<guild-id>:<setting>. Store wrappers preserve journal semantics when
; CAINE_STATE_FILE is configured.

section .text

; RDI=guild, ESI=guild len, RDX=setting, ECX=setting len,
; R8=value, R9D=value len. EAX propagates store_set status.
guild_config_set:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rbx, r8
    mov [config_value_len], r9d
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call build_config_key
    test eax, eax
    js .out
    mov esi, eax
    lea rdi, [config_key]
    mov rdx, rbx
    mov ecx, [config_value_len]
    call store_set
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=guild, ESI=guild len, RDX=setting, ECX=setting len.
; RAX=value pointer and EDX=value len, matching store_get; zero means missing.
guild_config_get:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call build_config_key
    test eax, eax
    js .missing
    mov esi, eax
    lea rdi, [config_key]
    call store_get
    jmp .out
.missing:
    xor eax, eax
    xor edx, edx
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=setting, ECX=setting len.
; EAX propagates store_delete status.
guild_config_delete:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    mov ecx, r15d
    call build_config_key
    test eax, eax
    js .out
    mov esi, eax
    lea rdi, [config_key]
    call store_delete
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=setting, ECX=setting len.
; EAX=config key len or -1. Both input parts must be non-empty and the final
; bounded key must fit the store's 95-byte maximum.
build_config_key:
    test esi, esi
    jz .bad
    test ecx, ecx
    jz .bad
    mov eax, esi
    add eax, ecx
    add eax, config_prefix_len + 1
    cmp eax, STORE_KEY_MAX
    ja .bad
    mov [config_key_len], eax
    mov r8, rdi
    mov r9d, esi
    mov r10, rdx
    mov r11d, ecx
    lea rdi, [config_key]
    lea rsi, [config_prefix]
    mov edx, config_prefix_len
    call copy_bytes
    lea rdi, [config_key + config_prefix_len]
    mov rsi, r8
    mov edx, r9d
    call copy_bytes
    lea rdi, [config_key + config_prefix_len]
    add rdi, r9
    mov byte [rdi], ':'
    inc rdi
    mov rsi, r10
    mov edx, r11d
    call copy_bytes
    mov eax, [config_key_len]
    ret
.bad:
    mov eax, -1
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
config_prefix: db 'cfg:'
config_prefix_len equ $ - config_prefix

section .data
config_key_len: dd 0
config_value_len: dd 0

section .bss
config_key: resb CONFIG_KEY_CAP

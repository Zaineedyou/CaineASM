BITS 64
DEFAULT REL

global asm_bot_main
global discord_token_ptr
global discord_token_len
global groq_key_ptr
global groq_key_len
global bot_prefix_ptr
global bot_prefix_len

extern gateway_run

%define SYS_WRITE 1

section .text

; System V ABI: RDI is envp supplied by the minimal C bootstrap.
asm_bot_main:
    push r12
    mov r12, rdi
    call load_environment
    cmp dword [discord_token_len], 0
    je .missing
    cmp dword [groq_key_len], 0
    je .missing
    call gateway_run
    pop r12
    ret
.missing:
    mov edi, 2
    lea rsi, [configuration_error]
    mov edx, configuration_error_len
    mov eax, SYS_WRITE
    syscall
    mov eax, 78
    pop r12
    ret

load_environment:
    mov r13, r12
.next:
    mov rbx, [r13]
    test rbx, rbx
    jz .done
    mov rdi, rbx
    lea rsi, [env_discord]
    mov ecx, env_discord_len
    call has_prefix
    test al, al
    jnz .discord
    mov rdi, rbx
    lea rsi, [env_groq]
    mov ecx, env_groq_len
    call has_prefix
    test al, al
    jnz .groq
    mov rdi, rbx
    lea rsi, [env_prefix]
    mov ecx, env_prefix_len
    call has_prefix
    test al, al
    jnz .prefix
.advance:
    add r13, 8
    jmp .next
.discord:
    lea rax, [rbx + env_discord_len]
    mov [discord_token_ptr], rax
    mov rdi, rax
    call cstring_length
    mov [discord_token_len], eax
    jmp .advance
.groq:
    lea rax, [rbx + env_groq_len]
    mov [groq_key_ptr], rax
    mov rdi, rax
    call cstring_length
    mov [groq_key_len], eax
    jmp .advance
.prefix:
    lea rax, [rbx + env_prefix_len]
    mov [bot_prefix_ptr], rax
    mov rdi, rax
    call cstring_length
    mov [bot_prefix_len], eax
    jmp .advance
.done:
    ret

; RDI=input, RSI=prefix, ECX=prefix length. AL=1 when it matches.
has_prefix:
    xor edx, edx
.loop:
    cmp edx, ecx
    jae .yes
    mov al, [rdi + rdx]
    cmp al, [rsi + rdx]
    jne .no
    inc edx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

cstring_length:
    xor eax, eax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    cmp rax, 4096
    jb .loop
.done:
    ret

section .rodata
env_discord: db 'DISCORD_TOKEN='
env_discord_len equ $ - env_discord
env_groq: db 'GROQ_API_KEY='
env_groq_len equ $ - env_groq
env_prefix: db 'BOT_PREFIX='
env_prefix_len equ $ - env_prefix
configuration_error: db 'caine-asm: DISCORD_TOKEN and GROQ_API_KEY are required', 10
configuration_error_len equ $ - configuration_error

section .data
discord_token_ptr: dq 0
discord_token_len: dd 0
groq_key_ptr: dq 0
groq_key_len: dd 0
bot_prefix_ptr: dq 0
bot_prefix_len: dd 0

BITS 64
DEFAULT REL

global _start

extern guild_config_set
extern guild_config_get
extern guild_config_delete

%define SYS_EXIT 60

section .text
_start:
    ; Set/get uses an exact cfg:<guild>:<setting> namespace.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    lea r8, [value_one]
    mov r9d, value_one_len
    call guild_config_set
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    call guild_config_get
    test rax, rax
    jz .fail
    cmp edx, value_one_len
    jne .fail
    mov rdi, rax
    lea rsi, [value_one]
    mov edx, value_one_len
    call equal_bytes
    test al, al
    jz .fail

    ; Same setting in another guild does not collide.
    lea rdi, [guild_two]
    mov esi, guild_two_len
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    call guild_config_get
    test rax, rax
    jnz .fail

    ; Update is replacement, not a second visible state entry.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    lea r8, [value_two]
    mov r9d, value_two_len
    call guild_config_set
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    call guild_config_get
    test rax, rax
    jz .fail
    cmp edx, value_two_len
    jne .fail
    mov rdi, rax
    lea rsi, [value_two]
    mov edx, value_two_len
    call equal_bytes
    test al, al
    jz .fail

    ; Delete makes only the exact guild/setting record absent.
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    call guild_config_delete
    test eax, eax
    jnz .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    call guild_config_get
    test rax, rax
    jnz .fail

    ; Empty namespace parts and a final key beyond the store cap are rejected.
    lea rdi, [guild_one]
    xor esi, esi
    lea rdx, [setting_model]
    mov ecx, setting_model_len
    lea r8, [value_one]
    mov r9d, value_one_len
    call guild_config_set
    cmp eax, -1
    jne .fail
    lea rdi, [guild_one]
    mov esi, guild_one_len
    lea rdx, [setting_model]
    xor ecx, ecx
    lea r8, [value_one]
    mov r9d, value_one_len
    call guild_config_set
    cmp eax, -1
    jne .fail
    lea rdi, [long_guild]
    mov esi, long_guild_len
    lea rdx, [long_setting]
    mov ecx, long_setting_len
    lea r8, [value_one]
    mov r9d, value_one_len
    call guild_config_set
    cmp eax, -1
    jne .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall

; RDI and RSI buffers, EDX count. AL=1 when equal.
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
guild_one: db 'guild-one'
guild_one_len equ $ - guild_one
guild_two: db 'guild-two'
guild_two_len equ $ - guild_two
setting_model: db 'model'
setting_model_len equ $ - setting_model
value_one: db 'llama-3.3-70b-versatile'
value_one_len equ $ - value_one
value_two: db 'qwen/qwen3-32b'
value_two_len equ $ - value_two
long_guild: times 70 db 'g'
long_guild_len equ $ - long_guild
long_setting: times 25 db 's'
long_setting_len equ $ - long_setting

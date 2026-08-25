BITS 64
DEFAULT REL

global _start

extern persist_configure
extern persist_append_set
extern persist_append_delete
extern persist_replay

%define SYS_OPENAT 257
%define SYS_WRITE 1
%define SYS_CLOSE 3
%define SYS_FSTAT 5
%define SYS_UNLINK 87
%define AT_FDCWD -100
%define O_WRONLY 1
%define O_CREAT 64
%define O_APPEND 1024
%define O_CLOEXEC 524288
%define FILE_MODE 0600o
%define REPLAY_TAIL 0x40000000

section .text
_start:
    lea rdi, [state_path]
    mov eax, SYS_UNLINK
    syscall

    lea rdi, [state_path]
    mov esi, state_path_len
    call persist_configure
    test eax, eax
    js fail

    lea rdi, [key_alpha]
    mov esi, key_alpha_len
    lea rdx, [value_one]
    mov ecx, value_one_len
    call persist_append_set
    test eax, eax
    jnz fail

    lea rdi, [key_beta]
    mov esi, key_beta_len
    lea rdx, [value_two]
    mov ecx, value_two_len
    call persist_append_set
    test eax, eax
    jnz fail

    lea rdi, [key_alpha]
    mov esi, key_alpha_len
    call persist_append_delete
    test eax, eax
    jnz fail

    mov dword [callback_count], 0
    lea rdi, [replay_callback]
    call persist_replay
    cmp eax, 3
    jne fail
    cmp dword [callback_count], 3
    jne fail

    ; The journal must be explicitly restricted to its owner.
    mov eax, SYS_OPENAT
    mov edi, AT_FDCWD
    lea rsi, [state_path]
    xor edx, edx
    xor r10d, r10d
    syscall
    test rax, rax
    js fail
    mov ebx, eax
    mov eax, SYS_FSTAT
    mov edi, ebx
    lea rsi, [stat_buf]
    syscall
    test rax, rax
    js fail_close
    mov eax, [stat_buf + 24]
    and eax, 0777o
    cmp eax, FILE_MODE
    jne fail_close
    mov eax, SYS_CLOSE
    mov edi, ebx
    syscall

    ; A partial final header is a recoverable interrupted-write tail.
    mov eax, SYS_OPENAT
    mov edi, AT_FDCWD
    lea rsi, [state_path]
    mov edx, O_WRONLY | O_APPEND | O_CLOEXEC
    xor r10d, r10d
    syscall
    test rax, rax
    js fail
    mov ebx, eax
    mov eax, SYS_WRITE
    mov edi, ebx
    lea rsi, [partial_byte]
    mov edx, 1
    syscall
    cmp eax, 1
    jne fail_close
    mov eax, SYS_CLOSE
    mov edi, ebx
    syscall

    mov dword [callback_count], 0
    lea rdi, [replay_callback]
    call persist_replay
    cmp eax, REPLAY_TAIL | 3
    jne fail
    cmp dword [callback_count], 3
    jne fail

    ; A full but malformed header is rejected instead of silently replayed.
    lea rdi, [state_path]
    mov eax, SYS_UNLINK
    syscall
    mov eax, SYS_OPENAT
    mov edi, AT_FDCWD
    lea rsi, [state_path]
    mov edx, O_WRONLY | O_CREAT | O_CLOEXEC
    mov r10d, FILE_MODE
    syscall
    test rax, rax
    js fail
    mov ebx, eax
    mov eax, SYS_WRITE
    mov edi, ebx
    lea rsi, [bad_header]
    mov edx, bad_header_len
    syscall
    cmp eax, bad_header_len
    jne fail_close
    mov eax, SYS_CLOSE
    mov edi, ebx
    syscall
    lea rdi, [replay_callback]
    call persist_replay
    cmp eax, -1
    jne fail

    ; Disabled persistence remains a valid volatile-mode no-op.
    xor edi, edi
    xor esi, esi
    call persist_configure
    test eax, eax
    js fail
    lea rdi, [key_alpha]
    mov esi, key_alpha_len
    lea rdx, [value_one]
    mov ecx, value_one_len
    call persist_append_set
    test eax, eax
    jnz fail

    ; Invalid input stays rejected even if persistence is disabled.
    lea rdi, [key_alpha]
    xor esi, esi
    lea rdx, [value_one]
    mov ecx, value_one_len
    call persist_append_set
    cmp eax, -1
    jne fail

    lea rdi, [state_path]
    mov eax, SYS_UNLINK
    syscall
    mov eax, 60
    xor edi, edi
    syscall

fail_close:
    mov eax, SYS_CLOSE
    mov edi, ebx
    syscall
fail:
    mov eax, 60
    mov edi, 1
    syscall

; EDI=op, RSI=key, EDX=key len, RCX=value, R8D=value len.
replay_callback:
    mov eax, [callback_count]
    cmp eax, 0
    je .set_alpha
    cmp eax, 1
    je .set_beta
    cmp eax, 2
    je .delete_alpha
    jmp .bad
.set_alpha:
    cmp edi, 1
    jne .bad
    cmp edx, key_alpha_len
    jne .bad
    cmp r8d, value_one_len
    jne .bad
    lea r9, [key_alpha]
    mov r10d, key_alpha_len
    call assert_equal
    test eax, eax
    jnz .bad
    mov rsi, rcx
    lea r9, [value_one]
    mov r10d, value_one_len
    call assert_equal
    test eax, eax
    jnz .bad
    jmp .ok
.set_beta:
    cmp edi, 1
    jne .bad
    cmp edx, key_beta_len
    jne .bad
    cmp r8d, value_two_len
    jne .bad
    lea r9, [key_beta]
    mov r10d, key_beta_len
    call assert_equal
    test eax, eax
    jnz .bad
    mov rsi, rcx
    lea r9, [value_two]
    mov r10d, value_two_len
    call assert_equal
    test eax, eax
    jnz .bad
    jmp .ok
.delete_alpha:
    cmp edi, 2
    jne .bad
    cmp edx, key_alpha_len
    jne .bad
    test r8d, r8d
    jnz .bad
    lea r9, [key_alpha]
    mov r10d, key_alpha_len
    call assert_equal
    test eax, eax
    jnz .bad
.ok:
    inc dword [callback_count]
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RSI=input, R9=expected, R10D=count. EAX=0 equal, -1 otherwise.
assert_equal:
    xor eax, eax
.loop:
    cmp eax, r10d
    jae .yes
    mov r11b, [rsi + rax]
    cmp r11b, [r9 + rax]
    jne .no
    inc eax
    jmp .loop
.yes:
    xor eax, eax
    ret
.no:
    mov eax, -1
    ret

section .rodata
state_path: db '/tmp/caineasm-persist-state', 0
state_path_len equ $ - state_path - 1
key_alpha: db 'afk:1:2'
key_alpha_len equ $ - key_alpha
key_beta: db 'xp:1:2'
key_beta_len equ $ - key_beta
value_one: db 'away'
value_one_len equ $ - value_one
value_two: db '42'
value_two_len equ $ - value_two
partial_byte: db 0
bad_header: db 'BAD!', 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
bad_header_len equ $ - bad_header

section .bss
callback_count: resd 1
stat_buf: resb 256

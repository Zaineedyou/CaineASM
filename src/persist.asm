BITS 64
DEFAULT REL

global persist_configure
global persist_append_set
global persist_append_delete
global persist_replay

; Optional append-only state journal. It deliberately operates below command and
; policy modules: callers provide bounded store keys and values, while replay
; supplies each verified record to a NASM callback.
;
; Record wire format (little-endian):
;   magic[4] = "CSL1", version[1] = 1, op[1], key_len[u16], value_len[u16],
;   sequence[u32], key[key_len], value[value_len], fnv1a32[u32].
; Only a complete checksum-valid record is replayed. A short final record is
; ignored as a crash/interrupted-write tail; malformed complete records fail.

%define SYS_READ       0
%define SYS_WRITE      1
%define SYS_CLOSE      3
%define SYS_FCHMOD     91
%define SYS_OPENAT     257

%define AT_FDCWD       -100
%define O_WRONLY       1
%define O_CREAT        64
%define O_APPEND       1024
%define O_NOFOLLOW     131072
%define O_CLOEXEC      524288
%define OPEN_WRITE_FLAGS (O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_CLOEXEC)
%define OPEN_READ_FLAGS (O_NOFOLLOW | O_CLOEXEC)

%define FILE_MODE      0600o
%define KEY_MAX        95
%define VALUE_MAX      511
%define HEADER_SIZE    14
%define CHECKSUM_SIZE  4
%define RECORD_CAP     (HEADER_SIZE + KEY_MAX + VALUE_MAX + CHECKSUM_SIZE)
%define RECORD_MAGIC   0x314c5343
%define RECORD_VERSION 1
%define OP_SET         1
%define OP_DELETE      2
%define REPLAY_TAIL    0x40000000

section .text

; RDI=path, ESI=path length. A zero length disables persistence.
; EAX=0 success, -1 invalid.
persist_configure:
    test esi, esi
    jz .disable
    cmp esi, 4095
    ja .bad
    mov ecx, esi
    xor edx, edx
.copy:
    cmp edx, ecx
    jae .copied
    mov al, [rdi + rdx]
    test al, al
    jz .bad
    mov [persist_path + rdx], al
    inc edx
    jmp .copy
.copied:
    mov byte [persist_path + rdx], 0
    mov [persist_path_len], ecx
    xor eax, eax
    ret
.disable:
    mov dword [persist_path_len], 0
    mov byte [persist_path], 0
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; RDI=key, ESI=key length, RDX=value, ECX=value length. EAX=0 or -1.
persist_append_set:
    mov r8d, OP_SET
    jmp persist_append_record

; RDI=key, ESI=key length. EAX=0 or -1.
persist_append_delete:
    xor edx, edx
    xor ecx, ecx
    mov r8d, OP_DELETE
    jmp persist_append_record

; RDI=key, ESI=key length, RDX=value, ECX=value length, R8D=record operation.
; A disabled journal is a successful no-op after input validation.
persist_append_record:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    cmp r13d, 1
    jb .bad
    cmp r13d, KEY_MAX
    ja .bad
    cmp r8d, OP_SET
    je .set
    cmp r8d, OP_DELETE
    jne .bad
    test r15d, r15d
    jnz .bad
    jmp .validated
.set:
    cmp r15d, VALUE_MAX
    ja .bad
    test r14, r14
    jz .bad
.validated:
    cmp dword [persist_path_len], 0
    je .ok

    mov dword [persist_record], RECORD_MAGIC
    mov byte [persist_record + 4], RECORD_VERSION
    mov byte [persist_record + 5], r8b
    mov [persist_record + 6], r13w
    mov [persist_record + 8], r15w
    mov eax, [persist_sequence]
    inc eax
    mov [persist_record + 10], eax

    lea rdi, [persist_record + HEADER_SIZE]
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [persist_record + HEADER_SIZE]
    add rdi, r13
    mov rsi, r14
    mov edx, r15d
    call copy_bytes

    mov eax, HEADER_SIZE
    add eax, r13d
    add eax, r15d
    mov ebx, eax
    lea rdi, [persist_record]
    mov esi, ebx
    call fnv1a32
    mov [persist_record + rbx], eax
    add ebx, CHECKSUM_SIZE

    mov eax, SYS_OPENAT
    mov edi, AT_FDCWD
    lea rsi, [persist_path]
    mov edx, OPEN_WRITE_FLAGS
    mov r10d, FILE_MODE
    syscall
    test rax, rax
    js .bad
    mov r12d, eax

    mov eax, SYS_FCHMOD
    mov edi, r12d
    mov esi, FILE_MODE
    syscall
    test rax, rax
    js .close_bad

    lea rsi, [persist_record]
    mov edx, ebx
.write:
    test edx, edx
    jz .close_ok
    mov eax, SYS_WRITE
    mov edi, r12d
    syscall
    test rax, rax
    js .write_error
    jz .close_bad
    add rsi, rax
    sub rdx, rax
    jmp .write
.write_error:
    cmp eax, -4                         ; EINTR
    je .write
.close_bad:
    mov eax, SYS_CLOSE
    mov edi, r12d
    syscall
    jmp .bad
.close_ok:
    mov eax, SYS_CLOSE
    mov edi, r12d
    syscall
    test rax, rax
    js .bad
    mov eax, [persist_record + 10]
    mov [persist_sequence], eax
.ok:
    xor eax, eax
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

; RDI=callback. Callback ABI: EDI=op, RSI=key, EDX=key len,
; RCX=value, R8D=value len. It returns negative on failure.
; EAX=number of applied records, optionally ORed with REPLAY_TAIL for a
; truncated final record; -1 for open/read/complete-record validation failure.
persist_replay:
    test rdi, rdi
    jz .bad_no_fd
    cmp dword [persist_path_len], 0
    je .empty
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    xor r14d, r14d                       ; applied count
    xor r15d, r15d                       ; tail flag

    mov eax, SYS_OPENAT
    mov edi, AT_FDCWD
    lea rsi, [persist_path]
    mov edx, OPEN_READ_FLAGS
    xor r10d, r10d
    syscall
    test rax, rax
    jns .opened
    cmp eax, -2                           ; ENOENT: no state yet
    je .finish
    jmp .fail
.opened:
    mov r13d, eax
.next:
    mov edi, r13d
    lea rsi, [persist_record]
    mov edx, HEADER_SIZE
    call read_exact_or_eof
    cmp eax, 1
    je .header
    cmp eax, 0
    je .finish_close
    cmp eax, 2
    je .tail_close
    jmp .fail_close
.header:
    cmp dword [persist_record], RECORD_MAGIC
    jne .fail_close
    cmp byte [persist_record + 4], RECORD_VERSION
    jne .fail_close
    movzx ebx, byte [persist_record + 5]
    cmp ebx, OP_SET
    je .operation_ok
    cmp ebx, OP_DELETE
    jne .fail_close
.operation_ok:
    movzx eax, word [persist_record + 6]
    test eax, eax
    jz .fail_close
    cmp eax, KEY_MAX
    ja .fail_close
    movzx ecx, word [persist_record + 8]
    cmp ecx, VALUE_MAX
    ja .fail_close
    cmp ebx, OP_DELETE
    jne .value_ok
    test ecx, ecx
    jnz .fail_close
.value_ok:
    add eax, ecx
    add eax, CHECKSUM_SIZE
    mov ebx, eax
    mov edi, r13d
    lea rsi, [persist_record + HEADER_SIZE]
    mov edx, ebx
    call read_exact_or_eof
    cmp eax, 1
    je .verify
    cmp eax, 2
    je .tail_close
    cmp eax, 0
    je .tail_close
    jmp .fail_close
.verify:
    movzx eax, word [persist_record + 6]
    movzx ecx, word [persist_record + 8]
    add eax, ecx
    add eax, HEADER_SIZE
    mov ebx, eax
    lea rdi, [persist_record]
    mov esi, ebx
    call fnv1a32
    cmp eax, [persist_record + rbx]
    jne .fail_close
    mov eax, [persist_record + 10]
    mov [persist_sequence], eax

    movzx edi, byte [persist_record + 5]
    lea rsi, [persist_record + HEADER_SIZE]
    movzx edx, word [persist_record + 6]
    lea rcx, [persist_record + HEADER_SIZE]
    add rcx, rdx
    movzx r8d, word [persist_record + 8]
    call r12
    test eax, eax
    js .fail_close
    inc r14d
    jmp .next
.tail_close:
    mov r15d, REPLAY_TAIL
.finish_close:
    mov eax, SYS_CLOSE
    mov edi, r13d
    syscall
    test rax, rax
    js .fail
.finish:
    mov eax, r14d
    or eax, r15d
    jmp .out
.fail_close:
    mov eax, SYS_CLOSE
    mov edi, r13d
    syscall
.fail:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.empty:
    xor eax, eax
    ret
.bad_no_fd:
    mov eax, -1
    ret

; RDI=fd, RSI=destination, EDX=required bytes.
; EAX=1 full record, 0 clean EOF, 2 partial/truncated, -1 read failure.
read_exact_or_eof:
    xor r8d, r8d
.read:
    test edx, edx
    jz .full
    mov eax, SYS_READ
    syscall
    test rax, rax
    js .error
    jz .eof
    add rsi, rax
    sub rdx, rax
    add r8, rax
    jmp .read
.error:
    cmp eax, -4                           ; EINTR
    je .read
    mov eax, -1
    ret
.eof:
    test r8, r8
    jz .clean_eof
    mov eax, 2
    ret
.clean_eof:
    xor eax, eax
    ret
.full:
    mov eax, 1
    ret

; RDI=buffer, ESI=length. EAX=FNV-1a 32-bit.
fnv1a32:
    mov eax, 2166136261
    xor edx, edx
.loop:
    cmp edx, esi
    jae .done
    movzx ecx, byte [rdi + rdx]
    xor eax, ecx
    imul eax, eax, 16777619
    inc edx
    jmp .loop
.done:
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

section .data
persist_path_len: dd 0
persist_sequence: dd 0

section .bss
persist_path: resb 4096
align 16
persist_record: resb RECORD_CAP

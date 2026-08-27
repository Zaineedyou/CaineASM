BITS 64
DEFAULT REL

global ai_rate_allow
global message_rate_allow

%define SYS_CLOCK_GETTIME 228
%define CLOCK_MONOTONIC 1
%define RATE_SLOTS 32
%define RATE_MAX 10
%define USER_ID_CAP 64
%define RATE_WINDOW_NS 60000000000
%define MESSAGE_RATE_SLOTS 64
%define MESSAGE_RATE_INTERVAL_NS 2000000000

section .text

; RDI=user ID, ESI=len. AL=1 when an AI request is admitted, 0 when limited
; or malformed. State is bounded and process-local, matching source's transient map.
ai_rate_allow:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    test r12, r12
    jz .deny
    test r13d, r13d
    jle .deny
    cmp r13d, USER_ID_CAP - 1
    ja .deny
    mov eax, SYS_CLOCK_GETTIME
    mov edi, CLOCK_MONOTONIC
    lea rsi, [clock_spec]
    syscall
    test eax, eax
    js .deny
    mov rax, [clock_spec]
    imul rax, rax, 1000000000
    add rax, [clock_spec + 8]
    mov r14, rax
    mov rdi, r12
    mov esi, r13d
    call rate_find_or_alloc
    test eax, eax
    js .deny
    mov r15d, eax
    mov rbx, r14
    mov rax, RATE_WINDOW_NS
    sub rbx, rax
    mov ecx, [rate_counts + r15 * 4]
    xor edx, edx
.prune:
    cmp edx, ecx
    jae .pruned
    mov eax, r15d
    imul eax, RATE_MAX
    add eax, edx
    mov rax, [rate_times + rax * 8]
    cmp rax, rbx
    ja .keep
    inc edx
    jmp .prune
.keep:
    ; Shift surviving timestamps down once the first retained entry is found.
    mov esi, ecx
    sub esi, edx
    xor edi, edi
.shift:
    cmp edi, esi
    jae .set_count
    mov eax, r15d
    imul eax, RATE_MAX
    add eax, edx
    add eax, edi
    mov r8, [rate_times + rax * 8]
    mov eax, r15d
    imul eax, RATE_MAX
    add eax, edi
    mov [rate_times + rax * 8], r8
    inc edi
    jmp .shift
.set_count:
    mov ecx, esi
.pruned:
    mov [rate_counts + r15 * 4], ecx
    cmp ecx, RATE_MAX
    jae .deny
    mov eax, r15d
    imul eax, RATE_MAX
    add eax, ecx
    mov [rate_times + rax * 8], r14
    inc ecx
    mov [rate_counts + r15 * 4], ecx
    mov al, 1
    jmp .out
.deny:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=user ID, ESI=len. AL=1 when a message is admitted, 0 for malformed,
; capacity-exhausted, or less-than-two-second repeat messages. The source map is
; transient; this fixed-capacity adaptation fails closed rather than allocating.
message_rate_allow:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    test r12, r12
    jz .deny
    test r13d, r13d
    jle .deny
    cmp r13d, USER_ID_CAP - 1
    ja .deny
    mov eax, SYS_CLOCK_GETTIME
    mov edi, CLOCK_MONOTONIC
    lea rsi, [message_clock_spec]
    syscall
    test eax, eax
    js .deny
    mov rax, [message_clock_spec]
    imul rax, rax, 1000000000
    add rax, [message_clock_spec + 8]
    mov r14, rax
    mov rdi, r12
    mov esi, r13d
    call message_rate_find_or_alloc
    test eax, eax
    js .deny
    mov ebx, eax
    cmp dword [message_rate_seen + rbx * 4], 0
    je .allow
    mov rax, [message_rate_times + rbx * 8]
    cmp r14, rax
    jb .deny
    sub r14, rax
    mov rax, MESSAGE_RATE_INTERVAL_NS
    cmp r14, rax
    jb .deny
.allow:
    mov rax, [message_clock_spec]
    imul rax, rax, 1000000000
    add rax, [message_clock_spec + 8]
    mov [message_rate_times + rbx * 8], rax
    mov dword [message_rate_seen + rbx * 4], 1
    mov al, 1
    jmp .out
.deny:
    xor eax, eax
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=user ID, ESI=len. EAX=slot or -1. This never evicts a recent identity;
; exhausted fixed capacity therefore fails closed.
message_rate_find_or_alloc:
    push rbx
    mov rbx, rdi
    xor eax, eax
.scan:
    cmp eax, MESSAGE_RATE_SLOTS
    jae .allocate_scan
    cmp dword [message_rate_active + rax * 4], 0
    je .next
    cmp esi, [message_rate_key_lens + rax * 4]
    jne .next
    mov r8d, eax
    imul r8, USER_ID_CAP
    xor ecx, ecx
.compare:
    cmp ecx, esi
    jae .found
    mov dl, [rbx + rcx]
    cmp dl, [message_rate_keys + r8 + rcx]
    jne .next
    inc ecx
    jmp .compare
.next:
    inc eax
    jmp .scan
.allocate_scan:
    xor eax, eax
.free:
    cmp eax, MESSAGE_RATE_SLOTS
    jae .bad
    cmp dword [message_rate_active + rax * 4], 0
    je .allocate
    inc eax
    jmp .free
.allocate:
    mov dword [message_rate_active + rax * 4], 1
    mov [message_rate_key_lens + rax * 4], esi
    mov dword [message_rate_seen + rax * 4], 0
    mov r8d, eax
    imul r8, USER_ID_CAP
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .found
    mov dl, [rbx + rcx]
    mov [message_rate_keys + r8 + rcx], dl
    inc ecx
    jmp .copy
.found:
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

; RDI=user ID, ESI=len. EAX=slot or -1.
rate_find_or_alloc:
    push rbx
    mov rbx, rdi
    xor eax, eax
.scan:
    cmp eax, RATE_SLOTS
    jae .allocate_scan
    cmp dword [rate_active + rax * 4], 0
    je .next
    cmp esi, [rate_key_lens + rax * 4]
    jne .next
    mov r8d, eax
    imul r8, USER_ID_CAP
    xor ecx, ecx
.compare:
    cmp ecx, esi
    jae .found
    mov dl, [rbx + rcx]
    cmp dl, [rate_keys + r8 + rcx]
    jne .next
    inc ecx
    jmp .compare
.next:
    inc eax
    jmp .scan
.allocate_scan:
    xor eax, eax
.free:
    cmp eax, RATE_SLOTS
    jae .bad
    cmp dword [rate_active + rax * 4], 0
    je .allocate
    inc eax
    jmp .free
.allocate:
    mov dword [rate_active + rax * 4], 1
    mov [rate_key_lens + rax * 4], esi
    mov dword [rate_counts + rax * 4], 0
    mov r8d, eax
    imul r8, USER_ID_CAP
    xor ecx, ecx
.copy:
    cmp ecx, esi
    jae .found
    mov dl, [rbx + rcx]
    mov [rate_keys + r8 + rcx], dl
    inc ecx
    jmp .copy
.found:
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

section .bss
clock_spec: resq 2
message_clock_spec: resq 2
message_rate_active: resd MESSAGE_RATE_SLOTS
message_rate_key_lens: resd MESSAGE_RATE_SLOTS
message_rate_seen: resd MESSAGE_RATE_SLOTS
message_rate_keys: resb MESSAGE_RATE_SLOTS * USER_ID_CAP
message_rate_times: resq MESSAGE_RATE_SLOTS
rate_active: resd RATE_SLOTS
rate_key_lens: resd RATE_SLOTS
rate_counts: resd RATE_SLOTS
rate_keys: resb RATE_SLOTS * USER_ID_CAP
rate_times: resq RATE_SLOTS * RATE_MAX

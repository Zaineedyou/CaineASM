BITS 64
DEFAULT REL

global guild_word_add
global guild_word_remove
global guild_word_matches
global guild_channel_disable
global guild_channel_enable
global guild_channel_is_disabled

extern store_set
extern store_get
extern store_delete
extern store_foreach

%define STORE_KEY_MAX 95
%define POLICY_KEY_CAP 96

; Bounded durable policy state. Banned-word entries use word:<guild>:<word>
; while disabled-channel entries use disabled:<guild>:<channel>. All reads of
; the store are via public store_get/store_foreach; callbacks never mutate it.

section .text

; RDI=guild, ESI=guild len, RDX=word, ECX=word len. EAX=store status.
guild_word_add:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    lea rdi, [word_prefix]
    mov esi, word_prefix_len
    mov rdx, r12
    mov ecx, r13d
    mov r8, r14
    mov r9d, r15d
    call build_policy_key
    test eax, eax
    js .out
    mov esi, eax
    lea rdi, [policy_key]
    lea rdx, [present_value]
    mov ecx, present_value_len
    call store_set
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=word, ECX=word len. EAX=store status.
guild_word_remove:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    lea rdi, [word_prefix]
    mov esi, word_prefix_len
    mov rdx, r12
    mov ecx, r13d
    mov r8, r14
    mov r9d, r15d
    call build_policy_key
    test eax, eax
    js .out
    mov esi, eax
    lea rdi, [policy_key]
    call store_delete
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=content, ECX=content len.
; RAX=matched word pointer, EDX=word len; zero means no exact-guild match.
; Content and configured words are compared ASCII case-insensitively.
guild_word_matches:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .missing
    test r13d, r13d
    jz .missing
    test r14, r14
    jz .missing
    test r15d, r15d
    jle .missing
    mov [match_guild_ptr], r12
    mov [match_guild_len], r13d
    mov [match_text_ptr], r14
    mov [match_text_len], r15d
    mov qword [match_word_ptr], 0
    mov dword [match_word_len], 0
    lea rdi, [word_match_callback]
    xor esi, esi
    call store_foreach
    test eax, eax
    js .missing
    mov rax, [match_word_ptr]
    mov edx, [match_word_len]
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

; RDI=guild, ESI=guild len, RDX=channel, ECX=channel len. EAX=store status.
guild_channel_disable:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    lea rdi, [disabled_prefix]
    mov esi, disabled_prefix_len
    mov rdx, r12
    mov ecx, r13d
    mov r8, r14
    mov r9d, r15d
    call build_policy_key
    test eax, eax
    js .out
    mov esi, eax
    lea rdi, [policy_key]
    lea rdx, [present_value]
    mov ecx, present_value_len
    call store_set
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=channel, ECX=channel len. EAX=store status.
guild_channel_enable:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    lea rdi, [disabled_prefix]
    mov esi, disabled_prefix_len
    mov rdx, r12
    mov ecx, r13d
    mov r8, r14
    mov r9d, r15d
    call build_policy_key
    test eax, eax
    js .out
    mov esi, eax
    lea rdi, [policy_key]
    call store_delete
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; RDI=guild, ESI=guild len, RDX=channel, ECX=channel len. AL=1 when disabled.
guild_channel_is_disabled:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    lea rdi, [disabled_prefix]
    mov esi, disabled_prefix_len
    mov rdx, r12
    mov ecx, r13d
    mov r8, r14
    mov r9d, r15d
    call build_policy_key
    test eax, eax
    js .no
    mov esi, eax
    lea rdi, [policy_key]
    call store_get
    test rax, rax
    jz .no
    mov al, 1
    jmp .out
.no:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; store_foreach callback. It checks a word:<guild>:<word> key and stops at
; the first configured word that occurs in the supplied text.
word_match_callback:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rsi
    mov r13d, edx
    mov eax, [match_guild_len]
    add eax, word_prefix_len + 1
    cmp r13d, eax
    jbe .ignore
    xor ebx, ebx
.prefix_loop:
    cmp ebx, word_prefix_len
    jae .guild_loop
    mov al, [r12 + rbx]
    cmp al, [word_prefix + rbx]
    jne .ignore
    inc ebx
    jmp .prefix_loop
.guild_loop:
    mov ebx, [match_guild_len]
    xor ecx, ecx
.guild_bytes:
    cmp ecx, ebx
    jae .separator
    mov al, [r12 + rcx + word_prefix_len]
    mov rdx, [match_guild_ptr]
    cmp al, [rdx + rcx]
    jne .ignore
    inc ecx
    jmp .guild_bytes
.separator:
    mov eax, word_prefix_len
    add eax, ebx
    cmp byte [r12 + rax], ':'
    jne .ignore
    inc eax
    mov edx, r13d
    sub edx, eax
    jle .ignore
    lea rdi, [r12 + rax]
    mov esi, edx
    mov rdx, [match_text_ptr]
    mov ecx, [match_text_len]
    call contains_ascii_folded
    test al, al
    jz .ignore
    mov [match_word_ptr], rdi
    mov [match_word_len], esi
    mov eax, 1
    jmp .out
.ignore:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=needle, ESI=needle len, RDX=haystack, ECX=haystack len.
; AL=1 if needle occurs in haystack using ASCII case-insensitive comparison.
contains_ascii_folded:
    test esi, esi
    jz .no
    cmp esi, ecx
    ja .no
    mov r8d, ecx
    sub r8d, esi
    xor r9d, r9d
.outer:
    cmp r9d, r8d
    ja .no
    xor r10d, r10d
.inner:
    cmp r10d, esi
    jae .yes
    mov al, [rdi + r10]
    call fold_ascii
    mov r11b, al
    lea rax, [rdx + r9]
    mov al, [rax + r10]
    call fold_ascii
    cmp al, r11b
    jne .next
    inc r10d
    jmp .inner
.next:
    inc r9d
    jmp .outer
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; AL=byte; AL=ASCII lowercase for A-Z, unchanged otherwise.
fold_ascii:
    cmp al, 'A'
    jb .out
    cmp al, 'Z'
    ja .out
    add al, 'a' - 'A'
.out:
    ret

; RDI=prefix, ESI=prefix len, RDX=guild, ECX=guild len,
; R8=suffix, R9D=suffix len. EAX=final key len or -1.
build_policy_key:
    test esi, esi
    jz .bad
    test ecx, ecx
    jz .bad
    test r9d, r9d
    jz .bad
    mov eax, esi
    add eax, ecx
    add eax, r9d
    add eax, 1
    cmp eax, STORE_KEY_MAX
    ja .bad
    mov [policy_key_len], eax
    mov r10, rdi
    mov r11d, esi
    mov r12, rdx
    mov r13d, ecx
    mov r14, r8
    mov r15d, r9d
    lea rdi, [policy_key]
    mov rsi, r10
    mov edx, r11d
    call copy_bytes
    lea rdi, [policy_key]
    add rdi, r11
    mov rsi, r12
    mov edx, r13d
    call copy_bytes
    lea rdi, [policy_key]
    add rdi, r11
    add rdi, r13
    mov byte [rdi], ':'
    inc rdi
    mov rsi, r14
    mov edx, r15d
    call copy_bytes
    mov eax, [policy_key_len]
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
word_prefix: db 'word:'
word_prefix_len equ $ - word_prefix
disabled_prefix: db 'disabled:'
disabled_prefix_len equ $ - disabled_prefix
present_value: db '1'
present_value_len equ $ - present_value

section .data
policy_key_len: dd 0
match_guild_ptr: dq 0
match_guild_len: dd 0
match_text_ptr: dq 0
match_text_len: dd 0
match_word_ptr: dq 0
match_word_len: dd 0

section .bss
policy_key: resb POLICY_KEY_CAP

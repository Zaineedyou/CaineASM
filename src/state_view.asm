BITS 64
DEFAULT REL

global state_format_afk_list
global state_format_leaderboard
global state_format_banned_words

extern store_foreach

%define OUTPUT_CAP 2000
%define MAX_REASON_DISPLAY 160
%define MAX_LEADERBOARD_ROWS 20
%define MAX_ENTRIES 128
%define AFK_ROW_FIXED_LEN 5
%define LEADERBOARD_ROW_FIXED_LEN 9

; Stateful render context is deliberately private to this single-threaded bot
; checkpoint. Both public formatters clamp output to Discord's 2000-byte limit.
; RDI=guild, ESI=guild length, RDX=output, ECX=output capacity.
; EAX=formatted byte length, or -1 for invalid input/internal iterator failure.

section .text
state_format_afk_list:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .bad
    test r13d, r13d
    jz .bad
    test r14, r14
    jz .bad
    test r15d, r15d
    jle .bad
    cmp r15d, OUTPUT_CAP
    jbe .capacity_ready
    mov r15d, OUTPUT_CAP
.capacity_ready:
    mov [view_guild_ptr], r12
    mov [view_guild_len], r13d
    mov [view_out_ptr], r14
    mov [view_out_cap], r15d
    mov dword [view_out_len], 0
    mov dword [view_match_count], 0
    mov dword [view_truncated], 0
    lea rdi, [afk_header]
    mov esi, afk_header_len
    call view_append_bytes
    test eax, eax
    js .bad
    lea rdi, [view_collect_afk]
    xor esi, esi
    call store_foreach
    test eax, eax
    js .bad
    cmp dword [view_match_count], 0
    jne .done
    lea rdi, [afk_empty]
    mov esi, afk_empty_len
    call view_append_bytes
    test eax, eax
    js .bad
.done:
    mov eax, [view_out_len]
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

; RDI=guild, ESI=guild length, RDX=output, ECX=output capacity.
; EAX=formatted byte length, or -1 for invalid input/internal iterator failure.
state_format_leaderboard:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .bad
    test r13d, r13d
    jz .bad
    test r14, r14
    jz .bad
    test r15d, r15d
    jle .bad
    cmp r15d, OUTPUT_CAP
    jbe .capacity_ready
    mov r15d, OUTPUT_CAP
.capacity_ready:
    mov [view_guild_ptr], r12
    mov [view_guild_len], r13d
    mov [view_out_ptr], r14
    mov [view_out_cap], r15d
    mov dword [view_out_len], 0
    mov dword [view_xp_count], 0
    mov dword [view_xp_overflow], 0
    mov dword [view_truncated], 0
    lea rdi, [view_collect_xp]
    xor esi, esi
    call store_foreach
    test eax, eax
    js .bad
    call view_sort_xp
    lea rdi, [leaderboard_header]
    mov esi, leaderboard_header_len
    call view_append_bytes
    test eax, eax
    js .bad
    cmp dword [view_xp_count], 0
    jne .render_rows
    lea rdi, [leaderboard_empty]
    mov esi, leaderboard_empty_len
    call view_append_bytes
    test eax, eax
    js .bad
    jmp .done
.render_rows:
    xor ebx, ebx
.row_loop:
    cmp ebx, [view_xp_count]
    jae .done
    cmp ebx, MAX_LEADERBOARD_ROWS
    jae .row_limit
    mov eax, ebx
    inc eax
    call view_uint32_len
    mov [view_rank_len], eax
    mov eax, [xp_scores + rbx * 4]
    call view_uint32_len
    mov [view_score_len], eax
    mov eax, [view_rank_len]
    add eax, [view_score_len]
    add eax, [xp_user_lens + rbx * 4]
    add eax, LEADERBOARD_ROW_FIXED_LEN
    mov edi, eax
    call view_row_fits_with_notice
    test al, al
    jz .row_truncated
    mov eax, ebx
    inc eax
    call view_append_uint32
    test eax, eax
    js .bad
    lea rdi, [leaderboard_after_rank]
    mov esi, leaderboard_after_rank_len
    call view_append_bytes
    test eax, eax
    js .bad
    mov rdi, [xp_user_ptrs + rbx * 8]
    mov esi, [xp_user_lens + rbx * 4]
    call view_append_sanitized
    test eax, eax
    js .bad
    lea rdi, [leaderboard_after_user]
    mov esi, leaderboard_after_user_len
    call view_append_bytes
    test eax, eax
    js .bad
    mov eax, [xp_scores + rbx * 4]
    call view_append_uint32
    test eax, eax
    js .bad
    lea rdi, [leaderboard_after_score]
    mov esi, leaderboard_after_score_len
    call view_append_bytes
    test eax, eax
    js .bad
    inc ebx
    jmp .row_loop
.row_limit:
    call view_append_truncated
    test eax, eax
    js .bad
.done:
    mov eax, [view_out_len]
    jmp .out
.row_truncated:
    call view_append_truncated
    test eax, eax
    js .bad
    jmp .done
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RDI=guild, ESI=guild length, RDX=output, ECX=output capacity.
; EAX=formatted byte length, or -1 for invalid input/internal iterator failure.
state_format_banned_words:
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15d, ecx
    test r12, r12
    jz .bad
    test r13d, r13d
    jz .bad
    test r14, r14
    jz .bad
    test r15d, r15d
    jle .bad
    cmp r15d, OUTPUT_CAP
    jbe .capacity_ready
    mov r15d, OUTPUT_CAP
.capacity_ready:
    mov [view_guild_ptr], r12
    mov [view_guild_len], r13d
    mov [view_out_ptr], r14
    mov [view_out_cap], r15d
    mov dword [view_out_len], 0
    mov dword [view_match_count], 0
    mov dword [view_truncated], 0
    lea rdi, [words_header]
    mov esi, words_header_len
    call view_append_bytes
    test eax, eax
    js .bad
    lea rdi, [view_collect_word]
    xor esi, esi
    call store_foreach
    test eax, eax
    js .bad
    cmp dword [view_match_count], 0
    jne .done
    lea rdi, [words_empty]
    mov esi, words_empty_len
    call view_append_bytes
    test eax, eax
    js .bad
.done:
    mov eax, [view_out_len]
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; store_foreach callback. RDI=context, RSI=key, EDX=key length,
; RCX=value, R8D=value length. It never mutates store state.
view_collect_word:
    push rbx
    push r12
    push r13
    mov r12, rsi
    mov r13d, edx
    mov eax, [view_guild_len]
    add eax, 6                       ; "word:" plus the separating colon.
    cmp r13d, eax
    jbe .ignore
    cmp byte [r12], 'w'
    jne .ignore
    cmp byte [r12 + 1], 'o'
    jne .ignore
    cmp byte [r12 + 2], 'r'
    jne .ignore
    cmp byte [r12 + 3], 'd'
    jne .ignore
    cmp byte [r12 + 4], ':'
    jne .ignore
    mov ebx, [view_guild_len]
    xor ecx, ecx
.guild_loop:
    cmp ecx, ebx
    jae .guild_done
    mov al, [r12 + rcx + 5]
    mov rdx, [view_guild_ptr]
    cmp al, [rdx + rcx]
    jne .ignore
    inc ecx
    jmp .guild_loop
.guild_done:
    mov eax, ebx
    add eax, 5
    cmp byte [r12 + rax], ':'
    jne .ignore
    inc eax
    mov edx, r13d
    sub edx, eax
    jle .ignore
    lea rdi, [r12 + rax]
    mov esi, edx
    add edx, words_row_prefix_len + line_end_len
    mov edi, edx
    call view_row_fits_with_notice
    test al, al
    jz .truncated
    lea rdi, [words_row_prefix]
    mov esi, words_row_prefix_len
    call view_append_bytes
    test eax, eax
    js .abort
    mov eax, ebx
    add eax, 6
    lea rdi, [r12 + rax]
    mov esi, r13d
    sub esi, eax
    call view_append_sanitized
    test eax, eax
    js .abort
    lea rdi, [line_end]
    mov esi, line_end_len
    call view_append_bytes
    test eax, eax
    js .abort
    inc dword [view_match_count]
    xor eax, eax
    jmp .out
.truncated:
    call view_append_truncated
    test eax, eax
    js .abort
    inc dword [view_match_count]
    mov eax, 1
    jmp .out
.ignore:
    xor eax, eax
    jmp .out
.abort:
    mov eax, -1
.out:
    pop r13
    pop r12
    pop rbx
    ret

; store_foreach callback. RDI=context, RSI=key, EDX=key length,
; RCX=value, R8D=value length. It never mutates store state.
view_collect_afk:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    mov eax, [view_guild_len]
    add eax, 5                       ; "afk:" plus the separating colon.
    cmp r13d, eax
    jbe .ignore
    cmp byte [r12], 'a'
    jne .ignore
    cmp byte [r12 + 1], 'f'
    jne .ignore
    cmp byte [r12 + 2], 'k'
    jne .ignore
    cmp byte [r12 + 3], ':'
    jne .ignore
    mov ebx, [view_guild_len]
    xor ecx, ecx
.guild_loop:
    cmp ecx, ebx
    jae .guild_done
    mov al, [r12 + rcx + 4]
    mov rdx, [view_guild_ptr]
    cmp al, [rdx + rcx]
    jne .ignore
    inc ecx
    jmp .guild_loop
.guild_done:
    mov eax, ebx
    add eax, 4
    cmp byte [r12 + rax], ':'
    jne .ignore
    inc eax
    mov edx, r13d
    sub edx, eax
    jle .ignore
    lea r8, [r12 + rax]
    mov [view_user_ptr], r8
    mov [view_user_len], edx
    mov [view_value_ptr], r14
    mov [view_value_len], r15d
    mov eax, r15d
    cmp eax, MAX_REASON_DISPLAY
    jbe .reason_ready
    mov eax, MAX_REASON_DISPLAY
.reason_ready:
    mov [view_reason_display_len], eax
    add eax, edx
    add eax, AFK_ROW_FIXED_LEN
    mov edi, eax
    call view_row_fits_with_notice
    test al, al
    jz .truncated
    lea rdi, [afk_row_prefix]
    mov esi, afk_row_prefix_len
    call view_append_bytes
    test eax, eax
    js .abort
    mov rdi, [view_user_ptr]
    mov esi, [view_user_len]
    call view_append_sanitized
    test eax, eax
    js .abort
    lea rdi, [afk_between_user_reason]
    mov esi, afk_between_user_reason_len
    call view_append_bytes
    test eax, eax
    js .abort
    mov rdi, [view_value_ptr]
    mov esi, [view_reason_display_len]
    call view_append_sanitized
    test eax, eax
    js .abort
    lea rdi, [line_end]
    mov esi, line_end_len
    call view_append_bytes
    test eax, eax
    js .abort
    inc dword [view_match_count]
    xor eax, eax
    jmp .out
.truncated:
    call view_append_truncated
    test eax, eax
    js .abort
    inc dword [view_match_count]
    mov eax, 1
    jmp .out
.ignore:
    xor eax, eax
    jmp .out
.abort:
    mov eax, -1
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; store_foreach callback. RDI=context, RSI=key, EDX=key length,
; RCX=value, R8D=value length. Invalid XP records are ignored safely.
view_collect_xp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    mov eax, [view_guild_len]
    add eax, 4                       ; "xp:" plus the separating colon.
    cmp r13d, eax
    jbe .ignore
    cmp byte [r12], 'x'
    jne .ignore
    cmp byte [r12 + 1], 'p'
    jne .ignore
    cmp byte [r12 + 2], ':'
    jne .ignore
    mov ebx, [view_guild_len]
    xor ecx, ecx
.guild_loop:
    cmp ecx, ebx
    jae .guild_done
    mov al, [r12 + rcx + 3]
    mov rdx, [view_guild_ptr]
    cmp al, [rdx + rcx]
    jne .ignore
    inc ecx
    jmp .guild_loop
.guild_done:
    mov eax, ebx
    add eax, 3
    cmp byte [r12 + rax], ':'
    jne .ignore
    inc eax
    mov edx, r13d
    sub edx, eax
    jle .ignore
    lea r8, [r12 + rax]
    mov [view_user_ptr], r8
    mov [view_user_len], edx
    mov rdi, r14
    mov esi, r15d
    call view_parse_uint32
    jc .ignore
    mov edx, [view_xp_count]
    cmp edx, MAX_ENTRIES
    jae .full
    mov r8, [view_user_ptr]
    mov [xp_user_ptrs + rdx * 8], r8
    mov ecx, [view_user_len]
    mov [xp_user_lens + rdx * 4], ecx
    mov [xp_scores + rdx * 4], eax
    inc edx
    mov [view_xp_count], edx
    xor eax, eax
    jmp .out
.full:
    mov dword [view_xp_overflow], 1
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

; Sort collected entries descending by XP. Equal scores use ascending bytewise
; user ID order, giving deterministic output independent of store slot order.
view_sort_xp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12d, [view_xp_count]
    cmp r12d, 1
    jbe .out
.pass:
    xor r13d, r13d
    xor r14d, r14d
    mov r15d, r12d
    dec r15d
.inner:
    cmp r14d, r15d
    jae .pass_done
    mov edi, r14d
    mov esi, r14d
    inc esi
    call view_xp_left_after_right
    test eax, eax
    jz .next
    mov ebx, r14d
    inc ebx
    mov rax, [xp_user_ptrs + r14 * 8]
    mov rdx, [xp_user_ptrs + rbx * 8]
    mov [xp_user_ptrs + r14 * 8], rdx
    mov [xp_user_ptrs + rbx * 8], rax
    mov eax, [xp_user_lens + r14 * 4]
    mov edx, [xp_user_lens + rbx * 4]
    mov [xp_user_lens + r14 * 4], edx
    mov [xp_user_lens + rbx * 4], eax
    mov eax, [xp_scores + r14 * 4]
    mov edx, [xp_scores + rbx * 4]
    mov [xp_scores + r14 * 4], edx
    mov [xp_scores + rbx * 4], eax
    mov r13d, 1
.next:
    inc r14d
    jmp .inner
.pass_done:
    test r13d, r13d
    jnz .pass
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; EDI=left index, ESI=right index. EAX=1 iff left sorts after right.
view_xp_left_after_right:
    mov eax, [xp_scores + rdi * 4]
    cmp eax, [xp_scores + rsi * 4]
    jb .yes
    ja .no
    mov r8, [xp_user_ptrs + rdi * 8]
    mov r9, [xp_user_ptrs + rsi * 8]
    mov r10d, [xp_user_lens + rdi * 4]
    mov r11d, [xp_user_lens + rsi * 4]
    mov edx, r10d
    cmp edx, r11d
    jbe .common_ready
    mov edx, r11d
.common_ready:
    xor ecx, ecx
.byte_loop:
    cmp ecx, edx
    jae .prefix_equal
    mov al, [r8 + rcx]
    cmp al, [r9 + rcx]
    ja .yes
    jb .no
    inc ecx
    jmp .byte_loop
.prefix_equal:
    cmp r10d, r11d
    ja .yes
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

; RDI=source, ESI=count. EAX=0 on append, -1 when insufficient capacity.
view_append_bytes:
    test esi, esi
    js .bad
    mov eax, [view_out_len]
    cmp eax, [view_out_cap]
    ja .bad
    mov edx, [view_out_cap]
    sub edx, eax
    cmp esi, edx
    ja .bad
    mov r8, [view_out_ptr]
    add r8, rax
    xor ecx, ecx
.copy_loop:
    cmp ecx, esi
    jae .copied
    mov dl, [rdi + rcx]
    mov [r8 + rcx], dl
    inc ecx
    jmp .copy_loop
.copied:
    add [view_out_len], esi
    xor eax, eax
    ret
.bad:
    mov eax, -1
    ret

; DIL=byte. EAX=0 on append, -1 when insufficient capacity.
view_append_byte:
    sub rsp, 8
    mov [rsp], dil
    lea rdi, [rsp]
    mov esi, 1
    call view_append_bytes
    add rsp, 8
    ret

; RDI=source, ESI=count. Control/non-ASCII bytes render as '?'.
; EAX=0 on append, -1 when insufficient capacity.
view_append_sanitized:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13d, esi
    xor ebx, ebx
.loop:
    cmp ebx, r13d
    jae .done
    movzx edi, byte [r12 + rbx]
    cmp dil, 0x20
    jb .replacement
    cmp dil, 0x7e
    jbe .append
.replacement:
    mov edi, '?'
.append:
    call view_append_byte
    test eax, eax
    js .out
    inc ebx
    jmp .loop
.done:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    ret

; EDI=row length. AL=1 iff the row and a truncation notice still fit.
view_row_fits_with_notice:
    mov eax, [view_out_len]
    add eax, truncated_notice_len
    jc .no
    cmp eax, [view_out_cap]
    ja .no
    mov edx, [view_out_cap]
    sub edx, eax
    cmp edi, edx
    ja .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; EAX=0 if appended, -1 on capacity failure. Caller stops rendering after this.
view_append_truncated:
    cmp dword [view_truncated], 0
    jne .done
    lea rdi, [truncated_notice]
    mov esi, truncated_notice_len
    call view_append_bytes
    test eax, eax
    js .out
    mov dword [view_truncated], 1
.done:
    xor eax, eax
.out:
    ret

; RDI=decimal bytes, ESI=len. EAX=value, CF=0 valid; CF=1 invalid/overflow.
view_parse_uint32:
    test esi, esi
    jz .bad
    xor eax, eax
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .good
    movzx edx, byte [rdi + rcx]
    sub dl, '0'
    cmp dl, 9
    ja .bad
    cmp eax, 429496729
    ja .bad
    jb .multiply
    cmp dl, 5
    ja .bad
.multiply:
    imul eax, eax, 10
    movzx edx, dl
    add eax, edx
    inc ecx
    jmp .loop
.good:
    clc
    ret
.bad:
    xor eax, eax
    stc
    ret

; EAX=value. EAX=decimal byte length.
view_uint32_len:
    test eax, eax
    jnz .nonzero
    mov eax, 1
    ret
.nonzero:
    xor ecx, ecx
    mov r8d, 10
.loop:
    xor edx, edx
    div r8d
    inc ecx
    test eax, eax
    jnz .loop
    mov eax, ecx
    ret

; EAX=value. EAX=0 on append, -1 on capacity failure.
view_append_uint32:
    sub rsp, 8
    lea r8, [view_number_scratch + 10]
    xor ecx, ecx
    test eax, eax
    jnz .digits
    mov byte [r8 - 1], '0'
    lea rdi, [r8 - 1]
    mov esi, 1
    call view_append_bytes
    add rsp, 8
    ret
.digits:
    mov r9d, 10
.loop:
    xor edx, edx
    div r9d
    add dl, '0'
    dec r8
    mov [r8], dl
    inc ecx
    test eax, eax
    jnz .loop
    mov rdi, r8
    mov esi, ecx
    call view_append_bytes
    add rsp, 8
    ret

section .rodata
afk_header: db 'AFK users:', 10
afk_header_len equ $ - afk_header
words_header: db 'Banned words:', 10
words_header_len equ $ - words_header
words_empty: db '(none)', 10
words_empty_len equ $ - words_empty
words_row_prefix: db '- '
words_row_prefix_len equ $ - words_row_prefix
afk_empty: db 'No AFK members in this server.', 10
afk_empty_len equ $ - afk_empty
afk_row_prefix: db '- '
afk_row_prefix_len equ $ - afk_row_prefix
afk_between_user_reason: db ': '
afk_between_user_reason_len equ $ - afk_between_user_reason
line_end: db 10
line_end_len equ $ - line_end
leaderboard_header: db 'XP leaderboard:', 10
leaderboard_header_len equ $ - leaderboard_header
leaderboard_empty: db 'No XP scores in this server.', 10
leaderboard_empty_len equ $ - leaderboard_empty
leaderboard_after_rank: db '. '
leaderboard_after_rank_len equ $ - leaderboard_after_rank
leaderboard_after_user: db ' - '
leaderboard_after_user_len equ $ - leaderboard_after_user
leaderboard_after_score: db ' XP', 10
leaderboard_after_score_len equ $ - leaderboard_after_score
truncated_notice: db '[truncated]', 10
truncated_notice_len equ $ - truncated_notice

section .bss
view_guild_ptr: resq 1
view_guild_len: resd 1
view_out_ptr: resq 1
view_out_cap: resd 1
view_out_len: resd 1
view_match_count: resd 1
view_truncated: resd 1
view_user_ptr: resq 1
view_user_len: resd 1
view_value_ptr: resq 1
view_value_len: resd 1
view_reason_display_len: resd 1
view_rank_len: resd 1
view_score_len: resd 1
view_xp_count: resd 1
view_xp_overflow: resd 1
align 8
xp_user_ptrs: resq MAX_ENTRIES
xp_user_lens: resd MAX_ENTRIES
xp_scores: resd MAX_ENTRIES
view_number_scratch: resb 10

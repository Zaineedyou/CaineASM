BITS 64
DEFAULT REL

global gateway_run
global gateway_process_frame
global gateway_reset_state
global gateway_bot_user_id
global gateway_bot_user_id_len
global gateway_last_heartbeat_latency_ms
global gateway_guild_name_get

global gateway_send_identify
global gateway_send_resume
global gateway_send_heartbeat

extern secure_gateway_connect
extern secure_gateway_send_text
extern secure_gateway_recv_text
extern secure_gateway_close
extern discord_token_ptr
extern discord_token_len
extern json_find_key
extern json_object_find_direct_key
extern json_read_uint
extern json_read_string
extern json_escape_append
extern json_value_is_true
extern json_object_end
extern dispatch_message_create
extern guild_auth_reset
extern guild_auth_cache_guild_create
extern channel_auth_reset
extern channel_auth_cache_guild_create
extern lifecycle_member_add
extern lifecycle_member_remove
extern interaction_handle_gateway
extern discord_register_application_commands

%define SYS_NANOSLEEP 35
%define SYS_CLOCK_GETTIME 228
%define SYS_GETRANDOM 318
%define CLOCK_MONOTONIC 1

%define GATEWAY_BUFFER_CAP 16384
%define OUTBOUND_BUFFER_CAP 4096
%define SESSION_ID_CAP 256
%define RESUME_URL_CAP 512
%define EVENT_NAME_CAP 64
%define BOT_USER_ID_CAP 64
%define GUILD_ID_CAP 64
%define GUILD_NAME_CAP 128
%define GUILD_CACHE_SLOTS 64

%define ACTION_NONE 0
%define ACTION_RECONNECT 1
%define ACTION_FATAL -1

section .text

; Opens and maintains the Discord Gateway connection. The transport boundary
; supplies only authenticated WSS frames; protocol/state policy remains NASM.
gateway_run:
    sub rsp, 8
    call gateway_reset_state
    call gateway_connect_current
    test eax, eax
    jnz .failure
.loop:
    lea rdi, [gateway_buffer]
    mov esi, GATEWAY_BUFFER_CAP
    lea rdx, [gateway_length]
    call secure_gateway_recv_text
    test rax, rax
    js .receive_wait
    test rax, rax
    jz .receive_wait
    lea rdi, [gateway_buffer]
    mov rsi, [gateway_length]
    call gateway_process_frame
    cmp eax, ACTION_RECONNECT
    je .reconnect
    cmp eax, ACTION_FATAL
    je .failure
    jmp .loop
.receive_wait:
    call gateway_heartbeat_due
    test al, al
    jz .sleep
    cmp byte [heartbeat_ack_pending], 0
    jne .reconnect
    call gateway_send_heartbeat
    test eax, eax
    jnz .reconnect
    call gateway_schedule_next_heartbeat
.sleep:
    lea rdi, [receive_pause]
    xor esi, esi
    mov eax, SYS_NANOSLEEP
    syscall
    jmp .loop
.reconnect:
    call gateway_reconnect
    test eax, eax
    jnz .failure
    jmp .loop
.failure:
    mov eax, 69
    add rsp, 8
    ret

; RDI=frame JSON, RSI=frame length. EAX is an ACTION_* result.
gateway_process_frame:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi

    lea rdx, [key_op]
    mov ecx, key_op_len
    call json_find_key
    test rax, rax
    jz .none
    mov rdi, rax
    lea rsi, [r12 + r13]
    call json_read_uint
    jc .none
    mov ebx, eax

    ; Dispatch events update the latest sequence before type-specific routing.
    cmp ebx, 0
    jne .opcode
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_sequence]
    mov ecx, key_sequence_len
    call json_find_key
    test rax, rax
    jz .dispatch_type
    mov rdi, rax
    lea rsi, [r12 + r13]
    call json_read_uint
    jc .dispatch_type
    mov [sequence], rax
    mov byte [has_sequence], 1
.dispatch_type:
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_type]
    mov ecx, key_type_len
    call json_find_key
    test rax, rax
    jz .none
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [event_name]
    mov ecx, EVENT_NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .none
    mov r14d, eax

    lea rdi, [event_name]
    mov esi, r14d
    lea rdx, [event_ready]
    mov ecx, event_ready_len
    call literal_equal
    test al, al
    jnz .ready
    lea rdi, [event_name]
    mov esi, r14d
    lea rdx, [event_resumed]
    mov ecx, event_resumed_len
    call literal_equal
    test al, al
    jnz .resumed
    lea rdi, [event_name]
    mov esi, r14d
    lea rdx, [event_guild_create]
    mov ecx, event_guild_create_len
    call literal_equal
    test al, al
    jnz .guild_create
    lea rdi, [event_name]
    mov esi, r14d
    lea rdx, [event_member_add]
    mov ecx, event_member_add_len
    call literal_equal
    test al, al
    jnz .member_add
    lea rdi, [event_name]
    mov esi, r14d
    lea rdx, [event_member_remove]
    mov ecx, event_member_remove_len
    call literal_equal
    test al, al
    jnz .member_remove
    lea rdi, [event_name]
    mov esi, r14d
    lea rdx, [event_message_create]
    mov ecx, event_message_create_len
    call literal_equal
    test al, al
    jnz .message_create
    lea rdi, [event_name]
    mov esi, r14d
    lea rdx, [event_interaction_create]
    mov ecx, event_interaction_create_len
    call literal_equal
    test al, al
    jnz .interaction_create
    jmp .none

.ready:
    call gateway_cache_ready
    test eax, eax
    jnz .fatal
    mov byte [resume_allowed], 1
    mov byte [identified], 1
    cmp byte [application_commands_attempted], 0
    jne .none
    mov byte [application_commands_attempted], 1
    lea rdi, [gateway_bot_user_id]
    mov esi, [gateway_bot_user_id_len]
    call discord_register_application_commands
    ; Registration failure is independent from gateway liveness. This one-shot
    ; attempt prevents duplicate global commands on subsequent reconnects.
    jmp .none
.resumed:
    mov byte [identified], 1
    jmp .none
.guild_create:
    mov rdi, r12
    mov rsi, r13
    call guild_auth_cache_guild_create
    mov rdi, r12
    mov rsi, r13
    call channel_auth_cache_guild_create
    mov rdi, r12
    mov rsi, r13
    call gateway_cache_guild_name
    ; Authorization and dashboard cache failures never invalidate an otherwise
    ; healthy Gateway session; incomplete cache data displays a safe fallback.
    jmp .none
.member_add:
    mov rdi, r12
    mov rsi, r13
    call lifecycle_member_add
    jmp .none
.member_remove:
    mov rdi, r12
    mov rsi, r13
    call lifecycle_member_remove
    jmp .none
.message_create:
    mov rdi, r12
    mov rsi, r13
    call dispatch_message_create
    ; REST errors do not invalidate the Gateway session; later rate-limit policy
    ; will make a retry decision rather than tearing down event reception here.
    jmp .none
.interaction_create:
    mov rdi, r12
    mov rsi, r13
    call interaction_handle_gateway
    ; A bounded callback failure must not tear down the live Gateway transport.
    jmp .none

.opcode:
    cmp ebx, 10
    je .hello
    cmp ebx, 11
    je .ack
    cmp ebx, 1
    je .heartbeat_now
    cmp ebx, 7
    je .reconnect
    cmp ebx, 9
    je .invalid_session
    jmp .none
.hello:
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_heartbeat_interval]
    mov ecx, key_heartbeat_interval_len
    call json_find_key
    test rax, rax
    jz .fatal
    mov rdi, rax
    lea rsi, [r12 + r13]
    call json_read_uint
    jc .fatal
    test rax, rax
    jz .fatal
    cmp rax, 86400000
    ja .fatal
    mov [heartbeat_ms], eax
    mov byte [hello_received], 1
    mov byte [heartbeat_ack_pending], 0
    call gateway_schedule_initial_heartbeat
    cmp byte [resume_allowed], 0
    jne .resume
    call gateway_send_identify
    test eax, eax
    jnz .fatal
    mov byte [identified], 1
    jmp .none
.resume:
    call gateway_send_resume
    test eax, eax
    jnz .fatal
    jmp .none
.ack:
    cmp byte [heartbeat_ack_pending], 0
    je .ack_clear
    call gateway_now_ms
    test rax, rax
    jz .ack_clear
    mov rdx, [heartbeat_sent_ms]
    test rdx, rdx
    jz .ack_clear
    cmp rax, rdx
    jb .ack_clear
    sub rax, rdx
    mov [gateway_last_heartbeat_latency_ms], rax
.ack_clear:
    mov byte [heartbeat_ack_pending], 0
    jmp .none
.heartbeat_now:
    call gateway_send_heartbeat
    test eax, eax
    jnz .reconnect
    call gateway_schedule_next_heartbeat
    jmp .none
.invalid_session:
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_data]
    mov ecx, key_data_len
    call json_find_key
    test rax, rax
    jz .invalidate_resume
    mov rdi, rax
    lea rsi, [r12 + r13]
    call json_value_is_true
    test al, al
    jnz .reconnect
.invalidate_resume:
    mov byte [resume_allowed], 0
    mov byte [identified], 0
    mov byte [has_sequence], 0
    mov dword [session_id_len], 0
    mov dword [resume_url_len], 0
    jmp .reconnect
.reconnect:
    mov eax, ACTION_RECONNECT
    jmp .out
.fatal:
    mov eax, ACTION_FATAL
    jmp .out
.none:
    xor eax, eax
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Cache Resume information from a READY Dispatch currently in R12/R13.
; EAX=0 success, -1 when mandatory bounded data cannot be read.
gateway_cache_ready:
    sub rsp, 8
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_session_id]
    mov ecx, key_session_id_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [session_id]
    mov ecx, SESSION_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [session_id_len], eax
    mov byte [session_id + rax], 0

    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_resume_gateway_url]
    mov ecx, key_resume_gateway_url_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [resume_url]
    mov ecx, RESUME_URL_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [resume_url_len], eax
    mov byte [resume_url + rax], 0

    ; READY carries the authenticated bot in d.user; cache only its bounded ID.
    mov rdi, r12
    mov rsi, r13
    lea rdx, [key_user]
    mov ecx, key_user_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .bad
    mov rdi, rbx
    mov rsi, rax
    sub rsi, rbx
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_find_key
    test rax, rax
    jz .bad
    mov rdi, rax
    lea rsi, [r12 + r13]
    lea rdx, [gateway_bot_user_id]
    mov ecx, BOT_USER_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [gateway_bot_user_id_len], eax
    mov byte [gateway_bot_user_id + rax], 0
    xor eax, eax
    add rsp, 8
    ret
.bad:
    mov eax, -1
    add rsp, 8
    ret

; RDI=complete GUILD_CREATE dispatch frame, RSI=frame len. EAX=0 only when a
; direct payload id/name pair passes bounded text validation and is cached. This
; cache is presentation-only; cache failure never affects Gateway liveness.
gateway_cache_guild_name:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .bad
    test r13, r13
    jle .bad
    mov rdi, r12
    lea rsi, [r12 + r13]
    lea rdx, [key_data]
    mov ecx, key_data_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, rbx
    lea rsi, [r12 + r13]
    call json_object_end
    test rax, rax
    jz .bad
    mov r14, rax
    mov rdi, rbx
    mov rsi, r14
    lea rdx, [key_id]
    mov ecx, key_id_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, r14
    lea rdx, [guild_cache_id_scratch]
    mov ecx, GUILD_ID_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [guild_cache_id_scratch_len], eax
    lea rdi, [guild_cache_id_scratch]
    mov esi, eax
    call gateway_decimal_id_valid
    test al, al
    jz .bad
    mov rdi, rbx
    mov rsi, r14
    lea rdx, [key_name]
    mov ecx, key_name_len
    call json_object_find_direct_key
    test rax, rax
    jz .bad
    mov rdi, rax
    mov rsi, r14
    lea rdx, [guild_cache_name_scratch]
    mov ecx, GUILD_NAME_CAP - 1
    call json_read_string
    test eax, eax
    jle .bad
    mov [guild_cache_name_scratch_len], eax
    lea rdi, [guild_cache_name_scratch]
    mov esi, eax
    call gateway_guild_name_valid
    test al, al
    jz .bad

    xor ebx, ebx
    mov r15d, -1
.find_slot:
    cmp ebx, GUILD_CACHE_SLOTS
    jae .select_slot
    cmp dword [guild_cache_id_lens + rbx * 4], 0
    jne .match_slot
    cmp r15d, -1
    jne .next_slot
    mov r15d, ebx
    jmp .next_slot
.match_slot:
    mov eax, [guild_cache_id_lens + rbx * 4]
    cmp eax, [guild_cache_id_scratch_len]
    jne .next_slot
    mov rax, rbx
    imul rax, GUILD_ID_CAP
    lea rdi, [guild_cache_ids + rax]
    lea rsi, [guild_cache_id_scratch]
    mov edx, [guild_cache_id_scratch_len]
    call gateway_equal_bytes
    test al, al
    jz .next_slot
    mov r15d, ebx
    jmp .store
.next_slot:
    inc ebx
    jmp .find_slot
.select_slot:
    cmp r15d, -1
    jne .store
    mov r15d, [guild_cache_evict]
    inc dword [guild_cache_evict]
    cmp dword [guild_cache_evict], GUILD_CACHE_SLOTS
    jb .store
    mov dword [guild_cache_evict], 0
.store:
    mov rax, r15
    imul rax, GUILD_ID_CAP
    lea rdi, [guild_cache_ids + rax]
    lea rsi, [guild_cache_id_scratch]
    mov edx, [guild_cache_id_scratch_len]
    call copy_bytes
    mov eax, r15d
    imul rax, GUILD_NAME_CAP
    lea rdi, [guild_cache_names + rax]
    lea rsi, [guild_cache_name_scratch]
    mov edx, [guild_cache_name_scratch_len]
    call copy_bytes
    mov eax, [guild_cache_id_scratch_len]
    mov [guild_cache_id_lens + r15 * 4], eax
    mov eax, [guild_cache_name_scratch_len]
    mov [guild_cache_name_lens + r15 * 4], eax
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

; RDI=guild decimal ID, ESI=len. RAX=name pointer and EDX=name length only for
; an exact cache hit; otherwise both are zero. The returned pointer remains valid
; until the single-threaded Gateway processes another GUILD_CREATE cache update.
gateway_guild_name_get:
    push rbx
    push r12
    push r13
    test rdi, rdi
    jz .miss
    test esi, esi
    jle .miss
    mov r12, rdi
    mov ebx, esi
    xor r13d, r13d
.loop:
    cmp r13d, GUILD_CACHE_SLOTS
    jae .miss
    cmp dword [guild_cache_id_lens + r13 * 4], ebx
    jne .next
    mov rax, r13
    imul rax, GUILD_ID_CAP
    lea rdi, [guild_cache_ids + rax]
    mov rsi, r12
    mov edx, ebx
    call gateway_equal_bytes
    test al, al
    jz .next
    mov rax, r13
    imul rax, GUILD_NAME_CAP
    lea rax, [guild_cache_names + rax]
    mov edx, [guild_cache_name_lens + r13 * 4]
    jmp .out
.next:
    inc r13d
    jmp .loop
.miss:
    xor eax, eax
    xor edx, edx
.out:
    pop r13
    pop r12
    pop rbx
    ret

; RDI=ASCII ID, ESI=len. AL=1 only for nonzero decimal bytes up to capacity.
gateway_decimal_id_valid:
    test rdi, rdi
    jz .no
    test esi, esi
    jle .no
    cmp esi, GUILD_ID_CAP - 1
    ja .no
    xor ecx, ecx
    xor edx, edx
.loop:
    cmp ecx, esi
    jae .done
    mov al, [rdi + rcx]
    cmp al, '0'
    jb .no
    cmp al, '9'
    ja .no
    cmp al, '0'
    jne .nonzero
    inc ecx
    jmp .loop
.nonzero:
    mov edx, 1
    inc ecx
    jmp .loop
.done:
    test edx, edx
    jz .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI=name, ESI=len. AL=1 only for 1..127 printable/UTF-8 byte sequences with
; no C0 controls; Discord guild names are never permitted to inject controls.
gateway_guild_name_valid:
    test rdi, rdi
    jz .no
    test esi, esi
    jle .no
    cmp esi, GUILD_NAME_CAP - 1
    ja .no
    xor ecx, ecx
.loop:
    cmp ecx, esi
    jae .yes
    mov al, [rdi + rcx]
    cmp al, 0x20
    jb .no
    inc ecx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; RDI=left, RSI=right, EDX=count. AL=1 only for exact bytes.
gateway_equal_bytes:
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

; Build and send Gateway Identify. EAX=0 success, -1 failure.
gateway_send_identify:
    push rbx
    push r12
    push r13
    mov r12, [discord_token_ptr]
    mov r13d, [discord_token_len]
    test r12, r12
    jz .bad
    test r13d, r13d
    jz .bad
    lea rdi, [outbound_buffer]
    lea rsi, [identify_prefix]
    mov edx, identify_prefix_len
    call copy_bytes
    lea rdi, [outbound_buffer + identify_prefix_len]
    mov esi, OUTBOUND_BUFFER_CAP - identify_prefix_len - identify_suffix_len
    mov rdx, r12
    mov ecx, r13d
    call json_escape_append
    test eax, eax
    js .bad
    mov ebx, eax
    lea rdi, [outbound_buffer + identify_prefix_len]
    add rdi, rbx
    lea rsi, [identify_suffix]
    mov edx, identify_suffix_len
    call copy_bytes
    mov esi, ebx
    add esi, identify_prefix_len + identify_suffix_len
    lea rdi, [outbound_buffer]
    call secure_gateway_send_text
    test rax, rax
    js .bad
    xor eax, eax
    jmp .out
.bad:
    mov eax, -1
.out:
    pop r13
    pop r12
    pop rbx
    ret

; Build and send Gateway Resume. EAX=0 success, -1 failure.
gateway_send_resume:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, [discord_token_ptr]
    mov r13d, [discord_token_len]
    mov r14d, [session_id_len]
    test r12, r12
    jz .bad
    test r13d, r13d
    jz .bad
    test r14d, r14d
    jz .bad
    cmp byte [has_sequence], 0
    je .bad

    lea rdi, [outbound_buffer]
    lea rsi, [resume_prefix]
    mov edx, resume_prefix_len
    call copy_bytes
    lea rdi, [outbound_buffer + resume_prefix_len]
    mov esi, OUTBOUND_BUFFER_CAP - resume_prefix_len - resume_middle_len - resume_suffix_reserve
    mov rdx, r12
    mov ecx, r13d
    call json_escape_append
    test eax, eax
    js .bad
    mov ebx, eax

    lea rdi, [outbound_buffer + resume_prefix_len]
    add rdi, rbx
    lea rsi, [resume_middle]
    mov edx, resume_middle_len
    call copy_bytes
    add ebx, resume_middle_len

    lea rdi, [outbound_buffer + resume_prefix_len]
    add rdi, rbx
    mov esi, OUTBOUND_BUFFER_CAP - resume_prefix_len - resume_suffix_reserve
    sub esi, ebx
    lea rdx, [session_id]
    mov ecx, r14d
    call json_escape_append
    test eax, eax
    js .bad
    add ebx, eax

    lea rdi, [outbound_buffer + resume_prefix_len]
    add rdi, rbx
    lea rsi, [resume_seq_prefix]
    mov edx, resume_seq_prefix_len
    call copy_bytes
    add ebx, resume_seq_prefix_len
    lea rdi, [outbound_buffer + resume_prefix_len]
    add rdi, rbx
    mov rax, [sequence]
    call append_uint
    test eax, eax
    js .bad
    add ebx, eax
    lea rdi, [outbound_buffer + resume_prefix_len]
    add rdi, rbx
    lea rsi, [resume_suffix]
    mov edx, resume_suffix_len
    call copy_bytes
    add ebx, resume_suffix_len

    lea rdi, [outbound_buffer]
    mov esi, ebx
    add esi, resume_prefix_len
    call secure_gateway_send_text
    test rax, rax
    js .bad
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

; Send a heartbeat with the latest Dispatch sequence or null. EAX=0 success, -1 failure.
gateway_send_heartbeat:
    push rbx
    lea rdi, [outbound_buffer]
    lea rsi, [heartbeat_prefix]
    mov edx, heartbeat_prefix_len
    call copy_bytes
    mov ebx, heartbeat_prefix_len
    cmp byte [has_sequence], 0
    je .null
    lea rdi, [outbound_buffer + heartbeat_prefix_len]
    mov rax, [sequence]
    call append_uint
    test eax, eax
    js .bad
    add ebx, eax
    jmp .suffix
.null:
    lea rdi, [outbound_buffer + heartbeat_prefix_len]
    lea rsi, [null_literal]
    mov edx, null_literal_len
    call copy_bytes
    add ebx, null_literal_len
.suffix:
    lea rdi, [outbound_buffer + rbx]
    lea rsi, [heartbeat_suffix]
    mov edx, heartbeat_suffix_len
    call copy_bytes
    add ebx, heartbeat_suffix_len
    lea rdi, [outbound_buffer]
    mov esi, ebx
    call secure_gateway_send_text
    test rax, rax
    js .bad
    call gateway_now_ms
    mov [heartbeat_sent_ms], rax
    mov byte [heartbeat_ack_pending], 1
    xor eax, eax
    pop rbx
    ret
.bad:
    mov eax, -1
    pop rbx
    ret

; RDI=destination, RAX=unsigned integer. EAX=written byte count, -1 if >20 bytes.
append_uint:
    lea r8, [uint_scratch + 20]
    mov byte [r8], 0
    xor ecx, ecx
    test rax, rax
    jnz .digits
    mov byte [rdi], '0'
    mov eax, 1
    ret
.digits:
    mov r9d, 10
.loop:
    xor edx, edx
    div r9
    add dl, '0'
    dec r8
    mov [r8], dl
    inc ecx
    test rax, rax
    jnz .loop
    cmp ecx, 20
    ja .bad
    xor edx, edx
.copy:
    cmp edx, ecx
    jae .done
    mov al, [r8 + rdx]
    mov [rdi + rdx], al
    inc edx
    jmp .copy
.done:
    mov eax, ecx
    ret
.bad:
    mov eax, -1
    ret

; RDI=left, ESI=left length, RDX=literal, ECX=literal length. AL=1 when equal.
literal_equal:
    cmp esi, ecx
    jne .no
    xor eax, eax
.loop:
    cmp eax, ecx
    jae .yes
    mov r8b, [rdi + rax]
    cmp r8b, [rdx + rax]
    jne .no
    inc eax
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; Connect using a resume URL only when it is complete; otherwise use the stable initial URL.
gateway_connect_current:
    sub rsp, 8
    cmp byte [resume_allowed], 0
    je .initial
    cmp dword [resume_url_len], 0
    je .initial
    lea rdi, [resume_url]
    jmp .connect
.initial:
    lea rdi, [gateway_url]
.connect:
    call secure_gateway_connect
    add rsp, 8
    ret

gateway_reconnect:
    sub rsp, 8
    call secure_gateway_close
    lea rdi, [reconnect_pause]
    xor esi, esi
    mov eax, SYS_NANOSLEEP
    syscall
    mov byte [identified], 0
    mov byte [hello_received], 0
    mov byte [heartbeat_ack_pending], 0
    call gateway_connect_current
    add rsp, 8
    ret

; AL=1 once the timer has elapsed and an acknowledged heartbeat is due.
gateway_heartbeat_due:
    cmp byte [hello_received], 0
    je .no
    sub rsp, 8
    call gateway_now_ms
    add rsp, 8
    cmp rax, [next_heartbeat_ms]
    jb .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

gateway_schedule_initial_heartbeat:
    sub rsp, 8
    call gateway_now_ms
    add rsp, 8
    mov r8, rax
    mov ecx, [heartbeat_ms]
    test ecx, ecx
    jz .store
    lea rdi, [jitter_seed]
    mov esi, 8
    xor edx, edx
    mov eax, SYS_GETRANDOM
    syscall
    test rax, rax
    js .fallback
    mov rax, [jitter_seed]
    xor edx, edx
    div rcx
    jmp .store
.fallback:
    mov edx, ecx
    shr edx, 1
.store:
    add r8, rdx
    mov [next_heartbeat_ms], r8
    ret

gateway_schedule_next_heartbeat:
    sub rsp, 8
    call gateway_now_ms
    add rsp, 8
    mov edx, [heartbeat_ms]
    add rax, rdx
    mov [next_heartbeat_ms], rax
    ret

; RAX=monotonic clock milliseconds.
gateway_now_ms:
    lea rdi, [clock_spec]
    mov esi, CLOCK_MONOTONIC
    mov eax, SYS_CLOCK_GETTIME
    syscall
    test rax, rax
    js .zero
    mov r8, [clock_spec]
    imul r8, r8, 1000
    mov rax, [clock_spec + 8]
    xor edx, edx
    mov ecx, 1000000
    div rcx
    add rax, r8
    ret
.zero:
    xor eax, eax
    ret

; Clears all Gateway session and heartbeat state for a process start.
gateway_reset_state:
    sub rsp, 8
    call guild_auth_reset
    call channel_auth_reset
    add rsp, 8
    mov byte [identified], 0
    mov byte [application_commands_attempted], 0
    mov byte [hello_received], 0
    mov byte [heartbeat_ack_pending], 0
    mov byte [resume_allowed], 0
    mov byte [has_sequence], 0
    mov dword [heartbeat_ms], 0
    mov qword [next_heartbeat_ms], 0
    mov qword [heartbeat_sent_ms], 0
    mov qword [gateway_last_heartbeat_latency_ms], 0
    mov qword [sequence], 0
    mov dword [session_id_len], 0
    mov dword [resume_url_len], 0
    mov dword [gateway_bot_user_id_len], 0
    mov byte [gateway_bot_user_id], 0
    mov dword [guild_cache_evict], 0
    xor ecx, ecx
.clear_guild_cache:
    cmp ecx, GUILD_CACHE_SLOTS
    jae .cache_cleared
    mov dword [guild_cache_id_lens + rcx * 4], 0
    mov dword [guild_cache_name_lens + rcx * 4], 0
    inc ecx
    jmp .clear_guild_cache
.cache_cleared:
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
gateway_url: db 'wss://gateway.discord.gg/?v=10&encoding=json',0
key_op: db 'op'
key_op_len equ $ - key_op
key_sequence: db 's'
key_sequence_len equ $ - key_sequence
key_type: db 't'
key_type_len equ $ - key_type
key_data: db 'd'
key_data_len equ $ - key_data
key_heartbeat_interval: db 'heartbeat_interval'
key_heartbeat_interval_len equ $ - key_heartbeat_interval
key_session_id: db 'session_id'
key_session_id_len equ $ - key_session_id
key_resume_gateway_url: db 'resume_gateway_url'
key_resume_gateway_url_len equ $ - key_resume_gateway_url
key_user: db 'user'
key_user_len equ $ - key_user
key_id: db 'id'
key_id_len equ $ - key_id
key_name: db 'name'
key_name_len equ $ - key_name
event_ready: db 'READY'
event_ready_len equ $ - event_ready
event_resumed: db 'RESUMED'
event_resumed_len equ $ - event_resumed
event_guild_create: db 'GUILD_CREATE'
event_guild_create_len equ $ - event_guild_create
event_member_add: db 'GUILD_MEMBER_ADD'
event_member_add_len equ $ - event_member_add
event_member_remove: db 'GUILD_MEMBER_REMOVE'
event_member_remove_len equ $ - event_member_remove
event_message_create: db 'MESSAGE_CREATE'
event_message_create_len equ $ - event_message_create
event_interaction_create: db 'INTERACTION_CREATE'
event_interaction_create_len equ $ - event_interaction_create
identify_prefix: db '{"op":2,"d":{"token":"'
identify_prefix_len equ $ - identify_prefix
identify_suffix: db '","intents":37379,"properties":{"os":"linux","browser":"caine-asm","device":"caine-asm"}}}'
identify_suffix_len equ $ - identify_suffix
resume_prefix: db '{"op":6,"d":{"token":"'
resume_prefix_len equ $ - resume_prefix
resume_middle: db '","session_id":"'
resume_middle_len equ $ - resume_middle
resume_seq_prefix: db '","seq":'
resume_seq_prefix_len equ $ - resume_seq_prefix
resume_suffix: db '}}'
resume_suffix_len equ $ - resume_suffix
resume_suffix_reserve equ resume_seq_prefix_len + 20 + resume_suffix_len
heartbeat_prefix: db '{"op":1,"d":'
heartbeat_prefix_len equ $ - heartbeat_prefix
heartbeat_suffix: db '}'
heartbeat_suffix_len equ $ - heartbeat_suffix
null_literal: db 'null'
null_literal_len equ $ - null_literal
receive_pause: dq 0, 20000000
reconnect_pause: dq 2, 0

section .data
heartbeat_ms: dd 0
identified: db 0
application_commands_attempted: db 0
hello_received: db 0
heartbeat_ack_pending: db 0
resume_allowed: db 0
has_sequence: db 0
sequence: dq 0
next_heartbeat_ms: dq 0
heartbeat_sent_ms: dq 0
gateway_last_heartbeat_latency_ms: dq 0
gateway_length: dq 0
session_id_len: dd 0
resume_url_len: dd 0
gateway_bot_user_id_len: dd 0
clock_spec: dq 0, 0
jitter_seed: dq 0
guild_cache_evict: dd 0

section .bss
gateway_buffer: resb GATEWAY_BUFFER_CAP
outbound_buffer: resb OUTBOUND_BUFFER_CAP
session_id: resb SESSION_ID_CAP
resume_url: resb RESUME_URL_CAP
gateway_bot_user_id: resb BOT_USER_ID_CAP
event_name: resb EVENT_NAME_CAP
uint_scratch: resb 21
guild_cache_id_scratch: resb GUILD_ID_CAP
guild_cache_id_scratch_len: resd 1
guild_cache_name_scratch: resb GUILD_NAME_CAP
guild_cache_name_scratch_len: resd 1
guild_cache_ids: resb GUILD_CACHE_SLOTS * GUILD_ID_CAP
guild_cache_id_lens: resd GUILD_CACHE_SLOTS
guild_cache_names: resb GUILD_CACHE_SLOTS * GUILD_NAME_CAP
guild_cache_name_lens: resd GUILD_CACHE_SLOTS

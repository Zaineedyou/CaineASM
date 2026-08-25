BITS 64
DEFAULT REL

extern json_find_key
extern json_read_uint
extern json_read_string
extern json_value_is_true
extern json_object_end

global _start

%define SYS_EXIT 60

section .text
_start:
    mov dword [failure_stage], 1
    ; Lookup ignores key-looking bytes inside a string and finds the real top-level op.
    lea rdi, [gateway_frame]
    mov esi, gateway_frame_len
    lea rdx, [key_op]
    mov ecx, key_op_len
    call json_find_key
    test rax, rax
    jz .fail
    mov rdi, rax
    lea rsi, [gateway_frame + gateway_frame_len]
    call json_read_uint
    jc .fail
    test rax, rax
    jnz .fail

    mov dword [failure_stage], 2
    ; Quoted content decodes common JSON escapes and a BMP Unicode sequence.
    lea rdi, [gateway_frame]
    mov esi, gateway_frame_len
    lea rdx, [key_content]
    mov ecx, key_content_len
    call json_find_key
    test rax, rax
    jz .fail
    mov dword [failure_stage], 21
    mov rdi, rax
    lea rsi, [gateway_frame + gateway_frame_len]
    lea rdx, [decoded]
    mov ecx, 64
    call json_read_string
    cmp eax, decoded_content_len
    jne .fail
    mov dword [failure_stage], 22
    lea rdi, [decoded]
    lea rsi, [decoded_content]
    mov edx, decoded_content_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [failure_stage], 3
    ; The nested bot flag remains available to a dispatcher filter.
    lea rdi, [gateway_frame]
    mov esi, gateway_frame_len
    lea rdx, [key_bot]
    mov ecx, key_bot_len
    call json_find_key
    test rax, rax
    jz .fail
    mov rdi, rax
    lea rsi, [gateway_frame + gateway_frame_len]
    call json_value_is_true
    test al, al
    jnz .fail

    mov dword [failure_stage], 4
    ; Snowflake-like identifiers stay byte strings and are decoded without loss.
    lea rdi, [gateway_frame]
    mov esi, gateway_frame_len
    lea rdx, [key_channel]
    mov ecx, key_channel_len
    call json_find_key
    test rax, rax
    jz .fail
    mov rdi, rax
    lea rsi, [gateway_frame + gateway_frame_len]
    lea rdx, [decoded]
    mov ecx, 64
    call json_read_string
    cmp eax, channel_id_len
    jne .fail
    lea rdi, [decoded]
    lea rsi, [channel_id]
    mov edx, channel_id_len
    call equal_bytes
    test al, al
    jz .fail

    mov dword [failure_stage], 5
    ; Decimal parser accepts uint64 max and rejects overflow deterministically.
    lea rdi, [uint64_max]
    lea rsi, [uint64_max + uint64_max_len]
    call json_read_uint
    jc .fail
    cmp rax, -1
    jne .fail
    lea rdi, [uint64_overflow]
    lea rsi, [uint64_overflow + uint64_overflow_len]
    call json_read_uint
    jnc .fail

    mov dword [failure_stage], 6
    ; Invalid or undersized strings cannot overrun caller storage.
    lea rdi, [surrogate_string]
    lea rsi, [surrogate_string + surrogate_string_len]
    lea rdx, [decoded]
    mov ecx, 64
    call json_read_string
    cmp eax, -1
    jne .fail
    lea rdi, [gateway_frame]
    mov esi, gateway_frame_len
    lea rdx, [key_content]
    mov ecx, key_content_len
    call json_find_key
    mov rdi, rax
    lea rsi, [gateway_frame + gateway_frame_len]
    lea rdx, [decoded]
    mov ecx, 4
    call json_read_string
    cmp eax, -1
    jne .fail

    mov dword [failure_stage], 7
    ; Object scanning stops exactly at the matching brace and ignores string bytes.
    lea rdi, [object_with_brace_string]
    lea rsi, [object_with_brace_string + object_with_brace_string_len]
    call json_object_end
    lea rdx, [object_with_brace_string + object_with_brace_string_len]
    cmp rax, rdx
    jne .fail
    lea rdi, [truncated_object]
    lea rsi, [truncated_object + truncated_object_len]
    call json_object_end
    test rax, rax
    jnz .fail

    mov dword [failure_stage], 8
    ; A missing key is zero, never an unbounded scan result.
    lea rdi, [gateway_frame]
    mov esi, gateway_frame_len
    lea rdx, [key_missing]
    mov ecx, key_missing_len
    call json_find_key
    test rax, rax
    jnz .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, [failure_stage]
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
; Includes a decoy `"op":99` inside content to prove string skipping.
gateway_frame: db '{"op":0,"d":{"content":"Hello', 0x5c, 'n', 0x5c, 'u263a ', 0x5c, '"op', 0x5c, '"', ':99","bot":false,"channel_id":"123456789012345678"}}'
gateway_frame_len equ $ - gateway_frame
key_op: db 'op'
key_op_len equ $ - key_op
key_content: db 'content'
key_content_len equ $ - key_content
key_bot: db 'bot'
key_bot_len equ $ - key_bot
key_channel: db 'channel_id'
key_channel_len equ $ - key_channel
key_missing: db 'absent'
key_missing_len equ $ - key_missing
decoded_content: db 'Hello', 10, 0xe2, 0x98, 0xba, ' ', '"op', '"', ':99'
decoded_content_len equ $ - decoded_content
channel_id: db '123456789012345678'
channel_id_len equ $ - channel_id
uint64_max: db '18446744073709551615'
uint64_max_len equ $ - uint64_max
uint64_overflow: db '18446744073709551616'
uint64_overflow_len equ $ - uint64_overflow
surrogate_string: db '"', 0x5c, 'uD800', '"'
surrogate_string_len equ $ - surrogate_string
object_with_brace_string: db '{"text":"{not an object}","nested":{"ok":true}}'
object_with_brace_string_len equ $ - object_with_brace_string
truncated_object: db '{"text":"open"'
truncated_object_len equ $ - truncated_object

section .data
failure_stage: dd 0

section .bss
decoded: resb 64

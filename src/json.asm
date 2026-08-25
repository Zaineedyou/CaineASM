BITS 64
DEFAULT REL

global json_escape_append
global json_find_key
global json_read_uint
global json_read_string
global json_value_is_true

; RDI=destination, ESI=destination capacity, RDX=source, ECX=source length.
; RAX=escaped byte length, or -1 when the bounded destination is insufficient.
; The output is not NUL-terminated. All JSON control, quote, and backslash
; escapes are emitted; non-control UTF-8 bytes pass through unchanged.
section .text
json_escape_append:
    xor r8d, r8d                     ; input offset
    xor r9d, r9d                     ; output offset
.loop:
    cmp r8d, ecx
    jae .done
    movzx eax, byte [rdx + r8]
    inc r8d
    cmp al, '"'
    je .quote
    cmp al, 0x5c
    je .backslash
    cmp al, 8
    je .backspace
    cmp al, 12
    je .formfeed
    cmp al, 10
    je .newline
    cmp al, 13
    je .carriage_return
    cmp al, 9
    je .tab
    cmp al, 0x20
    jb .unicode_control
    cmp r9d, esi
    jae .bad
    mov [rdi + r9], al
    inc r9d
    jmp .loop

.quote:
    mov al, '"'
    jmp .two_byte_escape
.backslash:
    mov al, 0x5c
    jmp .two_byte_escape
.backspace:
    mov al, 'b'
    jmp .two_byte_escape
.formfeed:
    mov al, 'f'
    jmp .two_byte_escape
.newline:
    mov al, 'n'
    jmp .two_byte_escape
.carriage_return:
    mov al, 'r'
    jmp .two_byte_escape
.tab:
    mov al, 't'
.two_byte_escape:
    lea r10d, [r9d + 2]
    cmp r10d, esi
    ja .bad
    mov byte [rdi + r9], 0x5c
    mov [rdi + r9 + 1], al
    mov r9d, r10d
    jmp .loop

.unicode_control:
    lea r10d, [r9d + 6]
    cmp r10d, esi
    ja .bad
    mov byte [rdi + r9], 0x5c
    mov byte [rdi + r9 + 1], 'u'
    mov byte [rdi + r9 + 2], '0'
    mov byte [rdi + r9 + 3], '0'
    mov r11d, eax
    shr r11d, 4
    and eax, 0x0f
    lea r10, [hex_lower]
    mov r11b, [r10 + r11]
    mov [rdi + r9 + 4], r11b
    mov al, [r10 + rax]
    mov [rdi + r9 + 5], al
    add r9d, 6
    jmp .loop
.done:
    mov eax, r9d
    ret
.bad:
    mov eax, -1
    ret

; RDI=JSON bytes, RSI=JSON length, RDX=unquoted ASCII key, ECX=key length.
; RAX=pointer to the first non-whitespace byte of that key's value, or zero.
; The scanner skips complete JSON strings so key-looking user text cannot match.
json_find_key:
    test rcx, rcx
    jz .none
    lea r9, [rdi + rsi]              ; exclusive end
    mov r8, rdi
.scan:
    cmp r8, r9
    jae .none
    cmp byte [r8], '"'
    jne .advance
    inc r8
    mov rax, r8
    mov r10d, ecx
    lea r11, [rax + r10]
    cmp r11, r9
    jae .skip_string
    mov edi, 0
.compare:
    cmp edi, ecx
    jae .key_bytes_match
    mov sil, [rax + rdi]
    cmp sil, [rdx + rdi]
    jne .skip_string
    inc edi
    jmp .compare
.key_bytes_match:
    cmp byte [rax + rcx], '"'
    jne .skip_string
    lea r11, [rax + rcx + 1]
.skip_whitespace:
    cmp r11, r9
    jae .none
    mov al, [r11]
    cmp al, ' '
    je .whitespace_advance
    cmp al, 9
    je .whitespace_advance
    cmp al, 10
    je .whitespace_advance
    cmp al, 13
    je .whitespace_advance
    cmp al, ':'
    jne .skip_string
    inc r11
.value_whitespace:
    cmp r11, r9
    jae .none
    mov al, [r11]
    cmp al, ' '
    je .value_ws_advance
    cmp al, 9
    je .value_ws_advance
    cmp al, 10
    je .value_ws_advance
    cmp al, 13
    je .value_ws_advance
    mov rax, r11
    ret
.whitespace_advance:
    inc r11
    jmp .skip_whitespace
.value_ws_advance:
    inc r11
    jmp .value_whitespace
.skip_string:
    mov r8, rax
.string_loop:
    cmp r8, r9
    jae .none
    mov al, [r8]
    inc r8
    cmp al, 0x5c
    je .escape_in_string
    cmp al, '"'
    je .scan
    jmp .string_loop
.escape_in_string:
    cmp r8, r9
    jae .none
    inc r8
    jmp .string_loop
.advance:
    inc r8
    jmp .scan
.none:
    xor eax, eax
    ret

; RDI=number start, RSI=exclusive input end.
; RAX=unsigned 64-bit result, RDX=first byte after the number; CF=0 success.
; CF=1 signals absent, malformed, or overflowing decimal data.
json_read_uint:
    xor eax, eax
    xor r8d, r8d
.loop:
    cmp rdi, rsi
    jae .done
    movzx r9d, byte [rdi]
    sub r9b, '0'
    cmp r9b, 9
    ja .done
.multiply:
    mov r10d, 10
    mul r10
    test rdx, rdx
    jnz .bad
    movzx r9d, r9b
    add rax, r9
    jc .bad
    inc rdi
    inc r8d
    jmp .loop
.done:
    test r8d, r8d
    jz .bad
    mov rdx, rdi
    clc
    ret
.bad:
    xor eax, eax
    xor edx, edx
    stc
    ret

; RDI=opening quote, RSI=exclusive input end, RDX=destination, ECX=capacity.
; EAX=decoded UTF-8 byte length and RDX=first byte after closing quote on success.
; EAX=-1 and RDX=0 on malformed input, capacity exhaustion, or lone surrogates.
json_read_string:
    sub rsp, 8
    cmp rdi, rsi
    jae .bad
    cmp byte [rdi], '"'
    jne .bad
    mov r11, rdx                     ; output base
    inc rdi
    xor r8d, r8d                     ; output length
.loop:
    cmp rdi, rsi
    jae .bad
    mov al, [rdi]
    inc rdi
    cmp al, '"'
    je .done
    cmp al, 0x5c
    je .escape
    cmp al, 0x20
    jb .bad
    jmp .emit_byte
.escape:
    cmp rdi, rsi
    jae .bad
    mov al, [rdi]
    inc rdi
    cmp al, '"'
    je .emit_byte
    cmp al, 0x5c
    je .emit_byte
    cmp al, '/'
    je .emit_byte
    cmp al, 'b'
    je .escape_backspace
    cmp al, 'f'
    je .escape_formfeed
    cmp al, 'n'
    je .escape_newline
    cmp al, 'r'
    je .escape_carriage_return
    cmp al, 't'
    je .escape_tab
    cmp al, 'u'
    je .unicode
    jmp .bad
.escape_backspace:
    mov al, 8
    jmp .emit_byte
.escape_formfeed:
    mov al, 12
    jmp .emit_byte
.escape_newline:
    mov al, 10
    jmp .emit_byte
.escape_carriage_return:
    mov al, 13
    jmp .emit_byte
.escape_tab:
    mov al, 9
    jmp .emit_byte
.emit_byte:
    cmp r8d, ecx
    jae .bad
    mov [r11 + r8], al
    inc r8d
    jmp .loop
.unicode:
    lea r9, [rdi + 4]
    cmp r9, rsi
    ja .bad
    xor r10d, r10d
    mov r9d, 4
.unicode_digit:
    movzx eax, byte [rdi]
    call json_hex_nibble
    jc .bad
    shl r10d, 4
    add r10d, eax
    inc rdi
    dec r9d
    jnz .unicode_digit
    cmp r10d, 0x7f
    jbe .unicode_one
    cmp r10d, 0x7ff
    jbe .unicode_two
    cmp r10d, 0xd800
    jb .unicode_three
    cmp r10d, 0xdfff
    jbe .bad
.unicode_three:
    lea eax, [r8d + 3]
    cmp eax, ecx
    ja .bad
    mov eax, r10d
    shr eax, 12
    or al, 0xe0
    mov [r11 + r8], al
    mov eax, r10d
    shr eax, 6
    and al, 0x3f
    or al, 0x80
    mov [r11 + r8 + 1], al
    mov eax, r10d
    and al, 0x3f
    or al, 0x80
    mov [r11 + r8 + 2], al
    add r8d, 3
    jmp .loop
.unicode_two:
    lea eax, [r8d + 2]
    cmp eax, ecx
    ja .bad
    mov eax, r10d
    shr eax, 6
    or al, 0xc0
    mov [r11 + r8], al
    mov eax, r10d
    and al, 0x3f
    or al, 0x80
    mov [r11 + r8 + 1], al
    add r8d, 2
    jmp .loop
.unicode_one:
    mov eax, r10d
    jmp .emit_byte
.done:
    mov rdx, rdi
    mov eax, r8d
    add rsp, 8
    ret
.bad:
    mov eax, -1
    xor edx, edx
    add rsp, 8
    ret

; AL=hex nibble for input AL; CF=1 when input is not a hexadecimal digit.
json_hex_nibble:
    cmp al, '0'
    jb .bad
    cmp al, '9'
    jbe .decimal
    cmp al, 'a'
    jb .upper
    cmp al, 'f'
    jbe .lower
.upper:
    cmp al, 'A'
    jb .bad
    cmp al, 'F'
    ja .bad
    sub al, 'A' - 10
    movzx eax, al
    clc
    ret
.lower:
    sub al, 'a' - 10
    movzx eax, al
    clc
    ret
.decimal:
    sub al, '0'
    movzx eax, al
    clc
    ret
.bad:
    xor eax, eax
    stc
    ret

; RDI=value start, RSI=exclusive input end. AL=1 only for the literal `true`.
json_value_is_true:
    lea rax, [rdi + 4]
    cmp rax, rsi
    ja .no
    cmp byte [rdi], 't'
    jne .no
    cmp byte [rdi + 1], 'r'
    jne .no
    cmp byte [rdi + 2], 'u'
    jne .no
    cmp byte [rdi + 3], 'e'
    jne .no
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

section .rodata
hex_lower: db '0123456789abcdef'

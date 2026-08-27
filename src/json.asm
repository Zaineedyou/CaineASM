BITS 64
DEFAULT REL

global json_escape_append
global json_find_key
global json_object_find_direct_key
global json_read_uint
global json_read_string
global json_value_is_true
global json_object_end
global json_array_end

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

; RDI=opening object brace, RSI=exclusive object end, RDX=unquoted ASCII key,
; ECX=key length. RAX=the direct member value pointer only when the key occurs
; exactly once. Zero means malformed JSON, non-object input, absent/duplicate
; key, or bytes after the closing brace. Nested keys can never match.
json_object_find_direct_key:
    push rbx
    push r12
    push r13
    push r14
    push r15
    test rdi, rdi
    jz .none
    cmp rdi, rsi
    jae .none
    test rcx, rcx
    jz .none
    cmp byte [rdi], '{'
    jne .none
    mov rbx, rdi
    mov r11, rsi
    mov r12, rdx
    mov r13d, ecx
    xor r14d, r14d                 ; matched value pointer
    xor r15d, r15d                 ; exact key occurrence count
    inc rbx
.first_ws:
    cmp rbx, r11
    jae .none
    mov al, [rbx]
    cmp al, ' '
    je .first_ws_advance
    cmp al, 9
    je .first_ws_advance
    cmp al, 10
    je .first_ws_advance
    cmp al, 13
    je .first_ws_advance
    cmp al, '}'
    je .close
    jmp .member
.first_ws_advance:
    inc rbx
    jmp .first_ws
.member:
    cmp byte [rbx], '"'
    jne .none
    mov rdi, rbx
    mov rsi, r11
    call json_direct_string_end
    test rax, rax
    jz .none
    mov r9, rax
    xor r10d, r10d
    mov r8, r9
    sub r8, rbx
    sub r8, 2
    cmp r8d, r13d
    jne .after_key
    xor eax, eax
.key_compare:
    cmp eax, r13d
    jae .key_match
    mov dl, [rbx + rax + 1]
    cmp dl, [r12 + rax]
    jne .after_key
    inc eax
    jmp .key_compare
.key_match:
    mov r10d, 1
.after_key:
    mov rbx, r9
.key_ws:
    cmp rbx, r11
    jae .none
    mov al, [rbx]
    cmp al, ' '
    je .key_ws_advance
    cmp al, 9
    je .key_ws_advance
    cmp al, 10
    je .key_ws_advance
    cmp al, 13
    je .key_ws_advance
    cmp al, ':'
    jne .none
    inc rbx
.value_ws:
    cmp rbx, r11
    jae .none
    mov al, [rbx]
    cmp al, ' '
    je .value_ws_advance
    cmp al, 9
    je .value_ws_advance
    cmp al, 10
    je .value_ws_advance
    cmp al, 13
    je .value_ws_advance
    jmp .value
.key_ws_advance:
    inc rbx
    jmp .key_ws
.value_ws_advance:
    inc rbx
    jmp .value_ws
.value:
    test r10d, r10d
    jz .skip_value
    inc r15d
    cmp r15d, 1
    jne .none
    mov r14, rbx
.skip_value:
    mov rdi, rbx
    mov rsi, r11
    call json_direct_value_end
    test rax, rax
    jz .none
    mov rbx, rax
.tail_ws:
    cmp rbx, r11
    jae .none
    mov al, [rbx]
    cmp al, ' '
    je .tail_ws_advance
    cmp al, 9
    je .tail_ws_advance
    cmp al, 10
    je .tail_ws_advance
    cmp al, 13
    je .tail_ws_advance
    cmp al, ','
    je .comma
    cmp al, '}'
    je .close
    jmp .none
.tail_ws_advance:
    inc rbx
    jmp .tail_ws
.comma:
    inc rbx
.next_member_ws:
    cmp rbx, r11
    jae .none
    mov al, [rbx]
    cmp al, ' '
    je .next_member_ws_advance
    cmp al, 9
    je .next_member_ws_advance
    cmp al, 10
    je .next_member_ws_advance
    cmp al, 13
    je .next_member_ws_advance
    cmp al, '"'
    jne .none
    jmp .member
.next_member_ws_advance:
    inc rbx
    jmp .next_member_ws
.close:
    inc rbx
    cmp rbx, r11
    jne .none
    cmp r15d, 1
    jne .none
    mov rax, r14
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

; RDI=value start, RSI=exclusive JSON end. RAX=first byte after one complete
; strict JSON value or zero. Recursion is capped to keep hostile nesting bounded.
json_direct_value_end:
    push r10
    cmp dword [json_strict_depth], 32
    jae .bad
    inc dword [json_strict_depth]
    cmp rdi, rsi
    jae .bad_depth
    mov al, [rdi]
    cmp al, '"'
    je .string
    cmp al, '{'
    je .object
    cmp al, '['
    je .array
    cmp al, 't'
    je .true
    cmp al, 'f'
    je .false
    cmp al, 'n'
    je .null
    cmp al, '-'
    je .number
    cmp al, '0'
    jb .bad_depth
    cmp al, '9'
    ja .bad_depth
.number:
    mov rax, rdi
    cmp byte [rax], '-'
    jne .integer
    inc rax
    cmp rax, rsi
    jae .bad_depth
.integer:
    mov dl, [rax]
    cmp dl, '0'
    je .zero_integer
    cmp dl, '1'
    jb .bad_depth
    cmp dl, '9'
    ja .bad_depth
.integer_digits:
    inc rax
    cmp rax, rsi
    jae .number_done
    mov dl, [rax]
    cmp dl, '0'
    jb .fraction
    cmp dl, '9'
    ja .fraction
    jmp .integer_digits
.zero_integer:
    inc rax
    cmp rax, rsi
    jae .number_done
    mov dl, [rax]
    cmp dl, '0'
    jb .fraction
    cmp dl, '9'
    jbe .bad_depth
.fraction:
    cmp dl, '.'
    jne .exponent
    inc rax
    cmp rax, rsi
    jae .bad_depth
    mov dl, [rax]
    cmp dl, '0'
    jb .bad_depth
    cmp dl, '9'
    ja .bad_depth
.fraction_digits:
    inc rax
    cmp rax, rsi
    jae .number_done
    mov dl, [rax]
    cmp dl, '0'
    jb .exponent
    cmp dl, '9'
    ja .exponent
    jmp .fraction_digits
.exponent:
    cmp dl, 'e'
    je .exponent_start
    cmp dl, 'E'
    jne .number_done
.exponent_start:
    inc rax
    cmp rax, rsi
    jae .bad_depth
    mov dl, [rax]
    cmp dl, '+'
    je .exponent_sign
    cmp dl, '-'
    je .exponent_sign
    jmp .exponent_digit
.exponent_sign:
    inc rax
    cmp rax, rsi
    jae .bad_depth
    mov dl, [rax]
.exponent_digit:
    cmp dl, '0'
    jb .bad_depth
    cmp dl, '9'
    ja .bad_depth
.exponent_digits:
    inc rax
    cmp rax, rsi
    jae .number_done
    mov dl, [rax]
    cmp dl, '0'
    jb .number_done
    cmp dl, '9'
    ja .number_done
    jmp .exponent_digits
.number_done:
    mov rdi, rax
    jmp .delimiter
.true:
    lea rax, [rdi + 4]
    cmp rax, rsi
    ja .bad_depth
    cmp byte [rdi + 1], 'r'
    jne .bad_depth
    cmp byte [rdi + 2], 'u'
    jne .bad_depth
    cmp byte [rdi + 3], 'e'
    jne .bad_depth
    mov rdi, rax
    jmp .delimiter
.false:
    lea rax, [rdi + 5]
    cmp rax, rsi
    ja .bad_depth
    cmp byte [rdi + 1], 'a'
    jne .bad_depth
    cmp byte [rdi + 2], 'l'
    jne .bad_depth
    cmp byte [rdi + 3], 's'
    jne .bad_depth
    cmp byte [rdi + 4], 'e'
    jne .bad_depth
    mov rdi, rax
    jmp .delimiter
.null:
    lea rax, [rdi + 4]
    cmp rax, rsi
    ja .bad_depth
    cmp byte [rdi + 1], 'u'
    jne .bad_depth
    cmp byte [rdi + 2], 'l'
    jne .bad_depth
    cmp byte [rdi + 3], 'l'
    jne .bad_depth
    mov rdi, rax
    jmp .delimiter
.string:
    call json_direct_string_end
    jmp .done_depth
.object:
    call json_strict_object_end
    jmp .done_depth
.array:
    call json_strict_array_end
    jmp .done_depth
.delimiter:
    cmp rdi, rsi
    je .scalar_done
    mov al, [rdi]
    cmp al, ' '
    je .scalar_done
    cmp al, 9
    je .scalar_done
    cmp al, 10
    je .scalar_done
    cmp al, 13
    je .scalar_done
    cmp al, ','
    je .scalar_done
    cmp al, '}'
    je .scalar_done
    cmp al, ']'
    je .scalar_done
    jmp .bad_depth
.scalar_done:
    mov rax, rdi
.done_depth:
    dec dword [json_strict_depth]
    pop r10
    ret
.bad_depth:
    dec dword [json_strict_depth]
.bad:
    xor eax, eax
    pop r10
    ret

; Strict JSON object/array readers used internally by json_direct_value_end.
json_strict_object_end:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    cmp rbx, r12
    jae .bad
    cmp byte [rbx], '{'
    jne .bad
    inc rbx
.ws_first:
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    cmp byte [rbx], '}'
    je .close
.member:
    cmp byte [rbx], '"'
    jne .bad
    mov rdi, rbx
    mov rsi, r12
    call json_direct_string_end
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    cmp byte [rbx], ':'
    jne .bad
    inc rbx
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, rbx
    mov rsi, r12
    call json_direct_value_end
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    cmp byte [rbx], ','
    je .comma
    cmp byte [rbx], '}'
    je .close
    jmp .bad
.comma:
    inc rbx
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    cmp byte [rbx], '"'
    jne .bad
    jmp .member
.close:
    inc rbx
    mov rax, rbx
    jmp .out
.bad:
    xor eax, eax
.out:
    add rsp, 8
    pop r12
    pop rbx
    ret

json_strict_array_end:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    cmp rbx, r12
    jae .bad
    cmp byte [rbx], '['
    jne .bad
    inc rbx
.ws_first:
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    cmp byte [rbx], ']'
    je .close
.value:
    mov rdi, rbx
    mov rsi, r12
    call json_direct_value_end
    test rax, rax
    jz .bad
    mov rbx, rax
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    cmp byte [rbx], ','
    je .comma
    cmp byte [rbx], ']'
    je .close
    jmp .bad
.comma:
    inc rbx
    mov rdi, rbx
    mov rsi, r12
    call json_direct_skip_ws
    test rax, rax
    jz .bad
    mov rbx, rax
    cmp byte [rbx], ']'
    je .bad
    jmp .value
.close:
    inc rbx
    mov rax, rbx
    jmp .out
.bad:
    xor eax, eax
.out:
    add rsp, 8
    pop r12
    pop rbx
    ret

; RDI=current byte, RSI=exclusive end. RAX=first non-whitespace byte, or zero.
json_direct_skip_ws:
    mov rax, rdi
.loop:
    cmp rax, rsi
    jae .none
    mov dl, [rax]
    cmp dl, ' '
    je .advance
    cmp dl, 9
    je .advance
    cmp dl, 10
    je .advance
    cmp dl, 13
    je .advance
    ret
.advance:
    inc rax
    jmp .loop
.none:
    xor eax, eax
    ret

; RDI=opening quote, RSI=exclusive end. RAX=after closing quote, or zero.
json_direct_string_end:
    cmp rdi, rsi
    jae .bad
    cmp byte [rdi], '"'
    jne .bad
    mov rax, rdi
    inc rax
.loop:
    cmp rax, rsi
    jae .bad
    mov dl, [rax]
    inc rax
    cmp dl, '"'
    je .done
    cmp dl, 0x5c
    je .escape
    cmp dl, 0x20
    jb .bad
    jmp .loop
.escape:
    cmp rax, rsi
    jae .bad
    mov dl, [rax]
    inc rax
    cmp dl, '"'
    je .loop
    cmp dl, 0x5c
    je .loop
    cmp dl, '/'
    je .loop
    cmp dl, 'b'
    je .loop
    cmp dl, 'f'
    je .loop
    cmp dl, 'n'
    je .loop
    cmp dl, 'r'
    je .loop
    cmp dl, 't'
    je .loop
    cmp dl, 'u'
    jne .bad
    mov r8d, 4
.unicode:
    cmp rax, rsi
    jae .bad
    mov dl, [rax]
    cmp dl, '0'
    jb .unicode_upper
    cmp dl, '9'
    jbe .unicode_next
.unicode_upper:
    cmp dl, 'A'
    jb .unicode_lower
    cmp dl, 'F'
    jbe .unicode_next
.unicode_lower:
    cmp dl, 'a'
    jb .bad
    cmp dl, 'f'
    ja .bad
.unicode_next:
    inc rax
    dec r8d
    jnz .unicode
    jmp .loop
.done:
    ret
.bad:
    xor eax, eax
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

; RDI=opening object brace, RSI=exclusive input end. RAX=first byte after the
; matching closing brace, or zero for malformed/truncated input. JSON strings
; and escapes are skipped so braces inside a string do not alter object depth.
json_object_end:
    cmp rdi, rsi
    jae .bad
    cmp byte [rdi], '{'
    jne .bad
    xor r8d, r8d
.loop:
    cmp rdi, rsi
    jae .bad
    mov al, [rdi]
    inc rdi
    cmp al, '"'
    je .string
    cmp al, '{'
    je .open
    cmp al, '}'
    je .close
    jmp .loop
.open:
    inc r8d
    jmp .loop
.close:
    dec r8d
    jnz .loop
    mov rax, rdi
    ret
.string:
    cmp rdi, rsi
    jae .bad
    mov al, [rdi]
    inc rdi
    cmp al, 0x5c
    je .escaped
    cmp al, '"'
    je .loop
    jmp .string
.escaped:
    cmp rdi, rsi
    jae .bad
    inc rdi
    jmp .string
.bad:
    xor eax, eax
    ret

; RDI=opening array bracket, RSI=exclusive input end. RAX=first byte after the
; matching closing bracket, or zero for malformed/truncated JSON. JSON strings
; and escapes are skipped so brackets inside a string do not alter depth.
json_array_end:
    cmp rdi, rsi
    jae .bad
    cmp byte [rdi], '['
    jne .bad
    xor r8d, r8d
.loop:
    cmp rdi, rsi
    jae .bad
    mov al, [rdi]
    inc rdi
    cmp al, '"'
    je .string
    cmp al, '['
    je .open
    cmp al, ']'
    je .close
    jmp .loop
.open:
    inc r8d
    jmp .loop
.close:
    dec r8d
    jnz .loop
    mov rax, rdi
    ret
.string:
    cmp rdi, rsi
    jae .bad
    mov al, [rdi]
    inc rdi
    cmp al, 0x5c
    je .escaped
    cmp al, '"'
    je .loop
    jmp .string
.escaped:
    cmp rdi, rsi
    jae .bad
    inc rdi
    jmp .string
.bad:
    xor eax, eax
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

section .bss
json_strict_depth: resd 1

section .rodata
hex_lower: db '0123456789abcdef'

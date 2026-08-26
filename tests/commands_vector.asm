BITS 64
DEFAULT REL

extern command_classify
extern command_is_admin_only
global _start

%define SYS_EXIT 60
%define CMD_HELP 1
%define CMD_WARN 9
%define CMD_SETPERSONA 22
%define CMD_SETLOG 30
%define CMD_SETGOODBYEMSG 32

section .text
_start:
    lea rdi, [help]
    mov esi, help_len
    call command_classify
    cmp eax, CMD_HELP
    jne .fail

    lea rdi, [warn]
    mov esi, warn_len
    call command_classify
    cmp eax, CMD_WARN
    jne .fail
    mov edi, eax
    call command_is_admin_only
    test al, al
    jz .fail

    lea rdi, [persona]
    mov esi, persona_len
    call command_classify
    cmp eax, CMD_SETPERSONA
    jne .fail

    lea rdi, [setlog]
    mov esi, setlog_len
    call command_classify
    cmp eax, CMD_SETLOG
    jne .fail
    mov edi, eax
    call command_is_admin_only
    test al, al
    jz .fail

    lea rdi, [goodbyemsg]
    mov esi, goodbyemsg_len
    call command_classify
    cmp eax, CMD_SETGOODBYEMSG
    jne .fail

    lea rdi, [setbridge]
    mov esi, setbridge_len
    call command_classify
    test eax, eax
    jnz .fail

    lea rdi, [bridgestatus]
    mov esi, bridgestatus_len
    call command_classify
    test eax, eax
    jnz .fail

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.fail:
    mov eax, SYS_EXIT
    mov edi, 1
    syscall

section .rodata
help: db 'help'
help_len equ $ - help
warn: db 'warn'
warn_len equ $ - warn
persona: db 'setpersona'
persona_len equ $ - persona
setlog: db 'setlog'
setlog_len equ $ - setlog
goodbyemsg: db 'setgoodbyemsg'
goodbyemsg_len equ $ - goodbyemsg
setbridge: db 'setbridge'
setbridge_len equ $ - setbridge
bridgestatus: db 'bridgestatus'
bridgestatus_len equ $ - bridgestatus

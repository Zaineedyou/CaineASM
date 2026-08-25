BITS 64
DEFAULT REL

global command_classify
global command_is_admin_only

; Input: RDI points to normalized command token, RSI contains its exact length.
; Output: EAX command ID. ID 0 means unknown or intentionally removed.
; Minecraft bridge command names are deliberately absent from this routing table.

%define CMD_UNKNOWN      0
%define CMD_HELP         1
%define CMD_RESET        2
%define CMD_AFK          3
%define CMD_AFKLIST      4
%define CMD_RANK         5
%define CMD_LEADERBOARD  6
%define CMD_STATUS       7
%define CMD_SUMMARIZE    8
%define CMD_WARN         9
%define CMD_KICK         10
%define CMD_BAN          11
%define CMD_TIMEOUT      12
%define CMD_CLEAR        13
%define CMD_LOCK         14
%define CMD_UNLOCK       15
%define CMD_SLOWMODE     16
%define CMD_ADDWORD      17
%define CMD_REMOVEWORD   18
%define CMD_WORDS        19
%define CMD_ENABLE       20
%define CMD_DISABLE      21
%define CMD_SETPERSONA  22
%define CMD_SETMODEL    23
%define CMD_SETHISTORY  24
%define CMD_AUTOROLE    25
%define CMD_SETWELCOME  26
%define CMD_SETGOODBYE  27

section .text
command_classify:
    mov r8, rdi
    mov r9, rsi
    lea rdx, [command_table]
.next:
    mov eax, [rdx]
    test eax, eax
    jz .unknown
    mov ecx, [rdx + 4]
    cmp rcx, r9
    jne .advance
    mov rdi, r8
    mov rsi, [rdx + 8]
    call equal_bytes
    test al, al
    jnz .matched
.advance:
    add rdx, 16
    jmp .next
.matched:
    mov eax, [rdx]
    ret
.unknown:
    xor eax, eax
    ret

; Input: EDI command ID. AL=1 only if it requires guild administration/moderation policy.
command_is_admin_only:
    cmp edi, CMD_WARN
    je .yes
    cmp edi, CMD_KICK
    je .yes
    cmp edi, CMD_BAN
    je .yes
    cmp edi, CMD_TIMEOUT
    je .yes
    cmp edi, CMD_CLEAR
    je .yes
    cmp edi, CMD_LOCK
    je .yes
    cmp edi, CMD_UNLOCK
    je .yes
    cmp edi, CMD_SLOWMODE
    je .yes
    cmp edi, CMD_ADDWORD
    je .yes
    cmp edi, CMD_REMOVEWORD
    je .yes
    cmp edi, CMD_ENABLE
    je .yes
    cmp edi, CMD_DISABLE
    je .yes
    cmp edi, CMD_SETPERSONA
    je .yes
    cmp edi, CMD_SETMODEL
    je .yes
    cmp edi, CMD_SETHISTORY
    je .yes
    cmp edi, CMD_AUTOROLE
    je .yes
    cmp edi, CMD_SETWELCOME
    je .yes
    cmp edi, CMD_SETGOODBYE
    je .yes
    xor eax, eax
    ret
.yes:
    mov al, 1
    ret

; RDI and RSI are two equal-sized buffers. RCX is their size. AL=1 when equal.
equal_bytes:
    xor eax, eax
.loop:
    cmp rax, rcx
    jae .yes
    mov r10b, [rdi + rax]
    cmp r10b, [rsi + rax]
    jne .no
    inc rax
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

section .rodata
s_help: db 'help'
s_reset: db 'reset'
s_clear: db 'clear'
s_afk: db 'afk'
s_afklist: db 'afklist'
s_rank: db 'rank'
s_leaderboard: db 'leaderboard'
s_status: db 'status'
s_summarize: db 'summarize'
s_warn: db 'warn'
s_kick: db 'kick'
s_ban: db 'ban'
s_timeout: db 'timeout'
s_lock: db 'lock'
s_unlock: db 'unlock'
s_slowmode: db 'slowmode'
s_addword: db 'addword'
s_removeword: db 'removeword'
s_words: db 'words'
s_enable: db 'enable'
s_disable: db 'disable'
s_setpersona: db 'setpersona'
s_setmodel: db 'setmodel'
s_sethistory: db 'sethistory'
s_autorole: db 'autorole'
s_setwelcome: db 'setwelcome'
s_setgoodbye: db 'setgoodbye'

align 8
command_table:
    dd CMD_HELP, 4
    dq s_help
    dd CMD_RESET, 5
    dq s_reset
    dd CMD_CLEAR, 5
    dq s_clear
    dd CMD_AFK, 3
    dq s_afk
    dd CMD_AFKLIST, 7
    dq s_afklist
    dd CMD_RANK, 4
    dq s_rank
    dd CMD_LEADERBOARD, 11
    dq s_leaderboard
    dd CMD_STATUS, 6
    dq s_status
    dd CMD_SUMMARIZE, 9
    dq s_summarize
    dd CMD_WARN, 4
    dq s_warn
    dd CMD_KICK, 4
    dq s_kick
    dd CMD_BAN, 3
    dq s_ban
    dd CMD_TIMEOUT, 7
    dq s_timeout
    dd CMD_LOCK, 4
    dq s_lock
    dd CMD_UNLOCK, 6
    dq s_unlock
    dd CMD_SLOWMODE, 8
    dq s_slowmode
    dd CMD_ADDWORD, 7
    dq s_addword
    dd CMD_REMOVEWORD, 10
    dq s_removeword
    dd CMD_WORDS, 5
    dq s_words
    dd CMD_ENABLE, 6
    dq s_enable
    dd CMD_DISABLE, 7
    dq s_disable
    dd CMD_SETPERSONA, 10
    dq s_setpersona
    dd CMD_SETMODEL, 8
    dq s_setmodel
    dd CMD_SETHISTORY, 10
    dq s_sethistory
    dd CMD_AUTOROLE, 8
    dq s_autorole
    dd CMD_SETWELCOME, 10
    dq s_setwelcome
    dd CMD_SETGOODBYE, 10
    dq s_setgoodbye
    dd 0, 0
    dq 0

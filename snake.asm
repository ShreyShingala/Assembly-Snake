extern _tcgetattr
extern _tcsetattr
extern _printf
extern _fflush
extern _getchar
extern _usleep
extern _select
extern _rand

default rel
global _main

%define Columns 60
%define Rows 30

section .data
    hide_cursor: db 27, '[?25l', 0
    show_cursor: db 27, '[?25h', 0
    cursortotop: db 27, '[%iA', 0
    cursortotop2: db 27, '[%iF', 0
    gameoverstr: db 27, '[%iB', 27, '[%iC Game Over! ', 0
    tailstr: db 27, '[%iB', 27, '[%iC·', 0
    headstr: db 27, '[%iB', 27, '[%iC▒', 0
    applestr: db 27, '[%iB', 27, '[%iC♥', 0

section .bss
    data: resb 1
    oldtime: resb 64
    newtime: resb 64
    buf: resq Columns * Rows + 1
    x: resq 1024
    y: resq 1024
    xdir: resq 1
    ydir: resq 1
    head: resq 1
    tail: resq 1
    applex: resq 1
    appley: resq 1
    tv: resq 2
    fds: resq 16 

section .text
init:
    push rbp
    mov rdi, hide_cursor
    call _printf
    xor rdi, rdi
    call _fflush

    ; start the magic game
    mov rdi, 0
    mov rsi, oldtime
    call _tcgetattr

    mov rdi, newtime
    mov rsi, oldtime
    mov rcx, 64
    rep movsb

    and word [newtime + 3 * 8], ~(0x0100 | 0x0008) ; disable ECHO and ICANON
    mov rdi, 0
    mov rsi, 0
    mov rdx, newtime
    call _tcsetattr
    pop rbp
    ret 

exit:
    mov rdi, show_cursor
    call _printf
    xor rdi, rdi
    call _fflush

    ; put terminal back to normal
    mov rdi, 0
    mov rsi, 0
    mov rdx, oldtime
    call _tcsetattr

    mov rax, 0x2000001
    xor rdi, rdi
    syscall

render_table:
    push rbp

    ;tippy top
    mov rdi, buf
    mov rax, '┌'
    stosd
    dec rdi
    mov rcx, Columns
    mov rax, '─'

_r0:
    stosd
    dec rdi
    dec rcx
    jnz _r0
    mov rax, '┐'
    stosd
    mov byte [rdi-1], 10 ; tis a new line

    ;middle

    mov rsi, Rows
_r1:
    mov rax, '│'
    stosd
    dec rdi
    mov rcx, Columns
    mov ax, '·'
    rep stosw
    mov eax, '│'
    stosd
    mov byte [rdi-1], 10 ; tis a new line
    dec rsi
    jnz _r1

    ;bottom
    mov rax, '└'
    stosd
    dec rdi
    mov rcx, Columns
    mov rax, '─'

_r2:
    stosd
    dec rdi
    dec rcx
    jnz _r2
    mov rax, '┘'
    stosd
    mov byte [rdi-1], 10 ; tis a new line

    mov rdi, buf
    call _printf
    
    mov rdi, cursortotop
    mov rsi, Rows + 2
    call _printf

    pop rbp
    ret

_main:
    push rbp
    call init

_main_loop:
    call render_table
    
    mov qword [tail], 0
    mov qword [head], 0
    mov qword [xdir], 1
    mov qword [ydir], 0
    mov qword [x], Columns / 2
    mov qword [y], Rows / 2
    mov qword [applex], -1

loop:
    lea rbp, [data]

    cmp qword [applex], 0
    jge apple_exists

    ;create apple
    call _rand
    xor rdx, rdx
    mov rbx, Columns
    div rbx
    mov [applex], rdx
    call _rand
    xor rdx, rdx
    mov rbx, Rows
    div rbx
    mov [appley], rdx

    ;check apple on snake
    mov rdi, [head]
    mov rax, [applex]
    mov rbx, [appley]
    mov rsi, [tail]

q3:
    cmp rsi, [head]
    jz q5
    cmp [rbp + (x - data) + rsi * 8], rax
    jnz q4
    cmp [rbp + (y - data) + rsi * 8], rbx
    jnz q4
    mov qword [applex], -1
q4:
    inc rsi
    and rsi, 1023
    jmp q3
q5:
    ;Draw apple
    cmp qword [applex], 0
    jl apple_exists
    mov rdi, applestr
    mov rsi, [appley]
    mov rdx, [applex]
    inc rsi
    inc rdx
    call _printf
    mov rdi, cursortotop2
    mov rsi, [appley]
    inc rsi
    call _printf

apple_exists:


    ;clear snake tail
    mov rbx, [tail]
    mov rdi, tailstr
    mov rsi, [rbp + (y - data) + rbx * 8 ]
    mov rdx, [rbp + (x - data) + rbx * 8 ]
    inc rsi
    inc rdx
    call _printf

    mov rbx, [tail]
    mov rdi, cursortotop2
    mov rsi, [rbp + (y - data) + rbx * 8 ]
    inc rsi
    call _printf

    ;Eat the apple
    mov rbx, [head]
    mov rax, [rbp + (x - data) + rbx * 8]
    cmp eax, [applex]
    jnz noeat
    mov rax, [rbp + (y - data) + rbx * 8]
    cmp eax, [appley]
    jnz noeat

    mov qword [applex], -1
    jmp apple_eaten

noeat:
    ;move tail
    mov rbx, [tail]
    inc rbx
    and rbx, 1023
    mov [tail], rbx

apple_eaten:
    ;move head
    mov rbx, [head]
    mov rax, rbx
    inc rbx
    and rbx, 1023

    mov rcx, [rbp + (x - data) + rax * 8]
    add rcx, [xdir]
    cmp rcx, Columns
    jb ok0
    jge o1
    add rcx, Columns
    jmp ok0
o1:
    sub rcx, Columns
ok0:
    mov [rbp + (x - data) + rbx * 8], rcx    
    mov rdx, [rbp + (y - data) + rax * 8]
    add rdx, [ydir]
    cmp rdx, Rows
    jb ok2
    jge o2
    add rdx, Rows
    jmp ok2
o2:
    sub rdx, Rows
ok2:
    mov [rbp + (y - data) + rbx * 8], rdx
    mov [head], rbx

    ;Check gameover
    mov rdi, [head]
    mov rax, [rbp + (x - data) + rdi * 8]
    mov rbx, [rbp + (y - data) + rdi * 8]
    mov rsi, [tail]
r3:
    cmp rsi, [head]
    jz r5
    cmp [rbp + (x - data) + rsi * 8], rax
    jnz r4
    cmp [rbp + (y - data) + rsi * 8], rbx
    jz gameover
r4:
    inc rsi
    and rsi, 1023
    jmp r3
r5:
    ;draw head
    mov rbx, [head]
    mov rdi, headstr
    mov rsi, [rbp + (y - data) + rbx * 8]
    mov rdx, [rbp + (x - data) + rbx * 8]
    inc rsi
    inc rdx
    call _printf
    mov rdi, cursortotop2
    mov rbx, [head]
    mov rsi, [rbp + (y - data) + rbx * 8]
    inc rsi 
    call _printf
    xor rdi, rdi
    call _fflush

    ;Delay
    mov rdi, 5 * 1000000 / 60
    call _usleep

    ;read keyboard
    mov qword [fds], 1
    mov rdi, 1
    mov rsi, fds
    mov rdx, 0
    mov rcx, 0
    mov qword [tv], 0
    mov qword [tv + 8], 0 ;I CHANGE THIS VALUE MYSELF OK SO REMEMBER THAT I DID IN FACT CHANGE IT FUTURE ME
    mov  r8, tv
    call _select
    test rax, 1
    jz nokey

    call _getchar
    cmp al, 27
    jz exit
    cmp al, 'q'
    jz exit

    cmp al, 'w'
    jnz notw
    cmp qword [ydir], 1
    jz notw
    mov qword [ydir], -1
    mov qword [xdir], 0

notw:
    cmp al, 's'
    jnz nots
    cmp qword [ydir], -1
    jz nots
    mov qword [ydir], 1
    mov qword [xdir], 0

nots:
    cmp al, 'a'
    jnz nota
    cmp qword [xdir], 1
    jz nota
    mov qword [ydir], 0
    mov qword [xdir], -1

nota:  
    cmp al, 'd'
    jnz nokey
    cmp qword [xdir], -1
    jz nokey
    mov qword [ydir], 0
    mov qword [xdir], 1

nokey:
    jmp loop

gameover:
    ; will show gameover

    mov rdi, gameoverstr
    mov rsi, Rows / 2
    mov rdx, Columns / 2 - 5 
    call _printf
    mov rdi, cursortotop2
    mov rsi, Rows / 2
    call _printf

    call _getchar
    jmp _main_loop
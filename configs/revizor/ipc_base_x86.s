// intel assembly syntax
.intel_syntax noprefix
// entry point for GNU ld
.global _start
// address where revizor will insert its code
.global code
// base address of memory sandbox for code to play with
.global sandbox

.ifndef SANDBOX_PAGES
.error "SANDBOX_PAGES not defined"
.endif

.data
.balign 4096
sandbox:
    .fill ((SANDBOX_PAGES + 1) * 4096)

start_sp:
    .quad 0
registers:
    .fill 64

.text
_start:
    // store stack pointer
    mov [start_sp], rsp
    mfence
    jmp code
.balign 4096
code:
    .fill 512, 1, 0x90
    xor edi, edi

    // m5exit
    .byte 0x0F, 0x04
    // M5OP_EXIT = 0x21
    .word 0x21

    mfence
    // restore stack pointer
    mov rsp, [start_sp]
    // load input register values
    // The ordering of registers:  RAX, RBX, RCX, RDX, RSI, RDI, FLAGS

    // set r14 to sandbox base address
    lea r14, sandbox

    // flush sandbox cache lines
    mov r10, 0
    1:
        clflush [sandbox+r10]
        // move to next cache line
        add r10, 64
        // extra 64B is for randomized_mem_alignment Revizor option
        cmp r10, (SANDBOX_PAGES*4096 + 64)
        jl 1b

    // ensure sandbox pages are loaded into TLB
    mov r10, 0
    1:
        mfence
        add r9, [sandbox+r10]
        mfence
        add r10, 4096
        cmp r10, (SANDBOX_PAGES*4096)
        jl 1b

    mfence
    // FLAGS <- [registers+48]
    mov rax, [registers+48]
    mfence
    push rax
    popf
    mfence
    mov rax, [registers]
    mfence
    mov rbx, [registers+8]
    mfence
    mov rcx, [registers+16]
    mfence
    mov rdx, [registers+24]
    mfence
    mov rsi, [registers+32]
    mfence
    mov rdi, [registers+40]
    mfence
    jmp code

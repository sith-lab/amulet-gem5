// intel assembly syntax
.intel_syntax noprefix
// entry point for GNU ld
.global _start
// address where revizor will insert its code
.global code
// base address of memory sandbox for code to play with
.global sandbox

.equiv L1D_SIZE, (128 << 10)
.equiv L1D_ASSOC, 8

// CHANGE THIS FOR SANDBOX: Number of pages in sandbox
.equiv SANDBOX_PAGES, 1

// A number which is a multiple of a large power of 2
// (it just has to satisfy the two conditions asserted below)
.equiv THRASH_SPACING, 16384


.if (THRASH_SPACING % 4096 != 0)
// THRASH_SPACING must be a multiple of page size
.abort
.endif
.if (THRASH_SPACING % (L1D_SIZE / L1D_ASSOC) != 0)
// THRASH_SPACING should be a multiple of L1D_SIZE / L1D_ASSOC
// so that thrash and sandbox map to the same cache sets.
.abort
.endif

.equiv SANDBOX_SIZE, (SANDBOX_PAGES * 4096)
// offset into sandbox of where the eviction set starts
.equiv THRASH_START, ((SANDBOX_SIZE / THRASH_SPACING + 1) * THRASH_SPACING)

// Number of cache sets to access in the eviction set
.if SANDBOX_SIZE + 64 < (L1D_SIZE / L1D_ASSOC)
// Eviction set of this size will fully cover cache sets which
// sandbox maps to.
// (extra 64B is for randomized_mem_alignment Revizor option)
.equiv THRASH_COUNT, ((SANDBOX_SIZE + 64) / 64)
.else
// This many accesses will completely fill the L1D cache, so
// we don't need to access any more.
.equiv THRASH_COUNT, (L1D_SIZE / (64 * L1D_ASSOC))
.endif

// Number of entries in DTLB. Must be a power of 2.
// (In fact, this just needs to be *at least as large as* the number of entries in the DTLB)
.equiv TLB_SIZE, 64

.data
.balign 4096
sandbox:
    .fill (THRASH_START + THRASH_COUNT * L1D_ASSOC * 64 + (L1D_ASSOC + TLB_SIZE) * THRASH_SPACING)

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

    // restore stack pointer
    mov rsp, [start_sp]
    // load input register values
    // The ordering of registers:  RAX, RBX, RCX, RDX, RSI, RDI, FLAGS

    // set r14 to sandbox base address
    lea r14, sandbox

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

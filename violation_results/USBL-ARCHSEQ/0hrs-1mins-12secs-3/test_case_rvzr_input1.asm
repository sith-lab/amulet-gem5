.intel_syntax noprefix
.test_case_enter:
LFENCE
# From spectre_v1_arch.asm

# delay the cond. jump
MOV rax, r14
MOV rbx, qword ptr [rax + 4096] # random value added to sandbox base
AND RBX, 0b11111100000 # instrumentation
MOV rbx, qword ptr [rax + rbx]
AND RBX, 0b11111100000 # instrumentation
MOV rbx, qword ptr [rax + rbx]
AND RBX, 0b11111100000 # instrumentation
MOV rbx, qword ptr [rax + rbx]
AND RBX, 0b11111100000 # instrumentation
MOV rbx, qword ptr [rax + rbx]

# reduce the entropy in rbx
AND rbx, 0b1000000

CMP rbx, 0
JE .l1  # misprediction
.l0:
    # rbx != 0
    MOV rax, qword ptr [r14 + 5218]
    # SHL rax, 2
    AND rax, 0b1111111111111 # Can be up to (268435456 - 1) bits of entropy (256MB total memory)
    SHL rax, 2 # Add entropy up to max 0x10000000
    MOV rax, qword ptr [r14 + rax] # load: leakage happens here
    # MOV qword ptr [r14 + rax], rax # store: leakage happens here
.l1:

.test_case_exit:
MFENCE

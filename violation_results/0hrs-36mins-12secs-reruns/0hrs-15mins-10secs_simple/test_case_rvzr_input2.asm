.intel_syntax noprefix
LEA R14, [R14 + 60] # instrumentation
MFENCE # instrumentation
.test_case_enter:
.function_main:
.bb_main.entry:
# mov r15, rax
# mov r15, rbx
# mov r15, rcx
# mov r15, rdx
# mov r15, rsi
# mov r15, rdi
# mov r15, rbp
# mov r15, rsp
# mov r15, r8
# mov r15, r9
# mov r15, r10
# mov r15, r11
# mov r15, r12
# mov r15, r13
# mov r15, r14
# mov r15, r15
# mov r15, 0 # Unused by executor

JMP .bb_main.0 
.bb_main.0:
AND RSI, 0b111111111111111 # instrumentation
OR word ptr [R14 + RSI], DX 
AND RDI, 0b111111111111111 # instrumentation
CMOVP EAX, dword ptr [R14 + RDI] 
AND RDI, 0b111111111111111 # instrumentation
LOCK AND qword ptr [R14 + RDI], 74 
JMP .bb_main.1 
.bb_main.1:
AND BL, 27 # instrumentation
LOOPNE .bb_main.2 
JMP .bb_main.3 
.bb_main.2:
AND RDI, 0b111111111111111 # instrumentation
OR byte ptr [R14 + RDI], SIL 
AND RDX, 0b111111111111111 # instrumentation
AND word ptr [R14 + RDX], CX 
AND RSI, 0b111111111111111 # instrumentation
XOR byte ptr [R14 + RSI], DIL 
AND RSI, 0b111111111111111 # instrumentation
LOCK AND dword ptr [R14 + RSI], 86 
AND RSI, 0b111111111111111 # instrumentation
XOR RSI, qword ptr [R14 + RSI] 
JNB .bb_main.3 
JMP .bb_main.exit 
.bb_main.3:
AND CL, -37 # instrumentation
AND RCX, 0b111111111111111 # instrumentation
CMOVO CX, word ptr [R14 + RCX] 
AND RDI, 0b111111111111111 # instrumentation
OR qword ptr [R14 + RDI], RDX 
AND RSI, 0b111111111111111 # instrumentation
CMOVL EDI, dword ptr [R14 + RSI] 
AND RBX, 0b111111111111111 # instrumentation
OR word ptr [R14 + RBX], 0b1000000000000000 # instrumentation
BSR DX, word ptr [R14 + RBX] 
AND BL, -101 # instrumentation
AND RAX, 0b111111111111111 # instrumentation
CMOVNB AX, word ptr [R14 + RAX] 
AND RBX, 0b111111111111111 # instrumentation
OR CL, byte ptr [R14 + RBX] 
JMP .bb_main.4 
.bb_main.4:
AND RBX, 0b111111111111111 # instrumentation
OR word ptr [R14 + RBX], CX 
AND RAX, 0b111111111111111 # instrumentation
TEST dword ptr [R14 + RAX], ESI 
.bb_main.exit:
# mov r15, rax
# mov r15, rbx
# mov r15, rcx
# mov r15, rdx
# mov r15, rsi
# mov r15, rdi
# mov r15, rbp
# mov r15, rsp
# mov r15, r8
# mov r15, r9
# mov r15, r10
# mov r15, r11
# mov r15, r12
# mov r15, r13
# mov r15, r14
# mov r15, r15
# mov r15, 0 # Unused by executor

.test_case_exit:
MFENCE # instrumentation
LEA R14, [R14 - 60] # instrumentation

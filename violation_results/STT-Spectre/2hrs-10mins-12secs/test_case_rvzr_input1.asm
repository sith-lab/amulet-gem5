.intel_syntax noprefix
LEA R14, [R14 + 60] # instrumentation
MFENCE # instrumentation
.test_case_enter:
.function_main:
.bb_main.entry:
JMP .bb_main.0 
.bb_main.0:
AND RAX, 0b111111111111 # instrumentation
XOR DI, word ptr [R14 + RAX] 
AND RDI, 0b111111111111 # instrumentation
CMOVNP CX, word ptr [R14 + RDI] 
AND RSI, 0b111111111111 # instrumentation
AND dword ptr [R14 + RSI], -3 
AND RBX, 0b111111111111 # instrumentation
OR qword ptr [R14 + RBX], RBX 
AND RBX, 0b111111111111 # instrumentation
XOR SI, word ptr [R14 + RBX] 
AND RAX, 0b111111111111 # instrumentation
OR qword ptr [R14 + RAX], -13 
JO .bb_main.1 
JMP .bb_main.2 
.bb_main.1:
AND BL, 58 # instrumentation
JS .bb_main.2 
JMP .bb_main.3 
.bb_main.2:
AND RDI, 0b111111111111 # instrumentation
XOR DIL, byte ptr [R14 + RDI] 
AND RSI, 0b111111111111 # instrumentation
CMOVNB BX, word ptr [R14 + RSI] 
AND RDX, 0b111111111111 # instrumentation
AND AL, byte ptr [R14 + RDX] 
JNBE .bb_main.3 
JMP .bb_main.4 
.bb_main.3:
AND RSI, 0b111111111111 # instrumentation
TEST dword ptr [R14 + RSI], 916525886 
AND RSI, 0b111111111111 # instrumentation
LOCK OR word ptr [R14 + RSI], -19 
AND RSI, 0b111111111111 # instrumentation
AND qword ptr [R14 + RSI], RAX 
AND RSI, 0b111111111111 # instrumentation
OR qword ptr [R14 + RSI], -52 
JMP .bb_main.4 
.bb_main.4:
AND CL, 121 # instrumentation
AND RDX, 0b111111111111 # instrumentation
CMOVLE RSI, qword ptr [R14 + RDX] 
AND RBX, 0b111111111111 # instrumentation
OR byte ptr [R14 + RBX], CL 
AND RDI, 0b111111111111 # instrumentation
CMOVNS ESI, dword ptr [R14 + RDI] 
.bb_main.exit:
.test_case_exit:
MFENCE # instrumentation
LEA R14, [R14 - 60] # instrumentation

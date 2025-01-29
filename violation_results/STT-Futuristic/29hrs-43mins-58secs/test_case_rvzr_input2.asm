.intel_syntax noprefix
LEA R14, [R14 + 60] # instrumentation
MFENCE # instrumentation
.test_case_enter:
.function_main:
.bb_main.entry:
JMP .bb_main.0 
.bb_main.0:
AND AL, -123 # instrumentation
AND RDI, 0b111111111111111111111 # instrumentation
CMOVB RDI, qword ptr [R14 + RDI] 
AND RAX, 0b111111111111111111111 # instrumentation
CMOVNL RAX, qword ptr [R14 + RAX] 
AND RDI, 0b111111111111111111111 # instrumentation
LOCK AND byte ptr [R14 + RDI], -32 
AND RAX, 0b111111111111111111111 # instrumentation
CMOVL SI, word ptr [R14 + RAX] 
JBE .bb_main.1 
JMP .bb_main.2 
.bb_main.1:
AND BL, 56 # instrumentation
AND RCX, 0b111111111111111111111 # instrumentation
CMOVNL DX, word ptr [R14 + RCX] 
JMP .bb_main.2 
.bb_main.2:
AND RBX, 0b111111111111111111111 # instrumentation
OR qword ptr [R14 + RBX], 0b1000000000000000000000000000000 # instrumentation
BSR RDI, qword ptr [R14 + RBX] 
AND RAX, 0b111111111111111111111 # instrumentation
XOR word ptr [R14 + RAX], -23 
AND RSI, 0b111111111111111111111 # instrumentation
TEST qword ptr [R14 + RSI], RSI 
AND RSI, 0b111111111111111111111 # instrumentation
OR word ptr [R14 + RSI], 64 
JS .bb_main.3 
JMP .bb_main.exit 
.bb_main.3:
AND RDI, 0b111111111111111111111 # instrumentation
TEST byte ptr [R14 + RDI], AL 
AND RSI, 0b111111111111111111111 # instrumentation
LOCK XOR byte ptr [R14 + RSI], BL 
AND RDI, 0b111111111111111111111 # instrumentation
LOCK OR byte ptr [R14 + RDI], AL 
AND RCX, 0b111111111111111111111 # instrumentation
CMOVNS EDI, dword ptr [R14 + RCX] 
JMP .bb_main.4 
.bb_main.4:
AND AL, -72 # instrumentation
AND RDX, 0b111111111111111111111 # instrumentation
CMOVBE RAX, qword ptr [R14 + RDX] 
AND RBX, 0b111111111111111111111 # instrumentation
CMOVLE BX, word ptr [R14 + RBX] 
AND RAX, 0b111111111111111111111 # instrumentation
AND byte ptr [R14 + RAX], AL 
.bb_main.exit:
.test_case_exit:
MFENCE # instrumentation
LEA R14, [R14 - 60] # instrumentation

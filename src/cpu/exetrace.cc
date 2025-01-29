/*
 * Copyright (c) 2001-2005 The Regents of The University of Michigan
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met: redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer;
 * redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution;
 * neither the name of the copyright holders nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Authors: Steve Reinhardt
 *          Lisa Hsu
 *          Nathan Binkert
 *          Steve Raasch
 */

#include "cpu/exetrace.hh"

#include <iomanip>

#include "arch/isa_traits.hh"
#include "arch/utility.hh"
#include "base/loader/symtab.hh"
#include "config/the_isa.hh"
#include "cpu/base.hh"
#include "cpu/static_inst.hh"
#include "cpu/thread_context.hh"
#include "debug/ExecAll.hh"
#include "debug/ExecX86Regs.hh"
#include "enums/OpClass.hh"
#include "cpu/o3/deriv.hh"

using namespace std;
using namespace TheISA;

namespace Trace {

void
ExeTracerRecord::dumpTicks(ostream &outs)
{
    ccprintf(outs, "%7d: ", when);
}

void
Trace::ExeTracerRecord::traceInst(const StaticInstPtr &inst, bool ran)
{
    ostream &outs = Trace::output();

    if (!Debug::ExecUser || !Debug::ExecKernel) {
        bool in_user_mode = TheISA::inUserMode(thread);
        if (in_user_mode && !Debug::ExecUser) return;
        if (!in_user_mode && !Debug::ExecKernel) return;
    }

    if (Debug::ExecTicks)
        dumpTicks(outs);

    outs << thread->getCpuPtr()->name() << " ";

    if (Debug::ExecAsid)
        outs << "A" << dec << TheISA::getExecutingAsid(thread) << " ";

    if (Debug::ExecThread)
        outs << "T" << thread->threadId() << " : ";

    std::string sym_str;
    Addr sym_addr;
    Addr cur_pc = pc.instAddr();
    if (debugSymbolTable && Debug::ExecSymbol &&
            (!FullSystem || !inUserMode(thread)) &&
            debugSymbolTable->findNearestSymbol(cur_pc, sym_str, sym_addr)) {
        if (cur_pc != sym_addr)
            sym_str += csprintf("+%d",cur_pc - sym_addr);
        outs << "@" << sym_str;
    } else {
        outs << "0x" << hex << cur_pc;
    }

    if (inst->isMicroop()) {
        outs << "." << setw(2) << dec << pc.microPC();
    } else {
        outs << "   ";
    }

    outs << " : ";

    //
    //  Print decoded instruction
    //

    outs << setw(26) << left;
    outs << inst->disassemble(cur_pc, debugSymbolTable);

    if (ran) {
        outs << " : ";

        if (Debug::ExecOpClass) {
            outs << Enums::OpClassStrings[inst->opClass()] << " : ";
        }

        if (Debug::ExecResult && !predicate) {
            outs << "Predicated False";
        }

        if (Debug::ExecResult && data_status != DataInvalid) {
            ccprintf(outs, " D=%#018x", data.as_int);
        }

        if (Debug::ExecEffAddr && getMemValid())
            outs << " A=0x" << hex << addr;

        if (Debug::ExecFetchSeq && fetch_seq_valid)
            outs << "  FetchSeq=" << dec << fetch_seq;

        if (Debug::ExecCPSeq && cp_seq_valid)
            outs << "  CPSeq=" << dec << cp_seq;

        if (Debug::ExecFlags) {
            outs << "  flags=(";
            inst->printFlags(outs, "|");
            outs << ")";
        }
    }


    //
    //  End of line...
    //
    outs << endl;
    DerivO3CPU *dcpu = dynamic_cast<DerivO3CPU *>(thread->getCpuPtr());
    if (DTRACE(ExecX86Regs) && dcpu) {
        outs << std::hex << std::showbase
            << " rax=" << dcpu->readArchIntReg(X86ISA::INTREG_RAX, 0)
            << " rbx=" << dcpu->readArchIntReg(X86ISA::INTREG_RBX, 0)
            << " rcx=" << dcpu->readArchIntReg(X86ISA::INTREG_RCX, 0)
            << " rdx=" << dcpu->readArchIntReg(X86ISA::INTREG_RDX, 0)
            << " rsp=" << dcpu->readArchIntReg(X86ISA::INTREG_RSP, 0)
            << " rbp=" << dcpu->readArchIntReg(X86ISA::INTREG_RBP, 0)
            << " rsi=" << dcpu->readArchIntReg(X86ISA::INTREG_RSI, 0)
            << " rdi=" << dcpu->readArchIntReg(X86ISA::INTREG_RDI, 0)
            << " r8="  << dcpu->readArchIntReg(X86ISA::INTREG_R8, 0)
            << " r9="  << dcpu->readArchIntReg(X86ISA::INTREG_R9, 0)
            << " r10="  << dcpu->readArchIntReg(X86ISA::INTREG_R10, 0)
            << " r11="  << dcpu->readArchIntReg(X86ISA::INTREG_R11, 0)
            << " r12="  << dcpu->readArchIntReg(X86ISA::INTREG_R12, 0)
            << " r13="  << dcpu->readArchIntReg(X86ISA::INTREG_R13, 0)
            << " r14="  << dcpu->readArchIntReg(X86ISA::INTREG_R14, 0)
            << " r15="  << dcpu->readArchIntReg(X86ISA::INTREG_R15, 0)
            << endl;
    }
}

void
Trace::ExeTracerRecord::dump()
{
    /*
     * The behavior this check tries to achieve is that if ExecMacro is on,
     * the macroop will be printed. If it's on and microops are also on, it's
     * printed before the microops start printing to give context. If the
     * microops aren't printed, then it's printed only when the final microop
     * finishes. Macroops then behave like regular instructions and don't
     * complete/print when they fault.
     */
    if (Debug::ExecMacro && staticInst->isMicroop() &&
        ((Debug::ExecMicro &&
            macroStaticInst && staticInst->isFirstMicroop()) ||
            (!Debug::ExecMicro &&
             macroStaticInst && staticInst->isLastMicroop()))) {
        traceInst(macroStaticInst, false);
    }
    if (Debug::ExecMicro || !staticInst->isMicroop()) {
        traceInst(staticInst, true);
    }
}

} // namespace Trace

////////////////////////////////////////////////////////////////////////
//
//  ExeTracer Simulation Object
//
Trace::ExeTracer *
ExeTracerParams::create()
{
    return new Trace::ExeTracer(this);
}

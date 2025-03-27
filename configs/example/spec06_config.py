# Copyright (c) 2012-2013 ARM Limited
# All rights reserved.
#
# The license below extends only to copyright in the software and shall
# not be construed as granting a license to any other intellectual
# property including but not limited to intellectual property relating
# to a hardware implementation of the functionality of the software
# licensed hereunder.  You may use the software subject to the license
# terms below provided that you ensure that this notice is replicated
# unmodified and in its entirety in all distributions of the software,
# modified or unmodified, in source code or in binary form.
#
# Copyright (c) 2006-2008 The Regents of The University of Michigan
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer;
# redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution;
# neither the name of the copyright holders nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Authors: Steve Reinhardt

# Simple test script
#
# "m5 test.py"

import argparse
import sys
import os

import m5
from m5.defines import buildEnv
from m5.objects import *
from m5.util import addToPath, fatal, warn

addToPath('../')

from ruby import Ruby

from common import Options
from common import Simulation
from common import CacheConfig
from common import CpuConfig
from common import MemConfig
from common.Caches import *
from common.cpu2000 import *

import spec06_benchmarks

# Check if KVM support has been enabled, we might need to do VM
# configuration if that's the case.
have_kvm_support = 'BaseKvmCPU' in globals()
def is_kvm_cpu(cpu_class):
    return have_kvm_support and cpu_class != None and \
        issubclass(cpu_class, BaseKvmCPU)


parser = argparse.ArgumentParser()
Options.addCommonOptions(parser)
Options.addSEOptions(parser)

parser.add_argument("-b", "--benchmark", type=str, required=True, help="The SPEC benchmark to be loaded.")
parser.add_argument("--benchmark_stdout", type=str, required=True, help="Absolute path for stdout redirection for the benchmark.")
parser.add_argument("--benchmark_stderr", type=str, required=True, help="Absolute path for stderr redirection for the benchmark.")
parser.add_argument("--fastmem", action="store_true", help="Use fastmem mode with atomic CPU.")

args = parser.parse_args()

assert not args.fastmem, "Fastmem mode is not supported in this script."
numThreads = 1

if args.benchmark:
    print('Selected SPEC_CPU2006 benchmark')
    if args.benchmark == 'perlbench':
        print('--> perlbench')
        process = spec06_benchmarks.perlbench
    elif args.benchmark == 'bzip2':
        print('--> bzip2')
        process = spec06_benchmarks.bzip2
    elif args.benchmark == 'gcc':
        print('--> gcc')
        process = spec06_benchmarks.gcc
    elif args.benchmark == 'bwaves':
        print('--> bwaves')
        process = spec06_benchmarks.bwaves
    elif args.benchmark == 'gamess':
        print('--> gamess')
        process = spec06_benchmarks.gamess
    elif args.benchmark == 'mcf':
        print('--> mcf')
        process = spec06_benchmarks.mcf
    elif args.benchmark == 'milc':
        print('--> milc')
        process = spec06_benchmarks.milc
    elif args.benchmark == 'zeusmp':
        print('--> zeusmp')
        process = spec06_benchmarks.zeusmp
    elif args.benchmark == 'gromacs':
        print('--> gromacs')
        process = spec06_benchmarks.gromacs
    elif args.benchmark == 'cactusADM':
        print('--> cactusADM')
        process = spec06_benchmarks.cactusADM
    elif args.benchmark == 'leslie3d':
        print('--> leslie3d')
        process = spec06_benchmarks.leslie3d
    elif args.benchmark == 'namd':
        print('--> namd')
        process = spec06_benchmarks.namd
    elif args.benchmark == 'gobmk':
        print('--> gobmk')
        process = spec06_benchmarks.gobmk
    elif args.benchmark == 'dealII':
        print('--> dealII')
        process = spec06_benchmarks.dealII
    elif args.benchmark == 'soplex':
        print('--> soplex')
        process = spec06_benchmarks.soplex
    elif args.benchmark == 'povray':
        print('--> povray')
        process = spec06_benchmarks.povray
    elif args.benchmark == 'calculix':
        print('--> calculix')
        process = spec06_benchmarks.calculix
    elif args.benchmark == 'hmmer':
        print('--> hmmer')
        process = spec06_benchmarks.hmmer
    elif args.benchmark == 'sjeng':
        print('--> sjeng')
        process = spec06_benchmarks.sjeng
    elif args.benchmark == 'GemsFDTD':
        print('--> GemsFDTD')
        process = spec06_benchmarks.GemsFDTD
    elif args.benchmark == 'libquantum':
        print('--> libquantum')
        process = spec06_benchmarks.libquantum
    elif args.benchmark == 'h264ref':
        print('--> h264ref')
        process = spec06_benchmarks.h264ref
    elif args.benchmark == 'tonto':
        print('--> tonto')
        process = spec06_benchmarks.tonto
    elif args.benchmark == 'lbm':
        print('--> lbm')
        process = spec06_benchmarks.lbm
    elif args.benchmark == 'omnetpp':
        print('--> omnetpp')
        process = spec06_benchmarks.omnetpp
    elif args.benchmark == 'astar':
        print('--> astar')
        process = spec06_benchmarks.astar
    elif args.benchmark == 'wrf':
        print('--> wrf')
        process = spec06_benchmarks.wrf
    elif args.benchmark == 'sphinx3':
        print('--> sphinx3')
        process = spec06_benchmarks.sphinx3
    elif args.benchmark == 'xalancbmk':
        print('--> xalancbmk')
        process = spec06_benchmarks.xalancbmk
    elif args.benchmark == 'specrand_i':
        print('--> specrand_i')
        process = spec06_benchmarks.specrand_i
    elif args.benchmark == 'specrand_f':
        print('--> specrand_f')
        process = spec06_benchmarks.specrand_f
    else:
        print ("No recognized SPEC2006 benchmark selected! Exiting.")
        sys.exit(1)
else:
    print >> sys.stderr, "Need --benchmark switch to specify SPEC CPU2006 workload. Exiting!\n"
    sys.exit(1)

# Set process stdout/stderr
if args.benchmark_stdout:
    process.output = args.benchmark_stdout
    print("Process stdout file: " + process.output)
if args.benchmark_stderr:
    process.errout = args.benchmark_stderr
    print("Process stderr file: " + process.errout)


(CPUClass, test_mem_mode, FutureClass) = Simulation.setCPUClass(args)
CPUClass.numThreads = numThreads

# Check -- do not allow SMT with multiple CPUs
if args.smt and args.num_cpus > 1:
    fatal("You cannot use SMT with multiple CPUs!")

np = args.num_cpus
system = System(cpu = [CPUClass(cpu_id=i) for i in range(np)],
                mem_mode = test_mem_mode,
                mem_ranges = [AddrRange(args.mem_size)],
                cache_line_size = args.cacheline_size)

if numThreads > 1:
    system.multi_thread = True

# Create a top-level voltage domain
system.voltage_domain = VoltageDomain(voltage = args.sys_voltage)

# Create a source clock for the system and set the clock period
system.clk_domain = SrcClockDomain(clock =  args.sys_clock,
                                   voltage_domain = system.voltage_domain)

# Create a CPU voltage domain
system.cpu_voltage_domain = VoltageDomain()

# Create a separate clock domain for the CPUs
system.cpu_clk_domain = SrcClockDomain(clock = args.cpu_clock,
                                       voltage_domain =
                                       system.cpu_voltage_domain)

# If elastic tracing is enabled, then configure the cpu and attach the elastic
# trace probe
if args.elastic_trace_en:
    CpuConfig.config_etrace(CPUClass, system.cpu, args)

# All cpus belong to a common cpu_clk_domain, therefore running at a common
# frequency.
for cpu in system.cpu:
    cpu.clk_domain = system.cpu_clk_domain

if is_kvm_cpu(CPUClass) or is_kvm_cpu(FutureClass):
    if buildEnv['TARGET_ISA'] == 'x86':
        system.kvm_vm = KvmVM()
        for process in multiprocesses:
            process.useArchPT = True
            process.kvmInSE = True
    else:
        fatal("KvmCPU can only be used in SE mode with x86")

# Sanity check
if args.fastmem:
    if CPUClass != AtomicSimpleCPU:
        fatal("Fastmem can only be used with atomic CPU!")
    if (args.caches or args.l2cache):
        fatal("You cannot use fastmem in combination with caches!")

if args.simpoint_profile:
    if not args.fastmem:
        # Atomic CPU checked with fastmem option already
        fatal("SimPoint generation should be done with atomic cpu and fastmem")
    if np > 1:
        fatal("SimPoint generation not supported with more than one CPUs")

for i in range(np):
    system.cpu[i].workload = process
    print(f'Process is: {process.cmd}')

    #if args.smt:
    #    system.cpu[i].workload = multiprocesses
    #elif len(multiprocesses) == 1:
    #    system.cpu[i].workload = multiprocesses[0]
    #else:
    #    system.cpu[i].workload = multiprocesses[i]

    if args.fastmem:
        system.cpu[i].fastmem = True

    if args.simpoint_profile:
        system.cpu[i].addSimPointProbe(args.simpoint_interval)

    if args.checker:
        system.cpu[i].addCheckerCpu()

    system.cpu[i].createThreads()

if args.ruby:
    assert False, "Ruby is not supported in this script."
else:
    MemClass = Simulation.setMemClass(args)
    system.membus = SystemXBar()
    system.system_port = system.membus.cpu_side_ports
    CacheConfig.config_cache(args, system)
    MemConfig.config_mem(args, system)

# [InvisiSpec] Configure simulation scheme
if CPUClass == DerivO3CPU:
    CpuConfig.config_scheme(CPUClass, system.cpu, args)

root = Root(full_system = False, system = system)
Simulation.run(args, root, system, FutureClass)

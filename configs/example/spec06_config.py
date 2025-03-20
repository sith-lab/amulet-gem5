import argparse
import sys
import os

import m5
from m5.defines import buildEnv
from m5.objects import *
from m5.util import addToPath, fatal

addToPath('../')

from ruby import Ruby
from common import Options, Simulation, CacheConfig, CpuConfig, MemConfig
import spec06_benchmarks


def select_spec06_benchmark(benchmark_name):
    benchmark_map = {name: getattr(spec06_benchmarks, name)
                     for name in dir(spec06_benchmarks)
                     if not name.startswith('__')}

    if benchmark_name in benchmark_map:
        print(f"--> {benchmark_name}")
        return benchmark_map[benchmark_name]

    fatal("No recognized SPEC2006 benchmark selected! Exiting.")


def parse_args():
    parser = argparse.ArgumentParser()
    Options.addCommonOptions(parser)
    Options.addSEOptions(parser)

    parser.add_argument("-b", "--benchmark", required=True, help="The SPEC benchmark to load.")
    parser.add_argument("--benchmark_stdout", help="Path for benchmark stdout redirection.")
    parser.add_argument("--benchmark_stderr", help="Path for benchmark stderr redirection.")
    parser.add_argument("--fastmem", action="store_true", help="Use fastmem mode with atomic CPU.")

    if '--ruby' in sys.argv:
        Ruby.define_options(parser)

    return parser.parse_args()


def configure_system(options, process):
    CPUClass, test_mem_mode, FutureClass = Simulation.setCPUClass(options)

    if options.smt and options.num_cpus > 1:
        fatal("SMT mode cannot be used with multiple CPUs!")

    system = System(
        cpu=[CPUClass(cpu_id=i) for i in range(options.num_cpus)],
        mem_mode=test_mem_mode,
        mem_ranges=[AddrRange(options.mem_size)],
        cache_line_size=options.cacheline_size,
        voltage_domain=VoltageDomain(voltage=options.sys_voltage),
        clk_domain=SrcClockDomain(
            clock=options.sys_clock,
            voltage_domain=VoltageDomain(voltage=options.sys_voltage)
        )
    )

    cpu_clk_domain = SrcClockDomain(
        clock=options.cpu_clock,
        voltage_domain=VoltageDomain()
    )

    for cpu in system.cpu:
        cpu.clk_domain = cpu_clk_domain
        cpu.workload = process

        if options.fastmem:
            cpu.fastmem = True

        cpu.createThreads()

    if options.ruby:
        Ruby.create_system(options, False, system)
        assert options.num_cpus == len(system.ruby._cpu_ports)

        system.ruby.clk_domain = SrcClockDomain(
            clock=options.ruby_clock,
            voltage_domain=system.voltage_domain
        )

        for i, cpu in enumerate(system.cpu):
            ruby_port = system.ruby._cpu_ports[i]
            cpu.createInterruptController()
            cpu.icache_port = ruby_port.slave
            cpu.dcache_port = ruby_port.slave

            if buildEnv['TARGET_ISA'] == 'x86':
                cpu.interrupts[0].pio = ruby_port.master
                cpu.interrupts[0].int_master = ruby_port.slave
                cpu.interrupts[0].int_slave = ruby_port.master
                cpu.itb.walker.port = ruby_port.slave
                cpu.dtb.walker.port = ruby_port.slave
    else:
        system.membus = SystemXBar()
        system.system_port = system.membus.cpu_side_ports
        CacheConfig.config_cache(options, system)
        MemConfig.config_mem(options, system)

    if CPUClass == DerivO3CPU:
        CpuConfig.config_scheme(CPUClass, system.cpu, options)

    return system, FutureClass


def main():
    options = parse_args()

    process = select_spec06_benchmark(options.benchmark)

    if options.benchmark_stdout:
        process.output = options.benchmark_stdout
        print("Process stdout file: " + process.output)

    if options.benchmark_stderr:
        process.errout = options.benchmark_stderr
        print("Process stderr file: " + process.errout)

    system, FutureClass = configure_system(options, process)
    root = Root(full_system=False, system=system)

    Simulation.run(options, root, system, FutureClass)


if __name__ == '__main__':
    main()

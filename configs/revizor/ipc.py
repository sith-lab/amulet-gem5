from __future__ import print_function

import m5
from m5.objects import *
from m5.util import *
from m5 import stats

import os
import sys
import subprocess
import time

addToPath('../example')

configs_revizor_path = os.path.dirname(os.path.abspath(__file__))
configs_path = os.path.dirname(configs_revizor_path)
gem5_path = os.path.dirname(configs_path)
assembly_path = configs_revizor_path + "/ipc_base_x86.s"
object_path = gem5_path + "/build/X86/revizor_ipc_base.o"
exec_path = object_path[:object_path.rindex(".o")] + ".out"
if '--socket' in sys.argv:
    index = sys.argv.index('--socket')
    sys.argv.pop(index)
    socket_name = sys.argv.pop(index)
else:
    print('Please provide name of socket for communication with Revizor (--socket <NAME>)')
    exit(1)

sys.argv.extend(["-c", exec_path])
# need backing store for ruby
if "--ruby" in sys.argv:
   sys.argv.append("--access-backing-store")

def is_newer(file1, file2, help_if_file1_doesnt_exist=""):
    try:
        t1 = os.path.getmtime(file1)
    except:
        raise KeyError(
            """expected {} to exist but it doesn't
            {}""".format(file1, help_if_file1_doesnt_exist)
        )
    try:
        t2 = os.path.getmtime(file2)
    except:
        return True
    return t1 > t2

def print_and_run(*cmd):
    def format_arg(arg):
        if any("\\#\"' ".count(c) for c in arg):
            return repr(arg)
        else:
            return arg
    print(' '.join(format_arg(arg) for arg in cmd))
    retcode = subprocess.call(cmd)
    if retcode != 0:
        print('failed with error code', retcode)
        exit(retcode)

if is_newer(assembly_path, object_path):
    # assemble base file
    print('assembling', object_path, '...')
    print_and_run('as', assembly_path, '-o', object_path)
if is_newer(object_path, exec_path):
    print('linking', exec_path, '...')
    print_and_run('ld', object_path, '-o', exec_path)

import se
from se import system, root, args, Simulation

assert se.np == 1, "can't run revizor on more than 1 cpu..."
system.ipc = RevizorIPC(cpu = system.cpu[0],
    dcache = system.cpu[0].dcache,
    icache = system.cpu[0].icache,
    l2cache = system.l2,
    dram = system.mem_ctrls[0].dram,
    process = se.multiprocesses[0],
    executable_path = exec_path,
    # ruby = system.ruby if args.ruby else NULL,
    socket_name = socket_name)

if __name__ == "__m5_main__":
    max_ticks = args.rel_max_tick
    m5.instantiate()
    cptdir = args.checkpoint_dir
    exit_event = m5.simulate(max_ticks, dump_stats=args.dump_stats) # first run to set things up
    print('Exiting @ tick %i because %s' % (m5.curTick(), exit_event.getCause()))
    while system.ipc.prepareNext():
        if args.profile: simulate_start = time.time()
        exit_event = m5.simulate(max_ticks, dump_stats=args.dump_stats)
        if args.profile:
            print('SIMULATION TIME:', time.time() - simulate_start)

        print('Exiting @ tick %i because %s' % (m5.curTick(), exit_event.getCause()))
        if args.checkpoint_at_end:
            m5.checkpoint(os.path.join(cptdir, "cpt.%d"), micro_state=args.save_micro_state, ignore_caches=args.dump_caches)
        if args.dump_caches:
            m5.dumpCaches(os.path.join(cptdir, "tags.%d"))
        if args.dump_stats:
            stats.dump()
        # important! don't change this because revizor uses this to detect when the stdout of one
        # run ends and the next one begins
        print('--- RESET ---')
        sys.stdout.flush()

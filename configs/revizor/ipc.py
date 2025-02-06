from __future__ import print_function

import m5
from m5.objects import *
from m5.util import *
from m5 import stats

import os
import sys
import subprocess
import time
import base64

addToPath('../example')

def parse_size_as_bytes(size):
    ''' converts a human-readable size (e.g. 10kB) to the number of bytes (e.g. 10240) '''
    if type(size) == int: return size
    if size.isdigit(): return int(size) # Return byte size if already in bytes
    size = size.lower()
    if size.endswith('kb'): return int(size[:-2]) << 10
    if size.endswith('mb'): return int(size[:-2]) << 20
    if size.endswith('gb'): return int(size[:-2]) << 30
    if size.endswith('tb'): return int(size[:-2]) << 40
    if size.endswith('b'): return int(size[:-1]) # Last case: assume bytes
    raise ValueError('unrecognized size format: {}'.format(size))

if '--sandbox-size' in sys.argv:
    index = sys.argv.index('--sandbox-size')
    sys.argv.pop(index)
    sandbox_size = parse_size_as_bytes(sys.argv.pop(index))
assert sandbox_size % 4096 == 0
sandbox_pages = sandbox_size // 4096

l1d_size = None
l1d_assoc = None
for arg in sys.argv:
    if arg.startswith('--l1d_size='):
        l1d_size = parse_size_as_bytes(arg[len('--l1d_size='):])
    if arg.startswith('--l1d_assoc='):
        l1d_assoc = parse_size_as_bytes(arg[len('--l1d_assoc='):])
if l1d_size is None: raise ValueError("Couldn't find --l1d_size=... argument")
if l1d_assoc is None: raise ValueError("Couldn't find --l1d_assoc=... argument")


configs_revizor_path = os.path.dirname(os.path.abspath(__file__))
configs_path = os.path.dirname(configs_revizor_path)
gem5_path = os.path.dirname(configs_path)
assembly_path = configs_revizor_path + "/ipc_base_x86.s"
object_path = gem5_path + "/build/X86/revizor_ipc_base_{}way_{}B_l1d_{}page_sandbox.o".format(l1d_assoc, l1d_size, sandbox_pages)
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

import se
from se import system, options, root, Simulation

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

def random_filename():
    return gem5_path + '/build/X86/' + base64.b64encode(os.urandom(32)).decode().replace('/','_').replace('+','_').replace('=','_')

if is_newer(assembly_path, object_path):
    # assemble base file
    print('assembling', object_path, '...')
    # first output to a temporary location then (atomically) rename it to prevent race condition
    temp = random_filename()
    print_and_run('as', assembly_path, '-o', temp, '--defsym', 'L1D_SIZE={}'.format(l1d_size),
        '--defsym', 'L1D_ASSOC={}'.format(l1d_assoc), '--defsym', 'SANDBOX_PAGES={}'.format(sandbox_pages))
    os.rename(temp, object_path)
if is_newer(object_path, exec_path):
    print('linking', exec_path, '...')
    temp = random_filename()
    print_and_run('ld', object_path, '-o', temp)
    os.rename(temp, exec_path)

print('Using executable', exec_path)

assert se.np == 1, "can't run revizor on more than 1 cpu..."
system.ipc = RevizorIPC(cpu = system.cpu[0],
    process = se.multiprocesses[0],
    executable_path = exec_path,
    ruby = system.ruby if options.ruby else NULL,
    socket_name = socket_name)

if __name__ == "__m5_main__":
    max_ticks = options.rel_max_tick
    m5.instantiate()
    cptdir = options.checkpoint_dir
    exit_event = m5.simulate(max_ticks, dump_stats=options.dump_stats) # first run to set things up
    print('Exiting @ tick %i because %s' % (m5.curTick(), exit_event.getCause()))
    while system.ipc.prepareNext():
        if options.profile: simulate_start = time.time()
        exit_event = m5.simulate(max_ticks, dump_stats=options.dump_stats)
        if options.profile:
            print('SIMULATION TIME:', time.time() - simulate_start)

        print('Exiting @ tick %i because %s' % (m5.curTick(), exit_event.getCause()))
        if options.checkpoint_at_end:
            m5.checkpoint(os.path.join(cptdir, "cpt.%d"), micro_state=options.save_micro_state, ignore_caches=options.dump_caches)
        if options.dump_caches:
            m5.dumpCaches(os.path.join(cptdir, "tags.%d"))
        if options.dump_stats:
            stats.dump()
        # important! don't change this because revizor uses this to detect when the stdout of one
        # run ends and the next one begins
        print('--- RESET ---')
        sys.stdout.flush()

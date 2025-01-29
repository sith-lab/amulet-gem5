from m5.params import *
from m5.SimObject import *

class RevizorIPC(SimObject):
    type = "RevizorIPC"
    cxx_header = "revizor_ipc/revizor_ipc.hh"
    cxx_class = "gem5::RevizorIPC"
    
    # Exposing C++ methods to Python (optional)
    cxx_exports = [PyBindMethod("prepareNext")]
    
    # Define parameters passed from the Python SimObject to the C++ SimObject
    cpu = Param.BaseCPU("The CPU object connected to RevizorIPC")
    dcache = Param.BaseCache("The data cache connected to RevizorIPC")
    icache = Param.BaseCache("The instruction cache connected to RevizorIPC")
    l2cache = Param.BaseCache("The L2 cache connected to RevizorIPC")
    dram = Param.AbstractMemory("DRAM")
    process = Param.Process("The process running in the simulation")
    executable_path = Param.String("Path to the executable file for RevizorIPC")
    socket_name = Param.String("Name of the UNIX abstract domain socket for communication with Revizor (excluding the initial null byte)")
    # ruby = Param.SubSystem("The Ruby memory system")


from m5.params import *
from m5.SimObject import *

class RevizorIPC(SimObject):
    type = "RevizorIPC"
    cxx_header = "revizor_ipc/revizor_ipc.hh"
    cxx_exports = [PyBindMethod("prepareNext")]
    cpu = Param.BaseCPU("CPU")
    process = Param.Process("Process")
    executable_path = Param.String("path to base executable")
    socket_name = Param.String("name of UNIX abstract domain socket for communication with Revizor (not including initial nul byte)")
    ruby = Param.RubySystem("ruby system")

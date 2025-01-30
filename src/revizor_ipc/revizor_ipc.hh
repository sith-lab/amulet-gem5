#ifndef REVIZOR_IPC_HH_
#define REVIZOR_IPC_HH_

#include "params/RevizorIPC.hh"
#include "sim/sim_object.hh"
#include <unordered_map>
typedef std::unordered_map<std::string, uint64_t> SymbolAddresses;

// #include "mem/ruby/system/RubySystem.hh"
#include "cpu/base.hh"
#include "cpu/o3/cpu.hh"
#include "sim/process.hh"
#include "mem/cache/base.hh"
#include "mem/abstract_mem.hh"
#include "mem/cache/base.hh"
#include "mem/xbar.hh"
#include "mem/page_table.hh"
#include "mem/simple_mem.hh"
#include "mem/xbar.hh" 

namespace gem5
{
  using namespace memory;

  class RevizorIPC : public SimObject
  {
    public:
      RevizorIPC(const RevizorIPCParams &p);
      ~RevizorIPC();
      void startup() override;
      bool prepareNext();
    private:
      void loadTestCase();
      void traceTestCase();
      void dumpRegisters(); // for debugging
      void recv(void *buf, size_t count);
      void send(const void *buf, size_t count);
      uint8_t *vaddrToHost(Addr addr);
      int sock = -1;
      BaseCPU *cpu = nullptr;
      BaseCache *l1dCache = nullptr;
      BaseCache *l1iCache = nullptr;
      BaseCache *l2Cache = nullptr;
      AbstractMemory *dram = nullptr;
      // RubySystem *ruby = nullptr;
      Process *process = nullptr;
      uint64_t inputHash = 0;
      bool tracingTestCase = false;
      SymbolAddresses addresses;
  };
} // namespace gem5

#endif // REVIZOR_IPC_HH_

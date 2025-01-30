#include "revizor_ipc/revizor_ipc.hh"

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <assert.h>

#include <cerrno>
#include <cinttypes>

#include "debug/RevizorIPC.hh"
#include "debug/RevizorIPCAddrs.hh"

#include "mem/cache/base.hh"
#include "sim/serialize.hh"
#include "arch/x86/regs/int.hh"

namespace gem5{

using namespace memory;
using namespace o3;

static constexpr uint64_t maxCodeSize = 512;

static constexpr uint64_t maxRegistersSize = 64;
static const uint64_t opInit = 0xd09e95bc2c73ad66;
static const uint64_t opAckInit = 0xc4f991d25774a0ac;
static const uint64_t opLoadTestCase = 0xf06e27858611c27a;
static const uint64_t opAckLoadTestCase = 0x847431e37076fb26;
static const uint64_t opTraceTestCase = 0x9ca711a73355bea;
static const uint64_t opAckTraceTestCase = 0xc1f8bc29862ef946;
static const uint64_t opResetLog = 0x7e310c4276780c9b;

// simple hash function that we implement both here and in revizor
// just to make sure data is being sent correctly.
static uint64_t hashBytes(const uint8_t *bytes, size_t count) {
    uint64_t hash = 0xbb7524eafb93804b;
    for (size_t i = 0; i < count; i++) {
        hash += bytes[i];
        hash *= 0x21f782547ea34f3d;
    }
    return hash;
}

void RevizorIPC::recv(void *buf, size_t size) {
    uint8_t *b = (uint8_t *)buf;
    size_t read = 0;
    while (read < size) {
        ssize_t count = ::read(sock, b + read, size - read);
        if (count > 0) {
            read += count;
        } else if (count == 0) {
            fatal("unexpected EOF from client\n");
        } else {
            fatal("error reading from client: %s\n",
                strerror(errno));
        }
    }
}

void RevizorIPC::send(const void *buf, size_t size) {
    const uint8_t *b = (const uint8_t *)buf;
    size_t written = 0;
    while (written < size) {
        ssize_t count = ::write(sock, b + written, size - written);
        if (count > 0) {
            written += count;
        } else {
            fatal("error writing to client: %s\n", strerror(errno));
        }
    }
}

#pragma GCC diagnostic push
// nothing will screw up horribly if fread fails...
//    and assuming the executable was created correctly it shouldn't
#pragma GCC diagnostic ignored "-Wunused-result"

static SymbolAddresses getSymbolAddresses(const char *executable_path) {
    FILE *fp = fopen(executable_path, "rb");
    if (!fp) {
        fatal("couldn't open executable %s: %s\n",
            executable_path, strerror(errno));
    }
    struct ElfHeader
    {
        uint8_t identifier[7];
        uint8_t osabi, abiversion;
        uint8_t pad[7];
        uint16_t type;
        uint16_t machine;
        uint32_t version;
        uint64_t entry;
        uint64_t phoff;
        uint64_t shoff;
        uint32_t flags;
        uint16_t ehsize;
        uint16_t phentsize;
        uint16_t phnum;
        uint16_t shentsize;
        uint16_t shnum;
        uint16_t shstrndx;
    };
    struct ElfSectionHeader
    {
        uint32_t name;
        uint32_t type;
        uint64_t flags;
        uint64_t addr;
        uint64_t offset;
        uint64_t size;
        uint32_t link;
        uint32_t info;
        uint64_t addralign;
        uint64_t entsize;
    };
    struct ElfSymbol
    {
        uint32_t name;
        unsigned char info;
        unsigned char other;
        uint16_t shndx;
        uint64_t value;
        uint64_t size;
    };
    static_assert(sizeof(ElfHeader) == 0x40);
    static_assert(sizeof(ElfSectionHeader) == 0x40);
    const uint8_t expected_identifier[7] = {
        0x7f, 'E', 'L', 'F',
        2, // 64-bit
        1, // little-endian
        1 // ELF version 1
    };
    ElfHeader header = {};
    fread(&header, 1, sizeof header, fp);
    if (memcmp(header.identifier,
        expected_identifier, sizeof header.identifier) != 0) {
        fatal("%s is not a 64-bit little endian ELF executable\n",
            executable_path);
    }
    uint32_t shstrndx = header.shstrndx;
    fseek(fp, (long)(shstrndx * header.shentsize + header.shoff), SEEK_SET);
    ElfSectionHeader shstrtab_header = {};
    fread(&shstrtab_header, sizeof shstrtab_header, 1, fp);
    uint64_t shstrtab_offset = shstrtab_header.offset;
    uint64_t symtab_offset = 0;
    uint64_t symtab_size = 0;
    std::vector<char> strtab;
    for (uint32_t sh = 0; sh < header.shnum; sh++) {
        fseek(fp, (long)(sh * header.shentsize + header.shoff), SEEK_SET);
        ElfSectionHeader section_header = {};
        fread(&section_header, sizeof section_header, 1, fp);
        char name[16] = {};
        fseek(fp, (long)(shstrtab_offset + section_header.name), SEEK_SET);
        for (int i = 0; i < sizeof name - 1; i++) {
            int c = getc(fp);
            if (c == 0 || c == EOF) break;
            name[i] = c;
        }
        if (strcmp(name, ".strtab") == 0) {
            strtab.resize(section_header.size, 0);
            fseek(fp, (long)section_header.offset, SEEK_SET);
            fread(&strtab[0], 1, section_header.size, fp);
        }
        if (strcmp(name, ".symtab") == 0) {
            symtab_offset = section_header.offset;
            symtab_size = section_header.size;
            assert(section_header.entsize == sizeof (ElfSymbol));
        }
    }

    fseek(fp, (long)symtab_offset, SEEK_SET);
    SymbolAddresses addresses = {};
    for (uint32_t i = 0; i < symtab_size / sizeof (ElfSymbol); i++) {
        ElfSymbol symbol = {};
        fread(&symbol, sizeof symbol, 1, fp);
        const char *name = &strtab.at(symbol.name);
        addresses[name] = symbol.value;
    }
    fclose(fp);
    const char *const required_symbols[] = {
        "code",
        "sandbox",
        "registers",

        NULL,
    };
    for (size_t i = 0; required_symbols[i]; i++) {
        if (addresses.count(required_symbols[i]) == 0) {
            fatal("%s does not define symbol `%s`\n",
                  executable_path, required_symbols[i]);
        }
    }
    return addresses;
}

#pragma GCC diagnostic pop

RevizorIPC::RevizorIPC(const RevizorIPCParams &params) :
    SimObject(params),
    cpu(params.cpu),
    l1dCache(params.dcache),
    l1iCache(params.icache),
    l2Cache(params.l2cache),
    dram(params.dram),
    // ruby(params.ruby),
    process(params.process),
    addresses(getSymbolAddresses(params.executable_path.c_str()))
{
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock == -1) {
        fatal("couldn't create socket: %s\n", strerror(errno));
    }
    struct sockaddr_un addr = {};
    addr.sun_family = AF_UNIX;
    const char *socket_name = params.socket_name.c_str();
    if (strlen(socket_name) + 1 > sizeof addr.sun_path) {
        fatal("socket path is too long.");
    }
    // first byte is left as 0 to indicate an abstract-domain socket
    memcpy(&addr.sun_path[1], socket_name, strlen(socket_name));
    if (connect(sock, (const struct sockaddr *)&addr,
             sizeof(sa_family_t) + 1 + strlen(socket_name)) == -1) {
        fatal("couldn't connect to server: %s\n", strerror(errno));
    }
    uint64_t init = 0;
    recv(&init, sizeof init);
    if (init != opInit) {
        fatal("client didn't send init operation: got %#" PRIx64 "\n", init);
    }
    DPRINTF(RevizorIPC, "Got command: init\n");
    const uint64_t ackInit[2] = {opAckInit, (uint64_t)getpid()};
    DPRINTF(RevizorIPC, "Send command: acknowledge init (pid = %" PRIu64 ")\n", ackInit[1]);
    send(ackInit, sizeof ackInit);
}


RevizorIPC::~RevizorIPC() {
    if (sock >= 0) {
        close(sock);
    }
}

void RevizorIPC::startup() {
// if (ruby) {
//     fatal("Ruby not supported on SpecLFB!");
//     dram = ruby->getPhysMem();
//     if (!dram) fatal("couldn't get physical memory from ruby\n");
// } else {

    // SimObject &data_object = cpu->getDataPort().getPeer().getOwner();
    // l1dCache = dynamic_cast<BaseCache *>(&data_object);
    // if (!l1dCache) fatal("expected L1D cache after CPU; got %s\n", data_object.name().c_str());

    // SimObject &inst_object = cpu->getInstPort().getPeer().getOwner();
    // l1iCache = dynamic_cast<BaseCache *>(&inst_object);
    // if (!l1iCache) fatal("expected L1I cache after CPU; got %s\n", inst_object.name().c_str());

    // SimObject &l2_xbar_object = l1dCache->getPort("mem_side").getPeer().getOwner();
    // BaseXBar *l2_xbar = dynamic_cast<BaseXBar *>(&l2_xbar_object);
    // if (!l2_xbar) fatal("expected L2 XBar after l1 cache; got %s\n", l2_xbar_object.name().c_str());

    // SimObject &l2_cache_object = l2_xbar->getPort("mem_side", 0).getPeer().getOwner();
    // l2Cache = dynamic_cast<BaseCache *>(&l2_cache_object);
    // if (!l2Cache) fatal("expected L2 cache after L2 XBar; got %s\n", l2_cache_object.name().c_str());

    // SimObject &mem_xbar_object = l2Cache->getPort("mem_side").getPeer().getOwner();
    // BaseXBar *mem_xbar = dynamic_cast<BaseXBar *>(&mem_xbar_object);
    // if (!mem_xbar) fatal("expected mem XBar after L2 cache; got %s\n", mem_xbar_object.name().c_str());

    // for (size_t i = 0; i < mem_xbar->memSidePortCount(); i++) {
    //     SimObject &dram_object = mem_xbar->getPort("mem_side", i).getPeer().getOwner();
    //     dram = dynamic_cast<AbstractMemory *>(&dram_object);
    //     if (dram) break;
    // }
    // if (!dram) fatal("expected DRAM after mem XBar but didn't find any\n");

// }
}

void RevizorIPC::loadTestCase() {
    uint64_t testCaseSize = 0;
    recv(&testCaseSize, sizeof testCaseSize);
    DPRINTF(RevizorIPC, "Got command: Load test case (size %llu)\n",
        (unsigned long long)testCaseSize);
    if (testCaseSize > maxCodeSize) {
        fatal("test case is too large: %" PRIu64 " bytes\n",
            testCaseSize);
    }
    uint8_t code[maxCodeSize];
    // fill unused portion of code with noops
    memset(code, 0x90, sizeof code);
    recv(code + maxCodeSize - testCaseSize, testCaseSize);
    const uint64_t hash = hashBytes(code + maxCodeSize - testCaseSize, testCaseSize);
    const uint64_t codeAddress = addresses.at("code");
    for (size_t i = 0; i < maxCodeSize; i++) {
        // performance could be improved here by doing just one vaddr->paddr translation
        // per page. but for now this is fine.
        *vaddrToHost(codeAddress + i) = code[i];
    }

    uint64_t response[] = {
        opAckLoadTestCase,
        hash
    };
    send(response, sizeof response);
}

uint8_t *RevizorIPC::vaddrToHost(Addr vaddr) {
    Addr paddr = 0;
    process->pTable->translate(vaddr, paddr);
    return dram->toHostAddr(paddr);
}

void RevizorIPC::traceTestCase() {
    // Write back all caches before running the test case
    l1dCache->memWriteback();
    l1iCache->memWriteback();
    l2Cache->memWriteback();

    // // Clear caches before next run
    // l1dCache->memInvalidate();
    // l1iCache->memInvalidate();
    // l2Cache->memInvalidate();

    uint64_t metadata[3] = {};
    recv(metadata, sizeof metadata);
    const uint64_t inputSize = metadata[0];
    const uint64_t registersStart = metadata[1];
    inputHash = metadata[2];
    DPRINTF(RevizorIPC,
        "Got command: trace test case input"
        "hash=%016llx size=%llu registers=%llu\n",
        (unsigned long long)inputHash,
        (unsigned long long)inputSize,
        (unsigned long long)registersStart);
    std::vector<uint8_t> input;
    input.resize(inputSize, 0);
    recv(&input[0], inputSize);
    assert(inputSize - registersStart <= maxRegistersSize);
    // Disable this for now since it is slowing us down.
    // assert(hashBytes(&input[0], inputSize) == inputHash);
    uint8_t *sandbox = vaddrToHost(addresses.at("sandbox"));
    uint8_t *registers = vaddrToHost(addresses.at("registers"));
    memcpy(sandbox, &input[0], registersStart);
    memset(registers, 0, maxRegistersSize);
    memcpy(registers, &input[registersStart], inputSize - registersStart);

    // Clear caches before next run
    l1dCache->memInvalidate();
    l1iCache->memInvalidate();
    l2Cache->memInvalidate();

    tracingTestCase = true;
}

void RevizorIPC::dumpRegisters() {
    CPU *dcpu = dynamic_cast<CPU *>(cpu);
    DPRINTF(RevizorIPC, "rax=%lx rbx=%lx rcx=%lx rdx=%lx "
        "rsp=%lx rbp=%lx rsi=%lx rdi=%lx "
        "r8=%lx r9=%lx r10=%lx r11=%lx r12=%lx r13=%lx r14=%lx r15=%lx\n",
        dcpu->getArchReg(X86ISA::int_reg::Rax, 0),
        dcpu->getArchReg(X86ISA::int_reg::Rbx, 0),
        dcpu->getArchReg(X86ISA::int_reg::Rcx, 0),
        dcpu->getArchReg(X86ISA::int_reg::Rdx, 0),
        dcpu->getArchReg(X86ISA::int_reg::Rsp, 0),
        dcpu->getArchReg(X86ISA::int_reg::Rbp, 0),
        dcpu->getArchReg(X86ISA::int_reg::Rsi, 0),
        dcpu->getArchReg(X86ISA::int_reg::Rdi, 0),
        dcpu->getArchReg(X86ISA::int_reg::R8, 0),
        dcpu->getArchReg(X86ISA::int_reg::R9, 0),
        dcpu->getArchReg(X86ISA::int_reg::R10, 0),
        dcpu->getArchReg(X86ISA::int_reg::R11, 0),
        dcpu->getArchReg(X86ISA::int_reg::R12, 0),
        dcpu->getArchReg(X86ISA::int_reg::R13, 0),
        dcpu->getArchReg(X86ISA::int_reg::R14, 0),
        dcpu->getArchReg(X86ISA::int_reg::R15, 0)
        );
}

bool RevizorIPC::prepareNext() {
    if (tracingTestCase) {
        if (debug::RevizorIPCAddrs) {
            DPRINTF(RevizorIPCAddrs, "--- start of memory mappings ---\n");
            for (auto p: addresses) {
                DPRINTF(RevizorIPCAddrs, "symbol %s => vaddr %llx\n", p.first.c_str(), p.second);
            }
            std::vector<std::pair<Addr, Addr>> mappings;
            process->pTable->getMappings(&mappings);
            for (auto p: mappings) {
                DPRINTF(RevizorIPCAddrs, "vaddr %llx => paddr %llx\n", p.first, p.second);
            }
            DPRINTF(RevizorIPCAddrs, "--- end of memory mappings ---\n");
        }
        // dumpRegisters();
        DPRINTF(RevizorIPC,
            "Finished running test case. Sending acknowledgement.\n");
        std::string cache_tags = Serializable::serializeAllCachesToString();
        uint64_t ack[] = {
            opAckTraceTestCase,
            inputHash,
            (uint64_t)cache_tags.length()
        };
        send(ack, sizeof ack);
        send(&cache_tags[0], cache_tags.length());
        tracingTestCase = false;
    }

    while (true) {
        uint64_t op = 0;
        recv(&op, sizeof op);
        if (op == opLoadTestCase) {
            loadTestCase();
        } else if (op == opTraceTestCase) {
            traceTestCase();
            return true;
        } else if (op == opResetLog) {
            trace::getDebugLogger()->reset();
        } else {
            fatal("unrecognized command from client: %#" PRIx64 "\n", op);
        }

    }
    return false;
}

// RevizorIPC *
// RevizorIPCParams::create() const
// {
//     RevizorIPC *revizor_ipc = new RevizorIPC(*this);
//     return revizor_ipc;
// }

} // namespace gem5

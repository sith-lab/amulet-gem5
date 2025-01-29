# Args: m5out_dir (e.g. $GEM5_DIR/m5out_testcase_$RUN_1_NAME)
#   Inputs: dCacheTrace_0.gz log.out
#   Outputs: trace_unfiltered.out trace_filtered.out; Placed into m5out dir

import os
import sys
from dataclasses import dataclass

import protolib
import packet_pb2 # Imports from script entrypoint dir, NOT cwd!

CACHELINE_SIZE: int = 64 # Bytes
WORKING_MEMORY_SIZE: int = 1024 * 1024
OVERFLOW_REGION_SIZE: int = 4096
FAULTY_REGION_SIZE: int = 4096
MAIN_REGION_SIZE: int = 4096
MAX_TICKS: int = 5000000

@dataclass
class TraceEntry:
    tick: int
    raw_cmd: int # ReadReq is 1 and WriteReq is 4 in src/mem/packet.hh command enum
    cmd: str # Relative
    raw_addr: int # Address within sandbox; Main - Lower Overflow for sandbox base addr. Aligned to CACHELINE_SIZE
    addr: int # Relative, Hex
    size: int
    pc: int # Hex
    sq: int

    def __hash__(self) -> int:
        return hash((self.pc, self.sq, self.tick, self.cmd, self.addr, self.size))

    def __str__(self) -> str:
        return f"TraceEntry [PC: {hex(self.pc)}, SQ: {self.sq}, Tick: {self.tick}, Cmd: {self.cmd}, Addr: {hex(self.addr)}, Size: {self.size}]"

def main():
  assert sys.argv[1] != "", "m5out directory path required"
  m5out_dir = sys.argv[1]
  if not os.path.isdir(m5out_dir):
    print(f"Curr working dir is: {os.getcwd()}")
    exit(f"parse_traces: Expected m5out directory {m5out_dir} not found!")
  print(f"Parsing traces for m5out directory: {m5out_dir}")
  
  # Retain old trace
  print("Making trace backup")
  trace_gz_path = os.path.join(m5out_dir, "dCacheTrace_0.gz")
  trace_backup_gz_path = os.path.join(m5out_dir, "dCacheTrace_0.gz" + ".temp") 
  os.system(f"cp {trace_gz_path} {trace_backup_gz_path}")

  # Parse raw traces
  trace_unfiltered_out_path = os.path.join(m5out_dir, "trace_unfiltered.out")
  unfiltered_count = parse_packets(trace_gz_path, trace_unfiltered_out_path)
  print(f"{unfiltered_count} packets total in unfiltered trace")
  
  # Squash filter
  log_path = os.path.join(m5out_dir, "log.out")
  squashed_insts = load_squash_filter(log_path)
  print(f"Found {len(squashed_insts)} insts. to squash filter")
  res = trace_squash_filter(squashed_insts, trace_gz_path)
  assert res # gzipped cache trace now clobbered with filtered trace
  print(f"Done squash filtering")

  # Parse again to extract filtered traces
  trace_filtered_out_path = os.path.join(m5out_dir, "trace_filtered.out")
  filtered_count = parse_packets(trace_gz_path, trace_filtered_out_path)
  print(f"{filtered_count} packets total in squash filtered trace")

  # Get old trace back
  os.system(f"mv -f {trace_backup_gz_path} {trace_gz_path}")
  print("Restored trace backup")

  print("Done parsing traces")
  return True

# InvisiSpec: Filter out squashed insts from the protobuf traceStream
def trace_squash_filter(squashed_insts: set, trace_gz_path):
  zipped_path = trace_gz_path
  if not os.path.isfile(zipped_path):
    exit(f"trace_squash_filter: Expected gzipped cache trace {zipped_path} not found!")

  dcache_packets, header = read_packets(zipped_path) # Will automatically gunzip
  os.remove(zipped_path) # Delete the file
  assert not os.path.exists(zipped_path)

  # ### Debug ###
  # print(f"\nSquashed insts:")
  # for entry in squashed_insts:
  #     print(f"PC: {hex(entry[0])}, SQ: {entry[1]}, Paddr: {hex(entry[2])}, Vaddr: {hex(entry[3])}")
  # print()
  # print("Before squash filtering:")
  # for i in range(len(dcache_packets)):
  #     print(f"Packet {i}: {dcache_packets[i]}")
  # print()
  # ### Debug ###

  safe_packets = [] # Unsquashed loads (including exposures)
  for packet in dcache_packets:
    relative_addr = packet.addr # Relative to model
    actual_addr = packet.raw_addr # Relative to gem5
    squashed = False

    for entry in squashed_insts:
      squashed_pc = entry[0]
      squashed_sq = entry[1]
      squashed_paddr = entry[2]
      # squashed_vaddr = entry[3] # Ungrabbed by packet, can't compare

      # Can solely match on SQ
      if (squashed_sq == packet.sq):
        # print(f" Inst. FILTERED - PC: {hex(packet.pc)}, SQ {packet.sq}, Addr: {hex(actual_addr)}") # Debug
        squashed = True
        break

    if not squashed:
      # print(f" Inst. PASSED filter - PC: {hex(packet.pc)}, SQ {packet.sq}, Addr: {hex(actual_addr)}") # Debug
      safe_packets.append(packet)
  
  unzipped_path = zipped_path[:-3]
  res = write_packets(safe_packets, header, unzipped_path)
  assert res, "trace_squash_filter: Packet write failed"

  # ### Debug ###
  # print()
  # print("After squash filtering:")
  # dcache_packets, header = read_packets(zipped_path)
  # for i in range(len(dcache_packets)):
  #     print(f"Packet {i}: {dcache_packets[i]}")
  # print()
  # ### Debug ###

  return True


def read_packets(path: str):
  # TODO: Protolib comes in gem5 distribution. Right now, we need to copy-paste the correct version into revizor. Can we do something better?
  # Generate packet_pb2.py in gem5 with "protoc -I=gem5/src/proto --python_out=gem5/src/proto gem5/src/packet.proto and copy into revizor/src
  import protolib
  import packet_pb2 # Make sure the proto definitions are up to date.
  import subprocess
  src_dir = os.path.dirname(os.path.realpath(__file__))
  subprocess.check_call(['make', '--quiet', '-C', src_dir, 'packet_pb2.py'])

  proto_in = protolib.openFileRd(path)

  # Read the magic number in 4-byte Little Endian
  magic_number = proto_in.read(4).decode()

  if magic_number != "gem5":
    print("Unrecognized file",path)
    exit(-1)

  ## Parsing packet header
  # Add the packet header
  header = packet_pb2.PacketHeader()
  protolib.decodeMessage(proto_in, header)

  ## Parsing packets
  packet = packet_pb2.Packet()
  packets = []
  # Decode the packet messages until we hit the end of the file
  while protolib.decodeMessage(proto_in, packet): 
    relative_addr = (packet.addr - OVERFLOW_REGION_SIZE) // CACHELINE_SIZE * CACHELINE_SIZE
    relative_cmd = 'r' if packet.cmd == 1 else ('w' if packet.cmd == 4 else 'u')
    curr_entry = TraceEntry(
      tick = packet.tick,
      raw_cmd = packet.cmd,
      cmd = relative_cmd,
      raw_addr = packet.addr,
      addr = relative_addr,
      size = packet.size,
      pc = packet.pc,
      sq = packet.sq
    )
    packets.append(curr_entry) 
      
  # We're done
  proto_in.close()
  return packets, header


def write_packets(packets, header, unzipped_path: str) -> bool:
  path = unzipped_path
  zipped_path = path + ".gz"
  if os.path.exists(zipped_path):
    print(f"Overwriting old file at {zipped_path}")
    os.remove(zipped_path)
  
  # TODO: Protolib comes in gem5 distribution. Right now, we need to copy-paste the correct version into revizor. Can we do something better?
  # Generate packet_pb2.py in gem5 with "protoc -I=gem5/src/proto --python_out=gem5/src/proto gem5/src/packet.proto and copy into revizor/src
  import protolib
  import packet_pb2 # Make sure the proto definitions are up to date.
  import subprocess
  src_dir = os.path.dirname(os.path.realpath(__file__))
  subprocess.check_call(['make', '--quiet', '-C', src_dir, 'packet_pb2.py'])
  
  proto_out = open(path, "wb")
  # Write in order: Magic number (gem5), packet header, packet(s)
  magic_number = "gem5".encode('utf-8')
  proto_out.write(magic_number)
  protolib.encodeMessage(proto_out, header)

  for entry in packets:
    assert(type(entry) == TraceEntry)
    proto_packet = packet_pb2.Packet()
    proto_packet.addr = entry.raw_addr
    proto_packet.pc = entry.pc
    proto_packet.sq = entry.sq
    proto_packet.tick = entry.tick
    proto_packet.cmd = entry.raw_cmd
    proto_packet.size = entry.size
    protolib.encodeMessage(proto_out, proto_packet)

  proto_out.close()

  result = subprocess.run(["gzip", path]) # Overwrite
  if (result.returncode != 0):
    exit(f"trace_squash_filter: Unable to gzip file {path}")
  # print(f'File {path} zipped to {zipped_path}') # Debug
  return True


# InvisiSpec: Using log.out 'Squashed' debug flag, return a set of squashed_insts (pc, paddr, vaddr)
# Get from actual run, for every run. Do not pre-populate!
def load_squash_filter(log_path):
  if not (os.path.isfile(log_path)):
      exit(f"Could not find log.out at {log_path}")
  log_file = open(log_path, "r")
  squashed_insts = set()

  curr_line = log_file.readline()
  while curr_line: # Do on-line as priming/debug log.out may be massive!
    target = "SQUASH FILTER - Squashing on load PC:"
    test_ind = curr_line.find(target)

    if (test_ind != -1): # If line is for squash filter
      # print(f"\nFound squash filter line: \n{curr_line}") # Debug
      pc_ind_start = test_ind + len(target)
      pc_ind_end = curr_line.find(',') # Always the first entry in line
      pc = int(curr_line[pc_ind_start:pc_ind_end], 16)

      # Sequence Number
      sq_ind_start = curr_line.find("SQ:") + len("SQ:") 
      sq_ind_end = curr_line.find(',', pc_ind_end+1)
      sq = int(curr_line[sq_ind_start:sq_ind_end])
      
      # Raw entries, (Paddr - OVERFLOW_REGION_SIZE) for Paddr relative to sandbox base
      paddr_ind_start = curr_line.find("Paddr:") + len("Paddr:") 
      paddr_ind_end = curr_line.find(',', sq_ind_end+1)
      paddr = int(curr_line[paddr_ind_start:paddr_ind_end], 16)
      
      # Currently unused
      vaddr_ind_start = curr_line.find("Vaddr:") + len("Vaddr:") 
      vaddr_ind_end = len(curr_line) # End of line
      vaddr = int(curr_line[vaddr_ind_start:vaddr_ind_end], 16)

      # print(f"Parsed values: PC: {hex(pc)}, SQ: {sq}, Paddr: {hex(paddr)}, Vaddr: {hex(vaddr)}") # Debug

      entry = (pc, sq, paddr, vaddr)
      squashed_insts.add(entry)
    curr_line = log_file.readline()

  log_file.close()
  return squashed_insts


def parse_packets(trace_gz_path, trace_out_path):
  path = trace_gz_path
  proto_in = protolib.openFileRd(path)
  if not (os.path.isfile(path)):
      exit(f"Could not find gzipped trace at {path}")
  trace_out = open(trace_out_path, "w")

  # Read the magic number in 4-byte Little Endian
  magic_number = proto_in.read(4).decode()
  if magic_number != "gem5":
      print("Unrecognized file",path)
      exit(-1)

  ## Parsing packet header
  header = packet_pb2.PacketHeader()
  protolib.decodeMessage(proto_in, header)

  ## Parsing packets
  packet = packet_pb2.Packet()
  count = 0
  # Decode the packet messages until we hit the end of the file
  while protolib.decodeMessage(proto_in, packet): 
    relative_addr = (packet.addr - OVERFLOW_REGION_SIZE) // CACHELINE_SIZE * CACHELINE_SIZE
    relative_cmd = 'r' if packet.cmd == 1 else ('w' if packet.cmd == 4 else 'u')
    curr_entry = TraceEntry( 
        tick = packet.tick,
        raw_cmd = packet.cmd,
        cmd = relative_cmd,
        raw_addr = packet.addr,
        addr = relative_addr,
        size = packet.size,
        pc = packet.pc,
        sq = packet.sq
    )
    
    trace_out.write(f"P{count}: {curr_entry}\n") # Showing actual packet info
    count += 1

  # We're done
  proto_in.close()
  trace_out.close()
  return count

main()
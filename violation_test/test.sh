#!/bin/bash
# Run gem5 with test binary

# Re-compile gem5:
#   export CORES=$(( `nproc --all` + 1));
#   python2.7 `which scons` -j$CORES --verbose build/X86/gem5.opt --default=X86 PROTOCOL=MESI_Two_Level

export CODE_DIR=/code;
export RVZR_DIR=$CODE_DIR/revizor-docker;
export GEM5_DIR=$CODE_DIR/gem5-docker;

# Revizor priming flags: Fetch,DRAM,Decode,Commit,ROB,IQ,O3PipeView,CommMonitor,O3CPUAll,CacheAll,MMU,Branch,IEW,LSQUnit,StoreSet,MemoryAccess,ExecAll
# Used: Squashed, LSQUnit, CacheBlockMiss, CacheBlockHit, CacheAccess
# Debug: Fetch,Decode,Commit,IEW,IQ
# Squashed,Fetch,Decode,IQ,Rename,LSQ,LSQUnit
# Squashed,LSQUnit,RubyCache,RubySlicc,RubySystem
export GEM5_DEBUG_FLAGS="Squashed"
export DEBUG_START=0 # Default: 188000 (big-rewrite), 69000 (violation-finder)

init_dirs(){
  RUN_1_NAME=$1; # E.g. "a_ruby"
  RUN_2_NAME=$2; # E.g. "b_ruby"

  cd $GEM5_DIR/violation_test;
  mkdir -p $GEM5_DIR/violation_test/out;
  mkdir -p $GEM5_DIR/m5out_testcase_$RUN_1_NAME;
  mkdir -p $GEM5_DIR/m5out_testcase_$RUN_2_NAME;
  mkdir -p $GEM5_DIR/checkpoint_testcase_$RUN_1_NAME;
  mkdir -p $GEM5_DIR/checkpoint_testcase_$RUN_2_NAME;
}



compile_test_case() {
  RUN_NAME=$1; # E.g. "a_ruby"

  echo "Compiling testcase_$RUN_NAME"
  # Compile testcase_$TC_NAME; Assuming cpt_base and test_case_*.asm
  cd testcase_$RUN_NAME;
  mv test_case_*.asm test_case_$RUN_NAME.asm
  as -g -mmnemonic=intel -msyntax=intel test_case_$RUN_NAME.asm -o test_case_$RUN_NAME.o
  objcopy --remove-section .note.gnu.property test_case_$RUN_NAME.o
  ld test_case_$RUN_NAME.o -o test_case_$RUN_NAME.out  -T ../link1.ld
  mv test_case_$RUN_NAME.o test_case_$RUN_NAME.out ../out
  cd ..
  echo "Done compiling testcase_$RUN_NAME"
}

emplace_ckpt() {
  PRIMARY_RUN_NAME=$1; # E.g. "a_ruby"
  SECONDARY_RUN_NAME=$2; # E.g. "b_ruby"
  START_TICK=$3; # Int

  echo "Putting checkpoint_$PRIMARY_RUN_NAME into place"
  cd testcase_$PRIMARY_RUN_NAME;
  mv cpt_base checkpoint_$PRIMARY_RUN_NAME
  if [ ! -f "checkpoint_$PRIMARY_RUN_NAME" ]; then
      exit "Abort: checkpoint_$PRIMARY_RUN_NAME does not exist"
  fi
  rm -rf $GEM5_DIR/checkpoint_testcase_$PRIMARY_RUN_NAME/*
  mkdir -p $GEM5_DIR/checkpoint_testcase_$PRIMARY_RUN_NAME/cpt.$START_TICK
  cp checkpoint_$PRIMARY_RUN_NAME $GEM5_DIR/checkpoint_testcase_$PRIMARY_RUN_NAME/cpt.$START_TICK/m5.cpt
  rm -rf $GEM5_DIR/checkpoint_testcase_$SECONDARY_RUN_NAME/*
  mkdir -p $GEM5_DIR/checkpoint_testcase_$SECONDARY_RUN_NAME/cpt.$START_TICK
  cp checkpoint_$PRIMARY_RUN_NAME $GEM5_DIR/checkpoint_testcase_$SECONDARY_RUN_NAME/cpt.$START_TICK/m5.cpt
  cd ..
  echo "Done putting checkpoint_$PRIMARY_RUN_NAME into place"
}

clean_state_ruby_memory_trace() { # CHECK needsTSO? Is true (1) in baseline code
  RUN_NAME=$1; # E.g. "a_ruby"

  echo "Running testcase_$RUN_NAME"
  cd $GEM5_DIR;
  mkdir -p m5out_testcase_$RUN_NAME
  $GEM5_DIR/build/X86/gem5.opt \
    --outdir=m5out_testcase_$RUN_NAME \
    --debug-flags=$GEM5_DEBUG_FLAGS \
    --debug-file=log.out \
    --debug-start=$DEBUG_START \
    $GEM5_DIR/configs/example/se.py \
    --cmd=$GEM5_DIR/violation_test/out/test_case_$RUN_NAME.out \
    --cpu-type=DerivO3CPU --l1d_size=64kB --l1i_size=16kB \
    --l2cache --l1traces --ruby --caches --num-cpu=1 \
    --needsTSO=0 --scheme_invisispec=UnsafeBaseline --scheme_cleanupcache=Cleanup_FOR_L1L2 \
    --rel-max-tick=50000000 \
    --checkpoint-at-end \
    --checkpoint-dir=$GEM5_DIR/checkpoint_testcase_$RUN_NAME > m5out_testcase_$RUN_NAME/gem5_output.out # Use &> to include stderr
  cd $GEM5_DIR/violation_test;
  echo "Done running testcase_$RUN_NAME"
}

clean_state_ruby_final_cache() {
  RUN_NAME=$1; # E.g. "a_ruby"

  echo "Running testcase_$RUN_NAME"
  cd $GEM5_DIR;
  mkdir -p m5out_testcase_$RUN_NAME
  $GEM5_DIR/build/X86/gem5.opt \
    --outdir=m5out_testcase_$RUN_NAME \
    --debug-flags=$GEM5_DEBUG_FLAGS \
    --debug-file=log.out \
    --debug-start=$DEBUG_START \
    $GEM5_DIR/configs/example/se.py \
    --cmd=$GEM5_DIR/violation_test/out/test_case_$RUN_NAME.out \
    --cpu-type=DerivO3CPU --l1d_size=64kB --l1i_size=16kB \
    --l2cache --ruby --dump-caches --caches --num-cpu=1 \
    --needsTSO=0 --scheme_invisispec=UnsafeBaseline --scheme_cleanupcache=Cleanup_FOR_L1L2 \
    --checkpoint-at-end \
    --checkpoint-dir=$GEM5_DIR/checkpoint_testcase_$RUN_NAME > m5out_testcase_$RUN_NAME/gem5_output.out # Use &> to include stderr
  cd $GEM5_DIR/violation_test;
  echo "Done running testcase_$RUN_NAME"
}

clean_state_traditional() {
  RUN_NAME=$1; # E.g. "a"

  echo "Running testcase_$RUN_NAME"
  cd $GEM5_DIR;
  mkdir -p m5out_testcase_$RUN_NAME
  $GEM5_DIR/build/X86/gem5.opt \
    --outdir=m5out_testcase_$RUN_NAME \
    --debug-flags=$GEM5_DEBUG_FLAGS \
    --debug-file=log.out \
    --debug-start=$DEBUG_START \
    $GEM5_DIR/configs/example/se.py \
    --cmd=$GEM5_DIR/violation_test/out/test_case_$RUN_NAME.out \
    --cpu-type=DerivO3CPU --l1d_size=64kB --l1i_size=16kB \
    --l2cache --mem-size=1MB --caches --num-cpu=1 \
    --needsTSO=0 --scheme_invisispec=UnsafeBaseline --scheme_cleanupcache=Cleanup_FOR_L1L2 \
    --rel-max-tick=5000000 \
    --checkpoint-at-end \
    --checkpoint-dir=$GEM5_DIR/checkpoint_testcase_$RUN_NAME > m5out_testcase_$RUN_NAME/gem5_output.out # Use &> to include stderr
  cd $GEM5_DIR/violation_test;
  echo "Done running testcase_$RUN_NAME"
}

ckpt_restored_ruby_memory_trace(){
  RUN_NAME=$1; # E.g. "a_ruby"

  echo "Running testcase_$RUN_NAME"
  cd $GEM5_DIR;
  mkdir -p m5out_testcase_$RUN_NAME
  $GEM5_DIR/build/X86/gem5.opt \
    --outdir=m5out_testcase_$RUN_NAME \
    --debug-flags=$GEM5_DEBUG_FLAGS \
    --debug-file=log.out \
    --debug-start=$DEBUG_START \
    $GEM5_DIR/configs/example/se.py \
    --cmd=$GEM5_DIR/violation_test/out/test_case_$RUN_NAME.out \
    --cpu-type=DerivO3CPU --l1d_size=64kB --l1i_size=16kB \
    --l2cache --ruby --l1traces --caches --num-cpu=1 \
    --needsTSO=0 --scheme_invisispec=UnsafeBaseline --scheme_cleanupcache=Cleanup_FOR_L1L2 \
    --rel-max-tick=50000000 \
    --checkpoint-at-end \
    --checkpoint-dir=$GEM5_DIR/checkpoint_testcase_$RUN_NAME \
    --restore-with-cpu=DerivO3CPU -r 1 > m5out_testcase_$RUN_NAME/gem5_output.out # Use &> to include stderr
  cd $GEM5_DIR/violation_test;
  echo "Done running testcase_$RUN_NAME"
}

ckpt_restored_ruby_final_cache(){
  RUN_NAME=$1; # E.g. "a_ruby"

  echo "Running testcase_$RUN_NAME"
  cd $GEM5_DIR;
  mkdir -p m5out_testcase_$RUN_NAME
  $GEM5_DIR/build/X86/gem5.opt \
    --outdir=m5out_testcase_$RUN_NAME \
    --debug-flags=$GEM5_DEBUG_FLAGS \
    --debug-file=log.out \
    --debug-start=$DEBUG_START \
    $GEM5_DIR/configs/example/se.py \
    --cmd=$GEM5_DIR/violation_test/out/test_case_$RUN_NAME.out \
    --cpu-type=DerivO3CPU --l1d_size=64kB --l1i_size=16kB \
    --l2cache --ruby --dump-caches --caches --num-cpu=1 \
    --needsTSO=0 --scheme_invisispec=UnsafeBaseline --scheme_cleanupcache=Cleanup_FOR_L1L2 \
    --checkpoint-at-end \
    --checkpoint-dir=$GEM5_DIR/checkpoint_testcase_$RUN_NAME \
    --restore-with-cpu=DerivO3CPU -r 1 > m5out_testcase_$RUN_NAME/gem5_output.out # Use &> to include stderr
  cd $GEM5_DIR/violation_test;
  echo "Done running testcase_$RUN_NAME"
}

ckpt_restored_traditional(){
  RUN_NAME=$1; # E.g. "a"

  echo "Running testcase_$RUN_NAME"
  cd $GEM5_DIR;
  mkdir -p m5out_testcase_$RUN_NAME
  $GEM5_DIR/build/X86/gem5.opt \
    --outdir=m5out_testcase_$RUN_NAME \
    --debug-flags=$GEM5_DEBUG_FLAGS \
    --debug-file=log.out \
    --debug-start=$DEBUG_START \
    $GEM5_DIR/configs/example/se.py \
    --cmd=$GEM5_DIR/violation_test/out/test_case_$RUN_NAME.out \
    --cpu-type=DerivO3CPU --l1d_size=64kB --l1i_size=16kB \
    --l2cache --mem-size=1MB --caches --num-cpu=1 \
    --needsTSO=0 --scheme_invisispec=UnsafeBaseline --scheme_cleanupcache=Cleanup_FOR_L1L2 \
    --rel-max-tick=5000000 \
    --checkpoint-at-end \
    --checkpoint-dir=$GEM5_DIR/checkpoint_testcase_$RUN_NAME \
    --restore-with-cpu=DerivO3CPU -r 1 > m5out_testcase_$RUN_NAME/gem5_output.out # Use &> to include stderr
  cd $GEM5_DIR/violation_test;
  echo "Done running testcase_$RUN_NAME"
}


main() {
  ARG=$1 # Set initial state
  RUBY_MODE=$2;

  if [[ "$RUBY_MODE" == "ruby" ]]; then
    echo "Running in ruby cache mode";
    RUN_1_NAME="a_ruby";
    RUN_2_NAME="b_ruby";
  else
    echo "Running in traditional cache mode";
    RUN_1_NAME="a";
    RUN_2_NAME="b";
  fi;

  init_dirs $RUN_1_NAME $RUN_2_NAME;
  compile_test_case $RUN_1_NAME;
  compile_test_case $RUN_2_NAME;

  case $ARG in
    "compile_gem5")
      cd $GEM5_DIR;
      export CORES=$(( `nproc --all` + 1));
      python2.7 `which scons` -j${CORES} --verbose build/X86/gem5.opt --default=X86 PROTOCOL=MESI_Two_Level --ignore-style
    ;;

    "clean_state")
      echo "Running with clean_state"

      # Run with clean initial uarch state (don't restore ckpts)
      if [[ "$RUBY_MODE" == "ruby" ]]; then
        clean_state_ruby_memory_trace $RUN_1_NAME;
        clean_state_ruby_memory_trace $RUN_2_NAME;

        # clean_state_ruby_final_cache $RUN_1_NAME;
        # clean_state_ruby_final_cache $RUN_2_NAME;
      else
        clean_state_traditional $RUN_1_NAME;
        clean_state_traditional $RUN_2_NAME;
      fi;

      echo "Done running with clean_state"
    ;;

    "ckpt_a")
      # N-1 Checkpoint is initial uarch state of N'th test case
      START_TICK=$2 # End tick of N-1'th test case (check output.out for last tc)
      if [[ "$START_TICK" == "ruby" ]]; then
          START_TICK=$3;
      fi;
      if [ -z "$START_TICK" ]; then
        exit "Abort: Please provide start tick to restore checkpoint_$RUN_1_NAME!";
      fi;
      echo "Running with ckpt_a"

      emplace_ckpt $RUN_1_NAME $RUN_2_NAME $START_TICK;
      if [[ "$RUBY_MODE" == "ruby" ]]; then
        ckpt_restored_ruby_memory_trace $RUN_1_NAME;
        ckpt_restored_ruby_memory_trace $RUN_2_NAME;
      else
        ckpt_restored_traditional $RUN_1_NAME;
        ckpt_restored_traditional $RUN_2_NAME;
      fi;

      echo "Done running with ckpt_a"
    ;;

    "ckpt_b")
      # N-1 Checkpoint is initial uarch state of N'th test case
      START_TICK=$2 # End tick of N-1'th test case (check output.out for last tc)
      if [[ "$START_TICK" == "ruby" ]]; then
          START_TICK=$3;
      fi;
      if [ -z "$START_TICK" ]; then
        exit "Abort: Please provide start tick to restore checkpoint_$RUN_1_NAME!";
      fi;
      echo "Running with ckpt_b"

      emplace_ckpt $RUN_2_NAME $RUN_1_NAME $START_TICK;
      if [[ "$RUBY_MODE" == "ruby" ]]; then
        ckpt_restored_ruby_memory_trace $RUN_1_NAME;
        ckpt_restored_ruby_memory_trace $RUN_2_NAME;
      else
        ckpt_restored_traditional $RUN_1_NAME;
        ckpt_restored_traditional $RUN_2_NAME;
      fi;

      echo "Done running with ckpt_b"
    ;;

    "parse_traces")
      # Change *ruby_memory_trace to *ruby_final_cache as appropriate for correct trace!
      echo "Running parse_traces"
      cd $GEM5_DIR/m5out_testcase_$RUN_1_NAME;
      python3.11 $GEM5_DIR/violation_test/parse_traces.py $GEM5_DIR/m5out_testcase_$RUN_1_NAME; # Places traces.out in workdir (m5out)

      cd $GEM5_DIR/m5out_testcase_$RUN_2_NAME;
      python3.11 $GEM5_DIR/violation_test/parse_traces.py $GEM5_DIR/m5out_testcase_$RUN_2_NAME;

      cd $GEM5_DIR/violation_test/out;
      objdump -d test_case_$RUN_1_NAME.out > test_case_$RUN_1_NAME.dump # Place objdump in violation_test/out dir
      objdump -d test_case_$RUN_2_NAME.out > test_case_$RUN_2_NAME.dump

      echo "Done running parse_traces"
    ;;

    *)
      echo "Error: No arguments given!";
      echo """
        Usage:
        ./test.sh compile_gem5
        ./test.sh clean_state <ruby_mode>
        ./test.sh ckpt_a <ruby_mode> <ckpt_start_tick>
        ./test.sh ckpt_b <ruby_mode> <ckpt_start_tick>
        ./test.sh parse_traces <ruby_mode>

        <ckpt_start_tick> may be 0 if wanting to restore checkpoint upon init!
        <ruby_mode> is "ruby" or else traditional caches

      """
    ;;
  esac
}

main "$@"

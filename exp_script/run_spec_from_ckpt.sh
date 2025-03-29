#!/bin/bash

# Max insts to run after restoring from checkpoint
MAX_INSTS=250000000; # Best

# Checkpoint configuration (Corellate with ckptscript.sh)
# CHECKPOINT_CONFIG="o3_4Gmem_10K";
# INST_TAKE_CHECKPOINT=10000;
# CHECKPOINT_CONFIG="o3_4Gmem_100K";
# INST_TAKE_CHECKPOINT=100000;
CHECKPOINT_CONFIG="o3_4Gmem_10B"; # Best
INST_TAKE_CHECKPOINT=10000000000;

############ DIRECTORY VARIABLES: MODIFY ACCORDINGLY #############
#Need to export GEM5_PATH
if [ -z ${GEM5_PATH+x} ];
then
    echo "GEM5_PATH is unset";
    exit
else
    echo "GEM5_PATH is set to '$GEM5_PATH'";
fi

#Need to export GEM5_PERF_ROOT
if [ -z ${GEM5_PERF_ROOT+x} ];
then
    echo "GEM5_PERF_ROOT is unset";
    exit
else
    echo "GEM5_PERF_ROOT is set to '$GEM5_PERF_ROOT'";
fi

#Need to export SPEC_PATH
# [mengjia] on my desktop, it is /home/mengjia/workspace/benchmarks/cpu2006
if [ -z ${SPEC_PATH+x} ];
then
    echo "SPEC_PATH is unset";
    exit
else
    echo "SPEC_PATH is set to '$SPEC_PATH'";
fi

##################################################################
 
ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" != 2 ]]; then # Bad number of arguments.
   echo "run_spec2017_from_ckpt.sh"
   echo "This program comes with ABSOLUTELY NO WARRANTY; for details see <http://www.gnu.org/licenses/>."
   echo "This is free software, and you are welcome to redistribute it under certain conditions; see <http://www.gnu.org/licenses/> for details."
   echo ""
    echo ""
    echo "This script runs a single gem5 simulation of a single SPEC CPU2006 benchmark"
    echo ""
    echo "USAGE: run_spec2017_from_ckpt.sh <BENCHMARK> <SCHEME>"
    echo "EXAMPLE: ./run_spec2017_from_ckpt.sh perlbench UnsafeBaseline"
    echo ""
    echo "A single --help help or -h argument will bring this message back."
    exit
fi
 
# Get command line input. We will need to check these.
BENCHMARK=$1                    # Benchmark name, e.g. bzip2
SCHEME=$2

######################### BENCHMARK CODENAMES ####################
PERLBENCH_CODE=400.perlbench
BZIP2_CODE=401.bzip2
GCC_CODE=403.gcc
BWAVES_CODE=410.bwaves
GAMESS_CODE=416.gamess
MCF_CODE=429.mcf
MILC_CODE=433.milc
ZEUSMP_CODE=434.zeusmp
GROMACS_CODE=435.gromacs
CACTUSADM_CODE=436.cactusADM
LESLIE3D_CODE=437.leslie3d
NAMD_CODE=444.namd
GOBMK_CODE=445.gobmk
DEALII_CODE=447.dealII
SOPLEX_CODE=450.soplex
POVRAY_CODE=453.povray
CALCULIX_CODE=454.calculix
HMMER_CODE=456.hmmer
SJENG_CODE=458.sjeng
GEMSFDTD_CODE=459.GemsFDTD
LIBQUANTUM_CODE=462.libquantum
H264REF_CODE=464.h264ref
TONTO_CODE=465.tonto
LBM_CODE=470.lbm
OMNETPP_CODE=471.omnetpp
ASTAR_CODE=473.astar
WRF_CODE=481.wrf
SPHINX3_CODE=482.sphinx3
XALANCBMK_CODE=483.xalancbmk
SPECRAND_INT_CODE=998.specrand
SPECRAND_FLOAT_CODE=999.specrand
##################################################################
 
# Check BENCHMARK input
#################### BENCHMARK CODE MAPPING ######################
BENCHMARK_CODE="none"
 
if [[ "$BENCHMARK" == "perlbench" ]]; then
    BENCHMARK_CODE=$PERLBENCH_CODE
fi
if [[ "$BENCHMARK" == "bzip2" ]]; then
    BENCHMARK_CODE=$BZIP2_CODE
fi
if [[ "$BENCHMARK" == "gcc" ]]; then
    BENCHMARK_CODE=$GCC_CODE
fi
if [[ "$BENCHMARK" == "bwaves" ]]; then
    BENCHMARK_CODE=$BWAVES_CODE
fi
if [[ "$BENCHMARK" == "gamess" ]]; then
    BENCHMARK_CODE=$GAMESS_CODE
fi
if [[ "$BENCHMARK" == "mcf" ]]; then
    BENCHMARK_CODE=$MCF_CODE
fi
if [[ "$BENCHMARK" == "milc" ]]; then
    BENCHMARK_CODE=$MILC_CODE
fi
if [[ "$BENCHMARK" == "zeusmp" ]]; then
    BENCHMARK_CODE=$ZEUSMP_CODE
fi
if [[ "$BENCHMARK" == "gromacs" ]]; then
    BENCHMARK_CODE=$GROMACS_CODE
fi
if [[ "$BENCHMARK" == "cactusADM" ]]; then
    BENCHMARK_CODE=$CACTUSADM_CODE
fi
if [[ "$BENCHMARK" == "leslie3d" ]]; then
    BENCHMARK_CODE=$LESLIE3D_CODE
fi
if [[ "$BENCHMARK" == "namd" ]]; then
    BENCHMARK_CODE=$NAMD_CODE
fi
if [[ "$BENCHMARK" == "gobmk" ]]; then
    BENCHMARK_CODE=$GOBMK_CODE
fi
if [[ "$BENCHMARK" == "dealII" ]]; then # DOES NOT WORK
    BENCHMARK_CODE=$DEALII_CODE
fi
if [[ "$BENCHMARK" == "soplex" ]]; then
    BENCHMARK_CODE=$SOPLEX_CODE
fi
if [[ "$BENCHMARK" == "povray" ]]; then
    BENCHMARK_CODE=$POVRAY_CODE
fi
if [[ "$BENCHMARK" == "calculix" ]]; then
    BENCHMARK_CODE=$CALCULIX_CODE
fi
if [[ "$BENCHMARK" == "hmmer" ]]; then
    BENCHMARK_CODE=$HMMER_CODE
fi
if [[ "$BENCHMARK" == "sjeng" ]]; then
    BENCHMARK_CODE=$SJENG_CODE
fi
if [[ "$BENCHMARK" == "GemsFDTD" ]]; then
    BENCHMARK_CODE=$GEMSFDTD_CODE
fi
if [[ "$BENCHMARK" == "libquantum" ]]; then
    BENCHMARK_CODE=$LIBQUANTUM_CODE
fi
if [[ "$BENCHMARK" == "h264ref" ]]; then
    BENCHMARK_CODE=$H264REF_CODE
fi
if [[ "$BENCHMARK" == "tonto" ]]; then
    BENCHMARK_CODE=$TONTO_CODE
fi
if [[ "$BENCHMARK" == "lbm" ]]; then
    BENCHMARK_CODE=$LBM_CODE
fi
if [[ "$BENCHMARK" == "omnetpp" ]]; then
    BENCHMARK_CODE=$OMNETPP_CODE
fi
if [[ "$BENCHMARK" == "astar" ]]; then
    BENCHMARK_CODE=$ASTAR_CODE
fi
if [[ "$BENCHMARK" == "wrf" ]]; then
    BENCHMARK_CODE=$WRF_CODE
fi
if [[ "$BENCHMARK" == "sphinx3" ]]; then
    BENCHMARK_CODE=$SPHINX3_CODE
fi
if [[ "$BENCHMARK" == "xalancbmk" ]]; then # DOES NOT WORK
    BENCHMARK_CODE=$XALANCBMK_CODE
fi
if [[ "$BENCHMARK" == "specrand_i" ]]; then
    BENCHMARK_CODE=$SPECRAND_INT_CODE
fi
if [[ "$BENCHMARK" == "specrand_f" ]]; then
    BENCHMARK_CODE=$SPECRAND_FLOAT_CODE
fi
 
# Sanity check
if [[ "$BENCHMARK_CODE" == "none" ]]; then
    echo "Input benchmark selection $BENCHMARK did not match any known SPEC CPU2006 benchmarks! Exiting."
    exit 1
fi
##################################################################

OUTPUT_DIR=$GEM5_PERF_ROOT/output/checkpoints/${CHECKPOINT_CONFIG}/SPEC-$BENCHMARK-$SCHEME
CKPT_OUT_DIR=$GEM5_PERF_ROOT/gem5_ckpt/${CHECKPOINT_CONFIG}/$BENCHMARK-1-ref-x86

echo "checkpoint direcotory: " $CKPT_OUT_DIR
echo "output directory: " $OUTPUT_DIR

if [ -d "$OUTPUT_DIR" ]
then
    rm -r $OUTPUT_DIR
fi
mkdir -p $OUTPUT_DIR

RUN_DIR=$SPEC_PATH/benchspec/CPU2006/$BENCHMARK_CODE/run/run_base_ref_gcc41-64bit.0000
#run_base_ref\_my-alpha.0000
# Run directory for the selected SPEC benchmark
SCRIPT_OUT=$OUTPUT_DIR/runscript.log
# File log for this script's stdout henceforth
 
################## REPORT SCRIPT CONFIGURATION ###################
 
echo "Command line:"                                | tee $SCRIPT_OUT
echo "$0 $*"                                        | tee -a $SCRIPT_OUT
echo "================= Hardcoded directories ==================" | tee -a $SCRIPT_OUT
echo "GEM5_PATH:                                     $GEM5_PATH" | tee -a $SCRIPT_OUT
echo "SPEC_PATH:                                     $SPEC_PATH" | tee -a $SCRIPT_OUT
echo "==================== Script inputs =======================" | tee -a $SCRIPT_OUT
echo "BENCHMARK:                                    $BENCHMARK" | tee -a $SCRIPT_OUT
echo "OUTPUT_DIR:                                   $OUTPUT_DIR" | tee -a $SCRIPT_OUT
echo "==========================================================" | tee -a $SCRIPT_OUT
##################################################################
 
 
#################### LAUNCH GEM5 SIMULATION ######################
echo ""
echo "Changing to SPEC benchmark runtime directory: $RUN_DIR" | tee -a $SCRIPT_OUT
cd $RUN_DIR
 
echo "" | tee -a $SCRIPT_OUT
echo "" | tee -a $SCRIPT_OUT
echo "--------- Here goes nothing! Starting gem5! ------------" | tee -a $SCRIPT_OUT
echo "" | tee -a $SCRIPT_OUT
echo "" | tee -a $SCRIPT_OUT

SPEC_CONFIG=$GEM5_PATH/configs/example/spec06_config.py
 
# Actually launch gem5!
$GEM5_PATH/build/X86/gem5.opt \
	--outdir=$OUTPUT_DIR $SPEC_CONFIG \
	--benchmark=$BENCHMARK --benchmark_stdout=$OUTPUT_DIR/$BENCHMARK.out \
	--benchmark_stderr=$OUTPUT_DIR/$BENCHMARK.err \
	--checkpoint-dir=$CKPT_OUT_DIR \
	--checkpoint-restore=$INST_TAKE_CHECKPOINT --at-instruction \
    --restore-with-cpu=AtomicSimpleCPU \
        --num-cpus=1 \
        --mem-size=8192MB \
        --bp-type=BiModeBP \
        --caches \
        --l2cache \
        --cacheline=64 \
        --num-l2cache=1 \
        --l1i_size=64kB \
        --l1i_assoc=4 \
        --l1d_size=16kB \
        --l1d_assoc=4 \
        --l2_size=256kB \
        --l2_assoc=4 \
    --cpu-type=DerivO3CPU \
    --scheme=$SCHEME \
        --redirects=/lib=/lib \
        --redirects=/lib64=/lib64 \
        --redirects=/usr=/usr \
        --redirects=/bin=/bin \
        --redirects=/etc=/etc \
        --redirects=/tmp=$OUTPUT_DIR/tmp \
  --maxinsts=$MAX_INSTS | tee -a $SCRIPT_OUT


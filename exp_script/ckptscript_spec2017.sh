#!/bin/bash

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

#Need to export SPEC2017_PATH
# [mengjia] on my desktop, it is /home/mengjia/workspace/benchmarks/cpu2006
if [ -z ${SPEC2017_PATH+x} ];
then
    echo "SPEC2017_PATH is unset";
    exit
else
    echo "SPEC2017_PATH is set to '$SPEC2017_PATH'";
fi

##################################################################
 
ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" != 1 ]]; then # Bad number of arguments.
   echo "ckptscript_spec2017.sh"
   echo "This program comes with ABSOLUTELY NO WARRANTY; for details see <http://www.gnu.org/licenses/>."
   echo "This is free software, and you are welcome to redistribute it under certain conditions; see <http://www.gnu.org/licenses/> for details."
   echo ""
    echo ""
    echo "This script runs a single gem5 simulation of a single SPEC CPU2017 benchmark"
    echo ""
    echo "USAGE: ckptscript_spec2017.sh <BENCHMARK>"
    echo "EXAMPLE: ./ckptscript_spec2017.sh bwaves_r"
    echo ""
    echo "A single --help help or -h argument will bring this message back."
    exit
fi
 
# Get command line input. We will need to check these.
BENCHMARK=$1                    # Benchmark name, e.g. bzip2
SCHEME=unsafebaseline  # Use to progress faster until measuring point

# Checkpoint configuration
CHECKPOINT_CONFIG="o3_4Gmem_10K"
INST_TAKE_CHECKPOINT=10000
# CHECKPOINT_CONFIG="o3_4Gmem_100K"
# INST_TAKE_CHECKPOINT=100000
# CHECKPOINT_CONFIG="o3_4Gmem_10B"
# INST_TAKE_CHECKPOINT=10000000000

MAX_INSTS=$((INST_TAKE_CHECKPOINT + 10))

######################### BENCHMARK CODENAMES ####################
PERLBENCH_R_CODE=500.perlbench_r
PERLBENCH_S_CODE=600.perlbench_s
GCC_R_CODE=502.gcc_r
GCC_S_CODE=602.gcc_s
MCF_R_CODE=505.mcf_r
MCF_S_CODE=605.mcf_s
OMNETPP_R_CODE=520.omnetpp_r
OMNETPP_S_CODE=620.omnetpp_s
XALANCBMK_R_CODE=523.xalancbmk_r
XALANCBMK_S_CODE=623.xalancbmk_s
X264_R_CODE=525.x264_r
X264_S_CODE=625.x264_s
DEEPSJENG_R_CODE=531.deepsjeng_r
DEEPSJENG_S_CODE=631.deepsjeng_s
LEELA_R_CODE=541.leela_r
LEELA_S_CODE=641.leela_s
EXCHANGE2_R_CODE=548.exchange2_r
EXCHANGE2_S_CODE=648.exchange2_s
XZ_R_CODE=557.xz_r
XZ_S_CODE=657.xz_s
BWAVES_R_CODE=503.bwaves_r
BWAVES_S_CODE=603.bwaves_s
CACTUBSSN_R_CODE=507.cactuBSSN_r
CACTUBSSN_S_CODE=607.cactuBSSN_s
NAMD_R_CODE=508.namd_r
PAREST_R_CODE=510.parest_r
POVRAY_R_CODE=511.povray_r
LBM_R_CODE=519.lbm_r
LBM_S_CODE=619.lbm_s
WRF_R_CODE=521.wrf_r
WRF_S_CODE=621.wrf_s
BLENDER_R_CODE=526.blender_r
CAM4_R_CODE=527.cam4_r
CAM4_S_CODE=627.cam4_s
POP2_S_CODE=628.pop2_s
IMAGICK_R_CODE=538.imagick_r
IMAGICK_S_CODE=638.imagick_s
NAB_R_CODE=544.nab_r
NAB_S_CODE=644.nab_s
FOTONIK3D_R_CODE=549.fotonik3d_r
FOTONIK3D_S_CODE=649.fotonik3d_s
ROMS_R_CODE=554.roms_r
ROMS_S_CODE=654.roms_s
SPECRAND_FS_CODE=996.specrand_fs
SPECRAND_FR_CODE=997.specrand_fr
SPECRAND_IS_CODE=998.specrand_is
SPECRAND_IR_CODE=999.specrand_ir
##################################################################

# Check BENCHMARK input
#################### BENCHMARK CODE MAPPING ######################
BENCHMARK_CODE="none"

if [[ "$BENCHMARK" == "perlbench_r" ]]; then BENCHMARK_CODE=$PERLBENCH_R_CODE; fi
if [[ "$BENCHMARK" == "perlbench_s" ]]; then BENCHMARK_CODE=$PERLBENCH_S_CODE; fi
if [[ "$BENCHMARK" == "gcc_r" ]]; then BENCHMARK_CODE=$GCC_R_CODE; fi
if [[ "$BENCHMARK" == "gcc_s" ]]; then BENCHMARK_CODE=$GCC_S_CODE; fi
if [[ "$BENCHMARK" == "mcf_r" ]]; then BENCHMARK_CODE=$MCF_R_CODE; fi
if [[ "$BENCHMARK" == "mcf_s" ]]; then BENCHMARK_CODE=$MCF_S_CODE; fi
if [[ "$BENCHMARK" == "omnetpp_r" ]]; then BENCHMARK_CODE=$OMNETPP_R_CODE; fi
if [[ "$BENCHMARK" == "omnetpp_s" ]]; then BENCHMARK_CODE=$OMNETPP_S_CODE; fi
if [[ "$BENCHMARK" == "xalancbmk_r" ]]; then BENCHMARK_CODE=$XALANCBMK_R_CODE; fi
if [[ "$BENCHMARK" == "xalancbmk_s" ]]; then BENCHMARK_CODE=$XALANCBMK_S_CODE; fi
if [[ "$BENCHMARK" == "x264_r" ]]; then BENCHMARK_CODE=$X264_R_CODE; fi
if [[ "$BENCHMARK" == "x264_s" ]]; then BENCHMARK_CODE=$X264_S_CODE; fi
if [[ "$BENCHMARK" == "deepsjeng_r" ]]; then BENCHMARK_CODE=$DEEPSJENG_R_CODE; fi
if [[ "$BENCHMARK" == "deepsjeng_s" ]]; then BENCHMARK_CODE=$DEEPSJENG_S_CODE; fi
if [[ "$BENCHMARK" == "leela_r" ]]; then BENCHMARK_CODE=$LEELA_R_CODE; fi
if [[ "$BENCHMARK" == "leela_s" ]]; then BENCHMARK_CODE=$LEELA_S_CODE; fi
if [[ "$BENCHMARK" == "exchange2_r" ]]; then BENCHMARK_CODE=$EXCHANGE2_R_CODE; fi
if [[ "$BENCHMARK" == "exchange2_s" ]]; then BENCHMARK_CODE=$EXCHANGE2_S_CODE; fi
if [[ "$BENCHMARK" == "xz_r" ]]; then BENCHMARK_CODE=$XZ_R_CODE; fi
if [[ "$BENCHMARK" == "xz_s" ]]; then BENCHMARK_CODE=$XZ_S_CODE; fi
if [[ "$BENCHMARK" == "bwaves_r" ]]; then BENCHMARK_CODE=$BWAVES_R_CODE; fi
if [[ "$BENCHMARK" == "bwaves_s" ]]; then BENCHMARK_CODE=$BWAVES_S_CODE; fi
if [[ "$BENCHMARK" == "cactuBSSN_r" ]]; then BENCHMARK_CODE=$CACTUBSSN_R_CODE; fi
if [[ "$BENCHMARK" == "cactuBSSN_s" ]]; then BENCHMARK_CODE=$CACTUBSSN_S_CODE; fi
if [[ "$BENCHMARK" == "namd_r" ]]; then BENCHMARK_CODE=$NAMD_R_CODE; fi
if [[ "$BENCHMARK" == "parest_r" ]]; then BENCHMARK_CODE=$PAREST_R_CODE; fi
if [[ "$BENCHMARK" == "povray_r" ]]; then BENCHMARK_CODE=$POVRAY_R_CODE; fi
if [[ "$BENCHMARK" == "lbm_r" ]]; then BENCHMARK_CODE=$LBM_R_CODE; fi
if [[ "$BENCHMARK" == "lbm_s" ]]; then BENCHMARK_CODE=$LBM_S_CODE; fi
if [[ "$BENCHMARK" == "wrf_r" ]]; then BENCHMARK_CODE=$WRF_R_CODE; fi
if [[ "$BENCHMARK" == "wrf_s" ]]; then BENCHMARK_CODE=$WRF_S_CODE; fi
if [[ "$BENCHMARK" == "blender_r" ]]; then BENCHMARK_CODE=$BLENDER_R_CODE; fi
if [[ "$BENCHMARK" == "cam4_r" ]]; then BENCHMARK_CODE=$CAM4_R_CODE; fi
if [[ "$BENCHMARK" == "cam4_s" ]]; then BENCHMARK_CODE=$CAM4_S_CODE; fi
if [[ "$BENCHMARK" == "pop2_s" ]]; then BENCHMARK_CODE=$POP2_S_CODE; fi
if [[ "$BENCHMARK" == "imagick_r" ]]; then BENCHMARK_CODE=$IMAGICK_R_CODE; fi
if [[ "$BENCHMARK" == "imagick_s" ]]; then BENCHMARK_CODE=$IMAGICK_S_CODE; fi
if [[ "$BENCHMARK" == "nab_r" ]]; then BENCHMARK_CODE=$NAB_R_CODE; fi
if [[ "$BENCHMARK" == "nab_s" ]]; then BENCHMARK_CODE=$NAB_S_CODE; fi
if [[ "$BENCHMARK" == "fotonik3d_r" ]]; then BENCHMARK_CODE=$FOTONIK3D_R_CODE; fi
if [[ "$BENCHMARK" == "fotonik3d_s" ]]; then BENCHMARK_CODE=$FOTONIK3D_S_CODE; fi
if [[ "$BENCHMARK" == "roms_r" ]]; then BENCHMARK_CODE=$ROMS_R_CODE; fi
if [[ "$BENCHMARK" == "roms_s" ]]; then BENCHMARK_CODE=$ROMS_S_CODE; fi
if [[ "$BENCHMARK" == "specrand_fs" ]]; then BENCHMARK_CODE=$SPECRAND_FS_CODE; fi
if [[ "$BENCHMARK" == "specrand_fr" ]]; then BENCHMARK_CODE=$SPECRAND_FR_CODE; fi
if [[ "$BENCHMARK" == "specrand_is" ]]; then BENCHMARK_CODE=$SPECRAND_IS_CODE; fi
if [[ "$BENCHMARK" == "specrand_ir" ]]; then BENCHMARK_CODE=$SPECRAND_IR_CODE; fi

# Sanity check
if [[ "$BENCHMARK_CODE" == "none" ]]; then
    echo "Input benchmark selection $BENCHMARK did not match any known SPEC2017 CPU benchmarks! Exiting."
    exit 1
fi
##################################################################

 
OUTPUT_DIR=$GEM5_PERF_ROOT/output/checkpoints/${CHECKPOINT_CONFIG}/$BENCHMARK-spec2017
CKPT_OUT_DIR=$GEM5_PERF_ROOT/gem5_ckpt/${CHECKPOINT_CONFIG}/$BENCHMARK-spec2017

echo "checkpoint direcotory: " $CKPT_OUT_DIR
echo "output directory: " $OUTPUT_DIR

if [ -d "$OUTPUT_DIR" ]
then
    rm -r $OUTPUT_DIR
fi
mkdir -p $OUTPUT_DIR
mkdir -p $CKPT_OUT_DIR

RUN_DIR=$SPEC2017_PATH/benchspec/CPU/$BENCHMARK_CODE/run/run_base_refrate_gem5-m64.0000

#run_base_ref\_my-alpha.0000
# Run directory for the selected SPEC benchmark
SCRIPT_OUT=$OUTPUT_DIR/runscript.log
# File log for this script's stdout henceforth
 
################## REPORT SCRIPT CONFIGURATION ###################
 
echo "Command line:"                                | tee $SCRIPT_OUT
echo "$0 $*"                                        | tee -a $SCRIPT_OUT
echo "================= Hardcoded directories ==================" | tee -a $SCRIPT_OUT
echo "GEM5_PATH:                                     $GEM5_PATH" | tee -a $SCRIPT_OUT
echo "SPEC2017_PATH:                                     $SPEC2017_PATH" | tee -a $SCRIPT_OUT
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

SPEC_CONFIG=$GEM5_PATH/configs/example/spec2017_config.py

# Actually launch gem5!
$GEM5_PATH/build/X86/gem5.opt \
	--outdir=$OUTPUT_DIR $SPEC_CONFIG \
	--benchmark=$BENCHMARK --benchmark_stdout=$OUTPUT_DIR/$BENCHMARK.out \
	--benchmark_stderr=$OUTPUT_DIR/$BENCHMARK.err \
        --num-cpus=1 \
        --mem-size=8192MB \
    --cpu-type=AtomicSimpleCPU --scheme=$SCHEME \
	--checkpoint-dir=$CKPT_OUT_DIR \
	--take-checkpoint=$INST_TAKE_CHECKPOINT --at-instruction \
    --maxinsts=$MAX_INSTS \
    | tee -a $SCRIPT_OUT


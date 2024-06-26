#!/bin/bash


############################################################
# USAGE FUNCTIONS                                          #
############################################################

print_common_usage() {
    cat << EOF
== OmniBench

Usage:
  $(basename $0) <command> [options] <arguments>

Commands:
  check      Run a correctness check on a kernel with specific optimization and problem dimensions.
  measure    Perform benchmarking on a kernel with specific optimization, benchmark type, and problem dimensions.
  export     Export GPU information and CSV data to a markdown file.

For detailed help on each command, use:
  $(basename $0) <command> --help

EOF
}

usage_check() {
    cat << EOF
== OmniBench: Check Command

Usage:
  $(basename $0) check [options] <kernel> <optimization> <problem_dim>

Options:
  -h, --help         Show this help message and exit
  -v, --verbose      Enable verbose mode

Arguments:
  <kernel>           Kernel to use (matrixMultiply, saxpy, matrixTranspose, matrixVectorMultiply, matrixCopy)
  <optimization>     Optimization type (NOPT, TILE, UNROLL, STRIDE)
  <problem_dim>      Problem dimensions (size for vectors, size for square matrices)

EOF
}

usage_measure() {
    cat << EOF
== OmniBench: Measure Command

Usage:
  $(basename $0) measure [options] <kernel> <optimization> <benchmark> <problem_dim>

Options:
  -h, --help         Show this help message and exit
  --rerun            Re-run all runs of the benchmark
  -o, --output <f>   Save the benchmark results in the specified file
  -v, --verbose      Enable verbose mode

Arguments:
  <kernel>           Kernel to use (matrixMultiply, saxpy, matrixTranspose, matrixVectorMultiply, matrixCopy)
  <optimization>     Optimization type (NOPT, TILE, UNROLL, STRIDE, ROCBLAS)
  <benchmark>        Benchmark type (Block size variation, Grid size variation, LDS size variation, Unroll size variation)
  <problem_dim>      Problem dimensions (size for vectors, sizexsize for matrices)

EOF
}

usage_export() {
    cat << EOF
== OmniBench: Export Command

Usage:
  $(basename $0) export [options]

Options:
  -h, --help         Show this help message and exit
  -o, --output <f>   Save the exported markdown file as the specified file
  -i, --input <f>    Specify the input CSV file to be converted to markdown table

EOF
}

usage() {
    case "$CMD" in
        check) usage_check ;;
        measure) usage_measure ;;
        export) usage_export ;;
        *) print_common_usage ;;
    esac
    exit 1
}


############################################################
# ARGS MANAGER                                             #
############################################################

check_option()
{
    verbose=0
    rerun=0
    input=""
    output=""
    type=""
    grid_size=""
    nrep=1
    nwu=5
    plot=0
    plot_file="$WORKDIR/results/graph_$(date +%F-%T).png"
    ROCPROF_ONLY=0
    MYDUR_METRICS=""
    block_size_values=""
    block_size_start=32
    block_size_end=32
    block_size_step=1
    grid_size_values=""
    grid_size_start=""
    grid_size_end=""
    grid_size_step=1
    step_x=32
    x_col="BlockSize"
    y_col="RocprofDurationMed"

    TEMP=$(getopt -o $opt_list_short \
                    -l $opt_list \
                    -n $(basename $0) -- "$@")
    if [ $? != 0 ]; then usage ; fi
    eval set -- "$TEMP"
    if [ $? != 0 ]; then usage ; fi

    while true ; do
        case "$1" in
            -h|--help) usage ;;
            -v|--verbose) verbose=1 ; shift ;;
            -o|--output) output=($2) ; shift 2 ;;
            -i|--input) input=($2) ; shift 2 ;;
            -n|--nrep) nrep=($2) ; shift 2 ;;
            -w|--nwu) nwu=($2) ; shift 2 ;;
            -p|--plot) 
                case "$2" in
                    "") plot=1; shift 2 ;;
                    *)  plot=1; plot_file="$2" ; shift 2 ;;
                esac ;;
            -b|--block-size)
                block_size_values="$2"
                shift 2 ;;
            -g|--grid-size)
                grid_size_values="$2"
                shift 2 ;;
            --rocprof-only) ROCPROF_ONLY=1 ; shift ;;
            -x)
                x_col="$2"
                shift 2 ;;
            -y)
                y_col="$2"
                shift 2 ;;
            --step_x)
                step_x="$2"
                shift 2 ;;
            --) shift ; break ;;
            *) echo "No option $1."; usage ;;
        esac
    done
    
    IFS=',' read -r -a block_values <<< "$block_size_values"
    block_size_start=${block_values[0]:-$block_size_start}
    block_size_end=${block_values[1]:-$block_size_start}
    block_size_step=${block_values[2]:-$block_size_step}

    IFS=',' read -r -a grid_values <<< "$grid_size_values"
    grid_size_start=${grid_values[0]:-$grid_size_start}
    grid_size_end=${grid_values[1]:-$grid_size_start}
    grid_size_step=${grid_values[2]:-$grid_size_step}

    ARGS=$@
}

check_args()
{
    if [ $# -ne 3 ]; then
        echo "Need arguments."
        usage
    fi
    KERNEL=$1
    OPT=$2
    PB_SIZE=$3
    BIN_PATH=$WORKDIR/benchmark/$KERNEL/build/bin
    DIM="ONE_DIM"
    if [[ "$KERNEL" == "matrixMultiply" ]]; then
        DIM="TWO_DIM"
    fi
}

############################################################
# RUN COMMAND                                              #
############################################################

run_command()
{
    CMD=$1
    shift
    
    case "$CMD" in
        "check") 
            opt_list_short="hvb:g:" ; 
            opt_list="help,verbose,block-size:,grid-size:" ; 
            check_option $@
            check_args $ARGS
            run_check $@ ;;
        "measure" ) 
            opt_list_short="hvn:w:o:b:g:p::" ; 
            opt_list="help,rocprof-only,verbose,nrep:,nwu:,output:,block-size:,grid-size:,plot::" ; 
            check_option $@
            check_args $ARGS
            run_measure $@ ;;
        "export" )
            opt_list_short="ho:i:x:y:" ; 
            opt_list="help,output:,input:,step-x:" ; 
            check_option $@
            run_export $@ ;;
       
        -h|--help) usage ;; 
        "") echo "OmniBench: need command"; usage ;;
        *) echo "OmniBench: $CMD is not an available command"; usage ;;
    esac
}



############################################################
# EXPORT COMMAND                                           #
############################################################

run_export()
{
    check_option $@
    if [[ -z "$input" ]]; then
        echo "Need an input CSV"
        usage
    fi
    if [[ -z "$output" ]]; then
        output="${input%.csv}.md"
    fi
    output_png="${input%.csv}.png"
    python3 python/plot_from_csv.py --save_plot "$output_png" "$input" "$x_col" "$step_x" "$y_col"
    echo "$(get_gpu_info)" > $output
    echo "" >> $output
    echo "## Graph Result" >> $output
    echo "![graph_from_csv_results]($output_png)" >> $output
    echo "" >> $output
    echo "## CSV Data" >> $output
    csv_to_mdtable $output $input
}

format_cell() 
{
    local cell="$1"
    local length="$2"
    printf "| %-*s " "$length" "$cell"
}

csv_to_mdtable()
{
    tmp=$(awk 'NR==1 {
        n = split($0, cols, ",")
        line = "---"
        for (i = 2; i <= n; i++) line = line "," "---"
        print $0
        print line 
        next
        }
        {print}' "$2")
    echo "$tmp" | column -s, -t | sed 's/ \([a-zA-Z0-9\-]\)/| \1/g' >> "$1"
}

get_gpu_info()
{
    rocminfo_output=$(rocminfo)
    agent_info=$(echo "$rocminfo_output" | awk '/Agent 2/,/Done/')
    gpu_info=$(echo "$agent_info" | awk '
    /^Agent [0-9]+/ { agent = $3 }
    /^  Name: / { name = $2 }
    /^  Marketing Name: / { marketing_name = substr($0, index($0,$3)) }
    /^  Cache Info:/ { cache_info = 1; next }
    /^  Cacheline Size: / { cacheline_size = $3 }
    /^  Compute Unit: / { compute_unit = $3 }
    /^  SIMDs per CU: / { simds_per_cu = $4 }
    /^  Max Waves Per CU: / { max_wave_per_cu = $5 }
    /^  Max Work-item Per CU: / { max_thread_per_cu = $5 }
    /^  Wavefront Size: / { wavefront_size = $3 }
    /^  Workgroup Max Size:/ { workgroup_max_size = $4 }
    /^  / && cache_info == 1 { if ($1 == "L1:" || $1 == "L2:" || $1 == "L3:") { cache_sizes = cache_sizes "- "$1" " $2" " "KB" "\n" } }
    /^$/ { cache_info = 0 }

    END {
    print "## GPU Information:"
    print ""
    print "GPU Name:             " name
    print ""
    print "Marketing Name:       " marketing_name
    print ""
    print "Compute Unit:         " compute_unit
    print ""
    print "SIMDs per CU:         " simds_per_cu
    print ""
    print "Max Wave per CU:      " max_wave_per_cu
    print ""
    print "Max threads per CU:   " max_thread_per_cu
    print ""
    print "Wavefront Size:       " wavefront_size
    print ""
    print "Workgroup Max Size:   " workgroup_max_size
    print ""
    print "Cacheline Size:       " cacheline_size " bytes"
    print ""
    print "Cache Info:"  
    print cache_sizes  
    }')

    echo "$gpu_info"
}

############################################################
# MEASURE COMMAND                                          #
############################################################

run_measure()
{
    ROCPROF_OUTPUT=$TMPDIR/results.csv
    ROCPROF_INPUT=./config/input.txt

    create_output_csv_file

    log_printf "=== Benchmark $BENCH for $KERNEL ($OPT) with size: $PB_SIZE"

    run_basic
}

run_basic()
{
    local counter=0
    block_size_seq=$(seq $block_size_start $block_size_step $block_size_end)
    for block_size in $block_size_seq ; do
        build_driver measure $KERNEL $OPT 
        if [ "$grid_size_values" == "" ]; then
            grid_size_start=$((($PB_SIZE + $block_size - 1) / $block_size))
            grid_size_end=$grid_size_start
        fi
        grid_size_seq=$(seq $grid_size_start $grid_size_step $grid_size_end)
        for grid_size in $grid_size_seq; do
            counter=$((counter+1))
            echo_run "measure" $KERNEL $OPT $PB_SIZE $block_size $grid_size "($(percentage_finish $counter)%)"
            set_call_args $PB_SIZE $block_size $grid_size $nrep $nwu
            rocprof_app
            echo "$(python3 python/extract_data_from_csv.py $output $TMPDIR/measure_tmp.out $TMPDIR/results.csv $nwu)"
        done
    done
    echo
    echo "Result saved in '$output'"
}

percentage_finish()
{
    local counter=$1
    local length_block_seq=$(echo "$block_size_seq" | wc -l)
    local length_grid_seq=$(echo "$grid_size_seq" | wc -l)
    local total_lenght=$((length_block_seq+length_grid_seq))
    local percentage=$(awk "BEGIN {print int(($counter+1)/$total_lenght*100)}")
    echo $percentage
}

call_driver()
{
    echo $BIN_PATH/measure $PB_SIZE $BLOCK_DIM $GRID_DIM $NB_REP $NWU
}

rocprof_app()
{
    eval_verbose rocprof -o $ROCPROF_OUTPUT -i $ROCPROF_INPUT --timestamp on --stats --basenames on $(call_driver) 
}

create_output_csv_file()
{
    fieldnames="Kernel Optimization ProblemSize BlockSize GridSize DurationMed DurationMin Stability RocprofDurationMed RocprofDurationMin RocprofStability MeanOccupancyPerCU MeanOccupancyPerActiveCU GPUBusy Wavefronts L2CacheHit SALUInsts VALUInsts SFetchInsts"
    
    if [[ -z $output ]]; then
        output="$RESULTDIR/"$KERNEL"_"$OPT"_"$PB_SIZE"_$(date +%F-%T).csv"
    fi

    if [[ ! -f "$output" ]]; then
        formatted_header=$(echo "$fieldnames" | tr ' ' ',')
        echo "$formatted_header" > "$output"
    fi
}

############################################################
# CHECK COMMAND                                            #
############################################################

call_driver_check()
{
    echo $BIN_PATH/check $PB_SIZE $BLOCK_DIM $GRID_DIM $CHECK_OUT_FILE $ONLY_GPU
}

run_check()
{
    local counter=0
    block_size_seq=$(seq $block_size_start $block_size_step $block_size_end)
    for block_size in $block_size_seq ; do
        build_driver check "$KERNEL" "$OPT"
        if [ "$grid_size_values" == "" ]; then
            grid_size_start=$((($PB_SIZE + $block_size - 1) / $block_size))
            grid_size_end=$grid_size_start
        fi
        grid_size_seq=$(seq $grid_size_start $grid_size_step $grid_size_end)
        for grid_size in $grid_size_seq; do
            counter=$((counter+1))
            set_call_args $PB_SIZE $block_size $grid_sizes 
            eval $(call_driver_check)
        done
    done
}

############################################################
# UTILS                                                    #
############################################################

check_error()
{
  err=$?
  if [ $err -ne 0 ]; then
    echo -e "OmniBench: error in $0\n\t$1 ($err)"
    echo "Script exit."
    exit 1
  fi
}

eval_verbose()
{
  if [ "$verbose" == 1 ]; then
    eval $@
  elif [ "$verbose" == 0 ]; then
    eval $@ > /dev/null
  fi
}

current_datetime() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

log_printf() {
    local datetime=$(current_datetime)
    local message="$*"
    echo "[$datetime] $message" >> output.log
    echo "$message"
}

echo_run()
{
    echo -ne "\r=== Run $1 $2 $3 (size: $4, blockDim: $5, gridDim: $6) $7"
}

build_driver()
{
    log_printf "=== Compilation $1 $2 ($3) . . ."
    eval_verbose make kernel KERNEL=$2 OPT=$3 DIM=$DIM ROCPROF_ONLY=$ROCPROF_ONLY TILE_SIZE=$block_size -B
    eval_verbose make $1 KERNEL=$2 OPT=$3 DIM=$DIM ROCPROF_ONLY=$ROCPROF_ONLY TILE_SIZE=$block_size
    check_error "compilation failed"
}

set_call_args()
{
    PB_SIZE=$1
    BLOCK_DIM=$2
    GRID_DIM=$3
    NB_REP=$4
    NWU=$5
}

log_printf "============== OMNIBENCH =============="

WORKDIR=`realpath $(dirname $0)`
TMPDIR="$WORKDIR/tmp"
RESULTDIR="$WORKDIR/results"
mkdir -p "$TMPDIR"
mkdir -p "$RESULTDIR"
cd "$WORKDIR"

make clean

run_command "$@"

rm "$TMPDIR" -rf
log_printf "================= END ================="

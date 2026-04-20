#!/bin/bash
NUM_CORE=${1:-1}
NUM_THREAD=${2:-1}
MODE=${3:-fread} # Default to fread
PAGE_FAULT_RATIO=${4:-0} # Default to 0
RESULT_DIR=${5:-result}
TEST_FILE="/mnt/raid0/test_file"

mkdir -p "$RESULT_DIR"
OUTPUT_FILE="${RESULT_DIR}/latency_granular_output_${MODE}_${NUM_CORE}_${NUM_THREAD}_pf${PAGE_FAULT_RATIO}.txt"

# Clear the output file
> "$OUTPUT_FILE"

if [ "$MODE" == "mmap" ]; then
    BT_FILE="latency_granular_mmap.bt"
    BINARY="./ssd_test_mmap"
    EXTRA_ARGS="$PAGE_FAULT_RATIO"
else
    BT_FILE="latency_granular_fread.bt"
    BINARY="./ssd_test_fread"
    EXTRA_ARGS="$PAGE_FAULT_RATIO"
fi

# Ensure binaries exist
if [ ! -f "$BINARY" ]; then
    echo "Binary $BINARY not found. Running make..." | tee -a "$OUTPUT_FILE"
    make all >> "$OUTPUT_FILE" 2>&1
fi

if [ ! -f "$TEST_FILE" ]; then
    echo "Test file $TEST_FILE not found. Creating 1TB file..." | tee -a "$OUTPUT_FILE"
    fallocate -l 1T "$TEST_FILE" || dd if=/dev/zero of="$TEST_FILE" bs=1M count=1048576 >> "$OUTPUT_FILE" 2>&1
fi

echo "Running $MODE test on RAID0 ($TEST_FILE) with $NUM_CORE cores and $NUM_THREAD threads (PF Ratio: $PAGE_FAULT_RATIO)..." | tee -a "$OUTPUT_FILE"
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

# Start bpftrace
sudo bpftrace "$BT_FILE" >> "$OUTPUT_FILE" 2>&1 &
BPF_PID=$!
sleep 5

# Run the binary and capture output
echo "--- Binary Output Start ---" | tee -a "$OUTPUT_FILE"
"$BINARY" "$TEST_FILE" 10 $NUM_THREAD $NUM_CORE $EXTRA_ARGS 2>&1 | tee -a "$OUTPUT_FILE"
echo "--- Binary Output End ---" | tee -a "$OUTPUT_FILE"

sleep 2
sudo kill -INT $BPF_PID
wait $BPF_PID 2>/dev/null

# Clean up internal maps from output and display
sed -i '/@start_/d' "$OUTPUT_FILE"
echo "------------------------------------------"
cat "$OUTPUT_FILE"
echo "------------------------------------------"

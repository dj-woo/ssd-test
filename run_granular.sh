#!/bin/bash
NUM_CORE=${1:-1}
NUM_THREAD=${2:-1}
MODE=${3:-fread} # Default to fread
OUTPUT_FILE="latency_granular_output_${MODE}_${NUM_CORE}_${NUM_THREAD}.txt"

if [ "$MODE" == "mmap" ]; then
    SOURCE="ssd_test_mmap.cpp"
else
    SOURCE="ssd_test.cpp"
fi

g++ -pthread -std=c++17 -o ssd_test "$SOURCE"

if [ ! -f test_file ]; then
    echo "Generating 10GB test_file..."
    fallocate -l 10G test_file || dd if=/dev/zero of=test_file bs=1M count=10240
fi

echo "Running $MODE test with $NUM_CORE cores and $NUM_THREAD threads..."
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
sudo bpftrace latency_granular.bt > "$OUTPUT_FILE" 2>&1 &
BPF_PID=$!
sleep 5
./ssd_test test_file 10 $NUM_THREAD $NUM_CORE | tee -a "$OUTPUT_FILE"
sleep 2
sudo kill -INT $BPF_PID
wait $BPF_PID 2>/dev/null
grep -v "@start_" "$OUTPUT_FILE"

#!/bin/bash
TEST_FILE="/mnt/raid0/test_file"

if command -v g++ >/dev/null 2>&1; then
    echo "Compiling ssd_test_fread.cpp..."
    g++ -O3 -pthread -std=c++17 -o ssd_test_fread ssd_test_fread.cpp
fi

if [ ! -f "$TEST_FILE" ]; then
    echo "Creating 1TB test file..."
    fallocate -l 1T "$TEST_FILE"
fi

echo "Dropping caches..."
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
echo "Starting bpftrace..."
sudo bpftrace latency_fread.bt > latency_output.txt 2>&1 &
BPF_PID=$!
sleep 2
echo "Running workload..."
./ssd_test_fread "$TEST_FILE" 10 1 1
echo "Stopping bpftrace and gathering results..."
sleep 1
sudo kill -INT $BPF_PID
wait $BPF_PID 2>/dev/null
echo "------------------------------------------"
cat latency_output.txt
echo "------------------------------------------"

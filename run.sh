#!/bin/bash

# 1. Compile without optimization
echo "Compiling ssd_test.cpp (no optimization)..."
g++ -pthread -std=c++17 -o ssd_test ssd_test.cpp

# 2. Prepare environment
echo "Dropping caches..."
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

# 3. Start tracing in background
echo "Starting bpftrace..."
sudo bpftrace latency.bt > latency_output.txt 2>&1 &
BPF_PID=$!

# Wait for bpftrace to attach probes
sleep 2

# 4. Run the workload
echo "Running workload..."
./ssd_test test_file 10 1 1

# 5. Cleanup and Show results
echo "Stopping bpftrace and gathering results..."
sleep 1
sudo kill -INT $BPF_PID
wait $BPF_PID 2>/dev/null

echo "------------------------------------------"
cat latency_output.txt
echo "------------------------------------------"

#!/bin/bash
g++ -pthread -std=c++17 -o ssd_test ssd_test.cpp
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
sudo bpftrace latency_granular.bt > latency_granular_output.txt 2>&1 &
BPF_PID=$!
sleep 5
./ssd_test test_file 10 1 1
sleep 2
sudo kill -INT $BPF_PID
wait $BPF_PID 2>/dev/null
grep -v "@start_" latency_granular_output.txt

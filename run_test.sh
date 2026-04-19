#!/bin/bash
chmod +x run_granular.sh

echo "Starting benchmark suite (fread and mmap)..."

for mode in fread mmap; do
    echo "======================================"
    echo "Testing Mode: $mode"
    echo "======================================"
    ./run_granular.sh 1 1 $mode
    ./run_granular.sh 1 2 $mode
    ./run_granular.sh 2 2 $mode
    ./run_granular.sh 2 4 $mode
done

echo "All tests completed."

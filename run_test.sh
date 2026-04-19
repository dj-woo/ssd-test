#!/bin/bash
chmod +x run_granular.sh

echo "Starting benchmark suite..."

./run_granular.sh 1 1
./run_granular.sh 1 2
./run_granular.sh 2 2
./run_granular.sh 2 4

echo "All tests completed."

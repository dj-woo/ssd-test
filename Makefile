CXX = g++
CXXFLAGS = -O3 -pthread -std=c++17
BINARIES = ssd_test_fread ssd_test_mmap
SCRIPTS = run_granular.sh run_fread.sh run_mmap.sh run_granular_fread.sh run_granular_mmap.sh

# Benchmark parameters
# PF_RATIOS = 0.0 0.2 0.4 0.6 0.8 1.0
PF_RATIOS = 0.0 0.5 1.0
CONFIGS = 1:1 1:2 2:2 2:4 4:4 4:8
RESULT_DIR = result

.PHONY: all clean test test_fread test_mmap analyze

all: $(BINARIES)

ssd_test_fread: ssd_test_fread.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

ssd_test_mmap: ssd_test_mmap.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

test: test_fread test_mmap
	@echo "All tests completed. Results are in $(RESULT_DIR)/"

test_fread: ssd_test_fread
	@echo "Running benchmark suite for fread with page fault variations..."
	@for pf in $(PF_RATIOS); do \
		echo "--- Testing fread with Page Fault Ratio: $$pf ---"; \
		for cfg in $(CONFIGS); do \
			core=$${cfg%:*}; \
			thread=$${cfg#*:}; \
			./run_granular.sh $$core $$thread fread $$pf $(RESULT_DIR); \
		done; \
	done

test_mmap: ssd_test_mmap
	@echo "Running benchmark suite for mmap with page fault variations..."
	@for pf in $(PF_RATIOS); do \
		echo "--- Testing mmap with Page Fault Ratio: $$pf ---"; \
		for cfg in $(CONFIGS); do \
			core=$${cfg%:*}; \
			thread=$${cfg#*:}; \
			./run_granular.sh $$core $$thread mmap $$pf $(RESULT_DIR); \
		done; \
	done

analyze:
	python3 analyze_results.py --input_dir $(RESULT_DIR)

clean:
	rm -f $(BINARIES)
	rm -rf $(RESULT_DIR)
	rm -f latency_output.txt latency_output_mmap.txt
	@echo "Cleaned up binaries and results directory."

# Project: NVMe SSD Kernel Stack Analysis

This project provides a C++ application and a strategy for analyzing the Linux kernel storage stack during SSD access.

## Goals
1.  **Workload Generation:** High-performance, multi-threaded random read workload with CPU affinity to stress the block layer.
2.  **Kernel Tracing:** Use `ftrace`, `blktrace`, and `bpftrace` to map the execution path from the VFS layer down to the NVMe driver.

## Project Structure
- `ssd_test.cpp`: Multi-threaded random read test application.
- `ssd_test`: Compiled binary.
- `todo.md`: Implementation plan and tracing command reference.
- `test_file`: 1GB test file (ignored by git).

## Usage
### 1. Compilation
```bash
g++ -O3 -pthread -std=c++17 -o ssd_test ssd_test.cpp
```

### 2. Execution
Run a test for 30 seconds with 4 threads pinned across 4 cores:
```bash
./ssd_test <target_file> 30 4 4
```

## Tracing Workflows
Detailed tracing commands are located in `todo.md`. Use these tools to capture:
- **Syscalls:** `strace -c`
- **Function Path:** `trace-cmd record -p function_graph`
- **Block Events:** `blktrace`
- **Latencies:** `bpftrace`

## Conventions
- Ensure `target_file` is located on an NVMe mount point for accurate driver analysis.
- Use `sudo` for all tracing operations.

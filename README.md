# NVMe SSD Software Stack Latency Analysis

This project provides tools to measure and analyze the latency across different layers of the Linux storage stack during SSD read operations.

## 1. Execution Scripts

### `run.sh`
The standard execution script for a high-level overview of the stack.
*   **Compilation**: Compiles `ssd_test.cpp` without optimizations to capture baseline software overhead.
*   **Preparation**: Drops the Linux Page Cache (`drop_caches`) to ensure reads hit the SSD.
*   **Tracing**: Runs a 4-probe `bpftrace` script.
*   **Workload**: Executes a 10-second random read test on a single core.

### `run_granular.sh`
The detailed execution script that breaks down the stack into 6 distinct layers.
*   **Layers Captured**: User Space, VFS, File System (EXT4), Block Layer, and Driver/SSD.
*   **Filter**: Automatically filters out "in-flight" request data to provide a clean report.

---

## 2. Output Analysis (`latency_granular_output.txt`)

The output consists of **Averages** and **Histograms** for each layer, measured in **nanoseconds (ns)**.

### Layer Definitions
1.  **`@avg_1_user_space_ns`**: Time spent in the application (User Space) preparing the `fread()` call before entering the kernel.
2.  **`@avg_2_vfs_layer_ns`**: Overhead of the Virtual File System (VFS) layer (syscall entry, permissions).
3.  **`@avg_3_filesystem_ns`**: Time spent in the File System (EXT4) translating file offsets to logical blocks.
4.  **`@avg_4_block_layer_ns`**: Time spent in the kernel's Block Layer (scheduling, queuing, BIO merging).
5.  **`@avg_5_driver_ssd_ns`**: The "Hardware" time. Combined latency of the VirtIO/NVMe driver and the physical SSD hardware.

### How to Analyze the Histogram
The histogram (e.g., `@latency_3_filesystem_ns`) uses power-of-two buckets:
*   `[1K, 2K)`: Count of operations that took between 1,024ns and 2,048ns (1µs - 2µs).
*   `[64K, 128K)`: Count of operations that took between 64µs and 128µs.

### Analysis Tips
*   **Dominant Latency**: Compare `@avg_5` (SSD) with the others. Typically, the SSD accounts for >90% of total latency.
*   **Software Bloat**: If `@avg_3` (FileSystem) or `@avg_4` (Block) increase significantly, it may indicate CPU bottlenecks or filesystem fragmentation.
*   **Tail Latency**: Look for counts in the high-value buckets (e.g., `[1M, 2M)` or higher). These represent "outliers" or lag spikes in the software stack or hardware.

---

## Usage
```bash
# Run the granular analysis
./run_granular.sh

# Results will be displayed and saved to latency_granular_output.txt
```

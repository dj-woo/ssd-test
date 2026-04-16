# NVMe SSD Stack Analysis Plan

## 1. Tool Installation
*   [ ] Install tracing tools: `sudo apt-get update && sudo apt-get install -y trace-cmd bpftrace strace blktrace`
*   [ ] Install compilation tools: `sudo apt-get install -y g++ build-essential`

## 2. C++ Application Development
*   [ ] **Create Test Application (`ssd_test.cpp`)**
    *   **Inputs:** `<target_file> <test_duration_sec> <num_thread> <num_cores>`
    *   **Logic:**
        *   Open the target file for reading (using standard buffered I/O, avoiding `O_DIRECT`).
        *   Initialize a high-resolution timer to run for `test_duration_sec`.
        *   Spawn `num_thread` worker threads.
        *   Use `pthread_setaffinity_np` to evenly pin threads across the specified `num_cores` (e.g., thread `i` pinned to core `i % num_cores`).
        *   Each thread performs concurrent random reads using `pread()` on randomly generated block-aligned offsets within the file boundaries.
        *   Track the total bytes read and the total read operations.
        *   After `test_duration_sec` elapses, signal threads to stop gracefully.
        *   Print aggregated statistics: Total IOPS, Throughput (MB/s).
*   [ ] **Compile Application:** `g++ -O3 -pthread -std=c++17 -o ssd_test ssd_test.cpp`

## 3. NVMe Kernel Stack Tracing Strategy
*   [ ] **Setup Target File:** Ensure a sufficiently large target file exists on the NVMe drive to minimize page cache hits and induce storage I/O.
*   [ ] **Execute Tracing:** Document and prepare the following tracing commands to be executed concurrently with the test application:
    *   **strace:** To capture system call overhead (`strace -c ./ssd_test ...`).
    *   **blktrace:** To capture block layer events for the NVMe device (`sudo blktrace -d /dev/nvme0n1 -o - | blkparse -i -`).
    *   **ftrace (via trace-cmd):** To capture function execution paths (`sudo trace-cmd record -p function_graph -l vfs_read -l blk_mq_submit_bio -l nvme_queue_rq -c ./ssd_test ...`).
    *   **bpftrace:** To profile specific kernel functions and measure I/O latency dynamically.

## 4. Verification
*   [ ] Verify the C++ application compiles and correctly distributes threads to the specified cores.
*   [ ] Verify that tracing tools capture the storage stack execution path down to the NVMe driver.
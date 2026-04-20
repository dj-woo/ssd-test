#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <unistd.h>
#include <sys/stat.h>
#include <random>
#include <pthread.h>
#include <iomanip>
#include <fcntl.h>

using namespace std;

struct ThreadStats {
    atomic<long long> total_reads{0};
    atomic<long long> total_bytes{0};
};

void worker(int id, string target_file, size_t file_size, int duration_sec, int num_cores, double page_fault_ratio, ThreadStats& stats, atomic<bool>& stop) {
    // Set thread affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(id % num_cores, &cpuset);
    pthread_t current_thread = pthread_self();
    if (pthread_setaffinity_np(current_thread, sizeof(cpu_set_t), &cpuset) != 0) {
        cerr << "Error setting affinity for thread " << id << endl;
    }

    // "don't use O_RDONLY" -> use "r+" which is O_RDWR
    FILE* fp = fopen(target_file.c_str(), "r+");
    if (!fp) {
        perror("fopen");
        return;
    }
    int fd = fileno(fp);

    const size_t block_size = 4096;
    char* buffer = new char[block_size];
    
    mt19937_64 rng(1337 + id);
    uniform_int_distribution<size_t> dist(0, (file_size - block_size) / block_size);
    uniform_real_distribution<double> fault_dist(0.0, 1.0);

    while (!stop.load()) {
        size_t offset = dist(rng) * block_size;
        
        // If page_fault_ratio > 0, randomly decide whether to force the kernel to drop the page from cache
        if (page_fault_ratio > 0.0 && fault_dist(rng) < page_fault_ratio) {
            // POSIX_FADV_DONTNEED tells the kernel to discard the data from the page cache.
            // Subsequent access will trigger a disk read (analogous to a page fault).
            posix_fadvise(fd, offset, block_size, POSIX_FADV_DONTNEED);
        }

        // Standard I/O buffer use
        if (fseeko(fp, offset, SEEK_SET) != 0) {
            perror("fseeko");
            break;
        }
        
        size_t bytes_read = fread(buffer, 1, block_size, fp);
        if (bytes_read > 0) {
            stats.total_reads++;
            stats.total_bytes += bytes_read;
        } else if (ferror(fp)) {
            perror("fread");
            break;
        }
    }

    delete[] buffer;
    fclose(fp);
}

int main(int argc, char* argv[]) {
    if (argc < 5 || argc > 6) {
        cerr << "Usage: " << argv[0] << " <target_file> <duration_sec> <num_threads> <num_cores> [page_fault_ratio (0.0-1.0)]" << endl;
        return 1;
    }

    string target_file = argv[1];
    int duration_sec = stoi(argv[2]);
    int num_threads = stoi(argv[3]);
    int num_cores = stoi(argv[4]);
    double page_fault_ratio = (argc == 6) ? stod(argv[5]) : 0.0;

    if (page_fault_ratio < 0.0 || page_fault_ratio > 1.0) {
        cerr << "Error: page_fault_ratio must be between 0.0 and 1.0" << endl;
        return 1;
    }

    struct stat st;
    if (stat(target_file.c_str(), &st) < 0) {
        perror("stat");
        return 1;
    }
    size_t file_size = st.st_size;

    cout << "Starting test on " << target_file << " (" << file_size / (1024 * 1024) << " MB)" << endl;
    cout << "Threads: " << num_threads << ", Cores: " << num_cores << ", Duration: " << duration_sec << "s" << endl;
    cout << "Page Fault Ratio (posix_fadvise): " << fixed << setprecision(2) << page_fault_ratio << endl;
    cout << "Mode: Standard I/O (fread), Mode: r+ (O_RDWR), No Optimization" << endl;

    ThreadStats stats;
    atomic<bool> stop{false};
    vector<thread> threads;

    auto start_time = chrono::high_resolution_clock::now();

    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([=, &stats, &stop]() {
            worker(i, target_file, file_size, duration_sec, num_cores, page_fault_ratio, stats, stop);
        });
    }

    this_thread::sleep_for(chrono::seconds(duration_sec));
    stop.store(true);

    for (auto& t : threads) {
        t.join();
    }

    auto end_time = chrono::high_resolution_clock::now();
    chrono::duration<double> diff = end_time - start_time;

    double iops = stats.total_reads.load() / diff.count();
    double throughput = (stats.total_bytes.load() / (1024.0 * 1024.0)) / diff.count();

    cout << fixed << setprecision(2);
    cout << "\nResults:" << endl;
    cout << "Total Reads: " << stats.total_reads.load() << endl;
    cout << "IOPS: " << iops << endl;
    cout << "Throughput: " << throughput << " MB/s" << endl;
    cout << "Actual Duration: " << diff.count() << "s" << endl;

    return 0;
}

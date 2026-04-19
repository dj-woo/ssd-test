#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <random>
#include <pthread.h>
#include <iomanip>
#include <cstring>

using namespace std;

struct ThreadStats {
    atomic<long long> total_reads{0};
    atomic<long long> total_bytes{0};
};

void worker(int id, char* mapped_data, size_t file_size, int duration_sec, int num_cores, ThreadStats& stats, atomic<bool>& stop) {
    // Set thread affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(id % num_cores, &cpuset);
    pthread_t current_thread = pthread_self();
    if (pthread_setaffinity_np(current_thread, sizeof(cpu_set_t), &cpuset) != 0) {
        cerr << "Error setting affinity for thread " << id << endl;
    }

    const size_t block_size = 4096;
    char buffer[block_size];
    
    mt19937_64 rng(1337 + id);
    uniform_int_distribution<size_t> dist(0, (file_size - block_size) / block_size);

    while (!stop.load()) {
        size_t offset = dist(rng) * block_size;
        
        // Simulate a read by copying from mapped memory
        // This triggers page faults if the data isn't in memory
        memcpy(buffer, mapped_data + offset, block_size);
        
        stats.total_reads++;
        stats.total_bytes += block_size;
    }
}

int main(int argc, char* argv[]) {
    if (argc != 5) {
        cerr << "Usage: " << argv[0] << " <target_file> <duration_sec> <num_threads> <num_cores>" << endl;
        return 1;
    }

    string target_file = argv[1];
    int duration_sec = stoi(argv[2]);
    int num_threads = stoi(argv[3]);
    int num_cores = stoi(argv[4]);

    int fd = open(target_file.c_str(), O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    struct stat st;
    if (fstat(fd, &st) < 0) {
        perror("fstat");
        close(fd);
        return 1;
    }
    size_t file_size = st.st_size;

    char* mapped_data = (char*)mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);
    if (mapped_data == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 1;
    }

    cout << "Starting test (mmap) on " << target_file << " (" << file_size / (1024 * 1024) << " MB)" << endl;
    cout << "Threads: " << num_threads << ", Cores: " << num_cores << ", Duration: " << duration_sec << "s" << endl;
    cout << "Mode: mmap (memcpy from mapped memory)" << endl;

    ThreadStats stats;
    atomic<bool> stop{false};
    vector<thread> threads;

    auto start_time = chrono::high_resolution_clock::now();

    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([=, &stats, &stop]() {
            worker(i, mapped_data, file_size, duration_sec, num_cores, stats, stop);
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

    munmap(mapped_data, file_size);
    close(fd);

    return 0;
}

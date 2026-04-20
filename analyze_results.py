import os
import re
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats

def parse_size(size_str):
    size_str = size_str.strip().upper()
    if size_str.endswith('K'): return int(size_str[:-1]) * 1024
    if size_str.endswith('M'): return int(size_str[:-1]) * 1024 * 1024
    if size_str.endswith('G'): return int(size_str[:-1]) * 1024 * 1024 * 1024
    return int(size_str)

def parse_histogram(content, hist_name):
    pattern = rf"@{hist_name}: \s*\n(.*?)\n\n"
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        pattern = rf"@{hist_name}: \s*\n(.*?)$"
        match = re.search(pattern, content, re.DOTALL)
        if not match: return []

    lines = match.group(1).splitlines()
    data = []
    for line in lines:
        m = re.match(r"\[(\d+\w*),\s*(\d+\w*)\)\s+(\d+)", line.strip())
        if m:
            low = parse_size(m.group(1))
            high = parse_size(m.group(2))
            count = int(m.group(3))
            if count > 0:
                data.append((low, high, count))
    return data

def reconstruct_samples(hist_data):
    samples = []
    for low, high, count in hist_data:
        val = np.sqrt(float(low) * float(high))
        samples.extend([val] * count)
    return np.array(samples)

def get_stats(samples):
    if len(samples) == 0:
        return { 'count': 0, 'avg': 0, 'std': 0, 'p50': 0, 'p90': 0, 'p99': 0, 'p999': 0, 'trimmed_mean': 0 }
    
    return {
        'count': len(samples),
        'avg': np.mean(samples),
        'std': np.std(samples),
        'p50': np.percentile(samples, 50),
        'p90': np.percentile(samples, 90),
        'p99': np.percentile(samples, 99),
        'p999': np.percentile(samples, 99.9),
        'trimmed_mean': stats.trim_mean(samples, 0.01)
    }

def generate_plot(stages, plot_data, title, output_path):
    plt.figure(figsize=(15, 10))
    plot_labels = [s[0] for s in stages]
    combined_samples = []
    for stage_name in plot_labels:
        if stage_name in plot_data and len(plot_data[stage_name]) > 0:
            combined_samples.append(np.concatenate(plot_data[stage_name]))
        else:
            combined_samples.append(np.array([1]))

    plt.boxplot(combined_samples, labels=plot_labels, whis=[0, 99], showfliers=False, patch_artist=True)
    plt.yscale('log')
    plt.ylabel('Latency (ns)')
    plt.title(title)
    plt.grid(True, which="both", ls="-", alpha=0.2)

    for i, stage_name in enumerate(plot_labels):
        samples = combined_samples[i]
        if len(samples) <= 1 and samples[0] == 1: continue
        
        p50 = np.percentile(samples, 50)
        p99 = np.percentile(samples, 99)
        p999 = np.percentile(samples, 99.9)
        t_mean = stats.trim_mean(samples, 0.01)

        plt.scatter(i + 1, p999, color='red', marker='x', label='P99.9' if i == 0 else "")
        plt.scatter(i + 1, t_mean, color='green', marker='o', label='1% Trimmed Mean' if i == 0 else "")
        plt.text(i + 1.1, p50, f'P50: {p50:.0f}', verticalalignment='center', fontsize=9)
        plt.text(i + 1.1, p99, f'P99: {p99:.0f}', verticalalignment='bottom', fontsize=9, color='blue')

    handles, labels = plt.gca().get_legend_handles_labels()
    if labels:
        plt.legend()
    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()

def generate_stacked_bar(df, output_path):
    # Filter out context switch and user space, and group by case
    # Case is mode, cores, threads, pf
    exclude_stages = ['1_user_space', '6_context_switch']
    plot_df = df[~df['stage'].isin(exclude_stages)].copy()
    
    # Create a 'case' label
    plot_df['case'] = plot_df.apply(lambda r: f"{r['mode']}\n{r['cores']}c{r['threads']}t\nPF:{r['pf']}", axis=1)
    
    # Pivot to get stages as columns and cases as rows
    pivot_df = plot_df.pivot(index='case', columns='stage', values='p50')
    
    # Ensure correct order of stages
    stage_order = [
        '2_kernel_entry',
        '3_filesystem',
        '4_block_layer',
        '5_driver_ssd'
    ]
    pivot_df = pivot_df[stage_order]

    ax = pivot_df.plot(kind='bar', stacked=True, figsize=(20, 10), width=0.8)
    plt.title('P50 Latency Breakdown by Test Case (excluding Context Switch)')
    plt.ylabel('P50 Latency (ns)')
    plt.xlabel('Test Case')
    plt.xticks(rotation=0)
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.legend(title='Stages', bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()

def main():
    parser = argparse.ArgumentParser(description='Analyze SSD Latency results')
    parser.add_argument('--input_dir', type=str, default='result', help='Directory containing benchmark result files')
    args = parser.parse_args()

    input_dir = args.input_dir
    if not os.path.exists(input_dir):
        print(f"Error: Directory '{input_dir}' does not exist.")
        return

    plots_dir = os.path.join(input_dir, 'plots')
    os.makedirs(plots_dir, exist_ok=True)

    files = [f for f in os.listdir(input_dir) if f.startswith('latency_granular_output_') and f.endswith('.txt')]
    all_results = []
    
    stages = [
        ('1_user_space', ['latency_1_user_space_ns']),
        ('2_kernel_entry', ['latency_2_vfs_layer_ns', 'latency_2_kernel_entry_ns']),
        ('3_filesystem', ['latency_3_filesystem_ns']),
        ('4_block_layer', ['latency_4_block_layer_ns']),
        ('5_driver_ssd', ['latency_5_driver_ssd_ns']),
        ('6_context_switch', ['latency_6_context_switch_ns'])
    ]

    global_plot_data = { s[0]: [] for s in stages }

    for filename in files:
        m = re.match(r"latency_granular_output_(?P<mode>\w+)_(?P<cores>\d+)_(?P<threads>\d+)_pf(?P<pf>[\d.]+)\.txt", filename)
        if not m: continue
        
        meta = m.groupdict()
        file_path = os.path.join(input_dir, filename)
        with open(file_path, 'r') as f:
            content = f.read()
        
        case_plot_data = { s[0]: [] for s in stages }
        has_data = False

        for stage_name, hist_names in stages:
            samples = np.array([])
            for hn in hist_names:
                hdata = parse_histogram(content, hn)
                if hdata:
                    reconstructed = reconstruct_samples(hdata)
                    samples = np.concatenate([samples, reconstructed])
            
            if len(samples) > 0:
                s_stats = get_stats(samples)
                res = {**meta, 'stage': stage_name, **s_stats}
                all_results.append(res)
                case_plot_data[stage_name].append(samples)
                global_plot_data[stage_name].append(samples)
                has_data = True
        
        if has_data:
            case_title = f"Mode: {meta['mode']}, Cores: {meta['cores']}, Threads: {meta['threads']}, PF: {meta['pf']}"
            case_plot_name = filename.replace('.txt', '.png')
            generate_plot(stages, case_plot_data, case_title, os.path.join(plots_dir, case_plot_name))

    df = pd.DataFrame(all_results)
    if df.empty:
        print(f"No valid data found in '{input_dir}' to analyze.")
        return

    df.to_csv(os.path.join(input_dir, 'summary_results.csv'), index=False)
    
    # Generate original global summary plot
    generate_plot(stages, global_plot_data, f'Global SSD Latency Summary (Source: {input_dir})', os.path.join(input_dir, 'latency_analysis.png'))
    
    # Generate new stacked bar chart
    generate_stacked_bar(df, os.path.join(input_dir, 'stacked_latency_summary.png'))
    
    print(f"Analysis complete. Reports saved to {input_dir}")

if __name__ == "__main__":
    main()

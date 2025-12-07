#!/usr/bin/env python3
"""
performance_advanced.py

Parallel CPU + GPU matmul benchmark with:
 - colored output (colorama)
 - GPU monitoring via nvidia-smi (if available)
 - parallel CPU+GPU execution (threads)
 - tqdm progress bar
 - adjustable tensor size (--size)
 - final visual summary (averages, speedup, ASCII bars)

Usage example:
  python3 performance_advanced.py --runtime 60 --size 1024 --poll 1

Dependencies:
  pip install torch tqdm colorama
(If you want GPU monitoring, ensure `nvidia-smi` is on PATH.)
"""

import argparse
import threading
import subprocess
import time
import sys
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from collections import deque

try:
    import torch
except Exception as e:
    print("ERROR: torch import failed. Make sure PyTorch is installed in this environment.")
    raise

try:
    from tqdm import tqdm
except Exception:
    print("ERROR: tqdm not installed. Run: pip install tqdm")
    raise

try:
    from colorama import init as colorama_init, Fore, Style
except Exception:
    print("ERROR: colorama not installed. Run: pip install colorama")
    raise

colorama_init(autoreset=True)

# -------------------------
# Helper: nvidia-smi polling
# -------------------------
def poll_nvidia_smi(poll_interval, stop_event, out_records):
    """
    Poll nvidia-smi every poll_interval seconds while stop_event not set.
    Append dicts to out_records.
    If nvidia-smi is not available, record nothing and exit.
    """
    # test nvidia-smi presence
    try:
        subprocess.run(["nvidia-smi", "-h"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except Exception:
        # nvidia-smi not available
        return

    query = [
        "nvidia-smi",
        "--query-gpu=index,utilization.gpu,memory.used,temperature.gpu,power.draw",
        "--format=csv,noheader,nounits"
    ]

    while not stop_event.is_set():
        try:
            out = subprocess.check_output(query, encoding="utf-8")
            # entries per GPU line
            ts = datetime.utcnow().isoformat() + "Z"
            for line in out.strip().splitlines():
                # index, util, mem, temp, power
                parts = [p.strip() for p in line.split(",")]
                if len(parts) >= 5:
                    rec = {
                        "timestamp": ts,
                        "gpu_index": int(parts[0]),
                        "util_percent": float(parts[1]),
                        "mem_MiB": float(parts[2]),
                        "temp_C": float(parts[3]),
                        "power_W": float(parts[4]),
                    }
                    out_records.append(rec)
        except Exception:
            # swallow transient errors
            pass
        stop_event.wait(poll_interval)

# -------------------------
# Worker functions
# -------------------------
def gpu_worker(stop_event, size, results, progress_queue=None):
    """Run matmul loops on GPU until stop_event set. Append durations (ms) to results list."""
    device = torch.device("cuda")
    torch.cuda.init() if hasattr(torch.cuda, 'init') else None
    # Pre-allocate tensors outside loop to avoid measuring allocation time each iteration
    a = torch.randn(size, size, device=device)
    b = a.t().contiguous()  # shape (size, size)
    while not stop_event.is_set():
        start = time.perf_counter()
        # matmul
        c = torch.matmul(a, b)
        # ensure completion
        torch.cuda.synchronize()
        dur_ms = (time.perf_counter() - start) * 1000.0
        results.append(dur_ms)
        if progress_queue is not None:
            progress_queue.append(('gpu', dur_ms))

def cpu_worker(stop_event, size, results, progress_queue=None):
    """Run matmul loops on CPU until stop_event set. Append durations (ms) to results list."""
    device = torch.device("cpu")
    a = torch.randn(size, size, device=device)
    b = a.t().contiguous()
    while not stop_event.is_set():
        start = time.perf_counter()
        c = torch.matmul(a, b)
        dur_ms = (time.perf_counter() - start) * 1000.0
        results.append(dur_ms)
        if progress_queue is not None:
            progress_queue.append(('cpu', dur_ms))

# -------------------------
# ASCII bar helper
# -------------------------
def ascii_bar(value, max_value, width=40):
    if max_value <= 0:
        return ""
    filled = int((value / max_value) * width)
    return "[" + "#" * filled + "-" * (width - filled) + "]"

# -------------------------
# Main
# -------------------------
def main(args):
    runtime = args.runtime
    size = args.size
    poll_interval = args.poll
    run_cpu = True
    run_gpu = torch.cuda.is_available()

    print(Style.BRIGHT + "PyTorch version: " + torch.__version__)
    print(f"Requested runtime: {runtime}s, tensor size: {size}x{size}")
    print("Detected devices:", end=" ")
    if run_gpu:
        print(Fore.GREEN + "GPU (CUDA available)")
    else:
        print(Fore.YELLOW + "No GPU detected — CPU-only mode")

    # Data collectors
    cpu_results = []
    gpu_results = []
    gpu_monitoring = []  # list of dicts from nvidia-smi
    progress_events = deque(maxlen=1000)

    # Stop events
    stop_event = threading.Event()
    monitor_stop = threading.Event()

    # Start GPU monitor thread (if nvidia-smi present)
    monitor_thread = None
    try:
        # Launch only if nvidia-smi exists
        subprocess.run(["nvidia-smi", "-h"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        monitor_thread = threading.Thread(target=poll_nvidia_smi, args=(poll_interval, monitor_stop, gpu_monitoring), daemon=True)
        monitor_thread.start()
        has_nvidia_smi = True
        print(Fore.BLUE + f"Started GPU monitor (nvidia-smi) polling every {poll_interval}s")
    except Exception:
        has_nvidia_smi = False
        print(Fore.YELLOW + "nvidia-smi not available; GPU telemetry will not be recorded.")

    # Progress bar setup
    pbar = tqdm(total=runtime, desc="Elapsed", bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt}s")

    # We'll update progress bar in a separate thread to avoid blocking the workers
    def progress_updater():
        start_t = time.time()
        last = start_t
        while not stop_event.is_set():
            now = time.time()
            elapsed = now - start_t
            to_advance = int(elapsed) - int(last - start_t)
            # update by fractional seconds (tqdm accepts float in update)
            pbar.n = elapsed
            pbar.refresh()
            if elapsed >= runtime:
                break
            time.sleep(0.25)
        # finalize
        pbar.n = min(runtime, time.time() - start_t)
        pbar.refresh()
        pbar.close()

    # Launch workers in threads
    worker_threads = []
    with ThreadPoolExecutor(max_workers=2) as exe:
        # Start progress updater thread
        prog_thread = threading.Thread(target=progress_updater, daemon=True)
        prog_thread.start()

        futures = []
        if run_gpu:
            futures.append(exe.submit(gpu_worker, stop_event, size, gpu_results, progress_events))
            print(Fore.GREEN + "GPU worker started.")
        if run_cpu:
            futures.append(exe.submit(cpu_worker, stop_event, size, cpu_results, progress_events))
            print(Fore.CYAN + "CPU worker started.")

        # Run for requested runtime
        try:
            time.sleep(runtime)
        except KeyboardInterrupt:
            print(Fore.RED + "\nInterrupted by user — stopping early.")
        finally:
            # request stop
            stop_event.set()
            monitor_stop.set()

            # wait a short time for threads to finish
            for f in futures:
                # worker functions exit when stop_event is set; wait quickly
                try:
                    f.result(timeout=5)
                except Exception:
                    pass

            # ensure monitor thread stops
            if monitor_thread and monitor_thread.is_alive():
                monitor_thread.join(timeout=1)

            # make sure progress thread stops
            if prog_thread.is_alive():
                prog_thread.join(timeout=1)

    # Summarize raw counts
    cpu_count = len(cpu_results)
    gpu_count = len(gpu_results)
    print()
    print(Style.BRIGHT + "Raw iteration counts: CPU={}  GPU={}".format(cpu_count, gpu_count))

    # Compute stats
    def summarize(samples):
        if not samples:
            return {"count":0, "min":None, "max":None, "mean":None, "median":None, "stdev":None}
        return {
            "count": len(samples),
            "min": min(samples),
            "max": max(samples),
            "mean": statistics.mean(samples),
            "median": statistics.median(samples),
            "stdev": statistics.stdev(samples) if len(samples) > 1 else 0.0
        }

    cpu_stats = summarize(cpu_results)
    gpu_stats = summarize(gpu_results)

    # Print colored summary
    print(Style.BRIGHT + "=== Benchmark Summary ===")
    if cpu_stats["count"] > 0:
        print(Fore.YELLOW + "CPU  : samples={count}  mean={mean:.2f}ms  median={median:.2f}ms  stdev={stdev:.2f}ms".format(**cpu_stats))
    else:
        print(Fore.YELLOW + "CPU  : no samples")

    if run_gpu:
        if gpu_stats["count"] > 0:
            print(Fore.GREEN + "GPU  : samples={count}  mean={mean:.2f}ms  median={median:.2f}ms  stdev={stdev:.2f}ms".format(**gpu_stats))
        else:
            print(Fore.GREEN + "GPU  : no samples (maybe CUDA not initialized?)")
    # Speedup
    if cpu_stats["mean"] and gpu_stats["mean"]:
        speedup = cpu_stats["mean"] / gpu_stats["mean"]
        print(Style.BRIGHT + f"Measured CPU_mean / GPU_mean = {speedup:.2f}x speedup (higher = GPU faster)")
    else:
        print(Style.BRIGHT + "Speedup: N/A (insufficient samples)")

    # ASCII bar chart (normalize by min of means)
    print("\nVisual comparison (lower = faster):")
    # choose baseline = max(mean_cpu, mean_gpu) for bars scale or 1 if missing
    means = [m for m in (cpu_stats["mean"], gpu_stats["mean"]) if m is not None]
    max_mean = max(means) if means else 1.0
    if cpu_stats["mean"] is not None:
        print(Fore.YELLOW + "CPU " + ascii_bar(cpu_stats["mean"], max_mean) + f" {cpu_stats['mean']:.2f}ms")
    if run_gpu and gpu_stats["mean"] is not None:
        print(Fore.GREEN + "GPU " + ascii_bar(gpu_stats["mean"], max_mean) + f" {gpu_stats['mean']:.2f}ms")

    # Optional: brief telemetry summary
    if has_nvidia_smi and gpu_monitoring:
        print("\nGPU telemetry (sampled):")
        # aggregate per-gpu index: util percent mean and peak memory
        by_idx = {}
        for rec in gpu_monitoring:
            idx = rec["gpu_index"]
            by_idx.setdefault(idx, []).append(rec)
        for idx, recs in by_idx.items():
            util_vals = [r["util_percent"] for r in recs]
            mem_vals = [r["mem_MiB"] for r in recs]
            temp_vals = [r["temp_C"] for r in recs]
            power_vals = [r["power_W"] for r in recs if r["power_W"] is not None]
            print(Fore.BLUE + f" GPU#{idx}: util_mean={statistics.mean(util_vals):.1f}%  util_max={max(util_vals):.1f}%"
                  + f"  mem_max={max(mem_vals):.1f}MiB  temp_mean={statistics.mean(temp_vals):.1f}C"
                  + (f"  power_mean={statistics.mean(power_vals):.1f}W" if power_vals else ""))

    print("\nDone. To reproduce, run the script again with different --size or --runtime values.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parallel CPU+GPU matmul performance tester")
    parser.add_argument("--runtime", "-t", type=int, default=120, help="Total runtime in seconds (max 3600)")
    parser.add_argument("--size", "-s", type=int, default=1024, help="Square tensor size (e.g. 1024, 2048)")
    parser.add_argument("--poll", type=float, default=1.0, help="GPU telemetry poll interval in seconds (nvidia-smi)")
    args = parser.parse_args()

    if args.runtime < 1 or args.runtime > 3600:
        print("runtime must be between 1 and 3600 seconds")
        sys.exit(2)
    if args.size < 16 or args.size > 16384:
        print("size should be reasonable (16..16384)")
        sys.exit(2)

    main(args)

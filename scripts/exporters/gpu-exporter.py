#!/usr/bin/env python3
"""
GPU Metrics Exporter for Prometheus
Reads NVIDIA GPU metrics via nvidia-smi and exposes them as Prometheus metrics

Usage:
    python3 gpu-exporter.py

Metrics available at: http://localhost:9445/metrics
"""

import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler


class GPUHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        
        try:
            # GPU Utilization
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=5
            )
            util = result.stdout.strip().split('\n')[0].strip() if result.stdout else '0'
            self.wfile.write(f'# HELP nvidia_smi_utilization_gpu GPU utilization percentage\n'.encode())
            self.wfile.write(f'# TYPE nvidia_smi_utilization_gpu gauge\n'.encode())
            self.wfile.write(f'nvidia_smi_utilization_gpu{{gpu="0"}} {util}\n\n'.encode())
            
            # Memory Used (MiB -> bytes)
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=memory.used', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=5
            )
            mem_used = result.stdout.strip().split('\n')[0].strip().replace(' MiB', '') if result.stdout else '0'
            mem_used_bytes = int(mem_used) * 1024 * 1024
            self.wfile.write(f'# HELP nvidia_smi_memory_used_bytes GPU memory used in bytes\n'.encode())
            self.wfile.write(f'# TYPE nvidia_smi_memory_used_bytes gauge\n'.encode())
            self.wfile.write(f'nvidia_smi_memory_used_bytes{{gpu="0"}} {mem_used_bytes}\n\n'.encode())
            
            # Memory Total
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=memory.total', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=5
            )
            mem_total = result.stdout.strip().split('\n')[0].strip().replace(' MiB', '') if result.stdout else '0'
            mem_total_bytes = int(mem_total) * 1024 * 1024
            self.wfile.write(f'# HELP nvidia_smi_memory_total_bytes GPU memory total in bytes\n'.encode())
            self.wfile.write(f'# TYPE nvidia_smi_memory_total_bytes gauge\n'.encode())
            self.wfile.write(f'nvidia_smi_memory_total_bytes{{gpu="0"}} {mem_total_bytes}\n\n'.encode())
            
            # Temperature
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=temperature.gpu', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=5
            )
            temp = result.stdout.strip().split('\n')[0].strip() if result.stdout else '0'
            self.wfile.write(f'# HELP nvidia_smi_temperature_gpu GPU temperature in Celsius\n'.encode())
            self.wfile.write(f'# TYPE nvidia_smi_temperature_gpu gauge\n'.encode())
            self.wfile.write(f'nvidia_smi_temperature_gpu{{gpu="0"}} {temp}\n\n'.encode())
            
            # Power Draw
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=power.draw', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=5
            )
            power = result.stdout.strip().split('\n')[0].strip().replace(' W', '') if result.stdout else '0'
            self.wfile.write(f'# HELP nvidia_smi_power_draw_watts GPU power draw in Watts\n'.encode())
            self.wfile.write(f'# TYPE nvidia_smi_power_draw_watts gauge\n'.encode())
            self.wfile.write(f'nvidia_smi_power_draw_watts{{gpu="0"}} {power}\n\n'.encode())
            
            # Up metric
            self.wfile.write(f'# HELP nvidia_smi_up NVIDIA SMI exporter is up\n'.encode())
            self.wfile.write(f'# TYPE nvidia_smi_up gauge\n'.encode())
            self.wfile.write(f'nvidia_smi_up 1\n'.encode())
            
        except Exception as e:
            self.wfile.write(f'# Error: {e}\n'.encode())
            self.wfile.write(f'nvidia_smi_up 0\n'.encode())


if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 9445), GPUHandler)
    print('GPU Exporter running on http://127.0.0.1:9445/metrics')
    server.serve_forever()

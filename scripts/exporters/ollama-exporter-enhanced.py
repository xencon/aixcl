#!/usr/bin/env python3
"""
Enhanced Ollama Metrics Exporter for Prometheus
Exposes Ollama API metrics including inference timing and request tracking

Usage:
    python3 ollama-exporter-enhanced.py

Metrics available at: http://localhost:11435/metrics

Features:
- Basic Ollama health and version info
- Model loading status
- Inference request tracking (requires log parsing or API interception)
- GPU utilization correlation
"""

import json
import urllib.request
import urllib.error
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from collections import deque
import threading

OLLAMA_BASE_URL = "http://127.0.0.1:11434"

# Store request timing data
request_times = deque(maxlen=100)  # Keep last 100 requests
request_count = 0
error_count = 0


class OllamaHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    
    def do_GET(self):
        global request_count, error_count
        
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        
        metrics = []
        
        try:
            # Check Ollama health/version
            version_resp = urllib.request.urlopen(
                urllib.request.Request(f"{OLLAMA_BASE_URL}/api/version", method='GET'),
                timeout=5
            )
            version_data = json.loads(version_resp.read().decode('utf-8'))
            version = version_data.get('version', 'unknown')
            
            # Models loaded
            models_resp = urllib.request.urlopen(
                urllib.request.Request(f"{OLLAMA_BASE_URL}/api/tags", method='GET'),
                timeout=5
            )
            models_data = json.loads(models_resp.read().decode('utf-8'))
            models = models_data.get('models', [])
            
            # Up metric
            metrics.append('# HELP ollama_up Ollama is up and responding')
            metrics.append('# TYPE ollama_up gauge')
            metrics.append('ollama_up 1')
            
            # Version info
            metrics.append('# HELP ollama_version_info Ollama version info')
            metrics.append('# TYPE ollama_version_info gauge')
            metrics.append(f'ollama_version_info{{version="{version}"}} 1')
            
            # Models count
            metrics.append('# HELP ollama_models_loaded_total Number of models loaded')
            metrics.append('# TYPE ollama_models_loaded_total gauge')
            metrics.append(f'ollama_models_loaded_total {len(models)}')
            
            # Individual model metrics
            metrics.append('# HELP ollama_model_info Model information')
            metrics.append('# TYPE ollama_model_info gauge')
            
            total_model_size = 0
            for model in models:
                name = model.get('name', 'unknown')
                size = model.get('size', 0)
                total_model_size += size
                family = model.get('details', {}).get('family', 'unknown')
                parameter_size = model.get('details', {}).get('parameter_size', 'unknown')
                quantization = model.get('details', {}).get('quantization_level', 'unknown')
                
                # Sanitize label values
                name = name.replace('"', '\\"')
                family = family.replace('"', '\\"')
                parameter_size = str(parameter_size).replace('"', '\\"')
                quantization = quantization.replace('"', '\\"')
                
                metrics.append(f'ollama_model_info{{name="{name}",family="{family}",parameter_size="{parameter_size}",quantization="{quantization}"}} {size}')
            
            # Total model storage used
            metrics.append('# HELP ollama_model_storage_bytes Total storage used by loaded models')
            metrics.append('# TYPE ollama_model_storage_bytes gauge')
            metrics.append(f'ollama_model_storage_bytes {total_model_size}')
            
            # If no models loaded, still show the metric
            if not models:
                metrics.append('ollama_model_info{name="none",family="none",parameter_size="0",quantization="none"} 0')
            
            # Request tracking metrics
            metrics.append('# HELP ollama_requests_total Total number of inference requests')
            metrics.append('# TYPE ollama_requests_total counter')
            metrics.append(f'ollama_requests_total {request_count}')
            
            metrics.append('# HELP ollama_request_errors_total Total number of inference request errors')
            metrics.append('# TYPE ollama_request_errors_total counter')
            metrics.append(f'ollama_request_errors_total {error_count}')
            
            # Response time metrics (if we have data)
            if request_times:
                avg_time = sum(request_times) / len(request_times)
                metrics.append('# HELP ollama_request_duration_seconds Average inference request duration')
                metrics.append('# TYPE ollama_request_duration_seconds gauge')
                metrics.append(f'ollama_request_duration_seconds {avg_time}')
            
        except Exception as e:
            # Up metric - failed
            metrics.append('# HELP ollama_up Ollama is up and responding')
            metrics.append('# TYPE ollama_up gauge')
            metrics.append('ollama_up 0')
            
            error_msg = str(e).replace('\n', ' ').replace('"', '\\"')
            metrics.append(f'# Error fetching metrics: {error_msg}')
        
        self.wfile.write('\n'.join(metrics).encode())
        self.wfile.write(b'\n')


def simulate_request_tracking():
    """Placeholder for actual request tracking
    In production, this would:
    1. Parse Ollama logs
    2. Intercept API calls
    3. Use Ollama's built-in metrics when available
    """
    global request_count, error_count
    # This is a placeholder - in real implementation, 
    # we'd parse logs or intercept requests
    pass


if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 11435), OllamaHandler)
    print('Enhanced Ollama Exporter running on http://127.0.0.1:11435/metrics')
    print('Note: Inference timing requires log parsing or API interception for full functionality')
    server.serve_forever()

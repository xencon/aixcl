#!/usr/bin/env python3
"""
Ollama Metrics Exporter for Prometheus
Exposes Ollama API metrics: models loaded, version, inference stats

Usage:
    python3 ollama-exporter.py

Metrics available at: http://localhost:11435/metrics
"""

import json
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

OLLAMA_BASE_URL = "http://127.0.0.1:11434"


class OllamaHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    
    def do_GET(self):
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
            
            for model in models:
                name = model.get('name', 'unknown')
                size = model.get('size', 0)
                family = model.get('details', {}).get('family', 'unknown')
                parameter_size = model.get('details', {}).get('parameter_size', 'unknown')
                quantization = model.get('details', {}).get('quantization_level', 'unknown')
                
                # Sanitize label values
                name = name.replace('"', '\\"')
                family = family.replace('"', '\\"')
                parameter_size = str(parameter_size).replace('"', '\\"')
                quantization = quantization.replace('"', '\\"')
                
                metrics.append(f'ollama_model_info{{name="{name}",family="{family}",parameter_size="{parameter_size}",quantization="{quantization}"}} {size}')
            
            # If no models loaded, still show the metric
            if not models:
                metrics.append('ollama_model_info{name="none",family="none",parameter_size="0",quantization="none"} 0')
            
        except Exception as e:
            # Up metric - failed
            metrics.append('# HELP ollama_up Ollama is up and responding')
            metrics.append('# TYPE ollama_up gauge')
            metrics.append('ollama_up 0')
            
            error_msg = str(e).replace('\n', ' ').replace('"', '\\"')
            metrics.append(f'# Error fetching metrics: {error_msg}')
        
        self.wfile.write('\n'.join(metrics).encode())
        self.wfile.write(b'\n')


if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 11435), OllamaHandler)
    print('Ollama Exporter running on http://127.0.0.1:11435/metrics')
    server.serve_forever()

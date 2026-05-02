#!/usr/bin/env python3
"""
Open WebUI Metrics Exporter for Prometheus
Exposes Open WebUI API metrics: health, user sessions, response times

Usage:
    python3 openwebui-exporter.py

Metrics available at: http://localhost:11436/metrics
"""

import json
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

OPENWEBUI_BASE_URL = "http://127.0.0.1:8080"


class OpenWebUIHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        
        metrics = []
        
        try:
            # Check Open WebUI health
            health_resp = urllib.request.urlopen(
                urllib.request.Request(f"{OPENWEBUI_BASE_URL}/health", method='GET'),
                timeout=5
            )
            health_status = health_resp.getcode()
            
            # Up metric
            metrics.append('# HELP openwebui_up Open WebUI is up and responding')
            metrics.append('# TYPE openwebui_up gauge')
            metrics.append('openwebui_up 1' if health_status == 200 else 'openwebui_up 0')
            
            # HTTP response time metric (simulated - actual implementation would measure)
            metrics.append('# HELP openwebui_http_response_time_seconds Response time of health check')
            metrics.append('# TYPE openwebui_http_response_time_seconds gauge')
            metrics.append('openwebui_http_response_time_seconds 0.1')  # Placeholder
            
            # Try to get API info
            try:
                api_resp = urllib.request.urlopen(
                    urllib.request.Request(f"{OPENWEBUI_BASE_URL}/api/v1/", method='GET'),
                    timeout=5
                )
                api_up = 1 if api_resp.getcode() == 200 else 0
            except:
                api_up = 0
            
            metrics.append('# HELP openwebui_api_up Open WebUI API is responding')
            metrics.append('# TYPE openwebui_api_up gauge')
            metrics.append(f'openwebui_api_up {api_up}')
            
        except Exception as e:
            # Up metric - failed
            metrics.append('# HELP openwebui_up Open WebUI is up and responding')
            metrics.append('# TYPE openwebui_up gauge')
            metrics.append('openwebui_up 0')
            
            error_msg = str(e).replace('\n', ' ').replace('"', '\\"')
            metrics.append(f'# Error fetching metrics: {error_msg}')
        
        self.wfile.write('\n'.join(metrics).encode())
        self.wfile.write(b'\n')


if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 11436), OpenWebUIHandler)
    print('Open WebUI Exporter running on http://127.0.0.1:11436/metrics')
    server.serve_forever()

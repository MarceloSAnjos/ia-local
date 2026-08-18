#!/usr/bin/env python3
import subprocess
import urllib.request
import json

base_url = "http://127.0.0.1:8080"
print("==========================================================")
print("              Local AI Server Status")
print("==========================================================")

try:
    with urllib.request.urlopen(f"{base_url}/health", timeout=2) as r:
        st = json.loads(r.read().decode())
        print(f"[✓] Status:           RUNNING (Health: {st.get('status', 'ok')})")
        print(f"[✓] Endpoint:         {base_url}/v1")
except Exception:
    print("[!] Status:           NOT RESPONDING / STOPPED")
    print(f"[!] Endpoint:         {base_url}/v1")

try:
    out = subprocess.check_output(["pgrep", "-f", "llama-server"]).decode().strip().splitlines()
    for pid in out:
        rss_kb = int(subprocess.check_output(["ps", "-o", "rss=", "-p", pid]).decode().strip())
        print(f"[✓] Process PID:      {pid}")
        print(f"[✓] Memory (RAM):     {rss_kb / 1024.0:.1f} MB (~{rss_kb / (1024.0 * 1024.0):.2f} GB)")
except Exception:
    print("[*] No active llama-server process detected.")

print("==========================================================")

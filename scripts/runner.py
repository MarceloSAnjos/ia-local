#!/usr/bin/env python3
"""
Benchmark runner for Local AI Coding Lab.
Measures Time to First Token (TTFT), generation tokens/s, prompt processing tokens/s,
memory usage, and draft acceptance rate over OpenAI-compatible llama-server endpoint.
"""

import sys
import os
import time
import json
import argparse
import subprocess
import urllib.request
import urllib.error

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8080

DEFAULT_PROMPTS = [
    {
        "id": "lru_cache",
        "name": "Thread-safe LRU Cache (Python)",
        "language": "python",
        "prompt": "Implement a thread-safe LRU Cache in Python with O(1) get and put operations, using double linked list and hash map. Include complete unit tests using pytest."
    },
    {
        "id": "rest_router",
        "name": "Minimal Type-Safe REST Router (TypeScript)",
        "language": "typescript",
        "prompt": "Write a zero-dependency type-safe HTTP router in TypeScript supporting path parameters (e.g. /users/:id), middleware chains, and async handlers."
    },
    {
        "id": "worker_pool",
        "name": "Concurrent Worker Pool (Go)",
        "language": "go",
        "prompt": "Implement a robust concurrent worker pool in Go with worker scaling, context cancellation, graceful shutdown, and aggregated error reporting."
    }
]

def check_server_health(base_url, retries=15, delay=2):
    url = f"{base_url}/health"
    print(f"[*] Checking server health at {url}...")
    for i in range(retries):
        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=3) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode())
                    print(f"[✓] Server is ready! Status: {data.get('status', 'ok')}")
                    return True
        except Exception:
            time.sleep(delay)
    return False

def get_server_process_memory():
    """Gets RSS memory (MB) of llama-server processes."""
    try:
        out = subprocess.check_output(["pgrep", "-f", "llama-server"]).decode().strip()
        pids = out.splitlines()
        total_rss_kb = 0
        for pid in pids:
            ps_out = subprocess.check_output(["ps", "-o", "rss=", "-p", pid]).decode().strip()
            total_rss_kb += int(ps_out)
        return total_rss_kb / 1024.0
    except Exception:
        return 0.0

def run_completion_benchmark(base_url, prompt_item, temperature=0.2, max_tokens=1024):
    url = f"{base_url}/v1/chat/completions"
    payload = {
        "model": "default",
        "messages": [
            {"role": "system", "content": "You are an expert senior software engineer. Write clean, idiomatic, high-performance code with concise explanations."},
            {"role": "user", "content": prompt_item["prompt"]}
        ],
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": True,
        "stream_options": {"include_usage": True}
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

    start_time = time.perf_counter()
    first_token_time = None
    generated_chunks = []
    usage_info = {}

    memory_before = get_server_process_memory()

    with urllib.request.urlopen(req, timeout=120) as response:
        for line in response:
            line_str = line.decode("utf-8").strip()
            if not line_str or line_str == "data: [DONE]":
                continue
            if line_str.startswith("data: "):
                data_json_str = line_str[6:]
                try:
                    data = json.loads(data_json_str)
                    if "choices" in data and len(data["choices"]) > 0:
                        delta = data["choices"][0].get("delta", {})
                        content = delta.get("content", "")
                        if content:
                            if first_token_time is None:
                                first_token_time = time.perf_counter()
                            generated_chunks.append(content)
                    if "usage" in data and data["usage"]:
                        usage_info = data["usage"]
                except json.JSONDecodeError:
                    pass

    end_time = time.perf_counter()
    memory_after = get_server_process_memory()

    if first_token_time is None:
        first_token_time = end_time

    ttft_sec = first_token_time - start_time
    total_time_sec = end_time - start_time
    generation_time_sec = max(0.0001, end_time - first_token_time)

    # Tokens generated
    completion_tokens = usage_info.get("completion_tokens", len("".join(generated_chunks).split()))
    prompt_tokens = usage_info.get("prompt_tokens", len(prompt_item["prompt"].split()))

    gen_tok_per_sec = completion_tokens / generation_time_sec if generation_time_sec > 0 else 0
    prompt_eval_tok_per_sec = prompt_tokens / ttft_sec if ttft_sec > 0 else 0

    full_text = "".join(generated_chunks)

    # Query metrics from /props or /slots if available
    extra_stats = {}
    try:
        with urllib.request.urlopen(f"{base_url}/props", timeout=2) as p_resp:
            extra_stats = json.loads(p_resp.read().decode())
    except Exception:
        pass

    return {
        "prompt_id": prompt_item["id"],
        "prompt_name": prompt_item["name"],
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "ttft_ms": round(ttft_sec * 1000, 2),
        "total_time_s": round(total_time_sec, 2),
        "generation_time_s": round(generation_time_sec, 2),
        "gen_tok_per_sec": round(gen_tok_per_sec, 2),
        "prompt_tok_per_sec": round(prompt_eval_tok_per_sec, 2),
        "memory_rss_mb": round(max(memory_before, memory_after), 1),
        "output_sample": full_text[:300] + ("..." if len(full_text) > 300 else ""),
        "full_output": full_text
    }

def main():
    parser = argparse.ArgumentParser(description="Run benchmarks for local LLM")
    parser.add_argument("--mode", choices=["baseline", "speculative"], default="baseline")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--runs", type=int, default=1, help="Number of runs per prompt")
    parser.add_argument("--output-dir", default="benchmarks")
    args = parser.parse_args()

    base_url = f"http://{args.host}:{args.port}"
    if not check_server_health(base_url):
        print(f"[!] Server is not reachable at {base_url}. Make sure llama-server is running.")
        sys.exit(1)

    print(f"\n========================================================")
    print(f" Starting Benchmarks: Mode = {args.mode.upper()}")
    print(f" Target Speed Goal: >= 30.0 tok/s")
    print(f"========================================================\n")

    results = []

    for prompt_item in DEFAULT_PROMPTS:
        print(f"--> Testing prompt: [{prompt_item['name']}]")
        run_stats = []
        for r in range(args.runs):
            print(f"    Run {r+1}/{args.runs}...", end="", flush=True)
            res = run_completion_benchmark(base_url, prompt_item)
            run_stats.append(res)
            print(f" Done. Speed: {res['gen_tok_per_sec']} tok/s | TTFT: {res['ttft_ms']} ms | Tokens: {res['completion_tokens']}")
            time.sleep(1)

        # Average across runs
        avg_gen_speed = sum(s["gen_tok_per_sec"] for s in run_stats) / len(run_stats)
        avg_ttft = sum(s["ttft_ms"] for s in run_stats) / len(run_stats)
        avg_prompt_tokens = sum(s["prompt_tokens"] for s in run_stats) / len(run_stats)
        avg_comp_tokens = sum(s["completion_tokens"] for s in run_stats) / len(run_stats)
        avg_mem = sum(s["memory_rss_mb"] for s in run_stats) / len(run_stats)

        results.append({
            "prompt_id": prompt_item["id"],
            "prompt_name": prompt_item["name"],
            "avg_gen_tok_s": round(avg_gen_speed, 2),
            "avg_ttft_ms": round(avg_ttft, 2),
            "avg_prompt_tokens": round(avg_prompt_tokens, 1),
            "avg_completion_tokens": round(avg_comp_tokens, 1),
            "memory_rss_mb": round(avg_mem, 1),
            "sample_output": run_stats[0]["output_sample"],
            "runs": run_stats
        })

    overall_avg_tok_s = round(sum(r["avg_gen_tok_s"] for r in results) / len(results), 2)
    overall_avg_ttft = round(sum(r["avg_ttft_ms"] for r in results) / len(results), 2)
    overall_max_ram = max(r["memory_rss_mb"] for r in results)

    meets_goal = overall_avg_tok_s >= 30.0

    summary = {
        "mode": args.mode,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "overall_avg_tok_s": overall_avg_tok_s,
        "overall_avg_ttft_ms": overall_avg_ttft,
        "peak_ram_mb": overall_max_ram,
        "target_goal_30_tok_s_met": meets_goal,
        "results": results
    }

    # Save to disk
    out_dir = os.path.join(args.output_dir, args.mode)
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, f"benchmark_{int(time.time())}.json")
    latest_json_path = os.path.join(out_dir, "latest.json")

    with open(json_path, "w") as f:
        json.dump(summary, f, indent=2)
    with open(latest_json_path, "w") as f:
        json.dump(summary, f, indent=2)

    # Print markdown table
    print("\n========================================================")
    print(f" BENCHMARK SUMMARY ({args.mode.upper()})")
    print("========================================================")
    print(f"| Prompt | Avg Speed (tok/s) | TTFT (ms) | Output Tokens | RAM (MB) |")
    print(f"|---|---|---|---|---|")
    for r in results:
        print(f"| {r['prompt_name']} | {r['avg_gen_tok_s']} tok/s | {r['avg_ttft_ms']} ms | {r['avg_completion_tokens']} | {r['memory_rss_mb']} MB |")
    print("--------------------------------------------------------")
    print(f"Overall Generation Speed: {overall_avg_tok_s} tok/s")
    print(f"Overall Avg TTFT:         {overall_avg_ttft} ms")
    print(f"Peak Server RAM:          {overall_max_ram} MB")
    print(f"Goal >= 30 tok/s Met:     {'[✓] YES' if meets_goal else '[✗] NO'}")
    print(f"Saved results to:         {latest_json_path}")
    print("========================================================\n")

if __name__ == "__main__":
    main()

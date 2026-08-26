#!/usr/bin/env python3
"""
Multi-Model CLI for Local AI Coding Lab.
Supports: OpenCode + Local GGUF models OR Direct Hugging Face inference.
"""

import sys
import os
import json
import argparse
import subprocess
import urllib.request
import urllib.error
import yaml
from pathlib import Path

# Try to import HTTP clients
try:
    import httpx
    HTTP_CLIENT = httpx
except ImportError:
    HTTP_CLIENT = None

try:
    import requests
    HTTP_CLIENT = requests
except ImportError:
    HTTP_CLIENT = None


class MultiModelCLI:
    def __init__(self, config_path="config.yaml"):
        self.config_path = Path(config_path)
        self.config = self.load_config()
        self.models = self.discover_models()
    
    def load_config(self):
        """Load configuration from YAML file."""
        if not os.path.exists(self.config_path):
            return {}
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            print(f"[!] Error loading config: {e}")
            return {}
    
    def discover_models(self):
        """Discover available models in the models directory."""
        models = {}
        models_dir = Path(self.config_path).parent / "models"
        if not models_dir.exists():
            return models
        
        for file in models_dir.glob("*.gguf"):
            model_name = file.stem
            models[model_name] = {
                "path": str(file),
                "size_mb": file.stat().st_size / (1024 * 1024),
                "local": True
            }
        
        return models
    
    def list_models(self):
        """Print available models."""
        print("\n" + "="*60)
        print("  Available Models:")
        print("="*60)
        
        if not self.models:
            print("  No local models found.")
            return
        
        print(f"  {'Name':<25} {'Size':<15} {'Type':<8}")
        print("-"*50)
        for name, info in self.models.items():
            print(f"  {name:<25} {info['size_mb']:.1f} MB {'Local':<8}")
        
        print("\n  Local models discovered from:", self.config_path.parent / "models")
        print("="*60 + "\n")
    
    def list_local_models(self):
        """List local models only (for CLI mode)."""
        self.list_models()
    
    def list_hf_models(self):
        """List available Hugging Face models (sample)."""
        print("\n" + "="*60)
        print("  Hugging Face Models (Examples):")
        print("="*60)
        
        hf_models = [
            {
                "name": "Qwen/Qwen2.5-0.5B-Instruct",
                "size": "~240 MB",
                "context": "32K",
                "output": "4K",
                "tags": ["fast", "small"],
                "description": "Ultra-fast small model for quick coding tasks"
            },
            {
                "name": "Qwen/Qwen2.5-1.5B-Instruct",
                "size": "~1.1 GB",
                "context": "32K",
                "output": "8K",
                "tags": ["balanced", "efficient"],
                "description": "Balanced model for general coding tasks"
            },
            {
                "name": "Qwen/Qwen2.5-3B-Instruct",
                "size": "~2.1 GB",
                "context": "32K",
                "output": "8K",
                "tags": ["balanced", "recommended"],
                "description": "Recommended for most coding tasks"
            },
            {
                "name": "Qwen/Qwen2.5-7B-Instruct",
                "size": "~4.1 GB",
                "context": "32K",
                "output": "32K",
                "tags": ["balanced", "powerful"],
                "description": "Powerful model for complex coding tasks"
            },
            {
                "name": "Qwen/Qwen2.5-14B-Instruct",
                "size": "~7.7 GB",
                "context": "32K",
                "output": "32K",
                "tags": ["balanced", "advanced"],
                "description": "Advanced model for complex requirements"
            },
            {
                "name": "Qwen/Qwen2.5-32B-Instruct",
                "size": "~17 GB",
                "context": "32K",
                "output": "32K",
                "tags": ["powerful", "large"],
                "description": "Large model for enterprise-level tasks"
            },
            {
                "name": "microsoft/phi-3-mini-instruct",
                "size": "~2.1 GB",
                "context": "128K",
                "output": "8K",
                "tags": ["long-context", "efficient"],
                "description": "Excellent long-context performance"
            },
            {
                "name": "microsoft/phi-3-medium-instruct",
                "size": "~4.7 GB",
                "context": "128K",
                "output": "8K",
                "tags": ["long-context", "balanced"],
                "description": "Balanced long-context model"
            },
        ]
        
        print(f"  {'Name':<40} {'Size':<15} {'Context':<10} {'Tags':<12}")
        print("-"*80)
        for model in hf_models:
            tags_str = ", ".join(model["tags"])
            print(f"  {model['name']:<40} {model['size']:<15} {model['context']:<10} {tags_str:<12}")
        
        print("\n  Visit https://huggingface.co for full catalog")
        print("="*60 + "\n")
    
    def select_system(self):
        """Interactive selection of inference system."""
        print("\n" + "="*60)
        print("  Select Inference System:")
        print("="*60)
        print("  1. OpenCode + Local GGUF (Metal GPU Acceleration)")
        print("  2. Direct Hugging Face (No GPU, slower but easier)")
        
        while True:
            try:
                choice = input("\n  Select [1/2]: ").strip()
                if choice == "1":
                    return "local", "OpenCode + Local GGUF"
                elif choice == "2":
                    return "hf", "Direct Hugging Face"
                else:
                    print("  Invalid choice. Please try again.")
            except KeyboardInterrupt:
                print("\n  Exiting...")
                sys.exit(0)
    
    def select_model(self, system):
        """Interactive selection of model."""
        if system == "local":
            return self._select_local_model()
        else:
            return self._select_hf_model()
    
    def _select_local_model(self):
        """Select a local GGUF model."""
        if not self.models:
            print("  No local models found.")
            return None
        
        print("\n  Available Local Models:")
        for name, info in self.models.items():
            print(f"    - {name} ({info['size_mb']:.1f} MB)")
        
        while True:
            try:
                choice = input("\n  Select model name: ").strip()
                if choice in self.models:
                    return choice
                else:
                    print("  Model not found.")
            except KeyboardInterrupt:
                print("\n  Exiting...")
                sys.exit(0)
    
    def _select_hf_model(self):
        """Select a Hugging Face model."""
        hf_models = [
            "Qwen/Qwen2.5-0.5B-Instruct",
            "Qwen/Qwen2.5-1.5B-Instruct",
            "Qwen/Qwen2.5-3B-Instruct",
            "Qwen/Qwen2.5-7B-Instruct",
            "Qwen/Qwen2.5-14B-Instruct",
            "Qwen/Qwen2.5-32B-Instruct",
            "microsoft/phi-3-mini-instruct",
            "microsoft/phi-3-medium-instruct",
        ]
        
        print("\n  Available Hugging Face Models:")
        for i, model in enumerate(hf_models, 1):
            print(f"    {i}. {model}")
        
        while True:
            try:
                choice = input("\n  Select model number: ").strip()
                idx = int(choice) - 1
                if 1 <= idx <= len(hf_models):
                    return hf_models[idx - 1]
                else:
                    print("  Invalid choice.")
            except KeyboardInterrupt:
                print("\n  Exiting...")
                sys.exit(0)
    
    def run_local(self, model_name, prompt, context_size=32768):
        """Run inference with local GGUF model via OpenCode/llama-server."""
        print(f"\n  [Running local model: {model_name}]")
        print(f"  [Context Size: {context_size//1024}K tokens]")
        
        # Check if server is running
        if not self._check_server_health():
            print("\n  [!] Server not running. Starting...")
            self._start_server(model_name, context_size)
        
        # Make API call
        try:
            import httpx
            
            url = f"http://127.0.0.1:8080/v1/chat/completions"
            payload = {
                "model": model_name,
                "messages": [
                    {"role": "system", "content": "You are an expert senior software engineer. Write clean, idiomatic, high-performance code with concise explanations."},
                    {"role": "user", "content": prompt}
                ],
                "temperature": 0.2,
                "max_tokens": 2048,
                "stream": True
            }
            
            print("\n  [Sending prompt...]")
            response = httpx.post(url, json=payload, timeout=120)
            response.raise_for_status()
            
            print("\n  [Model Response:]")
            for line in response.iter_lines():
                if line:
                    try:
                        data = json.loads(line.decode('utf-8'))
                    except:
                        data = json.loads(line)
                    content = data.get("choices", [{}])[0].get("delta", {}).get("content", "")
                    if content:
                        print(content, end="", flush=True)
            
            print("\n  [Done!]\n")
            
        except Exception as e:
            print(f"\n  [!] Error: {e}")
    
    def run_huggingface(self, model_name, prompt):
        """Run inference with Hugging Face model via API."""
        print(f"\n  [Running Hugging Face model: {model_name}]")
        
        # Get model info
        try:
            info_url = f"https://huggingface.co/api/models/{model_name}"
            response = HTTP_CLIENT.get(info_url, timeout=30)
            model_info = response.json()
        except Exception as e:
            print(f"  [!] Could not fetch model info: {e}")
            model_info = {}
        
        # Get model card for context size
        try:
            card_url = f"https://huggingface.co/api/models/{model_name}/cards"
            response = HTTP_CLIENT.get(card_url, timeout=30)
            model_card = response.json() if response.status_code == 200 else {}
        except Exception as e:
            print(f"  [!] Could not fetch model card: {e}")
            model_card = {}
        
        # Determine context size from model card or default
        context_size = 32768
        if "pipeline_tag" in model_card:
            tags = model_card["pipeline_tag"].lower()
            if "long" in tags:
                context_size = 131072
        elif "context_length" in model_card:
            context_size = model_card["context_length"]
        
        print(f"  [Context Size: {context_size//1024}K tokens]")
        
        # Make API call to Hugging Face Inference API
        try:
            # Use HF's public inference API
            url = "https://api-inference.huggingface.co/models"
            
            payload = {
                "inputs": prompt
            }
            
            headers = {
                "Authorization": f"Bearer {model_info.get('token', '')}"
            }
            
            print("\n  [Sending prompt...]")
            response = HTTP_CLIENT.post(url, json=payload, headers=headers, timeout=120)
            response.raise_for_status()
            
            result = response.json()
            print("\n  [Model Response:]")
            print(result.get("generated_text", "No output received"))
            print("\n  [Done!]\n")
            
        except Exception as e:
            print(f"\n  [!] Error: {e}")
            print("  [Tip: For production use, consider downloading model with `huggingface-cli download`")
    
    def _check_server_health(self):
        """Check if llama-server is running."""
        try:
            req = urllib.request.Request("http://127.0.0.1:8080/health", timeout=2)
            with urllib.request.urlopen(req) as resp:
                return resp.status == 200
        except:
            return False
    
    def _start_server(self, model_name, context_size):
        """Start llama-server with specified model and context."""
        root_dir = Path(__file__).parent.parent
        models_dir = root_dir / "models"
        start_script = root_dir / "scripts" / "start.sh"
        model_path = models_dir / f"{model_name}.gguf"
        
        if not model_path.exists():
            print(f"  [!] Target model not found at '{model_path}'. Run './setup.sh' or './scripts/download_models.sh' first.")
            return
        
        if start_script.exists():
            print(f"  [Starting llama-server with {model_name}...]")
            subprocess.Popen(
                ["./scripts/start.sh", "--target", str(model_path), "--ctx", str(context_size)],
                cwd=root_dir
            )
            print("  [Server starting. Press Ctrl+C to stop...]")
        else:
            print(f"  [!] Start script not found at {start_script}")
    
    def run_custom(self):
        """Run custom prompt with selected model."""
        print("\n" + "="*60)
        print("  Custom Prompt Mode")
        print("="*60)
        
        system, system_name = self.select_system()
        model = self.select_model(system)
        
        if not model:
            print("  No model selected.")
            return
        
        print("\n" + "="*60)
        print(f"  {system_name}")
        print("="*60)
        print(f"  Model: {model}")
        
        # Get prompt
        while True:
            prompt = input("\n  Enter your prompt: ").strip()
            if prompt:
                break
        
        # Run inference
        if system == "local":
            self.run_local(model, prompt)
        else:
            self.run_huggingface(model, prompt)
    
    def run_quick(self):
        """Quick run without interactive selection."""
        prompt = args.prompt
        
        if not prompt:
            print("  [!] Please provide a prompt")
            return
        
        system, system_name = self.select_system()
        model = self.select_model(system)
        
        if not model:
            return
        
        if system == "local":
            self.run_local(model, prompt)
        else:
            self.run_huggingface(model, prompt)


def main():
    parser = argparse.ArgumentParser(
        description="Multi-Model CLI for Local AI Coding Lab",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  cli run           # Interactive mode
  cli run --local Qwen/Qwen2.5-3B-Instruct "Write a Python function"
  cli run --hf "microsoft/phi-3-mini-instruct" "Write a Go struct"
  cli run --quick "Implement LRU cache in Python"
  
  # With custom context size
  cli run --local Qwen2.5-3B-Instruct --ctx 131072 "Long context task"
        """
    )
    
    parser.add_argument("--system", choices=["local", "hf"], default="local",
                        help="Inference system: local (GGUF) or hf (Hugging Face)")
    parser.add_argument("--model", type=str, help="Model name (local: local model, hf: Hugging Face repo)")
    parser.add_argument("--prompt", type=str, default="", help="Prompt to send to model")
    parser.add_argument("--ctx", type=int, default=32768, help="Context size in tokens (local only)")
    parser.add_argument("--list-local", action="store_true", help="List local models only")
    parser.add_argument("--list-hf", action="store_true", help="List Hugging Face models")
    parser.add_argument("prompt", nargs="?", help="Prompt to send to model (for quick mode)")
    
    args = parser.parse_args()
    
    cli = MultiModelCLI()
    
    if args.list_local:
        cli.list_local_models()
    elif args.list_hf:
        cli.list_hf_models()
    elif args.prompt:
        # Quick mode - run with target model locally
        cli.run_local("target", args.prompt)
    else:
        cli.run_custom()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# ============================================================
#  Groq AI Command Line Chatbot
#  Install dependencies: pip3 install groq --break-system-packages
#  Run: python3 chatbot.py
# ============================================================

import os
import sys

# ── Check groq is installed ───────────────────────────────────
try:
    from groq import Groq
except ImportError:
    print("\n[!] Groq package not found. Installing...")
    os.system("pip3 install groq --break-system-packages")
    from groq import Groq

# ── Colours ───────────────────────────────────────────────────
RED     = "\033[0;31m"
GREEN   = "\033[0;32m"
YELLOW  = "\033[1;33m"
BLUE    = "\033[0;34m"
CYAN    = "\033[0;36m"
MAGENTA = "\033[0;35m"
NC      = "\033[0m"

# ── Config ────────────────────────────────────────────────────
API_KEY = os.environ.get("GROQ_API_KEY", "")
MODEL   = "llama-3.3-70b-versatile"
SYSTEM  = "You are a helpful assistant."

# ── Available models (all current and working as of 2026) ─────
MODELS = {
    "1": ("llama-3.3-70b-versatile",              "Llama 3.3 70B       - Best general purpose"),
    "2": ("llama-3.1-8b-instant",                 "Llama 3.1 8B        - Fast and lightweight"),
    "3": ("meta-llama/llama-4-scout-17b-16e-instruct", "Llama 4 Scout  - Latest Llama 4 model"),
    "4": ("deepseek-r1-distill-llama-70b",        "DeepSeek R1 70B     - Great for reasoning"),
    "5": ("moonshotai/kimi-k2-instruct-0905",     "Kimi K2             - 256K context window"),
    "6": ("openai/gpt-oss-20b",                   "GPT-OSS 20B         - OpenAI open weight"),
    "7": ("qwen/qwen3-32b",                       "Qwen 3 32B          - Strong all-rounder"),
}

# ── Ask for API key if not set ────────────────────────────────
if not API_KEY:
    print(f"\n{YELLOW}[!] No GROQ_API_KEY found.{NC}")
    print(f"    Get a free key at {CYAN}console.groq.com{NC}\n")
    API_KEY = input("    Paste your Groq API key: ").strip()
    if not API_KEY:
        print(f"{RED}[✘] No API key provided. Exiting.{NC}")
        sys.exit(1)
    shell_rc = os.path.expanduser("~/.bashrc")
    with open(shell_rc, "a") as f:
        f.write(f'\nexport GROQ_API_KEY="{API_KEY}"\n')
    print(f"{GREEN}[✔] API key saved to ~/.bashrc for future sessions.{NC}")

# ── Init Groq client ──────────────────────────────────────────
client = Groq(api_key=API_KEY)

# ── Chat history ──────────────────────────────────────────────
messages = [{"role": "system", "content": SYSTEM}]

# ── Banner ────────────────────────────────────────────────────
print(f"""
{CYAN}╔══════════════════════════════════════════════╗
║         Groq AI Command Line Chatbot         ║
║  Model : {MODEL:<36}║
║  Type 'exit'  to quit                        ║
║  Type 'clear' to reset chat history          ║
║  Type 'model' to switch AI model             ║
║  Type 'help'  for all commands               ║
╚══════════════════════════════════════════════╝{NC}
""")

def change_model():
    print(f"\n{YELLOW}Available models:{NC}")
    for key, (name, desc) in MODELS.items():
        print(f"  {key}. {desc}")
    choice = input("\nChoose a model (1-7): ").strip()
    if choice in MODELS:
        return MODELS[choice][0]
    print(f"{RED}Invalid choice, keeping current model.{NC}")
    return MODEL

# ── Main chat loop ────────────────────────────────────────────
while True:
    try:
        user_input = input(f"{GREEN}You: {NC}").strip()

        if not user_input:
            continue
        if user_input.lower() == "exit":
            print(f"\n{CYAN}Goodbye!{NC}\n")
            break
        if user_input.lower() == "clear":
            messages = [{"role": "system", "content": SYSTEM}]
            print(f"{YELLOW}[!] Chat history cleared.{NC}\n")
            continue
        if user_input.lower() == "model":
            MODEL = change_model()
            print(f"{GREEN}[✔] Switched to {MODEL}{NC}\n")
            continue
        if user_input.lower() == "help":
            print(f"""
{YELLOW}Commands:{NC}
  exit   - Quit the chatbot
  clear  - Clear chat history
  model  - Switch AI model
  help   - Show this help
            """)
            continue

        messages.append({"role": "user", "content": user_input})

        print(f"{MAGENTA}AI: {NC}", end="", flush=True)

        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            stream=True,
            max_tokens=1024,
            temperature=0.7,
        )

        full_response = ""
        for chunk in response:
            if chunk.choices[0].delta.content:
                text = chunk.choices[0].delta.content
                print(text, end="", flush=True)
                full_response += text

        print("\n")
        messages.append({"role": "assistant", "content": full_response})

    except KeyboardInterrupt:
        print(f"\n\n{CYAN}Goodbye!{NC}\n")
        break
    except Exception as e:
        print(f"\n{RED}[✘] Error: {e}{NC}\n")
        continue

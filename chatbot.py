#!/usr/bin/env python3
# ============================================================
#  Groq AI Command Line Chatbot
#  Install dependencies: pip install groq
#  Run: python3 chatbot.py
# ============================================================

import os
import sys

# ── Check groq is installed ───────────────────────────────────
try:
    from groq import Groq
except ImportError:
    print("\n[!] Groq package not found. Installing...")
    os.system("pip install groq --break-system-packages")
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
API_KEY = os.environ.get("GROQ_API_KEY", "")  # Set via environment variable
MODEL   = "llama3-8b-8192"                     # Fast and free Groq model
SYSTEM  = "You are a helpful assistant."       # Change this to customise personality

# ── Ask for API key if not set ────────────────────────────────
if not API_KEY:
    print(f"\n{YELLOW}[!] No GROQ_API_KEY found.{NC}")
    print(f"    Get a free key at {CYAN}console.groq.com{NC}\n")
    API_KEY = input("    Paste your Groq API key: ").strip()
    if not API_KEY:
        print(f"{RED}[✘] No API key provided. Exiting.{NC}")
        sys.exit(1)
    # Save it for future sessions
    shell_rc = os.path.expanduser("~/.bashrc")
    with open(shell_rc, "a") as f:
        f.write(f'\nexport GROQ_API_KEY="{API_KEY}"\n')
    print(f"{GREEN}[✔] API key saved to ~/.bashrc for future sessions.{NC}")

# ── Init Groq client ──────────────────────────────────────────
client = Groq(api_key=API_KEY)

# ── Chat history ──────────────────────────────────────────────
messages = [
    {"role": "system", "content": SYSTEM}
]

# ── Banner ────────────────────────────────────────────────────
print(f"""
{CYAN}╔══════════════════════════════════════╗
║       Groq AI Command Line Chat      ║
║       Model: {MODEL:<22}║
║       Type 'exit' to quit            ║
║       Type 'clear' to reset chat     ║
║       Type 'model' to change model   ║
╚══════════════════════════════════════╝{NC}
""")

# ── Available models ──────────────────────────────────────────
MODELS = {
    "1": ("llama3-8b-8192",      "Llama 3 8B   - Fast and free"),
    "2": ("llama3-70b-8192",     "Llama 3 70B  - Smarter but slower"),
    "3": ("mixtral-8x7b-32768",  "Mixtral 8x7B - Great for long context"),
    "4": ("gemma-7b-it",         "Gemma 7B     - Google's model"),
}

def change_model():
    print(f"\n{YELLOW}Available models:{NC}")
    for key, (name, desc) in MODELS.items():
        print(f"  {key}. {desc}")
    choice = input("\nChoose a model (1-4): ").strip()
    if choice in MODELS:
        return MODELS[choice][0]
    print(f"{RED}Invalid choice, keeping current model.{NC}")
    return MODEL

# ── Main chat loop ────────────────────────────────────────────
while True:
    try:
        # Get user input
        user_input = input(f"{GREEN}You: {NC}").strip()

        # Handle commands
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
  model  - Change AI model
  help   - Show this help
            """)
            continue

        # Add user message to history
        messages.append({"role": "user", "content": user_input})

        # Send to Groq API
        print(f"{MAGENTA}AI: {NC}", end="", flush=True)

        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            stream=True,        # Stream the response word by word
            max_tokens=1024,
            temperature=0.7,
        )

        # Stream the response
        full_response = ""
        for chunk in response:
            if chunk.choices[0].delta.content:
                text = chunk.choices[0].delta.content
                print(text, end="", flush=True)
                full_response += text

        print("\n")

        # Add assistant response to history
        messages.append({"role": "assistant", "content": full_response})

    except KeyboardInterrupt:
        print(f"\n\n{CYAN}Goodbye!{NC}\n")
        break
    except Exception as e:
        print(f"\n{RED}[✘] Error: {e}{NC}\n")
        continue

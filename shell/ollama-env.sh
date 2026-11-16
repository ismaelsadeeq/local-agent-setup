# Local-only Ollama settings for the OpenCode + qwen3 setup.
# Works in bash and zsh. install.sh adds a line to ~/.zshrc or ~/.bashrc that sources this file.

export OLLAMA_NO_CLOUD=1                # never use ollama.com cloud models
export OLLAMA_CONTEXT_LENGTH=32768      # matches limit.context in opencode.jsonc
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE=q8_0        # halves KV cache memory vs f16
export OLLAMA_MAX_LOADED_MODELS=1       # 16 GB: one model in memory at a time
export OLLAMA_KEEP_ALIVE=15m            # stay loaded between agent steps
export LLAMA_ARG_CACHE_RAM=2048         # llama.cpp prompt cache: 2 GB instead of the 8 GB default
export OLLAMA_LOG="$HOME/.ollama/logs/server.log"

_ollama_alive() { curl -s -m 2 http://127.0.0.1:11434/api/version >/dev/null; }

# ollama-up: start the server in the background with the settings above
ollama-up() {
  if _ollama_alive; then echo "ollama already running"; return 0; fi
  mkdir -p "$(dirname "$OLLAMA_LOG")"
  nohup ollama serve >> "$OLLAMA_LOG" 2>&1 &
  disown 2>/dev/null || true
  i=0
  while [ $i -lt 30 ]; do
    if _ollama_alive; then echo "ollama up (log: $OLLAMA_LOG)"; return 0; fi
    sleep 1; i=$((i + 1))
  done
  echo "ollama did not start; see $OLLAMA_LOG" >&2; return 1
}

# ollama-down: stop the server (and the model runner it started)
ollama-down() { pkill -f '^ollama serve' && echo "ollama stopped" || echo "ollama was not running"; }

# ollama-restart: apply changed settings
ollama-restart() { ollama-down; sleep 2; ollama-up; }

# ollama-log: follow the server log
ollama-log() { tail -f "$OLLAMA_LOG"; }

# ollama-status: loaded models (CONTEXT should show 32768 after the first request)
ollama-status() { ollama ps; }

# ollama-help: list these commands
ollama-help() {
  cat <<'EOF'
ollama-up       start Ollama in the background with the local settings (logs to $OLLAMA_LOG)
ollama-down     stop Ollama and its model runner
ollama-restart  stop + start, to apply changed settings
ollama-status   loaded models and their context size
ollama-log      follow the server log
ollama-help     this list
EOF
}

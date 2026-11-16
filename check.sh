#!/usr/bin/env bash
# Check that the setup is installed and working. Read-only except for one tiny model request.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/shell/ollama-env.sh"
ok() { echo "ok   $*"; }
bad() { echo "FAIL $*"; FAILED=1; }
FAILED=0

command -v ollama >/dev/null && ok "ollama $(ollama --version 2>&1 | tail -1)" || bad "ollama not installed"
command -v opencode >/dev/null && ok "opencode $(opencode --version 2>&1 | tail -1)" || bad "opencode not installed"
command -v tldr >/dev/null && ok "tldr installed" || echo "warn tldr not installed (optional)"

for f in opencode.jsonc tool-notes.md AGENTS.md; do
  [ -f "$HOME/.config/opencode/$f" ] && ok "~/.config/opencode/$f" || bad "~/.config/opencode/$f missing"
done
grep -q "__HOME__" "$HOME/.config/opencode/opencode.jsonc" 2>/dev/null && bad "opencode.jsonc still has __HOME__ placeholder"

if _ollama_alive; then ok "ollama server running"; else bad "ollama server not running (run: ollama-up)"; fi
ollama list 2>/dev/null | grep -q '^qwen3:8b' && ok "qwen3:8b pulled" || bad "qwen3:8b not pulled (run: ollama pull qwen3:8b)"

if _ollama_alive; then
  out=$(curl -s -m 300 http://127.0.0.1:11434/api/generate -d '{"model":"qwen3:8b","prompt":"Reply with the word ok.","stream":false,"think":false}')
  echo "$out" | grep -q '"response"' && ok "model answers" || bad "model did not answer: ${out:0:200}"
  ctx=$(ollama ps 2>/dev/null | awk 'NR==2{print $0}')
  echo "info ollama ps: $ctx"
fi

[ $FAILED -eq 0 ] && echo "== all checks passed" || { echo "== some checks failed"; exit 1; }

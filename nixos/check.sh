#!/usr/bin/env bash
# Check the local coding agent on a host. Run via: just agent-check <hostname>
# Read-only except for one short prompt to the model.
FAILED=0
ok() { echo "ok   $*"; }
bad() { echo "FAIL $*"; FAILED=1; }

v=$(opencode --version 2>&1 | tail -1)
case "$v" in *v2.*|2.*) ok "opencode $v" ;; *) bad "opencode is not v2: $v" ;; esac
command -v ollama >/dev/null && ok "$(ollama --version 2>&1 | tail -1)" || bad "ollama not installed"
systemctl is-active --quiet ollama && ok "ollama service running" || bad "ollama service not running"

for f in opencode.jsonc tool-notes.md AGENTS.md; do
  [ -e "$HOME/.config/opencode/$f" ] && ok "~/.config/opencode/$f" || bad "~/.config/opencode/$f missing"
done

if ollama list 2>/dev/null | grep -q '^qwen3:8b'; then ok "qwen3:8b pulled"
else bad "qwen3:8b not pulled yet (see: journalctl -u ollama-model-loader)"; fi

out=$(curl -s -m 600 http://127.0.0.1:11434/api/generate \
  -d '{"model":"qwen3:8b","prompt":"Reply with the word ok.","stream":false,"think":false}')
echo "$out" | grep -q '"response"' && ok "model answers" || bad "model did not answer: ${out:0:200}"
ctx=$(ollama ps 2>/dev/null | awk 'NR==2')
case "$ctx" in *32768*) ok "context 32768: $ctx" ;; *) bad "context is not 32768: $ctx" ;; esac

[ $FAILED -eq 0 ] && echo "== all checks passed" || { echo "== some checks failed"; exit 1; }

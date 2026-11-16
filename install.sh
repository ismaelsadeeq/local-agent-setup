#!/usr/bin/env bash
# Install the local coding agent setup: Ollama + qwen3:8b + OpenCode with a local-only config.
#   ./install.sh            install
#   ./install.sh --dry-run  print what would happen, change nothing
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODEL="qwen3:8b"
OC_DIR="$HOME/.config/opencode"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

run() { echo "+ $*"; [ $DRY -eq 1 ] || eval "$@"; }
have() { command -v "$1" >/dev/null 2>&1; }
OS="$(uname -s)"
echo "== OS: $OS"

# 1. Ollama
if have ollama; then echo "== ollama already installed: $(ollama --version 2>&1 | tail -1)"
elif [ "$OS" = "Darwin" ] && have brew; then run "brew install ollama"
else run "curl -fsSL https://ollama.com/install.sh | sh"
fi

# 2. OpenCode (v2)
if have opencode; then echo "== opencode already installed: $(opencode --version 2>&1 | tail -1)"
elif [ "$OS" = "Darwin" ] && have brew; then run "brew install anomalyco/tap/opencode-v2"
else run "curl -fsSL https://opencode.ai/v2/install | bash"
fi

# 3. tldr client (optional; the tool notes tell the model to try `tldr <command>` first)
if have tldr; then echo "== tldr already installed"
elif have brew; then run "brew install tlrc"
else echo "== skipping tldr: install tlrc yourself (https://github.com/tldr-pages/tlrc) or ignore"
fi

# 4. Shell settings for Ollama
case "$(basename "${SHELL:-bash}")" in
  zsh) RC="$HOME/.zshrc" ;;
  *)   RC="$HOME/.bashrc" ;;
esac
LINE="[ -f \"$HERE/shell/ollama-env.sh\" ] && . \"$HERE/shell/ollama-env.sh\""
if [ -f "$RC" ] && grep -qF "$HERE/shell/ollama-env.sh" "$RC"; then echo "== $RC already sources ollama-env.sh"
else run "printf '\n# local coding agent (Ollama settings)\n%s\n' '$LINE' >> '$RC'"
fi

# 5. OpenCode config, tool notes and global AGENTS.md (existing files are backed up first)
run "mkdir -p '$OC_DIR'"
STAMP="$(date +%Y%m%d-%H%M%S)"
for f in opencode.jsonc tool-notes.md AGENTS.md; do
  if [ -f "$OC_DIR/$f" ]; then run "cp '$OC_DIR/$f' '$OC_DIR/$f.bak-$STAMP'"; fi
done
run "sed 's|__HOME__|$HOME|g' '$HERE/config/opencode.jsonc' > '$OC_DIR/opencode.jsonc'"
run "cp '$HERE/config/tool-notes.md' '$HERE/config/AGENTS.md' '$OC_DIR/'"

# 6. Start Ollama with the settings and pull the model
# shellcheck disable=SC1091
. "$HERE/shell/ollama-env.sh"
if [ $DRY -eq 0 ]; then
  ollama-up
  ollama pull "$MODEL"
else
  echo "+ ollama-up"; echo "+ ollama pull $MODEL"
fi

cat <<EOF

== Done. Next:
  1. Open a new terminal (or: . "$HERE/shell/ollama-env.sh")
  2. ollama-up
  3. cd your-project && opencode     # starts in clarify; /agents or Shift+Tab switches agent
  4. Check: ./check.sh
EOF

# Local coding agent setup

OpenCode + `qwen3:8b` on Ollama, configured to stay local: only the Ollama provider is allowed, web tools are off (except an approval-gated `research` agent), and every shell command asks first.

This is the configuration from the post [What Went Wrong When I Ran a Local Coding Agent on Bitcoin Core](https://ismaelsadeeq.github.io/blog/2026/what-went-wrong-local-coding-agent-bitcoin-core/). It's the everyday setup, without the benchmark harness and its verifier/writer loop, so **you are the checker**: run what it produces yourself.

Tested with Ollama 0.40.16, OpenCode 2.2.6–2.2.7 and `qwen3:8b` (Q4_K_M).

## Requirements

- macOS (with Homebrew), Linux (glibc or musl), or NixOS.
- About 8 GB of free memory for the model with a 32k context (measured 7.7 GB on an M2 Pro). Without a GPU it runs on CPU, much slower.
- About 6 GB of disk for the model.

## Install on macOS or Linux

```bash
git clone https://github.com/ismaelsadeeq/local-agent-setup ~/local-agent-setup
cd ~/local-agent-setup
./install.sh --dry-run   # see what it will do
./install.sh
./check.sh
```

`install.sh`:

1. installs Ollama, OpenCode v2 and a `tldr` client (`brew` on macOS; the official install scripts on Linux)
2. adds one line to `~/.zshrc` or `~/.bashrc` that sources `shell/ollama-env.sh`
3. copies `config/opencode.jsonc`, `config/tool-notes.md` and `config/AGENTS.md` to `~/.config/opencode/`, backing up any existing files as `*.bak-<timestamp>`
4. starts Ollama with the settings and pulls `qwen3:8b`

It's safe to run again; steps that are already done are skipped, except the config copy, which always backs up first.

`check.sh` checks that the tools, config files and model are in place, and sends one short prompt to the model. After that, `ollama ps` should show `CONTEXT 32768`.

Ollama and OpenCode are installed at their latest versions, which may differ from the tested ones. For pinned versions, use the NixOS route.

### Linux: the Ollama service

The Linux installer also sets up a systemd service called `ollama`. That service doesn't read your shell settings, so it runs with the defaults (no 32k context, no q8_0 cache). Pick one:

- stop it and use the shell helpers: `sudo systemctl disable --now ollama`, then `ollama-up`
- or put the settings in the service: `sudo systemctl edit ollama`, add the lines below, then `sudo systemctl restart ollama`

```ini
[Service]
Environment="OLLAMA_NO_CLOUD=1"
Environment="OLLAMA_CONTEXT_LENGTH=32768"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=15m"
Environment="LLAMA_ARG_CACHE_RAM=2048"
```

## Install on NixOS

This repo is also a flake. Its `nixosModules.default` sets up the same thing declaratively:

- the Ollama service with the settings above, and `qwen3:8b` pulled after each rebuild
- OpenCode v2 and `tlrc`
- the three config files linked into the user's `~/.config/opencode` (read-only; change them here, not on the host)
- a `local-agent-check` command, the server version of `check.sh`

Ollama and OpenCode come from the nixpkgs pinned in this repo's `flake.lock`, so every host gets exactly the same versions whatever nixpkgs the system uses.

In the host flake:

```nix
inputs.local-agent.url = "github:ismaelsadeeq/local-agent-setup";

# in the nixosSystem modules list:
local-agent.nixosModules.default
{ localAgent.user = "alice"; }
```

Per-host options:

| Option | Default | |
| --- | --- | --- |
| `localAgent.enable` | `true` | Turn the whole setup off on a host |
| `localAgent.models` | `[ "qwen3:8b" ]` | Models to pull. The OpenCode config uses `qwen3:8b`. |
| `localAgent.ollamaPackage` | `"ollama-cpu"` | `"ollama-cuda"` (NVIDIA), `"ollama-rocm"` (AMD) or `"ollama-vulkan"` |

To roll out a change to every server: commit and push here, run `nix flake update local-agent` in the host repo, then rebuild. Check a host with `ssh <host> local-agent-check`.

## Use it

```bash
ollama-up                # macOS/Linux only: start Ollama with the settings (ollama-help lists the helpers)
cd your-project
opencode                 # starts in clarify; /agents or Shift+Tab switches agent
```

- `clarify` can't edit or run anything. It asks up to three questions and writes a spec with a "Done when" list.
- `build` does the work and asks before every shell command.
- `research` is the only agent that can fetch web pages, with your approval per URL.

Give it one small, well-defined job at a time and check the result yourself. OpenCode's permission prompts aren't a security boundary; an agent with a shell can get around a blocked tool. If you let it run commands without approval, run it inside an OS-level sandbox.

## Files

| File | Used by | What it is |
| --- | --- | --- |
| `config/opencode.jsonc` | both | Models, agents, permissions, local-only policies (`__HOME__` is filled in on install) |
| `config/tool-notes.md` | both | Tool recipes and working rules, loaded via `instructions` |
| `config/AGENTS.md` | both | Global working rules |
| `install.sh`, `check.sh` | macOS/Linux | Install and check |
| `shell/ollama-env.sh` | macOS/Linux | Ollama settings and `ollama-up/down/restart/status/log/help` |
| `flake.nix`, `flake.lock`, `nixos/module.nix` | NixOS | The NixOS module and its pinned nixpkgs |
| `nixos/check.sh` | NixOS | Becomes `local-agent-check` |

To change the context size, change it in all three places: `limit.context` in `config/opencode.jsonc`, `OLLAMA_CONTEXT_LENGTH` in `shell/ollama-env.sh`, and `OLLAMA_CONTEXT_LENGTH` in `nixos/module.nix`. Then run `ollama-restart`, or rebuild on NixOS.

## Undo

macOS/Linux:

```bash
ollama-down
mv ~/.config/opencode/opencode.jsonc.bak-<timestamp> ~/.config/opencode/opencode.jsonc   # restore your old config
# remove the "local coding agent" line from ~/.zshrc or ~/.bashrc
ollama rm qwen3:8b
```

NixOS: set `localAgent.enable = false;` (or remove the module) and rebuild.

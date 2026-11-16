# Local coding agent setup

OpenCode + `qwen3:8b` on Ollama, configured to stay local: only the Ollama provider is allowed, web tools are off (except an approval-gated `research` agent), and every shell command asks first.

This is the configuration from the post [What Went Wrong When I Ran a Local Coding Agent on Bitcoin Core](https://ismaelsadeeq.github.io/blog/2026/what-went-wrong-local-coding-agent-bitcoin-core/). It's the everyday setup, without the benchmark harness and its verifier/writer loop, so **you are the checker**: run what it produces yourself.

## NixOS (servers)

This repo is also a flake. Its `nixosModules.default` sets up the same thing declaratively: the Ollama service with the settings above, `qwen3:8b` pulled automatically, OpenCode v2, `tlrc`, the config linked into the user's `~/.config/opencode`, and a `local-agent-check` command. Ollama and OpenCode come from this flake's own pinned nixpkgs, so every host gets the same versions.

In the host flake:

```nix
inputs.local-agent.url = "github:ismaelsadeeq/local-agent-setup";

# in the nixosSystem modules list:
local-agent.nixosModules.default
{ localAgent.user = "alice"; }
```

Per-host options: `localAgent.enable` (default `true`), `localAgent.models` (default `[ "qwen3:8b" ]`), `localAgent.ollamaPackage` (`"ollama-cpu"` by default; `"ollama-cuda"`, `"ollama-rocm"` or `"ollama-vulkan"` for GPUs).

Roll out a config change to every server: commit here, then in the host repo run `nix flake update local-agent` and rebuild. Check a host with `ssh <host> local-agent-check`.

## Requirements

- macOS or Linux (glibc or musl), with `curl`, `bash`, and Homebrew if you're on macOS.
- About 8 GB of free memory for the model with a 32k context (measured 7.7 GB on an M2 Pro). Less memory or no GPU: it will run on CPU, much slower.
- About 6 GB of disk for the model.

## Install

```bash
git clone <this repo> ~/local-agent-setup
cd ~/local-agent-setup
./install.sh --dry-run   # see what it will do
./install.sh
```

The script:

1. installs Ollama, OpenCode v2 and a `tldr` client (`brew` on macOS; the official install scripts on Linux)
2. adds one line to `~/.zshrc` or `~/.bashrc` that sources `shell/ollama-env.sh`
3. copies `config/opencode.jsonc`, `config/tool-notes.md` and `config/AGENTS.md` to `~/.config/opencode/`, backing up any existing files as `*.bak-<timestamp>`
4. starts Ollama with the settings and pulls `qwen3:8b`

It's safe to run again; steps that are already done are skipped, except the config copy, which always backs up first.

### Linux: the Ollama service

The Linux installer also sets up a systemd service called `ollama`. That service doesn't read your shell settings, so it runs with the defaults (no 32k context, no q8_0 cache). Pick one:

- stop it and use the shell helpers: `sudo systemctl disable --now ollama`, then `ollama-up`
- or put the settings in the service: `sudo systemctl edit ollama`, add the `Environment=` lines below, then `sudo systemctl restart ollama`

```ini
[Service]
Environment="OLLAMA_NO_CLOUD=1"
Environment="OLLAMA_CONTEXT_LENGTH=32768"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=15m"
```

## Check it

```bash
./check.sh
```

It checks that the tools, config files and model are in place, and sends one short prompt to the model. After that, `ollama ps` should show `CONTEXT 32768`.

## Use it

```bash
ollama-up                # start Ollama with the settings (ollama-help lists the helpers)
cd your-project
opencode                 # starts in clarify; /agents or Shift+Tab switches agent
```

- `clarify` can't edit or run anything. It asks up to three questions and writes a spec with a "Done when" list.
- `build` does the work and asks before every shell command.
- `research` is the only agent that can fetch web pages, with your approval per URL.

Give it one small, well-defined job at a time and check the result yourself. OpenCode's permission prompts aren't a security boundary; an agent with a shell can get around a blocked tool. If you let it run commands without approval, run it inside an OS-level sandbox.

## Files

| File | Goes to | What it is |
| --- | --- | --- |
| `config/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | Models, agents, permissions, local-only policies |
| `config/tool-notes.md` | `~/.config/opencode/tool-notes.md` | Tool recipes and working rules, loaded via `instructions` |
| `config/AGENTS.md` | `~/.config/opencode/AGENTS.md` | Global working rules |
| `shell/ollama-env.sh` | sourced from your shell rc | Ollama settings and `ollama-up/down/restart/status/log/help` |
| `flake.nix`, `nixos/module.nix` | NixOS hosts | Declarative version of all of the above |
| `nixos/check.sh` | `local-agent-check` on NixOS hosts | Checks versions, config, model and context on a server |

To change the model or context size, edit `OLLAMA_CONTEXT_LENGTH` in `shell/ollama-env.sh` **and** `limit.context` in `config/opencode.jsonc` together, then run `ollama-restart`.

## Undo

```bash
ollama-down
mv ~/.config/opencode/opencode.jsonc.bak-<timestamp> ~/.config/opencode/opencode.jsonc   # restore your old config
# remove the "local coding agent" line from ~/.zshrc or ~/.bashrc
ollama rm qwen3:8b
```

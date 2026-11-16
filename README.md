# Local coding agent setup

A coding agent that runs entirely on your machine: [OpenCode](https://opencode.ai/docs/) with `qwen3:8b` on [Ollama](https://github.com/ollama/ollama). Only the local Ollama provider is allowed, web access is limited to one approval-gated agent, and every shell command asks first.

This is the configuration from [What Went Wrong When I Ran a Local Coding Agent on Bitcoin Core](https://ismaelsadeeq.github.io/blog/2026/what-went-wrong-local-coding-agent-bitcoin-core/). It doesn't include the benchmark's checking loop, so **you are the checker**: run what it produces yourself.

Tested with Ollama 0.40.16, OpenCode 2.2.6–2.2.7 and `qwen3:8b` (Q4_K_M, ID `500a1f067a9f`).

## What it sets up

**Agents** (`config/opencode.jsonc`):

| Agent | Can | Can't |
| --- | --- | --- |
| `clarify` (default) | Ask up to 3 questions, write a spec with a "Done when" list | Edit or run anything |
| `build` | Edit files, run commands (each command asks first) | Fetch web pages |
| `research` | Fetch web pages, with your approval per URL | Read files, run commands, edit |
| `summarize` | Condense long command output | Edit or run anything |

**Ollama settings** (`shell/ollama-env.sh` on macOS/Linux, `nixos/module.nix` on NixOS):

| Setting | Value | Why |
| --- | --- | --- |
| `OLLAMA_NO_CLOUD` | `1` | Never use ollama.com cloud models |
| `OLLAMA_CONTEXT_LENGTH` | `32768` | Must match `limit.context` in `config/opencode.jsonc` |
| `OLLAMA_FLASH_ATTENTION` | `1` | Less memory, faster long prompts |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | Halves KV cache memory |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | One model in memory at a time |
| `OLLAMA_KEEP_ALIVE` | `15m` | Stay loaded between agent steps |
| `LLAMA_ARG_CACHE_RAM` | `2048` | 2 GB prompt cache instead of 8 GB |

Plus two instruction files loaded into every session: `config/tool-notes.md` (how to run code, look up commands, git recipes) and `config/AGENTS.md` (working rules).

Needs about 8 GB of free memory (7.7 GB measured with a 32k context) and 6 GB of disk. Without a GPU it runs on CPU, much slower.

## Install

### macOS or Linux

```bash
git clone https://github.com/ismaelsadeeq/local-agent-setup ~/local-agent-setup
cd ~/local-agent-setup
./install.sh --dry-run   # print the steps, change nothing
./install.sh
./check.sh
```

`install.sh` installs Ollama, OpenCode v2 and `tlrc` (Homebrew on macOS, the official install scripts on Linux), loads the settings from your shell rc, copies the config to `~/.config/opencode/` (backing up existing files as `*.bak-<timestamp>`), and pulls `qwen3:8b`. On Linux it also gives the Ollama systemd service the same settings, through `/etc/systemd/system/ollama.service.d/local-agent.conf`. It's safe to run again.

It installs the latest Ollama and OpenCode, which may differ from the tested versions. For pinned versions, use NixOS.

### NixOS

The repo is a flake exporting `nixosModules.default`. Ollama and OpenCode come from the nixpkgs pinned in this repo's `flake.lock`, so every host gets the same versions whatever nixpkgs the system uses.

In your system's `flake.nix`:

```nix
{
  inputs = {
    # ...your existing inputs
    local-agent.url = "github:ismaelsadeeq/local-agent-setup";
  };

  outputs = { nixpkgs, local-agent, ... }: {        # add local-agent here
    nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
      modules = [
        # ...your existing modules
        local-agent.nixosModules.default
        { localAgent.user = "<your-user>"; }
      ];
    };
  };
}
```

Remove `opencode` from your own `environment.systemPackages` if it's there; the module installs OpenCode v2. Then:

```bash
nix flake lock                                  # records the local-agent commit
sudo nixos-rebuild switch --flake .#<host>      # or --target-host for a remote server
local-agent-check                               # on the host
```

The first rebuild starts downloading `qwen3:8b` (about 5 GB) in the background, so the model checks fail until it finishes. Follow it with `journalctl -u ollama-model-loader -f`.

Options:

| Option | Default | |
| --- | --- | --- |
| `localAgent.user` | none (required) | Whose `~/.config/opencode` gets the config |
| `localAgent.enable` | `true` | Turn the setup off on a host |
| `localAgent.models` | `[ "qwen3:8b" ]` | Models to pull. The OpenCode config uses `qwen3:8b`. |
| `localAgent.ollamaPackage` | `"ollama-cpu"` | `"ollama-cuda"` (NVIDIA), `"ollama-rocm"` (AMD), `"ollama-vulkan"` |

The config files are linked read-only from the Nix store, so change them in this repo, not on the host.

## Check

`./check.sh` (macOS/Linux) and `local-agent-check` (NixOS) check the versions, config files, Ollama service, model and context size, then send the model one short prompt. They warn if `qwen3:8b` isn't the tested build, since the tag on ollama.com can change.

## Use

```bash
ollama-up       # macOS/Linux, if Ollama isn't running (ollama-help lists the helpers)
cd your-project
opencode        # starts in clarify; /agents or Shift+Tab switches agent
```

Give it one small, well-defined job at a time and check the result yourself. OpenCode's permission prompts aren't a security boundary: an agent with a shell can get around a blocked tool. If you let it run commands without approval, run it inside an OS-level sandbox.

## Update

- **This repo:** edit, commit, push. On macOS/Linux, `git pull && ./install.sh`. On NixOS hosts, `nix flake update local-agent` in the system flake, then rebuild.
- **Ollama and OpenCode versions (NixOS):** `nix flake update nixpkgs` in this repo, commit, push, then update hosts as above.
- **Context size:** change it in `config/opencode.jsonc` (`limit.context`), `shell/ollama-env.sh` and `nixos/module.nix`, together.

## Files

| File | What it is |
| --- | --- |
| `config/opencode.jsonc` | Models, agents, permissions, local-only policies. `__HOME__` is filled in on install. |
| `config/tool-notes.md` | Tool recipes and rules, loaded via `instructions` |
| `config/AGENTS.md` | Global working rules |
| `install.sh`, `check.sh` | Install and check on macOS/Linux |
| `shell/ollama-env.sh` | Ollama settings and the `ollama-up/down/restart/status/log/help` helpers |
| `flake.nix`, `flake.lock` | The flake and its pinned nixpkgs |
| `nixos/module.nix` | The NixOS module |
| `nixos/check.sh` | Installed as `local-agent-check` |

## Undo

macOS/Linux:

```bash
ollama-down
mv ~/.config/opencode/opencode.jsonc.bak-<timestamp> ~/.config/opencode/opencode.jsonc
# remove the "local coding agent" line from ~/.zshrc or ~/.bashrc
sudo rm -f /etc/systemd/system/ollama.service.d/local-agent.conf   # Linux
ollama rm qwen3:8b
```

NixOS: set `localAgent.enable = false;` or remove the module, then rebuild.

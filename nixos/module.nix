# NixOS module: Ollama + qwen3:8b + OpenCode v2, local-only, with the config from ../config.
# Exported by ../flake.nix as nixosModules.default. Per host:
#   localAgent.user = "alice";                          # required: whose ~/.config/opencode to set up
#   localAgent.enable = false;                          # turn it off on a host
#   localAgent.models = [ "qwen3:8b" "qwen3:14b" ];
#   localAgent.ollamaPackage = "ollama-cuda";           # NVIDIA host ("ollama-rocm" for AMD)
#
# agentsNixpkgs is this flake's own nixpkgs, so Ollama and OpenCode stay at the versions this
# setup was tested with, whatever nixpkgs the host system uses.
{ agentsNixpkgs }:
{ config, lib, pkgs, ... }:
let
  cfg = config.localAgent;
  agentsPkgs = import agentsNixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  home = config.users.users.${cfg.user}.home;
  group = config.users.users.${cfg.user}.group;
  opencodeConfig = pkgs.writeText "opencode.jsonc"
    (builtins.replaceStrings [ "__HOME__" ] [ home ] (builtins.readFile ../config/opencode.jsonc));
  check = pkgs.writeShellApplication {
    name = "local-agent-check";
    runtimeInputs = [ pkgs.curl pkgs.gawk ];
    checkPhase = ""; # check.sh is also run over ssh, so it isn't written for shellcheck's strict mode
    text = builtins.readFile ./check.sh;
  };
in
{
  options.localAgent = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Ollama, OpenCode v2 and the local-only OpenCode config.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose ~/.config/opencode gets the config.";
    };
    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "qwen3:8b" ];
      description = "Models Ollama pulls after a rebuild. config/opencode.jsonc uses qwen3:8b.";
    };
    ollamaPackage = lib.mkOption {
      type = lib.types.enum [ "ollama-cpu" "ollama-cuda" "ollama-rocm" "ollama-vulkan" ];
      default = "ollama-cpu";
      description = "Which Ollama build to use: CPU only, NVIDIA, AMD or Vulkan.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = agentsPkgs.${cfg.ollamaPackage};
      environmentVariables = {
        OLLAMA_NO_CLOUD = "1"; # never use ollama.com cloud models
        OLLAMA_CONTEXT_LENGTH = "32768"; # matches limit.context in opencode.jsonc
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0"; # halves KV cache memory vs f16
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_KEEP_ALIVE = "15m";
        LLAMA_ARG_CACHE_RAM = "2048"; # 2 GB prompt cache instead of the 8 GB default
      };
      loadModels = cfg.models; # pulled by the ollama-model-loader service after a rebuild
    };

    environment.systemPackages = [
      agentsPkgs.opencode
      pkgs.tlrc # tldr client; the tool notes tell the model to try `tldr <command>` first
      check # local-agent-check
    ];

    # Link the config into the user's home on every boot/rebuild (no home-manager needed).
    systemd.tmpfiles.rules = [
      "d ${home}/.config 0755 ${cfg.user} ${group} -"
      "d ${home}/.config/opencode 0755 ${cfg.user} ${group} -"
      "L+ ${home}/.config/opencode/opencode.jsonc - - - - ${opencodeConfig}"
      "L+ ${home}/.config/opencode/tool-notes.md - - - - ${../config/tool-notes.md}"
      "L+ ${home}/.config/opencode/AGENTS.md - - - - ${../config/AGENTS.md}"
    ];
  };
}

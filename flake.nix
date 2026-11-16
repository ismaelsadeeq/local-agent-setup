{
  description = "Local coding agent: Ollama + qwen3:8b + OpenCode v2, local-only";

  # Ollama and OpenCode come from this nixpkgs, not the host's.
  # Bump with: nix flake update nixpkgs
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }: {
    nixosModules.default = import ./nixos/module.nix { agentsNixpkgs = nixpkgs; };
  };
}

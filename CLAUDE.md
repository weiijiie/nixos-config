# NixOS Configuration Guide

## Commands
- Update system: `sudo nixos-rebuild switch --flake .#HOSTNAME`
- Update darwin: `darwin-rebuild switch --flake .#HOSTNAME`
- Update home-manager: `home-manager switch --flake .#USERNAME@HOSTNAME`
- Check Nix format: `nix fmt`
- Test configuration: `nix flake check`
- Run pre-commit checks: `nix develop -c pre-commit run --all`
- Enter dev shell: `nix develop`

## Dependency Updates
- Do targeted updates: `nix flake update INPUT_NAME` to bump a single input.
- Avoid bare `nix flake update` — bumping everything at once can cascade into expensive rebuilds.

## Style Guidelines
- Format: Use nixfmt (configured in flake.nix)
- Structure: Follow host/user separation pattern
- Imports: Keep module imports organized by functionality
- Naming: Use descriptive names for options and variables
- Overlays: Use for custom packages (pkgs.custom) and unstable packages (pkgs.unstable)
- Modules: Create reusable components in modules/ directory
- Error handling: Use nixpkgs.lib.mkIf for conditional config

## Personal agent hub
- The personal agent system (VPS hub, Hermes, vault sync, MCP services) is specced in `docs/personal-agent/SPEC.md`.
- Read the spec before touching `hosts/<hub>/` or `modules/nixos/agent/`.
- The spec is the source of truth for that system's design; if an implementation change invalidates a spec decision, update the spec's decision log in the same commit.

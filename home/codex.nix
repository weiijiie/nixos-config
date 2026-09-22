{
  config,
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}:
let
  codexSettings = {
    mcp_servers = {
      nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
    };
  };

  # The full level, because Codex takes rtk's guidance as prompt context and
  # has no hook that could narrow it per command.
  rtkAwareness = builtins.readFile "${pkgs.llm-agents.rtk}/libexec/rtk/hooks/rtk-awareness-full.md";

  # Codex writes ~/.codex/config.toml itself, project trust decisions among
  # them, and a write through a store symlink fails. The file therefore stays a
  # writable regular file, and each activation merges the declared keys back
  # over whatever Codex last wrote. The TOML is read and rewritten through
  # JSON, so comments and key order in it do not survive a switch.
  settings-merge = pkgs.writeShellApplication {
    name = "codex-settings-merge";
    runtimeInputs = [
      pkgs.jq
      pkgs.yj
      pkgs.coreutils
    ];
    text = ''
      umask 077

      declared="$1"
      target="$HOME/.codex/config.toml"
      base="$target.hm-base"
      merged="$target.hm-merged"
      out="$target.hm-new"
      trap 'rm -f "$base" "$merged" "$out"' EXIT

      mkdir -p "$HOME/.codex"

      if [ -s "$target" ]; then
        if ! yj -tj < "$target" > "$base" 2>/dev/null; then
          echo "codex config.toml is not valid TOML; leaving it unchanged" >&2
          exit 0
        fi
      else
        echo '{}' > "$base"
      fi

      jq -s '.[0] * .[1]' "$base" "$declared" > "$merged"

      # A store symlink an earlier generation left has to be replaced even when
      # the merge itself is a no-op.
      if [ ! -L "$target" ] && [ "$(jq -Sc . "$base")" = "$(jq -Sc . "$merged")" ]; then
        # umask only covers the write path, so tighten a file left loose here.
        chmod 600 "$target"
        exit 0
      fi

      # rename(2) replaces the symlink itself rather than writing through it.
      yj -jt < "$merged" > "$out"
      mv "$out" "$target"
    '';
  };
in
{
  options.codexConfig = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "Shared Codex configuration";
  };

  config = {
    codexConfig = {
      settings = codexSettings;
    };

    # Ahead of linkGeneration: it deletes the config.toml symlink an earlier
    # generation left, and the merge needs that file's keys.
    home.activation.codexSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      run ${settings-merge}/bin/codex-settings-merge ${
        (pkgs.formats.json { }).generate "codex-settings.json" config.codexConfig.settings
      }
    '';

    programs.codex = {
      enable = true;
      # Cached at cache.numtide.com; the shared-nixpkgs overlay would rebuild
      # it locally against our nixpkgs. See home/claude-code.nix.
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
      context = rtkAwareness;
      # settings stays unset: the module installs config.toml as a store
      # symlink that linkGeneration restores over the merged file. The merge
      # above reads codexConfig.settings directly instead.
    };
  };
}

{
  lib,
  pkgs,
  ...
}:
let
  # Pi updates settings at runtime, so keep the file writable and merge packages.
  piSettingsMerge = pkgs.writeShellApplication {
    name = "pi-settings-merge";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      umask 077

      target="$HOME/.pi/agent/settings.json"
      base="$target.hm-base"
      merged="$target.hm-new"
      trap 'rm -f "$base" "$merged"' EXIT

      mkdir -p "$HOME/.pi/agent"

      if [ -s "$target" ]; then
        if ! jq -e . "$target" > "$base" 2>/dev/null; then
          echo "pi settings.json is not valid JSON; leaving it unchanged" >&2
          exit 0
        fi
      else
        echo '{}' > "$base"
      fi

      # Vim must load last: Powerline replaces the prompt editor on startup.
      jq \
        --arg vimmode "npm:pi-vimmode@0.9.0" \
        --arg automode "npm:@czottmann/pi-automode@1.16.0" \
        '
          def is_package($name):
            (if type == "string" then . else .source end)
            | . == $name or startswith($name + "@");

          (.packages // []) as $existing
          | ($existing | map(select(is_package("npm:pi-vimmode")))) as $vimPackages
          | (if any($existing[]; is_package("npm:@czottmann/pi-automode")) then [] else [$automode] end) as $append
          | .packages = (
              ($existing | map(select(is_package("npm:pi-vimmode") | not)))
              + $append
              + (if $vimPackages == [] then [$vimmode] else $vimPackages end)
            )
        ' "$base" > "$merged"

      # Symlinks must be replaced to keep settings writable.
      if [ ! -L "$target" ] && [ "$(jq -Sc . "$base")" = "$(jq -Sc . "$merged")" ]; then
        chmod 600 "$target"
        exit 0
      fi

      mv "$merged" "$target"
    '';
  };
in
{
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${piSettingsMerge}/bin/pi-settings-merge
  '';
}

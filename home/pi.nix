{
  lib,
  pkgs,
  ...
}:
let
  # pi writes ~/.pi/agent/settings.json itself (theme, quietStartup,
  # lastChangelogVersion, and packages added via `pi install`), so the file
  # stays a writable regular file rather than a home.file symlink. Each
  # activation only ensures the two declared packages are present instead of
  # overwriting the file, so runtime-added packages and app-written state
  # (theme, lastChangelogVersion, ...) survive rebuilds.
  #
  # pi-vimmode: full modal vim editing for the prompt editor (normal/insert/
  # visual modes, motions, operators). Load it last: pi-powerline-footer
  # replaces the editor in session_start, discarding Vim's key handling.
  # Move existing entries too, preserving their versions and resource filters.
  # This chooses Vim's editor, not a composition with Powerline's editor extras;
  # Powerline preset/toggle commands can still replace it during a session.
  # pi-automode: Claude Code-style auto mode guardrail (classifier reviews
  # tool calls before they run); pi has no built-in equivalent.
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

      # A store symlink an earlier generation left has to be replaced even
      # when the merge itself is a no-op.
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

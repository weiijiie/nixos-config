{ pkgs }:
{
  nix-rebuild = pkgs.writeShellApplication {
    name = "nix-rebuild";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      FLAKE="$HOME/nixos-config"

      if [ ! -d "$FLAKE" ]; then
        echo "error: $FLAKE not found. clone the repo there first." >&2
        exit 1
      fi

      HOST="$(uname -n)"
      HOST="''${HOST%%.*}"
      USER_NAME="$(id -un)"

      if [ -e /etc/NIXOS ]; then
        exec sudo nixos-rebuild switch --flake "$FLAKE#$HOST" "$@"
      elif [ "$(uname -s)" = "Darwin" ]; then
        exec darwin-rebuild switch --flake "$FLAKE#$HOST" "$@"
      else
        exec home-manager switch --flake "$FLAKE#$USER_NAME@$HOST" "$@"
      fi
    '';
  };
}

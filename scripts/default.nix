{ pkgs }:
{
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      HOST="$(uname -n)"
      HOST="''${HOST%%.*}"
      USER_NAME="$(id -un)"

      if [ -e /etc/NIXOS ]; then
        exec sudo nixos-rebuild switch --flake ".#$HOST" "$@"
      elif [ "$(uname -s)" = "Darwin" ]; then
        exec darwin-rebuild switch --flake ".#$HOST" "$@"
      else
        exec home-manager switch --flake ".#$USER_NAME@$HOST" "$@"
      fi
    '';
  };
}

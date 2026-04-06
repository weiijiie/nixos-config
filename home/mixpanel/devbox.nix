# disable some of the config because it has already been
# configured in the devbox during provisioning
{
  outputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common.nix
  ];

  home.packages = lib.mkForce (
    (with pkgs; [
      manix
      tree
      yq-go
      tokei
      tldr
      bottom
      bazel-buildtools
      delve
      nixd
      nixfmt-rfc-style
      cachix
      custom.code2prompt
      ast-grep
    ])
    ++ (with outputs.packages.${pkgs.stdenv.hostPlatform.system}; [
      nvim
      rtk
    ])
  );

  programs.ssh.enable = lib.mkForce false;
  programs.go.enable = lib.mkForce false;

  programs.git.ignores = [ "/go/.editorconfig" ];

  programs.zsh = {
    initContent = lib.mkAfter ''
      # devbox setup
      source ~/.gcpdevbox
      source ~/analytics/google-cloud/scripts/kube.sh

      function gcloud() {
        if [[ "$1" == "compute" && "$2" == "ssh" ]]; then
            TERM=xterm-256color command gcloud "$@"
        else
            command gcloud "$@"
        fi
      }
    '';

    envExtra = ''
      source $HOME/analytics/.shellenv
    '';

    shellAliases = {
      bat = "${pkgs.bat}/bin/bat";
      shadow = "kubectl get pods --selector role=lqs-shadow -o json | ${pkgs.jq}/bin/jq -r '.items[0].metadata.name'";
      "perfflame.sh" = "~/analytics/tools/marcus/perfflame.sh";
      arb = "~/analytics/backend/arb/reader/arb";
    };
  };
}

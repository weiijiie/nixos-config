# disable some of the config because it has already been
# configured in the devbox during provisioning
{ pkgs, ... }@args:
((common:
  common // {
    home = common.home // {
      packages = with pkgs; [
        manix
        tree
        yq-go
        tokei
        ranger
        tldr
        bottom
        nil
        nixfmt-classic
        bazel-buildtools
      ];
    };

    programs = common.programs // {
      ssh.enable = false;
      go.enable = false;

      git = common.programs.git // { ignores = [ "/go/.editorconfig" ]; };

      zsh = common.programs.zsh // {
        initExtra = common.programs.zsh.initExtra + "\n" + ''
          # devbox setup
          source ~/.gcpdevbox
          source ~/analytics/google-cloud/scripts/kube.sh
        '';

        envExtra = ''
          source $HOME/analytics/.shellenv
        '';

        shellAliases = common.programs.zsh.shellAliases // {
          "gcloud compute ssh" = "TERM=xterm-256color gcloud compute ssh";
        };
      };
    };
  }) (import ../common.nix args))
